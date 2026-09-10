-- ---------------------------------------------------------------------------
-- LP_Heists.lua es, a proposito, el UNICO archivo bajo common/media/lua/shared
-- de todo el mod. El motor de Project Zomboid carga cada archivo .lua de
-- forma independiente y alfabetica; un archivo compartido que a su vez
-- requiere OTRO archivo compartido puede ejecutarse antes de que ese otro
-- haya cargado, y "require" no fuerza la carga si todavia no le tocaba su
-- turno. Consolidar todo aqui (config, etapas, constantes de mundo y
-- catalogo) elimina esa categoria entera de bug: no hay ningun require
-- interno entre archivos comunes, asi que no importa en que orden decida
-- cargarlo el motor.
--
-- Por la misma razon, aqui NO se llama a ninguna API exclusiva del cliente
-- (como Keyboard.*): ese tipo de acceso vive en los archivos de
-- 42/media/lua/client, que si tienen garantizado que las APIs de UI ya
-- estan listas cuando cargan.
-- ---------------------------------------------------------------------------

LastPurpose = LastPurpose or {}

-- ===== Config =====

-- Build de prueba para creadores de contenido: SOLO el registro de consola
-- viene activado (para que el console.txt sirva en los reportes). La
-- activacion sigue tardando sus 15 dias reales y la frecuencia de radio no
-- se revela. La casilla "Registro de depuracion" (Opciones -> Mods) lo
-- puede apagar.
LastPurpose.DEBUG = true
LastPurpose.DEBUG_FAST_ACTIVATION = false
LastPurpose.DEBUG_SHOW_EXACT_FREQUENCY = false

LastPurpose.VERSION = "1.3.1"
LastPurpose.SAVE_KEY = "LastPurpose"
LastPurpose.SCHEMA = 1

LastPurpose.ACTIVATION_MINUTES = 20
LastPurpose.ACTIVATION_DAYS = LastPurpose.DEBUG_FAST_ACTIVATION
    and (LastPurpose.ACTIVATION_MINUTES / (24 * 60))
    or 15

LastPurpose.OBJECTIVES = {
    { key = "crowbar",     label = "Palanca" },
    { key = "screwdriver", label = "Destornillador" },
    { key = "flashlight",  label = "Linterna" },
    { key = "bag",         label = "Bolsa o mochila" },
    { key = "vehicle",     label = "Vehiculo funcional con combustible" },
}

LastPurpose.TOOL_TYPES = {
    ["Base.Crowbar"] = "crowbar",
    ["Base.CrowbarForged"] = "crowbar",
    ["Base.Screwdriver"] = "screwdriver",
    ["Base.Screwdriver_Old"] = "screwdriver",
    ["Base.Screwdriver_Improvised"] = "screwdriver",
    ["Base.HandTorch"] = "flashlight",
    ["Base.Torch"] = "flashlight",
}

function LastPurpose.debugPrint(message)
    if LastPurpose.DEBUG then print("[LastPurpose] " .. tostring(message)) end
end

-- ===== Etapas narrativas (ver LP_Tracker.lua y cada sistema para su uso) =====

LastPurpose.STAGE_ORDER = {
    "inactive", "prep_started", "prep_completed", "radio_prompted", "radio_heard",
    "clue_found", "note_read", "bank_scouted", "heist_active", "loot_taken",
    "returning", "review_loot", "completed",
}

local STAGE_INDEX = {}
for index, name in ipairs(LastPurpose.STAGE_ORDER) do
    STAGE_INDEX[name] = index - 1
end
LastPurpose.STAGE_INDEX = STAGE_INDEX

function LastPurpose.stageIndex(name)
    return STAGE_INDEX[name] or -1
end

function LastPurpose.stageIs(data, name)
    return data.stage == name
end

function LastPurpose.stageAtLeast(data, name)
    return LastPurpose.stageIndex(data.stage) >= LastPurpose.stageIndex(name)
end

function LastPurpose.stageBefore(data, name)
    return LastPurpose.stageIndex(data.stage) < LastPurpose.stageIndex(name)
end

function LastPurpose.stageBetween(data, fromName, toNameExclusive)
    local index = LastPurpose.stageIndex(data.stage)
    return index >= LastPurpose.stageIndex(fromName) and index < LastPurpose.stageIndex(toNameExclusive)
end

function LastPurpose.setStage(data, name)
    if not STAGE_INDEX[name] then
        print("[LastPurpose] ERROR: se intento asignar una etapa desconocida: '" .. tostring(name) .. "'")
        return
    end
    data.stage = name
end

-- ===== Constantes de mundo (Knox Bank, Louisville) =====
-- Validadas por una partida de prueba completa. Cada punto tiene nombre
-- propio porque distintos sistemas necesitan distintas referencias dentro
-- del mismo edificio (ver LP_BankSecurity, LP_HeistLoot, LP_HeistEscape,
-- LP_SafehouseAnchor).

LastPurpose.World = {
    BANK_MARKER = { x = 12564, y = 1698, arrivalRadius = 35 },
    BANK_SECURITY_ANCHOR = { x = 12571, y = 1712 },
    BANK_PERIMETER = { minX = 12560, maxX = 12602, minY = 1687, maxY = 1737, minZ = 0, maxZ = 3 },
    BANK_LOOT_SPAWN = { x = 12562, y = 1690, z = 1 },
    BANK_ESCAPE_ORIGIN = { x = 12562, y = 1690 },
    ALARM_ORIGIN = { x = 12562, y = 1690, z = 0 },
    ESCAPE_DISTANCE = 520,
    RETURN_RADIUS = 8,
    TABLE_SEARCH_RADIUS = 5,
    NIGHT_START_HOUR = 20,
    NIGHT_END_HOUR = 5,
}

-- ===== Catalogo de golpes =====

LastPurpose.HEISTS = {
    louisville_knox_bank = {
        id = "louisville_knox_bank",
        title = "La boveda abandonada",
        mission = "Adelantarse a la competencia",
        destination = "Knox Bank, Louisville",
        x = LastPurpose.World.BANK_MARKER.x,
        y = LastPurpose.World.BANK_MARKER.y,
        arrivalRadius = LastPurpose.World.BANK_MARKER.arrivalRadius,
        marker = "X",
        clueSites = {
            {12595, 998}, {12916, 1204}, {13206, 1244}, {12688, 1497}, {13230, 1691},
            {12148, 1728}, {12556, 1914}, {13550, 2085}, {12762, 2206}, {13567, 2344},
            {12266, 2610}, {12606, 2819}, {13696, 2967}, {13638, 3069}, {13756, 3282},
            {12941, 3328}, {12318, 3591}, {12338, 3679}, {12748, 3924}, {13587, 4074},
            {13620, 4130},
        },
        dialogue = {
            "<bzzt> Soy yo. Escucha con atencion...",
            "Los documentos siguen escondidos en el punto de reunion.",
            "Es el punto que marcamos en Louisville. Nadie deberia encontrarlos.",
            "Con esa nota sabremos donde guardaron el botin antes de evacuar.",
            "Voy a seguir llamando hasta que respondas.",
            "¿Me copiaste? <fzzt>",
        },
        finalLine = "Me copiaste?",
        loot = {
            valuables = {
                { type = "Base.SmallGoldBar", count = 5 },
                { type = "Base.Diamond", count = 4 },
                { type = "Base.MoneyBundle", count = 6 },
            },
            supplies = {
                { type = "Base.Antibiotics", count = 2 },
                { type = "Base.Pills", count = 2 },
                { type = "Base.SutureNeedle", count = 2 },
                { type = "Base.Bandage", count = 6 },
                { type = "Base.AlcoholWipes", count = 8 },
                { type = "Base.Battery", count = 6 },
                { type = "Base.DuctTape", count = 2 },
                { type = "Base.Woodglue", count = 1 },
                { type = "Base.PetrolCan", count = 1 },
                { type = "LastPurpose.BandWalkieTalkie", count = 1 },
                { type = "Base.CannedCornedBeef", count = 2 },
                { type = "Base.CannedSardines", count = 2 },
            },
            ammoChoices = {
                "Base.Bullets9mmBox", "Base.ShotgunShellsBox", "Base.308Box",
                "Base.556Box", "Base.Bullets45Box", "Base.Bullets357Box",
            },
            ammoRolls = 3,
            nimbleLevels = 2,
        },
    },
}

LastPurpose.HEIST_ORDER = { "louisville_knox_bank" }

function LastPurpose.getHeist(id)
    return LastPurpose.HEISTS[tostring(id or "")]
end

function LastPurpose.chooseHeistId()
    if #LastPurpose.HEIST_ORDER == 0 then return nil end
    return LastPurpose.HEIST_ORDER[ZombRand(#LastPurpose.HEIST_ORDER) + 1]
end

function LastPurpose.getHeistClue(data, heist)
    if not data or not heist or not heist.clueSites or #heist.clueSites == 0 then return nil end
    if not data.clueSiteIndex or not heist.clueSites[data.clueSiteIndex] then
        data.clueSiteIndex = ZombRand(#heist.clueSites) + 1
    end
    local site = heist.clueSites[data.clueSiteIndex]
    return {
        x = site[1], y = site[2], z = 0,
        arrivalRadius = 28,
        title = "PUNTO DE REUNION",
        destination = "Un punto de reunion en Louisville",
    }
end
