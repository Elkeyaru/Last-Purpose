-- ---------------------------------------------------------------------------
-- LP_Unlocks.lua - Hito 2 del hub del ordenador.
--
-- Mantiene el estado que alimenta LastPurpose.heistStatus (definido en el
-- LP_Heists.lua compartido):
--   * data.citiesVisited[<CITY>]  - se marca al entrar al bbox de una ciudad.
--   * data.completedHeists[<id>]  - se marca cuando el golpe llega a "completed".
--   * data.activeHeistId          - el golpe en curso (uno a la vez).
--
-- Archivo de cliente: se ejecuta una vez por minuto desde LP_Main.
-- ---------------------------------------------------------------------------

LastPurpose = LastPurpose or {}

function LastPurpose.updateHubUnlocks(player)
    player = player or LastPurpose.getPlayerSafe(0)
    if not player or not LastPurpose.isBurglar(player) then return end
    local data = LastPurpose.getData(player)

    -- Ciudad visitada -> desbloquea el gate "cityKnown" de esa ciudad.
    local okPos, x, y = pcall(function()
        return math.floor(player:getX()), math.floor(player:getY())
    end)
    if okPos and x and LastPurpose.cityOf then
        local key = LastPurpose.cityOf(x, y)
        if key then
            data.citiesVisited = data.citiesVisited or {}
            if not data.citiesVisited[key] then
                data.citiesVisited[key] = true
                LastPurpose.debugPrint("Ciudad visitada: " .. tostring(key))
                if HaloTextHelper and LastPurpose.CITIES[key] then
                    HaloTextHelper.addTextWithArrow(player,
                        "Zona reconocida: " .. LastPurpose.CITIES[key].label, true, 100, 190, 255)
                end
            end
        end
    end

    -- Golpe en curso / archivado. Con una sola maquina de etapas (data.stage)
    -- solo hay un golpe activo a la vez: el de data.selectedHeist.
    local sel = data.selectedHeist
    if sel then
        if LastPurpose.stageIs(data, "completed") then
            data.completedHeists = data.completedHeists or {}
            if not data.completedHeists[sel] then
                data.completedHeists[sel] = true
                LastPurpose.debugPrint("Golpe archivado: " .. tostring(sel))
            end
            data.activeHeistId = nil
        elseif data.stage and data.stage ~= "inactive" then
            data.activeHeistId = sel
        end
    end
end
