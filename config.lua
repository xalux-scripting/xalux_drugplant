Config = {}

-- frameworks
Config.Framework = "QBX" -- Set to "ESX" or  "QBX" for the manage plants command


Config.Interiors = {
    ["Interior1"] = {
        InsideCoords = vector3(1088.81, -3187.57, -38.99),
        CookingCoords = vector3(1090.42, -3194.9, -38.99),
        ManagementCoords = vec3(1087.16, -3194.49, -38.99),
        drug = "cocaine", 
    },
    ["Interior2"] = {
        InsideCoords = vector3(1088.81, -3187.57, -38.99),
        CookingCoords = vector3(1090.42, -3194.9, -38.99),
        ManagementCoords = vec3(1087.16, -3194.49, -38.99),
        drug = "cocaine", 
    },

    --you can add more interiors
}

-- processing

Config.processing = {
    CycleTime = 500,
    TemperatureIncrease = 10,
    ExplosionThreshold = 25,
    EnableExplosion = true, -- Set to false to disable explosions,
    EnablePoliceNotify = false,
    ProcetaceChange = 50, -- 50% chance to dispatch police
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

--discord logs
Config.Webhook = 'change-me'

-- buying configuring
Config.maxPlantsPerLocation = 5

--selling
Config.SellPenaltyPercent = 25

--dispatch
Config.DispatchSystem = "CodeDesign" -- Options: "CodeDesign", "Brutal", "Quasar"

Config.dispatch = {
    Code = "10-66", -- Dispatch code
    Title = "Illegal Substance Cooking", -- Dispatch title
    Description = "Explosion reported, possibly related to illegal activity.", -- Dispatch description
    Sprite = 436, -- Blip sprite ID
    Color = 1, -- Blip color
    Scale = 1.2 -- Blip size
}
