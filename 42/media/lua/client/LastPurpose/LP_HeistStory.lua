require "ISUI/Maps/ISWorldMap"
require "ISUI/Maps/ISMap"

LastPurpose = LastPurpose or {}

local MAP_REVEAL_RADIUS = 18
local MAP_ICON_SIZE = 36
local MAP_ZOOM = 18.0

local function getMapTarget(data, heist)
    if LastPurpose.stageAtLeast(data, "returning") then
        if data.safehousePlaced and data.safehouseX and data.safehouseY then
            return data.safehouseX, data.safehouseY, "REFUGIO", "safehouse"
        end
        return nil
    end

    if LastPurpose.stageIs(data, "radio_heard") or LastPurpose.stageIs(data, "clue_found") then
        local clue = LastPurpose.getHeistClue(data, heist)
        if clue then return clue.x, clue.y, "PISTA", "clue" end
    end

    return heist.x, heist.y, "OBJETIVO", "heist"
end

-- Elige un golpe una unica vez por partida y lo comparte via ModData del
-- mundo para que el servidor de radio pueda leer el mismo dialogo.
function LastPurpose.ensureSelectedHeist(player)
    local data = LastPurpose.getData(player)
    if not LastPurpose.getHeist(data.selectedHeist) then
        data.selectedHeist = LastPurpose.chooseHeistId()
    end
    if data.selectedHeist then
        getGameTime():getModData().LastPurposeSelectedHeist = data.selectedHeist
    end
    return LastPurpose.getHeist(data.selectedHeist)
end

function LastPurpose.tryAddHeistMapMarker(player)
    if not player then return end
    local data = LastPurpose.getData(player)
    if LastPurpose.stageBefore(data, "radio_heard") then return end
    local heist = LastPurpose.ensureSelectedHeist(player)
    if not heist then return end

    local targetX, targetY, _, targetKey = getMapTarget(data, heist)
    if not targetX then return end

    local revealKey = "mapAreaRevealed_" .. tostring(targetKey or "heist")
    if not data[revealKey] then
        WorldMapVisited.getInstance():setKnownInSquares(
            targetX - MAP_REVEAL_RADIUS, targetY - MAP_REVEAL_RADIUS,
            targetX + MAP_REVEAL_RADIUS, targetY + MAP_REVEAL_RADIUS
        )
        data[revealKey] = true
        LastPurpose.debugPrint(targetKey == "safehouse"
            and "Sector del refugio revelado en el mapa"
            or "Sector del objetivo revelado en el mapa")
    end

    data.mapMarkerX = targetX
    data.mapMarkerY = targetY
end

function LastPurpose.renderHeistMapMarker(mapUI)
    local player = LastPurpose.getPlayerSafe(0)
    if not player or not LastPurpose.isBurglar(player) then return end
    local data = LastPurpose.getData(player)
    if LastPurpose.stageBefore(data, "radio_heard") then return end
    local heist = LastPurpose.ensureSelectedHeist(player)
    if not heist or not mapUI.mapAPI then return end

    local targetX, targetY, label, targetKey = getMapTarget(data, heist)
    if not targetX then return end

    local centeredKey = targetKey == "safehouse" and "safehouseMapCenteredOnce" or "mapCenteredOnce"
    if not data[centeredKey] then
        mapUI.mapAPI:centerOn(targetX, targetY)
        mapUI.mapAPI:setZoom(MAP_ZOOM)
        data[centeredKey] = true
    end

    local uiX = mapUI.mapAPI:worldToUIX(targetX, targetY)
    local uiY = mapUI.mapAPI:worldToUIY(targetX, targetY)
    if uiX < 0 or uiY < 0 or uiX > mapUI.width or uiY > mapUI.height then return end

    local texture = getTexture("media/ui/LootableMaps/map_x.png")
    if texture then
        local half = MAP_ICON_SIZE / 2
        mapUI:drawTextureScaledAspect(texture, uiX - half, uiY - half, MAP_ICON_SIZE, MAP_ICON_SIZE, 1.0, 0.18, 0.48, 0.95)
    end
    mapUI:drawTextCentre(label, uiX, uiY - 35, 0.25, 0.58, 1.0, 1.0, UIFont.Small)
end

if not LastPurpose.worldMapRenderPatched then
    LastPurpose.originalWorldMapRender = ISWorldMap.render
    function ISWorldMap:render()
        LastPurpose.originalWorldMapRender(self)
        local ok, err = pcall(LastPurpose.renderHeistMapMarker, self)
        if not ok then print("[LastPurpose] ERROR dibujando el marcador del mapa: " .. tostring(err)) end
    end
    LastPurpose.worldMapRenderPatched = true
end

function LastPurpose.updateHeistMapAndArrival()
    local player = LastPurpose.getPlayerSafe(0)
    if not player or not LastPurpose.isBurglar(player) then return end
    LastPurpose.tryAddHeistMapMarker(player)
end
