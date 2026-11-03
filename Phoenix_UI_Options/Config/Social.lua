local _, ns = ...
local Config = ns.Config

--[[ Social (specs/004 T010): friends, guild and group rules in one page instead of three. Every row is owned by
    the module it always belonged to (module = "<key>", the specs/002 row owner), so no saved key moved; rows of
    a module that is not loaded drop out. ]]
local social = { key = "social", label = "SOCIAL", desc = "SOCIAL_DESC", icon = "user", locked = true, db = {}, defaults = {} }
local ROWS = {
    { type = "header", label = "SOCIAL_FRIENDS", icon = "user" },
    { module = "Skins", type = "toggle", key = "ownFriends", label = "FRIENDW_OWN",
      desc = "FRIENDW_OWN_DESC", keywords = "friends social own window" },
    { module = "Skins", type = "toggle", key = "friends", label = "SKINS_FRIENDS", keywords = "social who raid" },
    { type = "header", label = "SOCIAL_TEXTS", icon = "datatexts" },
    { module = "DataTexts", type = "toggle", key = "friends", label = "DT_FRIENDS",
      desc = "DT_FRIENDS_DESC", keywords = "battle.net online" },
    { module = "DataTexts", type = "toggle", key = "guild", label = "DT_GUILD", desc = "DT_GUILD_DESC", keywords = "members online" },
    { type = "header", label = "AUTO_SOCIAL", icon = "user" },
    { module = "Automation", type = "toggle", key = "acceptInvites", label = "AUTO_ACCEPT_INVITES",
      desc = "AUTO_ACCEPT_INVITES_DESC", keywords = "group party" },
    { module = "Automation", type = "toggle", key = "declineDuels", label = "AUTO_DECLINE_DUELS", desc = "AUTO_DECLINE_DUELS_DESC" },
    { module = "Automation", type = "toggle", key = "declinePetDuels", label = "AUTO_DECLINE_PET_DUELS",
      desc = "AUTO_DECLINE_PET_DUELS_DESC",
      keywords = "pet battle duel" },
    { module = "Automation", type = "toggle", key = "declineGuild", label = "AUTO_DECLINE_GUILD", desc = "AUTO_DECLINE_GUILD_DESC",
      keywords = "guild invite spam" },
    { module = "Automation", type = "toggle", key = "acceptResurrect", label = "AUTO_ACCEPT_RES",
      desc = "AUTO_ACCEPT_RES_DESC", keywords = "resurrection" },
}
local cache
local function rows()
    if cache then return cache end
    cache = {}
    for _, item in ipairs(ROWS) do
        if not item.module or ns.modules[item.module] then cache[#cache + 1] = item end
    end
    cache = ns:FilterSchema(cache)
    return cache
end
Config:RegisterPage("social", function(parent)
    local page = Config.BuildSchemaPage(parent, social, rows())
    ns.Events:Listen("PUI_SETTING_CHANGED", page, function()
        if page:IsShown() then for _, row in ipairs(page.rows) do row:Refresh() end end
    end)
    return page
end, { label = social.label, icon = social.icon, object = social, schema = rows })
