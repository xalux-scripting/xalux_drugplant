Config = {}

Config.Interiors = {
    ["Interior1"] = {
        InsideCoords = vector3(1088.81, -3187.57, -38.99),
        CookingCoords = vector3(1090.42, -3194.9, -38.99),
        drug = "cocaine", 
    },
    ["Interior2"] = {
        InsideCoords = vector3(1088.81, -3187.57, -38.99),
        CookingCoords = vector3(1090.42, -3194.9, -38.99),
        drug = "cocaine", 
    },

}

Config.debug = false

Config.processing = {
    CycleTime = 10000, -- how long one cycle lasts by default 10 seconds
    TemperatureIncrease = 10, -- how much water temperature increases in one cycle
    ExplosionThreshold = 100, -- when will the water over heat
    EnableExplosion = false, -- Set to false to disable explosions,
    TemperatureResetTime = 60000, -- Time in milliseconds to reset temperature after stopping
    MinimumWaterRequired = 10, -- Minimum water (liters) required to cook
    WaterLossPerCycle = 2, -- Liters of water lost after each cycle
    Drugs = {
        ["cocaine"] = {
            PerfectItems = { -- Items needed for a perfect cycle
                { item = "raw_cocaine", amount = 5 },
                { item = "chemical", amount = 2 }
            },
            OutputItem = { name = "processed_cocaine", amount = 1 }, -- gived item and amount if set to 1 and PerfectItems matches 2 the you get 2 item its it set to 2 PerfectItems matches 2 then you get 4 etc...
        }
    }
}

Config.Framework = "QBX" -- Set to "ESX" or  "QBX" for the manage plants command

Config.Webhook = 'change-me'
