LastPurpose = LastPurpose or {}

local CUSTOM_SPRITE = "lastpurpose_planning_01_0"
local CUSTOM_SPRITES = {
    ["lastpurpose_planning_01_0"] = true,
    ["lastpurpose_planning_01_1"] = true,
}
local BANK_X, BANK_Y = 12562, 1690
local ESCAPE_DISTANCE = 520
local RETURN_RADIUS = 8
local SEARCH_RADIUS = 5

local function findTable(square)
    local objects = square and square:getObjects()
    if not objects then return nil end
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        local sprite = object and object:getSprite()
        local spriteName = sprite and sprite:getName()
        local data = object and object:getModData()
        if CUSTOM_SPRITES[spriteName] or (data and data.LastPurposeSafehouseAnchorV2 == true) then
            data.LastPurposeSafehouseAnchorV2 = true
            return object
        end
    end
    return nil
end

local function findNearbyTable(player)
    local px = math.floor(player:getX())
    local py = math.floor(player:getY())
    local pz = math.floor(player:getZ())
    for y = py - SEARCH_RADIUS, py + SEARCH_RADIUS do
        for x = px - SEARCH_RADIUS, px + SEARCH_RADIUS do
            local square = getCell():getGridSquare(x, y, pz)
            local object = findTable(square)
            if object then return square, object end
        end
    end
    return nil, nil
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
    if not ok then
        if not objectData.LastPurposeNativeVisualWarningV2 then
            objectData.LastPurposeNativeVisualWarningV2 = true
            print("[LastPurpose] Aviso al migrar la mesa al tile nativo: " .. tostring(err))
        end
    end
end

local function establishSafehouse(player, square, tableObject)
    local data = LastPurpose.getData(player)
    data.safehousePlaced = true
    data.safehouseX = square:getX()
    data.safehouseY = square:getY()
    data.safehouseZ = square:getZ()
    data.safehousePlacedAtHours = player:getHoursSurvived()
    data.safehouseMapCenteredOnce = false
    data.objectives.safehouse = true
    ensureNativeVisual(tableObject)
    if HaloTextHelper then HaloTextHelper.addTextWithArrow(player, "Refugio establecido", true, 100, 190, 255) end
    LastPurpose.showThought(player, { "Aquí prepararé mis golpes.", "Será mejor recordar este lugar." })
    print(string.format("[LastPurpose] Mesa de planificación V2 colocada en %d,%d,%d", data.safehouseX, data.safehouseY, data.safehouseZ))
end

function LastPurpose.hasSafehouseAnchor(player)
    if not player then return false end
    local data = LastPurpose.getData(player)
    if data.safehouseX == nil or data.safehouseY == nil or data.safehouseZ == nil then return false end
    local square = getCell():getGridSquare(data.safehouseX, data.safehouseY, data.safehouseZ)
    if not square then return data.safehousePlaced == true end
    local tableObject = findTable(square)
    if tableObject then ensureNativeVisual(tableObject) end
    return tableObject ~= nil
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
        print("[LastPurpose] La mesa activa ya no está en el refugio")
    end

    if data.stage == 6 and data.lootTaken and LastPurpose.findHeistLootBag(player:getInventory()) then
        local dx = player:getX() - BANK_X
        local dy = player:getY() - BANK_Y
        if (dx * dx) + (dy * dy) >= (ESCAPE_DISTANCE * ESCAPE_DISTANCE) then
            data.stage = 7
            data.bankEscapeCompleted = true
            data.bankEscapeAtHours = player:getHoursSurvived()
            data.safehouseMapCenteredOnce = false
            LastPurpose.showThought(player, { "Ya estoy lejos del banco.", "Ahora debo volver al refugio." })
            print("[LastPurpose] El jugador escapó 520 metros con el botín")
        end
    end

    if data.stage == 7 and LastPurpose.hasSafehouseAnchor(player) then
        local dx = player:getX() - data.safehouseX
        local dy = player:getY() - data.safehouseY
        if player:getZ() == data.safehouseZ and (dx * dx) + (dy * dy) <= (RETURN_RADIUS * RETURN_RADIUS) then
            data.stage = 8
            data.safehouseReturned = true
            data.safehouseReturnedAtHours = player:getHoursSurvived()
            LastPurpose.showThought(player, { "Por fin, de vuelta.", "Es hora de revisar el botín." })
            print("[LastPurpose] El jugador regresó a su refugio")
        end
    end
end
