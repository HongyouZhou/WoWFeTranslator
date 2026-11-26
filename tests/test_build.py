import copy
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

from tools import build, import_items

STUB = ("WoWFeTranslator={names={},RegisterNames=function(m) local t={} WoWFeTranslator.names[m.kind]=t "
        "WoWFeTranslator.meta=m return t end,FinishNames=function(k,l) local n=0 "
        "for _ in pairs(WoWFeTranslator.names[k]) do n=n+1 end assert(n==WoWFeTranslator.meta.count) "
        "WoWFeTranslator.done=k..l end}\n")


def run_lua(source, check):
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "pack.lua"
        path.write_text(STUB + source + check, encoding="utf-8")
        subprocess.run(["lua5.1", str(path)], check=True)


def fixture():
    data = build.load_source(build.ROOT / "tests/fixtures/sample-items.json")
    data["terms"] = [{"key": "item.hearthstone", "names": {"enUS": "Hearthstone", "zhCN": "炉石"},
                      "aliases": {"enUS": ["hearthstone"]}, "source": "manual-sample",
                      "entity": {"type": "item", "id": 6948}}]
    content = {
        "enUS": [{"id": "e1", "parts": [{"variable": "player"}, {"text": ", use your "},
                                         {"text": "Hearthstone", "term": "item.hearthstone"}, {"text": "."}]}],
        "zhCN": [{"id": "c1", "parts": [{"variable": "player"}, {"text": "，使用"},
                                         {"text": "炉石", "term": "item.hearthstone"}, {"text": "。"}]}],
    }
    data["texts"] = [{"key": "test.example", "entity": {"type": "item", "id": 6948},
                      "field": "description", "source": "manual-sample", "content": content,
                      "contentFingerprint": build.fingerprint(content),
                      "alignment": [{"enUS": ["e1"], "zhCN": ["c1"]}]}]
    return data


class BuildTests(unittest.TestCase):
    def test_names_pack_roundtrip(self):
        # Terms and texts are validated but stay in the source; the pack carries names only.
        generated = build.generate(fixture())
        self.assertNotIn("Hearthstone", generated)
        run_lua(generated, "assert(WoWFeTranslator.names.item[6948]=='炉石')\n"
                           "assert(WoWFeTranslator.meta.schemaVersion==2 and WoWFeTranslator.done=='itemzhCN')\n")

    def test_large_pack_is_chunked_under_lua_limits(self):
        data = fixture()
        data["texts"], data["terms"] = [], []
        data["entities"] = [{"type": "item", "id": i, "names": {"enUS": f"Item {i}", "zhCN": f"物品{i}"},
                             "source": "manual-sample"} for i in range(1, 100001)]
        generated = build.generate(data)
        self.assertEqual(generated.count("function(t)"), 50)
        run_lua(generated, "assert(WoWFeTranslator.names.item[100000]=='物品100000')\n")
        small = build.generate(data | {"entities": data["entities"][:7]}, chunk=3)
        self.assertEqual(small.count("function(t)"), 3)
        run_lua(small, "assert(WoWFeTranslator.names.item[7]=='物品7')\n")

    def test_stable_generation_and_revision_change(self):
        data = fixture()
        rearranged = json.loads(json.dumps(data, sort_keys=True))
        self.assertEqual(build.generate(data), build.generate(rearranged))
        changed = copy.deepcopy(data)
        changed["entities"][0]["names"]["zhCN"] = "测试"
        self.assertNotEqual(build.generate(data), build.generate(changed))

    def test_bad_data_rejected(self):
        def duplicate(d): d["entities"].append(copy.deepcopy(d["entities"][0]))
        def missing_source(d): d["entities"][0]["source"] = "absent"
        def string_id(d): d["entities"][0]["id"] = "6948"
        def unknown_term(d): d["terms"] = []
        def stale(d): d["texts"][0]["content"]["enUS"][0]["parts"][1]["text"] = "changed"
        def alignment(d): d["texts"][0]["alignment"][0]["zhCN"] = ["missing"]
        def duplicated_alignment(d): d["texts"][0]["alignment"] *= 2
        def variable(d):
            r = d["texts"][0]
            r["content"]["zhCN"][0]["parts"][0]["variable"] = "quantity"
            r["contentFingerprint"] = build.fingerprint(r["content"])
        for mutate in (duplicate, missing_source, string_id, unknown_term, stale,
                       alignment, duplicated_alignment, variable):
            with self.subTest(case=mutate.__name__):
                data = fixture()
                mutate(data)
                with self.assertRaises(ValueError): build.generate(data)

    def test_missing_translation_allowed(self):
        data = fixture()
        del data["entities"][1]["names"]["zhCN"]
        build.validate(data)

    def test_markup_literals_and_lua_escaping(self):
        value = '中文"\\\n\000123|Hitem:6948|h[Name]|h'
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "escape.lua"
            path.write_text("io.write(" + build.lua(value) + ")")
            actual = subprocess.check_output(["lua5.1", str(path)])
        self.assertEqual(actual, value.encode())

    def test_duplicate_json_keys(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "bad.json"
            path.write_text('{"id":1,"id":2}')
            with self.assertRaisesRegex(ValueError, "duplicate JSON"):
                build.load_source(path)

    def test_version_comes_from_main_toc(self):
        version = build.read_version()
        data_toc = (build.ROOT / "addon" / build.DATA_ADDON / (build.DATA_ADDON + ".toc")).read_text()
        self.assertIn("## Version: " + version + "\n", data_toc)
        with tempfile.TemporaryDirectory() as directory:
            toc = Path(directory) / build.MAIN_TOC
            toc.parent.mkdir(parents=True)
            for bad in ("## Title: x\n", "## Version: v1\n"):
                toc.write_text(bad)
                with self.assertRaises(ValueError):
                    build.read_version(Path(directory))

    def test_checked_in_generated_data_current(self):
        source = build.load_source(build.ROOT / build.SOURCE)
        output = build.ROOT / "addon" / build.DATA_ADDON / "Data.lua"
        self.assertEqual(build.generate(source), output.read_text())


class ImportTests(unittest.TestCase):
    CSV_EN = "ID,Display_lang\n25,Worn Shortsword\n26,Unused Thing\n27,\n28,Only English\n"
    CSV_ZH = "ID,Display_lang\n25,破损的短剑\n26,Unused Thing\n27,孤儿\n29,无英文\n"

    def test_only_items_with_english_and_chinese_names(self):
        english = import_items.rows(self.CSV_EN.encode(), "Display_lang")
        chinese = import_items.rows(self.CSV_ZH.encode(), "Display_lang")
        items = import_items.entities(english, chinese, "s")
        self.assertEqual([(e["id"], e["names"]["zhCN"]) for e in items], [(25, "破损的短剑")])

    def test_written_source_is_valid_and_reloads(self):
        english = import_items.rows(self.CSV_EN.encode(), "Display_lang")
        chinese = import_items.rows(self.CSV_ZH.encode(), "Display_lang")
        doc = import_items.document(import_items.entities(english, chinese, ""), "1.60.1.1",
                                    {"enUS": "a", "zhCN": "b"})
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "items.json"
            import_items.write(doc, path)
            loaded = build.load_source(path)
        self.assertEqual(loaded, doc)
        build.validate(loaded)

    def test_checked_in_source_matches_its_build(self):
        data = build.load_source(build.ROOT / build.SOURCE)
        self.assertEqual(list(data["sources"]), ["forever-db2-" + import_items.BUILD])
        self.assertGreater(len(data["entities"]), 17000)


if __name__ == "__main__":
    unittest.main()
