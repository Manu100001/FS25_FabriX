-- ####################
-- # Helper Functions #
-- ####################
-- false for no farm, the "everyone" farm and the spectator farm (npc-owned buildings)
function FabriX:isPlayerFarm(farmId)
    return farmId ~= nil and farmId ~= AccessHandler.EVERYONE and farmId ~= FarmManager.SPECTATOR_FARM_ID
end

-- this is for the case where a production is already placed on the map, but does not belong to the player
-- if the player buys it at some point, this ensures that it is added to the internal FabriX logic
-- factory is either registered and placed at the start of the game, or the player purchases a new factory
function FabriX:registerProduction(placeable)
    if placeable == nil or placeable.spec_productionPoint == nil then return end

    -- clients mirror the server list (FabriXInitialStateEvent); FS25 syncs no uniqueId for placed buildings
    if g_currentMission ~= nil and not g_currentMission:getIsServer() then
        FabriX:rebuildClientProductions()
        return
    end

    -- only productions that belong to a player farm
    local farmId = placeable:getOwnerFarmId()

    if not FabriX:isPlayerFarm(farmId) then return end

    local specProductionPoint = placeable.spec_productionPoint.productionPoint

    if type(specProductionPoint) ~= "table" then return end


    for _, production in pairs(FabriX.productions) do
        if production.placeable == placeable then return end -- placeable (factory) already there, do nothing
    end

    table.insert(FabriX.productions, FabriX:newProduction(placeable, placeable.uniqueId, farmId))
    FabriX:setProductionCostsToZero()
    FabriX:syncToClients()
end

function FabriX:onBuy(placeable)
    if placeable == nil or placeable.spec_productionPoint == nil then return end

    -- when a new factory is bought, both the onBuy function and the register function are called
    -- therefore, in the registerProduction function we check if the factory is already registered, and if so, we do not add it again
    -- however, if a production that has already been placed is bought, only the onBuy function is called
    -- therefore, we must ensure that it is also registered
    FabriX:registerProduction(placeable)
end

-- server only: clients drop the factory with the next full sync (rebuildClientProductions resets its capacities)
function FabriX:onSell(placeable)
    if placeable == nil or placeable.spec_productionPoint == nil or not g_currentMission:getIsServer() then return end

    local removed = false

    for i = #FabriX.productions, 1, -1 do
        if FabriX.productions[i].placeable == placeable then
            FabriX:releaseWorkersOfFactory(FabriX.productions[i].id, FabriX.productions[i].farmId)

            -- back to base capacities, otherwise a re-buy captures the upgraded ones as new base
            FabriX.productions[i].level = 1
            FabriX:applyCapacityForLevel(FabriX.productions[i])

            table.remove(FabriX.productions, i)
            removed = true
        end
    end

    if removed then
        FabriX:syncToClients()
    end
end

-- server only: owner changed (farmland bought/sold, farm removed): the level stays, autoMode is switched off, the old farm's workers are released
function FabriX:onOwnerChanged(placeable)
    -- clients get the new owner with the next full sync
    if g_currentMission == nil or not g_currentMission:getIsServer() then return end

    for _, production in ipairs(FabriX.productions) do
        if production.placeable == placeable then
            local farmId = placeable:getOwnerFarmId()
            if production.farmId == farmId then return end

            if not FabriX:isPlayerFarm(farmId) then
                FabriX:onSell(placeable)
                return
            end

            FabriX:releaseWorkersOfFactory(production.id, production.farmId)
            production.farmId = farmId
            production.autoMode = false
            production.autoSkip = nil
            FabriX:syncToClients()
            return
        end
    end

    -- not registered yet; a client bought a preplaced building (onBuy runs only on the buyer's machine)
    if placeable.finishedLoading then
        FabriX:registerProduction(placeable)
    end
end

-- true while distributeGoods runs; addMoney then books production costs as transport costs
FabriX.isDistributingGoods = false

function FabriX:distributeGoods(manager, superFunc, ...)
    -- here, the costs for distributing goods between production lines are captured and stored within the FabriX logic
    -- the costs are not deducted each time, but are instead deducted once a day as transportation costs
    FabriX:installTransportCostCapture()
    FabriX.isDistributingGoods = true
    local result = superFunc(manager, ...)

    FabriX.isDistributingGoods = false
    return result
end

-- wraps addMoney on the mission instance once; it books production costs as transport costs only during distributeGoods
function FabriX:installTransportCostCapture()
    local mission = g_currentMission

    if mission == nil or mission.fabrixTransportCaptureInstalled then return end

    local realAddMoney = mission.addMoney

    mission.addMoney = function(self, amount, farmId, moneyType, ...)
        if FabriX.isDistributingGoods and amount ~= nil and amount < 0 and moneyType == MoneyType.PRODUCTION_COSTS then
            FabriX.transportCosts[farmId] = (FabriX.transportCosts[farmId] or 0) - amount
            return
        end
        return realAddMoney(self, amount, farmId, moneyType, ...)
    end

    mission.fabrixTransportCaptureInstalled = true
end

function FabriX:setProductionCostsToZero()
    for _, production in pairs(FabriX.productions) do
        local productionPoint = production.productionPoint
        for _, recipe in ipairs(productionPoint.productions or {}) do
            recipe.costsPerActiveMonth = 0
            recipe.costsPerActiveHour = 0
            recipe.costsPerActiveMinute = 0
        end
    end
end

function FabriX:getResourceConsumption(placeable)
    local configFileName = placeable.configFileName or ""
    local path = configFileName:gsub("\\", "/"):lower()

    -- unknown (mod) productions get their own random consumption
    local resourceConsumption = { water = math.random(1, 15), electricity = math.random(5, 60) }

    for suffix, consumption in pairs(FabriX.RESOURCE_CONSUMPTION) do
        if path:sub(- #suffix) == suffix then
            resourceConsumption = consumption
            break
        end
    end
    return resourceConsumption
end

function FabriX:captureBaseCapacities(productionPoint)
    local base = {}
    local storage = productionPoint.storage

    if storage == nil or storage.capacities == nil then
        return base
    end

    for fillTypeIndex, capacity in pairs(storage.capacities) do
        base[fillTypeIndex] = capacity
    end
    return base
end

function FabriX:applyCapacityForLevel(production)
    local storage = production.productionPoint.storage

    if storage == nil or storage.capacities == nil then return end

    local factor = FabriX.CAPACITY_FACTOR[production.level]

    for fillTypeIndex, baseCapacity in pairs(production.baseCapacities) do
        storage.capacities[fillTypeIndex] = baseCapacity * factor
    end

    if production.baseCapacity ~= nil then
        storage.capacity = production.baseCapacity * factor
    end
end

function FabriX:getFillLevels(productionPoint)
    local fillLevels = {}
    local storage = productionPoint.storage
    if storage == nil then
        return fillLevels
    end

    for _, fillTypeIndex in ipairs(productionPoint.inputFillTypeIdsArray or {}) do
        fillLevels[fillTypeIndex] = storage:getFillLevel(fillTypeIndex)
    end

    for _, fillTypeIndex in ipairs(productionPoint.outputFillTypeIdsArray or {}) do
        fillLevels[fillTypeIndex] = storage:getFillLevel(fillTypeIndex)
    end

    return fillLevels
end

function FabriX:restoreFillLevels(productionPoint, fillLevels)
    local storage = productionPoint.storage

    if storage == nil or fillLevels == nil then return end

    for fillTypeIndex, fillLevel in pairs(fillLevels) do
        storage:setFillLevel(fillLevel, fillTypeIndex)
    end
end

-- get XP info to show it in the gui
function FabriX:getXpProgress(production)
    if production.level >= FabriX.MAX_LEVEL then
        return production.xp or 0, nil, 1
    end

    local xpNeededForNextLevel = FabriX.XP_FOR_LEVEL[production.level + 1]
    if xpNeededForNextLevel == nil or xpNeededForNextLevel <= 0 then
        return production.xp or 0, nil, 1
    end

    local xpCurrent = production.xp or 0
    if xpCurrent > xpNeededForNextLevel then xpCurrent = xpNeededForNextLevel end
    return xpCurrent, xpNeededForNextLevel, xpCurrent / xpNeededForNextLevel
end

function FabriX:getCurrentShiftId()
    if g_currentMission == nil or g_currentMission.environment == nil then return nil end

    local hour = g_currentMission.environment.currentHour

    if hour < 8 then
        return 1
    elseif hour < 16 then
        return 2
    else
        return 3
    end
end

function FabriX:getShiftProductivity(production, shiftId)
    local sum = 0

    if FabriX.worker == nil or FabriX.worker.employees == nil then
        return sum
    end

    if production == nil or shiftId == nil then
        return sum
    end

    local level = production.level or 0
    -- check mandatory role slots
    local master = nil

    if level >= FabriX.ROLE_MIN_LEVEL.meister then
        master = FabriX:getRoleHolder(production, "meister")
        if master == nil then
            return 0 -- no Meister => factory is idle
        end
    end

    if level >= FabriX.ROLE_MIN_LEVEL.betriebsleiter then
        if FabriX:getRoleHolder(production, "betriebsleiter") == nil then
            return 0 -- no Betriebsleiter => factory is idle
        end
    end

    local factoryId = production.id
    local farmId = production.farmId

    for _, categoryList in pairs(FabriX.worker.employees) do
        for _, worker in ipairs(categoryList) do
            if worker.farmId == farmId and worker.factoryId == factoryId and worker.shiftId == shiftId and worker.slotId ~= nil and worker.slotId > 0 and not worker.inSchool then
                local prod = FabriX:getWorkerProductivity(worker)
                sum = sum + prod
            end
        end
    end

    if shiftId == FabriX.worker.SHIFT_DAY and master ~= nil then
        sum = sum + FabriX:getWorkerProductivity(master)
    end
    return sum
end

function FabriX:updateProductionSpeed(production)
    if production == nil or production.productionPoint == nil then return end

    local shiftId = FabriX:getCurrentShiftId()
    local productivity = FabriX:getShiftProductivity(production, shiftId)
    production.currentProductivity = productivity

    -- never exactly 0: base game's missing-input check compares against cyclesPerMinute
    local speedFactor = math.max(productivity, 0.000001)

    for _, recipe in ipairs(production.productionPoint.productions or {}) do
        -- store base value
        if recipe.fabrixBaseCyclesPerMinute == nil then
            recipe.fabrixBaseCyclesPerMinute = recipe.cyclesPerMinute
            recipe.fabrixBaseCyclesPerHour = recipe.cyclesPerHour
            recipe.fabrixBaseCyclesPerMonth = recipe.cyclesPerMonth
        end

        recipe.cyclesPerMinute = recipe.fabrixBaseCyclesPerMinute * speedFactor
        recipe.cyclesPerHour = recipe.fabrixBaseCyclesPerHour * speedFactor
        recipe.cyclesPerMonth = recipe.fabrixBaseCyclesPerMonth * speedFactor
    end
end

-- status of a factory, computed locally from synced data (workers, recipe status, storage)
-- returns: status, partial (another recipe still runs), missing goods, low goods (fill type indices)
function FabriX:getProductionStatus(production)
    if production.isOnUpgrade then
        return "renovation", false, {}, {}
    end
    if FabriX:getShiftProductivity(production, FabriX:getCurrentShiftId()) <= 0 then
        return "noStaff", false, {}, {}
    end
    local point = production.productionPoint
    local storage = point and point.storage
    local running, full, missing, low, seen = 0, false, {}, {}, {}
    for _, recipe in ipairs(point and point.activeProductions or {}) do
        if recipe.status == ProductionPoint.PROD_STATUS.RUNNING then
            running = running + 1
        elseif recipe.status == ProductionPoint.PROD_STATUS.NO_OUTPUT_SPACE then
            full = true
        end

        for _, input in ipairs(recipe.inputs or {}) do
            local fillType = input.type
            if storage ~= nil and seen[fillType] ~= "missing" then
                local level = storage:getFillLevel(fillType)
                if recipe.status == ProductionPoint.PROD_STATUS.MISSING_INPUTS and level < input.amount then
                    -- a later recipe can upgrade a "low" input to "missing"
                    if seen[fillType] == "low" then
                        table.removeElement(low, fillType)
                    end
                    table.insert(missing, fillType)
                    seen[fillType] = "missing"
                elseif seen[fillType] == nil then
                    seen[fillType] = "ok"
                    if level < storage:getCapacity(fillType) * FabriX.STATUS_LOW_SHARE then
                        table.insert(low, fillType)
                        seen[fillType] = "low"
                    end
                end
            end
        end
    end
    if point == nil or #(point.activeProductions or {}) == 0 then
        return "noRecipe", false, {}, {}
    end
    if #missing > 0 then return "missing", running > 0, missing, low end
    if full then return "full", running > 0, missing, low end
    if #low > 0 then return "low", false, missing, low end
    return "running", false, missing, low
end

-- worker holding the role slot (meister/betriebsleiter) of a factory; nil if empty or the holder is in school
function FabriX:getRoleHolder(production, roleSlot)
    if FabriX.worker == nil or FabriX.worker.employees == nil then return nil end
    if production == nil then return nil end

    local factoryId = production.id
    local farmId = production.farmId
    for _, categoryList in pairs(FabriX.worker.employees) do
        for _, worker in ipairs(categoryList) do
            if worker.farmId == farmId and worker.factoryId == factoryId and worker.roleSlot == roleSlot and not worker.inSchool then
                return worker
            end
        end
    end
    return nil
end

-- Releases all workers assigned to a given factory (shift slots AND role slots)
-- The workers stay with the farm but become "unassigned" afterwards
function FabriX:releaseWorkersOfFactory(factoryId, farmId)
    if factoryId == nil then return end
    if FabriX.worker == nil or FabriX.worker.employees == nil then return end

    for _, categoryList in pairs(FabriX.worker.employees) do
        for _, worker in ipairs(categoryList) do
            if worker.factoryId == factoryId and (farmId == nil or worker.farmId == farmId) then
                if FabriX:isWorkerOnShift(worker) then
                    worker.workedToday = true
                end
                FabriX:clearAssignment(worker)
            end
        end
    end
end

function FabriX:newProduction(placeable, id, farmId)
    local specProductionPoint = placeable.spec_productionPoint.productionPoint
    local resourceConsumption = FabriX:getResourceConsumption(placeable)

    return {
        placeable = placeable,
        productionPoint = specProductionPoint,
        id = id,
        farmId = farmId,

        level = 1,
        xp = 0,
        isOnUpgrade = false,
        renovationDuration = 0,
        upgradeReadyNotified = false,
        propertyTax = math.random(80, 800),
        autoMode = false,
        basicWaterConsumption = resourceConsumption.water or 0,
        basicElectricityConsumption = resourceConsumption.electricity or 0,
        baseCapacities = FabriX:captureBaseCapacities(specProductionPoint),
        baseCapacity = specProductionPoint.storage and specProductionPoint.storage.capacity
    }
end

-- client only: mirror the server's list; a placeable still loading joins via its finalizePlacement
function FabriX:rebuildClientProductions()
    local productions, kept = {}, {}
    for _, data in ipairs(FabriX.serverProductions or {}) do
        local placeable = NetworkUtil.getObject(data.objectId)
        local spec = placeable ~= nil and placeable.spec_productionPoint or nil

        if spec ~= nil and spec.productionPoint ~= nil then
            local production = nil
            for _, existing in ipairs(FabriX.productions) do
                if existing.placeable == placeable then
                    production = existing
                    break
                end
            end

            production = production or FabriX:newProduction(placeable, data.id, data.farmId)
            production.id = data.id
            production.farmId = data.farmId
            table.insert(productions, production)
            kept[production] = true
        end
    end
    -- productions the server dropped (sold) go back to their base capacity
    for _, old in ipairs(FabriX.productions) do
        if not kept[old] then
            old.level = 1
            FabriX:applyCapacityForLevel(old)
        end
    end

    FabriX.productions = productions
    FabriX:setProductionCostsToZero()
    FabriX:applyLoadedData()
end

function FabriX:getFillTypeTitles(fillTypes)
    local names = {}

    for _, fillType in ipairs(fillTypes) do
        local info = g_fillTypeManager:getFillTypeByIndex(fillType)
        table.insert(names, info ~= nil and info.title or tostring(fillType))
    end

    return table.concat(names, ", ")
end

-- server only: a production owned by the farm
function FabriX:findProduction(farmId, productionId)
    for _, production in ipairs(FabriX.productions) do
        if production.id == productionId and production.farmId == farmId then
            return production
        end
    end
end

function FabriX:getMinutesPerMonth()
    local environment = g_currentMission ~= nil and g_currentMission.environment or nil
    return ((environment ~= nil and environment.daysPerPeriod) or 1) * 24 * 60
end

function FabriX:getSlotsPerShift(production)
    local level = (production and production.level) or 1

    return math.max(1, math.min(level, FabriX.MAX_LEVEL))
end

-- Returns a table slotId -> worker for a factory/shift of a farm
function FabriX:getAssignedWorkers(farmId, factoryId, shiftId)
    local bySlot = {}

    if FabriX.worker == nil or FabriX.worker.employees == nil then
        return bySlot
    end

    for _, categoryList in pairs(FabriX.worker.employees) do
        for _, worker in ipairs(categoryList) do
            if worker.farmId == farmId and worker.factoryId == factoryId and worker.shiftId == shiftId and worker.slotId ~= nil and worker.slotId > 0 then
                bySlot[worker.slotId] = worker
            end
        end
    end
    return bySlot
end

-- remaining renovation time in full ingame hours (renovationDuration is in minutes)
function FabriX:getRenovationHours(production)
    return math.ceil(((production and production.renovationDuration) or 0) / 60)
end

-- display name of a factory; the id if the placeable is missing
function FabriX:getProductionName(production)
    if production == nil then return "?" end

    return production.placeable ~= nil and production.placeable:getName() or tostring(production.id or "?")
end
