-- ###############################################################
-- # Server -> clients: an ingame notification for one farm only #
-- ###############################################################
FabriXNotificationEvent = {}

local FabriXNotificationEvent_mt = Class(FabriXNotificationEvent, Event)

InitEventClass(FabriXNotificationEvent, "FabriXNotificationEvent")

-- notification types are tables in FS25, so only their index in this list goes over the network
local TYPES = {
    FSBaseMission.INGAME_NOTIFICATION_OK,
    FSBaseMission.INGAME_NOTIFICATION_INFO,
    FSBaseMission.INGAME_NOTIFICATION_CRITICAL
}

-- a text is a plain string or { l10nKey, arg1, arg2, ...}; every arg is a text again
local function writeText(streamId, text)
    local isKey = type(text) == "table"
    streamWriteBool(streamId, isKey)

    if not isKey then
        streamWriteString(streamId, tostring(text))
        return
    end

    streamWriteString(streamId, text[1])
    streamWriteUInt8(streamId, #text - 1)
    for i = 2, #text do
        writeText(streamId, text[i])
    end
end

local function readText(streamId)
    if not streamReadBool(streamId) then
        return streamReadString(streamId)
    end

    local text = { streamReadString(streamId) }
    for _ = 1, streamReadUInt8(streamId) do
        table.insert(text, readText(streamId))
    end

    return text
end

function FabriXNotificationEvent.emptyNew()
    return Event.new(FabriXNotificationEvent_mt)
end

function FabriXNotificationEvent.new(farmId, notificationType, text, group)
    local self = FabriXNotificationEvent.emptyNew()
    self.farmId = farmId
    self.notificationType = notificationType
    self.text = text
    self.group = group or 0
    return self
end

function FabriXNotificationEvent:writeStream(streamId, connection)
    streamWriteUIntN(streamId, self.farmId, FarmManager.FARM_ID_SEND_NUM_BITS)

    local index = 2 -- unknown type falls back to INFO

    for i, notificationType in ipairs(TYPES) do
        if notificationType == self.notificationType then
            index = i
            break
        end
    end

    streamWriteUInt8(streamId, index)
    streamWriteUInt8(streamId, self.group)
    writeText(streamId, self.text)
end

function FabriXNotificationEvent:readStream(streamId, connection)
    -- only the server may send the full state
    if not connection:getIsServer() then return end

    self.farmId = streamReadUIntN(streamId, FarmManager.FARM_ID_SEND_NUM_BITS)
    self.notificationType = TYPES[streamReadUInt8(streamId)] or FSBaseMission.INGAME_NOTIFICATION_INFO
    self.group = streamReadUInt8(streamId)
    self.text = readText(streamId)
    self:run(connection)
end

function FabriXNotificationEvent:run(connection)
    if g_currentMission:getFarmId() == self.farmId and FabriX:isNotificationEnabled(self.group) then
        g_currentMission:addIngameNotification(self.notificationType, FabriX:localizeText(self.text))
    end
end

-- server: shows the notification to the host (if it is his farm) and to all clients of that farm
-- group: FabriX.NOTIFY_GROUP, nil = always shown
-- text: { l10nKey, args... } (see localizeText), translated by every receiver
function FabriX:notify(farmId, notificationType, text, group)
    local event = FabriXNotificationEvent.new(farmId, notificationType, text, group)
    event:run()
    if g_server == nil then return end

    for _, connection in pairs(g_server.clientConnections) do
        local userId = g_currentMission.userManager:getUserIdByConnection(connection)
        local farm = userId ~= nil and g_farmManager:getFarmByUserId(userId) or nil

        if farm ~= nil and farm.farmId == farmId and not connection:getIsLocal() then
            connection:sendEvent(event)
        end
    end
end

-- localized on the receiving side, so every player reads his own language
function FabriX:localizeText(text)
    if type(text) ~= "table" then
        return tostring(text)
    end

    local args = {}

    for i = 2, #text do
        args[i - 1] = FabriX:localizeText(text[i])
    end

    if #args == 0 then
        return g_i18n:getText(text[1])
    end

    return string.format(g_i18n:getText(text[1]), unpack(args))
end

-- ---- per-player settings, stored locally in modSettings/FabriX.xml ----
local SETTINGS_PATH = "FabriX.xml"

function FabriX:loadNotificationSettings()
    FabriX.notifySettings = {}
    for _, group in pairs(FabriX.NOTIFY_GROUP) do
        FabriX.notifySettings[group] = true
    end

    local path = g_modSettingsDirectory .. SETTINGS_PATH
    if not fileExists(path) then return end

    local xmlFile = XMLFile.load("fabrixSettings", path)
    if xmlFile == nil then return end
    for key, group in pairs(FabriX.NOTIFY_GROUP) do
        FabriX.notifySettings[group] = xmlFile:getBool("fabrix.notifications#" .. key:lower(), true)
    end
    xmlFile:delete()
end

function FabriX:saveNotificationSettings()
    createFolder(g_modSettingsDirectory)
    local xmlFile = XMLFile.create("fabrixSettings", g_modSettingsDirectory .. SETTINGS_PATH, "fabrix")
    if xmlFile == nil then return end
    for key, group in pairs(FabriX.NOTIFY_GROUP) do
        xmlFile:setBool("fabrix.notifications#" .. key:lower(), FabriX.notifySettings[group])
    end
    xmlFile:save()
    xmlFile:delete()
end

function FabriX:isNotificationEnabled(group)
    if group == nil or group == 0 then return true end
    if FabriX.notifySettings == nil then FabriX:loadNotificationSettings() end
    return FabriX.notifySettings[group] ~= false
end

-- local per-player setting (not synced): switches a notification group on/off and saves it
function FabriX:setNotificationEnabled(group, isOn)
    if FabriX.notifySettings == nil then FabriX:loadNotificationSettings() end
    FabriX.notifySettings[group] = isOn
    FabriX:saveNotificationSettings()
end
