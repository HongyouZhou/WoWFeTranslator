local _, A = ...
-- Text fonts. Where the client supports font families, one family per
-- (English font, size) carries a member per alphabet: Latin text uses the
-- user's English font and Chinese always uses the bundled font, so a Latin-only
-- English font can never turn Chinese into boxes, and mixed text in one
-- FontString renders. Without families, each column gets a plain font.
local F = { families = {}, loads = {}, created = 0 }
A.Fonts = F

-- Han characters are routed to the bundled font under both Chinese alphabets;
-- Cyrillic and Hangul keep the client's own fonts.
local BUNDLED = { simplifiedchinese = true, traditionalchinese = true }
local ALPHABETS = { "roman", "russian", "korean", "simplifiedchinese", "traditionalchinese" }

local function clientFont(alphabet)
    local base = _G.GameFontNormal
    local member = base and base.GetFontObjectForAlphabet and base:GetFontObjectForAlphabet(alphabet)
    local file = member and member.GetFont and member:GetFont()
    return type(file) == "string" and file or nil
end

-- Whether the client can load a font file. Probed once per path per session on
-- a hidden string; a file added while the game runs needs a restart anyway.
function F:Loads(path)
    local known = self.loads[path]
    if known ~= nil then return known end
    if not self.probe then
        local frame = CreateFrame("Frame")
        frame:Hide()
        self.probe = frame:CreateFontString(nil, "OVERLAY")
    end
    -- SetFont reports false for a file it cannot load; a client that returns
    -- nothing is treated as loaded rather than rejecting every font.
    local ok, loaded = pcall(self.probe.SetFont, self.probe, path, 12, "")
    self.loads[path] = ok and loaded ~= false
    return self.loads[path]
end

-- The font for Chinese text: the bundled one, else the client's own Chinese font.
function F:Chinese()
    if self:Loads(A.font) then return A.font end
    A.fontWarning = "Bundled font failed to load. Check the Fonts folder."
    return clientFont("simplifiedchinese") or STANDARD_TEXT_FONT
end

-- The font for English text: the selected one, else the bundled one, else the
-- client's standard font.
function F:English()
    local path = A.fonts[A.db.fontIndex] or A.font
    if self:Loads(path) then return path end
    if path ~= A.font then
        A.fontWarning = "English font failed to load; using the bundled font."
        if self:Loads(A.font) then return A.font end
    end
    A.fontWarning = "Bundled font failed to load. Check the Fonts folder."
    return STANDARD_TEXT_FONT
end

function F:Family(english, size)
    if type(CreateFontFamily) ~= "function" then return nil end
    local bySize = self.families[english]
    if not bySize then bySize = {}; self.families[english] = bySize end
    local family = bySize[size]
    if family ~= nil then return family or nil end
    local members = {}
    for i, alphabet in ipairs(ALPHABETS) do
        local file
        if BUNDLED[alphabet] then file = self:Chinese()
        elseif alphabet == "roman" then file = english
        else file = clientFont(alphabet) or english end
        members[i] = { alphabet = alphabet, file = file, height = size, flags = "" }
    end
    -- Font objects are never freed: one per English font and size (10-30).
    self.created = self.created + 1
    local ok, created = pcall(CreateFontFamily, A.name .. "Font" .. self.created, members)
    bySize[size] = ok and created or false
    return bySize[size] or nil
end

-- chinese: the string shows translated text, which needs Chinese glyphs when
-- no family is available.
function F:Apply(text, size, chinese)
    local english = self:English()
    local family = self:Family(english, size)
    if family then
        text:SetFontObject(family)
        self.mode = "family"
        return
    end
    self.mode = "plain"
    if text:SetFont(chinese and self:Chinese() or english, size, "") ~= false then return end
    text:SetFont(STANDARD_TEXT_FONT, size, "")
    A.fontWarning = "Font failed to load. Check the Fonts folder."
end
