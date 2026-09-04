LastPurposeRadio = LastPurposeRadio or {}
require "LastPurpose/LP_Heists"
LastPurposeRadio.UUID = "LP-HEIST-001"
LastPurposeRadio.MODDATA_KEY = "LastPurposeRadioFrequency"
LastPurposeRadio.CANDIDATES_KEY = "LastPurposeRadioCandidates"
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

local function validCandidateList(list, occupied, selected)
    if type(list) ~= "table" or #list ~= 10 then return false end
    local seen, containsSelected = {}, false
    for _, frequency in ipairs(list) do
        if not isValidFrequency(frequency) or seen[frequency] then return false end
        if occupied[frequency] and frequency ~= selected then return false end
        seen[frequency] = true
        if frequency == selected then containsSelected = true end
    end
    return containsSelected
end

local function createCandidateList(occupied, selected)
    local pool = {}
    for frequency = LastPurposeRadio.MIN_FREQUENCY, LastPurposeRadio.MAX_FREQUENCY, LastPurposeRadio.FREQUENCY_STEP do
        if frequency ~= selected and not occupied[frequency] then pool[#pool + 1] = frequency end
    end
    local list = { selected }
    while #list < 10 and #pool > 0 do
        local index = ZombRand(#pool) + 1
        list[#list + 1] = table.remove(pool, index)
    end
    for index = #list, 2, -1 do
        local target = ZombRand(index) + 1
        list[index], list[target] = list[target], list[index]
    end
    return list
end

function LastPurposeRadio.onLoadRadioScripts(scriptManager)
    local frequency = getFrequency(scriptManager)
    if not frequency then
        print("[LastPurpose] ERROR: no hay frecuencias de radio disponibles entre 88.0 y 108.0 MHz")
        return
    end
    local worldData = getGameTime():getModData()
    local occupied = getOccupiedFrequencies(scriptManager)
    local candidates = worldData[LastPurposeRadio.CANDIDATES_KEY]
    if not validCandidateList(candidates, occupied, frequency) then
        candidates = createCandidateList(occupied, frequency)
        worldData[LastPurposeRadio.CANDIDATES_KEY] = candidates
    end
    local channel = DynamicRadioChannel.new("Senal desconocida", frequency, ChannelCategory.Bandit, LastPurposeRadio.UUID)
    scriptManager:AddChannel(channel, false)
    LastPurposeRadio.channel = channel
    print("[LastPurpose] Canal narrativo registrado en " .. tostring(frequency / 1000) .. " MHz")
end

local function createBroadcast(worldAgeHours)
    local broadcast = RadioBroadCast.new("LP-HEIST-" .. tostring(math.floor(worldAgeHours * 2)), -1, -1)
    local selected = getGameTime():getModData().LastPurposeSelectedHeist
    local heist = LastPurpose.getHeist(selected) or LastPurpose.getHeist(LastPurpose.HEIST_ORDER[1])
    for index, text in ipairs(heist.dialogue) do
        local color = index % 2 == 0 and {0.82, 0.82, 0.76} or {0.72, 0.78, 0.68}
        broadcast:AddRadioLine(RadioLine.new(text, color[1], color[2], color[3]))
    end
    return broadcast
end

function LastPurposeRadio.onEveryTenMinutes()
    if not LastPurposeRadio.channel then return end
    local gameTime = getGameTime()
    local slot = math.floor(gameTime:getWorldAgeHours() * 2)
    if LastPurposeRadio.lastBroadcastSlot == slot then return end
    LastPurposeRadio.lastBroadcastSlot = slot
    LastPurposeRadio.channel:setAiringBroadcast(createBroadcast(gameTime:getWorldAgeHours()))
end

Events.OnLoadRadioScripts.Add(LastPurposeRadio.onLoadRadioScripts)
Events.EveryTenMinutes.Add(LastPurposeRadio.onEveryTenMinutes)
