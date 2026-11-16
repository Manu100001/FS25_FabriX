-- Parses a comma-separated l10n string into a list of trimmed names.
local function parseNamePool(l10nKey)
  local names = {}
  for name in string.gmatch(g_i18n:getText(l10nKey), "([^,]+)") do
    table.insert(names, string.trim(name))
  end
  return names
end

-- level up text with the worker's role (Azubi, Geselle, Meister, ...)
local function levelUpText(worker)
  return { "fabrix_worker_level_up", { FabriX:getWorkerRoleKey(worker) }, tostring(worker.name), worker.level }
end

-- rank and name for notifications, e.g. "Geselle Markus"
function FabriX:getWorkerTitle(worker)
  return FabriX:localizeText(FabriX:getWorkerTitleL10n(worker))
end

-- same as getWorkerTitle, but untranslated for FabriX:notify
function FabriX:getWorkerTitleL10n(worker)
  return { "fabrix_worker_title", { FabriX:getWorkerRoleKey(worker) }, tostring(worker.name) }
end

-- removes the worker from every shift slot and leadership role
function FabriX:clearAssignment(worker)
  worker.factoryId = ""
  worker.shiftId = 0
  worker.slotId = 0
  worker.roleSlot = nil
end

-- Lazily builds and caches both name pools. Returns male, female lists
function FabriX:getNamePools()
  if FabriX.worker.namePools == nil then
    FabriX.worker.namePools = {
      male = parseNamePool("ui_helper_name_pool_male"),
      female = parseNamePool("ui_helper_name_pool_female"),
    }
  end
  return FabriX.worker.namePools.male, FabriX.worker.namePools.female
end

-- #####################
-- # Worker generation #
-- #####################
-- returns the market of a farm, creates it on first access
function FabriX:getMarket(farmId)
  local market = FabriX.worker.market[farmId]

  if market == nil then
    market = { erntehelfer = {}, azubis = {}, facharbeiter = {} }
    FabriX.worker.market[farmId] = market
  end

  return market
end

function FabriX:addWorkersToMarket(farmId, category, count)
  local market = FabriX:getMarket(farmId)

  for _, worker in ipairs(FabriX:createWorkers(category, count)) do
    table.insert(market[category], worker)
  end
end

function FabriX:createWorkers(category, count)
  -- Name pools are parsed once (cached) and reused for every worker
  local maleNames, femaleNames = FabriX:getNamePools()
  local workers = {}

  for _ = 1, count do
    table.insert(workers, FabriX:buildWorker(category, maleNames, femaleNames))
  end
  return workers
end

-- builds and returns ONE worker. Pure: touches no global market state
function FabriX:buildWorker(category, maleNames, femaleNames)
  if category == "facharbeiter" then
    return FabriX:buildFacharbeiter(maleNames, femaleNames)
  elseif category == "azubis" then
    return FabriX:buildAzubi(maleNames, femaleNames)
  else
    return FabriX:buildErntehelfer(maleNames, femaleNames)
  end
end

-- azubis: between 16 and 21 years
function FabriX:buildAzubi(maleNames, femaleNames)
  local level = 1
  local age = math.random(16 * 12, 21 * 12)

  return FabriX:buildWorkerBase("azubis", maleNames, femaleNames, age, level)
end

-- facharbeiter: 25-35 years, level 4-10
function FabriX:buildFacharbeiter(maleNames, femaleNames)
  local level = FabriX:rollFacharbeiterLevel()
  local age = math.random(25 * 12, 35 * 12)
  local variation = FabriX:rollSalaryVariation("facharbeiter")

  return FabriX:buildWorkerBase("facharbeiter", maleNames, femaleNames, age, level, variation)
end

-- erntehelfer
function FabriX:buildErntehelfer(maleNames, femaleNames)
  local level = math.random(1, 3)
  local age = math.random(30 * 12, 55 * 12)
  local variation = FabriX:rollSalaryVariation("erntehelfer")

  return FabriX:buildWorkerBase("erntehelfer", maleNames, femaleNames, age, level, variation)
end

function FabriX:buildWorkerBase(category, maleNames, femaleNames, age, level, salaryVariation)
  -- no variation for Azubis
  salaryVariation = salaryVariation or 1.0

  -- grab a random NPC portrait; its path tells us the gender
  local imageFilename = nil
  if g_npcManager ~= nil then
    local npc = g_npcManager:getRandomNPC()
    if npc ~= nil then
      imageFilename = npc.imageFilename
    end
  end

  -- Female if the portrait is the animal-dealer image, otherwise male
  local isFemale = (imageFilename == FabriX.worker.FEMALE_IMAGE)
  local namePool = isFemale and femaleNames or maleNames
  local name = namePool[math.random(1, #namePool)]
  local base = FabriX.worker.BASE_SALARY[category]

  base = math.floor(base * salaryVariation + 0.5)

  local salary = FabriX:getSalaryFor(category, level, base)

  local worker = {
    id = FabriX:generateUniqueUUID(),
    icon = imageFilename,
    name = name,
    category = category,
    age = age,
    level = level,
    xp = 0,
    baseSalary = base,
    salary = salary,
    farmId = 0,
    factoryId = "",
    slotId = 0,
    shiftId = 0,
    inSchool = false,
    schoolMinutesLeft = 0,
    pendingSchool = false,
    resignationGiven = false,
    resignationMonthsLeft = 0,
    selfResigned = false,
    sickMinutesLeft = 0,
    workedToday = false,
  }

  return worker
end

-- generate unique uuid for every worker
function FabriX:generateUniqueUUID()
  local uuidTemplate = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  return (string.gsub(uuidTemplate, "[xy]", function(placeholder)
    local hexValue
    if placeholder == "x" then
      hexValue = math.random(0, 15)
    else
      hexValue = math.random(8, 11)
    end
    return string.format("%x", hexValue)
  end))
end

-- return age in years
function FabriX:getAgeInYearsFromWorker(worker)
  local months = worker ~= nil and worker.age or nil
  if months == nil then return end
  return math.floor(months / 12)
end

-- check if a worker can be assigned to the clicked slot
function FabriX:canAssignWorkerToSlot(worker, production, shiftId)
  if worker == nil or production == nil then
    return false, g_i18n:getText("fabrix_worker_invalid_data")
  end

  -- on school
  if worker.inSchool then
    return false, g_i18n:getText("fabrix_worker_in_training")
  end

  if FabriX:isSick(worker) then
    return false, g_i18n:getText("fabrix_worker_sick_blocked")
  end

  -- 8h already worked
  if worker.workedToday then
    return false, g_i18n:getText("fabrix_worker_already_worked")
  end

  if worker.category == "azubis" then
    -- azubis only for production with level 3 or higher
    if production.level < FabriX.AZUBI_MIN_FACTORY_LEVEL then
      return false, g_i18n:getText("fabrix_worker_azubi_level3")
    end
    -- azubis only in the day shift

    if shiftId ~= FabriX.worker.SHIFT_DAY then
      return false, g_i18n:getText("fabrix_worker_azubi_dayshift")
    end
  end
  return true
end

function FabriX:canAssignWorkerToRoleSlot(worker, roleSlot)
  if worker == nil then
    return false, g_i18n:getText("fabrix_worker_invalid_data")
  end

  if worker.inSchool then
    return false, g_i18n:getText("fabrix_worker_in_training")
  end

  if FabriX:isSick(worker) then
    return false, g_i18n:getText("fabrix_worker_sick_blocked")
  end

  if worker.category ~= "facharbeiter" then
    return false, g_i18n:getText("fabrix_worker_only_facharbeiter")
  end

  if roleSlot == "meister" then
    if FabriX:getFacharbeiterRank(worker) ~= "meister" then
      return false, g_i18n:getText("fabrix_worker_only_meister")
    end

    return true
  elseif roleSlot == "betriebsleiter" then
    if FabriX:getFacharbeiterRank(worker) ~= "betriebsleiter" then
      return false, g_i18n:getText("fabrix_worker_only_betriebsleiter")
    end

    return true
  end
  return false, g_i18n:getText("fabrix_worker_unknown_slot")
end

-- Formatted text for "employed since"
function FabriX:getEmploymentText(worker)
  local months = worker.monthsEmployed or 0

  if months < 12 then
    return string.format(g_i18n:getText("fabrix_worker_months"), months)
  end

  local years = math.floor(months / 12)

  return string.format(g_i18n:getText("fabrix_worker_years"), years)
end

-- Returns the level table matching the category
function FabriX:getLevelTable(category)
  if category == "facharbeiter" or category == "azubis" then
    return FabriX.worker.LEVELS_FACHARBEITER
  end

  return FabriX.worker.LEVELS_ERNTEHELFER
end

-- Productivity factor of the current level
function FabriX:getWorkerProductivity(worker)
  local levelDefinitions = FabriX:getLevelTable(worker.category)
  local workerLevel = worker.level or 1
  local levelDefinition = levelDefinitions[workerLevel]

  -- Betriebsleiter (level 10) has prod=0 as a leadership role.
  -- In a normal shift he should work like a Meister (level 9), though.
  if levelDefinition ~= nil and (levelDefinition.factor or levelDefinition.prod or 0) <= 0 then
    local previousLevelDefinition = levelDefinitions[workerLevel - 1]
    if previousLevelDefinition ~= nil then
      return previousLevelDefinition.factor or previousLevelDefinition.prod or 1.0
    end
  end

  if levelDefinition == nil then
    return 1.0
  end

  return levelDefinition.factor or levelDefinition.prod or 1.0
end

-- XP progress for the bar: current, max, ratio
function FabriX:getWorkerXpProgress(worker)
  local def = FabriX:getLevelTable(worker.category)[worker.level or 1]
  local maxXp = (def and def.xpToNext) or 0
  local curXp = worker.xp or 0

  if maxXp <= 0 then
    return curXp, 0, 1
  end

  if curXp > maxXp then
    curXp = maxXp
  end

  return curXp, maxXp, (curXp / maxXp)
end

-- Accumulates XP. Erntehelfer level up automatically. Facharbeiter/Azubi
-- are handled separately (school/manual) -> here we only accumulate
function FabriX:addWorkerXp(worker, amount)
  if worker == nil or amount == nil or amount <= 0 then return end

  worker.level = worker.level or 1
  worker.xp = worker.xp + amount

  if worker.category == "erntehelfer" then
    local levels = FabriX.worker.LEVELS_ERNTEHELFER
    while worker.level < FabriX.worker.MAX_WORKER_LEVEL do
      local need = levels[worker.level] and levels[worker.level].xpToNext or 0
      if need <= 0 or worker.xp < need then
        break
      end
      worker.xp = worker.xp - need
      worker.level = worker.level + 1
      worker.salary = FabriX:getSalaryFor(worker.category, worker.level, worker.baseSalary)
      FabriX:notify(worker.farmId, FSBaseMission.INGAME_NOTIFICATION_INFO,
        levelUpText(worker), FabriX.NOTIFY_GROUP.PROGRESS)
    end
    return
  end

  -- ===== From here on only Facharbeiter/Azubi =====
  if worker.inSchool then return end
  if worker.resignationGiven then return end
  if worker.level >= FabriX.worker.MAX_WORKER_LEVEL then return end

  local def = FabriX.worker.LEVELS_FACHARBEITER[worker.level]
  local need = def and def.xpToNext or 0

  if need <= 0 or worker.xp < need then return end

  worker.xp = need -- cap
  if def.schoolAuto then
    FabriX:startSchool(worker)
  elseif (def.schoolMonths or 0) > 0 then
    if not worker.pendingSchool then
      worker.pendingSchool = true
      FabriX:notify(worker.farmId, FSBaseMission.INGAME_NOTIFICATION_INFO,
        { "fabrix_worker_training_ready", tostring(worker.name) }, FabriX.NOTIFY_GROUP.PROGRESS)

      -- pendingSchool is not part of the minute sync
      FabriX:syncToClients()
    end
  else
    worker.level = worker.level + 1
    worker.xp = 0
    worker.salary = FabriX:getSalaryFor(worker.category, worker.level, worker.baseSalary)
    FabriX:notify(worker.farmId, FSBaseMission.INGAME_NOTIFICATION_INFO,
      levelUpText(worker), FabriX.NOTIFY_GROUP.PROGRESS)
  end
end

-- returns true when the current ingame hour lies within the worker's shift (hours: see getCurrentShiftId)
function FabriX:isWorkerOnShift(worker)
  return worker ~= nil and (worker.shiftId or 0) > 0 and worker.shiftId == FabriX:getCurrentShiftId()
end

function FabriX:startSchool(worker)
  if worker == nil then return end

  local def = FabriX.worker.LEVELS_FACHARBEITER[worker.level]
  if def == nil then return end

  worker.inSchool = true
  worker.pendingSchool = false
  worker.schoolMinutesLeft = FabriX:getSchoolMinutes(def.schoolMonths)

  FabriX:clearAssignment(worker)

  FabriX:notify(worker.farmId, FSBaseMission.INGAME_NOTIFICATION_INFO,
    { "fabrix_worker_training_enrolled", tostring(worker.name), def.schoolMonths }, FabriX.NOTIFY_GROUP.PROGRESS)

  -- slot/role changed and the minute sync does not carry them
  FabriX:syncToClients()
end

-- Compute school duration in in-game minutes from months
function FabriX:getSchoolMinutes(months)
  return (months or 0) * FabriX:getMinutesPerMonth()
end

-- one sick day = one in-game day (24 h), independent of daysPerPeriod
function FabriX:getSickMinutesPerDay()
  return 24 * 60
end

function FabriX:isSick(worker)
  return (worker.sickMinutesLeft or 0) > 0
end

-- skilled worker who may be sent to school now (waiting, not enrolled, not leaving, not sick)
function FabriX:canStartSchool(worker)
  return worker.category == "facharbeiter" and worker.pendingSchool == true and not worker.inSchool and not worker.resignationGiven and not FabriX:isSick(worker)
end

function FabriX:getSickDaysLeft(worker)
  return math.ceil((worker.sickMinutesLeft or 0) / FabriX:getSickMinutesPerDay())
end

-- server: rolls the lifelong sick factor once per worker
function FabriX:getSickFactor(worker)
  if worker.sickFactor == nil then
    local roll = math.random(1, 100)
    for _, sickType in ipairs(FabriX.worker.SICK_TYPES) do
      if roll <= sickType.share then
        worker.sickFactor = sickType.factor
        break
      end
      roll = roll - sickType.share
    end
  end
  return worker.sickFactor or 1
end

-- server: the worker falls sick and leaves his slot or role
function FabriX:startSick(worker)
  local reasons = FabriX.worker.SICK_REASONS
  local reason = reasons[math.random(#reasons)]
  local days = math.random(reason.min, reason.max)
  worker.sickMinutesLeft = math.max(1, math.floor(days * FabriX:getSickMinutesPerDay()))

  FabriX:clearAssignment(worker)

  FabriX:notify(worker.farmId, FSBaseMission.INGAME_NOTIFICATION_INFO,
    { "fabrix_worker_sick_" .. reason.key, FabriX:getWorkerTitleL10n(worker), days }, FabriX.NOTIFY_GROUP.SICKNESS)
end

-- server, at month change: rare resignation by the worker himself
function FabriX:rollSelfResignation(worker)
  if worker.category == "azubis" or worker.inSchool or worker.resignationGiven then return end

  local chance = FabriX.worker.SELF_RESIGN_CHANCE

  if FabriX:isWorkerFree(worker) then
    chance = chance * FabriX.worker.SELF_RESIGN_IDLE_FACTOR
  end

  if (worker.monthsEmployed or 0) >= FabriX.worker.SELF_RESIGN_LOYAL_MONTHS then
    chance = chance * FabriX.worker.SELF_RESIGN_LOYAL_FACTOR
  end

  if math.random() >= chance then return end

  worker.resignationGiven = true
  worker.selfResigned = true
  worker.resignationMonthsLeft = FabriX:getNoticeMonths(worker)

  FabriX:notify(worker.farmId, FSBaseMission.INGAME_NOTIFICATION_INFO,
    { "fabrix_worker_self_resigned", FabriX:getWorkerTitleL10n(worker), FabriX:getNoticeL10n(worker) })
end

function FabriX:getCounterOfferSalary(worker, percent)
  local base = math.floor((worker.baseSalary or FabriX.worker.BASE_SALARY[worker.category]) * (1 + percent / 100) + 0.5)
  return FabriX:getSalaryFor(worker.category, worker.level, base), base
end

-- Returns the notice period in months. -1 = not dismissible (Azubi)
function FabriX:getNoticeMonths(worker)
  if worker.category == "azubis" then
    -- Azubis cannot be dismissed
    return -1
  end

  if worker.category == "erntehelfer" then
    return 0 -- end of month
  end

  -- Facharbeiter: by level
  return FabriX.worker.NOTICE_MONTHS_FACHARBEITER[worker.level or 1] or 0
end

-- Human-readable text for the notice period
function FabriX:getNoticeText(worker)
  return FabriX:localizeText(FabriX:getNoticeL10n(worker))
end

-- same as getNoticeText, but untranslated for FabriX:notify
function FabriX:getNoticeL10n(worker)
  local m = FabriX:getNoticeMonths(worker)

  if m < 0 then
    return { "fabrix_worker_notice_none" }
  end

  if m == 0 then
    return { "fabrix_worker_notice_month_end" }
  end

  return { "fabrix_worker_notice_months", m }
end

-- returns the withdrawal fee after dismissal
function FabriX:getWithdrawFee(worker)
  if worker.category == "erntehelfer" then
    return FabriX.worker.WITHDRAW_FEE_ERNTEHELFER
  elseif worker.category == "facharbeiter" then
    return FabriX.worker.WITHDRAW_FEE_FACHARBEITER[worker.level or 4]
  end
  return 0
end

function FabriX:getSeverance(worker)
  local months = worker.monthsEmployed or 0
  return months * FabriX.worker.SEVERANCE_PER_MONTH
end

function FabriX:getSchoolMonthsLeft(worker)
  if worker == nil or not worker.inSchool then return 0 end

  return math.ceil((worker.schoolMinutesLeft or 0) / FabriX:getMinutesPerMonth())
end

-- duration of the next training in months (0 if none defined for the level)
function FabriX:getSchoolMonths(worker)
  local def = FabriX.worker.LEVELS_FACHARBEITER[worker and worker.level or 1]
  return (def and def.schoolMonths) or 0
end

function FabriX:getSchoolFee(worker)
  if worker == nil then return 0 end

  return FabriX.worker.SCHOOL_FEE_FACHARBEITER[worker.level or 0] or 0
end

function FabriX:getSalaryFor(category, level, baseSalary)
  level = level or 1

  local base = baseSalary or FabriX.worker.BASE_SALARY[category]

  local def = FabriX:getLevelTable(category)[level]

  -- Facharbeiter/Azubi: .salary, Erntehelfer: .factor (= productivity and salary)
  local factor = def and (def.salary or def.factor) or 1.0

  return math.floor(base * factor + 0.5)
end

-- get start level based on spawn weights
function FabriX:rollFacharbeiterLevel()
  local weights = FabriX.worker.FACHARBEITER_SPAWN_WEIGHTS
  local total = 0

  for _, weight in pairs(weights) do
    total = total + weight
  end

  local r = math.random(1, total)
  local acc = 0

  for level = FabriX.worker.AZUBI_GRADUATE_LEVEL, FabriX.worker.MAX_WORKER_LEVEL do
    local w = weights[level]
    if w ~= nil then
      acc = acc + w
      if r <= acc then
        return level
      end
    end
  end
  return 4
end

function FabriX:rollSalaryVariation(category)
  local min = FabriX.worker.SALARY_VARIATION_MIN
  return math.random(100 + min, 100 + (FabriX.worker.SALARY_VARIATION_MAX[category] or min)) / 100
end

-- can the worker be assigned (no shift slot, no leadership role, not in school, not sick)?
function FabriX:isWorkerFree(worker)
  if worker == nil then return false end

  local noSlot = (worker.slotId == nil or worker.slotId == 0)
  local noRole = (worker.roleSlot == nil or worker.roleSlot == "")

  return noSlot and noRole and not worker.inSchool and not FabriX:isSick(worker)
end

-- returns the target number of market workers for a category, based on the number of factories
function FabriX:getMarketTargetSize(category, factoryCount, period)
  if category == "azubis" and not FabriX.worker.AZUBI_ENROLMENT_PERIODS[period] then
    return 0
  end

  local tiers = FabriX.worker.MARKET_SIZE[category]
  if tiers == nil then return 0 end

  local amount = 0

  for _, tier in ipairs(tiers) do
    if factoryCount >= tier.minFactories then
      amount = tier.amount
    end
  end

  return amount
end

-- server only: charges the farm; false if it cannot afford the fee
function FabriX:payFee(farmId, fee, moneyType)
  local balance = g_currentMission:getMoney(farmId)

  if balance ~= nil and balance < fee then return false end

  if fee > 0 then g_currentMission:addMoney(-fee, farmId, moneyType, true, true) end
  return true
end

-- server only: a farm hires a worker from its own market
function FabriX.actions.hire(farmId, workerId, category)
  local marketList = FabriX:getMarket(farmId)[category]

  if marketList == nil then return end

  for i, worker in ipairs(marketList) do
    if worker.id == workerId then
      if not FabriX:payFee(farmId, FabriX.worker.HIRE_FEE, MoneyType.FABRIX_HIRING) then
        FabriX:notify(farmId, FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
          { "fabrix_gui_hire_no_money", g_i18n:formatMoney(FabriX.worker.HIRE_FEE, 0, true, false) })
        return
      end

      table.remove(marketList, i)

      worker.farmId = farmId

      FabriX:clearAssignment(worker)

      worker.monthsEmployed = 0
      worker.inSchool = false
      worker.schoolMinutesLeft = 0
      worker.pendingSchool = false
      worker.resignationGiven = false
      worker.resignationMonthsLeft = 0
      worker.workedToday = false
      table.insert(FabriX.worker.employees[category], worker)
      return
    end
  end
end

-- server only: an employee of the given farm; nil if the id belongs to another farm
function FabriX:findEmployee(farmId, workerId)
  for _, list in pairs(FabriX.worker.employees) do
    for _, worker in ipairs(list) do
      if worker.id == workerId and worker.farmId == farmId then
        return worker
      end
    end
  end
end

function FabriX.actions.dismiss(farmId, workerId)
  local worker = FabriX:findEmployee(farmId, workerId)

  if worker == nil or worker.resignationGiven then
    return
  end

  local months = FabriX:getNoticeMonths(worker)

  -- azubis cannot be dismissed (notice months = -1)
  if months < 0 then return end

  worker.resignationGiven = true
  worker.resignationMonthsLeft = months
  -- 0 = expires at the next month change
end

function FabriX.actions.withdrawResignation(farmId, workerId)
  local worker = FabriX:findEmployee(farmId, workerId)

  if worker == nil or not worker.resignationGiven or worker.selfResigned then
    return
  end

  if not FabriX:payFee(farmId, FabriX:getWithdrawFee(worker), MoneyType.FABRIX_HIRING) then
    return
  end

  worker.resignationGiven = false
  worker.resignationMonthsLeft = 0

  FabriX:notify(farmId, FSBaseMission.INGAME_NOTIFICATION_INFO, { "fabrix_gui_withdraw_done", tostring(worker.name) })
end

function FabriX.actions.train(farmId, workerId)
  local worker = FabriX:findEmployee(farmId, workerId)

  if worker == nil or not FabriX:canStartSchool(worker) then
    return
  end

  if not FabriX:payFee(farmId, FabriX:getSchoolFee(worker), MoneyType.FABRIX_SCHOOL) then
    return
  end

  FabriX:startSchool(worker)
end

function FabriX.actions.assignSlot(farmId, workerId, productionId, shiftId, slotId)
  local worker = FabriX:findEmployee(farmId, workerId)
  local production = FabriX:findProduction(farmId, productionId)

  shiftId, slotId = tonumber(shiftId), tonumber(slotId)

  if worker == nil or production == nil or shiftId == nil or slotId == nil or shiftId ~= math.floor(shiftId) or slotId ~= math.floor(slotId) then
    return
  end

  if shiftId < 1 or shiftId > FabriX.worker.SHIFT_COUNT or slotId < 1 or slotId > FabriX:getSlotsPerShift(production) then
    return
  end

  if not FabriX:isWorkerFree(worker) or not FabriX:canAssignWorkerToSlot(worker, production, shiftId) then
    return
  end

  if FabriX:getAssignedWorkers(farmId, production.id, shiftId)[slotId] ~= nil then
    return
  end

  worker.factoryId = production.id
  worker.shiftId = shiftId
  worker.slotId = slotId

  if FabriX:isWorkerOnShift(worker) then
    worker.workedToday = true
  end
end

function FabriX.actions.assignRole(farmId, workerId, productionId, roleSlot)
  local worker = FabriX:findEmployee(farmId, workerId)
  local production = FabriX:findProduction(farmId, productionId)
  local minLevel = FabriX.ROLE_MIN_LEVEL[roleSlot]

  if worker == nil or production == nil or minLevel == nil or production.level < minLevel then
    return
  end

  if not FabriX:isWorkerFree(worker) or FabriX:getRoleHolder(production, roleSlot) then
    return
  end

  if not FabriX:canAssignWorkerToRoleSlot(worker, roleSlot) then
    return
  end

  worker.factoryId = production.id
  worker.roleSlot = roleSlot
  worker.shiftId = 0
  worker.slotId = 0
end

--removed by hand (single or whole factory); same rules for both
local function releaseWorker(worker, production)
  if FabriX:isWorkerOnShift(worker) then
    worker.workedToday = true
  end

  -- shortcut: the marker is not saved, after loading a savegame the auto mode fills the slot
  if production ~= nil and production.autoMode then
    production.autoSkip = production.autoSkip or {}
    production.autoSkip[(worker.roleSlot or "") ~= "" and worker.roleSlot or worker.shiftId .. ":" .. worker.slotId] = true
  end

  -- the auto-mode leaves him alone until the day changed
  worker.autoSkipToday = true
  FabriX:clearAssignment(worker)
end

-- removes a worker from his shift slot or leadership slot; he stays employed
function FabriX.actions.unassign(farmId, workerId)
  local worker = FabriX:findEmployee(farmId, workerId)

  if worker == nil then
    return
  end

  releaseWorker(worker, FabriX:findProduction(farmId, worker.factoryId))
end

-- removes every worker (shifts and leadership) from one factory, same rules as unassign
function FabriX.actions.clearFactory(farmId, productionId)
  local production = FabriX:findProduction(farmId, productionId)

  if production == nil then return end

  production.autoMode = false

  for _, categoryList in pairs(FabriX.worker.employees) do
    for _, worker in ipairs(categoryList) do
      if worker.farmId == farmId and worker.factoryId == productionId then
        releaseWorker(worker, production)
      end
    end
  end
end

-- the client sends true/false; the level is checked again here because the client can't be trusted
function FabriX.actions.setAutoMode(farmId, productionId, enabled)
  local production = FabriX:findProduction(farmId, productionId)

  if production == nil or (production.level or 1) < FabriX.AUTO_MODE_MIN_LEVEL then return end

  production.autoMode = enabled == "true"

  if production.autoMode then
    production.autoSkip = nil
    FabriX:runAutoMode(false)
  end
end

-- ---- Auto-Modus (server only) -------------------------------------------------

local AUTO_CATEGORY_ORDER = { azubis = 1, facharbeiter = 2, erntehelfer = 3 }

-- all employees of a farm: Azubis, then Facharbeiter, then Erntehelfer; best productivity first
local function getAutoCandidates(farmId)
  local list = {}

  for _, categoryList in pairs(FabriX.worker.employees) do
    for _, worker in ipairs(categoryList) do
      if worker.farmId == farmId then
        table.insert(list, worker)
      end
    end
  end

  table.sort(list, function(a, b)
    local orderA, orderB = AUTO_CATEGORY_ORDER[a.category] or 9, AUTO_CATEGORY_ORDER[b.category] or 9

    if orderA ~= orderB then
      return orderA < orderB
    end

    return FabriX:getWorkerProductivity(a) > FabriX:getWorkerProductivity(b)
  end)

  return list
end

-- free, or in a shift slot of another factory under renovation; anyShift (roles only) allows every shift slot
local function isAutoSource(worker, production, anyShift)
  if worker.autoSkipToday then return false end

  if FabriX:isWorkerFree(worker) then
    return true
  end

  if (worker.roleSlot or "") ~= "" or (worker.slotId or 0) == 0 then
    return false
  end

  if anyShift then
    return true
  end

  local source = worker.factoryId ~= production.id and FabriX:findProduction(worker.farmId, worker.factoryId)

  return source and source.isOnUpgrade == true
end

-- same rule as unassign and assignSlot: leaving or joining a running shift counts as worked today
local function autoMove(worker, production, shiftId, slotId, roleSlot)
  if FabriX:isWorkerOnShift(worker) then
    worker.workedToday = true
  end

  worker.factoryId = production ~= nil and production.id or ""
  worker.shiftId = shiftId
  worker.slotId = slotId
  worker.roleSlot = roleSlot

  if FabriX:isWorkerOnShift(worker) then
    worker.workedToday = true
  end
end

local function findFreeSlot(worker, production, skip)
  for shiftId = 1, FabriX.worker.SHIFT_COUNT do
    local assigned = FabriX:getAssignedWorkers(production.farmId, production.id, shiftId)

    for slotId = 1, FabriX:getSlotsPerShift(production) do
      if assigned[slotId] == nil and not skip[shiftId .. ":" .. slotId] and FabriX:canAssignWorkerToSlot(worker, production, shiftId) then
        return shiftId, slotId
      end
    end
  end
end

-- day change: a free Azubi takes the full day shift's slot of the weakest non-Azubi; he moves to a free slot here or to the pool
local function placeAzubis(production, candidates, skip)
  local dayShift = FabriX.worker.SHIFT_DAY
  local changed = false

  for _, azubi in ipairs(candidates) do
    if azubi.category ~= "azubis" then
      break
    end

    if FabriX:isWorkerFree(azubi) and FabriX:canAssignWorkerToSlot(azubi, production, dayShift) then
      local assigned, count, weakest = FabriX:getAssignedWorkers(production.farmId, production.id, dayShift), 0, nil

      for _, worker in pairs(assigned) do
        count = count + 1

        if worker.category ~= "azubis" and (weakest == nil or FabriX:getWorkerProductivity(worker) < FabriX:getWorkerProductivity(weakest)) then
          weakest = worker
        end
      end

      -- free day slots are filled later anyway, Azubis come first there
      if count < FabriX:getSlotsPerShift(production) or weakest == nil then
        break
      end

      local slotId = weakest.slotId
      autoMove(weakest, nil, 0, 0, nil)
      autoMove(azubi, production, dayShift, slotId, nil)

      local shiftId, freeSlotId = findFreeSlot(weakest, production, skip)
      if shiftId ~= nil then
        autoMove(weakest, production, shiftId, freeSlotId, nil)
      end

      changed = true
    end
  end

  return changed
end

-- free workers first, then pull from any shift slot (never from a leadership role)
local function fillRoles(production, candidates, skip)
  local changed = false

  for roleSlot, minLevel in pairs(FabriX.ROLE_MIN_LEVEL) do
    if production.level >= minLevel and not skip[roleSlot] and FabriX:getRoleHolder(production, roleSlot) == nil then
      for _, anyShift in ipairs({ false, true }) do
        if FabriX:getRoleHolder(production, roleSlot) ~= nil then break end

        for _, worker in ipairs(candidates) do
          if isAutoSource(worker, production, anyShift) and FabriX:canAssignWorkerToRoleSlot(worker, roleSlot) then
            autoMove(worker, production, 0, 0, roleSlot)
            changed = true
            break
          end
        end
      end
    end
  end

  return changed
end

local function fillSlots(production, candidates, skip)
  local changed = false

  for shiftId = 1, FabriX.worker.SHIFT_COUNT do
    local assigned = FabriX:getAssignedWorkers(production.farmId, production.id, shiftId)

    for slotId = 1, FabriX:getSlotsPerShift(production) do
      if assigned[slotId] == nil and not skip[shiftId .. ":" .. slotId] then
        for _, worker in ipairs(candidates) do
          if isAutoSource(worker, production, false) and FabriX:canAssignWorkerToSlot(worker, production, shiftId) then
            autoMove(worker, production, shiftId, slotId, nil)
            changed = true
            break
          end
        end
      end
    end
  end

  return changed
end

-- server only, every ingame minute; true if a worker was moved
function FabriX:runAutoMode(isDayChange)
  local changed = false
  local candidatesByFarm = {}

  for _, production in ipairs(FabriX.productions) do
    if isDayChange then
      production.autoSkip = nil
    end

    if production.autoMode and not production.isOnUpgrade then
      local farmId = production.farmId
      candidatesByFarm[farmId] = candidatesByFarm[farmId] or getAutoCandidates(farmId)

      local candidates = candidatesByFarm[farmId]
      local skip = production.autoSkip or {}

      if isDayChange and production.level >= FabriX.AZUBI_MIN_FACTORY_LEVEL then
        changed = placeAzubis(production, candidates, skip) or changed
      end

      changed = fillRoles(production, candidates, skip) or changed
      changed = fillSlots(production, candidates, skip) or changed
    end
  end

  return changed
end

-- server only: start market for a farm that has none yet; true if created
function FabriX:createStartMarket(farmId)
  if farmId == FarmManager.SPECTATOR_FARM_ID or FabriX.worker.market[farmId] ~= nil then return false end

  FabriX:addWorkersToMarket(farmId, "erntehelfer", FabriX:getMarketTargetSize("erntehelfer", 0))
  FabriX:addWorkersToMarket(farmId, "facharbeiter", FabriX:getMarketTargetSize("facharbeiter", 0))
  return true
end

-- one try only: the worker accepts at random, otherwise he leaves as planned
function FabriX.actions.counterOffer(farmId, workerId, percent)
  local worker = FabriX:findEmployee(farmId, workerId)
  local raise = tonumber(percent)
  local cfg = FabriX.worker

  local chance = raise and cfg.COUNTER_OFFER_CHANCE[raise]

  if worker == nil or chance == nil or not worker.selfResigned or worker.counterOfferRejected then
    return
  end

  if math.random() < chance then
    worker.resignationGiven = false
    worker.resignationMonthsLeft = 0
    worker.selfResigned = false
    worker.salary, worker.baseSalary = FabriX:getCounterOfferSalary(worker, raise)
  else
    worker.counterOfferRejected = true
  end
end

-- l10n key of the role, e.g. fabrix_role_geselle
function FabriX:getWorkerRoleKey(worker)
  if worker.category == "erntehelfer" then
    return "fabrix_category_erntehelfer"
  end

  local def = FabriX.worker.LEVELS_FACHARBEITER[worker.level or 1]

  return (def and def.role) or "fabrix_category_facharbeiter"
end

-- Display role depending on category/level
function FabriX:getWorkerRole(worker)
  return g_i18n:getText(FabriX:getWorkerRoleKey(worker))
end

-- rank of a skilled worker from the level config
function FabriX:getFacharbeiterRank(worker)
  local def = FabriX.worker.LEVELS_FACHARBEITER[worker.level or 4]
  return def and def.role:match("^fabrix_role_(.+)$") or "geselle"
end

-- Finishes school: level-up, possibly category change Azubi -> Facharbeiter
function FabriX:finishSchool(worker)
  if worker == nil then return end

  worker.inSchool = false
  worker.schoolMinutesLeft = 0
  worker.roleSlot = nil -- old savegame kept the role during school
  worker.level = (worker.level or 1) + 1
  worker.xp = 0

  -- category change: from level 4 on he is a "facharbeiter" instead of "azubis".
  if worker.category == "azubis" and worker.level >= FabriX.worker.AZUBI_GRADUATE_LEVEL then
    FabriX:moveWorkerToCategory(worker, "azubis", "facharbeiter")
    worker.category = "facharbeiter"
  end

  worker.salary = FabriX:getSalaryFor(worker.category, worker.level, worker.baseSalary)

  FabriX:notify(worker.farmId, FSBaseMission.INGAME_NOTIFICATION_INFO,
    { "fabrix_worker_training_finished", tostring(worker.name), { FabriX:getWorkerRoleKey(worker) }, worker.level }, FabriX.NOTIFY_GROUP.PROGRESS)

  -- an azubi may have moved to the facharbeiter list; clients need the full state
  FabriX:syncToClients()
end

-- Moves a worker from one category list to another
function FabriX:moveWorkerToCategory(worker, fromKey, toKey)
  local emp = FabriX.worker.employees

  if emp == nil then return end

  emp[toKey] = emp[toKey] or {}

  -- Remove from the old list.
  local src = emp[fromKey]
  if src ~= nil then
    for i = #src, 1, -1 do
      if src[i] == worker or src[i].id == worker.id then
        table.remove(src, i)
        break
      end
    end
  end
  -- Insert into the new list
  table.insert(emp[toKey], worker)
end

function FabriX:addXpToAssignedWorkers(production, xpPerMinute)
  if production == nil then return end
  if FabriX.worker == nil or FabriX.worker.employees == nil then return end

  local factoryId = production.id
  local farmId = production.farmId
  for _, categoryList in pairs(FabriX.worker.employees) do
    for _, worker in ipairs(categoryList) do
      if worker.factoryId == factoryId and worker.farmId == farmId then
        local onShift = worker.slotId ~= nil and worker.slotId > 0 and FabriX:isWorkerOnShift(worker)
        -- Meister/BL work in the day shift (the Meister adds to its productivity)
        local onRole = worker.roleSlot ~= nil and worker.roleSlot ~= "" and FabriX:getCurrentShiftId() == FabriX.worker.SHIFT_DAY

        if worker.factoryId == factoryId and worker.farmId == farmId and (onShift or onRole) then
          -- 10 XP per month, but works only 8h per day --> therefore * 3
          FabriX:addWorkerXp(worker, xpPerMinute * 3)
        end
      end
    end
  end
end
