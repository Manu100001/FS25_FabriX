-- #######################################################################
-- FabriXGui - Screen for managing factory shift plans and hiring helpers
-- #######################################################################
FabriXGui = {}

local FabriXGui_mt = Class(FabriXGui, ScreenElement)
-- Shared constants are class fields so the GUI can be split across
-- multiple source files (FabriXGui_*.lua)

FabriXGui.DEFAULT_WORKER_ICONS = {
  erntehelfer = "dataS2/npc/grandpa/grandpa.png",
  facharbeiter = "dataS2/npc/animalDealer/animalDealer.png",
  azubis = "dataS2/npc/farmer/farmer.png",
}

-- Category definitions reused by market and pool
FabriXGui.CATEGORY_ROWS = {
  { id = "erntehelfer",  label = "fabrix_category_erntehelfer" },
  { id = "facharbeiter", label = "fabrix_category_facharbeiter" },
  { id = "azubis",       label = "fabrix_category_azubis" },
}

-- employees tab: the three categories plus two facharbeiter views
FabriXGui.POOL_CATEGORY_ROWS = {
  FabriXGui.CATEGORY_ROWS[1],
  FabriXGui.CATEGORY_ROWS[2],
  FabriXGui.CATEGORY_ROWS[3],
  {
    id = "inSchool",
    source = "facharbeiter",
    sources = { "facharbeiter", "azubis" },
    label = "fabrix_gui_ov_in_school",
    match = function(worker) return worker.inSchool == true end
  },
  {
    id = "trainable",
    source = "facharbeiter",
    label = "fabrix_gui_ov_trainable",
    match = function(worker) return FabriX:canStartSchool(worker) end
  },
  {
    id = "sick",
    sources = { "erntehelfer", "facharbeiter", "azubis" },
    source = "facharbeiter", -- icon only; employee lists come from sources
    label = "fabrix_gui_ov_sick",
    match = function(worker) return (worker.sickMinutesLeft or 0) > 0 end
  },
  {
    id = "resigning",
    sources = { "erntehelfer", "facharbeiter", "azubis" },
    source = "facharbeiter", -- icon only; employee lists come from sources
    label = "fabrix_gui_ov_resigning",
    match = function(worker) return (worker.resignationGiven or false) == true end
  }
}

FabriXGui.TAB_OVERVIEW = 1
FabriXGui.TAB_SHIFTPANE = 2
FabriXGui.TAB_EMPLOYEES = 3
FabriXGui.TAB_MARKET = 4

-- employees tab: sections of the category list (header, number of rows)
FabriXGui.POOL_SECTIONS = {
  { count = 3 },
  { title = "fabrix_gui_pool_section_training",  count = 2 },
  { title = "fabrix_gui_pool_section_sick",      count = 1 },
  { title = "fabrix_gui_pool_section_resigning", count = 1 }
}

-- File-local aliases for the constants used in this core file.
local DEFAULT_WORKER_ICONS = FabriXGui.DEFAULT_WORKER_ICONS

-- production status: red = produces nothing, orange = partly, yellow = low, grey = renovation
local STATUS_COLORS = {
  renovation = { 0.60, 0.60, 0.60, 1 },
  noStaff = { 0.90, 0.30, 0.20, 1 },
  noRecipe = { 0.90, 0.30, 0.20, 1 },
  missing = { 0.90, 0.30, 0.20, 1 },
  full = { 0.90, 0.30, 0.20, 1 },
  low = { 0.95, 0.75, 0.20, 1 },
  running = { 0.55, 0.90, 0.45, 1 }
}
local STATUS_PARTIAL_COLOR = { 0.95, 0.55, 0.20, 1 }

local CATEGORY_ROWS = FabriXGui.CATEGORY_ROWS
local TAB_OVERVIEW = FabriXGui.TAB_OVERVIEW
local TAB_SHIFTPANE = FabriXGui.TAB_SHIFTPANE
local TAB_EMPLOYEES = FabriXGui.TAB_EMPLOYEES
local TAB_MARKET = FabriXGui.TAB_MARKET

-- bottom buttons and the tab they belong to (hidden on every other tab)
local BUTTON_TAB = {
  hireButton = TAB_MARKET,
  fireButton = TAB_EMPLOYEES,
  trainButton = TAB_EMPLOYEES,
  clearShiftsButton = TAB_SHIFTPANE,
  upgradeButton = TAB_SHIFTPANE,
  visitButton = TAB_SHIFTPANE
}

-- employee lists of a pool row; rows with `sources` (training, sick, resigning) span several
function FabriXGui.getPoolSourceLists(cat)
  local lists = {}

  for _, source in ipairs(cat.sources or { cat.source or cat.id }) do
    table.insert(lists, (FabriX.worker.employees or {})[source] or {})
  end

  return lists
end

-- client-side money pre-check before a paid action (the server checks again)
-- shows the not-enough money dialog and returns false if the farm cannot pay
function FabriXGui.hasMoney(fee, textKey)
  local balance = g_currentMission:getMoney(g_currentMission:getFarmId())

  if balance ~= nil and balance < fee then
    InfoDialog.show(string.format(g_i18n:getText(textKey), g_i18n:formatMoney(fee, 0, true, false)))
    return false
  end
  return true
end

-- the game has no per-state slider color: on = strong green, off = red, in every state
local SLIDER_STATES = {
  GuiOverlay.STATE_NORMAL,
  GuiOverlay.STATE_FOCUSED,
  GuiOverlay.STATE_HIGHLIGHTED,
  GuiOverlay.STATE_PRESSED,
  GuiOverlay.STATE_SELECTED
}

function FabriXGui.colorAutoModeSwitch(option, isOn)
  local slider = option.sliderElement

  if slider == nil then return end
  -- the game's focus green, captured once before it gets overwritten
  slider.fabrixGreen = slider.fabrixGreen or { unpack(slider.overlay.colorFocused or slider.overlay.color) }
  local c = isOn and slider.fabrixGreen or { 0.75, 0.15, 0.15, 1 }
  for _, state in ipairs(SLIDER_STATES) do
    slider:setImageColor(state, c[1], c[2], c[3], c[4])
  end
end

function FabriXGui.new(target, customMt)
  local self = ScreenElement.new(target, customMt or FabriXGui_mt)
  self.currentTab = TAB_OVERVIEW
  self.rows = {}
  self.alertRows = {}
  self.selectedIndex = 1

  -- market
  self.categoryRows = CATEGORY_ROWS
  self.selectedCategoryIndex = 1
  self.selectedCategoryId = "erntehelfer"
  self.workerRows = {}
  self.selectedWorkerIndex = 1

  -- employees
  self.poolCategoryRows = FabriXGui.POOL_CATEGORY_ROWS
  self.selectedPoolCategoryIndex = 1
  self.selectedPoolCategoryId = "erntehelfer"
  self.poolWorkerRows = {}
  self.selectedPoolWorkerIndex = 1
  self.poolFilter = "all"
  self.poolLevel = nil

  -- shift plan / dialogs (set in the tab files, nil = nothing pending)
  self.selectedProduction = nil
  self.dialogWorkers = nil
  self.dialogCategories = nil
  self.isReloadingList = false
  self.pendingSlot = nil
  self.pendingRoleSlot = nil
  self.pendingRemoveWorker = nil
  self.pendingClearFactoryId = nil
  self.pendingHireWorker = nil
  self.pendingFireWorker = nil
  self.pendingTrainWorker = nil
  self.pendingWithdrawWorker = nil
  self.pendingCounterOfferId = nil

  return self
end

function FabriXGui:onOpen()
  FabriXGui:superClass().onOpen(self)

  self:showTab(self.currentTab or 1)
  -- k key stays active while the menu is open -> closes the menu
  local _, eventId = g_inputBinding:registerActionEvent(InputAction.FABRIX_OPEN_GUI, self, self.onToggleClose, false, true, false, true)
  self.closeEventId = eventId
end

function FabriXGui:onClose()
  FabriXGui:superClass().onClose(self)

  self.pendingSlot = nil
  self.pendingRoleSlot = nil
  self.dialogWorkers = nil
  self.dialogRoleWorkers = nil
  self.dialogCategories = nil

  if self.closeEventId ~= nil then
    g_inputBinding:removeActionEvent(self.closeEventId)
    self.closeEventId = nil
  end
end

function FabriXGui:onClickBack()
  g_gui:showGui(nil)
end

function FabriXGui:onToggleClose()
  self:onClickBack()
end

-- =========================================================================
-- Tab switching
-- index 1 = overview | 2 = Shift pane | 3 = Employees | 4 = Market
-- =========================================================================
function FabriXGui:showTab(index)
  self.currentTab = index
  self:highlightActiveTab(index)
  local showOverview = (index == TAB_OVERVIEW)
  local showShiftPlan = (index == TAB_SHIFTPANE)
  local showMarket = (index == TAB_MARKET)
  local showEmployees = (index == TAB_EMPLOYEES)

  -- overview
  if self.overviewContainer ~= nil then
    self.overviewContainer:setVisible(showOverview)
  end

  -- shift pane
  if self.einsatzplanContainer ~= nil then
    self.einsatzplanContainer:setVisible(showShiftPlan)
  end

  -- market
  if self.arbeitsmarktContainer ~= nil then
    self.arbeitsmarktContainer:setVisible(showMarket)
  end

  if self.workerDetailContainer ~= nil then
    self.workerDetailContainer:setVisible(showMarket)
  end

  -- employees
  if self.poolCategoryContainer ~= nil then
    self.poolCategoryContainer:setVisible(showEmployees)
  end

  if self.poolDetailContainer ~= nil then
    self.poolDetailContainer:setVisible(showEmployees)
  end

  if self.employeeDetailContainer ~= nil and not showEmployees then
    self.employeeDetailContainer:setVisible(false)
  end

  if self.emptyText ~= nil and not showShiftPlan then
    self.emptyText:setVisible(false)
  end

  if self.shiftPane ~= nil and not showShiftPlan then
    self.shiftPane:setVisible(false)
  end


  for buttonId, tab in pairs(BUTTON_TAB) do
    if self[buttonId] ~= nil and index ~= tab then
      self[buttonId]:setVisible(false)
    end
  end

  if index ~= TAB_MARKET then
    self.selectedWorker = nil
  end

  if showOverview then
    self:refreshOverview()
  elseif showShiftPlan then
    self:refreshProductions()
  elseif showMarket then
    self:populateCategories()
    self:populateWorkerMarket()
  elseif showEmployees then
    self:populatePoolCategories()
    self:populatePoolWorkers()
  end
end

function FabriXGui:onClickTabOverview()
  self:showTab(TAB_OVERVIEW)
end

function FabriXGui:onClickTabEinsatzplan()
  self:showTab(TAB_SHIFTPANE)
end

function FabriXGui:onClickTabArbeitsmarkt()
  self:showTab(TAB_MARKET)
end

function FabriXGui:onClickTabArbeitspool()
  self:showTab(TAB_EMPLOYEES)
end

-- =========================================================================
-- SmoothList callbacks (shared by all lists).
-- =========================================================================
-- called by the engine on the list delegate (this screen) for mouse, keyboard, focus and reload
function FabriXGui:onListSelectionChanged(list, section, index)
  if self.isReloadingList or index == nil or index < 1 then return end

  if list == self.productionList then
    self:onProductionSelected(list, section, index)
  elseif list == self.categoryList then
    self:onCategorySelected(list, section, index)
  elseif list == self.workerMarketList then
    self:onWorkerSelected(list, section, index)
  elseif list == self.poolCategoryList then
    self:onPoolCategorySelected(list, section, index)
  elseif list == self.poolWorkerList then
    self:onPoolWorkerSelected(list, section, index)
  end
end

-- reloads a list and restores the selection without triggering onListSelectionChanged
function FabriXGui:reloadList(list, section, index)
  self.isReloadingList = true
  list:reloadData()

  if index ~= nil then
    list:setSelectedItem(section, index)
  end

  self.isReloadingList = false
end

function FabriXGui:getNumberOfSections(list)
  if list == self.poolCategoryList then return #FabriXGui.POOL_SECTIONS end
  return 1
end

function FabriXGui:getNumberOfItemsInSection(list, section)
  if list == self.categoryList then
    return #self.categoryRows
  end

  if list == self.workerMarketList then
    return #(self.workerRows or {})
  end

  if list == self.poolCategoryList then
    local s = FabriXGui.POOL_SECTIONS[section]
    return s and s.count or 0
  end

  if list == self.poolWorkerList then
    return #(self.poolWorkerRows or {})
  end

  if list == self.alertList then
    return #(self.alertRows or {})
  end

  return #self.rows
end

function FabriXGui:getCellTypeForItemInSection(list, section, index)
  if list == self.categoryList or list == self.poolCategoryList then
    return "categoryCell"
  end

  if list == self.workerMarketList or list == self.poolWorkerList then
    return "workerCell"
  end

  if list == self.alertList then return "alertCell" end
  return "fabrixCell"
end

function FabriXGui:populateCellForItemInSection(list, section, index, cell)
  cell.target = self

  if list == self.alertList then
    local row = (self.alertRows or {})[index]

    if row == nil then return end

    local textCell = cell:getAttribute("text")

    if textCell ~= nil then
      textCell:setText(row.text)
      local color = row.color or { 0.88, 0.90, 0.86, 1 }
      textCell:setTextColor(color[1], color[2], color[3], color[4])
    end
    return
  end

  -- ---- Category rows (market or pool) ----
  if list == self.categoryList or list == self.poolCategoryList then
    local rows = (list == self.poolCategoryList) and self.poolCategoryRows or self.categoryRows
    local cat = rows[FabriXGui.poolRowIndex(section, index)]

    if cat == nil then return end

    -- get amount of workers, based on the list
    local farmId = g_currentMission:getFarmId()
    local isPool = (list == self.poolCategoryList)

    local market = FabriX:getMarket(farmId)
    local lists = isPool and FabriXGui.getPoolSourceLists(cat) or { market[cat.id] or {} }

    local count = 0

    for _, sourceList in ipairs(lists) do
      for _, worker in ipairs(sourceList) do
        if not isPool or (worker.farmId == farmId and (cat.match == nil or cat.match(worker))) then
          count = count + 1
        end
      end
    end

    -- Label with count, e.g. "Erntehelfer (5)"
    local nameCell = cell:getAttribute("name")
    if nameCell ~= nil then
      nameCell:setText(string.format("%s (%d)", g_i18n:getText(cat.label), count))
    end

    -- Icon: fixed per-category default icon
    local iconCell = cell:getAttribute("icon")
    if iconCell ~= nil then
      local iconPath = DEFAULT_WORKER_ICONS[cat.source or cat.id]
      if iconPath ~= nil and iconPath ~= "" then
        iconCell:setImageFilename(iconPath)
        iconCell:setImageColor(nil, 1, 1, 1, 1)
        iconCell:setVisible(true)
      else
        iconCell:setVisible(false)
      end
    end
    return
  end

  -- worker rows (market or pool)
  if list == self.workerMarketList or list == self.poolWorkerList then
    local rows = (list == self.poolWorkerList) and self.poolWorkerRows or self.workerRows
    local worker = rows[index]

    if worker == nil then return end

    -- Name
    local nameCell = cell:getAttribute("name")
    if nameCell ~= nil then
      nameCell:setText(tostring(worker.name))
    end

    -- Info line
    local infoCell = cell:getAttribute("info")

    if infoCell ~= nil then
      if list == self.poolWorkerList then
        -- Employees tab: level only
        infoCell:setText(string.format(g_i18n:getText("fabrix_gui_level"), worker.level or 0))
      else
        -- Job market: full info (level · age · salary)
        local years = FabriX:getAgeInYearsFromWorker(worker) or 0
        local salary = worker.salary or 0
        infoCell:setText(string.format(g_i18n:getText("fabrix_gui_worker_market_info"), worker.level or 0, years,
          g_i18n:formatMoney(salary, 0, true, false)))
      end
    end

    -- Icon
    local iconCell = cell:getAttribute("icon")
    if iconCell ~= nil then
      local imageFilename = worker.icon
      if imageFilename ~= nil and imageFilename ~= "" then
        iconCell:setImageFilename(imageFilename)
        iconCell:setImageColor(nil, 1, 1, 1, 1)
        iconCell:setVisible(true)
      else
        iconCell:setVisible(false)
      end
    end
    return
  end

  -- production row (factory)
  local production = self.rows[index]

  if production == nil then return end

  local placeable = production.placeable

  -- factory name
  local name = FabriX:getProductionName(production)
  local nameCell = cell:getAttribute("name")

  if nameCell ~= nil then
    nameCell:setText(tostring(name))
  end

  local infoCell = cell:getAttribute("info")

  if infoCell ~= nil then
    local status, partial = FabriX:getProductionStatus(production)
    local color = partial and STATUS_PARTIAL_COLOR or STATUS_COLORS[status]

    infoCell:setText(g_i18n:getText("fabrix_status_" .. status))
    infoCell:setTextColor(color[1], color[2], color[3], color[4])
  end

  -- factory store icon (from the placeable)
  local iconCell = cell:getAttribute("icon")

  if iconCell ~= nil then
    local imageFilename = nil

    if placeable ~= nil and placeable.getImageFilename ~= nil then
      imageFilename = placeable:getImageFilename()
    end

    if imageFilename ~= nil and imageFilename ~= "" then
      iconCell:setImageFilename(imageFilename)
      iconCell:setImageColor(nil, 1, 1, 1, 1)
      iconCell:setVisible(true)
    else
      iconCell:setVisible(false)
    end
  end
end

-- Highlights the active tab button by color.
function FabriXGui:highlightActiveTab(activeIndex)
  if self.tabs == nil then return end

  for i, tab in ipairs(self.tabs) do
    if tab ~= nil then
      if i == activeIndex then
        tab:setTextColor(0.68, 0.96, 0.08, 1) -- active: lightgreen
      else
        tab:setTextColor(1, 1, 1, 1)          -- inactive: white
      end
    end
  end
end

function FabriXGui.poolRowIndex(section, index)
  for s = 1, section - 1 do index = index + FabriXGui.POOL_SECTIONS[s].count end
  return index
end

-- reverse of poolRowIndex: row index -> section, index in section
function FabriXGui.poolSectionOf(i)
  for s, def in ipairs(FabriXGui.POOL_SECTIONS) do
    if i <= def.count then return s, i end
    i = i - def.count
  end
  return 1, 1
end

function FabriXGui:getTitleForSectionHeader(list, section)
  local s = list == self.poolCategoryList and FabriXGui.POOL_SECTIONS[section]
  if s and s.title then
    return g_i18n:getText(s.title)
  end
  return nil
end
