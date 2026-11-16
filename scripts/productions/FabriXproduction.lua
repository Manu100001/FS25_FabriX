-- subscribed for event YEAR_CHANGED
function FabriX.modules.production:onYearChanged()
    local taxPerFarm = {}

    for _, production in ipairs(FabriX.productions) do
        local tax = production.propertyTax or 0

        -- a director assigned to this factory reduces its property tax
        if FabriX:getRoleHolder(production, "betriebsleiter") then
            tax = tax * (1 - FabriX.FACTORY_MANAGER_TAX_DISCOUNT)
        end

        taxPerFarm[production.farmId] = (taxPerFarm[production.farmId] or 0) + tax
    end

    for farmId, tax in pairs(taxPerFarm) do
        g_currentMission:addMoney(-tax, farmId, MoneyType.FABRIX_TAX, true, true)
    end
end

-- subscribed for event MONTH_CHANGED
function FabriX.modules.production:onMonthChanged()
    for farmId, usage in pairs(FabriX.waterUsage) do
        local costs = usage * FabriX.WATER_COSTS

        g_currentMission:addMoney(-costs, farmId, MoneyType.FABRIX_WATER, true, true)
    end

    for farmId, usage in pairs(FabriX.electricityUsage) do
        local costs = usage * FabriX.ELECTRICITY_COSTS

        g_currentMission:addMoney(-costs, farmId, MoneyType.FABRIX_ELECTRICITY, true, true)
    end

    FabriX.waterUsage = {}
    FabriX.electricityUsage = {}
end

-- subscribed for event DAY_CHANGED
function FabriX.modules.production:onDayChanged()
    for farmId, costs in pairs(FabriX.transportCosts) do
        g_currentMission:addMoney(-costs, farmId, MoneyType.FABRIX_TRANSPORTATION, true, true)
    end

    FabriX.transportCosts = {}
end

-- subscribed for MINUTE_CHANGED
function FabriX.modules.production:onMinuteChanged()
    if g_currentMission == nil or g_currentMission.environment == nil then return end

    local minutesPerMonth = FabriX:getMinutesPerMonth()
    local xpPerMinute = FabriX.MAX_XP_PER_MONTH / minutesPerMonth

    for _, production in ipairs(FabriX.productions) do
        -- if production isOnUpgrade, check the renovation duration
        if production.isOnUpgrade then
            production.renovationDuration = production.renovationDuration - 1
            if production.renovationDuration <= 0 then
                production.isOnUpgrade = false
                FabriX:notify(production.farmId, FSBaseMission.INGAME_NOTIFICATION_INFO,
                    { "fabrix_renovation_finished", FabriX:getProductionName(production), production.level })

                FabriX:notify(production.farmId, FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
                    { "fabrix_renovation_finished_info", FabriX:getProductionName(production) })
            end
        end

        FabriX:updateProductionSpeed(production)

        -- calculate XP for each active production
        local productionPoint = production.productionPoint
        local activeProductions = productionPoint and productionPoint.activeProductions
        local allRecipes = productionPoint and productionPoint.productions or {}
        local amountRecipes = #allRecipes
        local amountActiveRecipes = 0

        if activeProductions ~= nil then
            local runningRecipeCount = 0
            for _, activeProduction in ipairs(activeProductions) do
                if activeProduction.status == ProductionPoint.PROD_STATUS.RUNNING then
                    runningRecipeCount = runningRecipeCount + 1
                end
            end
            -- XP only if production has active recipes and if workers are working in the factory
            if runningRecipeCount > 0 and (production.currentProductivity or 0) > 0 then
                local currentXP = production.xp or 0
                local newXP = currentXP + xpPerMinute

                if production.level >= FabriX.MAX_LEVEL then
                    production.xp = newXP
                else
                    local levelCapXP = FabriX.XP_FOR_LEVEL[production.level + 1]
                    if newXP >= levelCapXP then
                        production.xp = levelCapXP
                        if not production.upgradeReadyNotified then
                            FabriX:notify(production.farmId, FSBaseMission.INGAME_NOTIFICATION_INFO,
                                { "fabrix_upgrade_possible", FabriX:getProductionName(production), levelCapXP })
                            production.upgradeReadyNotified = true
                        end
                    else
                        production.xp = newXP
                        production.upgradeReadyNotified = false
                    end
                end
                FabriX:addXpToAssignedWorkers(production, xpPerMinute)
            end
            amountActiveRecipes = amountActiveRecipes + runningRecipeCount
        end

        if amountRecipes > 0 and amountActiveRecipes > 0 then
            -- calculate waterUsage and electricityUsage
            if production.basicWaterConsumption > 0 then
                local waterPerMinuteFullProduction = production.basicWaterConsumption / minutesPerMonth
                local currentWaterConsumption = waterPerMinuteFullProduction * amountActiveRecipes / amountRecipes

                FabriX.waterUsage[production.farmId] = (FabriX.waterUsage[production.farmId] or 0) +
                    currentWaterConsumption
            end

            if production.basicElectricityConsumption > 0 then
                local electricityPerMinuteFullProduction = production.basicElectricityConsumption / minutesPerMonth
                local currentElectricityConsumption = electricityPerMinuteFullProduction * amountActiveRecipes / amountRecipes
                FabriX.electricityUsage[production.farmId] = (FabriX.electricityUsage[production.farmId] or 0) + currentElectricityConsumption
            end
        end
    end
end
