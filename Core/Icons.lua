local _, ns = ...

--[[ ns.Icons — the Phoenix icon system (Phosphor duotone glyphs, MIT; see Media/Icons/LICENSE).
    Glyphs are white in three pre-filtered atlas tiers (24/48/64 px cells, uncompressed TGA, ≤1024 px, Core/IconData.lua). WoW does not
    mipmap addon TGAs, so every icon picks the smallest tier that covers its size in *physical* pixels and is
    re-evaluated when the UI scale or resolution changes. Colour comes from theme tokens via SetVertexColor.

    Icons:Create(parent, name, size, token[, layer, sublevel]) -> texture
    Icons:Apply(tex, name[, size])      set/replace the glyph (unknown names fall back to "question")
    Icons:Tint(tex, token[, alpha])     base colour token
    Icons:SetState(tex, state)          nil/"normal" | "hover" | "active" | "danger" | "disabled"
    Icons:Markup(name, size[, token])   inline |T..|t string for FontStrings
    Icons:Has(name) / Icons:Owns(tex)   known glyph name / texture is a tracked glyph
    Icons:Brand(tex, kind, width)       "emblem" | "logo" art at the best resolution for width
    Icons:GetTier(tex) -> file, cell    atlas tier a texture currently uses ]]
local I = {}
ns.Icons = I
local D = ns.IconData
local Theme = ns.Theme

local DIR = "Interface\\AddOns\\" .. ns.ADDON .. "\\Media\\Icons\\"
I.FALLBACK = "question"
I.EMBLEM_SMALL = ns.C.TEXTURES .. "Emblem64" -- TOC IconTexture and the Addon Compartment
I.missing = {}                                 -- names requested but not in the set (checked by the smoke test)

local BRAND = {
    emblem = { { px = 64, file = "Emblem64" }, { px = 128, file = "Emblem128" }, { px = 256, file = "Emblem256" } },
    logo = { { px = 512, file = "Logo512" }, { px = 1024, file = "Logo1024" } },
}
local STATE_TOKEN = { hover = "text.primary", active = "accent.primary", danger = "state.danger", disabled = "text.muted" }

local tracked = setmetatable({}, { __mode = "k" }) -- texture -> { name, size, token, alpha, state, brand, width }

--[[ Game-icon fallback. If /pui diag finds that our atlases did not load on this client (or the user picks
    "Game icons" on Tools > Diagnostics), glyphs are drawn from stock game files instead. Line-art interface
    files keep the theme tint; full-colour spell icons (sidebar and module art) are drawn untinted and zoomed.
    Anything unmapped shows a small neutral dot rather than a broken square. ]]
local B, IC = "Interface\\Buttons\\", "Interface\\Icons\\"
local GAME_LINE = {
    close = B .. "UI-StopButton", check = B .. "UI-CheckBox-Check", search = "Interface\\Common\\UI-Searchbox-Icon",
    reload = B .. "UI-RefreshButton", reset = B .. "UI-RefreshButton", add = B .. "UI-PlusButton-Up",
    ["chevron-right"] = B .. "UI-SpellbookIcon-NextPage-Up", ["chevron-left"] = B .. "UI-SpellbookIcon-PrevPage-Up",
    ["chevron-down"] = B .. "UI-MinusButton-Up", lock = B .. "LockButton-Locked-Up",
    warning = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew", question = "Interface\\Common\\help-i",
}
local GAME_ART = {
    home = "INV_Misc_Rune_01", general = "INV_Misc_Gear_01", theme = "INV_Misc_Gem_Variety_01",
    unitframes = "Achievement_Character_Human_Male", groupframes = "Achievement_GuildPerk_EverybodysFriend",
    nameplates = "Ability_Hunter_MarkedForDeath", actionbars = "INV_Misc_Book_09", cooldowntext = "INV_Misc_PocketWatch_01",
    ["cat-combat"] = "Ability_Warrior_BattleShout", castbars = "Spell_Nature_Lightning", auras = "Spell_Holy_PowerWordShield",
    combattext = "Spell_Fire_Fireball02", spellhistory = "Spell_Arcane_TeleportDalaran", damagemeter = "Ability_Warrior_Rampage",
    mythicplus = "INV_Relics_Hourglass", pvp = "Achievement_BG_winWSG", chat = "INV_Letter_15", afk = "Spell_Nature_Sleep",
    maps = "INV_Misc_Map_01", minimap = "INV_Misc_Map02", datatexts = "INV_Misc_Note_01", tooltip = "INV_Misc_Note_05",
    itemlevel = "INV_Chest_Plate04", quality = "INV_Misc_EngGizmos_30", automation = "INV_Gizmo_02",
    skins = "INV_Fabric_Silk_02", ["cat-utility"] = "Trade_Engineering", movers = "Ability_Rogue_Sprint",
    profiles = "INV_Misc_Book_11", bugs = "INV_Misc_Bugsprayer", diagnostics = "INV_Misc_Spyglass_03",
    about = "INV_Misc_Book_07", fonts = "INV_Inscription_Scroll", textures = "INV_Fabric_Linen_01",
    sound = "INV_Misc_Bell_01", tracker = "INV_Misc_PocketWatch_02", presets = "INV_Enchant_ShardBrilliantLarge",
}
local GAME_DOT = "Interface\\Common\\Indicator-Gray"
I.game = false

local function gameIcon(name)
    if GAME_LINE[name] then return GAME_LINE[name], false end
    if GAME_ART[name] then return IC .. GAME_ART[name], true end
    return GAME_DOT, false
end

local function physicalPixels(tex, size)
    local parent = tex:GetParent()
    local scale = parent and parent:GetEffectiveScale() or UIParent:GetEffectiveScale()
    return size * scale / PixelUtil.GetPixelToUIUnitFactor()
end

local function tierFor(px)
    for _, t in ipairs(D.tiers) do
        if t.cell >= px then return t end
    end
    return D.tiers[#D.tiers]
end

local function texCoords(t, index)
    local col, row = (index - 1) % D.cols, math.floor((index - 1) / D.cols)
    local g = t.gutter
    return (col * t.cell + g) / t.width, ((col + 1) * t.cell - g) / t.width,
        (row * t.cell + g) / t.height, ((row + 1) * t.cell - g) / t.height
end

local function indexOf(name)
    local index = D.index[name]
    if index then return index end
    I.missing[tostring(name)] = true
    ns:Debug("unknown icon %s", tostring(name))
    return D.index[I.FALLBACK]
end

local function paint(tex, s)
    local token = (s.state and STATE_TOKEN[s.state]) or s.token or "text.secondary"
    local r, g, b, a = Theme:Color(token)
    if s.art then r, g, b = 1, 1, 1 end -- full-colour game art is not tinted
    local alpha = s.alpha or a
    if s.state == "disabled" then alpha = alpha * 0.6 end
    tex:SetVertexColor(r, g, b, alpha)
end

local function state(tex)
    local s = tracked[tex]
    if not s then s = {}; tracked[tex] = s end
    return s
end

function I:Has(name)
    return D.index[name] ~= nil
end

-- True for textures showing a tintable glyph (W.Color routes those through Tint so theme refreshes agree).
function I:Owns(tex)
    local s = tracked[tex]
    return s ~= nil and s.name ~= nil
end

function I:Apply(tex, name, size)
    local s = state(tex)
    s.name = name
    s.size = size or s.size or tex:GetWidth()
    if s.size <= 0 then s.size = 16 end
    if I.game then
        local file, art = gameIcon(name)
        s.tier, s.art = nil, art
        tex:SetTexture(file)
        if art then tex:SetTexCoord(0.08, 0.92, 0.08, 0.92) else tex:SetTexCoord(0, 1, 0, 1) end
        indexOf(name) -- still records unknown names
        return
    end
    s.art = nil
    local t = tierFor(physicalPixels(tex, s.size))
    s.tier = t
    tex:SetTexture(DIR .. t.file)
    tex:SetTexCoord(texCoords(t, indexOf(name)))
end

-- Read-only view of every tracked texture (texture -> state) for /pui diag.
function I:Tracked() return tracked end

-- Atlas currently used by a texture (file name, cell size); for diagnostics and the smoke test.
function I:GetTier(tex)
    local s = tracked[tex]
    if s and s.tier then return s.tier.file, s.tier.cell end
end

function I:Tint(tex, token, alpha)
    local s = state(tex)
    s.token, s.alpha = token, alpha
    paint(tex, s)
end

function I:SetState(tex, st)
    local s = state(tex)
    s.state = st ~= "normal" and st or nil
    paint(tex, s)
end

function I:Create(parent, name, size, token, layer, sublevel)
    size = size or 16
    local tex = parent:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 0)
    tex:SetSize(size, size)
    self:Apply(tex, name, size)
    self:Tint(tex, token or "text.secondary")
    return tex
end

-- Inline icon for FontStrings, e.g. the data bar. Uses the tier for `size` at the current UI scale.
function I:Markup(name, size, token)
    if I.game then return ("|T%s:%d:%d|t"):format((gameIcon(name)), size, size) end
    local t = tierFor(size * UIParent:GetEffectiveScale() / PixelUtil.GetPixelToUIUnitFactor())
    local index = indexOf(name)
    local col, row = (index - 1) % D.cols, math.floor((index - 1) / D.cols)
    local g = t.gutter
    local r, gr, b = Theme:Color(token or "text.secondary")
    return ("|T%s%s:%d:%d:0:0:%d:%d:%d:%d:%d:%d:%d:%d:%d|t"):format(DIR, t.file, size, size, t.width, t.height,
        col * t.cell + g, (col + 1) * t.cell - g, row * t.cell + g, (row + 1) * t.cell - g,
        math.floor(r * 255 + 0.5), math.floor(gr * 255 + 0.5), math.floor(b * 255 + 0.5))
end

-- Coloured brand art (not tinted). width is the on-screen width in UI units.
function I:Brand(tex, kind, width)
    local s = state(tex)
    s.brand, s.width = kind, width
    local px = physicalPixels(tex, width)
    local list = BRAND[kind]
    local pick = list[#list]
    for _, entry in ipairs(list) do
        if entry.px >= px then pick = entry; break end
    end
    tex:SetTexture(ns.C.TEXTURES .. pick.file)
    tex:SetTexCoord(0, 1, 0, 1)
end

local function refreshAll()
    for tex, s in pairs(tracked) do
        if s.brand then
            I:Brand(tex, s.brand, s.width)
        elseif s.name then
            I:Apply(tex, s.name, s.size)
            paint(tex, s)
        end
    end
end
ns.Events:Listen("PUI_THEME_CHANGED", I, refreshAll)

--[[ Icon source: PhoenixUIDB.global.icons = "auto" (default) | "phoenix" | "game". Automatic uses the game
    icons only when the latest /pui diag of this version found an icon atlas that did not load. ]]
function I:Source()
    local g = ns.DB and ns.DB.sv and ns.DB.sv.global
    local v = g and g.icons
    return (v == "phoenix" or v == "game") and v or "auto"
end

function I:AtlasFailed()
    local d = ns.DB and ns.DB.sv and ns.DB.sv.global.diag
    if type(d) ~= "table" or d.version ~= ns.version or type(d.media) ~= "table" then return false end
    for _, r in ipairs(d.media) do
        if r.kind == "icons" and not r.ok then return true end
    end
    return false
end

function I:UpdateSource()
    local src = self:Source()
    local game = src == "game" or (src == "auto" and self:AtlasFailed())
    if game ~= I.game then
        I.game = game
        refreshAll()
    end
    return game
end

function I:SetSource(v)
    ns.DB.sv.global.icons = (v == "phoenix" or v == "game") and v or nil
    return self:UpdateSource()
end

ns.Events:On("PLAYER_LOGIN", I, function() I:UpdateSource() end)
ns.Events:Listen("PUI_DIAG_DONE", I, function() I:UpdateSource() end)
ns.Events:On("UI_SCALE_CHANGED", I, refreshAll)
ns.Events:On("DISPLAY_SIZE_CHANGED", I, refreshAll)
