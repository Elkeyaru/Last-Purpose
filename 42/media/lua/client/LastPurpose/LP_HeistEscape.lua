LastPurpose = LastPurpose or {}

-- Funcion, no una constante de archivo: LastPurpose.World vive en un archivo
-- compartido que puede no haber cargado todavia cuando este archivo carga.
local function ORIGIN() return LastPurpose.World.ALARM_ORIGIN end
local ALARM_DURATION_MS = 35000
local WAVE_COUNT = 5
local ZOMBIES_PER_WAVE = 40
local CLUSTERS_PER_WAVE = 5
local WAVE_INTERVAL_MS = 750
local SPAWN_MIN_RADIUS = 30
local SPAWN_MAX_RADIUS = 50

LastPurpose.heistAlarmRuntime = LastPurpose.heistAlarmRuntime or {}
LastPurpose.heistEscapeActive = LastPurpose.heistEscapeActive or false

local function startAlarm(player, data, now)
    local runtime = LastPurpose.heistAlarmRuntime
    -- Si veniamos de recuperar una partida guardada a mitad de la alarma,
    -- retomamos el tiempo restante en vez de reiniciar los 35 segundos.
    local remaining = math.max(0, math.min(ALARM_DURATION_MS, tonumber(data.ambushRemainingMs) or ALARM_DURATION_MS))
    runtime.startedAt = now - (ALARM_DURATION_MS - remaining)
    runtime.nextWaveAt = now
    runtime.nextNoiseAt = now
    runtime.soundId = nil

    local ok, soundId = pcall(function() return player:getEmitter():playSound("HouseAlarm") end)
    if ok then runtime.soundId = soundId end

    data.ambushTriggered = true
    data.ambushWavesSpawned = tonumber(data.ambushWavesSpawned) or 0
    LastPurpose.debugPrint("Alarma del Knox Bank activada")
end

-- Genera una oleada grupo por grupo. Si el motor falla a mitad de una
-- oleada, recordamos que grupos ya se procesaron para no repetirlos en el
-- siguiente intento.
local function spawnWave(data)
    local spawned = 0
    local clusterSize = math.floor(ZOMBIES_PER_WAVE / CLUSTERS_PER_WAVE)
    local baseAngle = ZombRand(360)
    local firstCluster = tonumber(data.ambushClustersProcessed) or 0

    for cluster = firstCluster, CLUSTERS_PER_WAVE - 1 do
        data.ambushClustersProcessed = cluster + 1
        local ok, err = pcall(function()
            local angle = math.rad(baseAngle + math.floor((360 / CLUSTERS_PER_WAVE) * cluster) + ZombRand(-12, 13))
            local radius = ZombRand(SPAWN_MIN_RADIUS, SPAWN_MAX_RADIUS + 1)
            local spawnX = math.floor(ORIGIN().x + math.cos(angle) * radius)
            local spawnY = math.floor(ORIGIN().y + math.sin(angle) * radius)
            local zombies = addZombiesInOutfit(spawnX, spawnY, ORIGIN().z, clusterSize, nil, 50)
            if zombies then
                for i = 0, zombies:size() - 1 do
                    local zombie = zombies:get(i)
                    if zombie then
                        spawned = spawned + 1
                        pcall(function() zombie:pathToLocation(ORIGIN().x, ORIGIN().y, ORIGIN().z) end)
                    end
                end
            end
        end)
        if not ok then
            print("[LastPurpose] Grupo de zombis omitido tras un error del motor: " .. tostring(err))
        end
    end

    data.ambushClustersProcessed = 0
    data.ambushWavesSpawned = (tonumber(data.ambushWavesSpawned) or 0) + 1
    data.ambushZombiesSpawned = (tonumber(data.ambushZombiesSpawned) or 0) + spawned
    LastPurpose.debugPrint(string.format("Oleada %d/%d: %d zombis generados", data.ambushWavesSpawned, WAVE_COUNT, spawned))
    return true
end

local function stopAlarm(player, data)
    local runtime = LastPurpose.heistAlarmRuntime
    if runtime.soundId then
        pcall(function() player:getEmitter():stopSound(runtime.soundId) end)
    end
    runtime.startedAt, runtime.nextWaveAt, runtime.nextNoiseAt, runtime.soundId = nil, nil, nil, nil
    data.ambushCompleted = true
    data.ambushRemainingMs = 0
    LastPurpose.debugPrint(string.format(
        "Emboscada completada: %d zombis confirmados de %d previstos",
        tonumber(data.ambushZombiesSpawned) or 0, WAVE_COUNT * ZOMBIES_PER_WAVE
    ))
end

-- Prepara una emboscada nueva y completa. Se llama al recoger el botin
-- (waitForExit=false, arranca de inmediato) o al preparar la segunda
-- emboscada de salida tras una alarma anticipada (waitForExit=true).
function LastPurpose.prepareExitAmbush(player, data, waitForExit)
    local runtime = LastPurpose.heistAlarmRuntime
    if runtime.soundId then
        pcall(function() player:getEmitter():stopSound(runtime.soundId) end)
    end
    runtime.startedAt, runtime.nextWaveAt, runtime.nextNoiseAt, runtime.soundId = nil, nil, nil, nil

    data.ambushTriggered = false
    data.ambushCompleted = false
    data.ambushForced = false
    data.ambushWavesSpawned = 0
    data.ambushZombiesSpawned = 0
    data.ambushClustersProcessed = 0
    data.ambushRemainingMs = ALARM_DURATION_MS
    data.exitAmbushPrepared = true
    data.exitAmbushPending = waitForExit == true
    LastPurpose.heistEscapeActive = waitForExit ~= true
    LastPurpose.debugPrint(waitForExit
        and "Segunda emboscada preparada para la salida del banco"
        or "Emboscada preparada al recoger el botin")
end

function LastPurpose.updateHeistEscape()
    local player = LastPurpose.getPlayerSafe(0)
    if not player or not LastPurpose.isBurglar(player) then return end
    local data = LastPurpose.getData(player)

    if data.exitAmbushPending and LastPurpose.stageAtLeast(data, "loot_taken") then
        local perimeter = LastPurpose.World.BANK_PERIMETER
        local x, y = player:getX(), player:getY()
        if x < perimeter.minX or x > perimeter.maxX or y < perimeter.minY or y > perimeter.maxY then
            data.exitAmbushPending = false
            LastPurpose.heistEscapeActive = true
            LastPurpose.debugPrint("El jugador salio del banco; comienza la segunda emboscada")
        end
    end

    if not LastPurpose.heistEscapeActive then return end
    if LastPurpose.stageBefore(data, "loot_taken") and not data.ambushForced then
        LastPurpose.heistEscapeActive = false
        return
    end
    if data.ambushCompleted then
        LastPurpose.heistEscapeActive = false
        return
    end

    local now = getTimestampMs()
    local runtime = LastPurpose.heistAlarmRuntime
    if not runtime.startedAt then startAlarm(player, data, now) end
    data.ambushRemainingMs = math.max(0, ALARM_DURATION_MS - (now - runtime.startedAt))

    if now >= runtime.nextNoiseAt then
        addSound(player, ORIGIN().x, ORIGIN().y, ORIGIN().z, 220, 100)
        runtime.nextNoiseAt = now + 1000
    end

    local waves = tonumber(data.ambushWavesSpawned) or 0
    if waves < WAVE_COUNT and now >= runtime.nextWaveAt then
        spawnWave(data)
        runtime.nextWaveAt = now + WAVE_INTERVAL_MS
    end

    if now - runtime.startedAt >= ALARM_DURATION_MS and (tonumber(data.ambushWavesSpawned) or 0) >= WAVE_COUNT then
        stopAlarm(player, data)
    end
end

-- Reactiva la emboscada al cargar una partida que se guardo a mitad de un
-- asalto en curso.
function LastPurpose.refreshHeistEscape()
    local player = LastPurpose.getPlayerSafe(0)
    if not player or not LastPurpose.isBurglar(player) then return end
    local data = LastPurpose.getData(player)
    LastPurpose.heistEscapeActive = (data.exitAmbushPending ~= true)
        and (LastPurpose.stageAtLeast(data, "loot_taken") or data.ambushForced == true)
        and data.ambushCompleted ~= true
end
