LastPurpose = LastPurpose or {}

local LOOT_ID = "louisville_knox_bank"
local BAG_TYPE = "Base.Bag_MoneyBag"
local LOOT_X, LOOT_Y, LOOT_Z = 12562, 1690, 1
local SCENE_VERSION = 2

local function markLootBag(bag)
    if not bag then return nil end
    local itemData = bag:getModData()
    itemData.LastPurposeLootId = LOOT_ID
    itemData.LastPurposeLootVersion = 1
    if bag.setName then bag:setName("Botin del Knox Bank") end
    if bag.setCustomName then bag:setCustomName(true) end

    local contents = bag:getInventory()
    if contents then
        contents:AddItems("Base.SmallGoldBar", 5)
        contents:AddItems("Base.Diamond", 4)
        contents:AddItems("Base.MoneyBundle", 6)
    end
    return bag
end

local function spawnCorpse(x, y, z)
    local square = getCell():getGridSquare(x, y, z)
    if not square then return false end
    local ok = pcall(function()
        createRandomDeadBody(square, 10)
        addBloodSplat(square, 6)
    end)
    return ok
end

local function spawnLootScene(data)
    local square = getCell():getGridSquare(LOOT_X, LOOT_Y, LOOT_Z)
    if not square then
        if not data.lootSquareWarningPrinted then
            print(string.format("[LastPurpose] La casilla del botin aun no esta cargada: %d,%d,%d", LOOT_X, LOOT_Y, LOOT_Z))
            data.lootSquareWarningPrinted = true
        end
        return false
    end
    local bag = markLootBag(square:AddWorldInventoryItem(BAG_TYPE, 0.5, 0.5, 0))
    if not bag then
        print("[LastPurpose] No se pudo crear Base.Bag_MoneyBag en la casilla del botin")
        return false
    end

    spawnCorpse(LOOT_X - 1, LOOT_Y, LOOT_Z)
    spawnCorpse(LOOT_X + 1, LOOT_Y, LOOT_Z)
    data.lootSpawned = true
    data.lootSceneCreated = true
    data.lootSceneVersion = SCENE_VERSION
    data.lootSquareWarningPrinted = nil
    data.lootSpawnX, data.lootSpawnY, data.lootSpawnZ = LOOT_X, LOOT_Y, LOOT_Z
    data.lootContainerType = "ground"
    print(string.format("[LastPurpose] Escena del botin creada en %d,%d,%d", LOOT_X, LOOT_Y, LOOT_Z))
    return true
end

function LastPurpose.findHeistLootBag(container, seen)
    if not container or not container.getItems then return nil end
    seen = seen or {}
    if seen[container] then return nil end
    seen[container] = true
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            local itemData = item:getModData()
            if itemData and itemData.LastPurposeLootId == LOOT_ID then return item end
            if item.getInventory then
                local found = LastPurpose.findHeistLootBag(item:getInventory(), seen)
                if found then return found end
            end
        end
    end
    return nil
end

function LastPurpose.updateHeistLoot(player)
    player = player or LastPurpose.getPlayerSafe(0)
    if not player or not LastPurpose.isBurglar(player) then return end
    local data = LastPurpose.getData(player)
    if data.stage < 5 then return end
    local heist = LastPurpose.ensureSelectedHeist(player)
    if not heist or heist.id ~= LOOT_ID then return end

    if not data.lootTaken and data.lootSceneVersion ~= SCENE_VERSION then
        if not data.lootMigrationPrinted then
            print("[LastPurpose] Migrando el botin guardado a la escena fija v2")
            data.lootMigrationPrinted = true
        end
        data.lootSpawned = false
        data.lootSceneCreated = false
    end

    if not data.lootSpawned then
        local dx, dy = player:getX() - LOOT_X, player:getY() - LOOT_Y
        if player:getZ() ~= LOOT_Z or (dx * dx) + (dy * dy) > (35 * 35) then return end
        spawnLootScene(data)
        return
    end
    if data.lootTaken then return end

    if LastPurpose.findHeistLootBag(player:getInventory()) then
        data.lootTaken = true
        data.lootTakenAtHours = player:getHoursSurvived()
        data.stage = 6
        if HaloTextHelper then
            HaloTextHelper.addTextWithArrow(player, "Botin asegurado", true, 220, 185, 70)
        end
        LastPurpose.showThought(player, {
            "Ya lo tengo.",
            "Ahora tengo que salir de aqui con vida."
        })
        print("[LastPurpose] El jugador recogio el botin del Knox Bank")
    end
end
