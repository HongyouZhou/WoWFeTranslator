import unittest

from tools import forever_api


def names(source):
    return [message.split(" ")[0] for _, _, message in forever_api.scan(source)]


class ForeverApiTest(unittest.TestCase):
    def test_direct_calls_are_reported(self):
        self.assertEqual(names("local n = GetItemInfo(6948)"), ["GetItemInfo"])
        self.assertEqual(names("x = _G.GetSpellInfo(1)"), ["GetSpellInfo"])
        self.assertEqual(names("LoadAddOn('X') GetItemCount(1)"), ["LoadAddOn", "GetItemCount"])

    def test_namespaced_methods_and_fields_are_fine(self):
        self.assertEqual(names("C_Item.GetItemInfo(1)"), [])
        self.assertEqual(names("tooltip:GetItemInfo()"), [])
        self.assertEqual(names("local t = { GetItemInfo = 1 }"), [])
        self.assertEqual(names("local MyGetItemInfo = 1; MyGetItemInfo()"), [])

    def test_guarded_uses_and_fallback_values_are_fine(self):
        self.assertEqual(names("local n = GetItemInfo and GetItemInfo(1)"), [])
        self.assertEqual(names("if GetItemInfo then GetItemInfo(1) end"), [])
        self.assertEqual(names("if type(GetItemInfo) == 'function' then GetItemInfo(1) end"), [])
        self.assertEqual(names("local load = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn"), [])

    def test_guard_of_another_name_does_not_count(self):
        self.assertEqual(names("if C_Item.GetItemInfo and x then GetItemInfo(1) end"), ["GetItemInfo"])

    def test_comments_and_strings_are_ignored(self):
        self.assertEqual(names("-- GetItemInfo(1)"), [])
        self.assertEqual(names("print('GetItemInfo(1)')"), [])
        self.assertEqual(names("--[[\nGetItemInfo(1)\n]] x = 1"), [])
        self.assertEqual(names("local s = [==[GetItemInfo(1)]==]"), [])

    def test_line_numbers_survive_stripping(self):
        source = "--[[ a\nb ]]\nlocal s = 'x'\nGetItemInfo(1)"
        self.assertEqual(forever_api.scan(source)[0][1], 4)

    def test_hooking_a_missing_global_is_reported(self):
        self.assertEqual(names('hooksecurefunc("GetItemInfo", f)'), ["GetItemInfo"])
        self.assertEqual(names('hooksecurefunc(GameTooltip, "SetOwner", f)'), [])
        self.assertEqual(names('if GetItemInfo then hooksecurefunc("GetItemInfo", f) end'), [])

    def test_accept_comment_needs_a_reason(self):
        self.assertEqual(names("GetItemInfo(1) -- forever-api-ok: guarded above"), [])
        self.assertEqual(names("GetItemInfo(1) -- forever-api-ok:"), ["forever-api-ok"])

    def test_addon_sources_pass(self):
        self.assertEqual(forever_api.scan_tree(), [])


if __name__ == "__main__":
    unittest.main()
