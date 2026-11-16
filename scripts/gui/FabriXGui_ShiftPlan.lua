-- #######################################################################
-- FabriXGui - Shift plan tab (production list, shift slots, worker and
-- leadership assignment). Part of the FabriXGui class defined in FabriXGui.lua
-- #######################################################################
-- =========================================================================
-- Data: shift-plan / production list
-- =========================================================================
local function setRoleColor(xpEl, worker)
    if worker.category == "azubis" then
        xpEl:setTextColor(0.95, 0.75, 0.20, 1) -- yellow-orange
    elseif worker.category == "facharbeiter" then
        local rank = FabriX:getFacharbeiterRank(worker)
        if rank == "betriebsleiter" then
            xpEl:setTextColor(0.95, 0.45, 0.55, 1) -- rose
        elseif rank == "meister" then
            xpEl:setTextColor(0.75, 0.55, 0.95, 1) -- violet
        else
            xpEl:setTextColor(0.40, 0.70, 0.95, 1) -- light blue
        end
    else
        xpEl:setTextColor(0.55, 0.90, 0.45, 1) -- light green
    end
end

local function getFactoryWorkers(farmId, factoryId)
    local any, onShift = false, false
    for _, list in pairs(FabriX.worker.employees or {}) do
        for _, worker in ipairs(list) do
            if worker.farmId == farmId and worker.factoryId == factoryId then
                any = true
                onShift = onShift or FabriX:isWorkerOnShift(worker)
            end
        end
    end

    return any, onShift
end

local function updateUpgradeBar(self, production)
    if self.upgradeXpText == nil or self.upgradeRenoText == nil or self.upgradeBarBg == nil or self.upgradeBarFill == nil then return end

    local onRenovation = production.isOnUpgrade == true
    self.upgradeRenoText:setVisible(onRenovation)
    self.upgradeBarBg:setVisible(not onRenovation)

    if onRenovation then
        local green = { 0.627, 0.761, 0.075, 1 }
        self.upgradeXpText:setText(g_i18n:getText("fabrix_upgrade_factory_onRenovation1"))
        self.upgradeXpText:setTextColor(unpack(green))
        self.upgradeRenoText:setText(string.format(g_i18n:getText("fabrix_upgrade_factory_onRenovation2"), FabriX:getRenovationHours(production)))
        self.upgradeRenoText:setTextColor(unpack(green))
        return
    end

    local text, isMax, ratio = FabriX:getXpText(production)
    self.upgradeXpText:setText(text)

    if isMax then
        self.upgradeXpText:setTextColor(1.0, 0.65, 0.05, 1)
    else
        self.upgradeXpText:setTextColor(1, 1, 1, 1)
    end

    -- bar as wide as the text (fixed width if the engine lacks getTextWidth)
    local width = self.upgradeXpText.getTextWidth ~= nil and self.upgradeXpText:getTextWidth() or self.upgradeBarBg.size[1]
    self.upgradeBarBg:setSize(width, self.upgradeBarBg.size[2])
    self.upgradeBarFill:setSize(width * math.min(math.max(ratio, 0), 1), self.upgradeBarFill.size[2])
end

function FabriXGui:refreshProductions()
    self.rows = {}
    local farmId = g_currentMission ~= nil and g_currentMission:getFarmId() or nil

    for _, production in ipairs(FabriX.productions or {}) do
        if farmId ~= nil and production.farmId == farmId then
            table.insert(self.rows, production)
        end
    end

    table.sort(self.rows,
        function(a, b)
            local nameA = FabriX:getProductionName(a)
            local nameB = FabriX:getProductionName(b)
            return nameA:lower() < nameB:lower()
        end)

    -- keep the selected factory selected when the list changes (sync, bought/sold factory)
    if self.selectedProduction ~= nil then
        for i, production in ipairs(self.rows) do
            if production.id == self.selectedProduction.id then
                self.selectedIndex = i
                break
            end
        end
    end

    if self.selectedIndex == nil or self.selectedIndex < 1 or self.selectedIndex > #self.rows then
        self.selectedIndex = 1
    end

    if self.emptyText ~= nil then
        self.emptyText:setVisible(#self.rows == 0)
    end

    if self.productionList ~= nil then
        self:reloadList(self.productionList, 1, #self.rows > 0 and self.selectedIndex or nil)
    end

    if #self.rows > 0 then
        self.selectedProduction = self.rows[self.selectedIndex]
        self:showShiftPlan(self.selectedProduction)
    else
        self.selectedProduction = nil
        self:showShiftPlan(nil)
    end
end

-- =========================================================================
-- Production list callbacks
-- =========================================================================
function FabriXGui:onProductionSelected(list, section, index)
    -- focus enter reports the current selection again
    if self.rows[index] == self.selectedProduction then return end

    self.selectedIndex = index
    self.selectedProduction = self.rows[index]
    self:showShiftPlan(self.selectedProduction)
end

-- =========================================================================
-- Shift plan (right side of the shift-plan tab)
-- =========================================================================
-- teleport position of the factory's map hotspot; nil if none or the player sits in a vehicle
local function getVisitPosition(production)
    local placeable = production ~= nil and production.placeable

    local hotspot = placeable and placeable.getHotspot ~= nil and placeable:getHotspot(1)

    if not hotspot or hotspot.getTeleportWorldPosition == nil or g_localPlayer == nil or g_localPlayer:getCurrentVehicle() ~= nil then
        return nil
    end

    return hotspot:getTeleportWorldPosition()
end


function FabriXGui:showShiftPlan(production)
    if self.shiftPane == nil then return end

    if production == nil then
        self.shiftPane:setVisible(false)

        if self.clearShiftsButton ~= nil then
            self.clearShiftsButton:setVisible(false)
        end

        if self.visitButton ~= nil then
            self.visitButton:setVisible(false)
        end

        if self.upgradeButton ~= nil then
            self.upgradeButton:setVisible(false)
        end
        return
    end

    self.shiftPane:setVisible(true)
    self.selectedProduction = production

    for shift = 1, FabriX.worker.SHIFT_COUNT do
        local factor = FabriX:getShiftProductivity(production, shift)
        local element = self:getDescendantById("shiftProductivity" .. shift)

        if element ~= nil then
            element:setText(string.format("%.0f%%", factor * 100))

            if factor <= 0 then
                element:setTextColor(0.90, 0.30, 0.20, 1)
            elseif factor < 1.0 then
                element:setTextColor(0.95, 0.75, 0.20, 1)
            else
                element:setTextColor(0.68, 0.96, 0.08, 1)
            end
        end
    end

    local name = FabriX:getProductionName(production)
    if self.shiftFactoryName ~= nil then
        self.shiftFactoryName:setText(tostring(name) .. " - " .. string.format(g_i18n:getText("fabrix_gui_level"), production.level or 1))
    end

    if self.autoModeBox ~= nil then
        self.autoModeBox:setVisible((production.level or 1) >= FabriX.AUTO_MODE_MIN_LEVEL)
        self.autoModeOption:setIsChecked(production.autoMode == true, true)
        FabriXGui.colorAutoModeSwitch(self.autoModeOption, production.autoMode == true)
    end

    updateUpgradeBar(self, production)

    if self.upgradeButton ~= nil then
        self.upgradeButton:setVisible((production.level or 1) < FabriX.MAX_LEVEL and not production.isOnUpgrade)
    end

    if self.clearShiftsButton ~= nil then
        self.clearShiftsButton:setVisible((getFactoryWorkers(g_currentMission:getFarmId(), production.id)))
    end

    if self.visitButton ~= nil then
        self.visitButton:setVisible(getVisitPosition(production) ~= nil)
    end

    local slotCount = FabriX:getSlotsPerShift(production)
    local farmId = g_currentMission:getFarmId()
    local factoryId = production.id

    for shift = 1, FabriX.worker.SHIFT_COUNT do
        local layout = self:getDescendantById("shiftSlots" .. shift)
        if layout ~= nil then
            while #layout.elements > 0 do layout.elements[1]:delete() end

            -- Fetch the actual assignment of this shift from the pool
            local assigned = FabriX:getAssignedWorkers(farmId, factoryId, shift)

            for slotIndex = 1, slotCount do
                local slot = self.helperSlotTemplate:clone(layout)
                slot:setVisible(true)
                slot.fabrixShift = shift
                slot.fabrixSlot = slotIndex
                slot.fabrixProduction = production

                local worker = assigned[slotIndex]
                local nameEl = slot:getDescendantByName("helperName")
                local levelEl = slot:getDescendantByName("helperLevel")
                local xpEl = slot:getDescendantByName("helperXP")
                local iconEl = slot:getDescendantByName("helperIcon")
                local bgEl = slot:getDescendantByName("bg")

                if worker ~= nil then -- Occupied: darker neutral background, bright name
                    if bgEl ~= nil then bgEl:setImageColor(nil, 0.10, 0.11, 0.10, 0.95) end
                    if nameEl ~= nil then
                        nameEl:setText(tostring(worker.name))
                        nameEl:setTextColor(0.88, 0.90, 0.86, 1)
                    end

                    if levelEl ~= nil then
                        levelEl:setText(string.format(g_i18n:getText("fabrix_gui_level"),
                            worker.level or 0))
                    end

                    if xpEl ~= nil then
                        xpEl:setText(FabriX:getWorkerRole(worker))
                        setRoleColor(xpEl, worker)
                    end

                    if iconEl ~= nil then
                        if worker.icon ~= nil and worker.icon ~= "" then
                            iconEl:setImageFilename(worker.icon)
                            iconEl:setImageColor(nil, 1, 1, 1, 1)
                            iconEl:setVisible(true)
                        else
                            iconEl:setVisible(false)
                        end
                    end
                else
                    -- Empty: greenish highlight, green "+ free" text
                    if bgEl ~= nil then
                        bgEl:setImageColor(nil, 0.16, 0.22, 0.10, 0.90)
                    end

                    if nameEl ~= nil then
                        nameEl:setText(g_i18n:getText("fabrix_gui_slot_free"))
                        nameEl:setTextColor(0.68, 0.96, 0.08, 1) -- green
                    end

                    if levelEl ~= nil then
                        levelEl:setText("")
                    end

                    if xpEl ~= nil then
                        xpEl:setText("")
                    end

                    if iconEl ~= nil then
                        iconEl:setVisible(false)
                    end
                end
            end
            layout:invalidateLayout()
        end
    end

    -- Render leadership slots (Meister from lvl 3, BL from lvl 5)
    self:showLeadershipSlots(production)
end

function FabriXGui:onSlotClicked(button)
    local production = button.fabrixProduction

    if production == nil then return end

    if button.fabrixRoleSlot ~= nil then
        self:onRoleSlotClicked(button)
        return
    end

    local shiftId = button.fabrixShift
    local slotId = button.fabrixSlot

    if shiftId == nil or slotId == nil then return end

    local farmId = g_currentMission:getFarmId()
    local factoryId = production.id
    local assigned = FabriX:getAssignedWorkers(farmId, factoryId, shiftId)
    local current = assigned[slotId]

    if current ~= nil then -- Occupied slot -> confirm removal
        self.pendingRemoveWorker = current
        self.selectedProduction = production
        local text = string.format(g_i18n:getText("fabrix_gui_remove_shift_confirm"), tostring(current.name))

        -- is he taken off the running shift?
        if FabriX:isWorkerOnShift(current) then
            text = text .. "\n\n" .. g_i18n:getText("fabrix_gui_remove_shift_warning")
        end

        YesNoDialog.show(self.onConfirmRemoveWorker, self, text, g_i18n:getText("fabrix_gui_remove_shift_title"))
    else
        -- Empty slot -> remember, then choose category
        self.pendingSlot = { factoryId = factoryId, farmId = farmId, shiftId = shiftId, slotId = slotId }
        self.selectedProduction = production
        self:showCategoryChoiceForSlot(production, shiftId)
    end
end

function FabriXGui:onSelectWorkerForSlot(index)
    if index == nil or index == 0 or self.dialogWorkers == nil or self.pendingSlot == nil then
        self.pendingSlot = nil
        self.dialogWorkers = nil
        return
    end

    local worker = self.dialogWorkers[index]
    local slot = self.pendingSlot
    local production = self.selectedProduction
    self.pendingSlot = nil
    self.dialogWorkers = nil

    if worker == nil then return end

    local ok, reason = FabriX:canAssignWorkerToSlot(worker, production, slot.shiftId)

    if not ok then
        InfoDialog.show(reason or g_i18n:getText("fabrix_gui_assign_failed"))
        return
    end

    FabriX:runAction("assignSlot", worker.id, slot.factoryId, slot.shiftId, slot.slotId)
end

function FabriXGui:onConfirmRemoveWorker(yes)
    local worker = self.pendingRemoveWorker
    self.pendingRemoveWorker = nil

    if not yes or worker == nil then return end

    FabriX:runAction("unassign", worker.id)
end

function FabriXGui:onClickAutoMode(state)
    local production = self.selectedProduction
    if production == nil then return end


    local isOn = state == BinaryOptionElement.STATE_RIGHT
    -- no permission: runAction sends nothing, so the switch goes back
    if FabriX:runAction("setAutoMode", production.id, isOn) == false then
        isOn = production.autoMode == true
        self.autoModeOption:setIsChecked(isOn, true)
    end

    FabriXGui.colorAutoModeSwitch(self.autoModeOption, isOn)
end

function FabriXGui:onClickUpgrade()
    if self.selectedProduction == nil then return end
    FabriX:onUpgradeClicked(self.selectedProduction)
end

function FabriXGui:onClickClearShifts()
    local production = self.selectedProduction
    if production == nil then return end

    local any, onShift = getFactoryWorkers(g_currentMission:getFarmId(), production.id)
    if not any then return end

    local name = FabriX:getProductionName(production)
    local text = string.format(g_i18n:getText("fabrix_gui_clear_shifts_confirm"), tostring(name))

    if onShift then
        text = text .. "\n\n" .. g_i18n:getText("fabrix_gui_clear_shifts_warning")
    end

    self.pendingClearFactoryId = production.id
    YesNoDialog.show(self.onConfirmClearShifts, self, text, g_i18n:getText("fabrix_gui_clear_shifts_title"))
end

function FabriXGui:onConfirmClearShifts(yes)
    local factoryId = self.pendingClearFactoryId
    self.pendingClearFactoryId = nil

    if not yes or factoryId == nil then return end

    FabriX:runAction("clearFactory", factoryId)
end

function FabriXGui:onClickVisit()
    local x, y, z = getVisitPosition(self.selectedProduction)
    if x == nil then return end


    g_gui:showGui(nil)
    g_localPlayer:teleportTo(x, y, z)
end

function FabriXGui:showCategoryChoiceForSlot(production, shiftId)
    local farmId = g_currentMission:getFarmId()
    -- For each category, count how many deployable helpers exist
    self.dialogCategories = {}
    local options = {}
    local azubiReason

    for _, cat in ipairs(self.categoryRows) do
        local list = FabriX.worker.employees[cat.id] or {}
        local count = 0

        for _, worker in ipairs(list) do
            if worker.farmId == farmId and FabriX:isWorkerFree(worker) then
                local ok, reason = FabriX:canAssignWorkerToSlot(worker, production, shiftId)
                if ok then
                    count = count + 1
                elseif worker.category == "azubis" then
                    azubiReason = reason
                end
            end
        end

        if count > 0 then
            table.insert(self.dialogCategories, cat.id)
            table.insert(options, string.format("%s (%d)", g_i18n:getText(cat.label), count))
        end
    end

    if #options == 0 then
        -- azubi hint: why a free azubi can't take this slot (level, shift, sick, ...)
        local text = g_i18n:getText("fabrix_gui_no_workers_available")

        if azubiReason ~= nil then
            text = text .. "\n" .. azubiReason
        end

        InfoDialog.show(text)


        self.pendingSlot = nil
        return
    end

    OptionDialog.show(function(index) self:onSelectCategoryForSlot(index) end,
        g_i18n:getText("fabrix_gui_choose_category_text"), g_i18n:getText("fabrix_gui_choose_category_title"), options)
end

function FabriXGui:onSelectCategoryForSlot(index)
    -- index == 0 means "back/cancel"
    if index == nil or index == 0 or self.dialogCategories == nil then
        self.pendingSlot = nil
        self.dialogCategories = nil
        return
    end

    local catId = self.dialogCategories[index]
    self.dialogCategories = nil

    if catId == nil then
        self.pendingSlot = nil
        return
    end
    self:showWorkerChoiceForSlot(catId)
end

function FabriXGui:showWorkerChoiceForSlot(catId)
    local slot = self.pendingSlot
    if slot == nil then return end

    local production = slot.production or self.selectedProduction
    local farmId = slot.farmId
    local shiftId = slot.shiftId
    local list = FabriX.worker.employees[catId] or {}
    self.dialogWorkers = {}
    local options = {}

    for _, worker in ipairs(list) do
        if worker.farmId == farmId and FabriX:isWorkerFree(worker) then
            if FabriX:canAssignWorkerToSlot(worker, production, shiftId) == true then
                table.insert(self.dialogWorkers, worker)
                local years = FabriX:getAgeInYearsFromWorker(worker)

                table.insert(options,
                    string.format(g_i18n:getText("fabrix_gui_worker_option"), tostring(worker.name), worker.level or 0,
                        years, g_i18n:formatMoney(worker.salary or 0, 0, true, false)))
            end
        end
    end

    if #options == 0 then
        InfoDialog.show(g_i18n:getText("fabrix_gui_no_workers_category"))
        self.pendingSlot = nil
        self.dialogWorkers = nil
        return
    end

    OptionDialog.show(function(index) self:onSelectWorkerForSlot(index) end,
        g_i18n:getText("fabrix_gui_choose_worker_text"), g_i18n:getText("fabrix_gui_choose_worker_title"), options)
end

-- Renders the factory leadership block (Meister from Lvl 3, Betriebsleiter from Lvl 5)
function FabriXGui:showLeadershipSlots(production)
    local block = self:getDescendantById("leadershipBlock")
    if block == nil or production == nil then return end

    local level = production.level or 1
    -- Only show the block from the Meister level on
    block:setVisible(level >= FabriX.ROLE_MIN_LEVEL.meister)
    if level < FabriX.ROLE_MIN_LEVEL.meister then return end

    -- Builds a leadership slot into the given BoxLayout

    local function buildRoleSlot(roleSlot, boxId, labelId)
        local box = self:getDescendantById(boxId)
        local labelEl = self:getDescendantById(labelId)

        if box == nil then return end

        if labelEl ~= nil then
            labelEl:setVisible(true)
        end

        -- clear old slots in the box
        while #box.elements > 0 do
            box.elements[1]:delete()
        end

        local slot = self.helperSlotTemplate:clone(box)
        slot:setVisible(true)
        slot.fabrixRoleSlot = roleSlot
        slot.fabrixProduction = production

        local worker = FabriX:getRoleHolder(production, roleSlot)
        local nameEl = slot:getDescendantByName("helperName")
        local levelEl = slot:getDescendantByName("helperLevel")
        local xpEl = slot:getDescendantByName("helperXP")
        local iconEl = slot:getDescendantByName("helperIcon")
        local bgEl = slot:getDescendantByName("bg")

        if worker ~= nil then
            if bgEl ~= nil then bgEl:setImageColor(nil, 0.10, 0.11, 0.10, 0.95) end

            if nameEl ~= nil then
                nameEl:setText(tostring(worker.name))
                nameEl:setTextColor(0.88, 0.90, 0.86, 1)
            end

            if levelEl ~= nil then
                levelEl:setText(string.format(g_i18n:getText("fabrix_gui_level"), worker.level or 0))
            end

            if xpEl ~= nil then
                xpEl:setText(FabriX:getWorkerRole(worker))
                setRoleColor(xpEl, worker)
            end

            if iconEl ~= nil then
                if worker.icon ~= nil and worker.icon ~= "" then
                    iconEl:setImageFilename(worker.icon)
                    iconEl:setImageColor(nil, 1, 1, 1, 1)
                    iconEl:setVisible(true)
                else
                    iconEl:setVisible(false)
                end
            end
        else
            -- Empty -> highlight the required slot in red
            if bgEl ~= nil then bgEl:setImageColor(nil, 0.22, 0.10, 0.10, 0.90) end
            if nameEl ~= nil then
                nameEl:setText(g_i18n:getText("fabrix_gui_slot_required"))
                nameEl:setTextColor(0.90, 0.30, 0.20, 1)
            end

            if levelEl ~= nil then
                levelEl:setText("")
            end

            if xpEl ~= nil then
                xpEl:setText("")
            end

            if iconEl ~= nil then
                iconEl:setVisible(false)
            end
        end
        box:invalidateLayout()
    end

    -- Meister slot (from lvl 3)
    buildRoleSlot("meister", "masterSlotBox", "masterSlotLabel")
    -- BL slot (from lvl 5)
    local blLabel = self:getDescendantById("blSlotLabel")

    local blBox = self:getDescendantById("blSlotBox")
    if level >= FabriX.ROLE_MIN_LEVEL.betriebsleiter then
        buildRoleSlot("betriebsleiter", "blSlotBox", "blSlotLabel")
    else
        if blLabel ~= nil then
            blLabel:setVisible(false)
        end

        if blBox ~= nil then
            while #blBox.elements > 0 do
                blBox.elements[1]:delete()
            end
        end
    end
end

-- Click on a Meister/BL slot.
function FabriXGui:onRoleSlotClicked(button)
    local production = button.fabrixProduction
    local roleSlot = button.fabrixRoleSlot

    if production == nil or roleSlot == nil then return end

    local current = FabriX:getRoleHolder(production, roleSlot)
    if current ~= nil then
        -- Occupied -> confirm removal
        self.pendingRemoveWorker = current
        self.selectedProduction = production

        local roleName = (roleSlot == "meister") and g_i18n:getText("fabrix_role_meister") or
            g_i18n:getText("fabrix_role_betriebsleiter")
        local text = string.format(g_i18n:getText("fabrix_gui_remove_role_confirm"), tostring(current.name), roleName,
            roleName)

        YesNoDialog.show(self.onConfirmRemoveWorker, self, text, g_i18n:getText("fabrix_gui_remove_role_title"))
    else
        -- Empty -> offer matching workers for selection
        self.pendingRoleSlot = { production = production, roleSlot = roleSlot }
        self.selectedProduction = production
        self:showRoleWorkerChoice(production, roleSlot)
    end
end

-- Selection dialog with all matching (free) Meister/BL of the farm
function FabriXGui:showRoleWorkerChoice(production, roleSlot)
    local farmId = g_currentMission:getFarmId()
    local list = FabriX.worker.employees["facharbeiter"] or {}
    self.dialogRoleWorkers = {}
    local options = {}

    for _, worker in ipairs(list) do
        -- Only offer free (nowhere assigned) workers
        local isFree = worker.farmId == farmId and FabriX:isWorkerFree(worker)

        if isFree then
            local canAssign = FabriX:canAssignWorkerToRoleSlot(worker, roleSlot)
            if canAssign then
                table.insert(self.dialogRoleWorkers, worker)
                local years = FabriX:getAgeInYearsFromWorker(worker)
                table.insert(options,
                    string.format(g_i18n:getText("fabrix_gui_role_worker_option"), tostring(worker.name),
                        FabriX:getWorkerRole(worker), worker.level or 0, years))
            end
        end
    end

    if #options == 0 then
        local roleName = (roleSlot == "meister") and g_i18n:getText("fabrix_role_meister_range") or
            g_i18n:getText("fabrix_role_betriebsleiter_range")

        InfoDialog.show(string.format(g_i18n:getText("fabrix_gui_no_free_role"), roleName))
        self.pendingRoleSlot = nil
        return
    end

    OptionDialog.show(function(index) self:onSelectRoleWorker(index) end,
        g_i18n:getText("fabrix_gui_choose_leader_text"), g_i18n:getText("fabrix_gui_choose_leader_title"), options)
end

function FabriXGui:onSelectRoleWorker(index)
    local pending = self.pendingRoleSlot
    self.pendingRoleSlot = nil

    if index == nil or index == 0 or self.dialogRoleWorkers == nil or pending == nil then
        self.dialogRoleWorkers = nil
        return
    end

    local worker = self.dialogRoleWorkers[index]
    self.dialogRoleWorkers = nil

    if worker == nil then return end

    local production = pending.production
    local roleSlot = pending.roleSlot

    if production == nil then return end

    local ok, reason = FabriX:canAssignWorkerToRoleSlot(worker, roleSlot)

    if not ok then
        InfoDialog.show(reason or g_i18n:getText("fabrix_gui_assign_failed"))
        return
    end

    FabriX:runAction("assignRole", worker.id, production.id, roleSlot)
end
