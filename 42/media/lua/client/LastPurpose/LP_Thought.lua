require "ISUI/ISPanel"

LastPurpose = LastPurpose or {}
LastPurposeThought = ISPanel:derive("LastPurposeThought")

function LastPurposeThought:new(player, lines, durationMs)
    local panel = ISPanel.new(self, 0, 0, 560, 62)
    panel.player = player
    panel.lines = lines
    panel.expiresAt = getTimestampMs() + durationMs
    panel.backgroundColor = { r=0, g=0, b=0, a=0 }
    panel.borderColor = { r=0, g=0, b=0, a=0 }
    panel.moveWithMouse = false
    return panel
end

function LastPurposeThought:prerender()
    if not self.player or getTimestampMs() >= self.expiresAt then
        self:removeFromUIManager()
        if LastPurpose.thoughtPanel == self then LastPurpose.thoughtPanel = nil end
        return
    end
    local screenX = isoToScreenX(0, self.player:getX(), self.player:getY(), self.player:getZ())
    local screenY = isoToScreenY(0, self.player:getX(), self.player:getY(), self.player:getZ())
    self:setX(math.max(10, math.min(screenX - self.width / 2, getCore():getScreenWidth() - self.width - 10)))
    self:setY(math.max(10, screenY - 150))
    ISPanel.prerender(self)
end

function LastPurposeThought:render()
    for index, line in ipairs(self.lines) do
        local y = 8 + ((index - 1) * 24)
        self:drawTextCentre(line, (self.width / 2) + 1, y + 1, 0, 0, 0.08, 0.90, UIFont.Medium)
        self:drawTextCentre(line, self.width / 2, y, 0.25, 0.58, 1.00, 1, UIFont.Medium)
        self:drawTextCentre(line, (self.width / 2) + 1, y, 0.25, 0.58, 1.00, 0.92, UIFont.Medium)
    end
end

function LastPurpose.showThought(player, lines)
    if LastPurpose.thoughtPanel then LastPurpose.thoughtPanel:removeFromUIManager() end
    local panel = LastPurposeThought:new(player, lines, 8000)
    panel:initialise()
    panel:addToUIManager()
    LastPurpose.thoughtPanel = panel
end
