require "ISUI/ISWorldObjectContextMenu"
require "TimedActions/ISSmashWindow"
require "TimedActions/ISOpenCloseDoor"
require "TimedActions/ISClimbThroughWindow"
require "TimedActions/ISDestroyStuffAction"

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

local function recalcSquareOf(object)
    local square = object:getSquare()
    if not square then return end
    pcall(function()
        if square.RecalcProperties then square:RecalcProperties() end
        if square.RecalcAllWithNeighbours then square:RecalcAllWithNeighbours(true) end
    end)
end

-- Des-rompe una entrada nuestra que se haya roto pese al bloqueo. El combate
-- directo contra el cristal y los zombis no pasan por ninguna accion Lua, asi
-- que la unica via fiable desde el mod es revertir el estado en el siguiente
-- tick de enforce. Solo actua sobre objetos que YA marcamos como protegidos
-- (LastPurposeBankProtected), nunca sobre daño preexistente ajeno.
local RESTORE_COOLDOWN_MS = 300

function LastPurpose.restoreEntranceIfBroken(object)
    local md = object:getModData()
    if not md.LastPurposeBankProtected then return end

    -- Limita la reconstruccion a ~3 por segundo por objeto: bajo pounding
    -- continuo de zombis, un setSmashed(false)+recalc en cada tick de OnTick
    -- puede causar parpadeo e inestabilidad de render (ver CHANGELOG 0.7.1).
    local now = getTimestampMs()
    if md.LastPurposeRestoredAt and now - md.LastPurposeRestoredAt < RESTORE_COOLDOWN_MS then return end

    local changed = false

    if instanceof(object, "IsoWindow") then
        local ok, smashed = pcall(function() return object:isSmashed() end)
        if ok and smashed then
            local okGlass, glassGone = pcall(function() return object:isGlassRemoved() end)
            if okGlass and glassGone then
                -- El cristal ya no existe: setSmashed(false) no lo reconstruye.
                -- Se registra una vez para no spamear.
                if not md.LastPurposeGlassLostLogged then
                    md.LastPurposeGlassLostLogged = true
                    print("[LastPurpose] AVISO: un cristal protegido del banco perdio el vidrio y no se pudo restaurar")
                end
            else
                pcall(function() object:setSmashed(false) end)
                md.LastPurposeWindowWasSmashed = false
                changed = true
            end
        end
    elseif instanceof(object, "IsoThumpable") then
        local ok, smashed = pcall(function() return object.isSmashed and object:isSmashed() end)
        if ok and smashed then
            pcall(function() object:setSmashed(false) end)
            changed = true
        end
    end

    if changed then
        md.LastPurposeRestoredAt = now
        pcall(function() if object.setHealth then object:setHealth(100000) end end)
        recalcSquareOf(object)
    end
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

    -- Tras marcarlo como protegido, revertir cualquier rotura que ya haya
    -- ocurrido (combate directo, zombis). Se llama tanto desde el tick de
    -- enforce como desde la reconstruccion por minuto.
    LastPurpose.restoreEntranceIfBroken(object)
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
    md.LastPurposeRestoredAt = nil
    md.LastPurposeGlassLostLogged = nil
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

-- ---------------------------------------------------------------------------
-- Bloqueo real de las acciones que vulneran una entrada.
--
-- setHealth()/setIsLocked() NO frena todas las vias en Build 42: romper un
-- cristal a mano llama directo a IsoPlayer:smashWindow() sin mirar la salud
-- del objeto; un Ladron puede forzar cerraduras; el mazo pasa por
-- ISDestroyStuffAction. En vez de tapar cada via por separado, se envuelve el
-- isValid() de cada accion cronometrada relevante: si el objetivo es una
-- entrada protegida del banco, la accion se rechaza ANTES de arrancar, venga
-- del menu contextual, de una tecla o del prompt en pantalla. Es una sola
-- envoltura idempotente por clase (flag LastPurposeSealGuard).
-- ---------------------------------------------------------------------------
local GUARDED_ACTIONS = {
    { class = "ISSmashWindow",        field = "window" },
    { class = "ISOpenCloseDoor",      field = "item" },
    { class = "ISClimbThroughWindow", field = "item" },
    { class = "ISDestroyStuffAction", field = "item" },
}

local function warnBankSealed(player)
    if not player then return end
    if not LastPurpose.bankWeaponWarningAt or getTimestampMs() - LastPurpose.bankWeaponWarningAt > 2500 then
        LastPurpose.bankWeaponWarningAt = getTimestampMs()
        LastPurpose.showThought(player, { "El banco sigue cerrado.", "Tengo que esperar a la hora del golpe." })
    end
end

function LastPurpose.installBankActionGuards()
    for _, spec in ipairs(GUARDED_ACTIONS) do
        local class = _G[spec.class]
        if class and not class.LastPurposeSealGuard then
            local originalIsValid = class.isValid
            class.isValid = function(self)
                local target = self[spec.field]
                local actor = self.character or LastPurpose.getPlayerSafe(0)
                local ok, blocked = pcall(LastPurpose.isProtectedBankEntrance, actor, target)
                if ok and blocked then
                    warnBankSealed(actor)
                    return false
                end
                if originalIsValid then return originalIsValid(self) end
                return true
            end
            class.LastPurposeSealGuard = true
            LastPurpose.debugPrint("Guardia de accion instalada sobre " .. spec.class)
        end
    end
end

LastPurpose.installBankActionGuards()

function LastPurpose.updateBankSecurity()
    -- Por si el motor cargo alguna de las clases de accion despues que este
    -- archivo; es idempotente y barato (solo instala lo que falte). Va antes
    -- del corte por distancia para que las guardias queden puestas aunque el
    -- jugador todavia no se haya acercado nunca al banco.
    LastPurpose.installBankActionGuards()

    local player = LastPurpose.getPlayerSafe(0)
    if not player then return end
    local dx, dy = player:getX() - ANCHOR().x, player:getY() - ANCHOR().y
    if dx * dx + dy * dy > RESCAN_RADIUS * RESCAN_RADIUS then
        knownEntrances = {}
        return
    end

    local data = LastPurpose.getData(player)
    local windowOpen = not shouldRemainProtected(player)

    if data.bankSecurityLoggedStage ~= data.stage then
        data.bankSecurityLoggedStage = data.stage
        LastPurpose.debugPrint(string.format(
            "Seguridad del banco: etapa=%s ladron=%s sellado=%s",
            tostring(data.stage), tostring(LastPurpose.isBurglar(player)), tostring(not windowOpen)))
    end

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
        LastPurpose.debugPrint(string.format(
            "Knox Bank sellado: %d puertas y ventanas protegidas (etapa %s)", count, tostring(data.stage)))
    end

    if not windowOpen then
        local ddx, ddy = player:getX() - ANCHOR().x, player:getY() - ANCHOR().y
        if ddx * ddx + ddy * ddy < 55 * 55 and not data.bankSecurityThoughtShown then
            data.bankSecurityThoughtShown = true
            LastPurpose.showThought(player, { "Seria problematico activar la alarma", "si rompo el cristal ahora." })
        end
    end
end
