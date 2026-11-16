-- ##########
-- # Worker #
-- ##########
function FabriX.modules.worker:onMonthChanged()
  -- every employee ages by one month
  local salarySum = {}
  local retirementMonths = FabriX.worker.RETIREMENT_AGE * 12

  for _, categoryList in pairs(FabriX.worker.employees or {}) do
    for i = #categoryList, 1, -1 do
      local worker = categoryList[i]
      worker.monthsEmployed = (worker.monthsEmployed or 0) + 1
      worker.age = (worker.age or 0) + 1
      local removed = false

      -- retirement: worker leaves the company when reaching retirement age
      if worker.age >= retirementMonths then
        table.remove(categoryList, i)
        FabriX:notify(worker.farmId, FSBaseMission.INGAME_NOTIFICATION_INFO,
          { "fabrix_worker_retired", tostring(worker.name) }, FabriX.NOTIFY_GROUP.STAFF)
        removed = true
      end

      if not removed and worker.resignationGiven then
        if worker.resignationMonthsLeft <= 0 then
          table.remove(categoryList, i)
          -- self-resigned workers leave without severance
          local textKey = worker.selfResigned and "fabrix_worker_left" or "fabrix_worker_dismissed"
          FabriX:notify(worker.farmId, FSBaseMission.INGAME_NOTIFICATION_INFO,
            { textKey, worker.selfResigned and FabriX:getWorkerTitleL10n(worker) or tostring(worker.name) }, FabriX.NOTIFY_GROUP.STAFF)

          local severance = worker.selfResigned and 0 or FabriX:getSeverance(worker)

          if severance > 0 then
            g_currentMission:addMoney(-severance, worker.farmId, MoneyType.FABRIX_SEVERANCE, true, true)
          end
        else
          worker.resignationMonthsLeft = worker.resignationMonthsLeft - 1
        end
      end

      -- azubi apprenticeship deadline: an apprentice who does not graduate at time
      -- costs money; after 5 years he gives up and leaves the farm
      if not removed and worker.category == "azubis" then
        local farmId = worker.farmId

        if worker.monthsEmployed >= FabriX.worker.AZUBI_LEAVE_MONTHS then
          g_currentMission:addMoney(-FabriX.worker.AZUBI_PENALTY_5_YEARS, farmId, MoneyType.FABRIX_PENALTY, true, true)
          g_currentMission:addMoney(-FabriX.worker.AZUBI_LEAVE_SEVERANCE, farmId, MoneyType.FABRIX_SEVERANCE, true, true)

          table.remove(categoryList, i)

          FabriX:notify(worker.farmId, FSBaseMission.INGAME_NOTIFICATION_INFO,
            { "fabrix_worker_azubi_left", tostring(worker.name) }, FabriX.NOTIFY_GROUP.STAFF)

          removed = true
        elseif worker.monthsEmployed == FabriX.worker.AZUBI_PENALTY_MONTHS then
          g_currentMission:addMoney(-FabriX.worker.AZUBI_PENALTY_4_YEARS, farmId, MoneyType.FABRIX_PENALTY, true, true)

          FabriX:notify(worker.farmId, FSBaseMission.INGAME_NOTIFICATION_INFO,
            { "fabrix_worker_azubi_penalty", tostring(worker.name) })
        end
      end

      if not removed then
        FabriX:rollSelfResignation(worker)
      end

      -- deduct salary costs
      salarySum[worker.farmId] = (salarySum[worker.farmId] or 0) + worker.salary
    end
  end

  -- auto-mode fee: every factory with the switch on at month end, booked with the wages
  for _, production in ipairs(FabriX.productions) do
    if production.autoMode then
      salarySum[production.farmId] = (salarySum[production.farmId] or 0) + FabriX.AUTO_MODE_FEE
    end
  end

  for farmId, sum in pairs(salarySum) do
    g_currentMission:addMoney(-sum, farmId, MoneyType.FABRIX_SALARY, true, true)
  end

  -- market applicants age one month as well
  for _, market in pairs(FabriX.worker.market) do
    for _, categoryList in pairs(market) do
      for _, worker in ipairs(categoryList) do
        worker.age = (worker.age or 0) + 1
      end
    end
  end

  -- per farm: number of factories and apprentices once one factory has reached level 3
  local factoryCount = {}
  local enableAzubis = {}

  for _, production in ipairs(FabriX.productions) do
    factoryCount[production.farmId] = (factoryCount[production.farmId] or 0) + 1

    if production.level >= FabriX.AZUBI_MIN_FACTORY_LEVEL then
      enableAzubis[production.farmId] = true
    end
  end

  -- every 3 months, the market will be deleted
  local period = g_currentMission.environment.currentPeriod
  local deletedMarket = period % 3 == 1

  for _, farm in ipairs(g_farmManager:getFarms()) do
    local farmId = farm.farmId
    if farmId ~= FarmManager.SPECTATOR_FARM_ID then
      local market = FabriX:getMarket(farmId)

      if deletedMarket then
        market.erntehelfer, market.facharbeiter, market.azubis = {}, {}, {}
      end

      for _, category in ipairs({ "erntehelfer", "facharbeiter", "azubis" }) do
        if category ~= "azubis" or enableAzubis[farmId] then
          local target = FabriX:getMarketTargetSize(category, factoryCount[farmId] or 0, period)
          FabriX:addWorkersToMarket(farmId, category, target - #market[category])
        end
      end
    end
  end
end

function FabriX.modules.worker:onMinuteChanged()
  if FabriX.worker == nil or FabriX.worker.employees == nil then return end

  for _, categoryList in pairs(FabriX.worker.employees) do
    for i = #categoryList, 1, -1 do
      local worker = categoryList[i]

      if FabriX:isSick(worker) then
        worker.sickMinutesLeft = worker.sickMinutesLeft - 1
        if worker.sickMinutesLeft <= 0 then
          FabriX:notify(worker.farmId, FSBaseMission.INGAME_NOTIFICATION_INFO,
            { "fabrix_worker_recovered", FabriX:getWorkerTitleL10n(worker) }, FabriX.NOTIFY_GROUP.SICKNESS)
        end
      end

      if worker.inSchool then
        worker.schoolMinutesLeft = (worker.schoolMinutesLeft or 0) - 1
        if worker.schoolMinutesLeft <= 0 then
          FabriX:finishSchool(worker)
        end
      end
      if worker.slotId ~= nil and worker.slotId > 0 then
        if FabriX:isWorkerOnShift(worker) then
          worker.workedToday = true
        end
      end
    end
  end
end

-- server, once per in-game day: day reset and sick notes (FabriX:onDayChanged syncs afterwards)
function FabriX.modules.worker:onDayChanged()
  for _, categoryList in pairs(FabriX.worker.employees or {}) do
    for _, worker in ipairs(categoryList) do
      worker.workedToday = false
      worker.autoSkipToday = nil

      if not worker.inSchool and not FabriX:isSick(worker) then
        local chance = (worker.age or 0) >= FabriX.worker.SICK_AGE_THRESHOLD * 12 and FabriX.worker.SICK_CHANCE_50PLUS or FabriX.worker.SICK_CHANCE
        if math.random() < chance * FabriX:getSickFactor(worker) then
          FabriX:startSick(worker)
        end
      end
    end
  end
end
