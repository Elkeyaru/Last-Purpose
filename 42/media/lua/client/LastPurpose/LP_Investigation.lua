LastPurpose = LastPurpose or {}

local NOTE_TYPE = "LastPurpose.KnoxMeetingNote"

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
                local nestedItem = findInventoryItem(item:getInventory(), fullType, seen)
                if nestedItem then return nestedItem end
            end
        end
    end
    return nil
end

function LastPurpose.findClueNote(player)
    if not player or not player.getInventory then return nil end
    return findInventoryItem(player:getInventory(), NOTE_TYPE)
end

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

local function vehicleReady(vehicle)
    if not vehicle or not vehicle.getPartById or not vehicle.isEngineWorking then return false end
    local okEngine, engineWorking = pcall(function() return vehicle:isEngineWorking() end)
    if not okEngine or not engineWorking then return false end
    local okTank, tank = pcall(function() return vehicle:getPartById("GasTank") end)
    if not okTank or not tank or not tank.getContainerContentAmount then return false end
    local okFuel, fuel = pcall(function() return tank:getContainerContentAmount() end)
    return okFuel and (tonumber(fuel) or 0) > 0
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
    print(string.format("[LastPurpose] Nota del golpe creada en %d,%d,%d", clue.x, clue.y, clue.z))
    return true
end

function LastPurpose.updateInvestigation(player)
    player = player or LastPurpose.getPlayerSafe(0)
    if not player or not LastPurpose.isBurglar(player) then return end
    local data = LastPurpose.getData(player)
    if data.storyFlowVersion ~= 2 then return end
    local heist = LastPurpose.ensureSelectedHeist(player)
    if not heist then return end
    local clue = LastPurpose.getHeistClue(data, heist)
    if not clue then return end

    if data.stage == 4 then
        local dx, dy = player:getX() - clue.x, player:getY() - clue.y
        if player:getZ() == clue.z and (dx * dx) + (dy * dy) <= (clue.arrivalRadius * clue.arrivalRadius) then
            if not data.clueSpawned then spawnClue(data, clue) end
            if data.clueSpawned then
                data.stage = 5
                LastPurpose.showThought(player, { "Este debe ser el lugar.", "Tiene que haber algo que dejaron atrás." })
            end
        end
        return
    end

    if data.stage == 5 then
        local note = LastPurpose.findClueNote(player)
        if note then data.cluePickedUp = true end
        if not LastPurpose.hasReadClueNote(player, note) then return end

            data.stage = 6
            data.clueRecovered = true
            data.clueRead = true
            data.mapCenteredOnce = false
            data.mapAreaRevealed_heist = false
        LastPurpose.showThought(player, { "Knox Bank... así que ese es el objetivo.", "Será mejor reconocer la zona primero." })
        print("[LastPurpose] El jugador leyo la nota y descubrio el banco")
        return
    end

    if data.stage == 6 then
        local dx, dy = player:getX() - heist.x, player:getY() - heist.y
        local distanceSquared = (dx * dx) + (dy * dy)
        if distanceSquared <= (90 * 90) and distanceSquared > (heist.arrivalRadius * heist.arrivalRadius) then
            data.stage = 8
            data.bankScouted = true
            data.mapCenteredOnce = false
            LastPurpose.showThought(player, { "Ya conozco las entradas.", "Volvere cuando haya oscurecido." })
            print("[LastPurpose] Knox Bank reconocido sin iniciar el golpe")
        end
        return
    end

    if data.stage == 8 then
        local hour = getGameTime():getHour()
        local isNight = hour >= 20 or hour < 5
        if not isNight then return end
        local dx, dy = player:getX() - heist.x, player:getY() - heist.y
        if (dx * dx) + (dy * dy) <= (heist.arrivalRadius * heist.arrivalRadius) then
            data.stage = 9
            data.heistLocationReached = true
            data.heistReachedAtHours = player:getHoursSurvived()
            LastPurpose.showThought(player, { "Este es el momento.", "Ahora tengo que encontrar el botín." })
            print("[LastPurpose] El golpe comenzo durante la ventana nocturna")
        end
    end
end
