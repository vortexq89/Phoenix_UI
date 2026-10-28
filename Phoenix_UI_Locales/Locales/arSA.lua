local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- arSA translations (optional language). There is no Arabic WoW client, so
-- Arabic is chosen in Phoenix settings (Language -> Arabic) and never by Auto.
-- The game's text engine does not join Arabic letters or reorder right-to-left
-- runs; Arabic text needs a font with Arabic glyphs (Media font setting). The
-- first pass covers module names and core labels (draft, needs native review);
-- any string not listed falls back to English.
PUI.Locale:Add("arSA", {
  ["Action bars"] = "أشرطة الأوامر",
  ["Chat"] = "الدردشة",
  ["Click-casting"] = "الإلقاء بالنقر",
  ["Cooldown manager"] = "مدير فترات التهدئة",
  ["Data bars"] = "أشرطة البيانات",
  ["Group Finder"] = "باحث المجموعات",
  ["Language"] = "اللغة",
  ["Loadouts"] = "التجهيزات",
  ["Minimap"] = "الخريطة المصغرة",
  ["Nameplates"] = "لوحات الأسماء",
  ["Options mode"] = "وضع الخيارات",
  ["Quest Tracker"] = "متتبع المهام",
  ["Raid and party frames"] = "إطارات الغارة والمجموعة",
  ["Reminders"] = "التذكيرات",
  ["Resource bars"] = "أشرطة الموارد",
  ["Skins"] = "الأشكال",
  ["Tooltip"] = "التلميح",
  ["Unit frames"] = "إطارات الوحدات",
})
