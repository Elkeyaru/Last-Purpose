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

-- Solo el registro de consola viene activado (util mientras se prueba Hito 2
-- y para los reportes con console.txt). La activacion sigue tardando sus 15
-- dias reales y la frecuencia de radio no se revela. La casilla "Registro de
-- depuracion" (Opciones -> Mods) lo puede apagar.
LastPurpose.DEBUG = true
LastPurpose.DEBUG_FAST_ACTIVATION = false
LastPurpose.DEBUG_SHOW_EXACT_FREQUENCY = false

LastPurpose.VERSION = "1.3.0"
LastPurpose.SAVE_KEY = "LastPurpose"
LastPurpose.SCHEMA = 1

LastPurpose.ACTIVATION_MINUTES = 20
LastPurpose.ACTIVATION_DAYS = LastPurpose.DEBUG_FAST_ACTIVATION
    and (LastPurpose.ACTIVATION_MINUTES / (24 * 60))
    or 15

-- Requisitos de la fase de preparacion. "safehouse" = mesa de planificacion
-- crafteada y colocada en el refugio: LP_SafehouseAnchor pone
-- data.objectives.safehouse = true cuando detecta la mesa cerca del jugador
-- (y la vuelve a false si desaparece). Se habia perdido de esta lista en la
-- reescritura 1.1.0 aunque el codigo que la marca seguia ahi.
LastPurpose.OBJECTIVES = {
    { key = "safehouse",   label = "Mesa de planificacion crafteada y colocada" },
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

-- ===== Hito 2: ciudades y catalogo de desbloqueo =====
--
-- Cada golpe pertenece a una CITY y tiene un ORDER dentro de esa ciudad
-- (cadena: completar el order N abre el N+1) y una spec UNLOCK:
--   { type = "start" }                       -- disponible desde el principio
--   { type = "completePrev" }                -- al completar el golpe anterior de su ciudad
--   { type = "cityKnown" }                   -- al haber estado en la ciudad O tener su mapa
--   { type = "profession", line = "medico" } -- al abrirse esa linea de profesion
--                                               (ver LastPurpose.PROFESSION_LINES);
--                                               los golpes 2+ de la linea usan completePrev
-- El estado ("done"/"active"/"available"/"locked") se CALCULA, nunca se
-- guarda (ver LastPurpose.heistStatus).
--
-- Los bbox de ciudad son AMPLIOS a proposito (rejilla de celdas de 300 tiles
-- de la Knox Country base). No hace falta afinarlos caminando: el gate
-- "cityKnown" solo decide si un golpe NO implementado se ve con nombre o
-- censurado, y hay dos desbloqueos alternativos que no dependen del bbox:
--   * llevar el mapa vanilla de la region (maps = {...}), y
--   * empezar un golpe de esa ciudad (LP_Unlocks marca citiesVisited).
-- Si algun dia un golpe de fuera de Louisville se implementa, se afina el
-- bbox de esa unica ciudad con LastPurpose.debugCityAt(player).

LastPurpose.CITIES = {
    LOUISVILLE  = { label = "LOUISVILLE",  bbox = { minX = 11100, maxX = 14700, minY = 150,   maxY = 4200  },
                    maps = { "Base.LouisvilleMap1", "Base.LouisvilleMap2", "Base.LouisvilleMap3",
                             "Base.LouisvilleMap4", "Base.LouisvilleMap5", "Base.LouisvilleMap6",
                             "Base.LouisvilleMap7", "Base.LouisvilleMap8", "Base.LouisvilleMap9" } },
    WEST_POINT  = { label = "WEST POINT",  bbox = { minX = 10950, maxX = 12650, minY = 6050,  maxY = 7750  },
                    maps = { "Base.WestpointMap" } },
    RIVERSIDE   = { label = "RIVERSIDE",   bbox = { minX = 5550,  maxX = 6950,  minY = 4900,  maxY = 6200  },
                    maps = { "Base.RiversideMap" } },
    ROSEWOOD    = { label = "ROSEWOOD",    bbox = { minX = 7600,  maxX = 8900,  minY = 10350, maxY = 11800 },
                    maps = { "Base.RosewoodMap" } },
    MARCH_RIDGE = { label = "MARCH RIDGE", bbox = { minX = 9950,  maxX = 11050, minY = 12400, maxY = 13650 },
                    maps = { "Base.MarchRidgeMap" } },
    MULDRAUGH   = { label = "MULDRAUGH",   bbox = { minX = 10350, maxX = 11650, minY = 8850,  maxY = 11050 },
                    maps = { "Base.MuldraughMap" } },
}

-- Catalogo del hub. Entradas con implemented=false salen como "proximamente":
-- se pueden desbloquear y ver el motivo, pero no seleccionarse todavia.
-- Objetivo ~19 para el Ladron; esto es la semilla.
LastPurpose.CATALOG = {
    -- Louisville: cadena de 3.
    { id = "louisville_knox_bank", city = "LOUISVILLE", order = 1,
      name = "El ultimo golpe", short = "Knox Bank, Louisville",
      unlock = { type = "start" }, implemented = true },
    { id = "louisville_last_exhibition", city = "LOUISVILLE", order = 2,
      name = "La ultima exposicion", short = "Galeria del norte, Louisville",
      unlock = { type = "completePrev" }, implemented = false },
    { id = "louisville_penthouse", city = "LOUISVILLE", order = 3,
      name = "El cielo tiene dueno", short = "Penthouse, Louisville",
      unlock = { type = "completePrev" }, implemented = false },

    -- Otras ciudades: gated por conocer la ciudad. Contenido en el punto 3.
    { id = "westpoint_payroll", city = "WEST_POINT", order = 1,
      name = "La nomina desaparecida", short = "Banco de West Point",
      unlock = { type = "cityKnown" }, implemented = false },
    { id = "westpoint_unit27", city = "WEST_POINT", order = 2,
      name = "Unidad 27", short = "Trastero privado, West Point",
      unlock = { type = "completePrev" }, implemented = false },
    { id = "riverside_frozen", city = "RIVERSIDE", order = 1,
      name = "Cuenta congelada", short = "Banco de Riverside",
      unlock = { type = "cityKnown" }, implemented = false },
    { id = "riverside_founder", city = "RIVERSIDE", order = 2,
      name = "El trofeo del fundador", short = "Country Club, Riverside",
      unlock = { type = "completePrev" }, implemented = false },
    { id = "rosewood_file93", city = "ROSEWOOD", order = 1,
      name = "Expediente 93", short = "Juzgado de Rosewood",
      unlock = { type = "cityKnown" }, implemented = false },
    { id = "rosewood_chiefbox", city = "ROSEWOOD", order = 2,
      name = "La caja del jefe", short = "Parque de bomberos, Rosewood",
      unlock = { type = "completePrev" }, implemented = false },
}

-- Indices derivados (id -> entrada, ciudad -> lista ordenada).
LastPurpose.CATALOG_BY_ID = {}
LastPurpose.CATALOG_BY_CITY = {}
for _, entry in ipairs(LastPurpose.CATALOG) do
    LastPurpose.CATALOG_BY_ID[entry.id] = entry
    local list = LastPurpose.CATALOG_BY_CITY[entry.city]
    if not list then list = {}; LastPurpose.CATALOG_BY_CITY[entry.city] = list end
    list[#list + 1] = entry
end
for _, list in pairs(LastPurpose.CATALOG_BY_CITY) do
    table.sort(list, function(a, b) return (a.order or 0) < (b.order or 0) end)
end

-- ===== Lineas de profesion =====
--
-- El hub muestra un dial de profesiones. La del Ladron esta siempre abierta
-- (es la del prologo). Las demas se abren al: (1) completar el prologo del
-- Ladron -- el golpe LastPurpose.PROLOGUE_HEIST_ID -- y (2) tener Nv. `level`
-- en `perk`. `perk` es el NOMBRE del enum Perks (se resuelve con pcall en
-- runtime; un nombre mal escrito degrada a "no se pudo comprobar", no revienta).
LastPurpose.PROLOGUE_HEIST_ID = "louisville_knox_bank"

LastPurpose.PROFESSION_LINES = {
    ladron    = { id = "ladron",    name = "LADRON",    isThief = true },
    medico    = { id = "medico",    name = "MEDICO",    perk = "Doctor",       level = 2, perkLabel = "Medicina" },
    ingeniero = { id = "ingeniero", name = "INGENIERO", perk = "MetalWelding", level = 2, perkLabel = "Fabricacion" },
    veterano  = { id = "veterano",  name = "VETERANO",  perk = "Aiming",       level = 2, perkLabel = "Punteria" },
}
LastPurpose.PROFESSION_LINE_ORDER = { "ladron", "medico", "ingeniero", "veterano" }

--- ¿El jugador termino el prologo del Ladron (El ultimo golpe)?
function LastPurpose.prologueDone(data)
    return not not (data and data.completedHeists
        and data.completedHeists[LastPurpose.PROLOGUE_HEIST_ID])
end

--- Comprueba Nv. de habilidad. Usa KeyasReq.skillAtLeast si esta cargado
--- (cliente); si no, hace su propio pcall. `perkName` es el nombre del enum.
--- @return boolean, string|nil
function LastPurpose.checkSkill(player, perkName, level, label)
    label = label or perkName
    if not player then return false, "Sin jugador." end
    local ok, perk = pcall(function()
        if type(Perks) ~= "table" and type(Perks) ~= "userdata" then return nil end
        local p = Perks[perkName]
        if not p and Perks.FromString then p = Perks.FromString(perkName) end
        return p
    end)
    if not ok or not perk then
        return false, "No se pudo comprobar " .. tostring(label) .. "."
    end
    if KeyasReq and KeyasReq.skillAtLeast then
        return KeyasReq.skillAtLeast(player, perk, level)
    end
    local ok2, cur = pcall(player.getPerkLevel, player, perk)
    if not ok2 or type(cur) ~= "number" then
        return false, "No se pudo comprobar " .. tostring(label) .. "."
    end
    if cur >= level then return true, nil end
    return false, "Necesitas " .. tostring(label) .. " Nv. " .. tostring(level)
        .. " (tienes " .. tostring(cur) .. ")."
end

--- Estado de una linea de profesion del hub.
--- @return "open" | "locked", motivo (string|nil)
function LastPurpose.professionLineStatus(lineId, data, player)
    local line = LastPurpose.PROFESSION_LINES[tostring(lineId or "")]
    if not line then return "locked", "Linea de profesion desconocida." end
    if line.isThief then return "open", nil end
    if not LastPurpose.prologueDone(data) then
        return "locked", "Completa el prologo del Ladron (El ultimo golpe)."
    end
    if line.perk and line.level then
        local ok, reason = LastPurpose.checkSkill(player, line.perk, line.level, line.perkLabel)
        if not ok then
            return "locked", reason or ("Sube " .. tostring(line.perkLabel) .. ".")
        end
    end
    return "open", nil
end

function LastPurpose.cityOf(x, y)
    for key, city in pairs(LastPurpose.CITIES) do
        local b = city.bbox
        if x >= b.minX and x <= b.maxX and y >= b.minY and y <= b.maxY then
            return key
        end
    end
    return nil
end

-- Imprime la ciudad detectada en la posicion del jugador. Para calibrar
-- los bbox: caminar por cada pueblo y ver que salga la etiqueta correcta.
function LastPurpose.debugCityAt(player)
    player = player or (getSpecificPlayer and getSpecificPlayer(0))
    if not player then return end
    local x, y = math.floor(player:getX()), math.floor(player:getY())
    local key = LastPurpose.cityOf(x, y)
    print(string.format("[LastPurpose] pos %d,%d -> ciudad: %s", x, y, tostring(key)))
end

--- ¿El jugador conoce la ciudad `cityKey`? True si la visito
--- (data.citiesVisited) o lleva su mapa vanilla en el inventario.
function LastPurpose.isCityKnown(data, player, cityKey)
    if not cityKey then return false end
    if data and data.citiesVisited and data.citiesVisited[cityKey] then return true end
    local city = LastPurpose.CITIES[cityKey]
    if not city or not player or not player.getInventory then return false end
    local inv = player:getInventory()
    for _, mapType in ipairs(city.maps or {}) do
        local ok, has = pcall(function() return inv:contains(mapType) or inv:containsTypeRecurse(mapType) end)
        if ok and has then return true end
    end
    return false
end

--- Estado calculado de un golpe del catalogo.
--- @return "done" | "active" | "available" | "locked", motivo (string|nil)
function LastPurpose.heistStatus(id, data, player)
    local entry = LastPurpose.CATALOG_BY_ID[tostring(id or "")]
    if not entry then return "locked", "Desconocido" end
    data = data or {}

    if data.completedHeists and data.completedHeists[entry.id] then
        return "done", nil
    end
    -- Activo: el golpe elegido mientras su maquina de etapas corre (o el
    -- activeHeistId que mantiene LP_Unlocks, por si el tick aun no paso).
    local running = data.stage and data.stage ~= "inactive" and data.stage ~= "completed"
    if data.activeHeistId == entry.id
        or (running and data.selectedHeist == entry.id) then
        return "active", nil
    end

    local u = entry.unlock or { type = "locked" }
    if u.type == "start" then
        return "available", nil
    elseif u.type == "completePrev" then
        local list = LastPurpose.CATALOG_BY_CITY[entry.city] or {}
        local prev
        for _, e in ipairs(list) do
            if (e.order or 0) < (entry.order or 0) then prev = e end
        end
        if not prev then return "available", nil end
        if data.completedHeists and data.completedHeists[prev.id] then
            return "available", nil
        end
        return "locked", "Completa antes \"" .. tostring(prev.name) .. "\"."
    elseif u.type == "cityKnown" then
        if LastPurpose.isCityKnown(data, player, entry.city) then
            return "available", nil
        end
        local label = (LastPurpose.CITIES[entry.city] or {}).label or entry.city
        return "locked", "Explora " .. tostring(label) .. " o consigue su mapa."
    elseif u.type == "profession" then
        -- La linea de profesion debe estar abierta (prologo + Nv. de habilidad).
        local st, reason = LastPurpose.professionLineStatus(u.line, data, player)
        if st ~= "open" then return "locked", reason end
        -- Linea abierta: dentro de ella el primer golpe es "profession" y ya
        -- esta disponible; los golpes 2+ de la linea usan completePrev.
        return "available", nil
    end
    return "locked", "Bloqueada."
end

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
