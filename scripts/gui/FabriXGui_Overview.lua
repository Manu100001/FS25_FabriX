-- #######################################################################
-- FabriXGui - Overview tab (command center: KPIs and action-required list)
-- Part of the FabriXGui class defined in FabriXGui.lua.
-- #######################################################################
-- Collects aggregated statistics across all FabriX productions and workers
-- of the current farm (factory slots, missing leaders, worker counts, costs)

function FabriXGui:collectOverviewStats()
    local farmId = g_currentMission ~= nil and g_currentMission:getFarmId() or nil

    local stats = {
        productionCount = 0,
        freeSlotFactories = {},
        missingLeaders = {},
        totalFreeSlots = 0,
        totalSlots = 0,
        idleFactories = 0,
        avgProductivity = 0,
        workerTotal = 0,
        countByCat = { erntehelfer = 0, geselle = 0, meister = 0, betriebsleiter = 0, azubis = 0 },
        assignedCount = 0,
        freeCount = 0,
        inSchoolCount = 0,
        pendingSchool = 0,
        trainableCount = 0,
        resigning = {},
        retiring = {},         -- workers who will retire soon
        unassignedAzubis = {}, -- azubis not assigned to any shift
        sick = {},
        statusFactories = {},  -- factories with a production problem
        salarySum = 0,
        propertyTaxSum = 0,
    }

    -- ---- Productions ----
    for _, production in ipairs(FabriX.productions or {}) do
        if farmId ~= nil and production.farmId == farmId then
            stats.productionCount = stats.productionCount + 1

            local name = FabriX:getProductionName(production)
            local level = production.level or 1

            -- count free shift slots
            local slotsPerShift = FabriX:getSlotsPerShift(production)
            local totalSlots = slotsPerShift * 3
            local usedSlots = 0

            for shift = 1, FabriX.worker.SHIFT_COUNT do
                local assigned = FabriX:getAssignedWorkers(farmId, production.id, shift)

                for _ in pairs(assigned) do
                    usedSlots = usedSlots + 1
                end
            end

            local free = totalSlots - usedSlots
            stats.totalSlots = stats.totalSlots + totalSlots
            stats.totalFreeSlots = stats.totalFreeSlots + free

            if free > 0 then
                table.insert(stats.freeSlotFactories, { name = name, free = free, total = totalSlots })
            end

            -- missing leadership roles
            if level >= FabriX.ROLE_MIN_LEVEL.meister and not FabriX:getRoleHolder(production, "meister") then
                table.insert(stats.missingLeaders, { name = name, role = g_i18n:getText("fabrix_role_meister") })
            end

            if level >= FabriX.ROLE_MIN_LEVEL.betriebsleiter and not FabriX:getRoleHolder(production, "betriebsleiter") then
                table.insert(
                    stats.missingLeaders, { name = name, role = g_i18n:getText("fabrix_role_betriebsleiter") })
            end

            -- productivity: average of this factory's 3 shifts
            local productivitySum = 0
            for shift = 1, FabriX.worker.SHIFT_COUNT do
                productivitySum = productivitySum + (FabriX:getShiftProductivity(production, shift) or 0)
            end

            local avgShiftProductivity = productivitySum / FabriX.worker.SHIFT_COUNT

            -- idle = produces nothing right now, whatever the reason
            local status, partial, missing, low = FabriX:getProductionStatus(production)
            if status == "renovation" or status == "noStaff" or status == "noRecipe" or ((status == "missing" or status == "full") and not partial) then
                stats.idleFactories = stats.idleFactories + 1
            end

            if status ~= "running" and status ~= "renovation" then
                table.insert(stats.statusFactories, { name = name, status = status, partial = partial, missing = missing, low = low })
            end

            stats.avgProductivity = stats.avgProductivity + avgShiftProductivity

            -- accumulate property tax
            local tax = production.propertyTax or 0
            if FabriX:getRoleHolder(production, "betriebsleiter") then
                tax = tax * (1 - FabriX.FACTORY_MANAGER_TAX_DISCOUNT)
            end
            stats.propertyTaxSum = stats.propertyTaxSum + tax
            if production.autoMode then
                stats.autoFeeSum = (stats.autoFeeSum or 0) + FabriX.AUTO_MODE_FEE
            end
        end
    end

    if stats.productionCount > 0 then
        stats.avgProductivity = stats.avgProductivity / stats.productionCount
    end

    -- ---- Employees ----
    for catId, categoryList in pairs(FabriX.worker.employees or {}) do
        for _, worker in ipairs(categoryList) do
            if farmId ~= nil and worker.farmId == farmId then
                stats.workerTotal = stats.workerTotal + 1

                -- category grouping: Facharbeiter by level into Geselle/Meister/BL
                if catId == "facharbeiter" then
                    local rank = FabriX:getFacharbeiterRank(worker)
                    stats.countByCat[rank] = (stats.countByCat[rank] or 0) + 1
                elseif stats.countByCat[catId] ~= nil then
                    stats.countByCat[catId] = stats.countByCat[catId] + 1
                end

                -- assigned vs. free; in school or sick is neither (school counted in inSchoolCount)
                local isFree = FabriX:isWorkerFree(worker)

                if isFree then
                    stats.freeCount = stats.freeCount + 1
                elseif not worker.inSchool and not FabriX:isSick(worker) then
                    stats.assignedCount = stats.assignedCount + 1
                end

                if catId == "azubis" and isFree then
                    table.insert(stats.unassignedAzubis, { name = worker.name })
                end

                if FabriX:isSick(worker) then
                    table.insert(stats.sick, { name = worker.name, days = FabriX:getSickDaysLeft(worker) })
                end

                if worker.inSchool then stats.inSchoolCount = stats.inSchoolCount + 1 end
                if worker.pendingSchool then stats.pendingSchool = stats.pendingSchool + 1 end

                -- trainable: waiting for school, not already enrolled, not dismissed
                if FabriX:canStartSchool(worker) then
                    stats.trainableCount = stats.trainableCount + 1
                end

                -- resignation
                if worker.resignationGiven then
                    table.insert(stats.resigning, { name = worker.name, monthsLeft = worker.resignationMonthsLeft or 0 })
                end

                -- retiring soon? (within the next 12 months)
                local retirementMonths = FabriX.worker.RETIREMENT_AGE * 12
                local monthsLeft = retirementMonths - (worker.age or 0)

                if monthsLeft <= 12 and not worker.resignationGiven then
                    table.insert(stats.retiring,
                        { name = worker.name, monthsLeft = math.max(0, monthsLeft) })
                end
                stats.salarySum = stats.salarySum + (worker.salary or 0)
            end
        end
    end
    return stats
end

-- Writes the collected statistics into the overview UI elements and builds
-- the action-required alert list
function FabriXGui:refreshOverview()
    local stats = self:collectOverviewStats()

    local function setText(id, txt)
        local element = self:getDescendantById(id)
        if element ~= nil then
            element:setText(txt)
        end
    end

    setText("ovWorkerTotal", tostring(stats.workerTotal))
    setText("ovCountErntehelfer", tostring(stats.countByCat.erntehelfer))
    setText("ovCountGeselle", tostring(stats.countByCat.geselle))
    setText("ovCountMeister", tostring(stats.countByCat.meister))
    setText("ovCountBetriebsleiter", tostring(stats.countByCat.betriebsleiter))
    setText("ovCountAzubis", tostring(stats.countByCat.azubis))
    setText("ovAssigned", string.format("%d / %d", stats.assignedCount, stats.freeCount))
    setText("ovInSchool", tostring(stats.inSchoolCount))
    setText("ovSalarySum", g_i18n:formatMoney(stats.salarySum, 0, true, false))
    setText("ovProductionCount", tostring(stats.productionCount))
    setText("ovSlotsUsage", string.format("%d / %d", stats.totalSlots - stats.totalFreeSlots, stats.totalSlots))
    setText("ovTrainable", tostring(stats.trainableCount))
    setText("ovAvgProd", tostring(string.format("%.0f%%", stats.avgProductivity * 100)))
    setText("ovIdleFactories", tostring(stats.idleFactories))
    setText("ovPropertyTax", g_i18n:formatMoney(stats.propertyTaxSum, 0, true, false))
    setText("ovCostTotal", g_i18n:formatMoney(stats.salarySum + (stats.autoFeeSum or 0) + (stats.propertyTaxSum / 12), 0, true, false))

    local ratio = 0

    if stats.totalSlots > 0 then
        ratio = (stats.totalSlots - stats.totalFreeSlots) / stats.totalSlots
    end

    local barBg = self:getDescendantById("ovSlotBarBg")
    local barFill = self:getDescendantById("ovSlotBarFill")

    if barBg ~= nil and barFill ~= nil then
        local fullWidth = barBg.size[1]
        barFill:setSize(math.max(fullWidth * 0.01, fullWidth * ratio), barFill.size[2])
    end

    setText("ovSlotBarText", string.format("%.0f%%", ratio * 100))

    -- ---- Action-required list ----
    self.alertRows = {}

    for _, leader in ipairs(stats.missingLeaders) do
        table.insert(self.alertRows, { text = string.format(g_i18n:getText("fabrix_gui_alert_no_leader"), leader.name, leader.role), color = { 0.90, 0.30, 0.20, 1 }, })
    end

    -- red = produces nothing, orange = another recipe still runs, yellow = runs low
    for _, factory in ipairs(stats.statusFactories) do
        local isLow = factory.status == "low"
        local color = isLow and { 0.95, 0.75, 0.20, 1 } or factory.partial and { 0.95, 0.55, 0.20, 1 } or { 0.90, 0.30, 0.20, 1 }
        table.insert(self.alertRows, {
            text = string.format(g_i18n:getText("fabrix_gui_alert_status_" .. factory.status),
                factory.name, FabriX:getFillTypeTitles(isLow and factory.low or factory.missing)),
            color = color
        })

        if not isLow and #factory.low > 0 then
            table.insert(self.alertRows, { text = string.format(g_i18n:getText("fabrix_gui_alert_status_low"), factory.name, FabriX:getFillTypeTitles(factory.low)), color = { 0.95, 0.75, 0.20, 1 } })
        end
    end

    for _, factory in ipairs(stats.freeSlotFactories) do
        table.insert(self.alertRows,
            {
                text = string.format(g_i18n:getText("fabrix_gui_alert_free_slots"), factory.name, factory.free,
                    factory.total),
                color = { 0.95, 0.75, 0.20, 1 },
            })
    end

    for _, worker in ipairs(stats.resigning) do
        table.insert(self.alertRows,
            { text = string.format(g_i18n:getText("fabrix_gui_alert_leaving"), worker.name, worker.monthsLeft), color = { 0.95, 0.55, 0.20, 1 }, })
    end

    for _, worker in ipairs(stats.retiring) do
        local text
        if worker.monthsLeft <= 0 then
            text = string.format(g_i18n:getText("fabrix_gui_alert_retiring"), worker.name)
        else
            text =
                string.format(g_i18n:getText("fabrix_gui_alert_retiring_months"), worker.name, worker.monthsLeft)
        end
        table.insert(self.alertRows, { text = text, color = { 0.70, 0.50, 0.85, 1 }, })
    end

    for _, worker in ipairs(stats.unassignedAzubis) do
        table.insert(self.alertRows, {
            text = string.format(g_i18n:getText("fabrix_gui_alert_unassigned_azubi"), worker.name),
            color = { 0.30, 0.65, 1.00, 1 },
        })
    end

    for _, worker in ipairs(stats.sick) do
        table.insert(self.alertRows, {
            text = string.format(g_i18n:getText("fabrix_gui_alert_sick"), worker.name, worker.days),
            color = { 0.90, 0.30, 0.20, 1 }
        })
    end

    if stats.pendingSchool > 0 then
        table.insert(self.alertRows,
            { text = string.format(g_i18n:getText("fabrix_gui_alert_pending_school"), stats.pendingSchool), color = { 0.30, 0.65, 1.00, 1 }, })
    end

    if self.alertList ~= nil then
        self.alertList:reloadData()
    end

    self:refreshNotifyOptions()
end

function FabriXGui:refreshNotifyOptions()
    local options = {
        [FabriX.NOTIFY_GROUP.PROGRESS] = self.notifyProgressOption,
        [FabriX.NOTIFY_GROUP.SICKNESS] = self.notifySicknessOption,
        [FabriX.NOTIFY_GROUP.STAFF]    = self.notifyStaffOption
    }
    for group, option in pairs(options) do
        local isOn = FabriX:isNotificationEnabled(group)
        option:setIsChecked(isOn, true)
        FabriXGui.colorAutoModeSwitch(option, isOn)
    end
end

local function setNotify(option, group, state)
    local isOn = state == BinaryOptionElement.STATE_RIGHT
    FabriX:setNotificationEnabled(group, isOn)
    FabriXGui.colorAutoModeSwitch(option, isOn)
end

function FabriXGui:onClickNotifyProgress(state)
    setNotify(self.notifyProgressOption, FabriX.NOTIFY_GROUP.PROGRESS, state)
end

function FabriXGui:onClickNotifySickness(state)
    setNotify(self.notifySicknessOption, FabriX.NOTIFY_GROUP.SICKNESS, state)
end

function FabriXGui:onClickNotifyStaff(state)
    setNotify(self.notifyStaffOption, FabriX.NOTIFY_GROUP.STAFF, state)
end
