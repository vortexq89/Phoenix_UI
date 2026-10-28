local _, ns = ...
local M = ns:GetModule("Skins")

--[[ Mail, skins plan window 18: inbox rows as Phoenix rows (cash-on-delivery mail with a danger-coloured bar),
    the send form on a sunken card, Send / Open all / Reply as primary buttons. Attachment icons are the
    game's own; taking, sending and returning stay Blizzard's clicks.
    Live both ways with its Skins switch, repainted on theme change (kit rows / cards). ]]

local function on() return M:IsEnabled() and M.db.mail and true or false end

-- Inbox rows: COD mail outlined in the danger colour (plain boolean from GetInboxHeaderInfo).
function M.MailRowToken(hasCOD) return hasCOD and "state.danger" or nil end

function M:SkinMail()
    if not _G.MailFrame then return end
    local isOn = on()
    local page = (_G.InboxFrame and rawget(_G.InboxFrame, "pageNum")) or 1
    for i = 1, 7 do
        local row = _G["MailItem" .. i]
        M.KitRow(row, isOn, { alpha = 0.45 })
        if row and isOn and GetInboxHeaderInfo then
            local index = (page - 1) * 7 + i
            local cod = select(6, GetInboxHeaderInfo(index))
            local tok = M.MailRowToken(type(cod) == "number" and cod > 0)
            if tok then
                local r, g, b = ns.Theme:Color(tok)
                M.KitRow(row, true, { alpha = 0.45, bar = true, barColor = { r = r, g = g, b = b } })
            end
        end
    end
    M.KitCard(_G.SendMailFrame, isOn, "sunken", false)
    M.SkinPopupButton(_G.SendMailMailButton, "primary", isOn)
    M.SkinPopupButton(_G.SendMailCancelButton, "secondary", isOn)
    M.SkinPopupButton(_G.OpenAllMail, "primary", isOn)
    M.SkinPopupButton(_G.OpenMailReplyButton, "primary", isOn)
end

local mailHooked
function M:SetupMail()
    self:SkinMail()
    local root = _G.MailFrame
    if mailHooked or not root then return end
    mailHooked = true
    root:HookScript("OnShow", function() M:SkinMail() end)
end
M.SETUPS[#M.SETUPS + 1] = "SetupMail"
M.RESKINS[#M.RESKINS + 1] = "SkinMail"
