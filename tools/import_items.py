"""Import official item names from the WoW Forever client tables.

Downloads the ItemSparse table of one pinned Forever build in enUS and zhCN from
wago.tools (which extracts the client's DB2 files from Blizzard's CDN), keeps
the items whose zhCN name is actually Chinese, and writes the reviewable source
file data/sources/items.json. Network access is only needed here; the build
reads the JSON offline.

Usage: python3 tools/import_items.py [--build 1.60.1.71037] [--cache DIR]
"""
import argparse
import csv
import hashlib
import io
import json
from pathlib import Path
import re
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
BUILD = "1.60.1.71037"
INTERFACE = 16001
URL = "https://wago.tools/db2/{table}/csv?build={build}&locale={locale}"
OUTPUT = ROOT / "data/sources/items.json"
HAN = re.compile(r"[㐀-䶿一-鿿]")


def fetch(table, build, locale, cache):
    """CSV text of one table, cached on disk by build and locale."""
    path = cache / f"{table}-{build}-{locale}.csv"
    if not path.exists():
        request = urllib.request.Request(URL.format(table=table, build=build, locale=locale),
                                         headers={"User-Agent": "WoWFeTranslator-import"})
        with urllib.request.urlopen(request, timeout=300) as response:
            data = response.read()
        if data.lstrip().startswith(b"{"):
            raise SystemExit(f"{table} {locale}: wago.tools returned an error: {data[:200]!r}")
        cache.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    return path.read_bytes()


def rows(data, name_field):
    """ID -> name for every row with a nonempty name."""
    reader = csv.DictReader(io.StringIO(data.decode("utf-8")))
    if "ID" not in reader.fieldnames or name_field not in reader.fieldnames:
        raise SystemExit(f"unexpected columns: {reader.fieldnames[:8]}")
    out = {}
    for row in reader:
        name = (row[name_field] or "").strip()
        if name and not any(ord(c) < 32 for c in name):
            out[int(row["ID"])] = name
    return out


def entities(english, chinese, source):
    """Items with an English name and a Chinese zhCN name, sorted by ID."""
    out = []
    for item_id in sorted(chinese):
        zh, en = chinese[item_id], english.get(item_id)
        if en and HAN.search(zh):
            out.append({"type": "item", "id": item_id, "names": {"enUS": en, "zhCN": zh},
                        "source": source})
    return out


def document(items, build, hashes):
    source = f"forever-db2-{build}"
    return {
        "schemaVersion": 1,
        "game": "forever",
        "interface": INTERFACE,
        "sources": {source: {
            "description": f"Official enUS and zhCN item names (ItemSparse.Display_lang) of WoW Forever "
                           f"client build {build}, exported by wago.tools from Blizzard's CDN.",
            "rights": "Item names are Blizzard Entertainment game text, redistributed only to display "
                      "translations in the game; no third-party addon code or database copied.",
            "revision": f"{build}; ItemSparse enUS sha256 {hashes['enUS']}, zhCN sha256 {hashes['zhCN']}",
        }},
        "entities": [dict(e, source=source) for e in items],
        "terms": [],
        "texts": [],
    }


def write(doc, path=OUTPUT):
    """One entity per line, so a new build shows as a readable diff."""
    head = {k: v for k, v in doc.items() if k != "entities"}
    text = json.dumps(head, ensure_ascii=False, indent=2, sort_keys=True)
    lines = [json.dumps(e, ensure_ascii=False, sort_keys=True) for e in doc["entities"]]
    body = '  "entities": [\n    ' + ",\n    ".join(lines) + "\n  ],\n"
    text = text[:2] + body + text[2:]
    path.write_text(text + "\n", encoding="utf-8", newline="\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", default=BUILD)
    parser.add_argument("--cache", type=Path, default=ROOT / ".cache/wago")
    args = parser.parse_args()
    raw = {locale: fetch("ItemSparse", args.build, locale, args.cache) for locale in ("enUS", "zhCN")}
    hashes = {locale: hashlib.sha256(data).hexdigest() for locale, data in raw.items()}
    english, chinese = rows(raw["enUS"], "Display_lang"), rows(raw["zhCN"], "Display_lang")
    items = entities(english, chinese, "")
    write(document(items, args.build, hashes))
    print(f"{len(items)} items with Chinese names of {len(english)} rows -> {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
