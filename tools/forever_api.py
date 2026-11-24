"""Static check for game globals the WoW Forever client may not define.

Forever runs the 12.1 engine without the deprecation fallback addons that still
define many legacy globals on retail, so calling one of these unguarded raises an
error on Forever. Each listed name maps to the namespaced API to use instead.

Rules, per line of addon Lua (comments and strings ignored):
- A direct call of a listed global (``GetItemInfo(...)`` or ``_G.GetItemInfo(...)``)
  is an error unless the same line guards it (``GetItemInfo and GetItemInfo(x)``,
  ``if GetItemInfo then``, ``type(GetItemInfo)``, ``GetItemInfo ~= nil``).
  Reading the global as a fallback value (``C_Item.GetItemInfo or GetItemInfo``)
  is allowed because the caller must then test the result.
- ``hooksecurefunc("Name", ...)`` on a listed global is an error unless guarded.
- A line can be accepted with ``-- forever-api-ok: <reason>``; the reason is required.
The check is line based: a guard on an earlier line is not seen, so use the
comment for such cases.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def _moved(namespace, names):
    return {name: f"{namespace}.{name}" for name in names.split()}


# Factual API names. Grouped by the namespace that replaces them.
REPLACEMENTS = {}
REPLACEMENTS.update(_moved("C_AddOns", "LoadAddOn IsAddOnLoaded IsAddOnLoadOnDemand GetAddOnInfo "
                           "GetAddOnMetadata GetNumAddOns EnableAddOn DisableAddOn "
                           "GetAddOnMemoryUsage UpdateAddOnMemoryUsage GetAddOnCPUUsage "
                           "UpdateAddOnCPUUsage GetAddOnDependencies"))
REPLACEMENTS.update(_moved("C_Item", "GetItemInfo GetItemInfoInstant GetItemCount GetItemSpell "
                           "GetItemQualityColor GetItemClassInfo GetItemSubClassInfo "
                           "GetItemCooldown GetItemFamily GetItemGem GetItemSetInfo "
                           "GetDetailedItemLevelInfo IsEquippableItem IsEquippedItem "
                           "IsUsableItem IsConsumableItem IsHarmfulItem IsHelpfulItem "
                           "IsItemInRange ItemHasRange PickupItem EquipItemByName UseItemByName"))
REPLACEMENTS.update(_moved("C_Spell", "GetSpellInfo GetSpellTexture GetSpellCooldown "
                           "GetSpellCharges GetSpellDescription GetSpellLink IsUsableSpell "
                           "IsSpellInRange GetSpellCount"))
REPLACEMENTS.update(_moved("C_Container", "GetContainerNumSlots GetContainerItemInfo "
                           "GetContainerItemLink GetContainerItemID GetContainerNumFreeSlots "
                           "PickupContainerItem UseContainerItem"))
REPLACEMENTS.update(_moved("C_SpecializationInfo", "GetSpecialization GetSpecializationInfo "
                           "GetNumSpecializationsForClassID GetActiveSpecGroup"))
REPLACEMENTS.update(_moved("C_CurrencyInfo", "GetCoinIcon GetCoinText GetCoinTextureString"))
REPLACEMENTS.update({
    "GetItemIcon": "C_Item.GetItemIconByID",
    "UnitAura": "C_UnitAuras.GetAuraDataByIndex",
    "UnitBuff": "C_UnitAuras.GetBuffDataByIndex",
    "UnitDebuff": "C_UnitAuras.GetDebuffDataByIndex",
    "GetMouseFocus": "GetMouseFoci",
    "InterfaceOptions_AddCategory": "Settings.RegisterCanvasLayoutCategory",
    "EasyMenu": "MenuUtil.CreateContextMenu",
})

_NAMES = "|".join(sorted(map(re.escape, REPLACEMENTS), key=len, reverse=True))
_CALL = re.compile(r"(?:(?<![\w.:])|(?<=\b_G\.))(" + _NAMES + r")\s*\(")
_HOOK = re.compile(r"hooksecurefunc\s*\(\s*([\"'])(" + _NAMES + r")\1")
_OK = re.compile(r"--\s*forever-api-ok:(.*)$")


def _guarded(line, name):
    # The name itself, not a field of the same name (C_Item.GetItemInfo).
    n = r"(?<![\w.:])" + re.escape(name)
    return re.search(rf"{n}\s+and\b|\bif\s+(?:not\s+)?{n}\b|\btype\s*\(\s*{n}\s*\)"
                     rf"|{n}\s*[~=]=\s*nil\b", line) is not None


def strip(source):
    """Blank out comments and string contents, keeping quotes and line breaks."""
    out, i, n = [], 0, len(source)
    while i < n:
        c = source[i]
        long = re.match(r"\[(=*)\[", source[i:]) if c == "[" else None
        if source.startswith("--", i):
            block = re.match(r"--\[(=*)\[", source[i:])
            if block:
                end = source.find("]" + block.group(1) + "]", i)
                end = n if end < 0 else end + len(block.group(1)) + 2
            else:
                end = source.find("\n", i)
                end = n if end < 0 else end
            out.append(re.sub(r"[^\n]", " ", source[i:end]))
            i = end
        elif long:
            end = source.find("]" + long.group(1) + "]", i)
            end = n if end < 0 else end + len(long.group(1)) + 2
            out.append('"' + re.sub(r"[^\n]", " ", source[i + 1:end - 1]) + '"')
            i = end
        elif c in "\"'":
            j = i + 1
            while j < n and source[j] != c and source[j] != "\n":
                j += 2 if source[j] == "\\" else 1
            out.append(c + " " * (min(j, n) - i - 1) + (c if j < n and source[j] == c else ""))
            i = j + 1 if j < n and source[j] == c else j
        else:
            out.append(c)
            i += 1
    return "".join(out)


def scan(source, path="<string>"):
    """Errors as (path, line number, message)."""
    errors = []
    raw_lines = source.split("\n")
    code_lines = strip(source).split("\n")
    for number, (raw, code) in enumerate(zip(raw_lines, code_lines), 1):
        ok = _OK.search(raw)
        if ok:
            if not ok.group(1).strip():
                errors.append((path, number, "forever-api-ok needs a reason"))
            continue
        found = [m.group(1) for m in _CALL.finditer(code)]
        # String contents are blanked in code, so the hook check reads the raw line
        # but only where the code line still has the hooksecurefunc call.
        if "hooksecurefunc" in code:
            found += [m.group(2) for m in _HOOK.finditer(raw)]
        for name in found:
            if not _guarded(code, name):
                errors.append((path, number, f"{name} may be missing on Forever; "
                                             f"use {REPLACEMENTS[name]} or guard it"))
    return errors


def scan_tree(root=ROOT):
    errors = []
    for path in sorted((root / "addon").rglob("*.lua")):
        errors += scan(path.read_text(encoding="utf-8"), path.relative_to(root).as_posix())
    return errors


if __name__ == "__main__":
    problems = scan_tree()
    for path, line, message in problems:
        print(f"{path}:{line}: {message}")
    raise SystemExit(1 if problems else 0)
