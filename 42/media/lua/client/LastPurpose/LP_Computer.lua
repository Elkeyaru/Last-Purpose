require "ISUI/ISPanel"
require "ISUI/ISButton"
require "LastPurpose/LP_TermFontData"
require "KeyasLib/KeyasUI"
require "KeyasLib/KeyasCSS"

-- ---------------------------------------------------------------------------
-- LP_Computer.lua - Hito 1 del hub del ordenador (roadmap punto 2).
--
-- La mesa de planificacion es "la mesa con ordenador": misma pieza, misma
-- receta salvo que ahora pide chatarra electronica. Su menu contextual abre
-- esta GUI, un archivo de misiones estilo SO retro. Por ahora es de SOLO
-- LECTURA: lista el catalogo y, en la etapa review_loot, entrega el botin
-- llamando a LastPurpose.reviewHeistLoot (ese flujo no se reescribio). El
-- diario (tecla J) sigue aparte para prologo/mision activa.
--
-- ESTRUCTURA (desde v1.2.x):
--   * El CHROME fijo (bisel CRT, escritorio, marco de ventana, barra de
--     titulo con degradado, franja, logo, vinneta, barra de estado) se
--     dibuja de una sola pieza desde xcyos_chrome.png -> arte horneado.
--   * El CONTENIDO (lista de misiones, panel de detalle, badges, tiles de
--     recompensa, apps Notas/Archivos/Sistema) se describe como un arbol de
--     cajas con hoja de estilos y lo maqueta/pinta KeyasCSS (KeyasLib).
--     Esquinas redondeadas, degradados y sombras que ISUI no dibuja salen
--     de KeyasCSS. Ver KeyasLib/MIGRATION.md seccion 0.
-- ---------------------------------------------------------------------------

LastPurpose = LastPurpose or {}

local REDACTED = "?????????"

-- Catalogo de PANTALLA. El unico golpe "real" hoy es louisville_knox_bank
-- (vive en LastPurpose.HEISTS); el resto se muestra censurado.
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

-- Paleta terminal. Hex exactos del mockup XCYOS (una sola: es una pantalla
-- dentro del juego, sin tema claro/oscuro).
local SCREEN    = { 0.043, 0.059, 0.051 }
local DESKTOP   = { 0.106, 0.125, 0.118 }
local WINFACE   = { 0.725, 0.714, 0.678 }
local WIN_HI    = { 0.933, 0.925, 0.894 }
local WIN_LO    = { 0.427, 0.416, 0.380 }
local INK       = { 0.086, 0.086, 0.059 }
local INK_SOFT  = { 0.290, 0.278, 0.235 }
local PHOSPHOR  = { 0.184, 0.906, 0.769 }
local PH_DIM    = { 0.110, 0.561, 0.486 }
local OKC       = { 0.337, 0.706, 0.353 }
local AMBER     = { 1.000, 0.714, 0.290 }
local LOCKC     = { 0.486, 0.478, 0.439 }

-- Texturas (assets/Gemini procesados). Cada una tiene fallback dibujado.
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

-- Dibuja un icono de la hoja procesada, tintado con `c`. Fallback: glifo de
-- rectangulos. (Se usa desde los hooks onPaint del arbol KeyasCSS.)
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
    KeyasUI.registerFont("lp_term_18", {
        atlasPath = "media/ui/LastPurpose/lp_term_18_0.png",
        metrics = LP_TermFontData[18], size = 18,
    })
    KeyasUI.registerFont("lp_term_26", {
        atlasPath = "media/ui/LastPurpose/lp_term_26_0.png",
        metrics = LP_TermFontData[26], size = 26,
    })
    FONTS_REGISTERED = true
end

-- ---- estado de la mision ------------------------------------------------

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
local SKIN = {
    win        = { 172, 60, 1372, 918 },
    content    = { 202, 116, 1306, 812 },   -- listPane .. detailPane en una sola caja para KeyasCSS
    titleClose = { 1516, 62, 24, 26 },
    rail       = { { 22, 22, 128, 88 }, { 22, 140, 128, 88 }, { 22, 258, 128, 88 }, { 22, 376, 128, 88 } },
}

-- Hoja de estilos del CONTENIDO. Se escribe en el espacio del PNG (1920) y
-- KeyasCSS.parse la escala por self.s en layout(). Colores = hex del mockup.
local CONTENT_CSS = [[
  .root { display: flex; flex-direction: row; gap: 14px; }

  .list-pane {
    width: 300px; background: #cbc8bf; border: 1px solid #6d6a61;
    border-radius: 4px; overflow: hidden; padding: 12px 6px 12px 12px;
    display: flex; flex-direction: column;
  }
  .detail-pane {
    flex-grow: 1; background: #cbc8bf; border: 1px solid #6d6a61;
    border-radius: 4px; overflow: hidden; padding: 20px 22px;
    display: flex; flex-direction: column;
  }

  .city { display: flex; flex-direction: column; margin-top: 14px; }
  .city-title { font: lp_term_18; color: #16160f; padding-bottom: 3px; }
  .rule { height: 2px; background: #16160f; }
  .rule-soft { height: 1px; background: #6d6a61; margin-bottom: 8px; }
  .city-hint { font: lp_term_18; color: #7c7a70; margin-top: 6px; }

  .missions { display: flex; flex-direction: column; margin-top: 4px; }
  .m-row {
    display: flex; flex-direction: row; align-items: center; gap: 8px;
    padding: 5px 10px 5px 9px; border-radius: 4px;
    border: 1px solid transparent; font: lp_term_18; color: #16160f;
  }
  .m-row .num { width: 22px; color: #4a473c; }
  .m-row .m-name { flex-grow: 1; }
  .m-row .dot { width: 10px; height: 10px; border-radius: 5px; }
  .dot.ok    { background: #56b45a; }
  .dot.prog  { background: #ffb64a; }
  .dot.lock  { background: #7c7a70; }
  .dot.claim { background: #2fe7c4; }
  .m-row.locked { color: #7c7a70; }
  .m-row.locked .num { color: #7c7a70; }
  .m-row.sel {
    background: #2f3f3a; color: #eafffb; border: 1px solid #2fe7c4;
  }
  .m-row.sel .num { color: #2fe7c4; }

  .d-head { display: flex; flex-direction: row; align-items: flex-start; gap: 12px; }
  .d-title { flex-grow: 1; display: flex; flex-direction: column; gap: 6px; }
  .d-name { font: lp_term_26; color: #16160f; }
  .d-city { font: lp_term_18; color: #4a473c; }
  .badge {
    font: lp_term_18; padding: 4px 10px; border-radius: 3px;
    border: 1px solid #4a473c;
  }

  .sec { margin-top: 22px; display: flex; flex-direction: column; }
  .sec-h { font: lp_term_18; color: #16160f; padding-bottom: 4px; }
  .grid { display: flex; flex-direction: row; gap: 18px; align-items: flex-start; }
  .body { font: lp_term_18; color: #16160f; line-height: 24px; flex-grow: 1; }
  .body-soft { font: lp_term_18; color: #4a473c; line-height: 24px; margin-top: 10px; }

  .map { width: 240px; height: 200px; border: 1px solid #16160f;
         border-radius: 3px; background: #d0cdc3; }

  .reward { display: flex; flex-direction: row; gap: 12px; margin-top: 6px; }
  .tile {
    width: 128px; padding: 10px 6px 8px; border: 1px solid #16160f;
    border-radius: 4px; background: #b9b6ad;
    box-shadow: 3px 3px 0 rgba(22,22,15,0.55);
    display: flex; flex-direction: column; align-items: center; gap: 4px;
  }
  .tile .ic { width: 40px; height: 34px; }

  .stub { flex-grow: 1; background: #cbc8bf; border: 1px solid #6d6a61;
          border-radius: 4px; padding: 22px 26px; display: flex; flex-direction: column; }
  .stub h { font: lp_term_26; color: #16160f; }
  .stub p { font: lp_term_18; color: #4a473c; line-height: 24px; margin-top: 12px; }
]]

-- ---------------------------------------------------------------------------

LPComputer = ISPanel:derive("LPComputer")

function LPComputer:new()
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    -- Panel con la MISMA proporcion que el PNG (16:9), centrado, ~95% de la
    -- pantalla. No es del tamano de la pantalla -> PZ no pausa ni oscurece.
    local scale = math.min(sw * 0.95 / BAKE_W, sh * 0.95 / BAKE_H)
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
    local dx, dy, dw, dh = self:zone(SKIN.content)
    self.actionRect = { x = dx + dw - 240, y = dy + dh + math.floor(8 * self.s), w = 228, h = 36 }
    -- (Re)parsea la hoja a la escala actual.
    self.sheet = KeyasCSS.parse(CONTENT_CSS, { scale = self.s })
end

-- ---- helpers para hooks onPaint del arbol ----------------------------

local function paintIcon(name)
    return function(node, owner, x, y, w, h)
        local s = math.min(w, h)
        drawIcon(owner, IC[name] or IC.crate, math.floor(x + (w - s) / 2), math.floor(y), math.floor(s), INK)
    end
end

-- Mini-mapa estilizado con primitivas (el mockup usa un SVG).
local function paintMap(label)
    return function(node, owner, x, y, w, h)
        owner:drawRect(x, y, w, h, 1, 0.812, 0.796, 0.749)
        local gc = { 0.55, 0.53, 0.49 }
        for gx = x + 16, x + w - 8, 26 do owner:drawRect(gx, y + 2, 1, h - 4, 1, gc[1], gc[2], gc[3]) end
        for gy = y + 16, y + h - 8, 24 do owner:drawRect(x + 2, gy, w - 4, 1, 1, gc[1], gc[2], gc[3]) end
        owner:drawRect(x + 6, y + math.floor(h * 0.62), math.floor(w * 0.5), 2, 1, 0.42, 0.40, 0.36)
        local ox, oy = x + math.floor(w * 0.52), y + math.floor(h * 0.42)
        owner:drawRectBorder(ox - 8, oy - 7, 16, 14, 1, 0.36, 0.35, 0.31)
        owner:drawRect(ox + 18, oy + 8, 1, 22, 1, INK[1], INK[2], INK[3])
        owner:drawRect(ox + 8, oy + 18, 22, 1, 1, INK[1], INK[2], INK[3])
        owner:drawRectBorder(ox + 12, oy + 12, 14, 14, 1, INK[1], INK[2], INK[3])
        KeyasUI.text(owner, tostring(label or ""), x + 6, y + 4, { r = 0.16, g = 0.16, b = 0.13, a = 1 }, "lp_term_18")
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
    elseif label == "EN CURSO" then return "prog"
    elseif label == "EN PREPARACION" then return "prog" end
    return "ok"
end

function LPComputer:listPaneNode()
    local player = LastPurpose.getPlayerSafe(0)
    local data = player and LastPurpose.getData(player)
    local children = {}
    for _, group in ipairs(CATALOG) do
        local rows = {}
        for i, row in ipairs(group.rows) do
            local sel = row.id == self.selectedId
            local cls = "m-row"
            if not row.unlocked then cls = cls .. " locked" end
            if sel then cls = cls .. " sel" end
            local dot = row.unlocked and (data and dotClass((knoxStatus(data))) or "ok") or "lock"
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
        children[#children + 1] = { tag = "div", class = "city", children = kids }
    end
    return { tag = "div", class = "list-pane", children = children }
end

function LPComputer:detailPaneNode()
    local player = LastPurpose.getPlayerSafe(0)
    local row, group = self:selectedRow()
    if not row then return { tag = "div", class = "detail-pane" } end

    if not row.unlocked then
        return { tag = "div", class = "detail-pane", children = {
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
    local label, color = "DISPONIBLE", PH_DIM
    if data then label, color = knoxStatus(data) end
    local function hex255(r, g, b) return string.format("#%02x%02x%02x",
        math.max(0, math.min(255, math.floor(r))), math.max(0, math.min(255, math.floor(g))),
        math.max(0, math.min(255, math.floor(b)))) end
    local badgeStyle = {
        color         = hex255(color[1] * 128, color[2] * 128, color[3] * 128),
        backgroundColor = hex255((color[1] * 0.35 + 0.62) * 255, (color[2] * 0.35 + 0.62) * 255, (color[3] * 0.35 + 0.62) * 255),
        borderColor   = hex255(color[1] * 153, color[2] * 153, color[3] * 153),
    }

    local tiles = {}
    local tileData = { { "cash", "$25 000", "EFECTIVO" }, { "gold", "x5", "LINGOTES" }, { "crate", "+", "SUMINISTROS" } }
    for _, t in ipairs(tileData) do
        tiles[#tiles + 1] = { tag = "div", class = "tile", children = {
            { tag = "div", class = "ic", onPaint = paintIcon(t[1]) },
            { tag = "div", text = t[2], style = { font = "lp_term_18", color = "#16160f" } },
            { tag = "div", text = t[3], style = { font = "lp_term_18", color = "#4a473c" } },
        }}
    end

    return { tag = "div", class = "detail-pane", children = {
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
                    or "Adelantarse a la competencia. El banco mas grande de Kentucky." },
                { tag = "div", class = "map", onPaint = paintMap((group and group.city) or "LOUISVILLE") },
            }},
        }},
        { tag = "div", class = "sec", children = {
            { tag = "div", class = "sec-h", text = "RECOMPENSA ESTIMADA" },
            { tag = "div", class = "rule-soft" },
            { tag = "div", class = "reward", children = tiles },
            { tag = "div", class = "body-soft", text = "5 lingotes de oro, 4 diamantes, 6 fajos, suministros de mid-game, municion y 2 niveles de Destreza." },
        }},
    }}
end

function LPComputer:stubNode()
    local title, body
    if self.app == "notas" then
        title = "NOTAS"
        body = "Las notas cifradas que recogiste en el mundo aparecen aca una vez leidas. El diario de mision (tecla J) sigue siendo aparte: solo se abre en el prologo y con una mision activa."
    elseif self.app == "archivos" then
        title = "ARCHIVOS"
        body = "Intel acumulada: planos parciales del Knox Bank, contacto de la radio, catalogo de golpes de Louisville. La mesa con ordenador fija tu refugio."
    else
        title = "SISTEMA"
        body = "Tecla del diario: J  (Opciones > Mods > Last Purpose).\nRegistro de depuracion: " ..
            (LastPurpose.DEBUG and "SI" or "NO") .. ".\nXCYOS v1.0.3  -  Last Purpose Terminal."
    end
    return { tag = "div", class = "stub", children = {
        { tag = "div", class = "h", text = title },
        { tag = "div", class = "p", text = body },
    }}
end

function LPComputer:contentTree()
    if self.app == "misiones" then
        return { tag = "div", class = "root", children = { self:listPaneNode(), self:detailPaneNode() } }
    end
    return { tag = "div", class = "root", children = { self:stubNode() } }
end

-- ---- botones (hijos ISButton) -------------------------------------

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

    local r = self.actionRect
    self.actionButton = ISButton:new(r.x, r.y, r.w, r.h, "", self, LPComputer.onAction)
    self.actionButton:initialise(); self.actionButton:instantiate()
    self.actionButton.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    self.actionButton.backgroundColorMouseOver = { r = 1, g = 1, b = 1, a = 0.06 }
    self.actionButton.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    self.actionButton.textColor = { r = 0, g = 0, b = 0, a = 0 }
    self:addChild(self.actionButton)

    self:refreshAction()
end

function LPComputer:refreshAction()
    local player = LastPurpose.getPlayerSafe(0)
    local row = self:selectedRow()
    local show = self.app == "misiones"
    if self.actionButton then self.actionButton:setVisible(show) end
    self.showAction = show
    if not show then return end
    if not player or not row or not row.unlocked then
        self.actionLabel, self.actionEnabled = "Bloqueada", false
    else
        local _, _, actionText, enabled = knoxStatus(LastPurpose.getData(player))
        self.actionLabel, self.actionEnabled = actionText, (enabled == true)
    end
    if self.actionButton then self.actionButton:setEnable(self.actionEnabled) end
end

function LPComputer:drawActionButton()
    if not self.showAction or not self.actionRect then return end
    local r = self.actionRect
    local on = self.actionEnabled
    local a = on and 1 or 0.55
    KeyasCSS.dropShadow(self, r.x, r.y, r.w, r.h, 4,
        { x = 3, y = 3, blur = 2, color = { r = INK[1], g = INK[2], b = INK[3], a = 0.5 * a } })
    KeyasCSS.roundedRect(self, r.x, r.y, r.w, r.h, 4, { r = WINFACE[1], g = WINFACE[2], b = WINFACE[3], a = a })
    if on then KeyasCSS.roundedRect(self, r.x, r.y, r.w, r.h, 4, { r = PHOSPHOR[1], g = PHOSPHOR[2], b = PHOSPHOR[3], a = 0.22 }) end
    self:drawRectBorder(r.x, r.y, r.w, r.h, a, INK[1], INK[2], INK[3])
    drawIcon(self, IC.finger, r.x + 8, r.y + 4, 28, INK)
    local lbl = self.actionLabel or ""
    local lw = (KeyasUI and KeyasUI.measure and (KeyasUI.measure(lbl, "lp_term_18"))) or 0
    KeyasUI.text(self, lbl, r.x + 44 + math.floor((r.w - 44 - lw) / 2), r.y + 9,
        { r = INK[1], g = INK[2], b = INK[3], a = 1 }, "lp_term_18")
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
        self:refreshAction()
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
            self:refreshAction()
            return true
        end
    end
    -- contenido: delega en el arbol KeyasCSS del ultimo frame
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

    -- resaltado del icono activo de la barra lateral
    for i, app in ipairs(APPS) do
        if self.app == app.id then
            local rx, ry, rw, rh = self:zone(SKIN.rail[i])
            self:drawRect(rx, ry, rw, rh, 0.14, PHOSPHOR[1], PHOSPHOR[2], PHOSPHOR[3])
            self:drawRectBorder(rx, ry, rw, rh, 1, PH_DIM[1], PH_DIM[2], PH_DIM[3])
        end
    end

    -- CONTENIDO: arbol KeyasCSS maquetado en la zona de contenido.
    local cx, cy, cw, chh = self:zone(SKIN.content)
    local ok, tree = pcall(function()
        local t = KeyasCSS.node(self:contentTree())
        t:resolve(self.sheet)
        t:layout(cx, cy, cw, chh)
        t:paint(self)
        return t
    end)
    if ok then self._contentTree = tree else self._contentTree = nil end

    if self.app == "misiones" then self:drawActionButton() end
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
        p:setAlwaysOnTop(true)
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
