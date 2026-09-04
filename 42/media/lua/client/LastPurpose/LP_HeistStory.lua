require "ISUI/Maps/ISWorldMap"
require "ISUI/Maps/ISMap"

LastPurpose = LastPurpose or {}

local function getMapTarget(data, heist)
    if data.stage >= 7 then
        if data.safehousePlaced and data.safehouseX and data.safehouseY then
            return data.safehouseX, data.safehouseY, "REFUGIO", true
        end
        return nil
    end
    return heist.x, heist.y, "OBJETIVO", false
end

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
    if data.stage < 4 then return end
    local heist = LastPurpose.ensureSelectedHeist(player)
    if not heist then return end
    local targetX, targetY, _, isSafehouse = getMapTarget(data, heist)
    if not targetX then return end

    local revealed = isSafehouse and data.safehouseAreaRevealed or data.mapAreaRevealed
    if not revealed then
        local revealRadius = 18
        WorldMapVisited.getInstance():setKnownInSquares(
            targetX - revealRadius,
            targetY - revealRadius,
            targetX + revealRadius,
            targetY + revealRadius
        )
        if isSafehouse then data.safehouseAreaRevealed = true
        else data.mapAreaRevealed = true end
        print(isSafehouse and "[LastPurpose] Sector del refugio revelado en el mapa" or "[LastPurpose] Sector del golpe revelado en el mapa")
    end

    data.mapMarkerX = targetX
    data.mapMarkerY = targetY
end

function LastPurpose.renderHeistMapMarker(mapUI)
    local player = LastPurpose.getPlayerSafe(0)
    if not player or not LastPurpose.isBurglar(player) then return end
    local data = LastPurpose.getData(player)
    if data.stage < 4 then return end
    local heist = LastPurpose.ensureSelectedHeist(player)
    if not heist or not mapUI.mapAPI then return end
    local targetX, targetY, label, isSafehouse = getMapTarget(data, heist)
    if not targetX then return end
    local centeredKey = isSafehouse and "safehouseMapCenteredOnce" or "mapCenteredOnce"

    if not data[centeredKey] then
        mapUI.mapAPI:centerOn(targetX, targetY)
        mapUI.mapAPI:setZoom(18.0)
        data[centeredKey] = true
    end

    local uiX = mapUI.mapAPI:worldToUIX(targetX, targetY)
    local uiY = mapUI.mapAPI:worldToUIY(targetX, targetY)
    if uiX < 0 or uiY < 0 or uiX > mapUI.width or uiY > mapUI.height then return end
    local texture = getTexture("media/ui/LootableMaps/map_x.png")
    if texture then
        mapUI:drawTextureScaledAspect(texture, uiX - 18, uiY - 18, 36, 36, 1.0, 0.18, 0.48, 0.95)
    end
    mapUI:drawTextCentre(label, uiX, uiY - 35, 0.25, 0.58, 1.0, 1.0, UIFont.Small)
end

if not LastPurpose.worldMapRenderPatched then
    LastPurpose.originalWorldMapRender = ISWorldMap.render
    function ISWorldMap:render()
        LastPurpose.originalWorldMapRender(self)
        LastPurpose.renderHeistMapMarker(self)
    end
    LastPurpose.worldMapRenderPatched = true
end

function LastPurpose.updateHeistArrival(player)
    if not player then return end
    local data = LastPurpose.getData(player)
    if data.stage ~= 4 then return end
    local heist = LastPurpose.ensureSelectedHeist(player)
    if not heist then return end
    local dx = player:getX() - heist.x
    local dy = player:getY() - heist.y
    if (dx * dx) + (dy * dy) > (heist.arrivalRadius * heist.arrivalRadius) then return end
    data.stage = 5
    data.heistLocationReached = true
    data.heistReachedAtHours = player:getHoursSurvived()
    LastPurpose.showThought(player, {
        "Este es el lugar...",
        "Ahora tengo que encontrar el botin."
    })
end

function LastPurpose.updateHeistMapAndArrival()
    local player = LastPurpose.getPlayerSafe(0)
    if not player or not LastPurpose.isBurglar(player) then return end
    LastPurpose.tryAddHeistMapMarker(player)
end
