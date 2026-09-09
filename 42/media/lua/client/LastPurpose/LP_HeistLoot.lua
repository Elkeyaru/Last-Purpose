LastPurpose = LastPurpose or {}

local LOOT_ID = "louisville_knox_bank"
local BAG_TYPE = "LastPurpose.SealedKnoxBankLoot"
local function SPAWN() return LastPurpose.World.BANK_LOOT_SPAWN end
local PICKUP_CHECK_RADIUS = 80

-- Tinte de la bolsa del botin. El icono base ya es gris (Icon = DuffelBag_Grey
-- en el script), asi que aqui solo se aplica un multiplicador suave para
-- darle un matiz consistente sin oscurecerla. Antes era 0.08 (casi negro).
-- El modelo del suelo (WorldStaticModel) puede no respetar este color en
-- B42; si sigue saliendo tostado en el suelo habra que darle un
-- WorldObjectSprite/modelo propio.
local LOOT_TINT = 0.85
function LastPurpose.applyLootVisual(item)
    if not item then return end
    pcall(function()
        item:setColorRed(LOOT_TINT)
        item:setColorGreen(LOOT_TINT)
        item:setColorBlue(LOOT_TINT)
        item:setColor(Color.new(LOOT_TINT, LOOT_TINT, LOOT_TINT))
        item:setCustomColor(true)
    end)
end

local function markLootBag(bag)
    if not bag then return nil end
    LastPurpose.applyLootVisual(bag)
    local itemData = bag:getModData()
    itemData.LastPurposeLootId = LOOT_ID
    itemData.LastPurposeLootSealed = true
    return bag
end

local function spawnCorpse(x, y, z)
    local square = getCell():getGridSquare(x, y, z)
    if not square then return false end
    return pcall(function()
        createRandomDeadBody(square, 10)
        addBloodSplat(square, 6)
    end)
end

local function spawnLootScene(data)
    local square = getCell():getGridSquare(SPAWN().x, SPAWN().y, SPAWN().z)
    if not square then
        if not data.lootSquareWarningPrinted then
            print(string.format("[LastPurpose] La casilla del botin aun no esta cargada: %d,%d,%d", SPAWN().x, SPAWN().y, SPAWN().z))
            data.lootSquareWarningPrinted = true
        end
        return false
    end

    local bag = markLootBag(square:AddWorldInventoryItem(BAG_TYPE, 0.5, 0.5, 0))
    if not bag then
        print("[LastPurpose] No se pudo crear la bolsa sellada del Knox Bank")
        return false
    end

    spawnCorpse(SPAWN().x - 1, SPAWN().y, SPAWN().z)
    spawnCorpse(SPAWN().x + 1, SPAWN().y, SPAWN().z)
    data.lootSpawned = true
    data.lootSquareWarningPrinted = nil
    LastPurpose.debugPrint(string.format("Escena del botin creada en %d,%d,%d", SPAWN().x, SPAWN().y, SPAWN().z))
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
            if itemData and itemData.LastPurposeLootId == LOOT_ID then
                LastPurpose.applyLootVisual(item)
                return item
            end
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
    if not LastPurpose.stageIs(data, "heist_active") then return end

    local heist = LastPurpose.ensureSelectedHeist(player)
    if not heist or heist.id ~= LOOT_ID then return end

    local carriedBag = LastPurpose.findHeistLootBag(player:getInventory())
    if not data.lootSpawned and not carriedBag then
        local hour = getGameTime():getHour()
        local isNight = hour >= LastPurpose.World.NIGHT_START_HOUR or hour < LastPurpose.World.NIGHT_END_HOUR
        if not isNight then return end
        spawnLootScene(data)
        return
    end

    if carriedBag then
        data.lootSpawned = true
        LastPurpose.setStage(data, "loot_taken")
        data.lootTakenAtHours = player:getHoursSurvived()
        if LastPurpose.prepareExitAmbush then
            LastPurpose.prepareExitAmbush(player, data, false)
        else
            LastPurpose.heistEscapeActive = true
        end
        if HaloTextHelper then
            HaloTextHelper.addTextWithArrow(player, "Botin asegurado", true, 220, 185, 70)
        end
        LastPurpose.showThought(player, {
            "Ya lo tengo.",
            "Ahora tengo que salir de aqui con vida.",
        })
        LastPurpose.debugPrint("El jugador recogio el botin del Knox Bank")
    end
end

-- Comprobacion ligera por fotograma, solo mientras el golpe esta activo y el
-- jugador esta cerca; se apaga sola en cuanto lootTaken pasa a true.
function LastPurpose.updateHeistLootPickup()
    local player = LastPurpose.getPlayerSafe(0)
    if not player or not LastPurpose.isBurglar(player) then return end
    local data = LastPurpose.getData(player)
    if not LastPurpose.stageIs(data, "heist_active") then return end
    local dx, dy = player:getX() - SPAWN().x, player:getY() - SPAWN().y
    if dx * dx + dy * dy > PICKUP_CHECK_RADIUS * PICKUP_CHECK_RADIUS then return end
    LastPurpose.updateHeistLoot(player)
end
