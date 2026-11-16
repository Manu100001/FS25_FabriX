-- ##############################################################
-- # Player actions: a client asks the server to run an action #
-- # (hire, fire, ...); the server checks it and syncs back #
-- ##############################################################

FabriXActionEvent = {}

local FabriXActionEvent_mt = Class(FabriXActionEvent, Event)

InitEventClass(FabriXActionEvent, "FabriXActionEvent")

function FabriXActionEvent.emptyNew() return Event.new(FabriXActionEvent_mt) end

function FabriXActionEvent.new(action, args)
    local self = FabriXActionEvent.emptyNew()
    self.action = action
    self.args = args

    return self
end

function FabriXActionEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.action)
    streamWriteUInt8(streamId, #self.args)

    for _, arg in ipairs(self.args) do
        streamWriteString(streamId, arg)
    end
end

function FabriXActionEvent:readStream(streamId, connection)
    self.action = streamReadString(streamId)
    self.args = {}
    for i = 1, streamReadUInt8(streamId) do
        self.args[i] = streamReadString(streamId)
    end

    self:run(connection)
end

local function execute(farmId, action, args, connection)
    local handler = FabriX.actions[action]

    if handler == nil or farmId == nil or farmId == FarmManager.SPECTATOR_FARM_ID then return end

    if connection ~= nil and not g_currentMission:getHasPlayerPermission("manageProductions", connection, farmId) then return end

    handler(farmId, unpack(args))
    FabriX:syncToClients()
    FabriX:refreshOpenGui()
end

-- server: the farm comes from the sender's connection, never from data the client sends
function FabriXActionEvent:run(connection)
    if connection:getIsServer() then return end

    local userId = g_currentMission.userManager:getUserIdByConnection(connection)
    local farm = userId ~= nil and g_farmManager:getFarmByUserId(userId) or nil

    if farm ~= nil then
        execute(farm.farmId, self.action, self.args, connection)
    end
end

-- GUI entry point (args are sent as strings): runs directly on server/host/SP, otherwise asks the server
function FabriX:runAction(action, ...)
    if not g_currentMission:getHasPlayerPermission("manageProductions") then
        InfoDialog.show(g_i18n:getText("fabrix_gui_no_permission"))
        return false
    end

    -- the network carries strings only, host/SP handlers get the same types as on a dedicated server
    local args = {}
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        args[i] = value ~= nil and tostring(value) or ""
    end

    if g_currentMission:getIsServer() then
        execute(g_currentMission:getFarmId(), action, args)
    else
        g_client:getServerConnection():sendEvent(FabriXActionEvent.new(action, args))
    end
    return true
end
