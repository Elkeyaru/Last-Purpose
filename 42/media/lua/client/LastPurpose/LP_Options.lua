-- ---------------------------------------------------------------------------
-- Panel de opciones del mod: Opciones -> Mods -> Last Purpose.
--
-- Usa la API nativa PZAPI.ModOptions de Build 42 (client/PZAPI/ModOptions.lua),
-- sin depender de ningun mod externo. El menu de opciones lo muestra solo en
-- cuanto hay al menos un panel registrado.
--
-- Es un archivo de cliente: Keyboard.* y la API de UI ya estan listas cuando
-- carga. La tecla configurada se LEE siempre dentro de una funcion
-- (getTrackerKey), nunca como constante de nivel de archivo.
-- ---------------------------------------------------------------------------

require "PZAPI/ModOptions"

LastPurpose = LastPurpose or {}

local OPTIONS_ID = "LastPurpose"

local function build()
    if not PZAPI or not PZAPI.ModOptions then return end
    -- No registrar dos veces si el archivo se recarga en la misma sesion.
    if PZAPI.ModOptions.Dict and PZAPI.ModOptions.Dict[OPTIONS_ID] then
        LastPurpose.optionsPanel = PZAPI.ModOptions.Dict[OPTIONS_ID]
        return
    end

    local opt = PZAPI.ModOptions:create(OPTIONS_ID, "Last Purpose")
    opt:addTitle("Last Purpose")
    opt:addKeyBind("toggleTracker", "Abrir / cerrar el diario", Keyboard.KEY_J,
        "Tecla para mostrar u ocultar el diario del golpe.")
    opt:addTickBox("debug", "Registro de depuracion", false,
        "Escribe trazas detalladas de Last Purpose en la consola (console.txt).")
    LastPurpose.optionsPanel = opt
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
-- tick de un minuto y una vez al arrancar. Si el panel no existe, deja el
-- valor por defecto de LP_Heists.lua (false).
function LastPurpose.refreshOptions()
    local debug = readOption("debug")
    if type(debug) == "boolean" then
        LastPurpose.DEBUG = debug
    end
end

LastPurpose.refreshOptions()
