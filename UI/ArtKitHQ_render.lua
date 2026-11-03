-- Copyright (c) 2026 VortexQ8 (ABDULRAHMAN ALYOUSEF). All rights reserved. See Media/LICENSE.md.
local _, ns = ...
local A = ns.Art
local H = ns.ArtHQ
-- settings shim: helpers read A.db.<key>; keys live in General.db.art (see V11_HANDOFF.md §5)
A.db = setmetatable({}, { __index = function(_, k)
  local g = ns.modules and ns.modules.General and ns.modules.General.db
  return g and g.art and g.art[k]
end })
-- HQ_RENDER_CHANGES.lua  (v10, handoff only; not applied to the repo)
-- © 2026 VortexQ8 / ABDULRAHMAN ALYOUSEF · Phoenix UI · All rights reserved
-- Copy the media to Media/Art/:  H.PhoenixUI_HQ.blp (2048x2048 BGRA, 12 mips) and H.PhoenixUI_LogoHQ.blp (512x512, 10 mips).
-- The .tga twins exist for tools; prefer the .blp (it carries the mip chain; TGA has none).
-- Texcoords in atlas.lua H.PhoenixUI_HQ are already half-texel inset; 9-slice margins are in atlas texels.

local ADDON_ART = "Interface\\AddOns\\Phoenix_UI\\Media\\Art\\"
-- (A is ns.Art, see top)

-- 1) New texture paths (add to ArtKit KIT tables)
A.HQ = {
    file  = ADDON_ART .. "PhoenixUI_HQ",
    logo  = ADDON_ART .. "PhoenixUI_LogoHQ",   -- replaces PhoenixUILogo for the GUI header (black background, centred)
    size  = 2048,
}

-- 2) One helper every PaintKit/Dress path goes through (replaces the bare tex:SetTexture at ArtKit.lua:247)
--    painted = true for painted rims/rings/icons; false for 1 px lines / pixel borders.
function A:SetHQTexture(tex, file, painted)
    tex:SetTexture(file, "CLAMP", "CLAMP", "TRILINEAR")       -- 4th arg = filter mode; uses the BLP mip chain
    if painted then
        if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
        if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
    else
        if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(true) end
        if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(1) end
    end
end

-- 3) Size tiers: choose the detailed or small piece by PHYSICAL pixels (same rule as Core/Icons.lua:94)
local function physical(tex, size)
    local p = tex:GetParent()
    local s = (p and p:GetEffectiveScale()) or UIParent:GetEffectiveScale()
    return size * s / PixelUtil.GetPixelToUIUnitFactor()
end
local SMALL = { action_normal = "action_s", stance_normal = "action_s", ring_player = "ring_s",
                crest_elite = "crest_elite_s", crest_rare = "crest_rare_s", crest_boss = "crest_boss_s",
                aura_border = "aura_border_s" }
local SMALL_BELOW = { action_normal = 48, stance_normal = 48, ring_player = 48, crest_elite = 32,
                      crest_rare = 32, crest_boss = 32, aura_border = 24 }
function A:HQKey(tex, key, size)
    local lim = SMALL_BELOW[key]
    if lim and physical(tex, size) < lim then return SMALL[key] end
    return key
end

-- 4) Paint (atlas.lua H.PhoenixUI_HQ entries). 9-slice margins scale with drawn height / texture height.
function A:PaintHQ(tex, key, drawW, drawH)
    local atlas = H.PhoenixUI_HQ
    key = self:HQKey(tex, key, math.min(drawW or 64, drawH or 64))
    local p = atlas[key]; if not p then return false end
    self:SetHQTexture(tex, atlas.file, true)
    tex:SetTexCoord(p.coords[1], p.coords[2], p.coords[3], p.coords[4])
    if p.top and tex.SetTextureSliceMargins then
        local k = (drawH or p.h) / p.h                          -- e.g. 26 px bar / 96 px strip = 0.27
        tex:SetTextureSliceMargins(p.left * k, p.top * k, p.right * k, p.bottom * k)
        if tex.SetTextureSliceMode then tex:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched) end
    end
    return true
end

-- 5) Usage
-- Player ring:   A:PaintHQ(f.ring, "ring_player", 96, 96)       target: ring_elite / ring_rare / ring_rareelite / ring_boss
-- Action button: A:PaintHQ(btn.PhoenixBorder, "action_normal", btn:GetWidth(), btn:GetHeight())   (inset = 16% of size)
-- Aura border:   A:PaintHQ(aura.border, "aura_border", 26, 26); aura.border:SetVertexColor(r, g, b)  -- debuff colour
-- Bars / cast / nameplate / DataTexts: A:PaintHQ(bar.frame, "bar_frame", w + 8, h + 8)  + caps "bar_cap_l"/"bar_cap_r"
-- Crests:        A:PaintHQ(np.crest, "crest_elite", 18, 18)      -- auto-picks crest_elite_s under 32 physical px
-- Logo:          A:SetHQTexture(header.logo, A.HQ.logo, true); header.logo:SetSize(96, 96)

-- ===== v10.1: border.style = "class" =====
-- Media: Media/Art/Class/H.PhoenixUI_Class_<CLASSFILE>.blp (1024x512 BGRA, 11 mips). atlas.lua: H.PhoenixUI_Class[CLASSFILE].
-- Only the needed classes are touched; the client loads a texture on first SetTexture, so default = the player's class only.
function A:ClassKit(unit)               -- unit = "player" by default; pass a unit for per-unit class kits (db.border.perUnitClass)
    local _, classFile = UnitClass(unit or "player")
    return classFile and H.PhoenixUI_Class[classFile]
end
-- piece = "square" | "ring" | "crest" | "bar" | "cap_l" | "cap_r"; small tier "<piece>_s" picked by physical px (bar_s for bars < 16 px tall)
function A:PaintClass(tex, piece, drawW, drawH, unit)
    local kit = self:ClassKit(unit); if not kit then return false end
    local small = (piece == "bar") and (physical(tex, drawH) < 16) or (piece ~= "bar" and physical(tex, math.min(drawW, drawH)) < 48)
    local p = kit[small and kit[piece .. "_s"] and (piece .. "_s") or piece]; if not p then return false end
    self:SetHQTexture(tex, kit.file, true)
    tex:SetTexCoord(p.coords[1], p.coords[2], p.coords[3], p.coords[4])
    if p.left and tex.SetTextureSliceMargins then
        local k = drawH / p.h
        tex:SetTextureSliceMargins(p.left * k, p.top * k, p.right * k, p.bottom * k)
        if tex.SetTextureSliceMode then tex:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched) end
    end
    return true, p
end

-- Ring/border centre offsets (fixes the off-centre rare ring): every ring/square entry carries center = { dx, dy }
-- (fraction of the piece size; opening centre minus piece centre). Shift the ART, not the portrait:
function A:PlaceCentred(tex, anchor, p, w, h)
    local c = p.center or { 0, 0 }
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", anchor, "CENTER", -c[1] * w, c[2] * h)   -- WoW y is up; image y is down
    tex:SetSize(w, h)
end
-- Example: local ok, p = A:PaintClass(f.ring, "ring", 96, 96); if ok then A:PlaceCentred(f.ring, f.portrait, p, 96, 96) end
-- HQ / Borders rings use the same field: A:PlaceCentred(tex, portrait, H.PhoenixUI_HQ.ring_rare, 96, 96)

-- ===== v10.2: layered borders, crisp small tiers, pixel-perfect sizing =====
-- Media: Media/Art/H.PhoenixUI_Small_v102.blp (all 14 kits' hand-tuned small tiers + layers + 1 px outlines)
--        Media/Art/Layers/H.PhoenixUI_Layers_<KIT>.blp (detailed .rim/.shade/.glow; KIT = EMBER or CLASSFILE)
-- atlas.lua: H.PhoenixUI_Small_v102["<KIT>.<piece>_s[.rim|.shade|.glow|.outline]"], H.PhoenixUI_Layers_v102.<KIT>["<KIT>.<piece>.rim|.shade|.glow"]

-- Pixel-perfect helpers: sizes/offsets that land on whole SCREEN pixels for the frame's effective scale.
local function PxUnit(frame)          -- UI units per physical pixel for this frame
    return PixelUtil.GetPixelToUIUnitFactor() / frame:GetEffectiveScale()
end
function A:PixelSnap(frame, v)        -- round a UI-unit value to whole physical pixels
    local u = PxUnit(frame); return math.floor(v / u + 0.5) * u
end
function A:SetPixelSize(region, w, h)
    region:SetSize(self:PixelSnap(region, w), self:PixelSnap(region, h))
end
function A:SetPixelPoint(region, point, rel, relPoint, x, y)
    region:SetPoint(point, rel, relPoint, self:PixelSnap(region, x or 0), self:PixelSnap(region, y or 0))
end

-- Layered paint. Creates/reuses 4 textures on `holder`: glow (BACKGROUND), rim (BORDER), shade (BORDER+1), outline (OVERLAY).
-- Painted layers: TRILINEAR, snapping OFF. Outline: snapping ON, texel bias 1, NEAREST-like crispness at exact size.
-- db.border.layers == false  -> falls back to the single combined piece (v10.1 / v10.2 combined).
local LAYER_ORDER = { { "glow", "BACKGROUND", 0 }, { "rim", "BORDER", 0 }, { "shade", "BORDER", 1 }, { "outline", "OVERLAY", 7 } }
function A:PaintLayered(holder, kit, piece, w, h, opts)
    opts = opts or {}
    holder.__pl = holder.__pl or {}
    local small = physical(holder, math.min(w, h)) < 48
    local atlas, base
    if small then atlas, base = H.PhoenixUI_Small_v102, kit .. "." .. piece .. "_s"
    else atlas, base = H.PhoenixUI_Layers_v102[kit], kit .. "." .. piece end
    if not atlas then return false end
    if opts.layers == false or not atlas[base .. ".rim"] then        -- combined fallback
        local t = holder.__pl.combined or holder:CreateTexture(nil, "BORDER"); holder.__pl.combined = t
        local p = small and atlas[base] or (H.PhoenixUI_Class[kit] and H.PhoenixUI_Class[kit][piece]) or H.PhoenixUI_HQ[piece]
        if not p then return false end
        self:SetHQTexture(t, (small and atlas.file) or (H.PhoenixUI_Class[kit] and H.PhoenixUI_Class[kit].file) or H.PhoenixUI_HQ.file, true)
        t:SetTexCoord(unpack(p.coords)); t:SetAllPoints(holder); t:Show(); return true
    end
    self:SetPixelSize(holder, w, h)
    for _, L in ipairs(LAYER_ORDER) do
        local name, layer, sub = L[1], L[2], L[3]
        local p = atlas[base .. "." .. name]
        local t = holder.__pl[name]
        if p then
            t = t or holder:CreateTexture(nil, layer, nil, sub); holder.__pl[name] = t
            local painted = (name ~= "outline")
            self:SetHQTexture(t, atlas.file, painted)               -- snapping only for the outline
            t:SetTexCoord(p.coords[1], p.coords[2], p.coords[3], p.coords[4])
            t:ClearAllPoints(); t:SetAllPoints(holder)
            if name == "glow" then t:SetBlendMode(p.blend == "ADD" and "ADD" or "BLEND") end
            if name == "outline" then t:SetVertexColor(0, 0, 0, 1) end
            if name == "shade" then t:SetVertexColor(1, 1, 1, opts.shade or 1) end
            if name == "glow" and opts.glowColor then t:SetVertexColor(unpack(opts.glowColor)) end
            t:SetShown(name ~= "glow" or opts.glow ~= false)
        elseif t then t:Hide() end
    end
    if holder.__pl.combined then holder.__pl.combined:Hide() end
    return true
end
-- Example: A:PaintLayered(btn.PhoenixBorder, "MAGE", "square", 36, 36, { layers = db.border.layers, glow = true })

-- ===================== v10.3: resource themes, pips, elite overlays =====================
-- © 2026 VortexQ8 / ABDULRAHMAN ALYOUSEF · Phoenix UI. Original art; EPF-style layout, no EPF files used.
A.HQ.RES   = "Interface\\AddOns\\Phoenix_UI\\Media\\Art\\v103\\PhoenixUI_Resources"
A.HQ.ELITE = "Interface\\AddOns\\Phoenix_UI\\Media\\Art\\v103\\PhoenixUI_EliteFrames"
local PT = Enum and Enum.PowerType or {}
-- power type -> theme key
A.PowerTheme = {}
for name, key in pairs({ Mana="mana", Rage="rage", Focus="focus", Energy="energy", RunicPower="runic", LunarPower="astral",
    Maelstrom="maelstrom", Insanity="insanity", Fury="fury", Pain="fury" }) do
  if PT and PT[name] then A.PowerTheme[PT[name]] = key end   -- Forever (1.x) lacks most of these: skip nil keys
end
A.PowerColor = { mana={0.20,0.45,1.00}, rage={0.90,0.12,0.10}, energy={1.00,0.85,0.20}, focus={1.00,0.55,0.20},
  runic={0.25,0.85,1.00}, astral={0.35,0.55,1.00}, maelstrom={0.10,0.55,1.00}, insanity={0.60,0.20,0.90}, fury={0.80,0.25,0.95} }
-- specID -> { main theme, secondary pip }   (pip nil = none)
A.SpecResource = {
  [250]={"runic","rune"},[251]={"runic","rune"},[252]={"runic","rune"},             -- Death Knight
  [577]={"fury"},[581]={"fury"},                                                        -- Demon Hunter (add new DH spec IDs here)
  [102]={"astral"},[103]={"energy","combo"},[104]={"rage"},[105]={"mana"},             -- Druid (forms: auto_power follows UnitPowerType)
  [1467]={"mana","essence"},[1468]={"mana","essence"},[1473]={"mana","essence"},       -- Evoker
  [253]={"focus"},[254]={"focus"},[255]={"focus"},                                     -- Hunter
  [62]={"mana","arcane"},[63]={"mana"},[64]={"mana"},                                   -- Mage
  [268]={"energy"},[269]={"energy","chi"},[270]={"mana"},                               -- Monk
  [65]={"mana","holy"},[66]={"mana","holy"},[70]={"mana","holy"},                       -- Paladin
  [256]={"mana"},[257]={"mana"},[258]={"insanity"},                                     -- Priest
  [259]={"energy","combo"},[260]={"energy","combo"},[261]={"energy","combo"},           -- Rogue
  [262]={"maelstrom"},[263]={"mana"},[264]={"mana"},                                    -- Shaman
  [265]={"mana","shard"},[266]={"mana","shard"},[267]={"mana","shard"},                 -- Warlock
  [71]={"rage"},[72]={"rage"},[73]={"rage"},                                            -- Warrior
}
-- resource.style: "auto_power" (default; follows UnitPowerType, so Druid forms switch), "auto_spec", or a fixed theme key
function A.ResourceTheme(unit)
  local st = (A.db.resource and A.db.resource.style) or "auto_power"
  local pt = UnitPowerType(unit)
  if st == "auto_power" or unit ~= "player" then return A.PowerTheme[pt] or "mana", pt end
  if st == "auto_spec" then
    local SI = C_SpecializationInfo
    local i = SI and SI.GetSpecialization and SI.GetSpecialization()
    local id = i and SI.GetSpecializationInfo and SI.GetSpecializationInfo(i)
    local e = id and A.SpecResource[id]; if e then return e[1], pt, e[2] end
    return A.PowerTheme[pt] or "mana", pt
  end
  return st, pt
end
-- bar: StatusBar; frameTex: Texture on an overlay frame
function A.PaintResource(bar, frameTex, unit)
  local key = A.ResourceTheme(unit); local AT = H.PhoenixUI_Resources
  local px = (bar:GetHeight() * bar:GetEffectiveScale()) / PixelUtil.GetPixelToUIUnitFactor()
  local tint = A.db.resource and A.db.resource.tint            -- "preset" (coloured fill) or "power"/"class" (grey + vertex colour)
  local f = AT["fill."..key..(tint and tint~="preset" and ".grey" or "")]
  bar:SetStatusBarTexture(A.HQ.RES); local t = bar:GetStatusBarTexture()
  t:SetTexCoord(unpack(f.coords)); t:SetHorizTile(false)
  if tint == "power" then t:SetVertexColor(unpack(A.PowerColor[key])) elseif tint == "class" then
    local c = C_ClassColor.GetClassColor(select(2, UnitClass(unit))); t:SetVertexColor(c.r, c.g, c.b) else t:SetVertexColor(1,1,1) end
  local fr = AT["frame."..key..(px <= 28 and "_s" or "")]
  frameTex:SetTexture(A.HQ.RES, "CLAMP", "CLAMP", "TRILINEAR"); frameTex:SetTexCoord(unpack(fr.coords))
  local k = bar:GetHeight() / fr.h
  frameTex:SetTextureSliceMargins(fr.slice[1], fr.slice[2], fr.slice[1], fr.slice[2]); frameTex:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
  frameTex:ClearAllPoints(); frameTex:SetPoint("TOPLEFT", bar, -fr.slice[1]*k*0.35, fr.slice[2]*k*0.6); frameTex:SetPoint("BOTTOMRIGHT", bar, fr.slice[1]*k*0.35, -fr.slice[2]*k*0.6)
end
function A.PaintPip(tex, pip, filled)   -- pip = "combo"|"chi"|"holy"|"shard"|"arcane"|"essence"|"rune"; empty socket when not filled
  local px = tex:GetHeight() * tex:GetEffectiveScale() / PixelUtil.GetPixelToUIUnitFactor()
  local e = H.PhoenixUI_Resources["pip."..(filled and pip or "empty")..(px <= 24 and "_s" or "")]
  tex:SetTexture(A.HQ.RES, "CLAMP", "CLAMP", "TRILINEAR"); tex:SetTexCoord(unpack(e.coords))
end
-- ---- elite overlays (EPF-like modes) ----
-- elite.mode: "auto" | "normal" | "silver" | "silver_winged" | "gold" | "gold_winged" | "rare" | "rareelite" | "boss" | registered custom key
A.EliteModes = { silver="ring_rare", gold="ring_elite", rare="ring_rare", rareelite_ring="ring_rareelite", boss_ring="ring_boss",   -- HQ rings (H.PhoenixUI_HQ)
  silver_winged="silver_winged", gold_winged="gold_winged", rareelite="rareelite_winged", boss="boss_winged" }   -- v10.3 overlays
A.CustomElite = {}   -- A.RegisterEliteFrame(key, {file=, coords={l,r,t,b}, w=, h=, hole={cx,cy,d}, auto=function(unit) return bool end})
function A.RegisterEliteFrame(key, def) A.CustomElite[key] = def end
function A.AutoEliteMode(unit)
  for k, d in pairs(A.CustomElite) do if d.auto and d.auto(unit) then return k end end
  if unit == "player" then
    local lvl, max = UnitLevel("player"), GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or 80
    if lvl >= max then return "silver_winged" elseif lvl >= 10 then return "silver" end; return "normal"
  end
  local c = A.Classification(unit)   -- never a secret (ArtKit.lua)
  return ({ worldboss="boss", elite="gold_winged", rareelite="rareelite", rare="silver" })[c] or "normal"
end
-- portrait: the unit's portrait texture; overlay: Texture above it. Target side is mirrored (wing sweeps left).
function A.PaintElite(overlay, portrait, unit)
  local mode = (A.db.elite and A.db.elite.mode ~= "auto" and A.db.elite.mode) or A.AutoEliteMode(unit)
  if mode == "normal" then overlay:Hide(); return end
  local e = A.CustomElite[mode]; local file = e and e.file
  if not e then
    local key = A.EliteModes[mode]
    if key and H.PhoenixUI_EliteFrames[key] then
      local px = portrait:GetWidth() * portrait:GetEffectiveScale() / PixelUtil.GetPixelToUIUnitFactor()
      e = H.PhoenixUI_EliteFrames[key..(px <= 60 and "_s" or "")]; file = A.HQ.ELITE
    else return A.PaintHQ(overlay, key) end     -- plain ring modes reuse the v10 HQ rings
  end
  local mirror = (unit ~= "player"); local l, r, t, b = unpack(e.coords); if mirror then l, r = r, l end
  overlay:SetTexture(file, "CLAMP", "CLAMP", "TRILINEAR"); overlay:SetTexCoord(l, r, t, b)
  local d = portrait:GetWidth() / e.hole[3]; overlay:SetSize(d, d * e.h / e.w)
  local cx = mirror and (1 - e.hole[1]) or e.hole[1]
  overlay:ClearAllPoints(); overlay:SetPoint("CENTER", portrait, "CENTER", (0.5 - cx) * d, (e.hole[2] - 0.5) * d * e.h / e.w); overlay:Show()
end

-- ===================== v11 showcase pass (art upgrade; v10.3 stays as fallback) =====================
-- © 2026 VortexQ8 / ABDULRAHMAN ALYOUSEF · Phoenix UI
A.V11 = {
  root = "Interface\\AddOns\\Phoenix_UI\\Media\\Art\\v11\\",
  elite = { gold="PhoenixUI_Elite_gold", silver="PhoenixUI_Elite_silver", rareelite="PhoenixUI_Elite_rareelite",
            boss="PhoenixUI_Elite_boss", deathknight="PhoenixUI_Elite_deathknight", demonhunter="PhoenixUI_Elite_demonhunter" },
}
-- v11 elite modes ( *_winged keep their v10.3 names; class frames are new, like EPF's DK/DH custom frames )
A.EliteV11 = { gold_winged="gold", silver_winged="silver", rareelite="rareelite", boss="boss", deathknight="deathknight", demonhunter="demonhunter" }
local _AutoElite = A.AutoEliteMode
function A.AutoEliteMode(unit)
  if unit == "player" and (not A.db.elite or A.db.elite.classFrames ~= false) then
    local _, c = UnitClass("player"); if c == "DEATHKNIGHT" then return "deathknight" elseif c == "DEMONHUNTER" then return "demonhunter" end
  end
  return _AutoElite(unit)
end
local _PaintElite = A.PaintElite
function A.PaintElite(overlay, portrait, unit)
  if A.db.version == "v10.3" then return _PaintElite(overlay, portrait, unit) end
  local mode = (A.db.elite and A.db.elite.mode ~= "auto" and A.db.elite.mode) or A.AutoEliteMode(unit)
  local k = A.EliteV11[mode]; if not k then return _PaintElite(overlay, portrait, unit) end
  local px = portrait:GetWidth() * portrait:GetEffectiveScale() / PixelUtil.GetPixelToUIUnitFactor()
  local e, file
  if px <= 90 then e = H.PhoenixUI_EliteSmall_v11[k.."_s"]; file = A.V11.eliteSmallFile or (A.V11.root.."PhoenixUI_EliteSmall_v11")
  else e = H["PhoenixUI_Elite_v11_"..k].frame; file = (k == "boss" and A.V111 and (A.V111.root.."PhoenixUI_Elite_boss_v111")) or (A.V11.root..A.V11.elite[k]) end
  local mirror = (unit ~= "player") and k ~= "boss" and k ~= "deathknight" and k ~= "demonhunter"   -- symmetric frames need no flip
  local l, r, t, b = unpack(e.coords); if mirror then l, r = r, l end
  overlay:SetTexture(file, "CLAMP", "CLAMP", "TRILINEAR"); overlay:SetTexCoord(l, r, t, b)
  -- hole is relative to the piece for _s, relative to the 1024 file for the big frame
  local hx, hy, hd = e.hole[1], e.hole[2], e.hole[3]
  if px > 90 then local x0, y0 = e.coords[1], e.coords[3]; local fw, fh = e.coords[2]-x0, e.coords[4]-y0
    hx, hy, hd = (hx - x0)/fw, (hy - y0)/fh, hd/fw end
  local d = portrait:GetWidth() / hd; overlay:SetSize(d, d * e.h / e.w)
  if mirror then hx = 1 - hx end
  overlay:ClearAllPoints(); overlay:SetPoint("CENTER", portrait, "CENTER", (0.5 - hx) * d, (hy - 0.5) * d * e.h / e.w); overlay:Show()
end
-- resources: v11 atlases; thin bars (<= 14 px) use the calm rage/fury _thin frames
A.HQ.RES_V11_FILLS  = A.V11.root.."PhoenixUI_ResFills_v11"
A.HQ.RES_V11_FRAMES = A.V11.root.."PhoenixUI_ResFrames_v11"
function A.ResFrameKey(key, px)
  if px <= 28 and H.PhoenixUI_ResFrames_v11["frame."..key.."_thin"] then return "frame."..key.."_thin" end
  return "frame."..key..(px <= 28 and "_s" or "")
end

-- ===================== v11.1 polish =====================
-- © 2026 VortexQ8 / ABDULRAHMAN ALYOUSEF · Phoenix UI
-- one frame file per power type: only the player's resource loads (+ a target's when different)
A.V111 = { root = "Interface\\AddOns\\Phoenix_UI\\Media\\Art\\v111\\" }
function A.ResFrameAtlas(key)
  return H["PhoenixUI_ResFrame_v111_"..key], A.V111.root.."PhoenixUI_ResFrame_"..key.."_v111"
end
function A.ResFrameKey(key, px)   -- replaces the v11 version; same keys inside each per-power file
  local AT = A.ResFrameAtlas(key)
  if px <= 28 and AT["frame."..key.."_thin"] then return "frame."..key.."_thin" end
  return "frame."..key..(px <= 28 and "_s" or "")
end
function A.PaintResFrame(frameTex, bar, key)
  local AT, file = A.ResFrameAtlas(key)
  local px = bar:GetHeight() * bar:GetEffectiveScale() / PixelUtil.GetPixelToUIUnitFactor()
  local fr = AT[A.ResFrameKey(key, px)]
  frameTex:SetTexture(file, "CLAMP", "CLAMP", "TRILINEAR"); frameTex:SetTexCoord(unpack(fr.coords))
  local k = bar:GetHeight() / fr.h
  frameTex:SetTextureSliceMargins(fr.slice[1], fr.slice[2], fr.slice[1], fr.slice[2]); frameTex:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
  frameTex:ClearAllPoints(); frameTex:SetPoint("TOPLEFT", bar, -fr.slice[1]*k*0.35, fr.slice[2]*k*0.6); frameTex:SetPoint("BOTTOMRIGHT", bar, fr.slice[1]*k*0.35, -fr.slice[2]*k*0.6)
end
-- brighter boss + Ember: point the v11 tables at the v11.1 files
H.PhoenixUI_Elite_v11_boss = H.PhoenixUI_Elite_v111_boss or H.PhoenixUI_Elite_v11_boss
H.PhoenixUI_EliteSmall_v11 = H.PhoenixUI_EliteSmall_v111 or H.PhoenixUI_EliteSmall_v11   -- same coords; file path below
A.V11.eliteSmallFile = A.V111.root.."PhoenixUI_EliteSmall_v111"
A.V11.emberFile = A.V111.root.."PhoenixUI_Ember_v111"   -- use H.PhoenixUI_Ember_v111 coords

-- ===================== v11 class kits / borders / HUD (v11.2) =====================
A.V11.classFile = function(class) return A.V11.root.."class\\PhoenixUI_Class_"..class.."_v11" end
A.V11.bordersFile = function(style) local B = { ornate_gold=1, shadowflame=1, frost=1, verdant=1, holy=1 }
  return A.V11.root.."hud\\PhoenixUI_Borders_v11_"..(B[style] and "A" or "B"), H["PhoenixUI_Borders_v11_"..(B[style] and "A" or "B")] end
A.V11.hudFile = A.V11.root.."hud\\PhoenixUI_HUD_v11"
-- generic painter for any v11 atlas piece; picks _s / _s36 / _20 style small keys when the drawn size is small
function A:PaintV11(tex, atlas, file, key, drawPx)
  local e = atlas[key]; if not e then return false end
  tex:SetTexture(file, "CLAMP", "CLAMP", "TRILINEAR"); tex:SetTexCoord(unpack(e.coords))
  if e.slice and tex.SetTextureSliceMargins then
    local k = (drawPx or e.h) / e.h; tex:SetTextureSliceMargins(e.slice[1]*k, e.slice[2]*k, e.slice[1]*k, e.slice[2]*k)
    if tex.SetTextureSliceMode then tex:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched) end
  end
  return true
end
function A:ClassKitV11(tex, piece, drawPx, unit)            -- piece = "ring" | "square" | "crest"
  local _, c = UnitClass(unit or "player"); if not c then return false end
  local AT = H["PhoenixUI_Class_v11_"..c]; if not AT then return false end
  local small = { ring = 90, square = 44, crest = 32 }
  local key = (drawPx and drawPx <= (small[piece] or 0)) and piece.."_s" or piece
  return self:PaintV11(tex, AT, A.V11.classFile(c), key, drawPx)
end
function A:BorderStyleV11(tex, style, shape, drawPx)        -- shape = "square" | "ring"
  local file, AT = A.V11.bordersFile(style); if not AT then return false end
  local key = "style_"..style.."_"..shape..((drawPx and drawPx <= 40) and "_s36" or (drawPx and drawPx <= 80) and "_s64" or "")
  return self:PaintV11(tex, AT, file, key, drawPx)
end
function A:HUDIconV11(tex, name, drawPx)                    -- name = time|gold|bugs|fps|ms|menu
  local key = "icon."..name..((drawPx <= 16 and "_16") or (drawPx <= 20 and "_20") or (drawPx <= 32 and "_32") or "")
  return self:PaintV11(tex, H.PhoenixUI_HUD_v11, A.V11.hudFile, key, drawPx)
end

-- ===== v11.2 REST helpers © 2026 VortexQ8 / ABDULRAHMAN ALYOUSEF =====
A.V112 = { root = "Interface\\AddOns\\Phoenix_UI\\Media\\Art\\v112\\" }
A.V112.icons, A.V112.bars, A.V112.panels = A.V112.root.."PhoenixUI_Icons_v112", A.V112.root.."PhoenixUI_ClassBars_v112", A.V112.root.."PhoenixUI_Panels_v112"
-- slice = { left, right, top, bottom } in texels; SetTextureSliceMargins takes (left, top, right, bottom)
function A:PaintV112(tex, atlas, file, key)
  local e = atlas and atlas[key]; if not e then return false end
  tex:SetTexture(file, "CLAMP", "CLAMP", "TRILINEAR"); tex:SetTexCoord(unpack(e.coords))
  if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false); tex:SetTexelSnappingBias(0) end
  if e.slice and tex.SetTextureSliceMargins then
    tex:SetTextureSliceMargins(e.slice[1], e.slice[3], e.slice[2], e.slice[4])
    if tex.SetTextureSliceMode then tex:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched) end
  end
  return true
end
local function tier(px, list) for _, t in ipairs(list) do if px <= t then return t end end end
-- status_* / mod_* icons (same keys as H.PhoenixUI_Icons, plus mod_about): 128 + 32/20/16
function A:IconV112(tex, key, drawPx)
  local t = tier(drawPx or 32, { 16, 20, 32 }); return self:PaintV112(tex, H.PhoenixUI_Icons_v112, A.V112.icons, t and (key.."_"..t) or key)
end
-- class bar 9-slice: <=16 px -> _s16, <=28 -> _s24, else 64 master; caps: "cap_<CLASS>_l|r"
function A:ClassBarV112(tex, drawH, unit, cap)
  local _, c = UnitClass(unit or "player"); if not c then return false end
  if cap then return self:PaintV112(tex, H.PhoenixUI_ClassBars_v112, A.V112.bars, "cap_"..c.."_"..cap) end
  local sfx = (drawH <= 16 and "_s16") or (drawH <= 28 and "_s24") or ""
  return self:PaintV112(tex, H.PhoenixUI_ClassBars_v112, A.V112.bars, "bar_"..c..sfx)
end
-- panels: panel | tooltip | tooltip_s | popup | title_banner | tab | tab_s | micro_bar | chat_frame | chat_frame_s
--         dt_strip | dt_cap_l | dt_cap_r | cast_calm_36 | cast_calm_18 | minimap_ring (+.rim/.glow)
--         border_stance|pet|aura_buff|aura_debuff (+_s36/_s24) | fix_MAGE_square | fix_style_titan_square (+_s..)
function A:PanelV112(tex, key) return self:PaintV112(tex, H.PhoenixUI_Panels_v112, A.V112.panels, key) end
function A:SmallBorderV112(tex, kind, drawPx)                 -- kind = stance|pet|aura_buff|aura_debuff
  local t = tier(drawPx or 36, { 24, 36 }); return self:PanelV112(tex, "border_"..kind..(t and ("_s"..t) or ""))
end
function A:CastCalmV112(tex, h) return self:PanelV112(tex, (h or 18) <= 22 and "cast_calm_18" or "cast_calm_36") end

-- Files the helpers above load by built paths (root .. name), listed so the media check sees them in use.
A.V11.MEDIA = { "PhoenixUI_HUD_v11", "PhoenixUI_EliteFrames",
    "PhoenixUI_ResFrame_mana_v111", "PhoenixUI_ResFrame_rage_v111", "PhoenixUI_ResFrame_energy_v111",
    "PhoenixUI_ResFrame_focus_v111", "PhoenixUI_ResFrame_runic_v111", "PhoenixUI_ResFrame_insanity_v111",
    "PhoenixUI_ResFrame_maelstrom_v111", "PhoenixUI_ResFrame_astral_v111", "PhoenixUI_ResFrame_fury_v111" }
