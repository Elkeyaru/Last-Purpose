LastPurpose = LastPurpose or {}
LastPurpose.RADIO_FREQUENCY_KEY = "LastPurposeRadioFrequency"
LastPurpose.RADIO_CANDIDATES_KEY = "LastPurposeRadioCandidates"

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
    if data.completed and data.stage < 3 then
        LastPurpose.ensureSelectedHeist(player)
        data.stage = 3
        data.radioPromptShown = true
        LastPurpose.showThought(player, {
            "Mmm... debería revisar la radio.",
            "Quizás encuentre más información."
        })
    end
end

function LastPurpose.onDeviceText(guid, interactCodes, x, y, z, line)
    local player = LastPurpose.getPlayerSafe(0)
    if not player or not LastPurpose.isBurglar(player) then return end
    local data = LastPurpose.getData(player)
    if data.stage ~= 3 or type(line) ~= "string" then return end
    local heist = LastPurpose.ensureSelectedHeist(player)
    if not heist or string.find(line, heist.finalLine, 1, true) == nil then return end

    data.stage = 4
    data.storyFlowVersion = data.storyFlowVersion or 2
    data.radioTransmissionHeard = true
    data.radioHeardAtHours = player:getHoursSurvived()
    LastPurpose.radioReactionAt = getTimestampMs() + 5000
end

function LastPurpose.updatePendingRadioReaction()
    if not LastPurpose.radioReactionAt or getTimestampMs() < LastPurpose.radioReactionAt then return end
    LastPurpose.radioReactionAt = nil
    local player = LastPurpose.getPlayerSafe(0)
    if not player then return end
    LastPurpose.showThought(player, {
        "Así que van tras ese botín...",
        "Primero encontraré ese punto de reunión."
    })
end
