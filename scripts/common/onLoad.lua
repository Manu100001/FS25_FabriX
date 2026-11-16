-- ##########################################
-- # Load all relevant data from FabriX.xml #
-- ##########################################
function FabriX.modules:onMissionLoaded()
    -- subscribe to relevant events
    g_messageCenter:subscribe(MessageType.MINUTE_CHANGED, FabriX.onMinuteChanged, FabriX)
    g_messageCenter:subscribe(MessageType.DAY_CHANGED, FabriX.onDayChanged, FabriX)
    g_messageCenter:subscribe(MessageType.YEAR_CHANGED, FabriX.onYearChanged, FabriX)
    g_messageCenter:subscribe(MessageType.PERIOD_CHANGED, FabriX.onMonthChanged, FabriX)
    g_messageCenter:subscribe(MessageType.PLAYER_FARM_CHANGED, FabriX.onPlayerFarmChanged, FabriX)
    g_messageCenter:subscribe(MessageType.FARM_DELETED, FabriX.onFarmDeleted, FabriX)

    if not g_currentMission:getIsServer() then
        -- clients get the FabriX state from the server via FabriXInitialStateEvent
        FabriX:rebuildClientProductions()
        return
    end

    local savegameDir = g_currentMission.missionInfo.savegameDirectory
    local xmlPath = nil

    if savegameDir ~= nil and savegameDir ~= "" then
        xmlPath = savegameDir .. "/FabriX.xml"
    else
        -- savegame not saved yet (brand-new game)
        Logging.info(g_i18n:getText("fabrix_savegame_directory_missing"))
    end

    if xmlPath == nil or not fileExists(xmlPath) then
        -- no FabriX data exists for this savegame yet
        -- production defaults come from newProduction
        -- the FabriX market has never been created for this savegame
        for _, farm in ipairs(g_farmManager:getFarms()) do
            FabriX:createStartMarket(farm.farmId)
        end
    else
        -- read all relevant data from FabriX.xml
        local xmlFile = XMLFile.load("FabriXXML", xmlPath)

        if xmlFile == nil then
            Logging.warning(g_i18n:getText("fabrix_xml_empty"))
        else
            xmlFile:iterate("fabriX.farms.farm", function(_, farmKey)
                local farmId = xmlFile:getInt(farmKey .. "#farmId")
                if farmId == nil then return end

                FabriX.transportCosts[farmId] = xmlFile:getFloat(farmKey .. "#transportCosts")
                FabriX.waterUsage[farmId] = xmlFile:getFloat(farmKey .. "#waterUsage")
                FabriX.electricityUsage[farmId] = xmlFile:getFloat(farmKey .. "#electricityUsage")
            end)

            -- load productions
            local index = 0

            while true do
                local key = string.format("fabriX.productions.production(%d)", index)

                if not xmlFile:hasProperty(key) then
                    break
                end

                local id = xmlFile:getString(key .. "#id")

                if id ~= nil and id ~= "" then
                    local farmId = xmlFile:getInt(key .. "#farmId")
                    local level = xmlFile:getInt(key .. "#level")
                    local xp = xmlFile:getFloat(key .. "#xp")
                    local isOnUpgrade = xmlFile:getBool(key .. "#isOnUpgrade")
                    local renovationDuration = xmlFile:getInt(key .. "#renovationDuration")
                    local propertyTax = xmlFile:getInt(key .. "#propertyTax")
                    local autoMode = xmlFile:getBool(key .. "#autoMode")
                    local basicWaterConsumption = xmlFile:getInt(key .. "#basicWaterConsumption")
                    local basicElectricityConsumption = xmlFile:getInt(key .. "#basicElectricityConsumption")
                    local fillLevels = {}
                    local fillIndex = 0

                    while true do
                        local fillKey = string.format("%s.fillLevels.fillLevel(%d)", key, fillIndex)

                        if not xmlFile:hasProperty(fillKey) then
                            break
                        end

                        local fillTypeName = xmlFile:getString(fillKey .. "#fillType")
                        local fillTypeIndex = fillTypeName ~= nil and g_fillTypeManager:getFillTypeIndexByName(fillTypeName) or nil
                        local fillLevel = xmlFile:getFloat(fillKey .. "#level")

                        if fillTypeIndex ~= nil and fillTypeIndex > 0 and fillLevel ~= nil then
                            fillLevels[fillTypeIndex] = fillLevel
                        end

                        fillIndex = fillIndex + 1
                    end

                    FabriX.loadedDataFromXML[id] = {
                        farmId = farmId,
                        level = level,
                        xp = xp,
                        isOnUpgrade = isOnUpgrade,
                        renovationDuration = renovationDuration,
                        fillLevels = fillLevels,
                        propertyTax = propertyTax,
                        autoMode = autoMode,
                        basicWaterConsumption = basicWaterConsumption,
                        basicElectricityConsumption = basicElectricityConsumption,
                    }
                end
                index = index + 1
            end

            -- load workers (employees)
            local workerIndex = 0
            while true do
                local key = string.format("fabriX.workers.employees(%d)", workerIndex)

                if not xmlFile:hasProperty(key) then break end

                local id = xmlFile:getString(key .. "#id")
                local category = xmlFile:getString(key .. "#category")
                local farmId = xmlFile:getInt(key .. "#farmId")

                if id ~= nil and id ~= "" and farmId ~= nil and FabriX.worker.employees[category] ~= nil then
                    local worker = {
                        id = id,
                        category = category,
                        icon = xmlFile:getString(key .. "#icon") or "",
                        name = xmlFile:getString(key .. "#name") or "",
                        age = xmlFile:getInt(key .. "#age") or (25 * 12),
                        farmId = farmId,
                        factoryId = xmlFile:getString(key .. "#factoryId") or "",
                        level = xmlFile:getInt(key .. "#level") or 1,
                        xp = xmlFile:getFloat(key .. "#xp") or 0,
                        salary = xmlFile:getFloat(key .. "#salary") or 0,
                        baseSalary = xmlFile:getFloat(key .. "#baseSalary") or FabriX.worker.BASE_SALARY[category] or 100,
                        slotId = xmlFile:getInt(key .. "#slotId") or 0,
                        shiftId = xmlFile:getInt(key .. "#shiftId") or 0,
                        monthsEmployed = xmlFile:getInt(key .. "#monthsEmployed") or 0,
                        inSchool = xmlFile:getBool(key .. "#inSchool") or false,
                        schoolMinutesLeft = xmlFile:getInt(key .. "#schoolMinutesLeft") or 0,
                        pendingSchool = xmlFile:getBool(key .. "#pendingSchool") or false,
                        resignationGiven = xmlFile:getBool(key .. "#resignationGiven") or false,
                        resignationMonthsLeft = xmlFile:getInt(key .. "#resignationMonthsLeft") or 0,
                        selfResigned = xmlFile:getBool(key .. "#selfResigned") or false,
                        counterOfferRejected = xmlFile:getBool(key .. "#counterOfferRejected") or false,
                        sickMinutesLeft = xmlFile:getInt(key .. "#sickMinutesLeft") or 0,
                        sickFactor = xmlFile:getFloat(key .. "#sickFactor"),
                        workedToday = xmlFile:getBool(key .. "#workedToday") or false,
                        roleSlot = xmlFile:getString(key .. "#roleSlot")
                    }
                    table.insert(FabriX.worker.employees[category], worker)
                end
                workerIndex = workerIndex + 1
            end

            -- load workers (market)
            local workerMarketIndex = 0
            while true do
                local key = string.format("fabriX.workers.market(%d)", workerMarketIndex)

                if not xmlFile:hasProperty(key) then break end

                local id = xmlFile:getString(key .. "#id")
                local category = xmlFile:getString(key .. "#category")

                if id ~= nil and id ~= "" and FabriX.worker.employees[category] ~= nil then
                    local farmId = xmlFile:getInt(key .. "#farmId")
                    local worker = {
                        id = id,
                        category = category,
                        icon = xmlFile:getString(key .. "#icon") or "",
                        name = xmlFile:getString(key .. "#name") or "",
                        age = xmlFile:getInt(key .. "#age") or (25 * 12),
                        level = xmlFile:getInt(key .. "#level") or 1,
                        xp = xmlFile:getFloat(key .. "#xp") or 0,
                        salary = xmlFile:getFloat(key .. "#salary") or 0,
                        baseSalary = xmlFile:getFloat(key .. "#baseSalary") or FabriX.worker.BASE_SALARY[category] or 100
                    }

                    local list = farmId ~= nil and FabriX:getMarket(farmId)[category] or nil

                    if list ~= nil then
                        table.insert(list, worker)
                    end
                end
                workerMarketIndex = workerMarketIndex + 1
            end
            xmlFile:delete()
        end
    end

    -- farms known at load keep their saved market
    for _, farm in ipairs(g_farmManager:getFarms()) do
        if FabriX:isPlayerFarm(farm.farmId) then
            FabriX:getMarket(farm.farmId)
        end
    end

    FabriX:applyLoadedData()
end

-- connect the loaded data (FabriX.xml on the server, join sync on a client) to the registered factories
-- safe to call more than once: capacities are always scaled from the base capacities
function FabriX:applyLoadedData()
    for _, production in pairs(FabriX.productions) do
        local loaded = FabriX.loadedDataFromXML[production.id]
        local resourceConsumption = FabriX:getResourceConsumption(production.placeable)

        if loaded ~= nil then
            production.level = loaded.level or 1
            production.xp = loaded.xp or 0
            production.isOnUpgrade = loaded.isOnUpgrade
            production.renovationDuration = loaded.renovationDuration or 0
            production.propertyTax = loaded.propertyTax
            production.autoMode = loaded.autoMode
            production.basicWaterConsumption = loaded.basicWaterConsumption or resourceConsumption.water
            production.basicElectricityConsumption = loaded.basicElectricityConsumption or resourceConsumption.electricity
            production.upgradeReadyNotified = false
        end

        FabriX:applyCapacityForLevel(production)
        -- the game loads factories always with the base capacities. However, if more goods have been stored in a level 2 factory, they would disappear at the start of the game
        -- therefore, the stock levels are loaded from FabriX.xml in order to restore them correctly
        -- fill levels are only in the XML data (server); clients get them from the game's own sync

        if loaded ~= nil then
            FabriX:restoreFillLevels(production.productionPoint, loaded.fillLevels)
        end
    end
end
