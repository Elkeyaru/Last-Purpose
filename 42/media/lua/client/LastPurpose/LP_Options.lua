-- ---------------------------------------------------------------------------
-- Panel de opciones del mod: Opciones -> Mods -> Last Purpose.
--
-- Desde la migracion a KeyasLib usa KeyasOptions.createPanel (envoltorio
-- fino y a prueba de doble registro sobre PZAPI.ModOptions de B42). Los IDs
-- de opcion ("toggleTracker", "debug") se conservan tal cual para no
-- huerfanar los ajustes guardados de los jugadores en modOptions.ini.
--
-- Es un archivo de cliente: Keyboard.* y la API de UI ya estan listas.
-- La tecla configurada se LEE siempre dentro de una funcion (getTrackerKey),
-- nunca como constante de nivel de archivo.
-- ---------------------------------------------------------------------------

require "PZAPI/ModOptions"
require "KeyasLib/KeyasOptions"

LastPurpose = LastPurpose or {}

local OPTIONS_ID = "LastPurpose"

-- Crea el panel via KeyasOptions. Idempotente: si KeyasOptions aun no
-- cargo (orden de carga), no pasa nada y refreshOptions lo reintenta en el
-- siguiente tick de un minuto.
local function build()
    if LastPurpose.optionsPanel then return end
    if not (KeyasOptions and KeyasOptions.createPanel) then return end

    local panel = KeyasOptions.createPanel(OPTIONS_ID, "Last Purpose", {
        keybind = {
            id = "toggleTracker",
            name = "Abrir / cerrar el diario",
            defaultKey = Keyboard.KEY_J,
            tooltip = "Tecla para mostrar u ocultar el diario del golpe.",
        },
    })
    if not panel then return end

    -- Titulo + casilla de depuracion propias del mod. La casilla usa el id
    -- "debug" historico y sincroniza LastPurpose.DEBUG (no KeyasLib.DEBUG),
    -- por eso se anade a mano y no con opts.addDebugTickbox.
    pcall(function() panel:addTitle("Last Purpose") end)
    pcall(function()
        panel:addTickBox("debug", "Registro de depuracion", false,
            "Escribe trazas detalladas de Last Purpose en la consola (console.txt).")
    end)

    LastPurpose.optionsPanel = panel
end

local ok, err = pcall(build)
if not ok then
    print("[LastPurpose] ERROR creando el panel de opciones: " .. tostring(err))
end

local function readOption(id)
    local panel = LastPurpose.optionsPanel
    if not panel or not panel.getOption then return nil end
    local option = panel:getOption(id)
    if not option then return nil end
    if option.getValue then
        local okValue, value = pcall(function() return option:getValue() end)
        if okValue then return value end
    end
    return option.value
end

-- Tecla configurada para el diario. Si el panel todavia no cargo o el valor
-- guardado no es utilizable, se cae a J (la tecla historica del mod).
function LastPurpose.getTrackerKey()
    local key = readOption("toggleTracker")
    if type(key) == "number" and key ~= 0 then
        return key
    end
    return Keyboard.KEY_J
end

-- Sincroniza LastPurpose.DEBUG con la casilla del panel. Se llama desde el
-- tick de un minuto y una vez al arrancar. Tambien reintenta build() por si
-- KeyasOptions cargo despues que este archivo.
function LastPurpose.refreshOptions()
    if not LastPurpose.optionsPanel then pcall(build) end
    local debug = readOption("debug")
    if type(debug) == "boolean" then
        LastPurpose.DEBUG = debug
    end
end

LastPurpose.refreshOptions()
