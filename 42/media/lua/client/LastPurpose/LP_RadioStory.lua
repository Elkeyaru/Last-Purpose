LastPurpose = LastPurpose or {}
LastPurpose.RADIO_FREQUENCY_KEY = "LastPurposeRadioFrequency"
LastPurpose.RADIO_CANDIDATES_KEY = "LastPurposeRadioCandidates"
LastPurpose.RADIO_REACTION_DELAY_MS = 5000

function LastPurpose.getStoryFrequency()
    local value = getGameTime():getModData()[LastPurpose.RADIO_FREQUENCY_KEY]
    return type(value) == "number" and value or nil
end

function LastPurpose.getStoryFrequencyCandidates()
    local values = getGameTime():getModData()[LastPurpose.RADIO_CANDIDATES_KEY]
    return type(values) == "table" and values or nil
end

function LastPurpose.updateRadioStory(player)
    if not player or not LastPurpose.isBurglar(player) then return end
    local data = LastPurpose.getData(player)
    if not LastPurpose.stageIs(data, "prep_completed") then return end

    LastPurpose.ensureSelectedHeist(player)
    LastPurpose.setStage(data, "radio_prompted")
    data.radioPromptShown = true
    LastPurpose.showThought(player, {
        "Mmm... deberia revisar la radio.",
        "Quizas encuentre mas informacion.",
    })
end

function LastPurpose.onDeviceText(guid, interactCodes, x, y, z, line)
    if type(line) ~= "string" then return end
    local player = LastPurpose.getPlayerSafe(0)
    if not player or not LastPurpose.isBurglar(player) then return end
    local data = LastPurpose.getData(player)
    if not LastPurpose.stageIs(data, "radio_prompted") then return end

    local heist = LastPurpose.ensureSelectedHeist(player)
    if not heist or type(heist.finalLine) ~= "string" then return end

    -- Busqueda en modo texto plano (el "true" final) para que un caracter
    -- especial del dialogo no rompa el patron.
    local ok, found = pcall(string.find, line, heist.finalLine, 1, true)
    if not ok or not found then return end

    LastPurpose.setStage(data, "radio_heard")
    data.radioTransmissionHeard = true
    data.radioHeardAtHours = player:getHoursSurvived()
    LastPurpose.radioReactionAt = getTimestampMs() + LastPurpose.RADIO_REACTION_DELAY_MS
end

function LastPurpose.updatePendingRadioReaction()
    if not LastPurpose.radioReactionAt or getTimestampMs() < LastPurpose.radioReactionAt then return end
    LastPurpose.radioReactionAt = nil
    local player = LastPurpose.getPlayerSafe(0)
    if not player then return end
    LastPurpose.showThought(player, {
        "Asi que van tras ese botin...",
        "Primero encontrare ese punto de reunion.",
    })
end
