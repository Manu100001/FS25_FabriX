-- #########################################
-- # GUI Extensions for standard FS 25 GUI #
-- #########################################
-- this file implements the XP display for the productions in the production menu

-- XP text for a production, shared by the production menu and the FabriX shift plan
function FabriX:getXpText(production)
    local current, needed, ratio = FabriX:getXpProgress(production)
    if production.level >= FabriX.MAX_LEVEL then
        return string.format(g_i18n:getText("fabrix_production_level_max"), production.level, current), true, ratio or 0
    end

    return string.format(g_i18n:getText("fabrix_production_level"), production.level, current, needed), false, ratio or 0
end

function FabriX:updateSelectedProductionXpDisplay(frame)
    FabriX.currentText = nil
    FabriX.currentIsMax = false
    FabriX.currentRatio = 0

    local _, selectedProductionPoint = frame:getSelectedProduction()
    if selectedProductionPoint == nil then return end

    for _, production in ipairs(FabriX.productions) do
        if production.productionPoint == selectedProductionPoint then
            FabriX.currentText, FabriX.currentIsMax, FabriX.currentRatio = FabriX:getXpText(production)
            return
        end
    end
end

-- function is called when the 'upgrade factory' button is clicked
function FabriX:onUpgradeClicked(production)
    -- enough XP for next Level?
    local requiredXP = FabriX.XP_FOR_LEVEL[production.level + 1]
    if production.xp < requiredXP then
        InfoDialog.show(string.format(g_i18n:getText("fabrix_upgrade_factory_xp_missing"), production.xp, requiredXP))
        return
    end

    -- enough money for next level?
    local upgradeCost = FabriX.UPGRADE_COSTS[production.level + 1]
    local farmId = g_currentMission:getFarmId()
    local farm = g_farmManager:getFarmById(farmId)

    if farm == nil then return end

    local balance = farm:getBalance()
    if balance < upgradeCost then
        InfoDialog.show(string.format(g_i18n:getText("fabrix_upgrade_factory_money_missing"), g_i18n:formatMoney(upgradeCost), g_i18n:formatMoney(balance)))
        return
    end

    -- enough xp and money
    FabriX.pendingUpgrade = production

    local targetLevel = production.level + 1
    local text = string.format(g_i18n:getText("fabrix_upgrade_factory"), FabriX:getProductionName(production),
        targetLevel, g_i18n:formatMoney(upgradeCost), FabriX.RENOVATION_DURATION[targetLevel])

    -- from ROLE_MIN_LEVEL on a factory requires a 'Meister' / 'Betriebsleiter'
    if targetLevel == FabriX.ROLE_MIN_LEVEL.meister then
        text = text .. "\n\n" .. g_i18n:getText("fabrix_upgrade_factory_requires_meister")
    elseif targetLevel == FabriX.ROLE_MIN_LEVEL.betriebsleiter then
        text = text .. "\n\n" .. g_i18n:getText("fabrix_upgrade_factory_requires_betriebsleiter")
    end

    YesNoDialog.show(FabriX.onUpgradeConfirmed, FabriX, text)
end

function FabriX:onUpgradeConfirmed(confirm)
    local production = FabriX.pendingUpgrade
    FabriX.pendingUpgrade = nil

    if not confirm or production == nil then return end

    -- the server confirms with a notification, only if the upgrade really started
    FabriX:runAction("upgrade", production.id)
end

-- server only: factory is upgraded, several things need to be done
function FabriX.actions.upgrade(farmId, productionId)
    local production = FabriX:findProduction(farmId, productionId)

    if production == nil or production.isOnUpgrade or production.level >= FabriX.MAX_LEVEL then return end

    local targetLevel = production.level + 1

    if production.xp < FabriX.XP_FOR_LEVEL[targetLevel] then return end

    if not FabriX:payFee(farmId, FabriX.UPGRADE_COSTS[targetLevel], MoneyType.SHOP_PROPERTY_BUY) then return end

    -- increase level of factory
    production.level = production.level + 1
    production.xp = 0
    production.isOnUpgrade = true
    production.upgradeReadyNotified = false
    production.renovationDuration = FabriX.RENOVATION_DURATION[production.level] * FabriX:getMinutesPerMonth() -- in minutes

    -- increase stock level for incoming and outgoing inventory
    FabriX:applyCapacityForLevel(production)

    -- set factory to pause
    local productionPoint = production.productionPoint
    local productionsToStop = {}
    if productionPoint ~= nil then
        local activeProductions = productionPoint.activeProductions
        for _, activeProduction in ipairs(activeProductions) do
            table.insert(productionsToStop, activeProduction)
        end
    end

    for _, activeProduction in ipairs(productionsToStop) do
        productionPoint:setProductionState(activeProduction.id, false)
    end

    FabriX:notify(farmId, FSBaseMission.INGAME_NOTIFICATION_OK, { "fabrix_upgrade_factory_confirmed" })
end

function FabriX:drawGui(frame)
    local _, selectedProductionPoint = frame:getSelectedProduction()
    if selectedProductionPoint ~= nil then
        for _, production in ipairs(FabriX.productions) do
            if production.productionPoint == selectedProductionPoint and production.isOnUpgrade then
                -- opaque black overlay while the production is under renovation
                drawFilledRect(0.3, 0.05, 0.67, 0.8, 0.0, 0.0, 0.0, 1.0)

                setTextColor(0.627, 0.761, 0.075, 1.0)
                setTextBold(true)
                setTextAlignment(RenderText.ALIGN_LEFT)
                renderText(0.7, 0.91, 0.025, g_i18n:getText("fabrix_upgrade_factory_onRenovation1"))
                renderText(0.7, 0.88, 0.025, string.format(g_i18n:getText("fabrix_upgrade_factory_onRenovation2"), FabriX:getRenovationHours(production)))

                -- restore default values
                setTextBold(false)
                setTextColor(1, 1, 1, 1)
                return
            end
        end
    end

    if FabriX.currentText == nil then return end

    local textX = 0.88
    local textY = 0.87
    local textSize = 0.020
    local barY = 0.85
    local barHeight = 0.008
    local progressRatio = FabriX.currentRatio or 0

    if FabriX.currentIsMax then
        -- set color to gold
        setTextColor(1.0, 0.65, 0.05, 1)
    else
        setTextColor(1, 1, 1, 1)
    end

    setTextBold(true)
    setTextAlignment(RenderText.ALIGN_RIGHT)
    renderText(textX, textY, textSize, FabriX.currentText)

    -- get text width for calculating the bar
    local textWidth = getTextWidth(textSize, FabriX.currentText)

    -- restore default values
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(false)
    setTextColor(1, 1, 1, 1)

    local barX = textX - textWidth
    local barWidth = math.max(textWidth, 0.01)

    drawFilledRect(barX, barY, barWidth, barHeight, 0.2, 0.2, 0.2, 0.8)
    drawFilledRect(barX, barY, barWidth * progressRatio, barHeight, 0.2, 0.8, 0.2, 1.0)
end
