-- #######################################################################
-- FabriXGui - Job market tab (browse categories, hire available workers)
-- Part of the FabriXGui class defined in FabriXGui.lua.
-- #######################################################################
-- =========================================================================
-- Data: job market
-- =========================================================================
function FabriXGui:populateCategories()
    if self.selectedCategoryIndex == nil or self.selectedCategoryIndex < 1 or self.selectedCategoryIndex > #self.categoryRows then
        self.selectedCategoryIndex = 1
    end

    self.selectedCategoryId = self.categoryRows[self.selectedCategoryIndex].id

    if self.categoryList ~= nil then
        self:reloadList(self.categoryList, 1, self.selectedCategoryIndex)
    end
end

function FabriXGui:populateWorkerMarket()
    local catId = self.selectedCategoryId or "erntehelfer"
    self.workerRows = FabriX:getMarket(g_currentMission:getFarmId())[catId] or {}

    if self.selectedWorkerIndex == nil or self.selectedWorkerIndex < 1 or self.selectedWorkerIndex > #self.workerRows then
        self.selectedWorkerIndex = 1
    end

    if self.workerMarketList ~= nil then
        self:reloadList(self.workerMarketList, 1, #self.workerRows > 0 and self.selectedWorkerIndex or nil)
    end

    if self.workerEmptyText ~= nil then
        local isEmpty = #self.workerRows == 0
        self.workerEmptyText:setVisible(isEmpty)

        if isEmpty then
            self.workerEmptyText:setText(g_i18n:getText("fabrix_gui_market_empty_" .. catId))
        end
    end

    if #self.workerRows > 0 then
        self.selectedWorker = self.workerRows[self.selectedWorkerIndex]
    else
        self.selectedWorker = nil
    end

    if self.hireButton ~= nil then
        self.hireButton:setVisible(self.selectedWorker ~= nil)
    end
end

-- =========================================================================
-- Job market: category + worker callbacks
-- =========================================================================
function FabriXGui:onCategorySelected(list, section, index)
    -- programmatic re-selection of the same row keeps the selected worker
    if index == self.selectedCategoryIndex then return end

    self.selectedCategoryIndex = index
    self.selectedCategoryId = self.categoryRows[index].id
    self.selectedWorkerIndex = 1
    self:populateWorkerMarket()
end

function FabriXGui:onCategoryClicked(list, section, index)
    self:onCategorySelected(list, section, index)
end

function FabriXGui:updateWorkerSelection(index)
    self.selectedWorkerIndex = index
    local worker = self.workerRows[index]
    self.selectedWorker = worker
    if self.hireButton ~= nil then
        self.hireButton:setVisible(worker ~= nil)
    end
end

function FabriXGui:onWorkerSelected(list, section, index)
    self:updateWorkerSelection(index)
end

function FabriXGui:onWorkerClicked(list, section, index, cell)
    self:updateWorkerSelection(index)
end

-- =========================================================================
-- Hiring flow
-- =========================================================================
function FabriXGui:onClickHire()
    local worker = self.selectedWorker

    if worker == nil then return end

    local years = FabriX:getAgeInYearsFromWorker(worker) or 0
    local salary = worker.salary or 0

    local text = string.format(g_i18n:getText("fabrix_gui_hire_confirm"), tostring(worker.name), worker.level or 0, years,
        g_i18n:formatMoney(salary, 0, true, false), g_i18n:formatMoney(FabriX.worker.HIRE_FEE, 0, true, false))

    self.pendingHireWorker = worker

    YesNoDialog.show(self.onHireWorkerDialogCallback, self, text, g_i18n:getText("fabrix_gui_hire_title"))
end

function FabriXGui:onHireWorkerDialogCallback(yes)
    local worker = self.pendingHireWorker
    self.pendingHireWorker = nil

    if not yes or worker == nil then return end

    self:hireWorker(worker)
end

function FabriXGui:hireWorker(worker)
    if not FabriXGui.hasMoney(FabriX.worker.HIRE_FEE, "fabrix_gui_hire_no_money") then return end

    FabriX:runAction("hire", worker.id, worker.category)
end
