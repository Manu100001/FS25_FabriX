-- Register the custom money types used by FabriX
local function registerMoneyTypes()
    if MoneyType == nil or MoneyType.register == nil then return end

    for _, row in ipairs(FabriX.GUI_FINANCE_ROWS) do
        if MoneyType[row.field] == nil then
            MoneyType[row.field] = MoneyType.register(row.key, "finance_" .. row.key, g_currentModName)
        end
    end
end

-- Add FabriX rows to the statistics screen before FinanceStats instances exist
local function registerFabriXFinanceStats()
    for _, row in ipairs(FabriX.GUI_FINANCE_ROWS) do
        if FinanceStats.statNameToIndex[row.key] == nil then
            table.insert(FinanceStats.statNames, row.key)
            FinanceStats.statNameToIndex[row.key] = #FinanceStats.statNames
        end
        FinanceStats.statNamesI18n[row.key] = g_i18n:getText("finance_" .. row.key)
    end
end

local fabrixNewHookInstalled = false

-- Re-apply the localized labels whenever the game creates FinanceStats.
local function installFabriXFinanceHooks()
    if fabrixNewHookInstalled then return end

    if FinanceStats == nil or type(FinanceStats.new) ~= "function" then
        Logging.warning("[FabriX]: FinanceStats.new is not available")
        return
    end

    fabrixNewHookInstalled = true

    local originalNew = FinanceStats.new

    FinanceStats.new = function(...)
        local self = originalNew(...)
        for _, row in ipairs(FabriX.GUI_FINANCE_ROWS) do
            FinanceStats.statNamesI18n[row.key] = g_i18n:getText("finance_" .. row.key)
        end
        return self
    end
end

-- Run these calls immediately while the game is still loading the scripts
registerMoneyTypes()
registerFabriXFinanceStats()
installFabriXFinanceHooks()

function FabriX:registerFinanceCategories()
    if InGameMenuStatisticsFrame == nil or InGameMenuStatisticsFrame.FINANCES == nil then return end

    for _, row in ipairs(FabriX.GUI_FINANCE_ROWS) do
        local moneyType = MoneyType[row.field]
        if moneyType ~= nil then
            local alreadyRegistered = false
            for _, registeredMoneyType in ipairs(InGameMenuStatisticsFrame.FINANCES) do
                if registeredMoneyType == moneyType.id then
                    alreadyRegistered = true
                    break
                end
            end

            if not alreadyRegistered then
                table.insert(InGameMenuStatisticsFrame.FINANCES, moneyType.id)
            end
        end
    end
end

FabriX:registerFinanceCategories()
