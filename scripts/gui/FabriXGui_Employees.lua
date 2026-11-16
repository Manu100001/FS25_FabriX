-- #######################################################################
-- FabriXGui - Employees tab (worker pool list, filters, detail panel,
-- fire/train actions). Part of the FabriXGui class defined in FabriXGui.lua
-- #######################################################################
-- =========================================================================
-- Data: worker pool (employees)
-- =========================================================================
function FabriXGui:populatePoolCategories()
    if self.selectedPoolCategoryIndex == nil or self.selectedPoolCategoryIndex < 1 or self.selectedPoolCategoryIndex > #self.poolCategoryRows then
        self.selectedPoolCategoryIndex = 1
    end

    self.selectedPoolCategoryId = self.poolCategoryRows[self.selectedPoolCategoryIndex].id

    if self.poolCategoryList ~= nil then
        local section, index = FabriXGui.poolSectionOf(self.selectedPoolCategoryIndex)
        self:reloadList(self.poolCategoryList, section, index)
    end

    self:refreshFilterButtons()
    self:updateLevelSelector()
end

function FabriXGui:populatePoolWorkers()
    local cat = self.poolCategoryRows[self.selectedPoolCategoryIndex] or self.poolCategoryRows[1]

    -- only the own farm; extra views by their match, Facharbeiter additionally by the active filter
    local farmId = g_currentMission:getFarmId()

    self.poolWorkerRows = {}
    local total = 0

    for _, sourceList in ipairs(FabriXGui.getPoolSourceLists(cat)) do
        for _, worker in ipairs(sourceList) do
            if worker.farmId == farmId and (cat.match == nil or cat.match(worker)) then
                total = total + 1

                if (self.poolLevel == nil or worker.level == self.poolLevel) and (cat.id ~= "facharbeiter" or self:workerMatchesFilter(worker)) then
                    table.insert(self.poolWorkerRows, worker)
                end
            end
        end
    end

    -- filters only when the list has workers at all
    if self.poolLevelBox ~= nil then
        self.poolLevelBox:setVisible(total > 0)
    end

    if self.poolFilterBox ~= nil then
        self.poolFilterBox:setVisible(total > 0 and cat.id == "facharbeiter")
        if total > 0 then
            self.poolFilterBox:invalidateLayout()
        end
    end

    if self.selectedPoolWorkerIndex == nil or self.selectedPoolWorkerIndex < 1 or self.selectedPoolWorkerIndex > #self.poolWorkerRows then
        self.selectedPoolWorkerIndex = 1
    end

    if self.poolWorkerList ~= nil then
        self:reloadList(self.poolWorkerList, 1, #self.poolWorkerRows > 0 and self.selectedPoolWorkerIndex or nil)
        if #self.poolWorkerRows > 0 then
            self:showEmployeeDetail(self.poolWorkerRows[self.selectedPoolWorkerIndex])
        else
            self:showEmployeeDetail(nil)
        end
    end

    if self.poolEmptyText ~= nil then
        self.poolEmptyText:setVisible(#self.poolWorkerRows == 0)
        self.poolEmptyText:setText(g_i18n:getText(total > 0 and "fabrix_gui_pool_empty_filter" or "fabrix_gui_pool_empty"))
    end
end

-- =========================================================================
-- Worker pool: category + worker callbacks
-- =========================================================================
function FabriXGui:onPoolCategorySelected(list, section, index)
    local rowIndex = FabriXGui.poolRowIndex(section, index)

    -- programmatic re-selection of the same row
    if rowIndex == self.selectedPoolCategoryIndex then return end

    self.selectedPoolCategoryIndex = rowIndex
    self.selectedPoolCategoryId = self.poolCategoryRows[self.selectedPoolCategoryIndex].id
    self.selectedPoolWorkerIndex = 1
    self.poolFilter = "all"
    self.poolLevel = nil
    self:updateLevelSelector()
    self:refreshFilterButtons()
    self:populatePoolWorkers()
end

function FabriXGui:onPoolCategoryClicked(list, section, index)
    self:onPoolCategorySelected(list, section, index)
end

function FabriXGui:onPoolWorkerSelected(list, section, index)
    self.selectedPoolWorkerIndex = index
    self:showEmployeeDetail(self.poolWorkerRows[index])
end

function FabriXGui:onPoolWorkerClicked(list, section, index)
    self:onPoolWorkerSelected(list, section, index)
end

-- =========================================================================
-- Employee detail panel (right side of the employees tab)
-- =========================================================================
-- Fills the detail panel with an employee's data (or hides it)
function FabriXGui:showEmployeeDetail(worker)
    if self.employeeDetailContainer == nil then return end

    -- no worker or other tab active (hidden list can still fire selection) -> disable panel
    if worker == nil or self.currentTab ~= FabriXGui.TAB_EMPLOYEES then
        self.employeeDetailContainer:setVisible(false)
        if self.fireButton ~= nil then
            self.fireButton:setVisible(false)
        end

        if self.trainButton ~= nil then
            self.trainButton:setVisible(false)
        end

        return
    end

    self.employeeDetailContainer:setVisible(true)

    -- ---- Portrait ----
    local portrait = self:getDescendantById("detailPortrait")
    if portrait ~= nil then
        if worker.icon ~= nil and worker.icon ~= "" then
            portrait:setImageFilename(worker.icon)
            portrait:setImageColor(nil, 1, 1, 1, 1)
            portrait:setVisible(true)
        else
            portrait:setVisible(false)
        end
    end

    -- ---- Name + title ----
    local nameEl = self:getDescendantById("detailName")
    if nameEl ~= nil then
        nameEl:setText(tostring(worker.name))
    end

    local catEl = self:getDescendantById("detailCategory")
    if catEl ~= nil then
        catEl:setText(FabriX:getWorkerRole(worker))
    end

    -- ---- Compute values ----
    local years = FabriX:getAgeInYearsFromWorker(worker)
    local hired = FabriX:getEmploymentText(worker)
    local salary = worker.salary or 0
    local productivity = FabriX:getWorkerProductivity(worker) or 1.0
    local curXp, maxXp, ratio = FabriX:getWorkerXpProgress(worker)

    -- "Assigned" text: factory + shift, otherwise "unassigned"
    local assignText = g_i18n:getText("fabrix_gui_detail_unassigned")

    if worker.factoryId ~= nil and worker.factoryId ~= "" then
        local factoryName = "?"
        for _, p in pairs(FabriX.productions or {}) do
            if p.id == worker.factoryId then
                factoryName = FabriX:getProductionName(p)
                break
            end
        end

        local shiftNames = {
            [1] = g_i18n:getText("fabrix_gui_shift_early"),
            [2] = g_i18n:getText("fabrix_gui_shift_day"),
            [3] = g_i18n:getText("fabrix_gui_shift_late"),
        }

        -- leadership slot instead of a shift
        local hasRole = worker.roleSlot ~= nil and worker.roleSlot ~= ""
        local shiftText = hasRole and g_i18n:getText("fabrix_role_" .. worker.roleSlot) or shiftNames[worker.shiftId] or string.format(g_i18n:getText("fabrix_gui_shift_generic"), worker.shiftId or 0)

        assignText = string.format("%s (%s)", factoryName, shiftText)
    end

    -- If in school: override status
    if worker.inSchool then
        local monthsLeft = FabriX:getSchoolMonthsLeft(worker)
        if monthsLeft > 0 then
            assignText = string.format(g_i18n:getText("fabrix_gui_detail_in_training_months"), monthsLeft)
        else
            assignText = g_i18n:getText("fabrix_gui_detail_in_training")
        end
    end

    if FabriX:isSick(worker) then
        assignText = string.format(g_i18n:getText("fabrix_gui_detail_sick_days"), FabriX:getSickDaysLeft(worker))
    end

    -- ---- Write values into the (fixed-position) value elements ----
    local function setVal(id, txt)
        local element = self:getDescendantById(id)
        if element ~= nil then
            element:setText(txt)
        end
    end

    setVal("detailAge", string.format(g_i18n:getText("fabrix_worker_years"), years or 0))
    setVal("detailLevel", string.format("%d", worker.level or 0))
    setVal("detailProductivity", string.format("%.0f%%", productivity * 100))
    setVal("detailHired", hired)
    setVal("detailAssign", assignText)
    setVal("detailSalary", string.format(g_i18n:getText("fabrix_gui_salary_per_month"), g_i18n:formatMoney(salary, 0, true, false)))

    local assignEl = self:getDescendantById("detailAssign")

    if assignEl ~= nil then
        if FabriX:isSick(worker) then
            assignEl:setTextColor(0.90, 0.30, 0.20, 1)
        elseif worker.inSchool then
            assignEl:setTextColor(0.30, 0.65, 1, 1)
        else
            assignEl:setTextColor(1, 1, 1, 1)
        end
    end

    -- ---- Notice-status row ----
    local noticeLabelEl = self:getDescendantById("detailNoticeLabel")
    local noticeValueEl = self:getDescendantById("detailNotice")

    if worker.resignationGiven then
        if noticeLabelEl ~= nil then
            noticeLabelEl:setVisible(true)
        end

        if noticeValueEl ~= nil then
            noticeValueEl:setVisible(true)

            local noticeKey = worker.selfResigned and "fabrix_gui_detail_self_resigned_months" or "fabrix_gui_detail_dismissed_months"

            noticeValueEl:setText(string.format(g_i18n:getText(noticeKey), worker.resignationMonthsLeft or 0))
            noticeValueEl:setTextColor(0.95, 0.55, 0.20, 1) -- orange
        end
    else
        if noticeLabelEl ~= nil then
            noticeLabelEl:setVisible(false)
        end
        if noticeValueEl ~= nil then
            noticeValueEl:setVisible(false)
        end
    end

    -- ---- XP bar ----
    local barBg = self:getDescendantById("detailXPBarBg")
    local barFill = self:getDescendantById("detailXPBarFill")

    if barBg ~= nil and barFill ~= nil then
        local fullW = barBg.size[1]
        local fillW = math.max(fullW * 0.01, fullW * ratio)
        barFill:setSize(fillW, barFill.size[2])
    end

    local barText = self:getDescendantById("detailXPText")
    if barText ~= nil then
        -- max level (no further XP target) -> show the collected XP only
        if maxXp <= 0 then
            barText:setText(string.format(g_i18n:getText("fabrix_gui_xp"), curXp))
        else
            barText:setText(string.format(g_i18n:getText("fabrix_gui_xp_progress"), curXp, maxXp))
        end
    end

    -- ---- Dismiss / withdraw button ----
    if self.fireButton ~= nil then
        if worker.category == "azubis" then
            -- Apprentices cannot be dismissed -> hide button
            self.fireButton:setVisible(false)
        elseif worker.resignationGiven then
            -- Already dismissed -> button becomes "withdraw"
            self.fireButton:setVisible(not worker.counterOfferRejected)
            self.fireButton:setText(g_i18n:getText(worker.selfResigned and "fabrix_gui_btn_counter_offer" or "fabrix_gui_btn_withdraw_notice"))
        else
            -- Normally dismissible
            self.fireButton:setVisible(true)
            self.fireButton:setText(g_i18n:getText("fabrix_gui_btn_dismiss"))
        end
    end

    -- ---- Train button ----
    if self.trainButton ~= nil then
        local canTrain = FabriX:canStartSchool(worker)
        self.trainButton:setVisible(canTrain)
        if canTrain then
            self.trainButton:setText(string.format(g_i18n:getText("fabrix_gui_btn_train"), FabriX:getSchoolMonths(worker)))
        end
    end
end

function FabriXGui:onClickFireEmployee()
    local worker = self.poolWorkerRows[self.selectedPoolWorkerIndex]

    if worker == nil then return end

    -- Apprentices: cannot be dismissed at all
    if worker.category == "azubis" then
        InfoDialog.show(g_i18n:getText("fabrix_gui_azubi_no_dismiss"))
        return
    end

    if worker.resignationGiven then
        if worker.selfResigned then
            local cfg = FabriX.worker
            local options, raises = {}, {}
            for raise = cfg.COUNTER_OFFER_RAISE_MIN, cfg.COUNTER_OFFER_RAISE_MAX, cfg.COUNTER_OFFER_RAISE_STEP do
                table.insert(raises, raise)
                table.insert(options, string.format(g_i18n:getText("fabrix_gui_counter_offer_option"), raise, g_i18n:formatMoney(FabriX:getCounterOfferSalary(worker, raise), 0, true, false)))
            end

            OptionDialog.show(function(index) self:onSelectCounterOffer(worker, raises[index]) end,
                string.format(g_i18n:getText("fabrix_gui_counter_offer_text"), tostring(worker.name)), g_i18n:getText("fabrix_gui_counter_offer_title"), options)
            return
        end

        -- withdraw dismissal (chargeable)
        self.pendingWithdrawWorker = worker
        local fee = FabriX:getWithdrawFee(worker)

        YesNoDialog.show(self.onConfirmWithdrawResignation, self, string.format(g_i18n:getText("fabrix_gui_withdraw_confirm"), tostring(worker.name),
            g_i18n:formatMoney(fee, 0, true, false)), g_i18n:getText("fabrix_gui_withdraw_title"))
    else
        --dismiss
        self.pendingFireWorker = worker
        local severance = FabriX:getSeverance(worker)

        YesNoDialog.show(self.onConfirmFireEmployee, self, string.format(g_i18n:getText("fabrix_gui_dismiss_confirm"),
            tostring(worker.name), FabriX:getNoticeText(worker), g_i18n:formatMoney(severance, 0, true, false)), g_i18n:getText("fabrix_gui_dismiss_title"))
    end
end

function FabriXGui:onConfirmFireEmployee(yes)
    local worker = self.pendingFireWorker
    self.pendingFireWorker = nil

    if not yes or worker == nil then return end

    FabriX:runAction("dismiss", worker.id)
end

function FabriXGui:onConfirmWithdrawResignation(yes)
    local worker = self.pendingWithdrawWorker
    self.pendingWithdrawWorker = nil

    if not yes or worker == nil then return end

    if not FabriXGui.hasMoney(FabriX:getWithdrawFee(worker), "fabrix_gui_withdraw_no_money") then return end

    FabriX:runAction("withdrawResignation", worker.id)
end

function FabriXGui:onSelectCounterOffer(worker, raise)
    -- raise == nil: dialog cancelled
    if raise == nil then return end

    self.pendingCounterOfferId = worker.id

    if FabriX:runAction("counterOffer", worker.id, raise) == false then
        self.pendingCounterOfferId = nil
    end
end

function FabriXGui:onClickTrainEmployee()
    local worker = self.poolWorkerRows[self.selectedPoolWorkerIndex]

    if worker == nil then return end
    if not FabriX:canStartSchool(worker) then return end

    local nextDef = FabriX.worker.LEVELS_FACHARBEITER[(worker.level or 1) + 1]
    local nextRole = nextDef and g_i18n:getText(nextDef.role) or "?"
    local fee = FabriX:getSchoolFee(worker)
    local months = FabriX:getSchoolMonths(worker)

    self.pendingTrainWorker = worker
    YesNoDialog.show(self.onConfirmTrainEmployee, self, string.format(g_i18n:getText("fabrix_gui_train_confirm"),
        tostring(worker.name), months, nextRole, g_i18n:formatMoney(fee, 0, true, false)), g_i18n:getText("fabrix_gui_train_title"))
end

function FabriXGui:onConfirmTrainEmployee(yes)
    local worker = self.pendingTrainWorker
    self.pendingTrainWorker = nil

    if not yes or worker == nil then return end
    -- Safety net: status could have changed
    if not FabriX:canStartSchool(worker) then return end

    if not FabriXGui.hasMoney(FabriX:getSchoolFee(worker), "fabrix_gui_train_no_money") then return end

    FabriX:runAction("train", worker.id)
end

-- Resets the filter outside the skilled-worker view, updates counts and highlight
function FabriXGui:refreshFilterButtons()
    local show = (self.selectedPoolCategoryId == "facharbeiter")

    if not show then self.poolFilter = "all" end

    if show then self:updateFilterCounts() end

    self:highlightActiveFilter()
end

-- "Gesellen (5)" etc. for the own farm
function FabriXGui:updateFilterCounts()
    local farmId = g_currentMission:getFarmId()
    local buttons = {
        geselle = { self.poolFilterGeselle, "fabrix_gui_filter_geselle" },
        meister = { self.poolFilterMeister, "fabrix_gui_filter_meister" },
        bl = { self.poolFilterBl, "fabrix_gui_filter_betriebsleiter" },
    }

    for filterId, entry in pairs(buttons) do
        local count = 0
        for _, worker in ipairs(FabriX.worker.employees.facharbeiter or {}) do
            if worker.farmId == farmId and self:workerMatchesFilter(worker, filterId) then
                count = count + 1
            end
        end

        if entry[1] ~= nil then
            entry[1]:setText(string.format("%s (%d)", g_i18n:getText(entry[2]), count))
        end
    end
end

-- linear colors: green fill of the selected list cell, dark cell, text colors
local FILTER_COLORS = {
    activeBg = { 0.284, 0.479, 0.005, 1 },
    bg = { 0.033, 0.033, 0.033, 1 },
    activeText = { 0.02, 0.02, 0.02, 1 },
    text = { 1, 1, 1, 1 },
    hover = { 0.68, 0.96, 0.08, 1 }
}
-- Highlights the active filter button (green fill, dark text), others dark with white text
function FabriXGui:highlightActiveFilter()
    local filterButtons = {
        all = self.poolFilterAll,
        geselle = self.poolFilterGeselle,
        meister = self.poolFilterMeister,
        bl = self.poolFilterBl,
    }

    for filterId, button in pairs(filterButtons) do
        if button ~= nil then
            local active = filterId == self.poolFilter
            local bg = active and FILTER_COLORS.activeBg or FILTER_COLORS.bg

            if button.overlay ~= nil and button.overlay.color ~= nil then
                for i = 1, 4 do
                    button.overlay.color[i] = bg[i]
                end
            end

            -- active filter keeps its green while focused/hovered/pressed
            local overlay = button.overlay

            if overlay ~= nil then
                overlay.fabrixDefault = overlay.fabrixDefault or { focused = overlay.colorFocused, highlighted = overlay.colorHighlighted, pressed = overlay.colorPressed }
                overlay.colorFocused = active and bg or overlay.fabrixDefault.focused
                overlay.colorHighlighted = active and bg or overlay.fabrixDefault.highlighted
                overlay.colorPressed = active and bg or overlay.fabrixDefault.pressed
            end

            button:setTextColor(unpack(active and FILTER_COLORS.activeText or FILTER_COLORS.text))
            -- active stays dark on hover, otherwise green text on green fill
            button.textFocusedColor = active and FILTER_COLORS.activeText or FILTER_COLORS.hover
            button.textHighlightedColor = button.textFocusedColor
        end
    end
end

-- Decides whether a skilled worker matches the current filter
function FabriXGui:workerMatchesFilter(worker, filterId)
    local filter = filterId or self.poolFilter or "all"

    if filter == "all" then return true end

    local rank = FabriX:getFacharbeiterRank(worker)
    return rank == filter or (filter == "bl" and rank == "betriebsleiter")
end

-- Filter button handler
function FabriXGui:setPoolFilter(filterId)
    self.poolFilter = filterId
    self.selectedPoolWorkerIndex = 1
    self:highlightActiveFilter()
    self:populatePoolWorkers()
end

function FabriXGui:onClickFilterAll() self:setPoolFilter("all") end

function FabriXGui:onClickFilterGeselle() self:setPoolFilter("geselle") end

function FabriXGui:onClickFilterMeister() self:setPoolFilter("meister") end

function FabriXGui:onClickFilterBl() self:setPoolFilter("bl") end

-- level range per worker category, for the level selector
local LEVEL_RANGE = {
    erntehelfer = { 1, FabriX.worker.MAX_WORKER_LEVEL },
    facharbeiter = { FabriX.worker.AZUBI_GRADUATE_LEVEL, FabriX.worker.MAX_WORKER_LEVEL },
    azubis = { 1, FabriX.worker.AZUBI_GRADUATE_LEVEL - 1 },
}

function FabriXGui:updateLevelSelector()
    if self.poolLevelButton == nil then return end

    self.poolLevelButton:setText(self.poolLevel == nil and g_i18n:getText("fabrix_gui_level_all") or string.format(g_i18n:getText("fabrix_gui_level"), self.poolLevel))
end

-- steps through Alle, min..max, Alle
function FabriXGui:stepPoolLevel(step)
    local cat = self.poolCategoryRows[self.selectedPoolCategoryIndex] or self.poolCategoryRows[1]
    local range = (not cat.sources and LEVEL_RANGE[cat.source or cat.id]) or LEVEL_RANGE.erntehelfer
    local level = (self.poolLevel or (step > 0 and range[1] - 1 or range[2] + 1)) + step

    self.poolLevel = (level >= range[1] and level <= range[2]) and level or nil
    self.selectedPoolWorkerIndex = 1
    self:updateLevelSelector()
    self:populatePoolWorkers()
end

function FabriXGui:onClickLevelPrev()
    self:stepPoolLevel(-1)
end

function FabriXGui:onClickLevelNext()
    self:stepPoolLevel(1)
end

-- result window for the acting player, once the synced state shows the decision
function FabriXGui:checkCounterOfferResult()
    if self.pendingCounterOfferId == nil then return end

    local worker = FabriX:findEmployee(g_currentMission:getFarmId(), self.pendingCounterOfferId)

    if worker == nil then
        self.pendingCounterOfferId = nil
        return
    end

    local key = (worker.counterOfferRejected and "fabrix_worker_counter_offer_rejected") or (not worker.selfResigned and "fabrix_worker_counter_offer_accepted")

    if not key then return end -- not decided yet (other sync arrived first)

    self.pendingCounterOfferId = nil
    InfoDialog.show(string.format(g_i18n:getText(key), FabriX:getWorkerTitle(worker)))
end
