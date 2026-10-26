local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- koKR translations (PUI_V2 5.17). Keys are the English strings Phoenix renders
-- (/pui loc lists coverage; .tools/locales.py writes ../keys.txt). Any
-- string not listed here falls back to English. First pass covers module
-- names and core labels (draft, needs native review); the rest is open to
-- data-pack style pull requests that touch only this file.
PUI.Locale:Add("koKR", {
  ["Action bars"] = "행동 단축바",
  ["Chat"] = "대화",
  ["Click-casting"] = "클릭 시전",
  ["Cooldown manager"] = "재사용 대기시간 관리자",
  ["Data bars"] = "정보 바",
  ["Group Finder"] = "파티 찾기",
  ["Language"] = "언어",
  ["Loadouts"] = "구성",
  ["Minimap"] = "미니맵",
  ["Nameplates"] = "이름표",
  ["Options mode"] = "설정 모드",
  ["Quest Tracker"] = "퀘스트 추적기",
  ["Raid and party frames"] = "공격대 및 파티 창",
  ["Reminders"] = "알림",
  ["Resource bars"] = "자원 바",
  ["Skins"] = "스킨",
  ["Tooltip"] = "툴팁",
  ["Unit frames"] = "유닛 프레임",
})
