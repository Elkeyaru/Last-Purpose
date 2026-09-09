require "ISUI/ISPanel"
require "ISUI/ISButton"
require "LastPurpose/LP_TermFontData"
require "KeyasLib/KeyasUI"

-- ---------------------------------------------------------------------------
-- LP_Computer.lua - Hito 1 del hub del ordenador (roadmap punto 2).
--
-- La mesa de planificacion es "la mesa con ordenador": misma pieza, misma
-- receta salvo que ahora pide chatarra electronica. Su menu contextual abre
-- esta GUI de pantalla completa, un archivo de misiones estilo SO retro.
-- Por ahora es de SOLO LECTURA: lista el catalogo y, en la etapa review_loot,
-- entrega el botin llamando a LastPurpose.reviewHeistLoot (ese flujo no se
-- reescribio). El diario (tecla J) sigue aparte para prologo/mision activa.
-- Seleccion de mision y desbloqueos por ciudad/profesion: hitos 2-5.
--
-- Project Zomboid solo da UIFont.Small/Medium/Large y primitivas planas
-- (drawRect/drawText), asi que esto es una aproximacion al mockup HTML, no
-- una copia: iconos vectoriales, la fuente pixel y el marco CRT curvo
-- necesitan PNGs, igual que el sprite de la mesa.
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

-- Paleta terminal. Una sola: es una pantalla dentro del juego.
local SCREEN    = { 0.050, 0.062, 0.056 }
local DESKTOP   = { 0.110, 0.132, 0.122 }
local WINFACE   = { 0.722, 0.706, 0.658 }
local WIN_HI    = { 0.906, 0.890, 0.836 }
local WIN_LO    = { 0.404, 0.392, 0.356 }
local PAGEFACE  = { 0.836, 0.820, 0.760 }
local TITLE_BG  = { 0.180, 0.235, 0.220 }
local INK       = { 0.086, 0.086, 0.058 }
local INK_SOFT  = { 0.300, 0.288, 0.240 }
local PHOSPHOR  = { 0.184, 0.902, 0.772 }
local PH_DIM    = { 0.102, 0.520, 0.462 }
local OKC       = { 0.300, 0.640, 0.320 }
local AMBER     = { 1.000, 0.712, 0.290 }
local LOCKC     = { 0.486, 0.478, 0.435 }
local STRIPE    = { {0.38,0.72,0.35}, {0.24,0.62,0.55}, {0.90,0.63,0.13}, {0.82,0.27,0.23} }

local RAIL_W = 96

-- Texturas (assets/Gemini procesados). Cada una tiene fallback dibujado, asi
-- que si un PNG falta o no carga la GUI sigue funcionando, solo mas pelada.
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

LPComputer = ISPanel:derive("LPComputer")

function LPComputer:new()
    local w, h = getCore():getScreenWidth(), getCore():getScreenHeight()
    local o = ISPanel:new(0, 0, w, h)
    setmetatable(o, self)
    self.__index = self
    o.background = false
    o.moveWithMouse = false
    o.app = "misiones"
    o.selectedId = "louisville_knox_bank"
    o.rowHitboxes = {}
    o.appHitboxes = {}
    return o
end

function LPComputer:layout()
    local sw, sh = self.width, self.height
    self.statusY = sh - 24
    local winX = RAIL_W + 40
    local winW = math.min(sw - winX - 60, 900)
    local winH = math.min(self.statusY - 80, 540)
    local winY = math.max(40, math.floor((self.statusY - winH) / 2) - 8)
    self.win = { x = winX, y = winY, w = winW, h = winH }
end

-- ---- helpers de pintado ------------------------------------------------

local function rect(self, x, y, w, h, c, a)
    self:drawRect(x, y, w, h, a or 1, c[1], c[2], c[3])
end

local function bevel(self, x, y, w, h, face, raised)
    local hi = raised ~= false and WIN_HI or WIN_LO
    local lo = raised ~= false and WIN_LO or WIN_HI
    rect(self, x, y, w, h, face)
    rect(self, x, y, w, 1, hi)
    rect(self, x, y, 1, h, hi)
    rect(self, x, y + h - 1, w, 1, lo)
    rect(self, x + w - 1, y, 1, h, lo)
end

-- ---- fuente de terminal (VT323) via KeyasUI --------------------------
-- El renderizado glifo-a-glifo desde el atlas ahora vive en KeyasUI
-- (KeyasLib). Aca solo registramos nuestras dos fuentes una vez y
-- enrutamos los helpers de este archivo por KeyasUI.text/measure. Si
-- KeyasUI o el atlas no estan, KeyasUI cae a UIFont solo; y si KeyasUI ni
-- siquiera cargo (dependencia ausente), estos helpers caen a drawText.
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

local function fontIdOf(font) return (font == UIFont.Large) and "lp_term_26" or "lp_term_18" end

local function measure(str, font)
    ensureFontsRegistered()
    if KeyasUI and KeyasUI.measure then
        return (KeyasUI.measure(tostring(str), fontIdOf(font)))
    end
    return getTextManager():MeasureStringX(font or UIFont.Small, tostring(str))
end

local function lineH(font)
    ensureFontsRegistered()
    if KeyasUI and KeyasUI.measure then
        local _, h = KeyasUI.measure("Mg", fontIdOf(font))
        return h or 14
    end
    return getTextManager():getFontHeight(font or UIFont.Small)
end

local function text(self, str, x, y, c, font)
    ensureFontsRegistered()
    if KeyasUI and KeyasUI.text then
        KeyasUI.text(self, tostring(str), x, y, { r = c[1], g = c[2], b = c[3], a = 1 }, fontIdOf(font))
        return
    end
    self:drawText(tostring(str), x, y, c[1], c[2], c[3], 1, font or UIFont.Small)
end

local function textRight(self, str, x, y, c, font)
    text(self, str, x - measure(str, font), y, c, font)
end

local function drawWrapped(self, str, x, y, w, c, font)
    local lh = lineH(font) + 3
    local line = ""
    for word in string.gmatch(tostring(str), "%S+") do
        local cand = (line == "") and word or (line .. " " .. word)
        if line ~= "" and measure(cand, font) > w then
            text(self, line, x, y, c, font); y = y + lh; line = word
        else
            line = cand
        end
    end
    if line ~= "" then text(self, line, x, y, c, font); y = y + lh end
    return y
end

-- Dibuja un icono de la hoja procesada, tintado con `c`. Si la textura no
-- esta, cae a un glifo de rectangulos.
local function drawIcon(self, n, x, y, size, c)
    local t = icon(n)
    if t then
        self:drawTextureScaled(t, x, y, size, size, 1, c[1], c[2], c[3])
        return
    end
    self:drawRectBorder(x + 3, y + 4, size - 8, size - 10, 1, c[1], c[2], c[3])
end

local function appGlyph(self, id, x, y, c)
    local n = IC[id]
    if n then drawIcon(self, n, x, y - 2, 30, c) end
end

-- ---- estado de la mision --------------------------------------------------

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

function LPComputer:selectedRow()
    for _, group in ipairs(CATALOG) do
        for _, row in ipairs(group.rows) do
            if row.id == self.selectedId then return row, group end
        end
    end
    return nil, nil
end

-- ---- botones (hijos ISButton) -----------------------------------------

function LPComputer:createChildren()
    ISPanel.createChildren(self)
    self:layout()
    local win = self.win

    self.closeButton = ISButton:new(win.x + win.w - 24, win.y + 4, 20, 18, "X", self, LPComputer.onClose)
    self.closeButton:initialise(); self.closeButton:instantiate()
    self.closeButton.backgroundColor = { r = WINFACE[1], g = WINFACE[2], b = WINFACE[3], a = 1 }
    self.closeButton.borderColor = { r = 0, g = 0, b = 0, a = 1 }
    self.closeButton.textColor = { r = 0.78, g = 0.16, b = 0.13, a = 1 }
    self:addChild(self.closeButton)

    local aw, ah = 224, 34
    self.actionButton = ISButton:new(win.x + win.w - aw - 24, win.y + win.h - ah - 22, aw, ah, "", self, LPComputer.onAction)
    self.actionButton:initialise(); self.actionButton:instantiate()
    self.actionButton.backgroundColor = { r = WINFACE[1], g = WINFACE[2], b = WINFACE[3], a = 1 }
    self.actionButton.borderColor = { r = 0, g = 0, b = 0, a = 1 }
    self.actionButton.textColor = { r = INK[1], g = INK[2], b = INK[3], a = 1 }
    self:addChild(self.actionButton)

    self:refreshAction()
end

function LPComputer:refreshAction()
    local player = LastPurpose.getPlayerSafe(0)
    local row = self:selectedRow()
    local show = self.app == "misiones"
    self.actionButton:setVisible(show)
    if not show then return end
    local function setImg(on)
        if not self.actionButton.setImage then return end
        pcall(function() self.actionButton:setImage(on and icon(IC.finger) or nil) end)
    end
    if not player or not row or not row.unlocked then
        self.actionButton:setTitle("Bloqueada")
        self.actionButton:setEnable(false)
        setImg(false)
        return
    end
    local _, _, actionText, enabled = knoxStatus(LastPurpose.getData(player))
    self.actionButton:setTitle(actionText)
    self.actionButton:setEnable(enabled == true)
    setImg(enabled == true)
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

-- ---- entrada ---------------------------------------------------------

function LPComputer:onMouseDown(x, y)
    for _, hb in ipairs(self.appHitboxes) do
        if x >= hb.x and x <= hb.x + hb.w and y >= hb.y and y <= hb.y + hb.h then
            self.app = hb.id
            self:refreshAction()
            return true
        end
    end
    local win = self.win
    if x < win.x or x > win.x + win.w or y < win.y or y > win.y + win.h then
        self:onClose()
        return true
    end
    if self.app == "misiones" then
        for _, hb in ipairs(self.rowHitboxes) do
            if x >= hb.x and x <= hb.x + hb.w and y >= hb.y and y <= hb.y + hb.h then
                self.selectedId = hb.id
                self:refreshAction()
                return true
            end
        end
    end
    return ISPanel.onMouseDown(self, x, y)
end

-- ---- pintado -------------------------------------------------------

function LPComputer:prerender()
    ISPanel.prerender(self)
    -- Un fallo de dibujo se lanzaria en cada fotograma: se atrapa, se
    -- reporta una sola vez y se deja de intentar en vez de spamear consola.
    if self.renderBroken then return end
    local ok, err = pcall(function() self:paint() end)
    if not ok then
        self.renderBroken = true
        print("[LastPurpose] ERROR pintando el ordenador (se detiene el dibujo): " .. tostring(err))
    end
end

function LPComputer:paint()
    if not self.win then self:layout() end
    local win = self.win

    rect(self, 0, 0, self.width, self.statusY, DESKTOP)
    self:renderRail()

    -- marca de agua del escritorio: el logo si esta, si no el texto
    local logo = tex("xcyos_logo.png")
    if logo then
        local lw = 320
        local lh = lw * logo:getHeight() / logo:getWidth()
        self:drawTextureScaled(logo, win.x + win.w + 30, math.floor(self.height / 2 - lh / 2), lw, lh, 0.9, 1, 1, 1)
    else
        text(self, "XCYOS", win.x + win.w + 30, math.floor(self.height / 2) - 30, PHOSPHOR, UIFont.Large)
    end

    -- scanlines tenues sobre el escritorio (rects en orden, sin textura
    -- grande que PZ componga al final y ensucie la ventana)
    for sy = 0, self.statusY, 3 do
        self:drawRect(0, sy, self.width, 1, 0.05, 0, 0, 0)
    end

    -- ventana: sombra, relleno solido, borde negro
    rect(self, win.x - 3, win.y - 3, win.w + 6, win.h + 6, { 0, 0, 0 }, 0.45)
    rect(self, win.x, win.y, win.w, win.h, WINFACE)
    self:drawRectBorder(win.x, win.y, win.w, win.h, 1, 0.05, 0.05, 0.04)
    -- barra de titulo: teal oscuro, dibujada dos veces por si algo compone encima
    rect(self, win.x + 1, win.y + 1, win.w - 2, 25, TITLE_BG)
    rect(self, win.x + 1, win.y + 1, win.w - 2, 25, TITLE_BG)
    self:drawRect(win.x + 1, win.y + 26, win.w - 2, 1, 1, 0, 0, 0)
    drawIcon(self, IC.folder, win.x + 6, win.y + 4, 18, { 0.92, 0.80, 0.42 })
    text(self, "LAST PURPOSE // ARCHIVO DE MISIONES", win.x + 30, win.y + 6, { 0.60, 1.0, 0.92 })
    drawIcon(self, IC.min, win.x + win.w - 72, win.y + 5, 16, { 0.85, 0.92, 0.89 })
    drawIcon(self, IC.max, win.x + win.w - 50, win.y + 5, 16, { 0.85, 0.92, 0.89 })
    -- (la X es un hijo ISButton)

    local bx, by = win.x + 14, win.y + 36
    local bw, bh = win.w - 28, win.h - 50

    local function pane(px, py, pw, ph)
        rect(self, px, py, pw, ph, PAGEFACE)
        self:drawRectBorder(px, py, pw, ph, 1, 0.32, 0.31, 0.28)
        self:drawRect(px + 1, py + 1, pw - 2, 1, 1, WIN_HI[1], WIN_HI[2], WIN_HI[3])
    end

    if self.app == "misiones" then
        local listW = 250
        pane(bx, by, listW, bh)
        pane(bx + listW + 14, by, bw - listW - 14, bh)
        self:renderList(bx + 12, by + 12, listW - 24)
        self:renderDetail(bx + listW + 14 + 18, by + 16, bw - listW - 14 - 36)
    else
        pane(bx, by, bw, bh)
        self:renderStub(bx + 22, by + 20, bw - 44)
    end

    -- barra de estado
    rect(self, 0, self.statusY, self.width, 24, { 0.02, 0.13, 0.11 })
    text(self, "XCYOS v1.0.3  |  LAST PURPOSE TERMINAL", 12, self.statusY + 5, PH_DIM)
    textRight(self, "12:47  .  14/07/1993", self.width - 12, self.statusY + 5, PHOSPHOR)
end

function LPComputer:renderRail()
    self.appHitboxes = {}
    -- franja de colores
    for i = 1, 4 do
        rect(self, 0, 150 + (i - 1) * 7, RAIL_W - 8, 7, STRIPE[i])
    end
    local ry = 14
    for _, app in ipairs(APPS) do
        local active = self.app == app.id
        if active then bevel(self, 4, ry, RAIL_W - 8, 52, { 0.12, 0.30, 0.27 }) end
        local c = active and { 0.92, 1.0, 0.97 } or { 0.72, 0.78, 0.75 }
        appGlyph(self, app.id, 33, ry + 6, c)
        local lw = measure(app.label, UIFont.Small)
        text(self, app.label, math.floor((RAIL_W - lw) / 2), ry + 37, c)
        table.insert(self.appHitboxes, { id = app.id, x = 4, y = ry, w = RAIL_W - 8, h = 52 })
        ry = ry + 58
    end
end

function LPComputer:renderList(x, y, w)
    self.rowHitboxes = {}
    local cy = y
    for _, group in ipairs(CATALOG) do
        text(self, group.city, x, cy, INK)
        rect(self, x, cy + 16, w, 1, INK)
        cy = cy + 22
        if group.hint then
            cy = drawWrapped(self, group.hint, x, cy, w, LOCKC) + 2
        end
        for i, row in ipairs(group.rows) do
            local sel = row.id == self.selectedId
            if sel then rect(self, x - 6, cy - 2, w + 12, 18, { 0.16, 0.24, 0.23 }) end
            local c = sel and PHOSPHOR or (row.unlocked and INK or LOCKC)
            text(self, i .. ". " .. (row.unlocked and row.name or REDACTED), x, cy, c)
            table.insert(self.rowHitboxes, { id = row.id, x = x - 6, y = cy - 2, w = w + 12, h = 18 })
            cy = cy + 19
        end
        cy = cy + 10
    end
end

function LPComputer:renderDetail(x, y, w)
    local player = LastPurpose.getPlayerSafe(0)
    local row, group = self:selectedRow()
    if not row then return end

    if not row.unlocked then
        text(self, REDACTED, x, y, INK, UIFont.Large)
        text(self, "EXPEDIENTE CLASIFICADO", x, y + 32, INK_SOFT)
        local cy = drawWrapped(self, "Nombre y detalles ocultos. Cumpli el requisito para que el expediente se abra.", x, y + 58, w, INK)
        drawWrapped(self, "Requisito: " .. ((group and group.hint) or "Avanza en la historia."), x, cy + 10, w, LOCKC)
        return
    end

    local heist = LastPurpose.getHeist(row.id)
    local data = player and LastPurpose.getData(player)
    text(self, row.name, x, y, INK, UIFont.Large)

    local label, color = "DISPONIBLE", PH_DIM
    if data then label, color = knoxStatus(data) end
    local lw = measure(label, UIFont.Small)
    self:drawRectBorder(x + w - lw - 12, y + 3, lw + 12, 18, 1, color[1], color[2], color[3])
    text(self, label, x + w - lw - 6, y + 5, color)

    local cy = y + 34
    text(self, (heist and heist.destination) or "Knox Bank, Louisville", x, cy, INK_SOFT)
    cy = cy + 24
    text(self, "OBJETIVO", x, cy, INK); cy = cy + 18
    cy = drawWrapped(self, (heist and heist.mission) or "Adelantarse a la competencia.", x, cy, w, INK)
    cy = cy + 12
    text(self, "RECOMPENSA", x, cy, INK); cy = cy + 20
    local tiles = { { IC.cash, "Efectivo" }, { IC.gold, "Oro" }, { IC.crate, "Suministros" } }
    for ti, t in ipairs(tiles) do
        local tx = x + (ti - 1) * 92
        self:drawRectBorder(tx, cy, 84, 58, 1, INK[1], INK[2], INK[3])
        drawIcon(self, t[1], tx + 27, cy + 6, 30, INK)
        local lw2 = measure(t[2], UIFont.Small)
        text(self, t[2], tx + math.floor((84 - lw2) / 2), cy + 40, INK_SOFT)
    end
    cy = cy + 66
    drawWrapped(self, "5 lingotes de oro, 4 diamantes, 6 fajos, suministros de mid-game, municion y 2 niveles de Destreza.", x, cy, w, INK_SOFT)
end

-- paneles de las otras apps: contenido minimo, real, de solo lectura.
function LPComputer:renderStub(x, y, w)
    if self.app == "notas" then
        text(self, "NOTAS", x, y, INK, UIFont.Medium)
        drawWrapped(self, "Las notas cifradas que recogiste en el mundo aparecen aca una vez leidas. El diario de mision (tecla J) sigue siendo aparte: solo se abre en el prologo y con una mision activa.", x, y + 30, w, INK_SOFT)
    elseif self.app == "archivos" then
        text(self, "ARCHIVOS", x, y, INK, UIFont.Medium)
        drawWrapped(self, "Intel acumulada: planos parciales del Knox Bank, contacto de la radio, catalogo de golpes de Louisville. La mesa con ordenador fija tu refugio.", x, y + 30, w, INK_SOFT)
    else
        text(self, "SISTEMA", x, y, INK, UIFont.Medium)
        local ky = y + 34
        text(self, "Tecla del diario:  J   (Opciones > Mods > Last Purpose)", x, ky, INK_SOFT)
        text(self, "Registro de depuracion:  " .. (LastPurpose.DEBUG and "SI" or "NO"), x, ky + 22, INK_SOFT)
        text(self, "XCYOS v1.0.3  -  Last Purpose Terminal", x, ky + 52, LOCKC)
    end
end

-- ---- apertura desde el menu contextual de la mesa --------------------

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
