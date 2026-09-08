require "ISUI/ISPanel"
require "ISUI/ISButton"

-- ---------------------------------------------------------------------------
-- LP_Computer.lua - Hito 1 del hub del ordenador (ver documentacion_mod.txt
-- seccion 13 y CLAUDE.md roadmap punto 2).
--
-- La mesa de planificacion pasa a ser "la mesa con ordenador": misma pieza,
-- misma receta salvo que ahora pide chatarra electronica. Su menu contextual
-- abre esta GUI de pantalla completa, un archivo de misiones estilo terminal
-- retro. Por ahora es de SOLO LECTURA: lista el catalogo y, cuando toca,
-- entrega el botin (la logica sigue siendo LastPurpose.reviewHeistLoot, no se
-- reescribio nada de ese flujo ya validado).
--
-- El diario (tecla J) sigue existiendo aparte, para el prologo y la mision
-- activa. La seleccion de misiones y los desbloqueos por ciudad/profesion son
-- hitos posteriores.
-- ---------------------------------------------------------------------------

LastPurpose = LastPurpose or {}

local REDACTED = "?????????"

-- Catalogo de PANTALLA. El unico golpe "real" hoy es louisville_knox_bank
-- (vive en LastPurpose.HEISTS); el resto se muestra censurado hasta que los
-- hitos de desbloqueo existan.
local CATALOG = {
    { city = "LOUISVILLE", rows = {
        { id = "louisville_knox_bank", name = "El ultimo golpe", unlocked = true },
        { id = "last_exhibition",  name = "La ultima exposicion" },
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

-- Paleta terminal (una sola, es una pantalla dentro del juego)
local SCREEN   = { 0.043, 0.059, 0.051 }
local PANEL    = { 0.72, 0.71, 0.68 }
local PANEL_HI = { 0.86, 0.85, 0.81 }
local INK      = { 0.09, 0.09, 0.06 }
local INK_SOFT = { 0.29, 0.28, 0.24 }
local TITLE_BG = { 0.15, 0.19, 0.18 }
local PHOSPHOR = { 0.18, 0.90, 0.77 }
local PH_DIM   = { 0.11, 0.56, 0.49 }
local OKC      = { 0.34, 0.70, 0.35 }
local AMBER    = { 1.0, 0.71, 0.29 }
local LOCKC    = { 0.49, 0.48, 0.44 }

LPComputer = ISPanel:derive("LPComputer")

function LPComputer:new()
    local w, h = getCore():getScreenWidth(), getCore():getScreenHeight()
    local o = ISPanel:new(0, 0, w, h)
    setmetatable(o, self)
    self.__index = self
    o.background = false
    o.moveWithMouse = false
    o.selectedId = "louisville_knox_bank"
    o.rowHitboxes = {}
    return o
end

function LPComputer:layout()
    -- Ventana centrada dentro de la pantalla; el borde exterior cierra al clic.
    local mw = math.min(self.width - 120, 1000)
    local mh = math.min(self.height - 110, 620)
    self.win = {
        x = math.floor((self.width - mw) / 2),
        y = math.floor((self.height - mh) / 2),
        w = mw, h = mh,
    }
end

function LPComputer:createChildren()
    ISPanel.createChildren(self)
    self:layout()
    local win = self.win

    self.closeButton = ISButton:new(win.x + win.w - 26, win.y + 5, 20, 18, "X", self, LPComputer.onClose)
    self.closeButton:initialise(); self.closeButton:instantiate()
    self.closeButton.backgroundColor = { r = PANEL[1], g = PANEL[2], b = PANEL[3], a = 1 }
    self.closeButton.textColor = { r = 0.75, g = 0.15, b = 0.12, a = 1 }
    self:addChild(self.closeButton)

    -- Boton de accion (esquina inferior del panel de detalle)
    local aw, ah = 220, 34
    self.actionButton = ISButton:new(win.x + win.w - aw - 22, win.y + win.h - ah - 20, aw, ah, "", self, LPComputer.onAction)
    self.actionButton:initialise(); self.actionButton:instantiate()
    self.actionButton.backgroundColor = { r = PANEL[1], g = PANEL[2], b = PANEL[3], a = 1 }
    self.actionButton.textColor = { r = INK[1], g = INK[2], b = INK[3], a = 1 }
    self:addChild(self.actionButton)

    self:refreshAction()
end

-- ---- estado de la mision -------------------------------------------------

-- Devuelve etiqueta, color y texto de accion segun la etapa del jugador,
-- solo para el golpe real. Todo lo demas esta bloqueado.
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
            if row.id == self.selectedId then return row end
        end
    end
    return nil
end

function LPComputer:refreshAction()
    local player = LastPurpose.getPlayerSafe(0)
    local row = self:selectedRow()
    if not player or not row or not row.unlocked then
        self.actionButton:setTitle("Bloqueada")
        self.actionButton:setEnable(false)
        return
    end
    local data = LastPurpose.getData(player)
    local _, _, actionText, enabled = knoxStatus(data)
    self.actionButton:setTitle(actionText)
    self.actionButton:setEnable(enabled == true)
end

function LPComputer:onAction()
    local player = LastPurpose.getPlayerSafe(0)
    if not player then return end
    local data = LastPurpose.getData(player)
    if not LastPurpose.stageIs(data, "review_loot") then return end

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

-- ---- entrada ------------------------------------------------------------

function LPComputer:onMouseDown(x, y)
    local win = self.win
    if x < win.x or x > win.x + win.w or y < win.y or y > win.y + win.h then
        self:onClose()
        return true
    end
    for _, hb in ipairs(self.rowHitboxes) do
        if x >= hb.x and x <= hb.x + hb.w and y >= hb.y and y <= hb.y + hb.h then
            self.selectedId = hb.id
            self:refreshAction()
            return true
        end
    end
    return ISPanel.onMouseDown(self, x, y)
end

-- ---- pintado ---------------------------------------------------------

local function drawWrapped(self, text, x, y, w, color, font)
    font = font or UIFont.Small
    local tm = getTextManager()
    local lh = tm:getFontHeight(font) + 3
    local line = ""
    for word in string.gmatch(tostring(text), "%S+") do
        local cand = (line == "") and word or (line .. " " .. word)
        if line ~= "" and tm:MeasureStringX(font, cand) > w then
            self:drawText(line, x, y, color[1], color[2], color[3], 1, font)
            y = y + lh; line = word
        else
            line = cand
        end
    end
    if line ~= "" then
        self:drawText(line, x, y, color[1], color[2], color[3], 1, font)
        y = y + lh
    end
    return y
end

function LPComputer:prerender()
    ISPanel.prerender(self)
    if not self.win then self:layout() end
    local win = self.win

    -- fondo de pantalla (cubre todo; el margen cierra al clic)
    self:drawRect(0, 0, self.width, self.height, 0.92, SCREEN[1], SCREEN[2], SCREEN[3])
    -- lineas de escaneo sutiles, solo sobre la ventana
    for sy = win.y, win.y + win.h, 3 do
        self:drawRect(win.x, sy, win.w, 1, 0.05, 0, 0, 0)
    end

    -- ventana
    self:drawRect(win.x, win.y, win.w, win.h, 1, PANEL[1], PANEL[2], PANEL[3])
    self:drawRectBorder(win.x, win.y, win.w, win.h, 1, 0, 0, 0)
    self:drawRect(win.x, win.y, win.w, 26, 1, TITLE_BG[1], TITLE_BG[2], TITLE_BG[3])
    self:drawText("LAST PURPOSE // ARCHIVO DE MISIONES", win.x + 10, win.y + 6, 0.92, 1, 0.98, 1, UIFont.Small)

    local padX, padY = win.x + 14, win.y + 38
    local listW = 250
    local detX = padX + listW + 16
    local detW = win.x + win.w - detX - 16

    -- panel lista
    self:drawRect(padX, padY, listW, win.h - 52, 1, PANEL_HI[1], PANEL_HI[2], PANEL_HI[3])
    self:drawRectBorder(padX, padY, listW, win.h - 52, 1, INK_SOFT[1], INK_SOFT[2], INK_SOFT[3])
    -- panel detalle
    self:drawRect(detX, padY, detW, win.h - 52, 1, PANEL_HI[1], PANEL_HI[2], PANEL_HI[3])
    self:drawRectBorder(detX, padY, detW, win.h - 52, 1, INK_SOFT[1], INK_SOFT[2], INK_SOFT[3])

    self:renderList(padX + 8, padY + 10, listW - 16)
    self:renderDetail(detX + 16, padY + 16, detW - 32)

    -- barra de estado
    self:drawRect(win.x, win.y + win.h - 20, win.w, 20, 1, 0.02, 0.13, 0.11)
    self:drawText("XCYOS v1.0.3  |  LAST PURPOSE TERMINAL", win.x + 10, win.y + win.h - 17,
        PH_DIM[1], PH_DIM[2], PH_DIM[3], 1, UIFont.Small)
end

function LPComputer:renderList(x, y, w)
    self.rowHitboxes = {}
    local cy = y
    for _, group in ipairs(CATALOG) do
        self:drawText(group.city, x, cy, INK[1], INK[2], INK[3], 1, UIFont.Small)
        self:drawRect(x, cy + 16, w, 1, 1, INK[1], INK[2], INK[3])
        cy = cy + 22
        if group.hint then
            cy = drawWrapped(self, group.hint, x, cy, w, LOCKC, UIFont.Small) + 2
        end
        for i, row in ipairs(group.rows) do
            local sel = (row.id == self.selectedId)
            local label = i .. ". " .. (row.unlocked and row.name or REDACTED)
            if sel then
                self:drawRect(x - 4, cy - 2, w + 8, 18, 1, 0.18, 0.25, 0.24)
            end
            local c = sel and PHOSPHOR or (row.unlocked and INK or LOCKC)
            self:drawText(label, x, cy, c[1], c[2], c[3], 1, UIFont.Small)
            table.insert(self.rowHitboxes, { id = row.id, x = x - 4, y = cy - 2, w = w + 8, h = 18 })
            cy = cy + 19
        end
        cy = cy + 8
    end
end

function LPComputer:renderDetail(x, y, w)
    local player = LastPurpose.getPlayerSafe(0)
    local row = self:selectedRow()
    if not row then return end

    if not row.unlocked then
        self:drawText(REDACTED, x, y, INK[1], INK[2], INK[3], 1, UIFont.Large)
        local cy = y + 34
        self:drawText("EXPEDIENTE CLASIFICADO", x, cy, INK_SOFT[1], INK_SOFT[2], INK_SOFT[3], 1, UIFont.Small)
        cy = cy + 26
        cy = drawWrapped(self, "Nombre y detalles ocultos. Cumpli el requisito para que el expediente se abra.", x, cy, w, INK, UIFont.Small)
        local groupHint = "Requiere avanzar en la historia."
        for _, g in ipairs(CATALOG) do
            for _, r in ipairs(g.rows) do
                if r.id == row.id and g.hint then groupHint = g.hint end
            end
        end
        drawWrapped(self, "Requisito: " .. groupHint, x, cy + 10, w, LOCKC, UIFont.Small)
        return
    end

    local heist = LastPurpose.getHeist(row.id)
    local data = player and LastPurpose.getData(player)
    self:drawText(row.name, x, y, INK[1], INK[2], INK[3], 1, UIFont.Large)

    local label, color = "DISPONIBLE", PH_DIM
    if data then label, color = knoxStatus(data) end
    self:drawText(label, x + w - getTextManager():MeasureStringX(UIFont.Small, label), y + 6,
        color[1], color[2], color[3], 1, UIFont.Small)

    local cy = y + 34
    self:drawText((heist and heist.destination) or "Knox Bank, Louisville", x, cy,
        INK_SOFT[1], INK_SOFT[2], INK_SOFT[3], 1, UIFont.Small)
    cy = cy + 24

    self:drawText("OBJETIVO", x, cy, INK[1], INK[2], INK[3], 1, UIFont.Small)
    cy = cy + 18
    cy = drawWrapped(self, (heist and heist.mission) or "Adelantarse a la competencia.", x, cy, w, INK, UIFont.Small)
    cy = cy + 10

    self:drawText("RECOMPENSA", x, cy, INK[1], INK[2], INK[3], 1, UIFont.Small)
    cy = cy + 18
    for _, line in ipairs({
        "Oro, diamantes y fajos de dinero.",
        "Suministros de mid-game y municion.",
        "2 niveles de Destreza (Nimble).",
    }) do
        cy = drawWrapped(self, "- " .. line, x, cy, w, INK_SOFT, UIFont.Small)
    end
end

-- ---- apertura desde el menu contextual de la mesa ----------------------

function LastPurpose.openComputer(player)
    player = player or LastPurpose.getPlayerSafe(0)
    if not player or not LastPurpose.isBurglar(player) then return end

    if LastPurpose.computer then
        LastPurpose.computer:onClose()
    end

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

-- Cerrar con Escape. Se registra una sola vez.
if not LastPurpose.computerKeyHook then
    LastPurpose.computerKeyHook = true
    Events.OnKeyPressed.Add(function(key)
        if key == Keyboard.KEY_ESCAPE and LastPurpose.computer then
            LastPurpose.computer:onClose()
        end
    end)
end
