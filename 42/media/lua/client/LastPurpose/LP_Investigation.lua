LastPurpose = LastPurpose or {}

local NOTE_TYPE = "LastPurpose.KnoxMeetingNote"
-- El reconocimiento exige acercarse sin llegar a entrar: entre el radio de
-- llegada del propio golpe (heist.arrivalRadius) y este maximo.
local RECON_MAX_RADIUS = 90

local function findInventoryItem(container, fullType, seen)
    if not container or not container.getItems then return nil end
    seen = seen or {}
    if seen[container] then return nil end
    seen[container] = true

    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            if item:getFullType() == fullType then return item end
            if item.getInventory then
                local nested = findInventoryItem(item:getInventory(), fullType, seen)
                if nested then return nested end
            end
        end
    end
    return nil
end

function LastPurpose.findClueNote(player)
    if not player or not player.getInventory then return nil end
    return findInventoryItem(player:getInventory(), NOTE_TYPE)
end

-- La nota debe leerse con la accion vanilla de lectura, no solo recogerse.
-- Comparamos tanto el registro del personaje como el del propio objeto
-- porque B42 expone la lectura de literatura de dos formas distintas segun
-- el contexto.
function LastPurpose.hasReadClueNote(player, note)
    note = note or LastPurpose.findClueNote(player)
    if not player or not note then return false end

    local okPages, numberOfPages = pcall(function() return note:getNumberOfPages() end)
    if not okPages or (tonumber(numberOfPages) or 0) <= 0 then return false end

    local okPlayerRead, playerPagesRead = pcall(function()
        return player:getAlreadyReadPages(note:getFullType())
    end)
    local okItemRead, itemPagesRead = pcall(function() return note:getAlreadyReadPages() end)

    local pagesRead = math.max(
        okPlayerRead and (tonumber(playerPagesRead) or 0) or 0,
        okItemRead and (tonumber(itemPagesRead) or 0) or 0
    )
    return pagesRead >= numberOfPages
end

-- Casilla utilizable para la escena de la nota: con suelo, no solida y SIN
-- vehiculo encima (el bug era que a veces caia bajo un coche). Si la de
-- destino no sirve, busca en espiral hasta 4 tiles alrededor.
local function squareUsable(sq)
    if not sq then return false end
    local okSolid, solid = pcall(function() return sq:isSolid() end)
    if okSolid and solid then return false end
    local okVeh, hasVeh = pcall(function()
        if sq.getVehicleContainer and sq:getVehicleContainer() then return true end
        if sq.HasVehicle and sq:HasVehicle() then return true end
        return false
    end)
    if okVeh and hasVeh then return false end
    local okFloor, hasFloor = pcall(function() return sq:getFloor() ~= nil end)
    if okFloor and not hasFloor then return false end
    return true
end

local function findClueSquare(cx, cy, cz)
    local cell = getCell()
    for r = 0, 4 do
        for dy = -r, r do
            for dx = -r, r do
                if r == 0 or math.abs(dx) == r or math.abs(dy) == r then
                    local sq = cell:getGridSquare(cx + dx, cy + dy, cz)
                    if squareUsable(sq) then return sq end
                end
            end
        end
    end
    return cell:getGridSquare(cx, cy, cz)
end

local function spawnGuards(x, y, z, n)
    local ok = pcall(function()
        if addZombiesInOutfit then
            addZombiesInOutfit(x, y, z, n, nil, 50)
        else
            error("no addZombiesInOutfit")
        end
    end)
    if not ok then
        pcall(function()
            for _ = 1, n do
                createHorde(1, x - 1, y - 1, x + 1, y + 1, x, y, false, false)
            end
        end)
    end
end

local function spawnClue(data, clue)
    local square = findClueSquare(clue.x, clue.y, clue.z)
    if not square then return false end
    local sx, sy, sz = square:getX(), square:getY(), square:getZ()

    -- Dos cuerpos; la nota va DENTRO de uno de ellos (hay que saquearlos).
    local corpses = {}
    pcall(function() corpses[1] = createRandomDeadBody(square, 10) end)
    local adj = findClueSquare(sx + 1, sy, sz)
    pcall(function() corpses[2] = createRandomDeadBody(adj or square, 10) end)
    pcall(function() addBloodSplat(square, 6) end)

    local placed = false
    for _, c in ipairs(corpses) do
        if not placed and c then
            local okC, cont = pcall(function()
                return c:getContainer() or (c.getItemContainer and c:getItemContainer()) or nil
            end)
            if okC and cont then
                local okA, item = pcall(function() return cont:AddItem(NOTE_TYPE) end)
                if okA and item then
                    item:getModData().LastPurposeClue = "louisville_knox_bank"
                    placed = true
                end
            end
        end
    end
    if not placed then
        -- Ultimo recurso: en el suelo, para que la nota nunca se pierda.
        local note = square:AddWorldInventoryItem(NOTE_TYPE, 0.5, 0.5, 0)
        if not note then return false end
        note:getModData().LastPurposeClue = "louisville_knox_bank"
    end

    -- Al menos 3 zombis custodiando.
    spawnGuards(sx, sy, sz, 3)

    data.clueSpawned = true
    data.clueX, data.clueY, data.clueZ = sx, sy, sz
    LastPurpose.debugPrint(string.format(
        "Escena de la nota creada en %d,%d,%d (nota %s)", sx, sy, sz,
        placed and "en un cadaver" or "en el suelo"))
    return true
end

function LastPurpose.updateInvestigation(player)
    player = player or LastPurpose.getPlayerSafe(0)
    if not player or not LastPurpose.isBurglar(player) then return end
    local data = LastPurpose.getData(player)
    local heist = LastPurpose.ensureSelectedHeist(player)
    if not heist then return end
    local clue = LastPurpose.getHeistClue(data, heist)
    if not clue then return end

    if LastPurpose.stageIs(data, "radio_heard") then
        local dx, dy = player:getX() - clue.x, player:getY() - clue.y
        if player:getZ() == clue.z and (dx * dx) + (dy * dy) <= (clue.arrivalRadius * clue.arrivalRadius) then
            if not data.clueSpawned then spawnClue(data, clue) end
            if data.clueSpawned then
                LastPurpose.setStage(data, "clue_found")
                LastPurpose.showThought(player, {
                    "Este debe ser el lugar.",
                    "Tiene que haber algo que dejaron atras.",
                })
            end
        end
        return
    end

    if LastPurpose.stageIs(data, "clue_found") then
        -- La nota tiene que estar en el INVENTARIO del jugador (no leerla
        -- desde el suelo/cadaver) y pasar un momento "leyendola". Antes se
        -- dependia solo de getAlreadyReadPages, que fallaba cuando la accion
        -- de lectura devolvia el item al mundo.
        local note = LastPurpose.findClueNote(player)
        if not note then
            data.clueHeldSinceHours = nil
            return
        end
        data.cluePickedUp = true
        data.clueHeldSinceHours = data.clueHeldSinceHours or player:getHoursSurvived()
        local heldHours = player:getHoursSurvived() - (data.clueHeldSinceHours or 0)
        -- Rato leyendo la nota: ~10 s reales a velocidad normal (1 min de
        -- juego ~ 3 s reales -> ~3.3 min de juego). La comprobacion corre
        -- 1x/minuto de juego, asi que confirma unos 3-4 ticks tras recogerla.
        local NOTE_READ_HOURS = 0.055

        if not (LastPurpose.hasReadClueNote(player, note) or heldHours >= NOTE_READ_HOURS) then
            if not data.clueReadHintShown then
                data.clueReadHintShown = true
                LastPurpose.showThought(player, { "Mejor leo esto con calma." })
            end
            return
        end

        LastPurpose.setStage(data, "note_read")
        data.clueRecovered = true
        data.mapCenteredOnce = false
        data.mapAreaRevealed_heist = false
        LastPurpose.showThought(player, {
            "Knox Bank... asi que ese es el objetivo.",
            "Sera mejor reconocer la zona primero.",
        })
        LastPurpose.debugPrint("El jugador leyo la nota y descubrio el banco")
        return
    end

    if LastPurpose.stageIs(data, "note_read") then
        local dx, dy = player:getX() - heist.x, player:getY() - heist.y
        local distanceSquared = (dx * dx) + (dy * dy)
        if distanceSquared <= (RECON_MAX_RADIUS * RECON_MAX_RADIUS)
            and distanceSquared > (heist.arrivalRadius * heist.arrivalRadius) then
            LastPurpose.setStage(data, "bank_scouted")
            data.mapCenteredOnce = false
            LastPurpose.showThought(player, {
                "Ya conozco las entradas.",
                "Volvere cuando haya oscurecido.",
            })
            LastPurpose.debugPrint("Knox Bank reconocido sin iniciar el golpe")
        end
        return
    end

    if LastPurpose.stageIs(data, "bank_scouted") then
        local hour = getGameTime():getHour()
        local isNight = hour >= LastPurpose.World.NIGHT_START_HOUR or hour < LastPurpose.World.NIGHT_END_HOUR
        if not isNight then return end
        local dx, dy = player:getX() - heist.x, player:getY() - heist.y
        if (dx * dx) + (dy * dy) <= (heist.arrivalRadius * heist.arrivalRadius) then
            LastPurpose.setStage(data, "heist_active")
            data.heistReachedAtHours = player:getHoursSurvived()
            LastPurpose.showThought(player, {
                "Este es el momento.",
                "Ahora tengo que encontrar el botin.",
            })
            LastPurpose.debugPrint("El golpe comenzo durante la ventana nocturna")
        end
    end
end
