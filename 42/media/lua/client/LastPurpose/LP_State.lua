LastPurpose = LastPurpose or {}

function LastPurpose.getPlayerSafe(index)
    if index ~= nil then return getSpecificPlayer(index) end
    return getPlayer()
end

local function traitListContainsBurglar(list)
    if not list or not list.size or not list.get then return false end
    local ok, size = pcall(function() return list:size() end)
    if not ok then return false end
    for i = 0, size - 1 do
        local ok2, value = pcall(function() return list:get(i) end)
        if ok2 and value and string.find(string.lower(tostring(value)), "burglar", 1, true) then
            return true
        end
    end
    return false
end

-- B42 ha expuesto varias APIs distintas para leer la profesion/los rasgos de
-- un personaje segun el parche. Probamos todas en cascada y protegemos cada
-- una con pcall: si el motor cambia una firma, perdemos ese metodo de
-- deteccion, no la sesion completa.
function LastPurpose.isBurglar(player)
    if not player then return false end

    local ok, profession = pcall(function()
        local descriptor = player.getDescriptor and player:getDescriptor()
        return descriptor and descriptor.getProfession and descriptor:getProfession()
    end)
    if ok and profession and string.find(string.lower(tostring(profession)), "burglar", 1, true) then
        return true
    end

    local ok2, traits = pcall(function() return player.getCharacterTraits and player:getCharacterTraits() end)
    if ok2 and traits then
        local ok3, hasIt = pcall(function()
            return CharacterTrait and CharacterTrait.BURGLAR and traits:get(CharacterTrait.BURGLAR)
        end)
        if ok3 and hasIt then return true end

        local ok4, known = pcall(function() return traits.getKnownTraits and traits:getKnownTraits() end)
        if ok4 and traitListContainsBurglar(known) then return true end
    end

    local ok5, legacyTraits = pcall(function() return player.getTraits and player:getTraits() end)
    if ok5 and traitListContainsBurglar(legacyTraits) then return true end

    for _, id in ipairs({ "Burglar", "burglar", "base:burglar" }) do
        local ok6, hasIt = pcall(function() return player.HasTrait and player:HasTrait(id) end)
        if ok6 and hasIt then return true end
    end

    return false
end

-- Crea, normaliza y devuelve la tabla de progreso persistente del jugador.
-- No hay migracion de esquemas antiguos aqui a proposito: esta es una
-- reconstruccion desde cero, sin compromiso de compatibilidad con guardados
-- de las versiones anteriores del mod.
function LastPurpose.getData(player)
    local root = player:getModData()
    if type(root[LastPurpose.SAVE_KEY]) ~= "table" then
        root[LastPurpose.SAVE_KEY] = {
            schema = LastPurpose.SCHEMA,
            stage = "inactive",
            trackerVisible = true,
            objectives = {},
        }
    end
    local data = root[LastPurpose.SAVE_KEY]
    if type(data.stage) ~= "string" then data.stage = "inactive" end
    if data.trackerVisible == nil then data.trackerVisible = true end
    if type(data.objectives) ~= "table" then data.objectives = {} end
    data.schema = LastPurpose.SCHEMA
    return data
end

function LastPurpose.getDaysSurvived(player)
    if not player or not player.getHoursSurvived then return 0 end
    return math.max(0, player:getHoursSurvived() / 24)
end
