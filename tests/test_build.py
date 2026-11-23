import copy
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

from tools import build


def fixture():
    data = build.load_source(build.ROOT / "data/sources/sample-items.json")
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
    def test_multilingual_entities_terms_texts_roundtrip(self):
        generated = build.generate(fixture())
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "data.lua"
            path.write_text("WoWFeTranslator={RegisterData=function(p)\n"
                            "assert(p.entities.item[6948].names.zhCN=='炉石')\n"
                            "assert(p.texts['test.example'].content.enUS[1].parts[1].variable=='player')\n"
                            "assert(p.terms['item.hearthstone'].entity.id==6948)\nend}\n" + generated)
            subprocess.run(["lua5.1", str(path)], check=True)

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

    def test_checked_in_generated_data_current(self):
        source = build.load_source(build.ROOT / "data/sources/sample-items.json")
        output = build.ROOT / "addon/WoWFeTranslator_Data_Items/Data.lua"
        self.assertEqual(build.generate(source), output.read_text())


if __name__ == "__main__":
    unittest.main()
