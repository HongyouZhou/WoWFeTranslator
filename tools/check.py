"""Run the reproducible developer checks from any working directory."""
import hashlib
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile

import build


def run(*command):
    subprocess.run(command, cwd=build.ROOT, check=True)


def main():
    for executable in ("lua5.1", "luac5.1"):
        if not shutil.which(executable):
            raise SystemExit(f"Missing {executable}; install Lua 5.1 development tools.")
    run(sys.executable, "-m", "unittest", "discover", "-s", "tests", "-v")
    for folder in ("addon", "tests", "benchmarks"):
        for file in sorted((build.ROOT / folder).rglob("*.lua")):
            run("luac5.1", "-p", str(file))
    run("lua5.1", "tests/runtime.lua")
    for toc in (build.ROOT / "addon").rglob("*.toc"):
        for line in toc.read_text().splitlines():
            if line and not line.startswith("#"):
                assert (toc.parent / line).is_file(), f"Missing TOC entry {line}"
    archive = build.package()
    first = hashlib.sha256(archive.read_bytes()).hexdigest()
    build.package()
    assert first == hashlib.sha256(archive.read_bytes()).hexdigest(), "ZIP not reproducible"
    with zipfile.ZipFile(archive) as package:
        assert package.testzip() is None
        entries = set(package.namelist())
        assert {p.split("/")[0] for p in entries} == {"WoWFeTranslator", build.DATA_ADDON}
        for entry in ("WoWFeTranslator/WoWFeTranslator.toc", "WoWFeTranslator/Fonts/OFL.txt",
                      "WoWFeTranslator/Fonts/LXGWWenKaiLite-Regular.ttf",
                      "WoWFeTranslator/TESTING-zhCN.txt", "WoWFeTranslator/THIRD-PARTY.txt",
                      "WoWFeTranslator_Data_Items/WoWFeTranslator_Data_Items.toc"):
            assert entry in entries, "Missing install entry " + entry
        assert not any(p.endswith((".py", ".json")) for p in entries)
    print(f"PASS Lua syntax, TOC paths, ZIP layout, licenses and byte-identical rebuild\n{archive}")


if __name__ == "__main__":
    main()
