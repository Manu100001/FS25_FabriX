-- ##############################################################
-- # State sync: the server sends the full FabriX state to a #
-- # joining client and to all clients after structural changes #
-- ##############################################################
FabriXInitialStateEvent = {}

local FabriXInitialStateEvent_mt = Class(FabriXInitialStateEvent, Event)

InitEventClass(FabriXInitialStateEvent, "FabriXInitialStateEvent")

local PRODUCTION_FIELDS = {
    { "id",                 "String" },
    { "farmId",             "FarmId" },
    { "level",              "UInt8" },
    { "xp",                 "Float32" },
    { "isOnUpgrade",        "Bool" },
    { "renovationDuration", "Int32" },
    { "propertyTax",        "Int32" },
    { "autoMode",           "Bool" }
}

-- employees and market workers share this list; missing fields (market workers loaded from the savegame) stay nil
local WORKER_FIELDS = {
    { "id",                    "String" },
    { "category",              "Category" },
    { "icon",                  "Icon" },
    { "name",                  "String" },
    { "age",                   "UInt16" }, -- in months
    { "farmId",                "FarmId" },
    { "factoryId",             "String" },
    { "level",                 "UInt8" },
    { "xp",                    "Float32" },
    { "salary",                "Float32" },
    { "baseSalary",            "Float32" },
    { "slotId",                "UInt8" },
    { "shiftId",               "UInt8" },
    { "monthsEmployed",        "UInt16" },
    { "inSchool",              "Bool" },
    { "schoolMinutesLeft",     "Int32" },
    { "pendingSchool",         "Bool" },
    { "resignationGiven",      "Bool" },
    { "resignationMonthsLeft", "UInt8" },
    { "workedToday",           "Bool" },
    { "roleSlot",              "String" },
    { "selfResigned",          "Bool" },
    { "counterOfferRejected",  "Bool" },
    { "sickMinutesLeft",       "Int32" }
}

-- category and icon go as UInt8 index; the icons (NPC portraits) are sent once per event as a list
local CATEGORIES = {
    "erntehelfer", "azubis", "facharbeiter"
}

local CATEGORY_INDEX = {
    erntehelfer = 1, azubis = 2, facharbeiter = 3
}

local iconIndex, iconList = {}, {} -- filled by writeIconList / readIconList for the event being processed

local STREAM_WRITE = {
    String = streamWriteString,
    Int32 = streamWriteInt32,
    UInt8 = streamWriteUInt8,
    UInt16 = streamWriteUInt16,
    FarmId = function(streamId, value) return streamWriteUIntN(streamId, value, FarmManager.FARM_ID_SEND_NUM_BITS) end,
    Float32 = streamWriteFloat32,
    Bool = streamWriteBool,
    Category = function(streamId, value) streamWriteUInt8(streamId, CATEGORY_INDEX[value] or 0) end,
    Icon = function(streamId, value) streamWriteUInt8(streamId, iconIndex[value] or 0) end
}

local STREAM_READ = {
    String = streamReadString,
    Int32 = streamReadInt32,
    UInt8 = streamReadUInt8,
    UInt16 = streamReadUInt16,
    FarmId = function(streamId) return streamReadUIntN(streamId, FarmManager.FARM_ID_SEND_NUM_BITS) end,
    Float32 = streamReadFloat32,
    Bool = streamReadBool,
    Category = function(streamId) return CATEGORIES[streamReadUInt8(streamId)] end,
    Icon = function(streamId) return iconList[streamReadUInt8(streamId)] end,
}

-- a presence flag per field keeps nil values nil on the client
local function writeFields(streamId, data, fields)
    for _, field in ipairs(fields) do
        local value = data[field[1]]
        streamWriteBool(streamId, value ~= nil)
        if value ~= nil then
            STREAM_WRITE[field[2]](streamId, value)
        end
    end
end

local function readFields(streamId, fields)
    local data = {}

    for _, field in ipairs(fields) do
        if streamReadBool(streamId) then
            data[field[1]] = STREAM_READ[field[2]](streamId)
        end
    end
    return data
end

-- every distinct icon once (max 255, more get no icon), then the workers refer to it by index
local function writeIconList(streamId, ...)
    iconIndex, iconList = {}, {}

    for _, workers in ipairs({ ... }) do
        for _, worker in ipairs(workers) do
            if worker.icon ~= nil and iconIndex[worker.icon] == nil and #iconList < 255 then
                table.insert(iconList, worker.icon)
                iconIndex[worker.icon] = #iconList
            end
        end
    end

    streamWriteUInt8(streamId, #iconList)
    for _, icon in ipairs(iconList) do
        streamWriteString(streamId, icon)
    end
end

local function readIconList(streamId)
    iconList = {}
    for i = 1, streamReadUInt8(streamId) do
        iconList[i] = streamReadString(streamId)
    end
end


-- farmId nil = all farms
local function allEmployees(farmId)
    local employees = {}
    for _, list in pairs(FabriX.worker.employees) do
        for _, worker in ipairs(list) do
            if farmId == nil or worker.farmId == farmId then
                table.insert(employees, worker)
            end
        end
    end
    return employees
end

-- employees and market: only the client's own farm; productions of all farms are sent (clients mirror level and capacity of every factory)
local function getConnectionFarmId(connection)
    local userId = g_currentMission.userManager:getUserIdByConnection(connection)
    local farm = userId ~= nil and g_farmManager:getFarmByUserId(userId) or nil
    return farm ~= nil and farm.farmId or FarmManager.SPECTATOR_FARM_ID
end

function FabriXInitialStateEvent.emptyNew() return Event.new(FabriXInitialStateEvent_mt) end

function FabriXInitialStateEvent.new() return FabriXInitialStateEvent.emptyNew() end

function FabriXInitialStateEvent:writeStream(streamId, connection)
    local farmId = getConnectionFarmId(connection)

    streamWriteUInt16(streamId, #FabriX.productions)

    for _, production in ipairs(FabriX.productions) do
        writeFields(streamId, production, PRODUCTION_FIELDS)

        -- clients find the placeables by its network id; 0 = not registered yet
        NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(production.placeable) or 0)
    end

    local employees = allEmployees(farmId)

    local market = {}

    -- spectators have no market
    for _, list in pairs(FabriX.worker.market[farmId] or {}) do
        for _, worker in ipairs(list) do
            table.insert(market, worker)
        end
    end

    writeIconList(streamId, employees, market)
    streamWriteUInt16(streamId, #employees)

    for _, worker in ipairs(employees) do
        writeFields(streamId, worker, WORKER_FIELDS)
    end

    streamWriteUIntN(streamId, farmId, FarmManager.FARM_ID_SEND_NUM_BITS)
    streamWriteUInt16(streamId, #market)

    for _, worker in ipairs(market) do
        writeFields(streamId, worker, WORKER_FIELDS)
    end
end

function FabriXInitialStateEvent:readStream(streamId, connection)
    -- only the server may send the full state
    if not connection:getIsServer() then return end

    -- full state: replace whatever the client had before
    FabriX.loadedDataFromXML = {}
    FabriX.serverProductions = {}

    for category in pairs(FabriX.worker.employees) do
        FabriX.worker.employees[category] = {}
    end

    FabriX.worker.market = {}

    for _ = 1, streamReadUInt16(streamId) do
        local production = readFields(streamId, PRODUCTION_FIELDS)
        production.objectId = NetworkUtil.readNodeObjectId(streamId)
        FabriX.loadedDataFromXML[production.id] = production
        table.insert(FabriX.serverProductions, production)
    end

    readIconList(streamId)

    for _ = 1, streamReadUInt16(streamId) do
        local worker = readFields(streamId, WORKER_FIELDS)
        local list = FabriX.worker.employees[worker.category]
        if list ~= nil then
            table.insert(list, worker)
        end
    end

    local marketFarmId = streamReadUIntN(streamId, FarmManager.FARM_ID_SEND_NUM_BITS)

    for _ = 1, streamReadUInt16(streamId) do
        local worker = readFields(streamId, WORKER_FIELDS)
        local list = FabriX:getMarket(marketFarmId)[worker.category]
        if list ~= nil then
            table.insert(list, worker)
        end
    end

    self:run(connection)
end

-- the event may arrive before or after the client's onMissionLoaded; applyLoadedData is safe in both orders
function FabriXInitialStateEvent:run(connection)
    FabriX:rebuildClientProductions()

    FabriX:refreshOpenGui()
end

-- server only: marks the full state as changed; FabriX:update sends it once per frame
function FabriX:syncToClients()
    if g_server ~= nil then
        FabriX.syncPending = true
    end
end

-- server only: sends a pending full state to all clients (a joining client gets it directly via sendInitialClientState)
function FabriX:flushSync()
    if not FabriX.syncPending or g_server == nil then return end

    FabriX.syncPending = false
    g_server:broadcastEvent(FabriXInitialStateEvent.new())
end

-- ###########################################################
-- # Minute sync: only the values that change every minute #
-- ###########################################################
FabriXMinuteSyncEvent = {}

local FabriXMinuteSyncEvent_mt = Class(FabriXMinuteSyncEvent, Event)

InitEventClass(FabriXMinuteSyncEvent, "FabriXMinuteSyncEvent")

local PRODUCTION_MINUTE_FIELDS = {
    { "id",                 "String" },
    { "xp",                 "Float32" },
    { "isOnUpgrade",        "Bool" },
    { "renovationDuration", "Int32" },
}

local WORKER_MINUTE_FIELDS = {
    { "id",                "String" },
    { "xp",                "Float32" },
    { "level",             "UInt8" },
    { "salary",            "Float32" },
    { "inSchool",          "Bool" },
    { "schoolMinutesLeft", "Int32" },
    { "workedToday",       "Bool" },
    { "sickMinutesLeft",   "Int32" }
}

-- copies the values onto the object with the same id; unknown ids wait for the next full sync
local function applyById(objects, data)
    for _, object in ipairs(objects) do
        if object.id == data.id then
            for key, value in pairs(data) do
                object[key] = value
            end
            return
        end
    end
end

function FabriXMinuteSyncEvent.emptyNew() return Event.new(FabriXMinuteSyncEvent_mt) end

function FabriXMinuteSyncEvent.new() return FabriXMinuteSyncEvent.emptyNew() end

function FabriXMinuteSyncEvent:writeStream(streamId, connection)
    streamWriteUInt16(streamId, #FabriX.productions)

    for _, production in ipairs(FabriX.productions) do
        writeFields(streamId, production, PRODUCTION_MINUTE_FIELDS)
    end

    local employees = allEmployees(getConnectionFarmId(connection))

    streamWriteUInt16(streamId, #employees)
    for _, worker in ipairs(employees) do
        writeFields(streamId, worker, WORKER_MINUTE_FIELDS)
    end
end

function FabriXMinuteSyncEvent:readStream(streamId, connection)
    -- only the server may send the full state
    if not connection:getIsServer() then return end

    for _ = 1, streamReadUInt16(streamId) do
        applyById(FabriX.productions, readFields(streamId, PRODUCTION_MINUTE_FIELDS))
    end

    local employees = allEmployees()

    for _ = 1, streamReadUInt16(streamId) do
        applyById(employees, readFields(streamId, WORKER_MINUTE_FIELDS))
    end
end

-- redraw an open FabriX Gui so the player sees the new state
function FabriX:refreshOpenGui()
    if FabriX.gui ~= nil and g_gui.currentGuiName == "FabriXGui" then
        FabriX.gui:showTab(FabriX.gui.currentTab or 1)
        FabriX.gui:checkCounterOfferResult()
    end
end
