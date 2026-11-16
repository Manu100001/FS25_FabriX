-- #############
-- # Utilities #
-- #############
-- this is where the values for electricity and water consumption are set for the standard productions
-- from the vanilla game. If no appropriate values are specified, consumption is determined using
-- a random number

FabriX.RESOURCE_CONSUMPTION = {
    -- Bäckerei
    ["bakeryus/bakeryus.xml"] = { water = 1, electricity = 100 },
    ["bakery/bakery.xml"] = { water = 1, electricity = 100 },

    -- BGA
    ["bga250kw/bga250kw.xml"] = { water = 0, electricity = 5 },
    ["bga500kw/bga500kw.xml"] = { water = 0, electricity = 5 },
    ["bga1mw/bga1mw_mixers.xml"] = { water = 0, electricity = 5 },
    ["bga99kw/bga99kw.xml"] = { water = 0, electricity = 5 },

    -- Böttcherei
    ["cooperus/cooperus.xml"] = { water = 0, electricity = 15 },

    -- Fischzucht
    ["fishfarmbuilding/fishfarmbuilding.xml"] = { water = 50, electricity = 50 },
    ["fishfarmlake/fishfarmlake.xml"] = { water = 50, electricity = 50 },
    ["fishfoodfactory/fishfoodfactoryplaceable.xml"] = { water = 50, electricity = 50 },

    -- Gewächshäuser
    ["greenhouses/greenhousestarp/greenhousestarplarge.xml"] = { water = 0, electricity = 0 },
    ["greenhouses/greenhousestarp/greenhousestarpmedium.xml"] = { water = 0, electricity = 0 },
    ["greenhouses/greenhousestarp/greenhousestarpsmall.xml"] = { water = 0, electricity = 0 },
    ["greenhouses/greenhouseglass/greenhouseglasssmall.xml"] = { water = 0, electricity = 0 },
    ["greenhouses/greenhouseglass/greenhouseglassmedium.xml"] = { water = 0, electricity = 0 },
    ["greenhouses/greenhouseglass/greenhouseglasslarge.xml"] = { water = 0, electricity = 0 },
    ["greenhouses/greenhousemushrooms/greenhousemushroomssmall.xml"] = { water = 0, electricity = 0 },
    ["greenhouses/greenhousemushrooms/greenhousemushroomsmedium.xml"] = { water = 0, electricity = 0 },
    ["greenhouses/greenhousemushrooms/greenhousemushroomslarge.xml"] = { water = 0, electricity = 0 },

    -- Getreidemühle
    ["grainflourmillus/grainflourmillus.xml"] = { water = 0, electricity = 15 },

    -- Kartoffelverarbeitung
    ["potatoprocessingplant/potatoprocessingplantplaceable.xml"] = { water = 20, electricity = 100 },

    -- Konservenfabrik
    ["cannedpackagedfactoryus/cannedpackagedfactoryus.xml"] = { water = 10, electricity = 40 },
    ["preservedfoodfactory/preservedfoodfactoryplaceable.xml"] = { water = 10, electricity = 40 },

    -- Molkerei
    ["dairy/dairy.xml"] = { water = 2, electricity = 200 },

    -- Müslifabrik
    ["cerealfactory/cerealfactory.xml"] = { water = 5, electricity = 30 },

    -- Ölmühle
    ["oilplantus/oilplantus.xml"] = { water = 1, electricity = 60 },

    -- Papierfabrik
    ["papermill/papermill.xml"] = { water = 60, electricity = 100 },
    ["paperfactory/paperfactory.xml"] = { water = 50, electricity = 100 },

    -- Sägemühle
    ["sawmillus/sawmillus.xml"] = { water = 0, electricity = 20 },

    -- Schreinerei
    ["carpenterus/carpenterus.xml"] = { water = 0, electricity = 15 },

    -- Schneiderei
    ["tailorus/tailorus.xml"] = { water = 0, electricity = 10 },
    ["tailorshop/tailorshop.xml"] = { water = 0, electricity = 10 },

    -- Seilerei
    ["ropemakerus/ropemakerus.xml"] = { water = 0, electricity = 20 },

    -- Spinnerei
    ["spinnery/spinneryus.xml"] = { water = 0, electricity = 10 },
    ["spinnery/spinnery.xml"] = { water = 0, electricity = 10 },
    ["spinnery/spinneryplaceable.xml"] = { water = 0, electricity = 10 },

    -- Steinbruch
    ["quarry/quarry.xml"] = { water = 40, electricity = 10 },

    -- Steinmetz
    ["stonemason/stonemason.xml"] = { water = 20, electricity = 10 },

    -- Suppenfabrik
    ["soupfactory/soupfactoryplaceable.xml"] = { water = 30, electricity = 30 },
    ["soupfactory/soupfactory.xml"] = { water = 30, electricity = 30 },

    -- Traubenverarbeitung
    ["grapeprocessingunit/grapeprocessingunit.xml"] = { water = 3, electricity = 20 },

    -- Zementfabrik
    ["cementfactoryus/cementfactoryus.xml"] = { water = 2, electricity = 300 },
    ["cementfactoryeu/cementfactoryplaceable.xml"] = { water = 2, electricity = 300 },

    -- Zuckerfabrik
    ["sugarmill/sugarmill.xml"] = { water = 20, electricity = 100 },

    -- Zwiebelverpackung
    ["as25/as25.xml"] = { water = 0, electricity = 10 }
}
