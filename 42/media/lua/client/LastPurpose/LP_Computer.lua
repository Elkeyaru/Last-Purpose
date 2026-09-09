require "ISUI/ISPanel"
require "ISUI/ISButton"
require "LastPurpose/LP_TermFontData"
require "KeyasLib/KeyasUI"
require "KeyasLib/KeyasCSS"

-- ---------------------------------------------------------------------------
-- LP_Computer.lua - Hito 1 del hub del ordenador (roadmap punto 2).
--
-- La mesa de planificacion es "la mesa con ordenador". Su menu contextual
-- abre esta GUI, un archivo de misiones estilo SO retro. Por ahora es de
-- SOLO LECTURA: lista el catalogo y, en la etapa review_loot, entrega el
-- botin (LastPurpose.reviewHeistLoot). El diario (tecla J) sigue aparte.
--
-- ESTRUCTURA:
--   * CHROME fijo -> xcyos_chrome.png horneado (bisel CRT, marco, barra de
--     titulo, rail, barra de estado, logo, vinneta). Ver docs/GUI_ASSETS.md.
--   * CONTENIDO -> arbol de cajas + hoja de estilos (CONTENT_CSS) que
--     maqueta y pinta KeyasCSS (KeyasLib >= 1.2.3): flexbox, esquinas
--     redondeadas, bordes, sombras. Iconos y mini-mapa por hooks onPaint.
--   * FUENTES -> atlas de glifos horneados con tools/bake_fonts.ps1
--     (Bahnschrift / Consolas), registrados en KeyasUI. 4 tamanos con
--     jerarquia: ui14 etiqueta, ui18 cuerpo, ui30 titulo, mono16 numeros.
-- ---------------------------------------------------------------------------

LastPurpose = LastPurpose or {}

local REDACTED = "?????????"

local CATALOG = {
    { city = "LOUISVILLE", rows = {
        { id = "louisville_knox_bank", name = "El ultimo golpe", unlocked = true },
        { id = "last_exhibition",   name = "La ultima exposicion" },
        { id = "penthouse_fortune", name = "El cielo tiene dueno" },
        { id = "zero_kilometers",   name = "Cero kilometros" },
    }},
    { city = "WEST POINT", hint = "Explora West Point y vuelve a tu refugio.", rows = {
        { id = "wp1" }, { id = "wp2" },
    }},
    { city = "RIVERSIDE", hint = "Explora Riverside y vuelve a tu refugio.", rows = {
        { id = "rv1" }, { id = "rv2" },
    }},
    { city = "ROSEWOOD", hint = "Explora Rosewood y vuelve a tu refugio.", rows = {
        { id = "rw1" }, { id = "rw2" },
    }},
}

local APPS = {
    { id = "misiones", label = "MISIONES" },
    { id = "notas",    label = "NOTAS" },
    { id = "archivos", label = "ARCHIVOS" },
    { id = "sistema",  label = "SISTEMA" },
}

-- Profesiones (solo lectura por ahora - hito 2). La primera es la del
-- personaje (Ladron); el resto muestra su requisito y la lista bloqueada.
local PROFS = {
    { id = "ladron",    name = "LADRON",    unlocked = true },
    { id = "medico",    name = "MEDICO",    req = "Completa el prologo del Ladron y sube Medicina a Nv. 2." },
    { id = "ingeniero", name = "INGENIERO", req = "Completa el prologo del Ladron y sube Fabricacion a Nv. 2." },
    { id = "veterano",  name = "VETERANO",  req = "Completa el prologo del Ladron y sube Punteria a Nv. 2." },
}

-- Notas del mundo (contenido estatico de solo lectura por ahora).
local NOTES = {
    { t = "Nota del punto de reunion",
      d = "\"Los documentos siguen escondidos en el punto que marcamos en Louisville. Con esa nota sabremos donde guardaron el botin antes de evacuar.\"" },
    { t = "Transmision interceptada",
      d = "Seis lineas de un contacto sin nombre que repite el mensaje en la banda de bandidos cada media hora hasta que respondes." },
    { t = "Recorte de prensa - Knox Bank",
      d = "\"El banco mas grande de Kentucky cierra sus puertas ante la evacuacion de Louisville.\"" },
}
local ARCHIVES = {
    { t = "Knox Bank - planta y perimetro",
      d = "Coordenadas validadas en partida. Puertas y ventanas selladas hasta que empieza el golpe." },
    { t = "Contacto - la voz de la radio",
      d = "Sin nombre. Llama en la banda de bandidos. Sabe donde esta todo lo que dejaron atras." },
    { t = "Catalogo de golpes - Louisville",
      d = "Cuatro objetivos. Uno se elige por partida; el resto queda archivado hasta abrir nuevas ciudades." },
    { t = "Refugio",
      d = "La mesa con el ordenador fija tu base. Volver aqui despues de explorar una ciudad revela sus golpes." },
}

-- Paleta terminal (hex del mockup XCYOS).
local DESKTOP   = { 0.106, 0.125, 0.118 }
local WINFACE   = { 0.725, 0.714, 0.678 }
local INK       = { 0.086, 0.086, 0.059 }
local INK_SOFT  = { 0.290, 0.278, 0.235 }
local PHOSPHOR  = { 0.184, 0.906, 0.769 }
local PH_DIM    = { 0.110, 0.561, 0.486 }
local OKC       = { 0.337, 0.706, 0.353 }
local AMBER     = { 1.000, 0.714, 0.290 }
local LOCKC     = { 0.486, 0.478, 0.439 }

local TEX_DIR = "media/ui/LastPurpose/"
local texCache = {}
local function tex(name)
    if texCache[name] == nil then
        local ok, t = pcall(getTexture, TEX_DIR .. name)
        texCache[name] = (ok and t) or false
    end
    return texCache[name] or nil
end
local function icon(n) return tex(string.format("lp_icon_%02d.png", n)) end

local IC = {
    misiones = 0, notas = 1, archivos = 2, sistema = 3, folder = 4,
    compass = 5, crosshair = 6, finger = 7,
    cash = 8, gold = 9, crate = 10, art = 11, watch = 12, car = 13,
    min = 14, max = 15, close = 16,
}

-- Dibuja un icono de la hoja procesada, tintado. Fallback: glifo de rects.
-- `c` puede venir nil desde un hook onPaint mal cableado: se usa INK para
-- no reventar el render (que ademas se cachea y spamearia el error).
local function drawIcon(self, n, x, y, size, c)
    c = c or INK
    local t = icon(n)
    if t then
        self:drawTextureScaled(t, x, y, size, size, 1, c[1], c[2], c[3])
        return
    end
    self:drawRectBorder(x + 3, y + 4, size - 8, size - 10, 1, c[1], c[2], c[3])
end

-- ---- fuentes de terminal via KeyasUI --------------------------------------
local FONTS_REGISTERED = false
local function ensureFontsRegistered()
    if FONTS_REGISTERED then return end
    if not (KeyasUI and KeyasUI.registerFont and LP_TermFontData) then return end
    local function reg(id, key, size, fb)
        local m = LP_TermFontData[key]
        if not m then return end
        KeyasUI.registerFont(id, {
            atlasPath = "media/ui/LastPurpose/" .. id .. ".png",
            metrics = m, size = size, fallbackFont = fb,
        })
    end
    reg("lp_ui_14",   "ui14",   14, UIFont and UIFont.Small)
    reg("lp_ui_18",   "ui18",   18, UIFont and UIFont.Medium)
    reg("lp_ui_30",   "ui30",   30, UIFont and UIFont.Large)
    reg("lp_mono_16", "mono16", 16, UIFont and UIFont.Small)
    FONTS_REGISTERED = true
end

-- ---- estado de la mision ------------------------------------------------

-- devuelve: labelBadge, colorBadge, textoBoton, habilitado
local function knoxStatus(data)
    if LastPurpose.stageIs(data, "completed") then
        return "ARCHIVADA", OKC, "Archivada", false
    end
    if LastPurpose.stageIs(data, "review_loot") then
        return "BOTIN PENDIENTE", PHOSPHOR, "Entregar botin", true
    end
    if LastPurpose.stageAtLeast(data, "heist_active") then
        return "EN CURSO", AMBER, "Sigue en el diario (J)", false
    end
    return "EN PREPARACION", PH_DIM, "En preparacion", false
end

-- ---- chrome horneado + zonas de contenido -----------------------------
-- Medido sobre el xcyos_chrome.png actual (espacio 1927x1080). Este chrome
-- NO trae rail ni texto de titulo horneados: los dibuja este archivo en
-- paint(). La GUI se abre a pantalla completa; el chrome se estira a la
-- pantalla y estas zonas se escalan con ella (sx = w/1927, sy = h/1080).
local BAKE_W, BAKE_H = 1927, 1080
local SKIN = {
    content    = { 176, 103, 1370, 847 },     -- rectangulo de contenido; lo pinta KeyasCSS
    titleClose = { 1502, 58, 46, 46 },        -- glifo X de la barra de titulo
    titleText  = { 216, 62, 1180, 42 },       -- franja del titulo (la dibujamos nosotros)
    rail       = { { 21, 66, 152, 110 }, { 21, 186, 152, 110 }, { 21, 306, 152, 110 }, { 21, 426, 152, 110 } },
}
local TITLE_BG  = { 0.196, 0.255, 0.235 }     -- verde de la barra de titulo (#324139)
local TITLE_INK = { 0.918, 1.000, 0.965 }     -- #eafffb
local RAIL_ON   = { 0.900, 1.000, 0.965 }     -- icono/etiqueta de la pestana activa
local RAIL_OFF  = { 0.760, 0.790, 0.770 }     -- icono/etiqueta inactiva
local RAIL_LBL_OFF = { 0.620, 0.660, 0.630 }

-- Hoja de estilos del CONTENIDO. Escrita en espacio 1927; KeyasCSS.parse la
-- escala por self.sy en layout(). Panel un pelin mas claro que la cara de
-- la ventana + borde + sombra suave = profundidad sin biseles inset.
-- Fuentes: atlas de glifos VT323 (lp_ui_14/18/30, lp_mono_16) - un solo
-- peso, la jerarquia es tamano.
local CONTENT_CSS = [[
  .root { display: flex; flex-direction: row; gap: 18px; height: 100%; }

  .pane {
    background: #c4c1b6; border: 2px solid #6d6a61; border-radius: 6px;
    box-shadow: 0 6px 18px rgba(0,0,0,0.28);
    overflow: hidden; height: 100%; display: flex; flex-direction: column;
  }
  .list-pane { width: 420px; padding: 16px 12px 16px 16px; }
  .detail-pane { flex-grow: 1; padding: 26px 36px; }

  /* selector de profesion */
  .prof {
    display: flex; flex-direction: row; align-items: center; gap: 10px;
    padding: 6px 4px 12px;
  }
  .prof-nav {
    width: 34px; height: 44px; display: flex; flex-direction: row;
    align-items: center; justify-content: center;
    border: 1px solid #16160f; border-radius: 4px; background: #b9b6ad;
    font: lp_ui_18; color: #16160f;
  }
  .prof-mid { flex-grow: 1; display: flex; flex-direction: column; align-items: center; gap: 2px; }
  .prof-ic { width: 40px; height: 40px; }
  .prof-name { font: lp_ui_18; color: #16160f; }
  .prof-tag { font: lp_ui_14; color: #1c8f7c; }
  .prof-tag.lock { color: #9a5a1a; }

  .city { display: flex; flex-direction: column; margin-top: 16px; }
  .city.first { margin-top: 4px; }
  .city-title { font: lp_ui_14; color: #16160f; padding-bottom: 4px; }
  .rule { height: 2px; background: #16160f; }
  .rule-soft { height: 1px; background: #8f8c82; }
  .city-hint { font: lp_ui_14; color: #7c7a70; margin-top: 8px; }

  .missions { display: flex; flex-direction: column; margin-top: 8px; }
  .m-row {
    display: flex; flex-direction: row; align-items: center; gap: 10px;
    padding: 6px 10px 6px 9px; border-radius: 5px;
    border: 1px solid transparent; font: lp_ui_18; color: #16160f;
  }
  .m-row .num { width: 30px; font: lp_mono_16; color: #4a473c; }
  .m-row .m-name { flex-grow: 1; }
  .m-row .dot { width: 12px; height: 12px; border-radius: 6px; }
  .dot.ok    { background: #56b45a; }
  .dot.prog  { background: #ffb64a; }
  .dot.lock  { background: #7c7a70; }
  .dot.claim { background: #2fe7c4; }
  .m-row.locked { color: #7c7a70; }
  .m-row.locked .num { color: #7c7a70; }
  .m-row.sel { background: #223330; color: #eafffb; border: 1px solid #2fe7c4; }
  .m-row.sel .num { color: #2fe7c4; }

  .d-head { display: flex; flex-direction: row; align-items: flex-start; gap: 14px; }
  .d-title { flex-grow: 1; display: flex; flex-direction: column; gap: 4px; }
  .d-name { font: lp_ui_30; color: #16160f; }
  .d-city { font: lp_ui_14; color: #4a473c; }
  .badge { font: lp_ui_14; padding: 6px 12px; border-radius: 4px; border: 1px solid #16160f; }

  .sec { margin-top: 28px; display: flex; flex-direction: column; }
  .sec-h { font: lp_ui_14; color: #16160f; padding-bottom: 5px; }
  .sec .rule-soft { margin-bottom: 12px; }
  .grid { display: flex; flex-direction: row; gap: 28px; align-items: flex-start; }
  .body { font: lp_ui_18; color: #16160f; line-height: 30px; flex-grow: 1; }
  .body-soft { font: lp_ui_14; color: #4a473c; line-height: 26px; margin-top: 14px; }

  .map {
    width: 300px; height: 240px; border: 2px solid #16160f;
    border-radius: 4px; background: #d0cdc3;
    box-shadow: 0 4px 12px rgba(0,0,0,0.25);
  }

  .reward { display: flex; flex-direction: row; gap: 16px; margin-top: 10px; }
  .tile {
    width: 160px; padding: 14px 10px 12px; border: 2px solid #16160f;
    border-radius: 6px; background: #b9b6ad;
    box-shadow: 4px 4px 0 rgba(22,22,15,0.65);
    display: flex; flex-direction: column; align-items: center; gap: 6px;
  }
  .tile .ic { width: 42px; height: 36px; }
  .tile .val { font: lp_mono_16; color: #16160f; }
  .tile .cap { font: lp_ui_14; color: #4a473c; }

  .action-row { display: flex; flex-direction: row; margin-top: 26px; }
  .cta {
    display: flex; flex-direction: row; align-items: center; gap: 14px;
    padding: 12px 22px 12px 12px;
    border: 2px solid #16160f; border-radius: 4px; background: #cbc8bf;
    box-shadow: 4px 4px 0 rgba(22,22,15,1);
    font: lp_ui_18; color: #16160f;
  }
  .cta .ic { width: 30px; height: 30px; }
  .cta.on { background: #bff2e8; }
  .cta.off { opacity: 0.5; }

  .stub { flex-grow: 1; display: flex; flex-direction: column; }
  .stub .h { font: lp_ui_30; color: #16160f; }
  .stub .p { font: lp_ui_18; color: #4a473c; line-height: 30px; margin-top: 12px; max-width: 780px; }

  .doc-list { display: flex; flex-direction: column; gap: 10px; margin-top: 18px; }
  .doc {
    display: flex; flex-direction: row; gap: 14px; align-items: flex-start;
    border: 1px solid #6d6a61; border-radius: 4px; background: #b9b6ad;
    padding: 12px 14px; max-width: 900px;
  }
  .doc-ic { width: 26px; height: 26px; }
  .doc-txt { flex-grow: 1; display: flex; flex-direction: column; gap: 4px; }
  .doc-t { font: lp_ui_14; color: #16160f; }
  .doc-d { font: lp_ui_14; color: #4a473c; line-height: 24px; }

  .note-card {
    margin-top: 20px; max-width: 820px;
    border: 1px solid #1c8f7c; border-radius: 4px; background: #c9c6bc;
    padding: 14px 16px; font: lp_ui_14; color: #16160f; line-height: 26px;
  }
]]

-- ---------------------------------------------------------------------------

LPComputer = ISPanel:derive("LPComputer")

function LPComputer:new()
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    -- Pantalla completa: ocupa toda la ventana del juego. El chrome
    -- (xcyos_chrome.png, 16:9) se estira a la pantalla; en pantallas que no
    -- son 16:9 hay un leve estirado, asumido a proposito.
    local o = ISPanel:new(0, 0, sw, sh)
    setmetatable(o, self)
    self.__index = self
    o.background = false
    o.moveWithMouse = false
    o.app = "misiones"
    o.prof = 1
    o.selectedId = "louisville_knox_bank"
    o.appHitboxes = {}
    o._treeDirty = true
    return o
end

-- Marca el arbol de contenido para reconstruirse en el proximo paint().
-- Se llama al cambiar de app, de mision seleccionada o de profesion, no en
-- cada frame -> sin lag al clicar (no se reasigna un arbol nuevo por frame).
function LPComputer:markDirty()
    self._treeDirty = true
end

function LPComputer:zone(bake)
    local sx = self.sx or (self.width / BAKE_W)
    local sy = self.sy or (self.height / BAKE_H)
    return math.floor(bake[1] * sx), math.floor(bake[2] * sy),
           math.floor(bake[3] * sx), math.floor(bake[4] * sy)
end

function LPComputer:layout()
    self.sx = self.width / BAKE_W
    self.sy = self.height / BAKE_H
    self.appHitboxes = {}
    for i, app in ipairs(APPS) do
        local rx, ry, rw, rh = self:zone(SKIN.rail[i])
        self.appHitboxes[i] = { id = app.id, x = rx, y = ry, w = rw, h = rh }
    end
    -- El contenido se maqueta en la escala vertical (el ancho sobra al
    -- estirar). Las fuentes bitmap no escalan: en pantallas mayores que
    -- 1080p el texto se vera algo pequeno (limitacion conocida).
    self.sheet = KeyasCSS.parse(CONTENT_CSS, { scale = self.sy })
end

-- ---- helpers para hooks onPaint del arbol ----------------------------

local function paintIcon(name)
    return function(node, owner, x, y, w, h)
        local s = math.min(w, h)
        drawIcon(owner, IC[name] or IC.crate, math.floor(x + (w - s) / 2), math.floor(y), math.floor(s), INK)
    end
end

local function paintMap(label)
    return function(node, owner, x, y, w, h)
        owner:drawRect(x, y, w, h, 1, 0.816, 0.804, 0.765)
        local gc = { 0.55, 0.53, 0.49 }
        for gx = x + 18, x + w - 8, 28 do owner:drawRect(gx, y + 3, 1, h - 6, 1, gc[1], gc[2], gc[3]) end
        for gy = y + 18, y + h - 8, 26 do owner:drawRect(x + 3, gy, w - 6, 1, 1, gc[1], gc[2], gc[3]) end
        owner:drawRect(x + 8, y + math.floor(h * 0.62), math.floor(w * 0.5), 2, 1, 0.42, 0.40, 0.36)
        local ox, oy = x + math.floor(w * 0.52), y + math.floor(h * 0.42)
        owner:drawRectBorder(ox - 9, oy - 8, 18, 16, 1, 0.36, 0.35, 0.31)
        owner:drawRect(ox + 20, oy + 9, 1, 24, 1, INK[1], INK[2], INK[3])
        owner:drawRect(ox + 9, oy + 20, 24, 1, 1, INK[1], INK[2], INK[3])
        owner:drawRectBorder(ox + 13, oy + 13, 15, 15, 1, INK[1], INK[2], INK[3])
        KeyasUI.text(owner, tostring(label or ""), x + 8, y + 6, { r = 0.16, g = 0.16, b = 0.13, a = 1 }, "lp_ui_14")
    end
end

-- ---- arbol de contenido (KeyasCSS) ---------------------------------

function LPComputer:selectedRow()
    for _, group in ipairs(CATALOG) do
        for _, row in ipairs(group.rows) do
            if row.id == self.selectedId then return row, group end
        end
    end
    return nil, nil
end

local function dotClass(label)
    if label == "ARCHIVADA" then return "ok"
    elseif label == "BOTIN PENDIENTE" then return "claim"
    elseif label == "EN CURSO" then return "prog" end
    return "prog"
end

-- Selector de profesion: icono + nombre + flechas. Solo lectura: cambiar de
-- profesion cambia lo que se ve (las bloqueadas muestran su requisito).
function LPComputer:profWidgetNode()
    local p = PROFS[self.prof]
    local function cycle(d)
        return function()
            self.prof = ((self.prof - 1 + d) % #PROFS) + 1
            self.selectedId = (PROFS[self.prof].unlocked and "louisville_knox_bank")
                or ("__locked_" .. PROFS[self.prof].id)
            self:markDirty()
        end
    end
    return { tag = "div", class = "prof", children = {
        { tag = "div", class = "prof-nav", onClick = cycle(-1), children = { { tag = "div", text = "<" } } },
        { tag = "div", class = "prof-mid", children = {
            { tag = "div", class = "prof-ic", onPaint = function(node, owner, x, y, w, h)
                local t = tex("lp_prof_" .. p.id .. ".png")
                local s = math.min(w, h)
                if t then owner:drawTextureScaled(t, math.floor(x + (w - s) / 2), y, s, s, 1,
                    RAIL_ON[1], RAIL_ON[2], RAIL_ON[3]) end
            end },
            { tag = "div", class = "prof-name", text = p.name },
            { tag = "div", class = p.unlocked and "prof-tag" or "prof-tag lock",
              text = p.unlocked and "PERFIL ACTIVO" or "LINEA BLOQUEADA" },
        }},
        { tag = "div", class = "prof-nav", onClick = cycle(1), children = { { tag = "div", text = ">" } } },
    }}
end

function LPComputer:listPaneNode()
    local p = PROFS[self.prof]
    local children = { self:profWidgetNode(), { tag = "div", class = "rule-soft" } }

    if not p.unlocked then
        children[#children + 1] = { tag = "div", class = "city first", children = {
            { tag = "div", class = "city-title", text = "LINEA BLOQUEADA" },
            { tag = "div", class = "rule" },
            { tag = "div", class = "city-hint", text = p.req or "" },
            { tag = "div", class = "missions", children = {
                { tag = "div", class = "m-row locked sel", children = {
                    { tag = "div", class = "num", text = "-" },
                    { tag = "div", class = "m-name", text = REDACTED },
                    { tag = "div", class = "dot lock" },
                }},
            }},
        }}
        return { tag = "div", class = "pane list-pane", children = children }
    end

    local player = LastPurpose.getPlayerSafe(0)
    local data = player and LastPurpose.getData(player)
    for gi, group in ipairs(CATALOG) do
        local rows = {}
        for i, row in ipairs(group.rows) do
            local sel = row.id == self.selectedId
            local cls = "m-row"
            if not row.unlocked then cls = cls .. " locked" end
            if sel then cls = cls .. " sel" end
            local dot = row.unlocked and (data and dotClass((knoxStatus(data))) or "prog") or "lock"
            local rid = row.id
            rows[#rows + 1] = { tag = "div", class = cls, key = rid,
                onClick = function() self.selectedId = rid; self:markDirty() end,
                children = {
                    { tag = "div", class = "num", text = i .. "." },
                    { tag = "div", class = "m-name", text = row.unlocked and row.name or REDACTED },
                    { tag = "div", class = "dot " .. dot },
                },
            }
        end
        local kids = {
            { tag = "div", class = "city-title", text = group.city },
            { tag = "div", class = "rule" },
        }
        if group.hint then kids[#kids + 1] = { tag = "div", class = "city-hint", text = group.hint } end
        kids[#kids + 1] = { tag = "div", class = "missions", children = rows }
        children[#children + 1] = { tag = "div", class = "city", children = kids }
    end
    return { tag = "div", class = "pane list-pane", children = children }
end

function LPComputer:detailPaneNode()
    local player = LastPurpose.getPlayerSafe(0)

    -- Profesion bloqueada: expediente clasificado con su requisito.
    local prof = PROFS[self.prof]
    if not prof.unlocked then
        return { tag = "div", class = "pane detail-pane", children = {
            { tag = "div", class = "d-head", children = {
                { tag = "div", class = "d-title", children = {
                    { tag = "div", class = "d-name", text = prof.name },
                    { tag = "div", class = "d-city", text = "LINEA DE PROFESION - CLASIFICADA" },
                }},
                { tag = "div", class = "badge", text = "BLOQUEADA", style = {
                    color = "#5f5d54", backgroundColor = "#c7c4ba", borderColor = "#16160f" } },
            }},
            { tag = "div", class = "sec", children = {
                { tag = "div", class = "sec-h", text = "REQUISITO" },
                { tag = "div", class = "rule-soft" },
                { tag = "div", class = "body", text = prof.req or "Avanza en la historia." },
                { tag = "div", class = "body-soft", text = "Sus golpes y su prologo se abren al cumplir el requisito." },
            }},
        }}
    end

    local row, group = self:selectedRow()
    if not row then return { tag = "div", class = "pane detail-pane" } end

    if not row.unlocked then
        return { tag = "div", class = "pane detail-pane", children = {
            { tag = "div", class = "d-head", children = {
                { tag = "div", class = "d-title", children = {
                    { tag = "div", class = "d-name", text = REDACTED },
                    { tag = "div", class = "d-city", text = "EXPEDIENTE CLASIFICADO" },
                }},
            }},
            { tag = "div", class = "sec", children = {
                { tag = "div", class = "sec-h", text = "OBJETIVO" },
                { tag = "div", class = "rule-soft" },
                { tag = "div", class = "body", text = "Nombre y detalles ocultos. Cumpli el requisito para que el expediente se abra." },
                { tag = "div", class = "body-soft", text = "Requisito: " .. ((group and group.hint) or "Avanza en la historia.") },
            }},
        }}
    end

    local heist = LastPurpose.getHeist(row.id)
    local data = player and LastPurpose.getData(player)
    local label, color, ctaText, ctaOn = "DISPONIBLE", PH_DIM, "En preparacion", false
    if data then label, color, ctaText, ctaOn = knoxStatus(data) end

    local function hx(r, g, b) return string.format("#%02x%02x%02x",
        math.max(0, math.min(255, math.floor(r))), math.max(0, math.min(255, math.floor(g))),
        math.max(0, math.min(255, math.floor(b)))) end
    local badgeStyle = {
        color         = hx(color[1] * 120, color[2] * 120, color[3] * 120),
        backgroundColor = hx((color[1] * 0.3 + 0.66) * 255, (color[2] * 0.3 + 0.66) * 255, (color[3] * 0.3 + 0.66) * 255),
        borderColor   = hx(color[1] * 140, color[2] * 140, color[3] * 140),
    }

    local tiles = {}
    local tileData = { { "cash", "$25 000", "EFECTIVO" }, { "gold", "x5", "LINGOTES" }, { "crate", "+", "SUMINISTROS" } }
    for _, t in ipairs(tileData) do
        tiles[#tiles + 1] = { tag = "div", class = "tile", children = {
            { tag = "div", class = "ic", onPaint = paintIcon(t[1]) },
            { tag = "div", class = "val", text = t[2] },
            { tag = "div", class = "cap", text = t[3] },
        }}
    end

    local cta = { tag = "div", class = "action-row", children = {
        { tag = "div", class = ctaOn and "cta on" or "cta off",
          onClick = ctaOn and function() self:onAction() end or nil,
          children = {
              { tag = "div", class = "ic", onPaint = paintIcon("finger") },
              { tag = "div", text = ctaText },
          } },
    }}

    return { tag = "div", class = "pane detail-pane", children = {
        { tag = "div", class = "d-head", children = {
            { tag = "div", class = "d-title", children = {
                { tag = "div", class = "d-name", text = row.name },
                { tag = "div", class = "d-city", text = (heist and heist.destination) or "Knox Bank, Louisville" },
            }},
            { tag = "div", class = "badge", text = label, style = badgeStyle },
        }},
        { tag = "div", class = "sec", children = {
            { tag = "div", class = "sec-h", text = "OBJETIVO" },
            { tag = "div", class = "rule-soft" },
            { tag = "div", class = "grid", children = {
                { tag = "div", class = "body", text = (heist and heist.mission)
                    or "Adelantarse a la competencia. El banco mas grande de Kentucky, con la camara acorazada llena y las alarmas caidas por la evacuacion." },
                { tag = "div", class = "map", onPaint = paintMap((group and group.city) or "LOUISVILLE") },
            }},
        }},
        { tag = "div", class = "sec", children = {
            { tag = "div", class = "sec-h", text = "RECOMPENSA ESTIMADA" },
            { tag = "div", class = "rule-soft" },
            { tag = "div", class = "reward", children = tiles },
            { tag = "div", class = "body-soft", text = "5 lingotes de oro, 4 diamantes, 6 fajos, suministros de mid-game, municion y 2 niveles de Destreza." },
        }},
        cta,
    }}
end

local function docListNode(items)
    local docs = {}
    for _, it in ipairs(items) do
        docs[#docs + 1] = { tag = "div", class = "doc", children = {
            { tag = "div", class = "doc-ic", onPaint = function(node, owner, x, y, w, h)
                local s = math.min(w, h)
                drawIcon(owner, IC.notas, math.floor(x), y, math.floor(s), INK_SOFT)
            end },
            { tag = "div", class = "doc-txt", children = {
                { tag = "div", class = "doc-t", text = it.t },
                { tag = "div", class = "doc-d", text = it.d },
            }},
        }}
    end
    return { tag = "div", class = "doc-list", children = docs }
end

function LPComputer:stubNode()
    if self.app == "notas" then
        return { tag = "div", class = "pane detail-pane", children = { { tag = "div", class = "stub", children = {
            { tag = "div", class = "h", text = "NOTAS" },
            { tag = "div", class = "p", text = "Las notas y papeles que recogiste en el mundo. Se leen con la accion de lectura del juego antes de aparecer aqui completas." },
            docListNode(NOTES),
            { tag = "div", class = "note-card", text = "Diario de mision (tecla J). El libro de cuero con el indice de capitulos existe aparte de este terminal. Solo se abre durante el prologo y con una mision activa." },
        }}}}
    elseif self.app == "archivos" then
        return { tag = "div", class = "pane detail-pane", children = { { tag = "div", class = "stub", children = {
            { tag = "div", class = "h", text = "ARCHIVOS" },
            { tag = "div", class = "p", text = "Intel acumulada. Planos parciales, contactos y todo lo que sobrevivio a la evacuacion." },
            docListNode(ARCHIVES),
        }}}}
    else
        return { tag = "div", class = "pane detail-pane", children = { { tag = "div", class = "stub", children = {
            { tag = "div", class = "h", text = "SISTEMA" },
            { tag = "div", class = "p", text = "XCYOS v1.0.3 - Last Purpose Terminal. Reemplaza la mesa de planificacion: eliges el golpe aqui y, al volver del golpe, entregas el botin aqui." },
            { tag = "div", class = "note-card", text = "Las opciones del mod (tecla del diario, registro de depuracion, etc.) estan en el menu del juego: Opciones > Mods > Last Purpose. No se configuran desde este terminal." },
        }}}}
    end
end

function LPComputer:contentTree()
    if self.app == "misiones" then
        return { tag = "div", class = "root", children = { self:listPaneNode(), self:detailPaneNode() } }
    end
    return { tag = "div", class = "root", children = { self:stubNode() } }
end

-- ---- botones (solo la X; el CTA vive en el arbol) -----------------

function LPComputer:createChildren()
    ISPanel.createChildren(self)
    self:layout()
    ensureFontsRegistered()

    local cx, cy, cw, ch = self:zone(SKIN.titleClose)
    self.closeButton = ISButton:new(cx, cy, cw, ch, "", self, LPComputer.onClose)
    self.closeButton:initialise(); self.closeButton:instantiate()
    self.closeButton.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    self.closeButton.backgroundColorMouseOver = { r = 0.85, g = 0.16, b = 0.13, a = 0.25 }
    self.closeButton.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    self.closeButton.textColor = { r = 0, g = 0, b = 0, a = 0 }
    self:addChild(self.closeButton)
end

function LPComputer:onAction()
    local player = LastPurpose.getPlayerSafe(0)
    if not player then return end
    if not LastPurpose.stageIs(LastPurpose.getData(player), "review_loot") then return end
    local ok = pcall(function() LastPurpose.reviewHeistLoot(player) end)
    if not ok then print("[LastPurpose] ERROR al entregar el botin desde el ordenador") end
    if LastPurpose.stageIs(LastPurpose.getData(player), "completed") then
        self:onClose()
    else
        self:markDirty()
    end
end

function LPComputer:onClose()
    self:setVisible(false)
    self:removeFromUIManager()
    if LastPurpose.computer == self then LastPurpose.computer = nil end
end

-- ---- entrada -----------------------------------------------------

function LPComputer:onMouseDown(x, y)
    for _, hb in ipairs(self.appHitboxes or {}) do
        if x >= hb.x and x <= hb.x + hb.w and y >= hb.y and y <= hb.y + hb.h then
            if self.app ~= hb.id then self.app = hb.id; self:markDirty() end
            return true
        end
    end
    if self._contentTree then
        local n = self._contentTree:hit(x, y)
        if n and n.onClick then
            pcall(n.onClick, n)
            return true
        end
    end
    -- La GUI ocupa toda la pantalla y NO se cierra al hacer clic fuera de un
    -- elemento: solo con la X o con ESC. Se consume el clic para que no
    -- llegue al mundo por debajo.
    return true
end

function LPComputer:onMouseDownOutside(x, y)
    -- No cerrar. (A pantalla completa no hay "fuera", pero se deja explicito.)
end

-- ---- pintado ---------------------------------------------------

function LPComputer:prerender()
    ISPanel.prerender(self)
    if self.renderBroken then return end
    local ok, err = pcall(function() self:paint() end)
    if not ok then
        self.renderBroken = true
        print("[LastPurpose] ERROR pintando el ordenador (se detiene el dibujo): " .. tostring(err))
    end
end

local TITLE_BY_APP = {
    misiones = "LAST PURPOSE // ARCHIVO DE MISIONES",
    notas    = "LAST PURPOSE // NOTAS",
    archivos = "LAST PURPOSE // ARCHIVOS",
    sistema  = "LAST PURPOSE // SISTEMA",
}

function LPComputer:paint()
    if not self.sx then self:layout() end
    ensureFontsRegistered()

    local chrome = tex("xcyos_chrome.png")
    if chrome then
        self:drawTextureScaled(chrome, 0, 0, self.width, self.height, 1, 1, 1, 1)
    else
        self:drawRect(0, 0, self.width, self.height, 1, DESKTOP[1], DESKTOP[2], DESKTOP[3])
    end

    -- Titulo: el chrome trae la franja en blanco; lo dibujamos nosotros
    -- para todas las apps.
    do
        local tx, ty, tw, th = self:zone(SKIN.titleText)
        local _, lh = KeyasUI.measure("Mg", "lp_ui_18")
        KeyasUI.text(self, TITLE_BY_APP[self.app] or "LAST PURPOSE",
            tx, ty + math.floor((th - (lh or 22)) / 2),
            { r = TITLE_INK[1], g = TITLE_INK[2], b = TITLE_INK[3], a = 1 }, "lp_ui_18")
    end

    -- Rail: 4 pestanas dibujadas por nosotros (el chrome nuevo no las trae).
    for i, app in ipairs(APPS) do
        local rx, ry, rw, rh = self:zone(SKIN.rail[i])
        local active = (self.app == app.id)
        if active then
            self:drawRect(rx, ry, rw, rh, 0.16, PHOSPHOR[1], PHOSPHOR[2], PHOSPHOR[3])
            self:drawRectBorder(rx, ry, rw, rh, 1, PH_DIM[1], PH_DIM[2], PH_DIM[3])
        else
            self:drawRect(rx, ry, rw, rh, 0.10, 1, 1, 1)
            self:drawRectBorder(rx, ry, rw, rh, 0.35, 0, 0, 0)
        end
        local isz = math.floor(rh * 0.42)
        drawIcon(self, IC[app.id] or 0,
            rx + math.floor((rw - isz) / 2), ry + math.floor(rh * 0.14), isz,
            active and RAIL_ON or RAIL_OFF)
        local lbl = app.label
        local lw = (KeyasUI and KeyasUI.measure and (KeyasUI.measure(lbl, "lp_ui_14"))) or (#lbl * 6)
        local lc = active and RAIL_ON or RAIL_LBL_OFF
        KeyasUI.text(self, lbl, rx + math.floor((rw - lw) / 2), ry + rh - math.floor(rh * 0.30),
            { r = lc[1], g = lc[2], b = lc[3], a = 1 }, "lp_ui_14")
    end

    -- Contenido KeyasCSS. El arbol solo se reconstruye/re-maqueta cuando
    -- cambia el estado o el tamano (no cada frame): asi no hay lag al
    -- clicar entre opciones. Cada frame solo se re-pinta el arbol cacheado.
    local cx, cy, cw, chh = self:zone(SKIN.content)
    local rectKey = cx .. "," .. cy .. "," .. cw .. "," .. chh
    if self._treeDirty or not self._contentTree or self._rectKey ~= rectKey then
        local ok, tree = pcall(function()
            local t = KeyasCSS.node(self:contentTree())
            t:resolve(self.sheet)
            t:layout(cx, cy, cw, chh)
            return t
        end)
        self._contentTree = ok and tree or nil
        self._treeDirty = false
        self._rectKey = rectKey
        self._paintFails = 0   -- arbol nuevo: se vuelve a intentar pintar
    end
    if self._contentTree and (self._paintFails or 0) < 3 then
        local ok, err = pcall(function() self._contentTree:paint(self) end)
        if not ok then
            self._paintFails = (self._paintFails or 0) + 1
            if self._paintFails == 3 then
                print("[LastPurpose] ERROR pintando el contenido del ordenador (se deja de intentar): " .. tostring(err))
            end
        end
    end
end

-- ---- apertura desde el menu contextual de la mesa ---------------

function LastPurpose.openComputer(player)
    player = player or LastPurpose.getPlayerSafe(0)
    if not player or not LastPurpose.isBurglar(player) then return end
    if LastPurpose.computer then LastPurpose.computer:onClose() end

    local ok, panel = pcall(function()
        local p = LPComputer:new()
        p:initialise()
        p:instantiate()
        p:addToUIManager()
        return p
    end)
    if ok and panel then
        LastPurpose.computer = panel
        LastPurpose.debugPrint("Ordenador de la mesa abierto")
    else
        print("[LastPurpose] ERROR abriendo el ordenador: " .. tostring(panel))
    end
end

if not LastPurpose.computerKeyHook then
    LastPurpose.computerKeyHook = true
    Events.OnKeyPressed.Add(function(key)
        -- ESC cierra la GUI si esta abierta.
        if key == Keyboard.KEY_ESCAPE and LastPurpose.computer then
            LastPurpose.computer:onClose()
            return
        end
        -- E abre la GUI SOLO si el jugador esta pegado a la mesa (casilla
        -- adyacente, como interactuar con un vehiculo). No hace nada si ya
        -- esta abierta, si no es Ladron, o si hay un menu contextual abierto.
        if key == Keyboard.KEY_E and not LastPurpose.computer then
            local ok = pcall(function()
                local player = LastPurpose.getPlayerSafe(0)
                if not player or player:isDead() then return end
                if not LastPurpose.isBurglar(player) then return end
                if ISContextMenu and ISContextMenu.instance and ISContextMenu.instance.visibleCheck then return end
                if not LastPurpose.findNearbyTable then return end
                local sq = select(1, LastPurpose.findNearbyTable(player))
                if not sq then return end
                -- adyacente: centro de la casilla de la mesa a <= ~1.5 tiles
                local dx = (sq:getX() + 0.5) - player:getX()
                local dy = (sq:getY() + 0.5) - player:getY()
                if (dx * dx + dy * dy) > 2.5 then return end
                LastPurpose.openComputer(player)
            end)
            if not ok then LastPurpose.debugPrint("Fallo el atajo E de la mesa") end
        end
    end)
end
