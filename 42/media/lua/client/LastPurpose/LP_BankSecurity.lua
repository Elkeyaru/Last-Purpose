require "ISUI/ISWorldObjectContextMenu"

LastPurpose = LastPurpose or {}

-- Funciones, no "local X = LastPurpose.World...." de nivel de archivo: el
-- motor puede ejecutar este archivo antes de que LP_Heists.lua (donde vive
-- LastPurpose.World) haya cargado. Al ser funciones, el valor solo se lee
-- cuando alguien las llama, mucho despues de que todo el mod ya cargo.
local function ANCHOR() return LastPurpose.World.BANK_SECURITY_ANCHOR end
local function PERIMETER() return LastPurpose.World.BANK_PERIMETER end
local ENFORCE_RADIUS = 70
local RESCAN_RADIUS = 120
local EARLY_ALARM_WINDOW_THRESHOLD = 2

local knownEntrances = {}

local function isEntrance(object)
    if instanceof(object, "IsoWindow") or instanceof(object, "IsoDoor") then return true end
    if not instanceof(object, "IsoThumpable") then return false end
    local ok, result = pcall(function() return object:isDoor() or object:isWindow() end)
    return ok and result == true
end

local function eachEntranceInPerimeter(callback)
    local count = 0
    for z = PERIMETER().minZ, PERIMETER().maxZ do
        for y = PERIMETER().minY, PERIMETER().maxY do
            for x = PERIMETER().minX, PERIMETER().maxX do
                local square = getCell():getGridSquare(x, y, z)
                local objects = square and square:getObjects()
                if objects then
                    for i = 0, objects:size() - 1 do
                        local object = objects:get(i)
                        if object and isEntrance(object) then
                            count = count + 1
                            callback(object)
                        end
                    end
                end
            end
        end
    end
    return count
end

local function protectEntrance(object)
    local md = object:getModData()
    -- Un cristal ya roto que no era nuestro no se "repara" al protegerlo.
    if instanceof(object, "IsoWindow") and object:isSmashed() and not md.LastPurposeBankProtected then return end

    if md.LastPurposeOriginalHealth == nil and object.getHealth then
        md.LastPurposeOriginalHealth = object:getHealth()
    end
    pcall(function() if object.setHealth then object:setHealth(100000) end end)
    pcall(function() if object.setIsLocked then object:setIsLocked(true) end end)
    pcall(function() if object.setLockedByKey then object:setLockedByKey(true) end end)
    pcall(function() if object.setPermaLocked then object:setPermaLocked(true) end end)
    md.LastPurposeBankProtected = true
    knownEntrances[object] = true
end

local function releaseEntrance(object)
    local md = object:getModData()
    if not md.LastPurposeBankProtected then return end
    if md.LastPurposeOriginalHealth and object.setHealth then object:setHealth(md.LastPurposeOriginalHealth) end
    pcall(function() if object.setPermaLocked then object:setPermaLocked(false) end end)
    pcall(function() if object.setLockedByKey then object:setLockedByKey(false) end end)
    pcall(function() if object.setIsLocked then object:setIsLocked(false) end end)
    md.LastPurposeBankProtected = false
    md.LastPurposeOriginalHealth = nil
end

local function shouldRemainProtected(player)
    if not player or not LastPurpose.isBurglar(player) then return false end
    local data = LastPurpose.getData(player)
    -- El perimetro queda sellado desde que se lee la nota hasta que el golpe
    -- arranca de verdad (heist_active). Antes se liberaba solo con que fuera
    -- de noche y el banco estuviera reconocido, aunque el jugador todavia no
    -- hubiera iniciado el golpe: eso dejaba puertas y ventanas abiertas en la
    -- franja entre "son las 20:00" y "el jugador llego al banco". Ahora tiene
    -- que llegar al banco dentro de la ventana nocturna para que la etapa
    -- pase a heist_active, y recien entonces se puede abrir o romper nada.
    return LastPurpose.stageBetween(data, "note_read", "heist_active")
end

function LastPurpose.enforceBankSecurity()
    local player = LastPurpose.getPlayerSafe(0)
    if not player then return end
    local dx, dy = player:getX() - ANCHOR().x, player:getY() - ANCHOR().y
    if dx * dx + dy * dy > ENFORCE_RADIUS * ENFORCE_RADIUS then return end

    if shouldRemainProtected(player) then
        for object in pairs(knownEntrances) do
            local square = object:getSquare()
            if square and getCell():getGridSquare(square:getX(), square:getY(), square:getZ()) == square then
                protectEntrance(object)
            else
                knownEntrances[object] = nil
            end
        end
        return
    end

    for object in pairs(knownEntrances) do releaseEntrance(object) end
    if not LastPurpose.isBurglar(player) then return end

    local data = LastPurpose.getData(player)
    if not LastPurpose.stageBetween(data, "bank_scouted", "loot_taken") then return end

    local smashed = tonumber(data.bankWindowsSmashed) or 0
    for object in pairs(knownEntrances) do
        if instanceof(object, "IsoWindow") then
            local ok, isSmashed = pcall(function() return object:isSmashed() end)
            if ok then
                local md = object:getModData()
                if isSmashed and md.LastPurposeWindowWasSmashed == false then smashed = smashed + 1 end
                md.LastPurposeWindowWasSmashed = isSmashed
            end
        end
    end
    data.bankWindowsSmashed = smashed

    if smashed > EARLY_ALARM_WINDOW_THRESHOLD and not data.ambushTriggered then
        data.ambushForced = true
        LastPurpose.heistEscapeActive = true
        print("[LastPurpose] Alarma anticipada: se rompieron mas de " .. EARLY_ALARM_WINDOW_THRESHOLD .. " cristales")
    end
end

function LastPurpose.isProtectedBankEntrance(player, object)
    if not player or not object or not shouldRemainProtected(player) then return false end
    local square = object:getSquare()
    if not square then return false end
    local x, y, z = square:getX(), square:getY(), square:getZ()
    return x >= PERIMETER().minX and x <= PERIMETER().maxX
        and y >= PERIMETER().minY and y <= PERIMETER().maxY
        and z >= PERIMETER().minZ and z <= PERIMETER().maxZ
        and isEntrance(object)
end

function LastPurpose.onWeaponHitBankObject(...)
    local player, object = nil, nil
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        if value and not player and instanceof(value, "IsoPlayer") then player = value end
        if value and not object and (instanceof(value, "IsoWindow") or instanceof(value, "IsoDoor") or instanceof(value, "IsoThumpable")) then
            object = value
        end
    end
    player = player or LastPurpose.getPlayerSafe(0)
    if not LastPurpose.isProtectedBankEntrance(player, object) then return end

    local wasProtected = object:getModData().LastPurposeBankProtected == true
    protectEntrance(object)
    if wasProtected and instanceof(object, "IsoWindow") then
        pcall(function()
            if object:isSmashed() then object:setSmashed(false) end
            local square = object:getSquare()
            if square then
                if square.RecalcProperties then square:RecalcProperties() end
                if square.RecalcAllWithNeighbours then square:RecalcAllWithNeighbours(true) end
            end
        end)
    end

    if not LastPurpose.bankWeaponWarningAt or getTimestampMs() - LastPurpose.bankWeaponWarningAt > 2500 then
        LastPurpose.bankWeaponWarningAt = getTimestampMs()
        LastPurpose.showThought(player, { "No puedo forzar la entrada ahora.", "La alarma atraeria a medio Louisville." })
    end
    return false
end

if not LastPurpose.bankSmashHookInstalled then
    LastPurpose.bankSmashHookInstalled = true
    local originalSmashWindow = ISWorldObjectContextMenu.onSmashWindow
    ISWorldObjectContextMenu.onSmashWindow = function(worldobjects, window, playerIndex)
        local player = getSpecificPlayer(playerIndex)
        if LastPurpose.isProtectedBankEntrance(player, window) then
            LastPurpose.showThought(player, { "Seria problematico activar la alarma", "si rompo el cristal ahora." })
            protectEntrance(window)
            return
        end
        return originalSmashWindow(worldobjects, window, playerIndex)
    end
end

function LastPurpose.updateBankSecurity()
    local player = LastPurpose.getPlayerSafe(0)
    if not player then return end
    local dx, dy = player:getX() - ANCHOR().x, player:getY() - ANCHOR().y
    if dx * dx + dy * dy > RESCAN_RADIUS * RESCAN_RADIUS then
        knownEntrances = {}
        return
    end

    local data = LastPurpose.getData(player)
    local windowOpen = not shouldRemainProtected(player)

    -- Se reconstruye siempre, incluso de noche: la cache Lua se pierde al
    -- cargar una partida guardada.
    knownEntrances = {}
    local count = eachEntranceInPerimeter(function(object)
        knownEntrances[object] = true
        local md = object:getModData()
        if instanceof(object, "IsoWindow") and md.LastPurposeWindowWasSmashed == nil then
            md.LastPurposeWindowWasSmashed = object:isSmashed()
        end
        if windowOpen then releaseEntrance(object) else protectEntrance(object) end
    end)

    if count == 0 then
        if not data.bankSecurityMissingLogged then
            data.bankSecurityMissingLogged = true
            print("[LastPurpose] AVISO: el edificio del Knox Bank aun no esta cargado")
        end
        return
    elseif not windowOpen and data.bankSecurityObjectCount ~= count then
        data.bankSecurityObjectCount = count
        data.bankSecurityMissingLogged = false
        LastPurpose.debugPrint(string.format("Knox Bank protegido: %d puertas y ventanas", count))
    end

    if not windowOpen then
        local ddx, ddy = player:getX() - ANCHOR().x, player:getY() - ANCHOR().y
        if ddx * ddx + ddy * ddy < 55 * 55 and not data.bankSecurityThoughtShown then
            data.bankSecurityThoughtShown = true
            LastPurpose.showThought(player, { "Seria problematico activar la alarma", "si rompo el cristal ahora." })
        end
    end
end
