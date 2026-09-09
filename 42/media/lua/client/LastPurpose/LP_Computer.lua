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

-- Paleta terminal. Hex exactos del mockup XCYOS (una sola: es una pantalla
-- dentro del juego, sin tema claro/oscuro).
local SCREEN    = { 0.043, 0.059, 0.051 }   -- #0b0f0d
local DESKTOP   = { 0.106, 0.125, 0.118 }   -- #1b201e
local WINFACE   = { 0.725, 0.714, 0.678 }   -- #b9b6ad
local WIN_HI    = { 0.933, 0.925, 0.894 }   -- #eeece4
local WIN_LO    = { 0.427, 0.416, 0.380 }   -- #6d6a61
local PAGEFACE  = { 0.796, 0.784, 0.749 }   -- #cbc8bf
local TITLE_BG  = { 0.145, 0.184, 0.173 }   -- #25302c (base del degradado teal)
local TITLE_INK = { 0.918, 1.000, 0.965 }   -- #eafffb
local INK       = { 0.086, 0.086, 0.059 }   -- #16160f
local INK_SOFT  = { 0.290, 0.278, 0.235 }   -- #4a473c
local PHOSPHOR  = { 0.184, 0.906, 0.769 }   -- #2fe7c4
local PH_DIM    = { 0.110, 0.561, 0.486 }   -- #1c8f7c
local OKC       = { 0.337, 0.706, 0.353 }   -- #56b45a
local AMBER     = { 1.000, 0.714, 0.290 }   -- #ffb64a
local LOCKC     = { 0.486, 0.478, 0.439 }   -- #7c7a70
local SEL_BG    = { 0.184, 0.247, 0.227 }   -- #2f3f3a fila seleccionada
local STRIPE    = { {0.384,0.714,0.349}, {0.235,0.604,0.549}, {0.886,0.627,0.129}, {0.820,0.267,0.227} }

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
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    -- NO a pantalla completa: PZ trata un panel del tamano exacto de la
    -- pantalla como un menu, pausa el juego y oscurece TODO (incluida esta
    -- UI). Un panel centrado grande (~94% x 92%) no dispara esa pausa.
    local w = math.floor(sw * 0.94)
    local h = math.floor(sh * 0.92)
    local o = ISPanel:new(math.floor((sw - w) / 2), math.floor((sh - h) / 2), w, h)
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

    -- Boton de accion: el visual lo dibujamos nosotros en paint() (para que
    -- no se ponga negro al deshabilitarse ni pise nuestra paleta). El
    -- ISButton queda transparente y solo sirve de zona de clic.
    local aw, ah = 236, 36
    self.actionRect = { x = win.x + win.w - aw - 24, y = win.y + win.h - ah - 22, w = aw, h = ah }
    self.actionButton = ISButton:new(self.actionRect.x, self.actionRect.y, aw, ah, "", self, LPComputer.onAction)
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
    self.actionButton:setVisible(show)
    self.showAction = show
    if not show then return end
    if not player or not row or not row.unlocked then
        self.actionLabel, self.actionEnabled = "Bloqueada", false
    else
        local _, _, actionText, enabled = knoxStatus(LastPurpose.getData(player))
        self.actionLabel, self.actionEnabled = actionText, (enabled == true)
    end
    self.actionButton:setEnable(self.actionEnabled)
end

-- Dibuja el boton de accion (rect crema + sombra + huella + label).
function LPComputer:drawActionButton()
    if not self.showAction or not self.actionRect then return end
    local r = self.actionRect
    local on = self.actionEnabled
    local a = on and 1 or 0.55
    self:drawRect(r.x + 3, r.y + 3, r.w, r.h, a, INK[1], INK[2], INK[3])          -- sombra dura
    self:drawRect(r.x, r.y, r.w, r.h, a, WINFACE[1], WINFACE[2], WINFACE[3])
    if on then self:drawRect(r.x, r.y, r.w, r.h, 0.25, PHOSPHOR[1], PHOSPHOR[2], PHOSPHOR[3]) end
    self:drawRectBorder(r.x, r.y, r.w, r.h, a, INK[1], INK[2], INK[3])
    self:drawRectBorder(r.x + 1, r.y + 1, r.w - 2, r.h - 2, a, INK[1], INK[2], INK[3])
    drawIcon(self, IC.finger, r.x + 8, r.y + 4, 28, { INK[1], INK[2], INK[3] })
    local lbl = self.actionLabel or ""
    local lw = measure(lbl, UIFont.Small)
    text(self, lbl, r.x + 44 + math.floor((r.w - 44 - lw) / 2), r.y + 10, { INK[1], INK[2], INK[3] })
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

function LPComputer:onMouseDownOutside(x, y)
    self:onClose()
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

    -- ventana: sombra, relleno solido, bisel noventero (claro arriba/izq)
    rect(self, win.x - 3, win.y - 3, win.w + 6, win.h + 6, { 0, 0, 0 }, 0.5)
    rect(self, win.x, win.y, win.w, win.h, WINFACE)
    self:drawRectBorder(win.x, win.y, win.w, win.h, 1, 0.04, 0.04, 0.03)
    self:drawRect(win.x + 1, win.y + 1, win.w - 2, 1, 1, WIN_HI[1], WIN_HI[2], WIN_HI[3])
    self:drawRect(win.x + 1, win.y + 1, 1, win.h - 2, 1, WIN_HI[1], WIN_HI[2], WIN_HI[3])

    -- barra de titulo: degradado teal si esta el PNG, si no teal oscuro plano
    local TB_H = 26
    local gtitle = tex("grad_title.png")
    if gtitle then
        self:drawTextureScaled(gtitle, win.x + 2, win.y + 2, win.w - 4, TB_H, 1, 1, 1, 1)
    else
        rect(self, win.x + 2, win.y + 2, win.w - 4, TB_H, TITLE_BG)
    end
    self:drawRect(win.x + 2, win.y + 2 + TB_H, win.w - 4, 1, 1, 0, 0, 0)
    drawIcon(self, IC.folder, win.x + 8, win.y + 5, 18, { 0.94, 0.82, 0.39 })
    text(self, "LAST PURPOSE // ARCHIVO DE MISIONES", win.x + 32, win.y + 7, TITLE_INK)
    drawIcon(self, IC.min, win.x + win.w - 74, win.y + 6, 16, TITLE_INK)
    drawIcon(self, IC.max, win.x + win.w - 52, win.y + 6, 16, TITLE_INK)
    -- (la X es un hijo ISButton)

    local bx, by = win.x + 14, win.y + 38
    local bw, bh = win.w - 28, win.h - 52

    local function pane(px, py, pw, ph)
        rect(self, px, py, pw, ph, PAGEFACE)
        self:drawRectBorder(px, py, pw, ph, 1, WIN_LO[1], WIN_LO[2], WIN_LO[3])
        self:drawRect(px + 1, py + 1, pw - 2, 1, 1, WIN_HI[1], WIN_HI[2], WIN_HI[3])
        self:drawRect(px + 1, py + 1, 1, ph - 2, 1, WIN_HI[1], WIN_HI[2], WIN_HI[3])
    end

    if self.app == "misiones" then
        local listW = 250
        pane(bx, by, listW, bh)
        pane(bx + listW + 14, by, bw - listW - 14, bh)
        self:renderList(bx + 12, by + 12, listW - 24)
        self:renderDetail(bx + listW + 14 + 18, by + 16, bw - listW - 14 - 36)
        self:drawActionButton()
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
        if active then
            rect(self, 4, ry, RAIL_W - 8, 52, { 0.075, 0.135, 0.125 })
            self:drawRectBorder(4, ry, RAIL_W - 8, 52, 1, PH_DIM[1], PH_DIM[2], PH_DIM[3])
        end
        local c = active and { 0.918, 1.0, 0.965 } or { 0.706, 0.765, 0.737 }
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
        rect(self, x, cy + 15, w, 2, INK)
        cy = cy + 23
        if group.hint then
            cy = drawWrapped(self, group.hint, x, cy, w, LOCKC) + 3
        end
        for i, row in ipairs(group.rows) do
            local sel = row.id == self.selectedId
            if sel then
                rect(self, x - 8, cy - 3, w + 16, 19, SEL_BG)
                rect(self, x - 8, cy - 3, 3, 19, PHOSPHOR)
            end
            local c = sel and TITLE_INK or (row.unlocked and INK or LOCKC)
            text(self, i .. ". " .. (row.unlocked and row.name or REDACTED), x, cy, c)
            table.insert(self.rowHitboxes, { id = row.id, x = x - 8, y = cy - 3, w = w + 16, h = 19 })
            cy = cy + 20
        end
        cy = cy + 11
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
    local bx0 = x + w - lw - 14
    -- chip: relleno claro tenue del color de estado + borde + texto oscuro
    rect(self, bx0, y + 2, lw + 14, 19, { color[1] * 0.35 + 0.62, color[2] * 0.35 + 0.62, color[3] * 0.35 + 0.62 })
    self:drawRectBorder(bx0, y + 2, lw + 14, 19, 1, color[1] * 0.6, color[2] * 0.6, color[3] * 0.6)
    text(self, label, bx0 + 7, y + 5, { color[1] * 0.5, color[2] * 0.5, color[3] * 0.5 })

    local cy = y + 34
    text(self, (heist and heist.destination) or "Knox Bank, Louisville", x, cy, INK_SOFT)
    cy = cy + 24

    -- OBJETIVO en dos columnas: texto a la izquierda, mini-mapa a la derecha
    local mapW = math.min(200, math.floor(w * 0.42))
    local textW = w - mapW - 18
    text(self, "OBJETIVO", x, cy, INK)
    self:sectionRule(x, cy + 15, w)
    local objY = cy + 24
    local endY = drawWrapped(self, (heist and heist.mission)
        or "Adelantarse a la competencia. El banco mas grande de Kentucky.", x, objY, textW, INK)
    self:drawMap(x + textW + 18, cy + 20, mapW, math.max(endY - objY, mapW - 10),
        (group and group.city) or "LOUISVILLE")
    cy = math.max(endY, cy + 20 + mapW - 10) + 18

    text(self, "RECOMPENSA ESTIMADA", x, cy, INK)
    self:sectionRule(x, cy + 15, w)
    cy = cy + 24
    local tiles = { { IC.cash, "$25 000", "EFECTIVO" }, { IC.gold, "x5", "LINGOTES" }, { IC.crate, "+", "SUMINISTROS" } }
    for ti, t in ipairs(tiles) do
        local tw, tx = 104, x + (ti - 1) * 112
        self:drawRect(tx + 2, cy + 2, tw, 64, 1, 0, 0, 0)
        rect(self, tx, cy, tw, 64, WINFACE)
        self:drawRectBorder(tx, cy, tw, 64, 1, INK[1], INK[2], INK[3])
        self:drawRect(tx + 1, cy + 1, tw - 2, 1, 1, WIN_HI[1], WIN_HI[2], WIN_HI[3])
        drawIcon(self, t[1], tx + math.floor(tw / 2) - 14, cy + 6, 28, INK)
        local vw = measure(t[2], UIFont.Small)
        text(self, t[2], tx + math.floor((tw - vw) / 2), cy + 34, INK)
        local lw2 = measure(t[3], UIFont.Small)
        text(self, t[3], tx + math.floor((tw - lw2) / 2), cy + 48, INK_SOFT)
    end
    cy = cy + 74
    drawWrapped(self, "5 lingotes de oro, 4 diamantes, 6 fajos, suministros de mid-game, municion y 2 niveles de Destreza.", x, cy, w, INK_SOFT)
end

-- Regla de seccion 1px, tinta.
function LPComputer:sectionRule(x, y, w)
    self:drawRect(x, y, w, 1, 1, INK[1], INK[2], INK[3])
end

-- Mini-mapa estilizado (rejilla de calles + diagonal + mira + N), dibujado
-- con primitivas: el mockup usa un SVG, aca es lo mas cerca sin un PNG.
function LPComputer:drawMap(x, y, w, h, label)
    rect(self, x, y, w, h, { 0.812, 0.796, 0.749 })
    self:drawRectBorder(x, y, w, h, 1, INK[1], INK[2], INK[3])
    local gc = { 0.55, 0.53, 0.49 }
    for gx = x + 16, x + w - 8, 26 do self:drawRect(gx, y + 2, 1, h - 4, 1, gc[1], gc[2], gc[3]) end
    for gy = y + 16, y + h - 8, 24 do self:drawRect(x + 2, gy, w - 4, 1, 1, gc[1], gc[2], gc[3]) end
    -- "avenida" diagonal
    self:drawRect(x + 6, y + math.floor(h * 0.62), math.floor(w * 0.5), 2, 1, 0.42, 0.40, 0.36)
    -- objetivo: recuadro + mira
    local ox, oy = x + math.floor(w * 0.52), y + math.floor(h * 0.42)
    self:drawRectBorder(ox - 8, oy - 7, 16, 14, 1, 0.36, 0.35, 0.31)
    self:drawRect(ox + 18, oy + 8, 1, 22, 1, INK[1], INK[2], INK[3])
    self:drawRect(ox + 8, oy + 18, 22, 1, 1, INK[1], INK[2], INK[3])
    self:drawRectBorder(ox + 12, oy + 12, 14, 14, 1, INK[1], INK[2], INK[3])
    text(self, label, x + 5, y + 3, { 0.16, 0.16, 0.13 })
    text(self, "N", x + w - 14, y + 3, { 0.16, 0.16, 0.13 })
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
