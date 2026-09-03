LastPurposeRadio = LastPurposeRadio or {}
LastPurposeRadio.UUID = "LP-HEIST-001"
LastPurposeRadio.MODDATA_KEY = "LastPurposeRadioFrequency"
LastPurposeRadio.MIN_FREQUENCY = 88000
LastPurposeRadio.MAX_FREQUENCY = 108000
LastPurposeRadio.FREQUENCY_STEP = 200

local function getOccupiedFrequencies(scriptManager)
    local occupied = {}
    local channels = scriptManager:getChannelsList()
    if channels then
        for index = 0, channels:size() - 1 do
            local channel = channels:get(index)
            if channel and tostring(channel:getGUID()) ~= LastPurposeRadio.UUID then
                occupied[channel:GetFrequency()] = true
            end
        end
    end

    -- DynamicRadio contiene tambien canales declarados por mods que aun no han
    -- ejecutado su turno de registro en OnLoadRadioScripts.
    if DynamicRadio and type(DynamicRadio.channels) == "table" then
        for _, definition in ipairs(DynamicRadio.channels) do
            local frequency = tonumber(definition.freq)
            if frequency and tostring(definition.uuid or "") ~= LastPurposeRadio.UUID then
                occupied[frequency] = true
            end
        end
    end
    return occupied
end

local function isValidFrequency(frequency)
    return type(frequency) == "number"
        and frequency >= LastPurposeRadio.MIN_FREQUENCY
        and frequency <= LastPurposeRadio.MAX_FREQUENCY
        and frequency % LastPurposeRadio.FREQUENCY_STEP == 0
end

local function chooseFreeFrequency(occupied)
    local total = math.floor((LastPurposeRadio.MAX_FREQUENCY - LastPurposeRadio.MIN_FREQUENCY) / LastPurposeRadio.FREQUENCY_STEP) + 1
    local start = ZombRand(total)
    for offset = 0, total - 1 do
        local index = (start + offset) % total
        local candidate = LastPurposeRadio.MIN_FREQUENCY + (index * LastPurposeRadio.FREQUENCY_STEP)
        if not occupied[candidate] then return candidate end
    end
    return nil
end

local function getFrequency(scriptManager)
    local data = getGameTime():getModData()
    local occupied = getOccupiedFrequencies(scriptManager)
    local saved = data[LastPurposeRadio.MODDATA_KEY]
    if isValidFrequency(saved) and not occupied[saved] then return saved end

    local frequency = chooseFreeFrequency(occupied)
    if frequency then
        if isValidFrequency(saved) and occupied[saved] then
            print("[LastPurpose] Colision de radio detectada en " .. tostring(saved / 1000) .. " MHz; buscando otra frecuencia")
        end
        data[LastPurposeRadio.MODDATA_KEY] = frequency
    end
    return frequency
end

function LastPurposeRadio.onLoadRadioScripts(scriptManager)
    local frequency = getFrequency(scriptManager)
    if not frequency then
        print("[LastPurpose] ERROR: no hay frecuencias de radio disponibles entre 88.0 y 108.0 MHz")
        return
    end
    local channel = DynamicRadioChannel.new("Senal desconocida", frequency, ChannelCategory.Bandit, LastPurposeRadio.UUID)
    scriptManager:AddChannel(channel, false)
    LastPurposeRadio.channel = channel
    print("[LastPurpose] Canal narrativo registrado en " .. tostring(frequency / 1000) .. " MHz")
end

local function createBroadcast(worldAgeHours)
    local broadcast = RadioBroadCast.new("LP-HEIST-" .. tostring(math.floor(worldAgeHours / 6)), -1, -1)
    broadcast:AddRadioLine(RadioLine.new("<bzzt> ...Confirmaste el lugar?...", 0.72, 0.78, 0.68))
    broadcast:AddRadioLine(RadioLine.new("Si. El Banco de Louisville sigue cerrado desde la evacuacion.", 0.82, 0.82, 0.76))
    broadcast:AddRadioLine(RadioLine.new("Dicen que dejaron dinero, joyas y las piezas de la boveda privada.", 0.72, 0.78, 0.68))
    broadcast:AddRadioLine(RadioLine.new("Entraremos por la parte trasera. Nos vemos alli cuando oscurezca.", 0.82, 0.82, 0.76))
    broadcast:AddRadioLine(RadioLine.new("No llegues tarde. Esta es nuestra ultima oportunidad. <fzzt>", 0.72, 0.78, 0.68))
    return broadcast
end

local function isStoryHour(hour)
    return hour == 2 or hour == 8 or hour == 14 or hour == 20
end

function LastPurposeRadio.onEveryHours()
    if not LastPurposeRadio.channel then return end
    local gameTime = getGameTime()
    local hour = gameTime:getHour()
    local slot = math.floor(gameTime:getWorldAgeHours())
    if LastPurposeRadio.lastBroadcastSlot == slot then return end
    LastPurposeRadio.lastBroadcastSlot = slot
    if not isStoryHour(hour) then return end
    LastPurposeRadio.channel:setAiringBroadcast(createBroadcast(gameTime:getWorldAgeHours()))
end

Events.OnLoadRadioScripts.Add(LastPurposeRadio.onLoadRadioScripts)
Events.EveryHours.Add(LastPurposeRadio.onEveryHours)
