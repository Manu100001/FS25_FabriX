-- Hook callback implementations for FabriX
-- The callbacks are shared with hooks.lua through this table
---@diagnostic disable: undefined-global
FabriX.hooks = {}

-- Callback for Mission00.saveSavegame
function FabriX.hooks.saveSavegame()
    FabriX:onSave()
end

-- Callback for Placeable.finalizePlacement
function FabriX.hooks.finalizePlacement(placeable)
    FabriX:registerProduction(placeable)
end

-- Refresh the FabriX XP display in the production menu
function FabriX.hooks.updateMenuButtons(frame)
    FabriX:updateSelectedProductionXpDisplay(frame)
end

-- Draw the FabriX progress or renovation overlay in the production menu
function FabriX.hooks.drawProductionFrame(frame)
    FabriX:drawGui(frame)
end

-- Callback for purchases of already placed production buildings
function FabriX.hooks.onBuy(placeable)
    FabriX:onBuy(placeable)
end

function FabriX.hooks.onSell(placeable)
    FabriX:onSell(placeable)
end

function FabriX.hooks.setOwnerFarmId(placeable)
    FabriX:onOwnerChanged(placeable)
end

-- a bought building gets its network id in register(), after finalizePlacement: sync again so clients can map it
function FabriX.hooks.register(placeable)
    for _, production in ipairs(FabriX.productions) do
        if production.placeable == placeable then
            FabriX:syncToClients()
            return
        end
    end
end

-- Forward the overwritten production distribution call to FabriX logic
function FabriX.hooks.distributeGoods(self, superFunc, ...)
    return FabriX:distributeGoods(self, superFunc, ...)
end

-- Block activation of recipes while the corresponding factory is upgrading
function FabriX.hooks.setProductionState(productionPoint, superFunc, productionId, isEnabled, ...)
    if productionPoint ~= nil then
        for _, production in ipairs(FabriX.productions) do
            if production.productionPoint == productionPoint and production.isOnUpgrade and isEnabled then return end
        end
    end
    return superFunc(productionPoint, productionId, isEnabled, ...)
end

function FabriX:registerActionEvents()
    if self.actionEventId ~= nil then
        g_inputBinding:removeActionEvent(self.actionEventId)
        self.actionEventId = nil
    end

    local success, eventId = g_inputBinding:registerActionEvent(InputAction.FABRIX_OPEN_GUI, FabriX, FabriX.onOpenGuiPressed, false, true, false, true)
    if success then
        self.actionEventId = eventId
        g_inputBinding:setActionEventText(eventId, g_i18n:getText("fabrix_action_open_gui"))
        g_inputBinding:setActionEventTextVisibility(eventId, true)
    end
end

-- append the FabriX help pages to the in-game help menu (pause menu > help)
function FabriX.hooks.loadHelpLine(helpLineManager, superFunc, ...)
    local result = superFunc(helpLineManager, ...)

    if not FabriX.helpLineLoaded and helpLineManager ~= nil and helpLineManager.loadFromXML ~= nil then
        local filename = FabriX.dir .. "xml/helpLine.xml"
        if fileExists(filename) then
            helpLineManager:loadFromXML(filename)
            FabriX.helpLineLoaded = true
        end
    end
    return result
end

local INFO_SHIFT_NAMES = { "fabrix_gui_shift_early", "fabrix_gui_shift_day", "fabrix_gui_shift_late" }
local INFO_ROLE_SLOTS = { "meister", "betriebsleiter" }

-- in-world info box of a production point: FabriX lines, only for the player's own registered factories
function FabriX.hooks.updateProductionInfo(productionPoint, infoTable)
    if infoTable == nil or g_currentMission == nil then return end

    local farmId = g_currentMission:getFarmId()
    local production

    for _, entry in ipairs(FabriX.productions or {}) do
        if entry.productionPoint == productionPoint and entry.farmId == farmId then
            production = entry
            break
        end
    end

    if production == nil then return end

    table.insert(infoTable, { title = "FabriX", accentuate = true })

    if production.isOnUpgrade then
        local hours = FabriX:getRenovationHours(production)
        table.insert(infoTable, { title = g_i18n:getText("fabrix_status_renovation"), text = string.format(g_i18n:getText("fabrix_upgrade_factory_onRenovation2"), hours) })
        return
    end

    local level = production.level or 1
    local autoText = (production.autoMode and level >= FabriX.AUTO_MODE_MIN_LEVEL) and g_i18n:getText("fabrix_info_auto_on") or ""
    table.insert(infoTable, { title = string.format(g_i18n:getText("fabrix_gui_level"), level), text = autoText })

    local shiftId = FabriX:getCurrentShiftId()

    if shiftId ~= nil then
        local count = 0

        for _ in pairs(FabriX:getAssignedWorkers(farmId, production.id, shiftId)) do
            count = count + 1
        end

        local percent = math.floor(FabriX:getShiftProductivity(production, shiftId) * 100 + 0.5)
        table.insert(infoTable, {
            title = g_i18n:getText(INFO_SHIFT_NAMES[shiftId]),
            text = string.format(g_i18n:getText("fabrix_info_shift"), count, FabriX:getSlotsPerShift(production), percent)
        })
    end

    for _, roleSlot in ipairs(INFO_ROLE_SLOTS) do
        if level >= FabriX.ROLE_MIN_LEVEL[roleSlot] then
            local worker = FabriX:getRoleHolder(production, roleSlot)
            table.insert(infoTable, { title = g_i18n:getText("fabrix_role_" .. roleSlot), text = worker ~= nil and tostring(worker.name) or g_i18n:getText("fabrix_info_unassigned") })
        end
    end

    local status, _, missing, low = FabriX:getProductionStatus(production)
    local text = g_i18n:getText("fabrix_status_" .. status)
    local goods = (status == "missing" and missing) or (status == "low" and low) or nil

    if goods ~= nil and #goods > 0 then
        text = text .. " (" .. FabriX:getFillTypeTitles(goods) .. ")"
    end

    table.insert(infoTable, { title = g_i18n:getText("fabrix_gui_detail_status"), text = text })
end
