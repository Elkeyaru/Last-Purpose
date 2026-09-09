require "ISUI/ISWorldObjectContextMenu"
-- Se cargan aqui para garantizar que las clases esten en _G antes de que
-- KeyasZones intente envolver su isValid().
require "TimedActions/ISSmashWindow"
require "TimedActions/ISOpenCloseDoor"
require "TimedActions/ISClimbThroughWindow"
require "TimedActions/ISDestroyStuffAction"
require "KeyasLib/KeyasZones"

-- ---------------------------------------------------------------------------
-- Sellado del Knox Bank durante la ventana de preparacion.
--
-- Desde la migracion a KeyasLib el trabajo generico -bloquear las acciones
-- cronometradas que abren/rompen/destruyen una entrada, y revertir el daño
-- que no pasa por una accion Lua (combate directo, zombis)- lo hace
-- KeyasZones. Este archivo se queda con lo especifico del banco:
--   * cerrojo real de puertas/ventanas (setIsLocked/PermaLocked) y guardar
--     su salud original para restaurarla al liberar el perimetro,
--   * el contador de cristales rotos tras iniciar el golpe -> alarma
--     anticipada,
--   * los pensamientos del jugador al acercarse con el banco sellado.
--
-- Nada de "local X = LastPurpose.World.*" a nivel de archivo: el motor puede
-- ejecutar este archivo antes de que LP_Heists.lua cargue. Todo se lee
-- dentro de funciones.
-- ---------------------------------------------------------------------------

LastPurpose = LastPurpose or {}

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

-- El perimetro queda sellado desde que se lee la nota hasta que el golpe
-- arranca de verdad (heist_active).
local function shouldRemainProtected(player)
    if not player or not LastPurpose.isBurglar(player) then return false end
    local data = LastPurpose.getData(player)
    return LastPurpose.stageBetween(data, "note_read", "heist_active")
end

-- ---- zona KeyasLib: bloqueo de acciones + reversion de roturas ----------
-- Se registra una sola vez. `active` se consulta en cada comprobacion, asi
-- que abrir/cerrar el sello es solo cambiar de etapa. KeyasZones se encarga
-- de: envolver isValid() en ISSmashWindow/ISOpenCloseDoor/ISClimbThroughWindow
-- /ISDestroyStuffAction, y de un barrido que revierte roturas por combate
-- directo o zombis (ver KeyasLib MIGRATION.md seccion 2).
local function ensureBankZone()
    if LastPurpose._bankZoneRegistered then return end
    if not (KeyasZones and KeyasZones.register) then return end
    local p = PERIMETER()
    if not p then return end
    local ok = KeyasZones.register("knox_bank_seal", {
        bbox = { minX = p.minX, maxX = p.maxX, minY = p.minY, maxY = p.maxY, minZ = p.minZ, maxZ = p.maxZ },
        active = function()
            return shouldRemainProtected(LastPurpose.getPlayerSafe(0))
        end,
        warn = function(player)
            LastPurpose.showThought(player, {
                "El banco sigue cerrado.",
                "Tengo que esperar a la hora del golpe.",
            })
        end,
    })
    if ok then
        LastPurpose._bankZoneRegistered = true
        LastPurpose.debugPrint("Zona KeyasZones 'knox_bank_seal' registrada")
    end
end

-- ---- cerrojo + salud (especifico del banco; KeyasZones no cierra) -------

local function protectEntrance(object)
    local md = object:getModData()
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
    md.LastPurposeGlassLostLogged = nil
end

-- Sigue existiendo para el hook del menu contextual y para el conteo de
-- cristales: dice si `object` es una entrada del perimetro que debe estar
-- sellada ahora mismo.
function LastPurpose.isProtectedBankEntrance(player, object)
    if not player or not object or not shouldRemainProtected(player) then return false end
    local square = object:getSquare()
    if not square then return false end
    local x, y, z = square:getX(), square:getY(), square:getZ()
    local p = PERIMETER()
    return x >= p.minX and x <= p.maxX
        and y >= p.minY and y <= p.maxY
        and z >= p.minZ and z <= p.maxZ
        and isEntrance(object)
end

-- ---- eventos ----------------------------------------------------------

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

    -- Sello YA abierto: contar cristales rotos para la alarma anticipada.
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

-- Redundante con la guardia isValid de KeyasZones sobre ISSmashWindow, pero
-- barato y da un pensamiento propio: se deja como cinturon y tirantes.
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
    ensureBankZone()

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
