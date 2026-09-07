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

local function spawnClue(data, clue)
    local square = getCell():getGridSquare(clue.x, clue.y, clue.z)
    if not square then return false end

    local note = square:AddWorldInventoryItem(NOTE_TYPE, 0.5, 0.5, 0)
    if not note then return false end
    note:getModData().LastPurposeClue = "louisville_knox_bank"

    pcall(function()
        createRandomDeadBody(getCell():getGridSquare(clue.x + 1, clue.y, clue.z), 10)
        addBloodSplat(square, 5)
    end)

    data.clueSpawned = true
    data.clueX, data.clueY, data.clueZ = clue.x, clue.y, clue.z
    LastPurpose.debugPrint(string.format("Nota del golpe creada en %d,%d,%d", clue.x, clue.y, clue.z))
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
        local note = LastPurpose.findClueNote(player)
        if note then data.cluePickedUp = true end
        if not LastPurpose.hasReadClueNote(player, note) then return end

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
