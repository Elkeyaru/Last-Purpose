LastPurpose = LastPurpose or {}

local CUSTOM_SPRITE = "lastpurpose_planning_01_0"
local CUSTOM_SPRITES = {
    ["lastpurpose_planning_01_0"] = true,
    ["lastpurpose_planning_01_1"] = true,
}
local function ORIGIN() return LastPurpose.World.BANK_ESCAPE_ORIGIN end
local function ESCAPE_DISTANCE() return LastPurpose.World.ESCAPE_DISTANCE end
local function RETURN_RADIUS() return LastPurpose.World.RETURN_RADIUS end
local function SEARCH_RADIUS() return LastPurpose.World.TABLE_SEARCH_RADIUS end
local OPEN_LOOT_BAG_TYPE = "LastPurpose.OpenKnoxBankLootBag"

local function isPlanningTable(object)
    local sprite = object and object:getSprite()
    local spriteName = sprite and sprite:getName()
    local objectData = object and object:getModData()
    return CUSTOM_SPRITES[spriteName] or (objectData and objectData.LastPurposeSafehouseAnchor == true)
end

local function findTable(square)
    local objects = square and square:getObjects()
    if not objects then return nil end
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if isPlanningTable(object) then
            object:getModData().LastPurposeSafehouseAnchor = true
            return object
        end
    end
    return nil
end

local function findNearbyTable(player)
    local px, py, pz = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    for y = py - SEARCH_RADIUS(), py + SEARCH_RADIUS() do
        for x = px - SEARCH_RADIUS(), px + SEARCH_RADIUS() do
            local square = getCell():getGridSquare(x, y, pz)
            local object = findTable(square)
            if object then return square, object end
        end
    end
    return nil, nil
end

-- Publico: lo usa LP_Computer.lua para la interaccion con la tecla E.
-- Devuelve (square, object) o (nil, nil).
function LastPurpose.findNearbyTable(player)
    if not player then return nil, nil end
    return findNearbyTable(player)
end

local function ensureNativeVisual(tableObject)
    local objectData = tableObject:getModData()
    local currentSprite = tableObject:getSprite()
    if currentSprite and CUSTOM_SPRITES[currentSprite:getName()] then return end

    local ok, err = pcall(function()
        local sprite = getSprite(CUSTOM_SPRITE)
        if not sprite then error("tile nativo no registrado: " .. CUSTOM_SPRITE) end
        tableObject:setSprite(sprite)
        if FBORenderChunk then tableObject:invalidateRenderChunkLevel(FBORenderChunk.DIRTY_REDRAW) end
    end)
    if not ok and not objectData.LastPurposeNativeVisualWarning then
        objectData.LastPurposeNativeVisualWarning = true
        print("[LastPurpose] Aviso al fijar el tile nativo de la mesa: " .. tostring(err))
    end
end

local function establishSafehouse(player, square, tableObject)
    local data = LastPurpose.getData(player)
    data.safehousePlaced = true
    data.safehouseX, data.safehouseY, data.safehouseZ = square:getX(), square:getY(), square:getZ()
    data.safehousePlacedAtHours = player:getHoursSurvived()
    data.safehouseMapCenteredOnce = false
    data.mapAreaRevealed_safehouse = false
    data.objectives.safehouse = true
    ensureNativeVisual(tableObject)

    if HaloTextHelper then HaloTextHelper.addTextWithArrow(player, "Refugio establecido", true, 100, 190, 255) end
    LastPurpose.showThought(player, { "Aqui preparare mis golpes.", "Sera mejor recordar este lugar." })
    LastPurpose.debugPrint(string.format("Mesa de planificacion colocada en %d,%d,%d", data.safehouseX, data.safehouseY, data.safehouseZ))
end

local function openLootBag(player, sealedBag, data)
    if sealedBag:getFullType() == OPEN_LOOT_BAG_TYPE then
        LastPurpose.applyLootVisual(sealedBag)
        return sealedBag
    end

    local openBag = player:getInventory():AddItem(OPEN_LOOT_BAG_TYPE)
    if not openBag then return nil end
    LastPurpose.applyLootVisual(openBag)

    local openData = openBag:getModData()
    openData.LastPurposeLootId = "louisville_knox_bank"
    openData.LastPurposeLootSealed = false
    openData.LastPurposeLootOpened = true

    if sealedBag.getInventory then
        local oldContents, newContents = sealedBag:getInventory(), openBag:getInventory()
        while oldContents and newContents and oldContents:getItems():size() > 0 do
            local item = oldContents:getItems():get(0)
            oldContents:Remove(item)
            newContents:AddItem(item)
        end
    end

    pcall(function() if player:isEquipped(sealedBag) then player:removeWornItem(sealedBag) end end)
    local oldContainer = sealedBag:getContainer()
    if oldContainer then oldContainer:Remove(sealedBag) end
    data.lootBagOpened = true
    return openBag
end

-- Cada recompensa se registra por clave en data.completionRewardItems para
-- que, si esta funcion se llama mas de una vez, nunca se dupliquen objetos.
local function addCompletionSupplies(lootBag, data, lootTable)
    if data.completionSuppliesGranted then return true end
    local contents = lootBag and lootBag:getInventory()
    if not contents then return false end

    data.completionRewardItems = data.completionRewardItems or {}
    data.completionAmmoTypes = data.completionAmmoTypes or {}

    local function give(key, itemType, count)
        local granted = tonumber(data.completionRewardItems[key]) or 0
        while granted < count do
            local ok, item = pcall(function() return contents:AddItem(itemType) end)
            if not ok or not item then
                print("[LastPurpose] Recompensa pendiente: " .. itemType)
                return false
            end
            -- El walkie de la banda arranca en su frecuencia (la de este
            -- golpe). Las de otros golpes se anadiran al descubrir sus mapas.
            if itemType == "LastPurpose.BandWalkieTalkie" then
                pcall(function()
                    local dd = item.getDeviceData and item:getDeviceData()
                    if dd then
                        if dd.setChannel then dd:setChannel(93300) end
                        if dd.setIsTurnedOn then dd:setIsTurnedOn(false) end
                    end
                end)
            end
            granted = granted + 1
            data.completionRewardItems[key] = granted
        end
        return true
    end

    for _, reward in ipairs(lootTable.valuables) do
        local key = "valuables:" .. reward.type
        if data.completionRewardItems[key] == nil then
            local existing = 0
            local items = contents:getItems()
            for i = 0, items:size() - 1 do
                if items:get(i):getFullType() == reward.type then existing = existing + 1 end
            end
            data.completionRewardItems[key] = math.min(existing, reward.count)
        end
        if not give(key, reward.type, reward.count) then return false end
    end

    for _, reward in ipairs(lootTable.supplies) do
        if not give("supplies:" .. reward.type, reward.type, reward.count) then return false end
    end

    for index = 1, lootTable.ammoRolls do
        data.completionAmmoTypes[index] = data.completionAmmoTypes[index] or lootTable.ammoChoices[ZombRand(#lootTable.ammoChoices) + 1]
        if not give("ammo:" .. index, data.completionAmmoTypes[index], 1) then return false end
    end

    -- Trofeo coleccionable del golpe (uno por golpe, via la misma clave
    -- idempotente de give()).
    local trophy = LastPurpose.HEIST_TROPHIES and LastPurpose.HEIST_TROPHIES[data.selectedHeist or ""]
    if trophy and not give("trophy:" .. trophy, trophy, 1) then return false end

    data.completionSuppliesGranted = true
    return true
end

local function grantNimbleLevels(player, data, levels)
    local granted = tonumber(data.completionNimbleLevelsGranted) or 0
    while granted < levels do
        if player:getPerkLevel(Perks.Nimble) >= 10 then break end
        player:LevelPerk(Perks.Nimble)
        granted = granted + 1
        data.completionNimbleLevelsGranted = granted
    end
    if luautils and luautils.updatePerksXp then
        pcall(function() luautils.updatePerksXp(Perks.Nimble, player) end)
    end
end

local function grantCompletionReward(player, lootBag, data, lootTable)
    if data.heistCompletionRewardGranted then return true end
    local openBag = openLootBag(player, lootBag, data)
    if not openBag or not addCompletionSupplies(openBag, data, lootTable) then return false end
    grantNimbleLevels(player, data, lootTable.nimbleLevels)
    data.heistCompletionRewardGranted = true
    data.heistCompletedAtHours = player:getHoursSurvived()
    LastPurpose.debugPrint(string.format(
        "Golpe completado; suministros entregados y %d niveles de Destreza resueltos",
        tonumber(data.completionNimbleLevelsGranted) or 0
    ))
    return true
end

function LastPurpose.hasSafehouseAnchor(player)
    if not player then return false end
    local data = LastPurpose.getData(player)
    if data.safehouseX == nil or data.safehouseY == nil or data.safehouseZ == nil then return false end
    local square = getCell():getGridSquare(data.safehouseX, data.safehouseY, data.safehouseZ)
    if not square then return data.safehousePlaced == true end -- la casilla puede estar descargada
    local tableObject = findTable(square)
    if tableObject then ensureNativeVisual(tableObject) end
    return tableObject ~= nil
end

function LastPurpose.reviewHeistLoot(player)
    if not player or not LastPurpose.isBurglar(player) then return end
    local data = LastPurpose.getData(player)
    if not LastPurpose.stageIs(data, "review_loot") then return end
    if not LastPurpose.hasSafehouseAnchor(player) then return end
    if not findTable(getCell():getGridSquare(data.safehouseX, data.safehouseY, data.safehouseZ)) then return end

    local dx, dy = player:getX() - data.safehouseX, player:getY() - data.safehouseY
    if player:getZ() ~= data.safehouseZ or dx * dx + dy * dy > RETURN_RADIUS() * RETURN_RADIUS() then return end

    local lootBag = LastPurpose.findHeistLootBag(player:getInventory())
    if not lootBag then
        if HaloTextHelper then HaloTextHelper.addTextWithArrow(player, "Necesito el botin del banco.", false, 255, 190, 90) end
        return
    end

    local heist = LastPurpose.ensureSelectedHeist(player)
    local lootTable = heist and heist.loot
    if not lootTable then return end

    local nimbleBefore = tonumber(data.completionNimbleLevelsGranted) or 0
    if not grantCompletionReward(player, lootBag, data, lootTable) then return end

    LastPurpose.setStage(data, "completed")
    data.safehouseReturned = true
    -- Hito 2: archivar el golpe para el desbloqueo en cadena del hub.
    if data.selectedHeist then
        data.completedHeists = data.completedHeists or {}
        data.completedHeists[data.selectedHeist] = true
        data.activeHeistId = nil
    end

    if HaloTextHelper then
        local nimbleGranted = (tonumber(data.completionNimbleLevelsGranted) or 0) - nimbleBefore
        local rewardText = nimbleGranted > 0 and ("+" .. nimbleGranted .. " niveles de Destreza") or "Destreza al maximo"
        HaloTextHelper.addTextWithArrow(player, rewardText, true, 100, 190, 255)
    end
    LastPurpose.showThought(player, { "El golpe ha terminado.", "Todo esto ha valido la pena." })
    LastPurpose.debugPrint("El jugador reviso el botin y completo el golpe")
end

function LastPurpose.fillPlanningTableWorldMenu(playerIndex, context, worldObjects)
    local player = LastPurpose.getPlayerSafe(playerIndex)
    if not player or not LastPurpose.isBurglar(player) then return end
    local data = LastPurpose.getData(player)

    local tableHere = nil
    for _, object in ipairs(worldObjects or {}) do
        if isPlanningTable(object) then tableHere = object end
    end
    if not tableHere then return end

    -- La mesa con ordenador: la GUI de pantalla completa (hito 1, solo lectura).
    if LastPurpose.openComputer then
        context:addOption("Usar el ordenador", player, LastPurpose.openComputer)
    end

    -- Entrega del botin: sigue siendo el mismo flujo validado. Se conserva la
    -- opcion directa del menu mientras el boton de la GUI se prueba en juego;
    -- ambos llaman a la misma funcion.
    local square = tableHere:getSquare()
    if LastPurpose.stageIs(data, "review_loot") and square
        and square:getX() == data.safehouseX
        and square:getY() == data.safehouseY
        and square:getZ() == data.safehouseZ then
        context:addOption("Revisar el botin", player, LastPurpose.reviewHeistLoot)
    end
end

function LastPurpose.updateSafehouseAnchor()
    local player = LastPurpose.getPlayerSafe(0)
    if not player or not LastPurpose.isBurglar(player) then return end
    local data = LastPurpose.getData(player)

    local nearbySquare, nearbyTable = findNearbyTable(player)
    if nearbySquare and nearbyTable then
        local isCurrentAnchor = data.safehousePlaced
            and data.safehouseX == nearbySquare:getX()
            and data.safehouseY == nearbySquare:getY()
            and data.safehouseZ == nearbySquare:getZ()
        if not isCurrentAnchor then establishSafehouse(player, nearbySquare, nearbyTable) end
    end

    if data.safehousePlaced and not LastPurpose.hasSafehouseAnchor(player) then
        data.safehousePlaced = false
        data.objectives.safehouse = false
        LastPurpose.debugPrint("La mesa activa ya no esta en el refugio")
    end

    if LastPurpose.stageIs(data, "loot_taken") and LastPurpose.findHeistLootBag(player:getInventory()) then
        local dx, dy = player:getX() - ORIGIN().x, player:getY() - ORIGIN().y
        if (dx * dx) + (dy * dy) >= (ESCAPE_DISTANCE() * ESCAPE_DISTANCE()) then
            LastPurpose.setStage(data, "returning")
            data.bankEscapeCompleted = true
            data.safehouseMapCenteredOnce = false
            LastPurpose.showThought(player, { "Ya estoy lejos del banco.", "Ahora debo volver al refugio." })
            LastPurpose.debugPrint("El jugador escapo con el botin")
        end
    end

    if LastPurpose.stageIs(data, "returning")
        and LastPurpose.hasSafehouseAnchor(player)
        and LastPurpose.findHeistLootBag(player:getInventory()) then
        local dx, dy = player:getX() - data.safehouseX, player:getY() - data.safehouseY
        if player:getZ() == data.safehouseZ and dx * dx + dy * dy <= RETURN_RADIUS() * RETURN_RADIUS() then
            LastPurpose.setStage(data, "review_loot")
            data.safehouseReturned = true
            LastPurpose.showThought(player, { "Por fin, de vuelta.", "Es hora de revisar el botin." })
            LastPurpose.debugPrint("El jugador regreso al refugio; debe revisar el botin")
        end
    end
end
