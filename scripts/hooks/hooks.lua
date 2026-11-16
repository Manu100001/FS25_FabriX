-- Hook registrations for FabriX
-- Callback implementations are defined in hookFunctions.lua
---@diagnostic disable: undefined-global

-- ######################
-- # Appended functions #
-- ######################

-- Save FabriX production data together with the savegame
Mission00.saveSavegame = Utils.appendedFunction(Mission00.saveSavegame, FabriX.hooks.saveSavegame)

-- Register productions when placeables are created or bought
Placeable.finalizePlacement = Utils.appendedFunction(Placeable.finalizePlacement, FabriX.hooks.finalizePlacement)
Placeable.onBuy = Utils.appendedFunction(Placeable.onBuy, FabriX.hooks.onBuy)
Placeable.onSell = Utils.appendedFunction(Placeable.onSell, FabriX.hooks.onSell)
Placeable.setOwnerFarmId = Utils.appendedFunction(Placeable.setOwnerFarmId, FabriX.hooks.setOwnerFarmId)
Placeable.register = Utils.appendedFunction(Placeable.register, FabriX.hooks.register)

-- Update the production menu with FabriX progress and upgrade controls
InGameMenuProductionFrame.updateMenuButtons = Utils.appendedFunction(InGameMenuProductionFrame.updateMenuButtons,
    FabriX.hooks.updateMenuButtons)
InGameMenuProductionFrame.draw = Utils.appendedFunction(InGameMenuProductionFrame.draw, FabriX.hooks.drawProductionFrame)

PlayerInputComponent.registerGlobalPlayerActionEvents = Utils.appendedFunction(
    PlayerInputComponent.registerGlobalPlayerActionEvents, function(self, controlling) FabriX:registerActionEvents() end)


-- sends the fabrix state to a client that joins a multiplayer game (only called on the server)
FSBaseMission.sendInitialClientState = Utils.appendedFunction(FSBaseMission.sendInitialClientState, function(self, connection, user, farm) connection:sendEvent(FabriXInitialStateEvent.new()) end)

-- #########################
-- # Overwritten functions #
-- #########################
-- Capture production distribution costs for later FabriX accounting
ProductionChainManager.distributeGoods = Utils.overwrittenFunction(ProductionChainManager.distributeGoods,
    FabriX.hooks.distributeGoods)

-- Prevent production from being enabled while its factory is being upgraded
ProductionPoint.setProductionState = Utils.overwrittenFunction(ProductionPoint.setProductionState,
    FabriX.hooks.setProductionState)

-- add the FabriX documentation pages to the in-game help menu
HelpLineManager.loadMapData = Utils.overwrittenFunction(HelpLineManager.loadMapData, FabriX.hooks.loadHelpLine)


-- FabriX lines in the in-world info box of a factory
ProductionPoint.updateInfo = Utils.appendedFunction(ProductionPoint.updateInfo, FabriX.hooks.updateProductionInfo)
