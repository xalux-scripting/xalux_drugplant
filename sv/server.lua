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
            description = "The plant data could not be found.",
            type = "error"
        })
        return
    end

    local totalPlantsAtLocation = MySQL.scalar.await(
        'SELECT COUNT(*) FROM player_plants WHERE interior_id = ? AND plant_name = ?',
        { plantData.interior, plantData.name }
    )

    if totalPlantsAtLocation >= Config.maxPlantsPerLocation then
        TriggerClientEvent('ox_lib:notify', playerId, {
            title = "Purchase Unavailable",
            description = "All plants at this location have been purchased.",
            type = "error"
        })
        return
    end

    local existingPlantForPlayer = MySQL.query.await(
        'SELECT player_identifier FROM player_plants WHERE plant_name = ? AND interior_id = ? AND player_identifier = ?',
        { plantData.name, plantData.interior, playerIdentifier }
    )

    if existingPlantForPlayer and #existingPlantForPlayer > 0 then
        TriggerClientEvent('ox_lib:notify', playerId, {
            title = "Purchase Failed",
            description = "You have already purchased this plant in this location.",
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

    MySQL.insert.await(
        'INSERT INTO player_plants (player_identifier, plant_id, plant_name, interior_id, buying_price) VALUES (?, ?, ?, ?, ?)',
        { playerIdentifier, plantId, plantData.name, plantData.interior, plantData.price }
    )

    TriggerClientEvent('ox_lib:notify', playerId, {
        title = "Purchase Successful",
        description = "You have successfully purchased " .. plantData.name .. " for $" .. plantData.price .. ".",
        type = "success"
    })

    sendDiscordLog("Plant Purchased", string.format(
        "Player **%s** (ID: %d) bought **%s** for $%d at interior ID: %s.",
        GetPlayerName(playerId), playerId, plantData.name, plantData.price, plantData.interior
    ), 3447003)
end)

RegisterNetEvent('xalux_drug:grantAccess', function(targetPlayerId)
    local src = source
    local targetIdentifier = GetPlayerIdentifier(targetPlayerId)
    local targetSteamName = GetPlayerName(targetPlayerId)

    if not targetIdentifier or not targetSteamName then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Grant Access Failed",
            description = "Invalid player ID or unable to fetch player name.",
            type = "error"
        })
        return
    end
    local plantId = GetPlayerRoutingBucket(src)

    local result = MySQL.insert.await(
        'INSERT INTO plant_permissions (plant_id, player_identifier, steam_name) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE steam_name = VALUES(steam_name)',
        { plantId, targetIdentifier, targetSteamName }
    )

    if result then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Access Granted",
            description = ("You have given access to %s."):format(targetSteamName),
            type = "success"
        })

        TriggerClientEvent('ox_lib:notify', targetPlayerId, {
            title = "Access Granted",
            description = "You have been granted access to a plant.",
            type = "inform"
        })
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Grant Access Failed",
            description = "An error occurred while saving permissions.",
            type = "error"
        })
    end
end)

RegisterNetEvent('xalux_drug:getAccessList', function(plantId)
    local src = source

    local result = MySQL.query.await(
        'SELECT player_identifier, steam_name FROM plant_permissions WHERE plant_id = ?',
        { plantId }
    )

    if result and #result > 0 then
        TriggerClientEvent('xalux_drug:sendAccessList', src, result)
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Access List',
            description = 'No players have access to this plant.',
            type = 'inform'
        })
    end
end)

RegisterNetEvent('xalux_drug:sell', function()
    local src = source
    local playerIdentifier = GetPlayerIdentifier(src)

    local routingBucket = GetPlayerRoutingBucket(src)

    local plantData = MySQL.query.await(
        'SELECT plant_name, buying_price FROM player_plants WHERE player_identifier = ? AND plant_id = ?',
        { playerIdentifier, routingBucket }
    )

    if not plantData or #plantData == 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Sell Failed",
            description = "You do not own this plant.",
            type = "error"
        })
        return
    end

    local plantName = plantData[1].plant_name
    local buyingPrice = plantData[1].buying_price
    local penalty = math.floor(buyingPrice * (Config.SellPenaltyPercent / 100))
    local sellPrice = buyingPrice - penalty

    exports.ox_inventory:AddItem(src, "money", sellPrice)

    local affectedRows = MySQL.update.await(
        'DELETE FROM player_plants WHERE player_identifier = ? AND plant_id = ?',
        { playerIdentifier, routingBucket }
    )

    if affectedRows == 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Error",
            description = "Failed to remove the plant from the database.",
            type = "error"
        })
        return
    end

    TriggerClientEvent('ox_lib:notify', src, {
        title = "Sell Successful",
        description = string.format("You sold %s for $%d after a %d%% penalty.", plantName, sellPrice, Config.SellPenaltyPercent),
        type = "success"
    })
    
    sendDiscordLog("Plant Sold", string.format(
        "Player **%s** (ID: %d) sold **%s** for $%d after a %d%% penalty in bucket %d.",
        GetPlayerName(src), src, plantName, sellPrice, Config.SellPenaltyPercent, routingBucket
    ), 3447003)
end)

RegisterNetEvent('xalux_drug:enterInterior', function(plantName)
    local src = source
    local playerIdentifier = GetPlayerIdentifier(src)

    local plantData = MySQL.query.await(
        'SELECT plant_id, interior_id, player_identifier FROM player_plants WHERE plant_name = ? AND (player_identifier = ? OR EXISTS (SELECT 1 FROM plant_permissions WHERE plant_id = player_plants.plant_id AND player_identifier = ?))',
        { plantName, playerIdentifier, playerIdentifier }
    )

    if not plantData or #plantData == 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Access Denied",
            description = "You do not own or have access to this plant.",
            type = "error"
        })
        return
    end

    local plantId = plantData[1].plant_id
    local interiorId = plantData[1].interior_id
    local ownerIdentifier = plantData[1].player_identifier

    local isOwner = (ownerIdentifier == playerIdentifier)

    if plantId and tonumber(plantId) then
        SetPlayerRoutingBucket(src, tonumber(plantId))
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Error",
            description = "Failed to set routing bucket due to invalid plant ID.",
            type = "error"
        })
        return
    end

    local interior = Config.Interiors[interiorId]
    if not interior then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Error",
            description = "Interior configuration not found.",
            type = "error"
        })
        return
    end

    TriggerClientEvent('xalux_drug:teleportToInterior', src, interior.InsideCoords, plantName, interiorId, isOwner)
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
