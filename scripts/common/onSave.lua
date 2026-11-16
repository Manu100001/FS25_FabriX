-- ########################################
-- # save all relevant data to FabriX.xml #
-- ########################################
function FabriX.modules:onSave()
    local saveGameDir = g_currentMission.missionInfo.savegameDirectory

    if saveGameDir == nil or saveGameDir == "" then
        Logging.error(g_i18n:getText("fabrix_error_savegame_dir"))
        return
    end

    local xmlPath = saveGameDir .. "/FabriX.xml"

    -- create xml file, will be recreated every time
    local xmlFile = XMLFile.create("FabriXXML", xmlPath, "fabriX")

    if xmlFile == nil then
        Logging.error(g_i18n:getText("fabrix_xml_creation_failed_when_saving"))
        return
    end

    xmlFile:setInt("fabriX#version", 1)
    local farmIds = {}

    for _, counter in ipairs({ FabriX.transportCosts, FabriX.waterUsage, FabriX.electricityUsage }) do
        for farmId in pairs(counter) do farmIds[farmId] = true end
    end

    local farmIndex = 0
    for farmId in pairs(farmIds) do
        local farmKey = string.format("fabriX.farms.farm(%d)", farmIndex)
        xmlFile:setInt(farmKey .. "#farmId", farmId)
        xmlFile:setFloat(farmKey .. "#transportCosts", FabriX.transportCosts[farmId] or 0)
        xmlFile:setFloat(farmKey .. "#waterUsage", FabriX.waterUsage[farmId] or 0)
        xmlFile:setFloat(farmKey .. "#electricityUsage", FabriX.electricityUsage[farmId] or 0)
        farmIndex = farmIndex + 1
    end

    local index = 0
    for _, production in pairs(FabriX.productions) do
        -- all farms; helper.lua already skips EVERYONE/spectator-owned placeables
        local key = string.format("fabriX.productions.production(%d)", index)
        xmlFile:setString(key .. "#id", production.id)
        xmlFile:setInt(key .. "#farmId", production.farmId)
        xmlFile:setInt(key .. "#level", production.level or 1)
        xmlFile:setFloat(key .. "#xp", production.xp or 0)
        xmlFile:setBool(key .. "#isOnUpgrade", production.isOnUpgrade or false)
        xmlFile:setInt(key .. "#renovationDuration", production.renovationDuration or 0)
        xmlFile:setInt(key .. "#propertyTax", production.propertyTax or 0)
        xmlFile:setBool(key .. "#autoMode", production.autoMode or false)
        xmlFile:setInt(key .. "#basicWaterConsumption", production.basicWaterConsumption or 0)
        xmlFile:setInt(key .. "#basicElectricityConsumption", production.basicElectricityConsumption or 0)

        -- get stock level of each fill type
        local fillLevels = FabriX:getFillLevels(production.productionPoint)
        local fillIndex = 0

        for fillTypeIndex, fillLevel in pairs(fillLevels) do
            local fillKey = string.format("%s.fillLevels.fillLevel(%d)", key, fillIndex)
            xmlFile:setString(fillKey .. "#fillType", g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex))
            xmlFile:setFloat(fillKey .. "#level", fillLevel)
            fillIndex = fillIndex + 1
        end
        index = index + 1
    end

    -- save worker (employees)
    local employeeIndex = 0
    for categoryId, workerList in pairs(FabriX.worker.employees or {}) do
        for _, worker in ipairs(workerList) do
            local workerKey = string.format("fabriX.workers.employees(%d)", employeeIndex)
            xmlFile:setString(workerKey .. "#category", worker.category or categoryId)
            xmlFile:setString(workerKey .. "#icon", worker.icon or "")
            xmlFile:setString(workerKey .. "#id", worker.id)
            xmlFile:setString(workerKey .. "#name", worker.name or "")
            xmlFile:setInt(workerKey .. "#age", worker.age or (25 * 12))
            xmlFile:setInt(workerKey .. "#farmId", worker.farmId)
            xmlFile:setString(workerKey .. "#factoryId", worker.factoryId or "")
            xmlFile:setInt(workerKey .. "#level", worker.level or 1)
            xmlFile:setFloat(workerKey .. "#xp", worker.xp or 0)
            xmlFile:setFloat(workerKey .. "#salary", worker.salary or 0)
            xmlFile:setFloat(workerKey .. "#baseSalary", worker.baseSalary or FabriX.worker.BASE_SALARY[worker.category] or 100)
            xmlFile:setInt(workerKey .. "#slotId", worker.slotId or 0)
            xmlFile:setInt(workerKey .. "#shiftId", worker.shiftId or 0)
            xmlFile:setInt(workerKey .. "#monthsEmployed", worker.monthsEmployed or 0)
            xmlFile:setBool(workerKey .. "#inSchool", worker.inSchool == true)
            xmlFile:setInt(workerKey .. "#schoolMinutesLeft", worker.schoolMinutesLeft or 0)
            xmlFile:setBool(workerKey .. "#pendingSchool", worker.pendingSchool == true)
            xmlFile:setBool(workerKey .. "#resignationGiven", worker.resignationGiven == true)
            xmlFile:setInt(workerKey .. "#resignationMonthsLeft", worker.resignationMonthsLeft or 0)
            xmlFile:setBool(workerKey .. "#selfResigned", worker.selfResigned == true)
            xmlFile:setBool(workerKey .. "#counterOfferRejected", worker.counterOfferRejected == true)
            xmlFile:setInt(workerKey .. "#sickMinutesLeft", worker.sickMinutesLeft or 0)

            if worker.sickFactor ~= nil then
                xmlFile:setFloat(workerKey .. "#sickFactor", worker.sickFactor)
            end

            xmlFile:setBool(workerKey .. "#workedToday", worker.workedToday == true)
            xmlFile:setString(workerKey .. "#roleSlot", worker.roleSlot or "")
            employeeIndex = employeeIndex + 1
        end
    end

    local marketWorkerIndex = 0
    for farmId, market in pairs(FabriX.worker.market) do
        for categoryId, workerList in pairs(market) do
            for _, worker in ipairs(workerList) do
                local workerMarketKey = string.format("fabriX.workers.market(%d)", marketWorkerIndex)
                xmlFile:setInt(workerMarketKey .. "#farmId", farmId)
                xmlFile:setString(workerMarketKey .. "#category", worker.category or categoryId)
                xmlFile:setString(workerMarketKey .. "#icon", worker.icon or "")
                xmlFile:setString(workerMarketKey .. "#id", worker.id)
                xmlFile:setString(workerMarketKey .. "#name", worker.name or "")
                xmlFile:setInt(workerMarketKey .. "#age", worker.age or (25 * 12))
                xmlFile:setInt(workerMarketKey .. "#level", worker.level or 1)
                xmlFile:setFloat(workerMarketKey .. "#xp", worker.xp or 0)
                xmlFile:setFloat(workerMarketKey .. "#salary", worker.salary or 0)
                xmlFile:setFloat(workerMarketKey .. "#baseSalary", worker.baseSalary or FabriX.worker.BASE_SALARY[worker.category] or 100)
                marketWorkerIndex = marketWorkerIndex + 1
            end
        end
    end

    xmlFile:save()
    xmlFile:delete()
end
