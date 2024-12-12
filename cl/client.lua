local buyingPoints = {}
local sphereZones = {} 
local isSettingCoords = false
local processingActive = false
local currentCallback = nil
local temperatureResetTimer = nil 
local originalCoords

local function getPlayerCoords()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    return vector3(coords.x, coords.y, coords.z)
end

local function showSetCoordsText()
    lib.showTextUI('[E] - Set Coordinates', {
        position = 'right-center',
        icon = 'map-marker-alt',
        style = {
            backgroundColor = '#25262b',
            color = 'white',
            borderRadius = 4
        }
    })
end

local function hideSetCoordsText()
    lib.hideTextUI()
end

CreateThread(function()
    while true do
        Wait(0)
        if isSettingCoords then
            if not lib.isTextUIOpen() then
                showSetCoordsText()
            end
            if IsControlJustPressed(0, 51) then 
                local coords = getPlayerCoords()
                isSettingCoords = false
                hideSetCoordsText()

                if currentCallback then
                    currentCallback(coords)
                    currentCallback = nil
                end

                lib.notify({
                    title = "Coordinates Set",
                    description = string.format("Coordinates set to: %.2f, %.2f, %.2f", coords.x, coords.y, coords.z),
                    type = "success"
                })
            end
        else
            Wait(500)
            if lib.isTextUIOpen() then
                hideSetCoordsText()
            end
        end
    end
end)
local function addTargetZone(coords, radius, name, label, icon, onSelect)
    exports.ox_target:addSphereZone({
        coords = coords,
        radius = radius,
        options = {
            {
                name = name, 
                label = label, 
                icon = icon, 
                onSelect = function()
                    onSelect() 
                end
            }
        }
    })
end
function SetupInteriorZones(interiorName)
    RemoveInteriorZones()

    local interiorData = Config.Interiors[interiorName]

    local processedCoords = {}

    local CookingCoords = interiorData.CookingCoords
    local returnCoords = interiorData.InsideCoords

    if CookingCoords then
        local cookingKey = string.format("%.2f_%.2f_%.2f", CookingCoords.x, CookingCoords.y, CookingCoords.z)
        if not processedCoords[cookingKey] then
            processedCoords[cookingKey] = true
            local zoneName = "processing_" .. interiorName
            sphereZones[zoneName] = exports.ox_target:addSphereZone({
                name = zoneName,
                coords = vec3(CookingCoords.x, CookingCoords.y, CookingCoords.z),
                radius = 2.0,
                options = {
                    {
                        name = "start_processing_" .. interiorName,
                        label = "Start Processing",
                        icon = "fas fa-flask",
                        onSelect = function()
                            TriggerEvent("xalux_drug:openMenu", interiorName)
                        end
                    }
                }
            })
        end
    end

    if returnCoords then
        local returnKey = string.format("%.2f_%.2f_%.2f", returnCoords.x, returnCoords.y, returnCoords.z)
        if not processedCoords[returnKey] then
            processedCoords[returnKey] = true
            local zoneName = "return_" .. interiorName
            sphereZones[zoneName] = exports.ox_target:addSphereZone({
                name = zoneName,
                coords = vec3(returnCoords.x, returnCoords.y, returnCoords.z),
                radius = 2.0,
                options = {
                    {
                        name = "leave_interior_" .. interiorName,
                        label = "Leave Interior",
                        icon = "fas fa-door-open",
                        onSelect = function()
                            TriggerServerEvent('xalux_drug:leaveInterior')
                        end
                    }
                }
            })
        end
    end
end



function RemoveInteriorZones()
    for zoneName, zoneRef in pairs(sphereZones) do
        if zoneRef then
            exports.ox_target:removeZone(zoneRef)
        end
        sphereZones[zoneName] = nil
    end
end




Citizen.CreateThread(function()
    local rawBuyingPoints = LoadResourceFile(GetCurrentResourceName(), "buyingPoints.json")
    if rawBuyingPoints then
        buyingPoints = json.decode(rawBuyingPoints)
        if type(buyingPoints) ~= "table" or #buyingPoints == 0 then
            print("[ERROR] Buying points data is missing or empty!")
        end
    else
        print("[ERROR] Failed to load buyingPoints.json")
    end

for _, point in ipairs(buyingPoints) do
    exports.ox_target:addSphereZone({
        coords = vector3(point.coords[1], point.coords[2], point.coords[3]),
        radius = 2.0,
        options = {
            {
                name = 'buy_' .. point.name,
                label = 'Buy ' .. point.name,
                icon = 'shopping-cart',
                onSelect = function()
                    TriggerServerEvent('xalux_drug:buy', point.name, point.price)
                end
            }
        }
    })

    exports.ox_target:addSphereZone({
        coords = vector3(point.coords[1], point.coords[2], point.coords[3]),
        radius = 2.0,
        options = {
            {
                name = 'enter_' .. point.name,
                label = 'Enter Plant ' .. point.name,
                icon = 'door-open',
                onSelect = function()
                    TriggerServerEvent('xalux_drug:enterInterior', point.name)
                end
            }
        }
    })
end

end)
RegisterNetEvent('xalux_drug:teleportToInterior', function(coords, plantName, interiorName)
    if not coords or not coords.x or not coords.y or not coords.z then
        return
    end

    originalCoords = GetEntityCoords(PlayerPedId())

    SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z)

    if interiorName then
        SetupInteriorZones(interiorName)
    end

    lib.notify({
        title = "Access Granted",
        description = "Welcome to your plant interior for " .. plantName .. ".",
        type = "success"
    })
end)
RegisterNetEvent("interior:leave", function(interiorName)
    if originalCoords then
        SetEntityCoords(PlayerPedId(), originalCoords.x, originalCoords.y, originalCoords.z)

        lib.notify({
            title = "Exited Interior",
            description = "You returned to your original location.",
            type = "success"
        })

        RemoveInteriorZones()

        originalCoords = nil
    else
        lib.notify({
            title = "Error",
            description = "No original location saved. Unable to return.",
            type = "error"
        })
    end
end)


RegisterCommand('managePlants', function()
    TriggerServerEvent('xalux_drug:checkAdmin')
end)


RegisterNetEvent('xalux_drug:openMenu1', function()
    local plantOptions = {}

    for index, plant in ipairs(buyingPoints) do
        table.insert(plantOptions, {
            title = plant.name,
            description = "Edit or delete this plant",
            icon = "seedling",
            onSelect = function()
                TriggerEvent('xalux_drug:editPlant', index, plant)
            end
        })
    end

    table.insert(plantOptions, {
        title = "Add New Plant",
        icon = "plus",
        onSelect = function()
            TriggerEvent('xalux_drug:addPlant')
        end
    })

    lib.registerContext({
        id = 'plant_management_menu',
        title = "Manage Plants",
        options = plantOptions
    })

    lib.showContext('plant_management_menu')
end)

RegisterNetEvent('xalux_drug:addPlant', function()
    local input = lib.inputDialog("Add New Plant", {
        { label = "Plant Name", type = "input", required = true },
        { label = "Price", type = "number", required = true }
    })

    if not input or not input[1] or not input[2] then
        lib.notify({
            title = "Creation Cancelled",
            description = "Plant creation requires all fields.",
            type = "error"
        })
        return
    end

    local plantName = input[1]
    local plantPrice = tonumber(input[2])

    local interiorOptions = {}
    for interiorId, _ in pairs(Config.Interiors) do
        table.insert(interiorOptions, {
            value = interiorId,
            label = "Interior: " .. interiorId
        })
    end

    local interiorInput = lib.inputDialog("Select Plant Interior", {
        {
            type = "select",
            label = "Choose Interior",
            options = interiorOptions,
            required = true
        }
    })

    if not interiorInput or not interiorInput[1] then
        lib.notify({
            title = "Interior Selection Cancelled",
            description = "You must select an interior.",
            type = "error"
        })
        return
    end

    local selectedInterior = interiorInput[1]

    lib.registerContext({
        id = 'add_plant_menu',
        title = "Set Plant Coordinates",
        options = {
            {
                title = "Set Coordinates",
                description = "Set the coordinates for this plant.",
                icon = "map-marker-alt",
                onSelect = function()
                    isSettingCoords = true
                    currentCallback = function(coords)
                        TriggerServerEvent('xalux_drug:savePlant', {
                            name = plantName,
                            coords = { coords.x, coords.y, coords.z },
                            price = plantPrice,
                            interior = selectedInterior
                        })

                        lib.notify({
                            title = "Plant Created",
                            description = "Plant '" .. plantName .. "' with interior '" .. selectedInterior .. "' has been created.",
                            type = "success"
                        })
                    end
                end
            }
        }
    })

    lib.showContext('add_plant_menu')
end)

RegisterNetEvent('xalux_drug:editPlant', function(index, plant)
    lib.registerContext({
        id = 'edit_plant_menu',
        title = "🌱 Edit Plant: **" .. plant.name .. "**",
        description = "Manage plant properties and settings.",
        options = {
            {
                title = "📝 Edit Name",
                description = "Rename the plant to a new name.",
                icon = "edit",
                onSelect = function()
                    local nameInput = lib.inputDialog("Edit Plant Name", {
                        { label = "New Name", type = "input", required = true }
                    })

                    if nameInput and nameInput[1] then
                        plant.name = nameInput[1]
                        TriggerServerEvent('xalux_drug:updatePlant', index, plant)

                        lib.notify({
                            title = "Name Updated",
                            description = "The plant's name has been updated to **" .. plant.name .. "**.",
                            type = "success",
                            icon = "check-circle"
                        })
                    end
                end
            },
            {
                title = "💲 Change Price",
                description = "Update the price of this plant.",
                icon = "dollar-sign",
                onSelect = function()
                    local priceInput = lib.inputDialog("Set New Price", {
                        { label = "Price", type = "number", required = true, min = 0 }
                    })

                    if priceInput and priceInput[1] then
                        plant.price = priceInput[1]
                        TriggerServerEvent('admin:updatePlant', index, plant)

                        lib.notify({
                            title = "Price Updated",
                            description = "The plant's price is now **$" .. plant.price .. "**.",
                            type = "success",
                            icon = "money-bill-alt"
                        })
                    end
                end
            },
            {
                title = "🏠 Change Interior",
                description = "Select a different interior for this plant.",
                icon = "building",
                onSelect = function()
                    local interiorOptions = {}
                    for interiorId, _ in pairs(Config.Interiors) do
                        table.insert(interiorOptions, {
                            value = interiorId,
                            label = "Interior: " .. interiorId
                        })
                    end

                    local interiorInput = lib.inputDialog("Select New Interior", {
                        {
                            type = "select",
                            label = "Choose Interior",
                            options = interiorOptions,
                            required = true
                        }
                    })

                    if interiorInput and interiorInput[1] then
                        plant.interior = interiorInput[1]
                        TriggerServerEvent('xalux_drug:updatePlant', index, plant)

                        lib.notify({
                            title = "Interior Updated",
                            description = "Interior set to **" .. plant.interior .. "**.",
                            type = "success",
                            icon = "home"
                        })
                    end
                end
            },
            {
                title = "📍 Change Coords",
                description = "Modify the plant's coordinates.",
                icon = "map-marker-alt",
                onSelect = function()
                    local coordsInput = lib.inputDialog("Change Plant Coordinates", {
                        { label = "X", type = "number", required = true },
                        { label = "Y", type = "number", required = true },
                        { label = "Z", type = "number", required = true }
                    })

                    if coordsInput then
                        plant.coords = { x = coordsInput[1], y = coordsInput[2], z = coordsInput[3] }
                        TriggerServerEvent('xalux_drug:updatePlant', index, plant)

                        lib.notify({
                            title = "Coordinates Updated",
                            description = "The plant coordinates have been updated.",
                            type = "success",
                            icon = "location-arrow"
                        })
                    end
                end
            },
            {
                title = "🗑️ Remove Plant",
                description = "Delete this plant permanently.",
                icon = "trash-alt",
                onSelect = function()
                    TriggerServerEvent('xalux_drug:removePlant', index)

                    lib.notify({
                        title = "Plant Removed",
                        description = "The plant has been successfully deleted.",
                        type = "error",
                        icon = "times-circle"
                    })
                end
            }
        }
    })

    lib.showContext('edit_plant_menu')
end)


local currentSession = {
    itemsPerCycle = {}, -- items in cycle
    items = {}, -- Stores items added to the session
    water = 0, -- Tracks water quantity (litres)
    temperature = 20 -- Initial water temperature
}


RegisterNetEvent("xalux_drug:notify", function(title, description, type)
    lib.notify({ title = title, description = description, type = type })
end)

RegisterNetEvent("xalux_drug:addSessionItem", function(itemName, itemAmount)
    if not itemName or itemAmount <= 0 then
        lib.notify({
            title = "Error",
            description = "Invalid item or amount provided.",
            type = "error"
        })
        return
    end

    currentSession.items[itemName] = (currentSession.items[itemName] or 0) + itemAmount
    lib.notify({
        title = "Item Added",
        description = ("Added %d x %s to the session."):format(itemAmount, itemName),
        type = "success"
    })
end)

RegisterNetEvent("xalux_drug:clearSessionItems", function()
    currentSession.items = {}
    lib.notify({
        title = "Session Cleared",
        description = "All items have been removed from the session.",
        type = "inform"
    })
end)

RegisterNetEvent("xalux_drug:openMenu", function(interiorName)
    local interiorData = Config.Interiors[interiorName]
    if not interiorData or not interiorData.drug then
        lib.notify({ title = "Error", description = "No drug is set for this interior.", type = "error" })
        return
    end

    local drugConfig = Config.processing.Drugs[interiorData.drug]
    if not drugConfig then
        lib.notify({ title = "Error", description = "Invalid drug configuration.", type = "error" })
        return
    end

    local totalItems = 0
    for _, count in pairs(currentSession.items or {}) do
        totalItems = totalItems + count
    end

    local currentWater = currentSession.water or 0

    local menuOptions = {
        {
            title = "📥 Import Items",
            description = "Add required items to the session for processing.",
            onSelect = function()
                TriggerEvent("xalux_drug:importItems", drugConfig)
            end,
            icon = "box-open",
            iconColor = "green"
        },
        {
            title = "💧 Manage Water",
            description = "Check and add water to the session.",
            onSelect = function()
                TriggerEvent("xalux_drug:waterMenu")
            end,
            icon = "tint",
            iconColor = "blue"
        },
        {
            title = "📦 Take Out Items",
            description = "Retrieve all processed items and materials.",
            onSelect = function()
                TriggerServerEvent("xalux_drug:takeOutItems", currentSession.items, currentSession.water)
            end,
            icon = "hand-holding",
            iconColor = "orange"
        },
        {
            title = "🔄 Set Items Per Cycle",
            description = "Configure the number of items used per cycle.",
            onSelect = function()
                TriggerEvent("xalux_drug:setItemsPerCycle", drugConfig)
            end,
            icon = "sliders-h",
            iconColor = "purple"
        },
        {
            title = "🚀 Start Processing",
            description = "Begin processing items automatically.",
            onSelect = function()
                local playerCoords = GetEntityCoords(PlayerPedId())

                local currentInterior = nil
                for intName, intData in pairs(Config.Interiors) do
                    local interiorCoords = intData.CookingCoords
                    if #(playerCoords - vector3(interiorCoords.x, interiorCoords.y, interiorCoords.z)) < 5.0 then
                        currentInterior = intData
                        break
                    end
                end

                if not currentInterior then
                    lib.notify({
                        title = "Processing Failed",
                        description = "You are not inside a valid processing interior.",
                        type = "error"
                    })
                    return
                end

                TriggerEvent("xalux_drug:start", currentInterior.drug)
            end,
            icon = "play",
            iconColor = "green"
        },
        {
            title = "⛔ Stop Processing",
            description = "Stop the current processing cycle.",
            onSelect = function()
                TriggerEvent("xalux_drug:stop")
            end,
            icon = "stop",
            iconColor = "red"
        },
        {
            title = "📊 Total Items: " .. totalItems,
            description = "Shows the total number of items in the session.",
            icon = "archive",
            iconColor = "gray",
            disabled = true
        },
        {
            title = "💧 Water Level: " .. currentWater .. "L",
            description = "Shows the current water level in the session.",
            icon = "water",
            iconColor = "blue",
            disabled = true 
        }
    }

    lib.registerContext({
        id = "processing_menu_" .. interiorName,
        title = "Processing Menu",
        description = "Manage processing operations for drug manufacturing.",
        options = menuOptions,
        position = "top-right", 
        icon = "cogs",
        iconColor = "gray"
    })

    lib.showContext("processing_menu_" .. interiorName)
end)

RegisterNetEvent("xalux_drug:importItems", function(drugConfig)
    local itemInputs = {}
    for _, perfectItem in ipairs(drugConfig.PerfectItems) do
        table.insert(itemInputs, {
            type = "number",
            label = "Amount of " .. perfectItem.item,
            default = 0
        })
    end

    local input = lib.inputDialog("Import Items", itemInputs)

    if not input then
        lib.notify({ title = "Cancelled", description = "No items were added.", type = "inform" })
        return
    end

    for i, perfectItem in ipairs(drugConfig.PerfectItems) do
        local itemName = perfectItem.item
        local itemAmount = tonumber(input[i]) or 0

        if itemAmount > 0 then
            TriggerServerEvent("xalux_drug:importItem", itemName, itemAmount)
        end
    end
end)

RegisterNetEvent("xalux_drug:waterMenu", function()
    local menuOptions = {
        {
            title = "Add Water",
            description = "Add water to the session (1 item = 1 litre).",
            onSelect = function()
                local input = lib.inputDialog("Add Water", {
                    { type = "number", label = "Amount of Water Items", default = 0 }
                })

                if not input or not tonumber(input[1]) or tonumber(input[1]) <= 0 then
                    lib.notify({ title = "Error", description = "Invalid water input.", type = "error" })
                    return
                end

                local waterAmount = tonumber(input[1])
                TriggerServerEvent("xalux_drug:addWater", waterAmount)
            end
        },
        {
            title = "View Water Status",
            description = "Check water temperature and quantity.",
            onSelect = function()
                lib.notify({
                    title = "Water Status",
                    description = "Temperature: " .. currentSession.temperature .. "°C\nQuantity: " .. currentSession.water .. " litres",
                    type = "inform"
                })
            end
        }
    }

    lib.registerContext({
        id = "water_menu",
        title = "Water Management",
        options = menuOptions
    })
    lib.showContext("water_menu")
end)

RegisterNetEvent("processing:updateWater", function(newWater, newTemperature)
    currentSession.water = newWater
    currentSession.temperature = newTemperature
end)

RegisterNetEvent("xalux_drug:setItemsPerCycle", function(drugConfig)
    local itemInputs = {}
    for _, perfectItem in ipairs(drugConfig.PerfectItems) do
        table.insert(itemInputs, {
            type = "number",
            label = "Cycle Amount for " .. perfectItem.item,
            default = currentSession.itemsPerCycle and currentSession.itemsPerCycle[perfectItem.item] or 0
        })
    end

    local input = lib.inputDialog("Set Items Per Cycle", itemInputs)

    if not input then
        lib.notify({
            title = "Cancelled",
            description = "No changes were made to cycle items.",
            type = "inform"
        })
        return
    end

    currentSession.itemsPerCycle = currentSession.itemsPerCycle or {}

    for i, perfectItem in ipairs(drugConfig.PerfectItems) do
        local itemName = perfectItem.item
        local itemAmount = tonumber(input[i]) or 0

        if itemAmount > 0 then
            currentSession.itemsPerCycle[itemName] = itemAmount
            lib.notify({
                title = "Cycle Updated",
                description = "Set " .. itemAmount .. "x " .. itemName .. " per cycle.",
                type = "success"
            })
        else
            currentSession.itemsPerCycle[itemName] = nil
        end
    end
end)

RegisterNetEvent("xalux_drug:start", function(drugType)
    local playerSession = currentSession
    if processingActive then
        lib.notify({
            title = "Error",
            description = "Processing is already active.",
            type = "error"
        })
        return
    end

    if not Config.processing.Drugs[drugType] then
        lib.notify({
            title = "Error",
            description = "Invalid drug type selected.",
            type = "error"
        })
        return
    end

    local drugConfig = Config.processing.Drugs[drugType]

    if not playerSession or (playerSession.water or 0) < Config.processing.MinimumWaterRequired then
        lib.notify({
            title = "Error",
            description = "Insufficient water. You need at least " .. Config.processing.MinimumWaterRequired .. " liters.",
            type = "error"
        })
        return
    end

    processingActive = true
    ProcessCycle(drugConfig)
end)

function ProcessCycle(drugConfig)
    if not processingActive then return end

    local itemsPerCycle = currentSession.itemsPerCycle or {}

    local matches = 0
    local readyItems = 0

    for itemName, availableAmount in pairs(itemsPerCycle) do
        for _, perfectItem in ipairs(drugConfig.PerfectItems) do
            if perfectItem.item == itemName and availableAmount >= perfectItem.amount then
                matches = matches + 1
                readyItems = readyItems + math.floor(availableAmount / perfectItem.amount)
                break
            end
        end
    end

    if matches == 0 then
        lib.notify({
            title = "Processing Stopped",
            description = "No valid items in this cycle. Processing cannot continue.",
            type = "error"
        })
        StopProcessing()
        return
    end

    if (currentSession.water or 0) < Config.processing.MinimumWaterRequired then
        lib.notify({
            title = "Processing Stopped",
            description = string.format("Insufficient water. You need at least %d liters.", Config.processing.MinimumWaterRequired),
            type = "error"
        })
        StopProcessing()
        return
    end
    currentSession.water = currentSession.water - Config.processing.WaterLossPerCycle

    for itemName, availableAmount in pairs(itemsPerCycle) do
        for _, perfectItem in ipairs(drugConfig.PerfectItems) do
            if perfectItem.item == itemName and availableAmount >= perfectItem.amount then
                local usedAmount = readyItems * perfectItem.amount
                currentSession.items[itemName] = (currentSession.items[itemName] or 0) - usedAmount
                break
            end
        end
    end

    lib.notify({
        title = "Processing",
        description = string.format("Processing %d matches... Please wait.", matches),
        type = "inform"
    })

    Wait(Config.processing.CycleTime)

    currentSession.temperature = (currentSession.temperature or 20) + Config.processing.TemperatureIncrease

    if currentSession.temperature >= Config.processing.ExplosionThreshold then
        TriggerEvent("xalux_drug:explosion")
        StopProcessing()
        return
    end

    local rewardItem = drugConfig.OutputItem.name
    TriggerServerEvent("xalux_drug:rewardPlayer", rewardItem, readyItems)

    lib.notify({
        title = "Processing Complete",
        description = string.format("You received %d x %s.", readyItems, rewardItem),
        type = "success"
    })

    ProcessCycle(drugConfig)
end


function IsAnyMatchAvailable(drugConfig)
    for _, perfectItem in ipairs(drugConfig.PerfectItems) do
        local itemName = perfectItem.item
        local requiredAmount = perfectItem.amount
        if (currentSession.items[itemName] or 0) >= requiredAmount then
            return true
        end
    end
    return false
end



function StopProcessing()
    processingActive = false
    if temperatureResetTimer then
        KillTimer(temperatureResetTimer)
    end

    temperatureResetTimer = SetTimeout(Config.processing.TemperatureResetTime, function()
        currentSession.temperature = 20
        lib.notify({
            title = "Temperature Reset",
            description = "The lab's temperature has returned to normal.",
            type = "inform"
        })
    end)
end

RegisterNetEvent("xalux_drug:stop", function()
    if processingActive then
        StopProcessing()
        lib.notify({
            title = "Processing Stopped",
            description = "Processing has been stopped by the player.",
            type = "inform"
        })
    else
        lib.notify({
            title = "Error",
            description = "No active processing to stop.",
            type = "error"
        })
    end
end)

RegisterNetEvent("xalux_drug:explosion", function()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    if Config.processing.EnableExplosion then
        AddExplosion(playerCoords.x, playerCoords.y, playerCoords.z, 29, 10.0, true, false, 1.0)
    end

    lib.notify({
        title = Config.processing.EnableExplosion and "Explosion!" or "Overheat Alert!",
        description = Config.processing.EnableExplosion and 
                      "The lab overheated and exploded! Be careful next time." or 
                      "The lab overheated!",
        type = Config.processing.EnableExplosion and "error" or "warning"
    })

    currentSession.temperature = 20
    currentSession.itemsPerCycle = {}
    currentSession.items = {}
    currentSession.water = 0
end)
