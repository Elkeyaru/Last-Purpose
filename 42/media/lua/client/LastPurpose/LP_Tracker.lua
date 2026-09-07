require "ISUI/ISPanel"
require "ISUI/ISButton"

LastPurpose = LastPurpose or {}
LPGoalTracker = ISPanel:derive("LPGoalTracker")

local PANEL_WIDTH, PANEL_HEIGHT = 560, 320
local HEADER_HEIGHT = 28
local PAGE_MARGIN = 10
local SPINE_WIDTH = 14
local ROW_HEIGHT = 26

-- Paleta "libro de cuero": tapa oscura, paginas color pergamino, tinta en
-- vez de los tonos de HUD que tenia la version anterior.
local INK = {
    title = { 0.22, 0.15, 0.08 },
    body = { 0.30, 0.22, 0.13 },
    muted = { 0.55, 0.48, 0.38 },
    done = { 0.20, 0.42, 0.20 },
    current = { 0.55, 0.10, 0.08 },
    locked = { 0.72, 0.68, 0.60 },
    alert = { 0.55, 0.12, 0.10 },
}
local COVER_COLOR = { 0.20, 0.13, 0.08 }
local PAGE_COLOR = { 0.93, 0.87, 0.72 }
local PAGE_BORDER = { 0.55, 0.42, 0.28 }

-- ---------------------------------------------------------------------------
-- Capitulos: agrupan las 13 etapas internas en 7 "paginas" narrativas para
-- el indice del libro. fromStage/toStageExclusive usan los mismos nombres
-- de LastPurpose.STAGE_ORDER, asi que no duplican logica de progreso.
-- ---------------------------------------------------------------------------
local CHAPTERS = {
    { id = "prep", title = "I. Preparar el golpe", fromStage = "inactive", toStageExclusive = "radio_prompted",
      recap = "Reuniste el equipo necesario y esperaste tu momento." },
    { id = "radio", title = "II. La transmision", fromStage = "radio_prompted", toStageExclusive = "radio_heard",
      recap = "Encontraste la senal correcta entre la estatica." },
    { id = "clue", title = "III. El punto de reunion", fromStage = "radio_heard", toStageExclusive = "note_read",
      recap = "Hallaste y leiste la nota cifrada." },
    { id = "scout", title = "IV. Reconocimiento", fromStage = "note_read", toStageExclusive = "heist_active",
      recap = "Estudiaste las entradas del banco sin ser visto." },
    { id = "heist", title = "V. El golpe", fromStage = "heist_active", toStageExclusive = "loot_taken",
      recap = "Entraste al banco y tomaste el botin." },
    { id = "escape", title = "VI. La huida", fromStage = "loot_taken", toStageExclusive = "review_loot",
      recap = "Escapaste de Louisville con vida y el botin." },
    { id = "ending", title = "VII. El refugio", fromStage = "review_loot", toStageExclusive = nil,
      recap = "Revisaste el botin en tu refugio. El golpe termino." },
}

local function chapterStatus(chapter, data)
    if LastPurpose.stageBefore(data, chapter.fromStage) then return "locked" end
    if chapter.toStageExclusive then
        if LastPurpose.stageAtLeast(data, chapter.toStageExclusive) then return "done" end
        return "current"
    end
    if LastPurpose.stageIs(data, "completed") then return "done" end
    return "current"
end

function LPGoalTracker:new(x, y, w, h)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.background = false
    o.border = false
    o.moveWithMouse = false
    o.dragging = false
    o.chapterHitboxes = {}
    return o
end

function LPGoalTracker:initialise()
    ISPanel.initialise(self)
end

function LPGoalTracker:createChildren()
    ISPanel.createChildren(self)
    self.closeButton = ISButton:new(self.width - 27, 4, 20, 20, "X", self, LPGoalTracker.onClose)
    self.closeButton:initialise()
    self.closeButton:instantiate()
    self:addChild(self.closeButton)
end

function LPGoalTracker:onClose()
    self:setVisible(false)
    local player = LastPurpose.getPlayerSafe(0)
    if player and LastPurpose.isBurglar(player) then LastPurpose.getData(player).trackerVisible = false end
end

function LPGoalTracker:onMouseDown(x, y)
    if y <= HEADER_HEIGHT and x < self.width - HEADER_HEIGHT then
        self.dragging = true
        self.dragOffsetX = getMouseX() - self:getX()
        self.dragOffsetY = getMouseY() - self:getY()
        self:setCapture(true)
        return true
    end

    for _, box in ipairs(self.chapterHitboxes) do
        if box.clickable and x >= box.x and x <= box.x + box.w and y >= box.y and y <= box.y + box.h then
            self.selectedChapterId = box.id
            return true
        end
    end

    return ISPanel.onMouseDown(self, x, y)
end

function LPGoalTracker:onMouseMoveOutside(dx, dy)
    return self:onMouseMove(dx, dy)
end

function LPGoalTracker:onMouseMove(dx, dy)
    if not self.dragging then return ISPanel.onMouseMove(self, dx, dy) end
    local maxX = math.max(0, getCore():getScreenWidth() - self.width)
    local maxY = math.max(0, getCore():getScreenHeight() - self.height)
    self:setX(math.max(0, math.min(maxX, getMouseX() - self.dragOffsetX)))
    self:setY(math.max(0, math.min(maxY, getMouseY() - self.dragOffsetY)))
    return true
end

function LPGoalTracker:stopDragging()
    local wasDragging = self.dragging
    self.dragging = false
    self:setCapture(false)
    if not wasDragging then return end
    local player = LastPurpose.getPlayerSafe(0)
    if player and LastPurpose.isBurglar(player) then
        local data = LastPurpose.getData(player)
        data.trackerX = math.floor(self:getX())
        data.trackerY = math.floor(self:getY())
    end
end

function LPGoalTracker:onMouseUp(x, y)
    self:stopDragging()
    return ISPanel.onMouseUp(self, x, y)
end

function LPGoalTracker:onMouseUpOutside(x, y)
    self:stopDragging()
end

function LPGoalTracker:update()
    ISPanel.update(self)
    if self.dragging and not isMouseButtonDown(0) then self:stopDragging() end
end

-- ===== Contenido de la pagina derecha por etapa exacta =====
--
-- Project Zomboid no recorta drawText() al ancho del contenedor, asi que las
-- frases largas se salian por el borde derecho del libro. Ahora todo el
-- texto pasa por drawWrapped(): parte la frase en palabras, mide cada linea
-- con el TextManager y devuelve la Y siguiente. Cada renderer avanza un
-- cursor vertical con ese valor en vez de usar desplazamientos fijos
-- (y + 28, y + 52...) que se solapaban en cuanto una linea se ajustaba a dos.

local BODY_GAP = 8

local function lineHeight(font)
    return getTextManager():getFontHeight(font) + 3
end

local function drawWrapped(self, x, y, w, text, color, font)
    font = font or UIFont.Small
    local tm = getTextManager()
    local lh = lineHeight(font)
    local line = ""
    for word in string.gmatch(tostring(text), "%S+") do
        local candidate = (line == "") and word or (line .. " " .. word)
        if line ~= "" and tm:MeasureStringX(font, candidate) > w then
            self:drawText(line, x, y, color[1], color[2], color[3], 1, font)
            y = y + lh
            line = word
        else
            line = candidate
        end
    end
    if line ~= "" then
        self:drawText(line, x, y, color[1], color[2], color[3], 1, font)
        y = y + lh
    end
    return y
end

-- Compat: una sola linea sin ajuste, solo para textos cortos garantizados
-- (el aviso de "sin historia para esta profesion").
local function drawLine(self, x, text, y, color)
    self:drawText(text, x, y, color[1], color[2], color[3], 1, UIFont.Small)
end

local function drawTitle(self, x, y, w, text)
    return drawWrapped(self, x, y, w, text, INK.title, UIFont.Medium) + BODY_GAP
end

local function drawBody(self, x, y, w, text, color)
    return drawWrapped(self, x, y, w, text, color or INK.body, UIFont.Small)
end

local function drawPrepStage(self, x, y, w, player, data)
    local days = LastPurpose.getDaysSurvived(player)
    local remaining = math.max(0, LastPurpose.ACTIVATION_DAYS - days)

    local cy = drawTitle(self, x, y, w, "Algo quedo pendiente...")
    if LastPurpose.DEBUG_FAST_ACTIVATION then
        cy = drawBody(self, x, cy, w, string.format("Sobrevive %.0f minutos mas", remaining * 24 * 60))
    else
        cy = drawBody(self, x, cy, w, string.format("Sobrevive %.1f dias mas", remaining))
    end

    cy = cy + 6
    local progress = math.min(days / LastPurpose.ACTIVATION_DAYS, 1)
    self:drawRect(x, cy, w, 10, 0.35, 0.55, 0.42, 0.28)
    self:drawRect(x + 2, cy + 2, math.max(0, (w - 4) * progress), 6, 0.85, 0.35, 0.12, 0.10)
    self:drawRectBorder(x, cy, w, 10, 0.55, 0.40, 0.30, 0.20)
    cy = cy + 20

    if LastPurpose.DEBUG_FAST_ACTIVATION then
        drawBody(self, x, cy, w, string.format("Minuto %.0f / %d", days * 24 * 60, LastPurpose.ACTIVATION_MINUTES), INK.muted)
    else
        drawBody(self, x, cy, w, string.format("Dia %.1f / %d", days, LastPurpose.ACTIVATION_DAYS), INK.muted)
    end
end

local function drawObjectives(self, x, y, w, data)
    local cy = drawTitle(self, x, y, w, "Preparar el golpe")
    for _, goal in ipairs(LastPurpose.OBJECTIVES) do
        local done = data.objectives[goal.key] == true
        local color = done and INK.done or INK.muted
        cy = drawBody(self, x, cy, w, (done and "[X] " or "[ ] ") .. goal.label, color)
    end
end

local function drawPrepCompleted(self, x, y, w)
    local cy = drawTitle(self, x, y, w, "Mision completada")
    drawBody(self, x, cy, w, "Ya tienes todo lo necesario.")
end

local function drawRadioStage(self, x, y, w)
    local cy = drawTitle(self, x, y, w, "Intercepta la transmision")
    if LastPurpose.DEBUG_SHOW_EXACT_FREQUENCY then
        local frequency = LastPurpose.getStoryFrequency()
        cy = drawBody(self, x, cy, w, "Frecuencia de depuracion:", INK.muted)
        drawWrapped(self, x, cy, w,
            frequency and string.format("%.1f MHz", frequency / 1000) or "Esperando registro del canal...",
            INK.current, UIFont.Medium)
        return
    end

    cy = drawBody(self, x, cy, w, "Prueba estas posibles frecuencias:")
    local candidates = LastPurpose.getStoryFrequencyCandidates()
    if not candidates or #candidates == 0 then
        drawBody(self, x, cy, w, "Buscando senales disponibles...", INK.current)
        return
    end
    cy = cy + 4
    local colW = w / 2
    local rowH = lineHeight(UIFont.Small) + 2
    for i = 1, math.min(#candidates, 10) do
        local column = math.floor((i - 1) / 5)
        local row = (i - 1) % 5
        self:drawText(
            string.format("%.1f MHz", candidates[i] / 1000),
            x + column * colW, cy + row * rowH,
            INK.current[1], INK.current[2], INK.current[3], 1, UIFont.Small
        )
    end
end

local function drawClueStage(self, x, y, w, player, data)
    local heist = LastPurpose.ensureSelectedHeist(player)
    local clue = heist and LastPurpose.getHeistClue(data, heist)
    local cy = drawTitle(self, x, y, w, "Investiga la pista")
    cy = drawBody(self, x, cy, w, clue and clue.destination or "Punto de reunion desconocido", INK.current)
    if clue then
        local dx, dy = clue.x - player:getX(), clue.y - player:getY()
        drawBody(self, x, cy, w, string.format("Distancia a la pista: %.0f m", math.sqrt(dx * dx + dy * dy)))
    end
end

local function drawNoteStage(self, x, y, w, player)
    local hasNote = LastPurpose.findClueNote and LastPurpose.findClueNote(player) ~= nil
    local cy = drawTitle(self, x, y, w, hasNote and "Lee la nota" or "Registra el punto")
    cy = drawBody(self, x, cy, w, hasNote and "Lee la nota cifrada que encontraste." or "Encuentra la nota que dejaron atras.", INK.current)
    drawBody(self, x, cy, w, hasNote and "Usa la accion de lectura del juego." or "La nota revelara el objetivo.")
end

local function drawScoutStage(self, x, y, w, player)
    local heist = LastPurpose.ensureSelectedHeist(player)
    local cy = drawTitle(self, x, y, w, "Reconoce el objetivo")
    cy = drawBody(self, x, cy, w, heist and heist.destination or "Knox Bank", INK.current)
    drawBody(self, x, cy, w, "Acercate al banco sin entrar.")
end

local function drawWaitForNightStage(self, x, y, w)
    local cy = drawTitle(self, x, y, w, "Espera la oscuridad")
    cy = drawBody(self, x, cy, w, "Reconocimiento completado.", INK.done)
    drawBody(self, x, cy, w, "El banco sigue sellado. Llega entre las 20:00 y las 05:00 para iniciar el golpe.", INK.current)
end

local function drawHeistActiveStage(self, x, y, w, data)
    local cy = drawTitle(self, x, y, w, "El golpe ha comenzado")
    cy = drawBody(self, x, cy, w, "Encuentra el botin dentro del banco.", INK.current)
    if data.lootSpawned then drawBody(self, x, cy, w, "Busca junto a los dos cadaveres.", INK.muted) end
end

local function drawLootTakenStage(self, x, y, w, data)
    local cy = drawTitle(self, x, y, w, "Escapa con el botin")
    cy = drawBody(self, x, cy, w, "Botin del Knox Bank asegurado.", INK.current)
    if data.ambushTriggered and not data.ambushCompleted then
        cy = drawBody(self, x, cy, w, "ALERTA: escapa del banco ahora.", INK.alert)
        drawBody(self, x, cy, w, string.format("Amenaza: oleada %d / 5", tonumber(data.ambushWavesSpawned) or 0), INK.muted)
    else
        drawBody(self, x, cy, w, "Sal de Louisville con vida.", INK.alert)
    end
end

local function drawReturningStage(self, x, y, w, player, data)
    local cy = drawTitle(self, x, y, w, "Vuelve al refugio")
    if data.safehousePlaced and data.safehouseX then
        local dx, dy = data.safehouseX - player:getX(), data.safehouseY - player:getY()
        cy = drawBody(self, x, cy, w, "La mesa marca tu base segura.", INK.current)
        drawBody(self, x, cy, w, string.format("Distancia al refugio: %.0f m", math.sqrt(dx * dx + dy * dy)))
    else
        drawBody(self, x, cy, w, "Debes colocar otra mesa.", INK.alert)
    end
end

local function drawReviewLootStage(self, x, y, w)
    local cy = drawTitle(self, x, y, w, "Revisa el botin")
    cy = drawBody(self, x, cy, w, "Has vuelto al refugio con vida.", INK.done)
    drawBody(self, x, cy, w, "Usa la mesa para revisar el botin.")
end

local function drawCompletedStage(self, x, y, w)
    local cy = drawTitle(self, x, y, w, "Golpe completado")
    cy = drawBody(self, x, cy, w, "Has vuelto al refugio con vida.", INK.done)
    drawBody(self, x, cy, w, "Recompensa asegurada.")
end

-- Una entrada por etapa exacta (no por capitulo): un mismo capitulo del
-- libro puede cubrir mas de una etapa interna (por ejemplo "III. El punto
-- de reunion" cubre tanto viajar hasta el punto como leer la nota).
local STAGE_RENDERERS = {
    radio_prompted = function(self, x, y, w, player, data) drawRadioStage(self, x, y, w) end,
    radio_heard = function(self, x, y, w, player, data) drawClueStage(self, x, y, w, player, data) end,
    clue_found = function(self, x, y, w, player, data) drawNoteStage(self, x, y, w, player) end,
    note_read = function(self, x, y, w, player, data) drawScoutStage(self, x, y, w, player) end,
    bank_scouted = function(self, x, y, w, player, data) drawWaitForNightStage(self, x, y, w) end,
    heist_active = function(self, x, y, w, player, data) drawHeistActiveStage(self, x, y, w, data) end,
    loot_taken = function(self, x, y, w, player, data) drawLootTakenStage(self, x, y, w, data) end,
    returning = function(self, x, y, w, player, data) drawReturningStage(self, x, y, w, player, data) end,
    review_loot = function(self, x, y, w, player, data) drawReviewLootStage(self, x, y, w) end,
    completed = function(self, x, y, w, player, data) drawCompletedStage(self, x, y, w) end,
}

local function drawRightPage(self, x, y, w, player, data)
    if LastPurpose.stageIs(data, "inactive") then
        drawPrepStage(self, x, y, w, player, data)
        return
    end
    if LastPurpose.stageIs(data, "prep_started") then
        drawObjectives(self, x, y, w, data)
        return
    end
    if LastPurpose.stageIs(data, "prep_completed") then
        drawPrepCompleted(self, x, y, w)
        return
    end

    -- Si el jugador esta mirando un capitulo ya completado (hizo clic en el
    -- indice), mostramos la recapitulacion en vez del contenido en vivo.
    if self.selectedChapterId and self.selectedChapterId ~= self.currentChapterId then
        for _, chapter in ipairs(CHAPTERS) do
            if chapter.id == self.selectedChapterId then
                local cy = drawTitle(self, x, y, w, chapter.title)
                drawBody(self, x, cy, w, chapter.recap)
                return
            end
        end
    end

    local renderer = STAGE_RENDERERS[data.stage]
    if renderer then renderer(self, x, y, w, player, data) end
end

-- ===== Pintado del libro completo =====

local function drawBookChrome(self)
    self:drawRect(0, 0, self.width, self.height, 0.90, COVER_COLOR[1], COVER_COLOR[2], COVER_COLOR[3])
    self:drawRect(0, 0, self.width, HEADER_HEIGHT, 0.95, 0.14, 0.09, 0.06)
    self:drawRectBorder(0, 0, self.width, self.height, 0.60, 0.05, 0.03, 0.02)
    self:drawText("EL ULTIMO GOLPE", 10, 7, 0.82, 0.70, 0.45, 1, UIFont.Small)
end

local function drawPageBackground(self, x, y, w, h)
    self:drawRect(x, y, w, h, 0.98, PAGE_COLOR[1], PAGE_COLOR[2], PAGE_COLOR[3])
    self:drawRectBorder(x, y, w, h, 0.60, PAGE_BORDER[1], PAGE_BORDER[2], PAGE_BORDER[3])
end

local function drawSpineShadow(self, x, y, h)
    -- Un par de franjas semitransparentes a cada lado del lomo simulan la
    -- sombra donde se doblan las paginas.
    self:drawRect(x - 8, y, 8, h, 0.18, 0, 0, 0)
    self:drawRect(x + SPINE_WIDTH, y, 8, h, 0.18, 0, 0, 0)
    self:drawRect(x, y, SPINE_WIDTH, h, 0.85, 0.12, 0.08, 0.05)
end

local function drawChapterIndex(self, x, y, w, h, data)
    self.chapterHitboxes = {}
    self:drawText("Indice", x, y, INK.title[1], INK.title[2], INK.title[3], 1, UIFont.Small)

    local rowY = y + 22
    for _, chapter in ipairs(CHAPTERS) do
        local status = chapterStatus(chapter, data)
        if status == "current" then self.currentChapterId = chapter.id end

        local color = INK.locked
        local marker = "  "
        if status == "done" then color, marker = INK.done, "+ "
        elseif status == "current" then color, marker = INK.current, "> " end

        self:drawText(marker .. chapter.title, x, rowY, color[1], color[2], color[3], 1, UIFont.Small)

        if status ~= "locked" then
            table.insert(self.chapterHitboxes, { id = chapter.id, x = x, y = rowY - 2, w = w, h = ROW_HEIGHT, clickable = true })
        end
        rowY = rowY + ROW_HEIGHT
    end
end

function LPGoalTracker:prerender()
    ISPanel.prerender(self)
    drawBookChrome(self)

    local player = LastPurpose.getPlayerSafe(0)
    if not player then return end
    if not LastPurpose.isBurglar(player) then
        drawLine(self, 12, "Sin historia para esta profesion", HEADER_HEIGHT + 20, { 0.75, 0.72, 0.66 })
        return
    end

    local data = LastPurpose.getData(player)

    -- Golpe terminado: el diario se cierra solo y no se vuelve a abrir. Se
    -- comprueba en cada frame para atrapar el instante en que la etapa pasa
    -- a "completed" con el libro abierto.
    if LastPurpose.stageIs(data, "completed") then
        data.trackerVisible = false
        self:setVisible(false)
        return
    end

    if LastPurpose.stageIs(data, "inactive") or LastPurpose.stageIs(data, "prep_started") or LastPurpose.stageIs(data, "prep_completed") then
        -- Todavia no hay capitulos que mostrar: una sola pagina con el
        -- progreso de preparacion, a todo el ancho.
        local pageX, pageY = PAGE_MARGIN, HEADER_HEIGHT + PAGE_MARGIN
        local pageW, pageH = self.width - PAGE_MARGIN * 2, self.height - HEADER_HEIGHT - PAGE_MARGIN * 2
        drawPageBackground(self, pageX, pageY, pageW, pageH)
        drawRightPage(self, pageX + 16, pageY + 14, pageW - 32, player, data)
        return
    end

    if self.lastStage ~= data.stage then
        self.selectedChapterId = nil
        self.lastStage = data.stage
    end

    local leftX, pageY = PAGE_MARGIN, HEADER_HEIGHT + PAGE_MARGIN
    local pageH = self.height - HEADER_HEIGHT - PAGE_MARGIN * 2
    local pageW = (self.width - PAGE_MARGIN * 2 - SPINE_WIDTH) / 2
    local rightX = leftX + pageW + SPINE_WIDTH

    drawPageBackground(self, leftX, pageY, pageW, pageH)
    drawPageBackground(self, rightX, pageY, pageW, pageH)
    drawSpineShadow(self, leftX + pageW, pageY, pageH)

    drawChapterIndex(self, leftX + 14, pageY + 12, pageW - 24, pageH - 24, data)
    drawRightPage(self, rightX + 14, pageY + 14, pageW - 28, player, data)
end

function LastPurpose.ensureTracker(playerIndex, player)
    player = player or LastPurpose.getPlayerSafe(playerIndex)
    if not player then return end
    if not LastPurpose.isBurglar(player) then return end

    LastPurpose.updateProgress(player)

    -- Golpe terminado: si el diario ya existe se oculta, y no se crea uno
    -- nuevo. El jugador ya no puede abrirlo.
    if LastPurpose.stageIs(LastPurpose.getData(player), "completed") then
        if LastPurpose.tracker then LastPurpose.tracker:setVisible(false) end
        LastPurpose.getData(player).trackerVisible = false
        return
    end

    if not LastPurpose.tracker then
        local data = LastPurpose.getData(player)
        local defaultX = getCore():getScreenWidth() - PANEL_WIDTH - 25
        local savedX = tonumber(data.trackerX) or defaultX
        local savedY = tonumber(data.trackerY) or 90
        local x = math.max(0, math.min(getCore():getScreenWidth() - PANEL_WIDTH, savedX))
        local y = math.max(0, math.min(getCore():getScreenHeight() - PANEL_HEIGHT, savedY))

        LastPurpose.tracker = LPGoalTracker:new(x, y, PANEL_WIDTH, PANEL_HEIGHT)
        LastPurpose.tracker:initialise()
        LastPurpose.tracker:addToUIManager()
        LastPurpose.debugPrint("Ladron detectado; tracker creado (v" .. LastPurpose.VERSION .. ")")
    end
    LastPurpose.tracker:setVisible(LastPurpose.getData(player).trackerVisible ~= false)
end

function LastPurpose.onKeyPressed(key)
    -- La tecla se resuelve aqui, dentro de la funcion: la configura el panel
    -- de opciones (LP_Options.getTrackerKey) y por defecto es J. Si el panel
    -- aun no cargo, getTrackerKey no existe todavia y se cae a J.
    local wantKey = LastPurpose.getTrackerKey and LastPurpose.getTrackerKey() or Keyboard.KEY_J
    if key ~= wantKey then return end
    local player = LastPurpose.getPlayerSafe(0)
    if not player or not LastPurpose.isBurglar(player) then return end

    local data = LastPurpose.getData(player)
    -- Con el golpe terminado el diario deja de ser accesible.
    if LastPurpose.stageIs(data, "completed") then
        data.trackerVisible = false
        if LastPurpose.tracker then LastPurpose.tracker:setVisible(false) end
        return
    end

    LastPurpose.ensureTracker(0, player)
    if not LastPurpose.tracker then return end
    data.trackerVisible = not LastPurpose.tracker:getIsVisible()
    LastPurpose.tracker:setVisible(data.trackerVisible)
end
