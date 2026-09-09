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

-- Paleta terminal (hex del mockup XCYOS).
local DESKTOP   = { 0.106, 0.125, 0.118 }
local WINFACE   = { 0.725, 0.714, 0.678 }
local INK       = { 0.086, 0.086, 0.059 }
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
local function drawIcon(self, n, x, y, size, c)
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
local BAKE_W, BAKE_H = 1920, 1080
-- Medido sobre el xcyos_chrome.png de ChatGPT (sigue GUI_ASSETS.md al pixel).
local SKIN = {
    win        = { 172, 60, 1372, 918 },     -- generoso a proposito: clic fuera de aqui = cerrar
    content    = { 202, 112, 1310, 828 },    -- rectangulo oscuro del PNG; lo pinta KeyasCSS
    titleClose = { 1506, 62, 34, 30 },       -- glifo X de la barra de titulo
    rail       = { { 19, 39, 133, 93 }, { 19, 149, 133, 93 }, { 19, 261, 133, 93 }, { 19, 373, 133, 93 } },
}

-- Hoja de estilos del CONTENIDO. Escrita en espacio 1920; KeyasCSS.parse la
-- escala por self.s en layout(). Un color de panel algo mas oscuro que la
-- cara de la ventana + borde visible + una sombra suave = profundidad sin
-- biseles inset (que ISUI no tiene).
local CONTENT_CSS = [[
  .root { display: flex; flex-direction: row; gap: 16px; height: 100%; }

  .pane {
    background: #c4c1b6; border: 2px solid #6d6a61; border-radius: 6px;
    box-shadow: 0 6px 18px rgba(0,0,0,0.28);
    overflow: hidden; height: 100%; display: flex; flex-direction: column;
  }
  .list-pane { width: 320px; padding: 14px 8px 14px 14px; }
  .detail-pane { flex-grow: 1; padding: 22px 26px; }

  .city { display: flex; flex-direction: column; margin-top: 16px; }
  .city.first { margin-top: 2px; }
  .city-title { font: lp_ui_14; color: #16160f; padding-bottom: 4px; }
  .rule { height: 2px; background: #16160f; }
  .rule-soft { height: 1px; background: #8f8c82; }
  .city-hint { font: lp_ui_14; color: #7c7a70; margin-top: 7px; }

  .missions { display: flex; flex-direction: column; margin-top: 6px; }
  .m-row {
    display: flex; flex-direction: row; align-items: center; gap: 10px;
    padding: 7px 10px 7px 10px; border-radius: 5px;
    border: 1px solid transparent; font: lp_ui_18; color: #16160f;
  }
  .m-row .num { width: 26px; font: lp_mono_16; color: #4a473c; }
  .m-row .m-name { flex-grow: 1; }
  .m-row .dot { width: 11px; height: 11px; border-radius: 6px; }
  .dot.ok    { background: #56b45a; }
  .dot.prog  { background: #ffb64a; }
  .dot.lock  { background: #7c7a70; }
  .dot.claim { background: #2fe7c4; }
  .m-row.locked { color: #7c7a70; }
  .m-row.locked .num { color: #7c7a70; }
  .m-row.sel {
    background: #223330; color: #eafffb;
    border: 1px solid #2fe7c4;
  }
  .m-row.sel .num { color: #2fe7c4; }

  .d-head { display: flex; flex-direction: row; align-items: flex-start; gap: 14px; }
  .d-title { flex-grow: 1; display: flex; flex-direction: column; gap: 5px; }
  .d-name { font: lp_ui_30; color: #16160f; }
  .d-city { font: lp_ui_14; color: #4a473c; }
  .badge {
    font: lp_ui_14; padding: 6px 12px; border-radius: 4px;
    border: 1px solid #16160f;
  }

  .sec { margin-top: 24px; display: flex; flex-direction: column; }
  .sec-h { font: lp_ui_14; color: #16160f; padding-bottom: 5px; }
  .sec .rule-soft { margin-bottom: 10px; }
  .grid { display: flex; flex-direction: row; gap: 22px; align-items: flex-start; }
  .body { font: lp_ui_18; color: #16160f; line-height: 26px; flex-grow: 1; }
  .body-soft { font: lp_ui_14; color: #4a473c; line-height: 22px; margin-top: 12px; }

  .map {
    width: 260px; height: 210px; border: 2px solid #16160f;
    border-radius: 4px; background: #d0cdc3;
    box-shadow: 0 4px 12px rgba(0,0,0,0.25);
  }

  .reward { display: flex; flex-direction: row; gap: 14px; margin-top: 8px; }
  .tile {
    width: 138px; padding: 12px 8px 10px; border: 2px solid #16160f;
    border-radius: 6px; background: #b9b6ad;
    box-shadow: 4px 4px 0 rgba(22,22,15,0.65);
    display: flex; flex-direction: column; align-items: center; gap: 6px;
  }
  .tile .ic { width: 40px; height: 34px; }
  .tile .val { font: lp_mono_16; color: #16160f; }
  .tile .cap { font: lp_ui_14; color: #4a473c; }

  .action-row { display: flex; flex-direction: row; margin-top: 26px; }
  .cta {
    display: flex; flex-direction: row; align-items: center; gap: 14px;
    padding: 12px 20px 12px 12px;
    border: 2px solid #16160f; border-radius: 4px; background: #cbc8bf;
    box-shadow: 4px 4px 0 rgba(22,22,15,1);
    font: lp_ui_18; color: #16160f;
  }
  .cta .ic { width: 30px; height: 30px; }
  .cta.on { background: #bff2e8; }
  .cta.off { opacity: 0.5; }

  .stub { flex-grow: 1; display: flex; flex-direction: column; }
  .stub .h { font: lp_ui_30; color: #16160f; }
  .stub .p { font: lp_ui_18; color: #4a473c; line-height: 26px; margin-top: 14px; }
  .stub .k {
    font: lp_mono_16; color: #16160f; margin-top: 16px;
    border: 1px solid #16160f; border-radius: 3px; background: #cbc8bf;
    padding: 6px 12px;
  }
]]

-- ---------------------------------------------------------------------------

LPComputer = ISPanel:derive("LPComputer")

function LPComputer:new()
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    -- ~90% de la pantalla, misma proporcion que el PNG, centrado. Por debajo
    -- del tamano de pantalla -> PZ no oscurece el juego.
    local scale = math.min(sw * 0.90 / BAKE_W, sh * 0.90 / BAKE_H)
    local w = math.floor(BAKE_W * scale)
    local h = math.floor(BAKE_H * scale)
    local o = ISPanel:new(math.floor((sw - w) / 2), math.floor((sh - h) / 2), w, h)
    setmetatable(o, self)
    self.__index = self
    o.background = false
    o.moveWithMouse = false
    o.app = "misiones"
    o.selectedId = "louisville_knox_bank"
    o.appHitboxes = {}
    return o
end

function LPComputer:zone(bake)
    local s = self.s or (self.width / BAKE_W)
    return math.floor(bake[1] * s), math.floor(bake[2] * s),
           math.floor(bake[3] * s), math.floor(bake[4] * s)
end

function LPComputer:layout()
    self.s = self.width / BAKE_W
    self.appHitboxes = {}
    for i, app in ipairs(APPS) do
        local rx, ry, rw, rh = self:zone(SKIN.rail[i])
        self.appHitboxes[i] = { id = app.id, x = rx, y = ry, w = rw, h = rh }
    end
    self.sheet = KeyasCSS.parse(CONTENT_CSS, { scale = self.s })
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

function LPComputer:listPaneNode()
    local player = LastPurpose.getPlayerSafe(0)
    local data = player and LastPurpose.getData(player)
    local children = {}
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
                onClick = function()
                    self.selectedId = rid
                    self:refreshAction()
                end,
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
        children[#children + 1] = { tag = "div", class = (gi == 1) and "city first" or "city", children = kids }
    end
    return { tag = "div", class = "pane list-pane", children = children }
end

function LPComputer:detailPaneNode()
    local player = LastPurpose.getPlayerSafe(0)
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

function LPComputer:stubNode()
    local title, body, key
    if self.app == "notas" then
        title = "NOTAS"
        body = "Las notas cifradas que recogiste en el mundo aparecen aca una vez leidas. El diario de mision (tecla J) sigue siendo aparte: solo se abre en el prologo y con una mision activa."
    elseif self.app == "archivos" then
        title = "ARCHIVOS"
        body = "Intel acumulada: planos parciales del Knox Bank, contacto de la radio, catalogo de golpes de Louisville. La mesa con ordenador fija tu refugio."
    else
        title = "SISTEMA"
        body = "Opciones del mod (Opciones > Mods > Last Purpose). El registro de depuracion esta " ..
            (LastPurpose.DEBUG and "activado" or "desactivado") .. ". XCYOS v1.0.3 - Last Purpose Terminal."
        key = "Tecla del diario:  J"
    end
    local kids = {
        { tag = "div", class = "h", text = title },
        { tag = "div", class = "p", text = body },
    }
    if key then kids[#kids + 1] = { tag = "div", class = "k", text = key } end
    return { tag = "div", class = "pane detail-pane", children = { { tag = "div", class = "stub", children = kids } } }
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

function LPComputer:refreshAction()
    -- El CTA se reconstruye con el arbol cada frame; nada que hacer aqui,
    -- pero se conserva el metodo porque lo llaman los onClick de las filas.
end

function LPComputer:onAction()
    local player = LastPurpose.getPlayerSafe(0)
    if not player then return end
    if not LastPurpose.stageIs(LastPurpose.getData(player), "review_loot") then return end
    local ok = pcall(function() LastPurpose.reviewHeistLoot(player) end)
    if not ok then print("[LastPurpose] ERROR al entregar el botin desde el ordenador") end
    if LastPurpose.stageIs(LastPurpose.getData(player), "completed") then
        self:onClose()
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
            self.app = hb.id
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
    local wx, wy, ww, wh = self:zone(SKIN.win)
    if x < wx or x > wx + ww or y < wy or y > wy + wh then
        self:onClose()
        return true
    end
    return ISPanel.onMouseDown(self, x, y)
end

function LPComputer:onMouseDownOutside(x, y)
    self:onClose()
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

function LPComputer:paint()
    if not self.s then self:layout() end
    ensureFontsRegistered()

    local chrome = tex("xcyos_chrome.png")
    if chrome then
        self:drawTextureScaled(chrome, 0, 0, self.width, self.height, 1, 1, 1, 1)
    else
        self:drawRect(0, 0, self.width, self.height, 1, DESKTOP[1], DESKTOP[2], DESKTOP[3])
    end

    for i, app in ipairs(APPS) do
        if self.app == app.id then
            local rx, ry, rw, rh = self:zone(SKIN.rail[i])
            self:drawRect(rx, ry, rw, rh, 0.16, PHOSPHOR[1], PHOSPHOR[2], PHOSPHOR[3])
            self:drawRectBorder(rx, ry, rw, rh, 1, PH_DIM[1], PH_DIM[2], PH_DIM[3])
        end
    end

    local cx, cy, cw, chh = self:zone(SKIN.content)
    local ok, tree = pcall(function()
        local t = KeyasCSS.node(self:contentTree())
        t:resolve(self.sheet)
        t:layout(cx, cy, cw, chh)
        t:paint(self)
        return t
    end)
    self._contentTree = ok and tree or nil
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
        if key == Keyboard.KEY_ESCAPE and LastPurpose.computer then
            LastPurpose.computer:onClose()
        end
    end)
end
