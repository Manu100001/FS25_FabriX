-- =============================================================================
-- FabriX - Global variables and configuration constants
-- -----------------------------------------------------------------------------
-- This file is loaded first. It holds the global FabriX table, runtime state
-- and all configuration constants.
-- NOTE: fees, XP and costs are also written literally in the help texts
-- (fabrix_help_* in l10n/) -- update both when balancing
-- Sections: core tables (top, no header) / Production / Worker / Other
-- =============================================================================

FabriX = {}
FabriX.dir = g_currentModDirectory
FabriX.modName = g_currentModName
FabriX.modules = {}
FabriX.modules.production = {}
FabriX.modules.worker = {}

-- =============================================================================
-- Production
-- =============================================================================
-- ---- Runtime state ----------------------------------------------------------
FabriX.productions = {}       -- all tracked productions at runtime
FabriX.loadedDataFromXML = {} -- production data restored from the savegame
FabriX.actions = {}           -- server-side handlers for player actions, see FabriXActionEvent

-- ---- Level progression ------------------------------------------------------
FabriX.MAX_LEVEL = 5
FabriX.MAX_XP_PER_MONTH = 10

-- Capacity factor for input and output storage of each factory, per level
FabriX.CAPACITY_FACTOR = {
    [1] = 1.0, -- Level 1
    [2] = 2.0, -- Level 2
    [3] = 3.5, -- Level 3
    [4] = 5.0, -- Level 4
    [5] = 7.5  -- Level 5
}

-- XP required for each level (xp resets to 0 after an upgrade)
FabriX.XP_FOR_LEVEL = {
    [1] = 0,
    [2] = 80,
    [3] = 110,
    [4] = 210,
    [5] = 330
}

-- Cost to upgrade a production to each level
FabriX.UPGRADE_COSTS = {
    [1] = 0,
    [2] = 30000,
    [3] = 80000,
    [4] = 120000,
    [5] = 250000
}

-- Renovation duration after an upgrade, in ingame months, per level
FabriX.RENOVATION_DURATION = {
    [1] = 0,
    [2] = 1,
    [3] = 2,
    [4] = 3,
    [5] = 3
}

-- auto-mode: available from factory level 2, fee per factory at month end
FabriX.AUTO_MODE_MIN_LEVEL = 2
FabriX.AUTO_MODE_FEE = 150

-- leadership slots: available from this factory level
FabriX.ROLE_MIN_LEVEL = {
    meister = 3,
    betriebsleiter = 5
}

-- notification groups the player can switch off (0 = always shown)
FabriX.NOTIFY_GROUP = {
    PROGRESS = 1, -- level-up and training
    SICKNESS = 2, -- sick / recovered
    STAFF = 3     -- dismissed / left / retired / azubi left
}

-- ---- Running costs ----------------------------------------------------------
FabriX.transportCosts = {}      -- accumulated transport costs (runtime)
FabriX.waterUsage = {}          -- accumulated water usage (runtime)
FabriX.electricityUsage = {}    -- accumulated electricity usage (runtime)
FabriX.WATER_COSTS = 5.45       -- per 1000l (1 m^3)
FabriX.ELECTRICITY_COSTS = 0.35 -- per 1 kWh

FabriX.AZUBI_MIN_FACTORY_LEVEL = 3

-- worst status first; "low" = an input of an active recipe below this share of its capacity
FabriX.STATUS_LOW_SHARE = 0.2

-- a director assigned to a factory reduces that factory's property tax
FabriX.FACTORY_MANAGER_TAX_DISCOUNT = 0.75 -- 75% saved when a director is in place

-- ---- GUI --------------------------------------------------------------------
-- Finance rows and money types: key = MoneyType name / bucket (l10n "finance_" .. key), field = MoneyType.<field>
FabriX.GUI_FINANCE_ROWS = {
    { key = "fabrixTax",            field = "FABRIX_TAX" },
    { key = "fabrixWater",          field = "FABRIX_WATER" },
    { key = "fabrixElectricity",    field = "FABRIX_ELECTRICITY" },
    { key = "fabrixTransportation", field = "FABRIX_TRANSPORTATION" },
    { key = "fabrixSalary",         field = "FABRIX_SALARY", },
    { key = "fabrixSeverance",      field = "FABRIX_SEVERANCE", },
    { key = "fabrixHiring",         field = "FABRIX_HIRING", },
    { key = "fabrixSchool",         field = "FABRIX_SCHOOL", },
    { key = "fabrixPenalty",        field = "FABRIX_PENALTY", }
}

-- =============================================================================
-- Worker
-- =============================================================================
FabriX.worker = {}

-- ---- Runtime state ----------------------------------------------------------
-- Currently employed workers, grouped by category
FabriX.worker.employees = {}
FabriX.worker.employees.erntehelfer = {}
FabriX.worker.employees.azubis = {}
FabriX.worker.employees.facharbeiter = {}

-- Workers available for hire, per farm: [farmId] = {erntehelfer = {}, azubis = {}, facharbeiter = {} }
FabriX.worker.market = {}

-- ---- General config ---------------------------------------------------------
FabriX.worker.RETIREMENT_AGE = 65
FabriX.worker.SHIFT_DAY = 2 -- 08:00 - 16:00 is the day shift

FabriX.worker.SHIFT_COUNT = 3

FabriX.worker.HIRE_FEE = 250
FabriX.worker.SEVERANCE_PER_MONTH = 50

-- self-resignation: chance per month; x4 without slot/role, x0.5 from 5 years on
FabriX.worker.SELF_RESIGN_CHANCE = 0.005
FabriX.worker.SELF_RESIGN_IDLE_FACTOR = 4
FabriX.worker.SELF_RESIGN_LOYAL_MONTHS = 60
FabriX.worker.SELF_RESIGN_LOYAL_FACTOR = 0.5

-- counter offer: raise in percent the player can choose
FabriX.worker.COUNTER_OFFER_RAISE_MIN = 10
FabriX.worker.COUNTER_OFFER_RAISE_MAX = 100
FabriX.worker.COUNTER_OFFER_RAISE_STEP = 10

-- chance that the worker stays, per offered raise in %
FabriX.worker.COUNTER_OFFER_CHANCE = {
    [10] = 0.30,
    [20] = 0.40,
    [30] = 0.75,
    [40] = 0.75,
    [50] = 0.9,
    [60] = 0.9,
    [70] = 0.95,
    [80] = 0.95,
    [90] = 0.95,
    [100] = 0.5,
}

-- sickness: chance per worker and in-game day (higher from 50), duration see SICK_REASONS
FabriX.worker.SICK_CHANCE = 0.02
FabriX.worker.SICK_CHANCE_50PLUS = 0.03
FabriX.worker.SICK_AGE_THRESHOLD = 50 -- years

-- hidden, lifelong disposition per worker: share in percent and factor on the chance
FabriX.worker.SICK_TYPES = {
    { share = 30, factor = 0 }, -- robust: never sick
    { share = 50, factor = 1 }, -- normal
    { share = 20, factor = 3 }, -- prone
}

-- sick reasons: l10n key suffix and duration range in in-game days
FabriX.worker.SICK_REASONS = {
    { key = "cow",         min = 1, max = 2 },
    { key = "flu",         min = 3, max = 4 },
    { key = "cold",        min = 1, max = 2 },
    { key = "back",        min = 2, max = 4 },
    { key = "stomach",     min = 2, max = 3 },
    { key = "toe",         min = 1, max = 1 },
    { key = "wasp",        min = 1, max = 1 },
    { key = "wheelbarrow", min = 1, max = 1 },
    { key = "tooth",       min = 1, max = 2 },
    { key = "hayfever",    min = 1, max = 2 },
    { key = "sunburn",     min = 1, max = 1 },
    { key = "cat",         min = 1, max = 1 },
    { key = "goat",        min = 1, max = 2 },
    { key = "bees",        min = 1, max = 1 },
    { key = "ladder",      min = 2, max = 3 },
    { key = "rake",        min = 1, max = 1 },
    { key = "manure",      min = 1, max = 1 },
    { key = "rooster",     min = 1, max = 1 },
    { key = "cowslip",     min = 1, max = 1 },
    { key = "horn",        min = 2, max = 3 },
    { key = "horse",       min = 1, max = 2 },
    { key = "dog",         min = 1, max = 2 },
    { key = "pumpkin",     min = 1, max = 1 },
    { key = "nettles",     min = 1, max = 1 },
    { key = "migraine",    min = 1, max = 2 },
    { key = "coldroom",    min = 1, max = 2 },
    { key = "stool",       min = 1, max = 1 },
    { key = "fence",       min = 1, max = 2 },
    { key = "molehill",    min = 1, max = 2 },
    { key = "neck",        min = 1, max = 1 },
    { key = "deaf",        min = 1, max = 1 },
    { key = "sheep",       min = 1, max = 2 },
    { key = "chainsaw",    min = 2, max = 4 },
    { key = "feedsack",    min = 1, max = 2 },
    { key = "headache",    min = 1, max = 1 },
    { key = "backache",    min = 1, max = 2 },
    { key = "hammer",      min = 1, max = 2 },
    { key = "hose",        min = 1, max = 1 },
    { key = "splinter",    min = 1, max = 2 },
    { key = "dust",        min = 1, max = 2 },
    { key = "tractorstep", min = 1, max = 2 },
    { key = "heat",        min = 1, max = 1 },
    { key = "barbedwire",  min = 1, max = 2 },
    { key = "trampoline",  min = 1, max = 2 },
    { key = "pitchfork",   min = 1, max = 2 },
    { key = "pneumonia",   min = 3, max = 4 },
    { key = "bull",        min = 2, max = 3 },
    { key = "bale",        min = 1, max = 2 },
    { key = "tractordoor", min = 1, max = 1 },
    { key = "alpaca",      min = 1, max = 1 },
    { key = "yawn",        min = 1, max = 1 },
    { key = "cowtail",     min = 1, max = 1 },
    { key = "fleas",       min = 1, max = 1 },
    { key = "haircut",     min = 1, max = 2 },
    { key = "udder",       min = 1, max = 2 },
    { key = "silo",        min = 2, max = 4 },
    { key = "mower",       min = 1, max = 2 },
    { key = "chicken",     min = 1, max = 2 },
    { key = "silage",      min = 1, max = 1 },
}

-- Marker: the image path that identifies a FEMALE portrait
FabriX.worker.FEMALE_IMAGE = "dataS2/npc/animalDealer/animalDealer.png"

-- Base salary per category (level-1 value, scaled by the level factor)
FabriX.worker.BASE_SALARY = { erntehelfer = 100, facharbeiter = 80, azubis = 80 }

-- Salary surcharge in percent for job-market applicants (min/max per category)
FabriX.worker.SALARY_VARIATION_MIN = 10
FabriX.worker.SALARY_VARIATION_MAX = { erntehelfer = 40, facharbeiter = 70 }

-- ---- Erntehelfer (seasonal workers) -----------------------------------------
FabriX.worker.MAX_WORKER_LEVEL = 10

-- Level table: xpToNext = XP needed for the next level, factor = productivity
FabriX.worker.LEVELS_ERNTEHELFER = {
    [1] = { xpToNext = 50, factor = 1.00 },
    [2] = { xpToNext = 60, factor = 1.05 },
    [3] = { xpToNext = 70, factor = 1.10 },
    [4] = { xpToNext = 80, factor = 1.15 },
    [5] = { xpToNext = 90, factor = 1.20 },
    [6] = { xpToNext = 100, factor = 1.25 },
    [7] = { xpToNext = 110, factor = 1.30 },
    [8] = { xpToNext = 120, factor = 1.35 },
    [9] = { xpToNext = 130, factor = 1.40 },
    [10] = { xpToNext = 0, factor = 1.45 },
}

FabriX.worker.WITHDRAW_FEE_ERNTEHELFER = 1500

-- ---- Facharbeiter (skilled workers) -----------------------------------------
-- Career path: Azubi -> Geselle -> Meister -> Betriebsleiter

FabriX.worker.AZUBI_GRADUATE_LEVEL = 4 -- from level 4 on: azubi => facharbeiter

-- Level table for the Facharbeiter path:
-- role: display label
-- prod/salary: productivity / salary factor
-- schoolMonths: months of school AFTER reaching the required XP (0 = none)
-- schoolAuto: true = automatic (Azubi), false = player-triggered (from Geselle on)
FabriX.worker.LEVELS_FACHARBEITER = {
    [1] = { role = "fabrix_category_azubi", xpToNext = 100, prod = 0.80, salary = 0.30, schoolMonths = 2, schoolAuto = true },
    [2] = { role = "fabrix_category_azubi", xpToNext = 100, prod = 0.90, salary = 0.40, schoolMonths = 2, schoolAuto = true },
    [3] = { role = "fabrix_category_azubi", xpToNext = 80, prod = 1.00, salary = 0.60, schoolMonths = 4, schoolAuto = true },
    [4] = { role = "fabrix_role_geselle", xpToNext = 50, prod = 1.05, salary = 0.90, schoolMonths = 0 },
    [5] = { role = "fabrix_role_geselle", xpToNext = 50, prod = 1.20, salary = 1.00, schoolMonths = 0 },
    [6] = { role = "fabrix_role_geselle", xpToNext = 50, prod = 1.30, salary = 1.10, schoolMonths = 6, schoolAuto = false },
    [7] = { role = "fabrix_role_meister", xpToNext = 100, prod = 1.50, salary = 1.20, schoolMonths = 0 },
    [8] = { role = "fabrix_role_meister", xpToNext = 110, prod = 1.60, salary = 1.40, schoolMonths = 0 },
    [9] = { role = "fabrix_role_meister", xpToNext = 120, prod = 1.70, salary = 1.50, schoolMonths = 8, schoolAuto = false },
    [10] = { role = "fabrix_role_betriebsleiter", xpToNext = 0, prod = 0.00, salary = 2.20, schoolMonths = 0 },
}

-- Notice period in months per Facharbeiter role (by level)
-- Erntehelfer: 0 = end of month. Azubi: cannot be dismissed
FabriX.worker.NOTICE_MONTHS_FACHARBEITER = {
    [4] = 3,
    [5] = 3,
    [6] = 3, -- Geselle
    [7] = 6,
    [8] = 6,
    [9] = 6,  -- Meister
    [10] = 9, -- Betriebsleiter
}

-- One-time fee to withdraw a dismissal
FabriX.worker.WITHDRAW_FEE_FACHARBEITER = {
    [4] = 3000,
    [5] = 3000,
    [6] = 3000, -- Geselle
    [7] = 6000,
    [8] = 6000,
    [9] = 6000, -- Meister
    [10] = 10000
}

-- Fee for the player-triggered school steps (see schoolAuto = false above)
FabriX.worker.SCHOOL_FEE_FACHARBEITER = {
    [6] = 3000,
    [9] = 6000
}

-- Relative spawn weights for Facharbeiter levels on the market
FabriX.worker.FACHARBEITER_SPAWN_WEIGHTS = {
    [4] = 60,
    [5] = 24,
    [6] = 10,
    [7] = 2,
    [8] = 2,
    [9] = 1,
    [10] = 1
}

-- Azubi: deadline for his apprenticeship
-- an apprentice who has not graduated in time (4 years) costs the player money
FabriX.worker.AZUBI_PENALTY_MONTHS = 48
FabriX.worker.AZUBI_LEAVE_MONTHS = 60 -- after 5 years, the azubi leaves the farm and looks for a new farm to finish his apprenticeship
FabriX.worker.AZUBI_PENALTY_4_YEARS = 500
FabriX.worker.AZUBI_PENALTY_5_YEARS = 2500
FabriX.worker.AZUBI_LEAVE_SEVERANCE = 15000 -- severance paid when the azubi leaves the farm after 5 years

-- # Market Size #
-- the number of workers offered on the market each month scaled with the number of the factories the farm owns
FabriX.worker.MARKET_SIZE = {
    erntehelfer = {
        { minFactories = 0, amount = 4 },
        { minFactories = 3, amount = 6 },
        { minFactories = 5, amount = 8 },
        { minFactories = 7, amount = 10 }
    },
    facharbeiter = {
        { minFactories = 0, amount = 3 },
        { minFactories = 3, amount = 5 },
        { minFactories = 5, amount = 7 },
        { minFactories = 7, amount = 10 }
    },
    azubis = {
        { minFactories = 0,  amount = 5 },
        { minFactories = 3,  amount = 9 },
        { minFactories = 5,  amount = 12 },
        { minFactories = 7,  amount = 17 },
        { minFactories = 11, amount = 20 }
    }
}

FabriX.worker.AZUBI_ENROLMENT_PERIODS = {
    [5] = true,
    [6] = true,
    [7] = true
}

-- =============================================================================
-- Other
-- =============================================================================
-- Seed the RNG so we can generate unique uuids every time the game is loaded
math.randomseed(math.floor(getTimeSec() * 1000))
