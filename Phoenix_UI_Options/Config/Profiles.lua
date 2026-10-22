local _, ns = ...
local L = ns.L
local W, Skin = ns.Widgets, ns.Skin
local Config = ns.Config
local DB, Profiles = ns.DB, ns.Profiles

--[[ Profiles page: switch / create / rename / delete, per-spec auto switching, export & import.
    Rendered through the schema renderer with a module-like page object. ]]
local page = { key = "profiles", label = "PROFILES", desc = "PROFILES_DESC", icon = "profiles", locked = true, db = {} }
local NONE = "\0none"

-- Danger buttons need a second click within 3 s.
local function confirmButton(row, label, action, icon)
    local b = W:Button(row, label, "danger", icon, 120)
    b.onClick = function(self)
        if self.armed then
            self.armed = nil
            self:SetText(label)
            action()
        else
            self.armed = true
            self:SetText(L.CONFIRM)
            C_Timer.After(3, function()
                if self.armed then self.armed = nil; self:SetText(label) end
            end)
        end
    end
    return b
end

local function nameAndButton(row, buttonLabel, onSubmit, icon)
    local holder = CreateFrame("Frame", nil, row)
    holder:SetSize(W.CONTROL_WIDTH + 96, 28)
    local input = W:Input(holder, W.CONTROL_WIDTH - 8, L.PROFILE_NAME)
    input:SetPoint("LEFT")
    local b = W:Button(holder, buttonLabel, "secondary", icon, 96)
    b:SetPoint("LEFT", input, "RIGHT", 8, 0)
    local function submit()
        local name = strtrim(input:GetText() or "")
        if name ~= "" and onSubmit(name) then
            input:SetValue("")
            input:ClearFocus()
        else
            Config:SetStatus(L.PROFILE_NAME_INVALID, "state.danger")
        end
    end
    b.onClick = submit
    input.onChange = submit
    return holder
end

local function profileValues(includeNone, excludeActive)
    local out = {}
    if includeNone then out[1] = { value = NONE, label = L.NONE, icon = "close" } end
    for _, name in ipairs(DB:GetProfiles()) do
        if not (excludeActive and name == DB:GetProfileName()) then out[#out + 1] = { value = name, label = name, icon = "user" } end
    end
    return out
end

local deleteTarget
local exportBox, importBox, importStatus, importName, pending

local function buildSchema()
    local schema = {
        { type = "header", label = "ACTIVE_PROFILE", icon = "profiles" },
        { type = "select", label = "PROFILE", desc = "PROFILE_DESC", values = function() return profileValues() end,
          get = function() return DB:GetProfileName() end, set = function(_, v) DB:SetProfile(v) end },
        { type = "custom", label = "PROFILE_NEW", desc = "PROFILE_NEW_DESC", build = function(row)
            return nameAndButton(row, L.CREATE, function(name)
                if not DB:NewProfile(name) then return false end
                DB:SetProfile(name)
                return true
            end, "add")
        end },
        { type = "custom", label = "PROFILE_COPY", desc = "PROFILE_COPY_DESC", build = function(row)
            return nameAndButton(row, L.DUPLICATE, function(name)
                if not DB:NewProfile(name, DB:GetProfileName()) then return false end
                DB:SetProfile(name)
                return true
            end, "duplicate")
        end },
        { type = "custom", label = "PROFILE_RENAME", desc = "PROFILE_RENAME_DESC", build = function(row)
            return nameAndButton(row, L.RENAME, function(name) return DB:RenameProfile(DB:GetProfileName(), name) end, "rename")
        end },
        { type = "custom", label = "PROFILE_RESET", desc = "PROFILE_RESET_DESC", build = function(row)
            return confirmButton(row, L.RESET, function()
                DB:ResetProfile()
                Config:SetStatus(L.PROFILE_RESET_DONE, "state.success")
            end, "reset")
        end },
        { type = "select", label = "PROFILE_DELETE", desc = "PROFILE_DELETE_DESC", values = function() return profileValues(true, true) end,
          get = function() return deleteTarget or NONE end, set = function(_, v) deleteTarget = (v ~= NONE) and v or nil end },
        { type = "custom", label = "", build = function(row)
            return confirmButton(row, L.DELETE, function()
                if deleteTarget and DB:DeleteProfile(deleteTarget) then
                    Config:SetStatus(L.PROFILE_DELETED:format(deleteTarget), "state.success")
                    deleteTarget = nil
                    ns.Events:Fire("PUI_PROFILE_CHANGED", DB:GetProfileName())
                end
            end, "delete")
        end },
    }

    -- per-spec profiles, where this character can choose a specialization (ns.FEATURES.specSelection)
    local _, _, classID = UnitClass("player")
    local specs = ns:Supports("specSelection") and classID and C_SpecializationInfo.GetNumSpecializationsForClassID(classID) or 0
    if specs > 0 then
        schema[#schema + 1] = { type = "header", label = "SPEC_PROFILES", icon = "spec" }
        schema[#schema + 1] = { type = "toggle", label = "SPEC_PROFILES_ENABLE", desc = "SPEC_PROFILES_ENABLE_DESC",
            get = function() return DB:GetSpecProfiles().enabled end, set = function(_, v) DB:GetSpecProfiles().enabled = v end }
    end
    for spec = 1, specs do
        local _, specName = C_SpecializationInfo.GetSpecializationInfo(spec)
        schema[#schema + 1] = {
            type = "select", label = specName or ("#" .. spec),
            values = function() return profileValues(true) end,
            disabled = function() return not DB:GetSpecProfiles().enabled end,
            get = function() return DB:GetSpecProfiles()[spec] or NONE end,
            set = function(_, v) DB:GetSpecProfiles()[spec] = (v ~= NONE) and v or nil end,
        }
    end

    local rest = {
        { type = "header", label = "EXPORT", icon = "export" },
        { type = "custom", label = "EXPORT_STRING", desc = "EXPORT_DESC", build = function(row)
            local b = W:Button(row, L.GENERATE, "primary", "export", 140)
            b.onClick = function()
                exportBox:SetValue(Profiles:Export())
                exportBox.edit:SetFocus()
                exportBox.edit:HighlightText()
                Config:SetStatus(L.EXPORT_READY, "state.success")
            end
            return b
        end },
        { type = "custom", label = "", fullWidth = true, height = 120, build = function(row)
            exportBox = W:TextArea(row, 600, 80)
            exportBox.edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
            return exportBox
        end },
        { type = "header", label = "IMPORT", icon = "import" },
        { type = "custom", label = "IMPORT_STRING", desc = "IMPORT_DESC", fullWidth = true, height = 160, build = function(row)
            importBox = W:TextArea(row, 600, 90)
            importBox.edit:HookScript("OnTextChanged", function(_, user)
                if not user then return end
                local payload, err = Profiles:Decode(importBox:GetValue())
                pending = payload
                if not payload then
                    importStatus:SetText(importBox:GetValue() == "" and "" or ns.Theme:Wrap(L[err], "state.danger"))
                else
                    local parts = {}
                    for _, e in ipairs(Profiles:Summarize(payload)) do parts[#parts + 1] = e.label end
                    importStatus:SetText(ns.Theme:Wrap(L.IMPORT_PREVIEW:format(tostring(payload.name), #parts), "state.success")
                        .. "\n" .. table.concat(parts, ", "))
                    if importName:GetText() == "" and type(payload.name) == "string" then importName:SetValue(payload.name) end
                end
            end)
            return importBox
        end },
        { type = "custom", label = "IMPORT_AS", height = 72, build = function(row)
            local holder = CreateFrame("Frame", nil, row)
            holder:SetSize(W.CONTROL_WIDTH + 124, 28)
            importName = W:Input(holder, W.CONTROL_WIDTH, L.PROFILE_NAME)
            importName:SetPoint("LEFT")
            local b = W:Button(holder, L.IMPORT, "primary", "import", 116)
            b:SetPoint("LEFT", importName, "RIGHT", 8, 0)
            b.onClick = function()
                if not pending then
                    Config:SetStatus(L.IMPORT_ERR_EMPTY, "state.danger")
                    return
                end
                local name = Profiles:Import(pending, strtrim(importName:GetText() or ""))
                pending = nil
                importBox:SetValue("")
                importName:SetValue("")
                importStatus:SetText("")
                Config:SetStatus(L.IMPORT_DONE:format(name), "state.success")
            end
            row.label:ClearAllPoints()
            row.label:SetPoint("TOPLEFT", 16, -12)
            importStatus = W.Text(row, "desc", "text.secondary")
            importStatus:SetWordWrap(true)
            importStatus:SetMaxLines(3)
            importStatus:SetJustifyV("TOP")
            importStatus:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -6)
            importStatus:SetPoint("RIGHT", row, "RIGHT", -(W.CONTROL_WIDTH + 160), 0)
            Skin:Register(importStatus, function(fs) Skin:Text(fs, "desc", "text.secondary") end)
            return holder
        end },
    }
    for _, item in ipairs(rest) do schema[#schema + 1] = item end
    return schema
end

-- one schema for the page and for search, so a search result focuses the very row it names
local schema
local function getSchema()
    schema = schema or buildSchema()
    return schema
end

Config:RegisterPage("profiles", function(parent)
    return Config.BuildSchemaPage(parent, page, getSchema())
end, { label = page.label, icon = page.icon, object = page, schema = getSchema })
