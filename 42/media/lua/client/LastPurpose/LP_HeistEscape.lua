LastPurpose = LastPurpose or {}

local ALARM_X, ALARM_Y, ALARM_Z = 12562, 1690, 0
local ALARM_DURATION_MS = 35000
local WAVE_COUNT = 5
local ZOMBIES_PER_WAVE = 40
local CLUSTERS_PER_WAVE = 5
local WAVE_INTERVAL_MS = 750
local SPAWN_MIN_RADIUS = 30
local SPAWN_MAX_RADIUS = 50
local AMBUSH_VERSION = 3
local BANK_MIN_X, BANK_MAX_X = 12560, 12583
local BANK_MIN_Y, BANK_MAX_Y = 1687, 1737

LastPurpose.heistAlarmRuntime = LastPurpose.heistAlarmRuntime or {}
LastPurpose.heistEscapeActive = LastPurpose.heistEscapeActive or false

local function startAlarm(player, data, now)
    local runtime = LastPurpose.heistAlarmRuntime
    runtime.startedAt = now
    runtime.nextWaveAt = now
    runtime.nextNoiseAt = now
    runtime.soundId = nil

    local ok, soundId = pcall(function()
        return player:getEmitter():playSound("HouseAlarm")
    end)
    if ok then runtime.soundId = soundId end

    data.ambushTriggered = true
    data.ambushVersion = AMBUSH_VERSION
    data.ambushStartedAtHours = player:getHoursSurvived()
    data.ambushWavesSpawned = tonumber(data.ambushWavesSpawned) or 0
    print("[LastPurpose] Alarma del Knox Bank activada durante 35 segundos")
end

local function spawnWave(data)
    local spawned = 0
    local clusterSize = math.floor(ZOMBIES_PER_WAVE / CLUSTERS_PER_WAVE)
    local baseAngle = ZombRand(360)
    local ok, err = pcall(function()
        for cluster = 0, CLUSTERS_PER_WAVE - 1 do
            local angle = math.rad(baseAngle + math.floor((360 / CLUSTERS_PER_WAVE) * cluster) + ZombRand(-12, 13))
            local radius = ZombRand(SPAWN_MIN_RADIUS, SPAWN_MAX_RADIUS + 1)
            local spawnX = math.floor(ALARM_X + math.cos(angle) * radius)
            local spawnY = math.floor(ALARM_Y + math.sin(angle) * radius)
            local zombies = addZombiesInOutfit(spawnX, spawnY, ALARM_Z, clusterSize, nil, 50)
            if zombies then
                for i = 0, zombies:size() - 1 do
                    local zombie = zombies:get(i)
                    if zombie then
                        zombie:pathToLocation(ALARM_X, ALARM_Y, ALARM_Z)
                        spawned = spawned + 1
                    end
                end
            end
        end
    end)
    if not ok then
        print("[LastPurpose] Error creando oleada del banco: " .. tostring(err))
        return false
    end
    data.ambushWavesSpawned = (tonumber(data.ambushWavesSpawned) or 0) + 1
    data.ambushZombiesSpawned = (tonumber(data.ambushZombiesSpawned) or 0) + spawned
    print(string.format("[LastPurpose] Oleada %d/%d creada: %d zombis cercanos", data.ambushWavesSpawned, WAVE_COUNT, spawned))
    return true
end

local function stopAlarm(player, data)
    local runtime = LastPurpose.heistAlarmRuntime
    if runtime.soundId then
        pcall(function() player:getEmitter():stopSound(runtime.soundId) end)
    end
    runtime.startedAt = nil
    runtime.nextWaveAt = nil
    runtime.nextNoiseAt = nil
    runtime.soundId = nil
    data.ambushCompleted = true
    data.ambushCompletedAtHours = player:getHoursSurvived()
    print(string.format("[LastPurpose] Emboscada completada: %d zombis solicitados", WAVE_COUNT * ZOMBIES_PER_WAVE))
end

function LastPurpose.prepareExitAmbush(player, data, waitForExit)
    local runtime = LastPurpose.heistAlarmRuntime
    if runtime.soundId then
        pcall(function() player:getEmitter():stopSound(runtime.soundId) end)
    end
    runtime.startedAt = nil
    runtime.nextWaveAt = nil
    runtime.nextNoiseAt = nil
    runtime.soundId = nil
    data.ambushTriggered = false
    data.ambushCompleted = false
    data.ambushForced = false
    data.ambushWavesSpawned = 0
    data.ambushZombiesSpawned = 0
    data.ambushVersion = AMBUSH_VERSION
    data.exitAmbushPrepared = true
    data.exitAmbushPending = waitForExit == true
    LastPurpose.heistEscapeActive = waitForExit ~= true
    print(waitForExit and "[LastPurpose] Segunda emboscada preparada para la salida del banco" or "[LastPurpose] Emboscada preparada al recoger el botin")
end

function LastPurpose.updateHeistEscape()
    local player = LastPurpose.getPlayerSafe(0)
    if not player or not LastPurpose.isBurglar(player) then return end
    local data = LastPurpose.getData(player)
    if data.exitAmbushPending and data.lootTaken then
        local x,y=player:getX(),player:getY()
        if x<BANK_MIN_X or x>BANK_MAX_X or y<BANK_MIN_Y or y>BANK_MAX_Y then
            data.exitAmbushPending=false
            LastPurpose.heistEscapeActive=true
            print("[LastPurpose] El jugador salio del banco; comienza la segunda emboscada")
        end
    end
    if not LastPurpose.heistEscapeActive then return end
    local lootStage = data.storyFlowVersion == 2 and 10 or 6
    if (not data.lootTaken and not data.ambushForced) or (data.stage < lootStage and not data.ambushForced) then
        LastPurpose.heistEscapeActive = false
        return
    end

    if data.ambushVersion ~= AMBUSH_VERSION then
        local dx, dy = player:getX() - ALARM_X, player:getY() - ALARM_Y
        if (dx * dx) + (dy * dy) > (100 * 100) then return end
        data.ambushTriggered = false
        data.ambushCompleted = false
        data.ambushWavesSpawned = 0
        data.ambushZombiesSpawned = 0
        data.ambushVersion = AMBUSH_VERSION
        print("[LastPurpose] Emboscada migrada al asalto inmediato v3")
    end
    if data.ambushCompleted then
        LastPurpose.heistEscapeActive = false
        return
    end

    local now = getTimestampMs()
    local runtime = LastPurpose.heistAlarmRuntime
    if not runtime.startedAt then startAlarm(player, data, now) end

    if now >= runtime.nextNoiseAt then
        addSound(player, ALARM_X, ALARM_Y, ALARM_Z, 220, 100)
        runtime.nextNoiseAt = now + 1000
    end

    local waves = tonumber(data.ambushWavesSpawned) or 0
    if waves < WAVE_COUNT and now >= runtime.nextWaveAt then
        if spawnWave(data) then runtime.nextWaveAt = now + WAVE_INTERVAL_MS
        else runtime.nextWaveAt = now + 1000 end
    end

    if now - runtime.startedAt >= ALARM_DURATION_MS and (tonumber(data.ambushWavesSpawned) or 0) >= WAVE_COUNT then
        stopAlarm(player, data)
    end
end

function LastPurpose.refreshHeistEscape()
    local player = LastPurpose.getPlayerSafe(0)
    if not player or not LastPurpose.isBurglar(player) then return end
    local data = LastPurpose.getData(player)
    local lootStage = data.storyFlowVersion == 2 and 10 or 6
    LastPurpose.heistEscapeActive = (data.exitAmbushPending ~= true)
        and (data.lootTaken == true and data.stage >= lootStage or data.ambushForced == true)
        and data.ambushCompleted ~= true
end
