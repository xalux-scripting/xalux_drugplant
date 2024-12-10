local buyingPoints = json.decode(LoadResourceFile(GetCurrentResourceName(), "buyingPoints.json"))
local discordWebhook = Config.Webhook

local function saveJSON(filename, data)
    SaveResourceFile(GetCurrentResourceName(), filename, json.encode(data, { indent = true }), -1)
end
local function sendDiscordLog(title, description, color)
    local payload = {
        embeds = {{
            title = title,
            description = description,
            color = color
        }}
    }
    PerformHttpRequest(discordWebhook, function(err, text, headers) end, "POST", json.encode(payload), { ["Content-Type"] = "application/json" })
end
RegisterNetEvent('xalux_drug:savePlant', function(plantData)
    table.insert(buyingPoints, plantData)
    saveJSON("buyingPoints.json", buyingPoints)
    sendDiscordLog("Plant Saved", "A new plant was saved: **" .. plantData.name .. "**", 65280) 
end)

RegisterNetEvent('xalux_drug:updatePlant', function(index, plantData)
    buyingPoints[index] = plantData
    saveJSON("buyingPoints.json", buyingPoints)
    sendDiscordLog("Plant Updated", "Plant at index **" .. index .. "** updated: **" .. plantData.name .. "**", 16776960)
end)

RegisterNetEvent('xalux_drug:removePlant', function(index)
    local removedPlant = buyingPoints[index]
    table.remove(buyingPoints, index)
    saveJSON("buyingPoints.json", buyingPoints)
    if removedPlant then
        sendDiscordLog("Plant Removed", "Plant **" .. removedPlant.name .. "** was removed.", 16711680) 
    end
end)

local function generateUniquePlantId()
    local plantId
    local isUnique = false

    while not isUnique do
        plantId = math.random(5000, 6000)

        local result = MySQL.scalar.await('SELECT COUNT(*) FROM player_plants WHERE plant_id = ?', { plantId })
        if result == 0 then
            isUnique = true
        end
    end

    return plantId
end

RegisterNetEvent('xalux_drug:checkAdmin', function()
    local src = source

    local isAdmin = false

    if Config.Framework == "ESX" then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer and xPlayer.getGroup() == "admin" then
            isAdmin = true
        end
    elseif Config.Framework == "QBX" then
        local Player = exports.qbx_core:GetPlayer(source)
        if Player or (Player.groups['admin'] == nil and Player.groups['god'] == nil and Player.groups['mod'] == nil) then
            isAdmin = true
        end
    end
    if isAdmin then
        TriggerClientEvent('xalux_drug:openMenu1', src)
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Access Denied",
            description = "You do not have permission to use this command.",
            type = "error"
        })
    end
end)

RegisterNetEvent('xalux_drug:buy', function(plantName)
    local playerId = source
    local playerIdentifier = GetPlayerIdentifier(playerId)

    local plantData = nil
    for _, plant in pairs(buyingPoints) do
        if plant.name == plantName then
            plantData = plant
            break
        end
    end

    if not plantData then
        TriggerClientEvent('ox_lib:notify', playerId, {
            title = "Purchase Failed",
            description = "The plant data could not be found in the JSON file.",
            type = "error"
        })
        return
    end

    local existingPlant = MySQL.query.await(
        'SELECT player_identifier FROM player_plants WHERE plant_name = ? AND interior_id = ?',
        { plantData.name, plantData.interior }
    )

    if existingPlant and #existingPlant > 0 then
        TriggerClientEvent('ox_lib:notify', playerId, {
            title = "Purchase Failed",
            description = "This plant has already been purchased by another player.",
            type = "error"
        })
        return
    end

    local hasMoney = exports.ox_inventory:GetItemCount(playerId, "money") >= plantData.price
    if not hasMoney then
        TriggerClientEvent('ox_lib:notify', playerId, {
            title = "Purchase Failed",
            description = "You don't have enough money.",
            type = "error"
        })
        return
    end

    exports.ox_inventory:RemoveItem(playerId, "money", plantData.price)

    local plantId = generateUniquePlantId()

    MySQL.insert.await('INSERT INTO player_plants (player_identifier, plant_id, plant_name, interior_id) VALUES (?, ?, ?, ?)', {
        playerIdentifier,
        plantId,
        plantData.name,
        plantData.interior
    })

    TriggerClientEvent('ox_lib:notify', playerId, {
        title = "Purchase Successful",
        description = "You bought " .. plantData.name .. " and were assigned the interior '" .. plantData.interior .. "'.",
        type = "success"
    })
    
    sendDiscordLog("Plant Purchased", "Player **" .. GetPlayerName(playerId) .. "** (ID: " .. playerId .. ") bought **" .. plantData.name .. "** for $" .. plantData.price, 3447003)
end)

RegisterNetEvent('xalux_drug:enterInterior', function(plantName)
    local src = source
    local playerIdentifier = GetPlayerIdentifier(src)

    local plantData = MySQL.query.await(
        'SELECT plant_id, interior_id FROM player_plants WHERE player_identifier = ? AND plant_name = ?',
        { playerIdentifier, plantName }
    )

    if not plantData or #plantData == 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Access Denied",
            description = "You do not own this plant.",
            type = "error"
        })
        return
    end

    local plantId = plantData[1].plant_id
    local interiorId = plantData[1].interior_id

    SetPlayerRoutingBucket(src, plantId)

    local interior = Config.Interiors[interiorId]
    if not interior then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Error",
            description = "Interior configuration not found.",
            type = "error"
        })
        return
    end

    TriggerClientEvent('xalux_drug:teleportToInterior', src, interior.InsideCoords, plantName, interiorId)
end)

RegisterNetEvent('xalux_drug:leaveInterior', function(originalCoords)
    local src = source
    SetPlayerRoutingBucket(src, 0)
    TriggerClientEvent('interior:leave', src, originalCoords)
end)


RegisterNetEvent("xalux_drug:importItem", function(itemName, itemAmount)
    local src = source
    local hasItem = exports.ox_inventory:Search(src, "count", itemName) >= itemAmount

    if not hasItem then
        TriggerClientEvent("xalux_drug:notify", src, "Error", "You don't have enough " .. itemName .. ".", "error")
        return
    end

    exports.ox_inventory:RemoveItem(src, itemName, itemAmount)
    TriggerClientEvent("xalux_drug:addSessionItem", src, itemName, itemAmount)
end)

RegisterNetEvent("xalux_drug:addWater", function(waterAmount)
    local src = source

    currentSession = currentSession or {}
    currentSession[src] = currentSession[src] or { water = 0, temperature = 20 }

    local hasWater = exports.ox_inventory:Search(src, "count", "water") >= waterAmount

    if not hasWater then
        TriggerClientEvent("xalux_drug:notify", src, "Error", "You don't have enough water items.", "error")
        return
    end

    exports.ox_inventory:RemoveItem(src, "water", waterAmount)
    currentSession[src].water = (currentSession[src].water or 0) + waterAmount

    TriggerClientEvent("processing:updateWater", src, currentSession[src].water, currentSession[src].temperature)
    TriggerClientEvent("xalux_drug:notify", src, "Success", "Added " .. waterAmount .. " litres of water.", "success")
end)

RegisterNetEvent("xalux_drug:takeOutItems", function(sessionItems, sessionWater)
    local src = source

    for itemName, itemAmount in pairs(sessionItems) do
        if itemAmount > 0 then
            exports.ox_inventory:AddItem(src, itemName, itemAmount)
        end
    end

    if sessionWater > 0 then
        exports.ox_inventory:AddItem(src, "water", sessionWater)
    end

    TriggerClientEvent("xalux_drug:clearSessionItems", src)
    TriggerClientEvent("xalux_drug:notify", src, "Items Retrieved", "All items, including water, have been returned to your inventory.", "inform")
end)
RegisterNetEvent("xalux_drug:rewardPlayer", function(rewardItem, rewardAmount)
    local playerId = source

    if exports.ox_inventory:CanCarryItem(playerId, rewardItem, rewardAmount) then
        exports.ox_inventory:AddItem(playerId, rewardItem, rewardAmount)
    else
        TriggerClientEvent("xalux_drug:notify", playerId, "Error", "You can't carry the reward items!", "error")
    end
end)

