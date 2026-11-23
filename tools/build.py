"""Offline-only validator, Lua generator and reproducible internal ZIP builder.

Python >=3.10, standard library only. No Python is shipped to the game.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = "0.1.0-alpha.1"
DATA_ADDON = "WoWFeTranslator_Data_Items"


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def fingerprint(value):
    return hashlib.sha256(canonical(value).encode("utf-8")).hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def string(value):
    return isinstance(value, str) and bool(value) and not any(ord(c) < 32 for c in value)


def names(value):
    require(isinstance(value, dict) and value, "names must be a nonempty locale map")
    for locale, text in value.items():
        require(re.fullmatch(r"[a-z]{2}[A-Z]{2}", locale) and string(text), "invalid localized name")


def validate(data):
    require(data.get("schemaVersion") == 1, "unsupported schemaVersion")
    require(data.get("game") == "forever", "unsupported game")
    require(type(data.get("interface")) is int and data["interface"] > 0, "invalid interface")
    sources = data.get("sources")
    require(isinstance(sources, dict) and sources, "sources required")
    for key, source in sources.items():
        require(string(key) and isinstance(source, dict), "invalid source")
        for field in ("description", "rights", "revision"):
            require(string(source.get(field)), "source needs " + field)
    for kind in ("entities", "terms", "texts"):
        require(isinstance(data.get(kind), list), kind + " must be a list")

    def provenance(record):
        require(record.get("source") in sources, "unknown source reference")

    def entity_key(record):
        require(isinstance(record, dict), "invalid entity reference")
        require(record.get("type") in ("item", "npc", "spell", "quest"), "invalid entity type")
        require(type(record.get("id")) is int and 0 < record["id"] < 2**31, "invalid entity id")
        return record["type"], record["id"]

    entities, terms, texts = {}, {}, {}
    for entity in data["entities"]:
        key = entity_key(entity)
        require(key not in entities, "duplicate entity")
        names(entity.get("names"))
        provenance(entity)
        entities[key] = entity
    for term in data["terms"]:
        key = term.get("key")
        require(string(key) and key not in terms, "invalid or duplicate term key")
        names(term.get("names"))
        provenance(term)
        if "entity" in term:
            require(entity_key(term["entity"]) in entities, "unknown term entity")
        require(isinstance(term.get("aliases", {}), dict), "aliases must be a locale map")
        for locale, aliases in term.get("aliases", {}).items():
            require(locale in term["names"] and isinstance(aliases, list)
                    and all(string(a) for a in aliases), "invalid aliases")
        terms[key] = term
    for record in data["texts"]:
        key = record.get("key")
        require(string(key) and key not in texts, "invalid or duplicate text key")
        require(entity_key(record.get("entity")) in entities, "unknown text entity")
        require(string(record.get("field")), "text field required")
        provenance(record)
        content = record.get("content")
        require(isinstance(content, dict) and content, "text content required")
        require(record.get("contentFingerprint") == fingerprint(content), "stale text fingerprint")
        segment_ids, variables = {}, {}
        for locale, segments in content.items():
            require(re.fullmatch(r"[a-z]{2}[A-Z]{2}", locale), "invalid text locale")
            require(isinstance(segments, list) and segments, "segments required")
            ids, tokens = set(), Counter()
            for segment in segments:
                sid = segment.get("id")
                require(string(sid) and sid not in ids, "duplicate or invalid segment id")
                ids.add(sid)
                parts = segment.get("parts")
                require(isinstance(parts, list) and parts, "segment parts required")
                for part in parts:
                    require(isinstance(part, dict), "invalid text part")
                    if set(part) == {"variable"}:
                        require(string(part["variable"]), "invalid variable")
                        tokens[part["variable"]] += 1
                    elif set(part) == {"text"}:
                        require(isinstance(part["text"], str), "invalid literal")
                    elif set(part) == {"text", "term"}:
                        require(part["term"] in terms and string(part["text"]), "unknown term reference")
                        require(locale in terms[part["term"]]["names"], "missing term locale")
                        require("|" not in part["text"], "annotated term cannot include UI markup")
                    else:
                        raise ValueError("unknown text part shape")
            segment_ids[locale], variables[locale] = ids, tokens
        require(all(v == next(iter(variables.values())) for v in variables.values()),
                "placeholder mismatch between locales")
        alignment = record.get("alignment", [])
        require(isinstance(alignment, list), "alignment must be a list")
        if alignment:
            require(len(content) >= 2, "alignment requires two locales")
            used = {locale: set() for locale in content}
            for row in alignment:
                require(isinstance(row, dict) and set(row) == set(content), "alignment locale mismatch")
                for locale, ids in row.items():
                    require(isinstance(ids, list) and ids and all(string(s) for s in ids), "invalid alignment row")
                    require(len(set(ids)) == len(ids), "duplicate aligned segment")
                    for sid in ids:
                        require(sid in segment_ids[locale] and sid not in used[locale], "invalid alignment reference")
                        used[locale].add(sid)
            require(used == segment_ids, "incomplete alignment")
        texts[key] = record
    return entities, terms, texts


def lua(value):
    r"""Serialize UTF-8 strings without JSON's incompatible \u escapes."""
    if isinstance(value, str):
        escaped = []
        for char in value:
            if char in ('"', "\\"):
                escaped.append("\\" + char)
            elif ord(char) < 32 or ord(char) == 127:
                escaped.append("\\%03d" % ord(char))
            else:
                escaped.append(char)
        return '"' + "".join(escaped) + '"'
    if value is True:
        return "true"
    if value is False:
        return "false"
    if type(value) is int:
        return str(value)
    if isinstance(value, list):
        return "{" + ",".join(lua(v) for v in value) + "}"
    if isinstance(value, dict):
        return "{\n" + "".join("[" + lua(k) + "]=" + lua(value[k]) + ",\n"
                                  for k in sorted(value)) + "}"
    raise ValueError("unsupported Lua value: " + repr(value))


def generate(data):
    entities, terms, texts = validate(data)
    by_type = {"item": {}}
    for (kind, identity), record in entities.items():
        by_type.setdefault(kind, {})[identity] = {"names": record["names"], "source": record["source"]}
    pack = dict(schemaVersion=1, game=data["game"], interface=data["interface"],
                dataRevision=fingerprint(data), sources=data["sources"],
                entities=by_type, terms=terms, texts=texts)
    return "-- Generated by tools/build.py; edit source JSON instead.\nWoWFeTranslator.RegisterData(" + lua(pack) + ")\n"


def load_source(path):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, "duplicate JSON key: " + key)
            result[key] = value
        return result
    return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique)


def build(root=ROOT):
    data = load_source(root / "data/sources/sample-items.json")
    generated = generate(data)
    folder = root / "addon" / DATA_ADDON
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "Data.lua").write_text(generated, encoding="utf-8", newline="\n")
    toc = (f"## Interface: {data['interface']}\n## Title: WoWFeTranslator - Sample Items\n"
           f"## Version: {VERSION}\n## Dependencies: WoWFeTranslator\n"
           "## LoadOnDemand: 1\n\nData.lua\n")
    (folder / (DATA_ADDON + ".toc")).write_text(toc, encoding="utf-8", newline="\n")
    return data


def package(root=ROOT):
    build(root)
    font = root / "addon/WoWFeTranslator/Fonts/LXGWWenKaiLite-Regular.ttf"
    require(hashlib.sha256(font.read_bytes()).hexdigest() ==
            "f799a538a3355877e597a0ae04050e897932c9ae7689eb9227c2953c5dd549ea", "font checksum mismatch")
    (root / "dist").mkdir(exist_ok=True)
    archive = root / "dist" / f"WoWFeTranslator-{VERSION}.zip"
    entries = {}
    for path in sorted((root / "addon").rglob("*")):
        if path.is_file() and path.suffix in (".lua", ".toc", ".ttf", ".txt"):
            entries[path.relative_to(root / "addon").as_posix()] = path.read_bytes()
    entries["WoWFeTranslator/TESTING-zhCN.txt"] = (root / "docs/windows-testing.md").read_bytes()
    entries["WoWFeTranslator/THIRD-PARTY.txt"] = (root / "THIRD-PARTY.md").read_bytes()
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as output:
        for name, content in sorted(entries.items()):
            info = zipfile.ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            output.writestr(info, content)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    archive.with_suffix(".zip.sha256").write_text(digest + "  " + archive.name + "\n", encoding="ascii")
    return archive


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", action="store_true")
    args = parser.parse_args()
    if args.package:
        print(package())
    else:
        data = build()
        print(f"Generated {len(data['entities'])} entities, revision {fingerprint(data)}")
