LastPurpose = LastPurpose or {}

-- Generico para cualquier golpe: lee lootSpawn/lootBagType del golpe activo
-- (LastPurpose.ensureSelectedHeist) en vez de apuntar siempre al Knox Bank.
-- Los dos campos son obligatorios en LastPurpose.HEISTS; si faltan en algun
-- golpe nuevo, cae al valor del Knox Bank para no romper nada (pero conviene
-- rellenarlos).
local function lootSpawnOf(heist)
    return (heist and heist.lootSpawn) or LastPurpose.World.BANK_LOOT_SPAWN
end
local function bagTypeOf(heist)
    return (heist and heist.lootBagType) or "LastPurpose.SealedKnoxBankLoot"
end
local PICKUP_CHECK_RADIUS = 80

-- NO-OP a proposito. El tinte por codigo (setCustomColor + setColor*) sobre
-- estas bolsas rompia su renderizado (icono/modelo salian en negro), tanto
-- con 0.08 como con 1.0. La bolsa usa ahora el icono/modelo vanilla del
-- duffel tal cual (Icon = Duffelbag en el script). Si se quiere gris de
-- verdad hara falta un icono/modelo propio, no un multiplicador.
function LastPurpose.applyLootVisual(item)
    -- deliberadamente sin efecto
end

local function markLootBag(bag, heistId)
    if not bag then return nil end
    LastPurpose.applyLootVisual(bag)
    local itemData = bag:getModData()
    itemData.LastPurposeLootId = heistId
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

local function spawnLootScene(data, heist)
    local spawn = lootSpawnOf(heist)
    local square = getCell():getGridSquare(spawn.x, spawn.y, spawn.z)
    if not square then
        if not data.lootSquareWarningPrinted then
            print(string.format("[LastPurpose] La casilla del botin aun no esta cargada: %d,%d,%d", spawn.x, spawn.y, spawn.z))
            data.lootSquareWarningPrinted = true
        end
        return false
    end

    local bag = markLootBag(square:AddWorldInventoryItem(bagTypeOf(heist), 0.5, 0.5, 0), heist.id)
    if not bag then
        print("[LastPurpose] No se pudo crear la bolsa sellada de " .. tostring(heist.id))
        return false
    end

    spawnCorpse(spawn.x - 1, spawn.y, spawn.z)
    spawnCorpse(spawn.x + 1, spawn.y, spawn.z)
    data.lootSpawned = true
    data.lootSquareWarningPrinted = nil
    LastPurpose.debugPrint(string.format("Escena del botin creada en %d,%d,%d (%s)", spawn.x, spawn.y, spawn.z, tostring(heist.id)))
    return true
end

-- Acepta la bolsa sellada/abierta de CUALQUIER golpe conocido (no solo el
-- Knox Bank): basta con que LastPurposeLootId resuelva a un golpe real.
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
            if itemData and itemData.LastPurposeLootId and LastPurpose.getHeist(itemData.LastPurposeLootId) then
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
    if not heist then return end

    local carriedBag = LastPurpose.findHeistLootBag(player:getInventory())
    if not data.lootSpawned and not carriedBag then
        -- La mayoria de los golpes se hacen de noche (ver requiresNight en
        -- LastPurpose.HEISTS); los que no lo exigen generan el botin en
        -- cuanto el golpe esta activo.
        if heist.requiresNight ~= false then
            local hour = getGameTime():getHour()
            local isNight = hour >= LastPurpose.World.NIGHT_START_HOUR or hour < LastPurpose.World.NIGHT_END_HOUR
            if not isNight then return end
        end
        spawnLootScene(data, heist)
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
        LastPurpose.debugPrint("El jugador recogio el botin (" .. tostring(heist.id) .. ")")
    end
end

-- Comprobacion mientras el golpe esta activo y el jugador esta cerca; se
-- apaga sola en cuanto lootTaken pasa a true. El escaneo recursivo del
-- inventario (findHeistLootBag) es lo caro, asi que se limita a ~4 veces
-- por segundo en vez de en cada fotograma: quita el tiron al recoger la
-- bolsa sin retrasar la deteccion de forma perceptible.
local pickupTick = 0
function LastPurpose.updateHeistLootPickup()
    local player = LastPurpose.getPlayerSafe(0)
    if not player or not LastPurpose.isBurglar(player) then return end
    local data = LastPurpose.getData(player)
    if not LastPurpose.stageIs(data, "heist_active") then return end
    local heist = LastPurpose.getHeist(data.selectedHeist)
    if not heist then return end
    local spawn = lootSpawnOf(heist)
    local dx, dy = player:getX() - spawn.x, player:getY() - spawn.y
    if dx * dx + dy * dy > PICKUP_CHECK_RADIUS * PICKUP_CHECK_RADIUS then return end
    pickupTick = pickupTick + 1
    if pickupTick % 15 ~= 0 then return end
    LastPurpose.updateHeistLoot(player)
end
