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
local COMPLETION_REWARD_VERSION = 2
local OPEN_LOOT_BAG_TYPE = "LastPurpose.OpenKnoxBankLootBag"
local ORIGINAL_LOOT = {
    { type = "Base.SmallGoldBar", count = 5 },
    { type = "Base.Diamond", count = 4 },
    { type = "Base.MoneyBundle", count = 6 },
}
local COMPLETION_SUPPLIES = {
    { type = "Base.Antibiotics", count = 2 },
    { type = "Base.Pills", count = 2 },
    { type = "Base.SutureNeedle", count = 2 },
    { type = "Base.Bandage", count = 6 },
    { type = "Base.AlcoholWipes", count = 8 },
    { type = "Base.Battery", count = 6 },
    { type = "Base.DuctTape", count = 2 },
    { type = "Base.Woodglue", count = 1 },
    { type = "Base.PetrolCan", count = 1 },
    { type = "Base.WalkieTalkie5", count = 1 },
    { type = "Base.CannedCornedBeef", count = 2 },
    { type = "Base.CannedSardines", count = 2 },
}
local AMMO_REWARDS = {
    "Base.Bullets9mmBox",
    "Base.ShotgunShellsBox",
    "Base.308Box",
    "Base.556Box",
    "Base.Bullets45Box",
    "Base.Bullets357Box",
}

local function isPlanningTable(object)
    local sprite = object and object:getSprite()
    local spriteName = sprite and sprite:getName()
    local objectData = object and object:getModData()
    return CUSTOM_SPRITES[spriteName] or (objectData and objectData.LastPurposeSafehouseAnchorV2 == true)
end

local function findTable(square)
    local objects = square and square:getObjects()
    if not objects then return nil end
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        local data = object and object:getModData()
        if isPlanningTable(object) then
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

local function openLootBag(player, sealedBag, data)
    if sealedBag:getFullType() == OPEN_LOOT_BAG_TYPE then
        LastPurpose.applyBlackLootVisual(sealedBag)
        return sealedBag
    end
    local openBag = player:getInventory():AddItem(OPEN_LOOT_BAG_TYPE)
    if not openBag then return nil end
    LastPurpose.applyBlackLootVisual(openBag)

    local openData = openBag:getModData()
    openData.LastPurposeLootId = "louisville_knox_bank"
    openData.LastPurposeLootVersion = 2
    openData.LastPurposeLootSealed = false
    openData.LastPurposeLootOpened = true

    if sealedBag.getInventory then
        local oldContents = sealedBag:getInventory()
        local newContents = openBag:getInventory()
        while oldContents and newContents and oldContents:getItems():size() > 0 do
            local item = oldContents:getItems():get(0)
            oldContents:Remove(item)
            newContents:AddItem(item)
        end
    end

    pcall(function()
        if player:isEquipped(sealedBag) then player:removeWornItem(sealedBag) end
    end)
    local oldContainer = sealedBag:getContainer()
    if oldContainer then oldContainer:Remove(sealedBag) end
    data.lootBagOpened = true
    return openBag
end

local function addCompletionSupplies(lootBag, data)
    if data.completionSuppliesGranted then return true end
    local contents = lootBag and lootBag:getInventory()
    if not contents then return false end

    for _, reward in ipairs(ORIGINAL_LOOT) do
        contents:AddItems(reward.type, reward.count)
    end
    for _, reward in ipairs(COMPLETION_SUPPLIES) do
        contents:AddItems(reward.type, reward.count)
    end
    for _ = 1, 3 do
        contents:AddItem(AMMO_REWARDS[ZombRand(#AMMO_REWARDS) + 1])
    end
    data.completionSuppliesGranted = true
    return true
end

local function grantNimbleLevels(player, data)
    local granted = tonumber(data.completionNimbleLevelsGranted) or 0
    while granted < 2 do
        local currentLevel = player:getPerkLevel(Perks.Nimble)
        if currentLevel >= 10 then break end
        player:LevelPerk(Perks.Nimble)
        granted = granted + 1
        data.completionNimbleLevelsGranted = granted
    end
    if granted >= 2 or player:getPerkLevel(Perks.Nimble) >= 10 then
        data.completionNimbleRewardResolved = true
    end
    if luautils and luautils.updatePerksXp then
        pcall(function() luautils.updatePerksXp(Perks.Nimble, player) end)
    end
end

local function grantCompletionReward(player, lootBag, data)
    if (tonumber(data.heistCompletionRewardVersion) or 0) >= COMPLETION_REWARD_VERSION then return true end
    local openBag = openLootBag(player, lootBag, data)
    if not openBag or not addCompletionSupplies(openBag, data) then return false end
    grantNimbleLevels(player, data)
    data.heistCompletionRewardVersion = COMPLETION_REWARD_VERSION
    data.heistCompleted = true
    data.heistCompletedAtHours = player:getHoursSurvived()
    print(string.format(
        "[LastPurpose] Golpe completado; suministros entregados y %d niveles de Destreza resueltos",
        tonumber(data.completionNimbleLevelsGranted) or 0
    ))
    return true
end

function LastPurpose.reviewHeistLoot(player)
    if not player then return end
    local data = LastPurpose.getData(player)
    local reviewStage = data.storyFlowVersion == 2 and 12 or 8
    local completeStage = data.storyFlowVersion == 2 and 13 or 9
    if data.stage ~= reviewStage then return end
    local lootBag = LastPurpose.findHeistLootBag(player:getInventory())
    if not lootBag then
        if HaloTextHelper then
            HaloTextHelper.addTextWithArrow(player, "Necesito el botín del banco.", false, 255, 190, 90)
        end
        return
    end
    local nimbleBefore = tonumber(data.completionNimbleLevelsGranted) or 0
    if not grantCompletionReward(player, lootBag, data) then return end

    data.stage = completeStage
    data.safehouseReturned = true
    data.safehouseReturnedAtHours = data.safehouseReturnedAtHours or player:getHoursSurvived()
    if HaloTextHelper then
        local nimbleGranted = (tonumber(data.completionNimbleLevelsGranted) or 0) - nimbleBefore
        local rewardText = nimbleGranted > 0 and ("+" .. nimbleGranted .. " niveles de Destreza") or "Destreza al máximo"
        HaloTextHelper.addTextWithArrow(player, rewardText, true, 100, 190, 255)
    end
    LastPurpose.showThought(player, { "El golpe ha terminado.", "Todo esto ha valido la pena." })
    print("[LastPurpose] El jugador revisó el botín y completó el golpe")
end

function LastPurpose.fillPlanningTableWorldMenu(playerIndex, context, worldObjects)
    local player = LastPurpose.getPlayerSafe(playerIndex)
    if not player or not LastPurpose.isBurglar(player) then return end
    local data = LastPurpose.getData(player)
    local reviewStage = data.storyFlowVersion == 2 and 12 or 8
    if data.stage ~= reviewStage then return end

    for _, object in ipairs(worldObjects or {}) do
        if isPlanningTable(object) then
            context:addOption("Revisar el botín", player, LastPurpose.reviewHeistLoot)
            return
        end
    end
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

    local completeStage = data.storyFlowVersion == 2 and 13 or 9
    local lootStage = data.storyFlowVersion == 2 and 10 or 6
    local returnStage = data.storyFlowVersion == 2 and 11 or 7
    local reviewStage = data.storyFlowVersion == 2 and 12 or 8
    if data.stage >= completeStage and (tonumber(data.heistCompletionRewardVersion) or 0) < COMPLETION_REWARD_VERSION then
        local legacyBag = LastPurpose.findHeistLootBag(player:getInventory())
        if legacyBag and openLootBag(player, legacyBag, data) then
            data.heistCompletionRewardVersion = COMPLETION_REWARD_VERSION
            print("[LastPurpose] Bolsa de recompensa anterior migrada a capacidad 28")
        end
    end

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

    if data.stage == lootStage and data.lootTaken and LastPurpose.findHeistLootBag(player:getInventory()) then
        local dx = player:getX() - BANK_X
        local dy = player:getY() - BANK_Y
        if (dx * dx) + (dy * dy) >= (ESCAPE_DISTANCE * ESCAPE_DISTANCE) then
            data.stage = returnStage
            data.bankEscapeCompleted = true
            data.bankEscapeAtHours = player:getHoursSurvived()
            data.safehouseMapCenteredOnce = false
            LastPurpose.showThought(player, { "Ya estoy lejos del banco.", "Ahora debo volver al refugio." })
            print("[LastPurpose] El jugador escapó 520 metros con el botín")
        end
    end

    if data.stage == returnStage and LastPurpose.hasSafehouseAnchor(player) then
        local dx = player:getX() - data.safehouseX
        local dy = player:getY() - data.safehouseY
        if player:getZ() == data.safehouseZ and (dx * dx) + (dy * dy) <= (RETURN_RADIUS * RETURN_RADIUS) then
            data.stage = reviewStage
            data.safehouseReturned = true
            data.safehouseReturnedAtHours = player:getHoursSurvived()
            LastPurpose.showThought(player, { "Por fin, de vuelta.", "Es hora de revisar el botín." })
            print("[LastPurpose] El jugador regresó al refugio; debe revisar el botín")
        end
    end
end
