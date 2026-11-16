-- ##########
-- # FabriX #
-- ##########

-- FabriX - production & workforce management for Farming Simulator 25.
-- Author: Manu100001
-- License: All rights reserved.

-- The version is maintained in modDesc.xml (single source of truth)

local startInit = true

function FabriX:loadMap()
    local mod = g_modManager ~= nil and g_modManager:getModByName(FabriX.modName) or nil
    local version = (mod ~= nil and mod.version) or "unknown"
    Logging.info("[FabriX]: FabriX mod loaded (version %s)", version)

    -- FabriX was tested with this Production Revamp version only
    local testedRevampVersion = "1.0.0.0"
    if g_modIsLoaded["FS25_0_ProductionRevamp"] then
        local revamp = g_modManager:getModByName("FS25_0_ProductionRevamp")

        local revampVersion = (revamp ~= nil and revamp.version) or "unknown"

        if revampVersion == testedRevampVersion then
            Logging.info("[FabriX]: Production Revamp detected with version: %s", revampVersion)
        else
            Logging.warning("[FabriX]: Production Revamp detected with version: %s, but FabriX was tested only with version: %s", revampVersion, testedRevampVersion)
        end
    end
end

-- is called every frame
function FabriX:update(dt)
    -- wait until the production system exists before loading FabriX data
    if startInit then
        local productionChainManager = g_currentMission and (g_currentMission.productionChainManager or g_productionChainManager)
        if productionChainManager ~= nil then
            -- Retry this here in case FINANCES was not ready during script load
            self:registerFinanceCategories()
            self:onMissionLoaded()
            startInit = false
            -- register FabriX GUI once (no GUI on a dedicated server)
            if g_dedicatedServer == nil and FabriX.gui == nil then
                local guiPath = FabriX.dir .. "xml/gui/FabriXGui.xml"
                FabriX.gui = FabriXGui.new()
                g_gui:loadGui(guiPath, "FabriXGui", FabriX.gui)
            end
        end
    end
    FabriX:flushSync()
end

function FabriX:onOpenGuiPressed()
    if g_gui.currentGuiName == "FabriXGui" then
        g_gui:showGui(nil)         -- open -> close
    elseif g_gui.currentGui == nil then
        g_gui:showGui("FabriXGui") -- nothing open -> open
    end
end

function FabriX:onYearChanged()
    if not g_currentMission:getIsServer() then return end

    FabriX.modules.production:onYearChanged()
end

function FabriX:onMonthChanged()
    if not g_currentMission:getIsServer() then return end

    FabriX.modules.production:onMonthChanged()
    FabriX.modules.worker:onMonthChanged()
    FabriX:syncToClients()
    FabriX:refreshOpenGui()
end

function FabriX:onDayChanged()
    if not g_currentMission:getIsServer() then return end

    FabriX.modules.production:onDayChanged()
    FabriX.modules.worker:onDayChanged()

    -- after the worker day reset: autoSkip is cleared and azubis get placed
    FabriX:runAutoMode(true)
    FabriX:syncToClients()
    FabriX:refreshOpenGui()
end

function FabriX:onMinuteChanged()
    if not g_currentMission:getIsServer() then return end

    FabriX.modules.production:onMinuteChanged()
    FabriX.modules.worker:onMinuteChanged()

    if FabriX:runAutoMode(false) then
        FabriX:syncToClients()
        FabriX:refreshOpenGui()
    end

    -- at most every 2.5 real seconds (g_time = real ms): high timescales would flood MP clients otherwise
    if FabriX.lastMinuteSyncTime == nil or g_time - FabriX.lastMinuteSyncTime >= 2500 then
        FabriX.lastMinuteSyncTime = g_time
        g_server:broadcastEvent(FabriXMinuteSyncEvent.new())
    end
end

-- server: a player joined a farm; a brand-new farm gets its start market
function FabriX:onPlayerFarmChanged(player)
    if not g_currentMission:getIsServer() or player == nil then return end

    FabriX:createStartMarket(player.farmId)
    -- the player now needs the data of the new farm
    FabriX:syncToClients()
    FabriX:refreshOpenGui()
end

-- server: a farm was deleted, drop its workers, market and open costs
function FabriX:onFarmDeleted(farmId)
    if not g_currentMission:getIsServer() or farmId == nil then return end

    for _, categoryList in pairs(FabriX.worker.employees) do
        for i = #categoryList, 1, -1 do
            if categoryList[i].farmId == farmId then
                table.remove(categoryList, i)
            end
        end
    end

    FabriX.worker.market[farmId] = nil
    FabriX.transportCosts[farmId] = nil
    FabriX.waterUsage[farmId] = nil
    FabriX.electricityUsage[farmId] = nil
    FabriX:syncToClients()
end

-- init FabriX
function FabriX:onMissionLoaded()
    FabriX.modules:onMissionLoaded()
end

-- the game is saved: write the current FabriX state to FabriX.xml
function FabriX:onSave()
    FabriX.modules:onSave()
end

function FabriX:deleteMap()
    g_messageCenter:unsubscribeAll(self)
    startInit = true

    -- the Lua state may survive a savegame switch: start the next game clean
    FabriX.productions = {}
    FabriX.serverProductions = nil
    FabriX.loadedDataFromXML = {}
    FabriX.worker.employees = { erntehelfer = {}, azubis = {}, facharbeiter = {} }
    FabriX.worker.market = {}
    FabriX.transportCosts, FabriX.waterUsage, FabriX.electricityUsage = {}, {}, {}
    FabriX.isDistributingGoods = false
    FabriX.lastMinuteSyncTime = nil
    FabriX.syncPending = false
    FabriX.pendingUpgrade = nil
    FabriX.actionEventId = nil
    FabriX.helpLineLoaded = false
end
