LastPurpose = LastPurpose or {}
LastPurpose.RADIO_FREQUENCY_KEY = "LastPurposeRadioFrequency"

function LastPurpose.getStoryFrequency()
    local value = getGameTime():getModData()[LastPurpose.RADIO_FREQUENCY_KEY]
    return type(value) == "number" and value or nil
end

function LastPurpose.updateRadioStory(player)
    if not player or not LastPurpose.isBurglar(player) then return end
    local data = LastPurpose.getData(player)
    if data.completed and data.stage < 3 then
        data.stage = 3
        data.radioPromptShown = true
        LastPurpose.showThought(player, {
            "Mmm... deberia revisar la radio.",
            "Quizas encuentre mas informacion."
        })
    end
end

function LastPurpose.onDeviceText(guid, interactCodes, x, y, z, line)
    local player = LastPurpose.getPlayerSafe(0)
    if not player or not LastPurpose.isBurglar(player) then return end
    local data = LastPurpose.getData(player)
    if data.stage ~= 3 or type(line) ~= "string" then return end
    if string.find(line, "Esta es nuestra ultima oportunidad", 1, true) == nil then return end

    data.stage = 4
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
        "Asi que van tras ese botin...",
        "Ese golpe sera mio."
    })
end
