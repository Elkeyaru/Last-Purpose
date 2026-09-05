require "ISUI/ISPanel"
require "ISUI/ISButton"
LastPurpose=LastPurpose or {}; LPGoalTracker=ISPanel:derive("LPGoalTracker")
function LPGoalTracker:initialise() ISPanel.initialise(self) end
function LPGoalTracker:createChildren()
 ISPanel.createChildren(self); self.closeButton=ISButton:new(self.width-27,5,22,22,"X",self,LPGoalTracker.onClose)
 self.closeButton:initialise(); self.closeButton:instantiate(); self:addChild(self.closeButton)
end
function LPGoalTracker:onClose()
 self:setVisible(false); local p=LastPurpose.getPlayerSafe(0)
 if p and LastPurpose.isBurglar(p) then LastPurpose.getData(p).trackerVisible=false end
end
function LPGoalTracker:onMouseDown(x,y)
 if y<=32 and x<self.width-32 then
  self.dragging=true
  self.dragOffsetX=getMouseX()-self:getX()
  self.dragOffsetY=getMouseY()-self:getY()
  self:setCapture(true)
  return true
 end
 return ISPanel.onMouseDown(self,x,y)
end
function LPGoalTracker:onMouseMoveOutside(dx,dy)
 return self:onMouseMove(dx,dy)
end
function LPGoalTracker:onMouseMove(dx,dy)
 if self.dragging then
  local maxX=math.max(0,getCore():getScreenWidth()-self.width)
  local maxY=math.max(0,getCore():getScreenHeight()-self.height)
  self:setX(math.max(0,math.min(maxX,getMouseX()-self.dragOffsetX)))
  self:setY(math.max(0,math.min(maxY,getMouseY()-self.dragOffsetY)))
  return true
 end
 return ISPanel.onMouseMove(self,dx,dy)
end
function LPGoalTracker:stopDragging()
 local wasDragging=self.dragging
 self.dragging=false
 self:setCapture(false)
 if wasDragging then
  local p=LastPurpose.getPlayerSafe(0)
  if p and LastPurpose.isBurglar(p) then
   local d=LastPurpose.getData(p)
   d.trackerX=math.floor(self:getX())
   d.trackerY=math.floor(self:getY())
  end
 end
end
function LPGoalTracker:onMouseUp(x,y)
 self:stopDragging()
 return ISPanel.onMouseUp(self,x,y)
end
function LPGoalTracker:onMouseUpOutside(x,y)
 self:stopDragging()
end
function LPGoalTracker:update()
 ISPanel.update(self)
 if self.dragging and not isMouseButtonDown(0) then self:stopDragging() end
end
function LPGoalTracker:prerender()
 ISPanel.prerender(self); self:drawRect(0,0,self.width,self.height,0.82,0.055,0.065,0.075)
 self:drawRect(0,0,self.width,32,0.95,0.10,0.12,0.14); self:drawRectBorder(0,0,self.width,self.height,0.75,0.45,0.50,0.55)
 self:drawText("PROPÓSITO",12,8,0.45,0.72,1.00,1,UIFont.Small)
 local p=LastPurpose.getPlayerSafe(0); if not p then return end
 if not LastPurpose.isBurglar(p) then self:drawText("Sin historia para esta profesión",12,47,0.70,0.70,0.70,1,UIFont.Small); return end
 local d=LastPurpose.getData(p); local days=LastPurpose.getDaysSurvived(p)
 if not d.active then
  local remaining=math.max(0,LastPurpose.ACTIVATION_DAYS-days)
  self:drawText("Algo quedo pendiente...",12,44,0.92,0.92,0.92,1,UIFont.Medium)
  if LastPurpose.DEBUG_FAST_ACTIVATION then
   self:drawText(string.format("Sobrevive %.0f minutos más",remaining*24*60),12,72,0.72,0.78,0.82,1,UIFont.Small)
  else
   self:drawText(string.format("Sobrevive %.1f días más",remaining),12,72,0.72,0.78,0.82,1,UIFont.Small)
  end
  local progress=math.min(days/LastPurpose.ACTIVATION_DAYS,1); local width=self.width-24
  self:drawRect(12,102,width,12,0.90,0.10,0.12,0.14); self:drawRect(14,104,math.max(0,(width-4)*progress),8,1.00,0.36,0.58,0.74)
  self:drawRectBorder(12,102,width,12,0.70,0.45,0.50,0.55)
  if LastPurpose.DEBUG_FAST_ACTIVATION then
   self:drawText(string.format("Minuto %.0f / %d",days*24*60,LastPurpose.ACTIVATION_MINUTES),12,121,0.65,0.68,0.72,1,UIFont.Small)
  else
   self:drawText(string.format("Día %.1f / %d",days,LastPurpose.ACTIVATION_DAYS),12,121,0.65,0.68,0.72,1,UIFont.Small)
  end
 elseif d.stage==3 then
  self:drawText("INTERCEPTAR LA TRANSMISIÓN",12,44,0.45,0.72,1.00,1,UIFont.Medium)
  self:drawText("Prueba estas posibles frecuencias:",12,72,0.72,0.78,0.82,1,UIFont.Small)
  local candidates=LastPurpose.getStoryFrequencyCandidates()
  if candidates and #candidates==10 then
   for i=1,5 do
    self:drawText(string.format("%.1f MHz",candidates[i]/1000),12,92+((i-1)*22),0.90,0.74,0.38,1,UIFont.Small)
    self:drawText(string.format("%.1f MHz",candidates[i+5]/1000),180,92+((i-1)*22),0.90,0.74,0.38,1,UIFont.Small)
   end
  else
   self:drawText("Buscando señales disponibles...",12,100,0.90,0.74,0.38,1,UIFont.Small)
  end
 elseif d.storyFlowVersion==2 and d.stage==4 then
  local heist=LastPurpose.ensureSelectedHeist(p); local clue=heist and LastPurpose.getHeistClue(d,heist)
  self:drawText("INVESTIGA LA PISTA",12,44,0.92,0.92,0.92,1,UIFont.Medium)
  self:drawText(clue and clue.destination or "Punto de reunión desconocido",12,76,0.90,0.74,0.38,1,UIFont.Small)
  if clue then
   local dx=clue.x-p:getX(); local dy=clue.y-p:getY(); local distance=math.sqrt((dx*dx)+(dy*dy))
   self:drawText(string.format("Distancia a la pista: %.0f m",distance),12,100,0.72,0.78,0.82,1,UIFont.Small)
  end
 elseif d.storyFlowVersion==2 and d.stage==5 then
  local hasNote=LastPurpose.findClueNote and LastPurpose.findClueNote(p)~=nil
  self:drawText(hasNote and "LEE LA NOTA" or "REGISTRA EL PUNTO",12,44,0.92,0.92,0.92,1,UIFont.Medium)
  self:drawText(hasNote and "Lee la nota cifrada que encontraste." or "Encuentra la nota que dejaron atras.",12,76,0.90,0.74,0.38,1,UIFont.Small)
  self:drawText(hasNote and "Usa la accion de lectura del juego." or "La nota revelara el objetivo.",12,100,0.72,0.78,0.82,1,UIFont.Small)
 elseif d.storyFlowVersion==2 and d.stage==6 then
  local heist=LastPurpose.ensureSelectedHeist(p)
  self:drawText("RECONOCE EL OBJETIVO",12,44,0.92,0.92,0.92,1,UIFont.Medium)
  self:drawText(heist and heist.destination or "Knox Bank",12,76,0.90,0.74,0.38,1,UIFont.Small)
  self:drawText("Acércate al banco sin entrar.",12,100,0.72,0.78,0.82,1,UIFont.Small)
 elseif d.storyFlowVersion==2 and d.stage==8 then
  self:drawText("ESPERA LA OSCURIDAD",12,44,0.92,0.92,0.92,1,UIFont.Medium)
  self:drawText("El vehículo de fuga está preparado.",12,76,0.45,0.86,0.55,1,UIFont.Small)
  self:drawText("Entra al banco entre las 20:00 y 05:00.",12,100,0.90,0.74,0.38,1,UIFont.Small)
 elseif d.storyFlowVersion==2 and d.stage==9 then
  self:drawText("EL GOLPE HA COMENZADO",12,44,0.92,0.92,0.92,1,UIFont.Medium)
  self:drawText("Encuentra el botín dentro del banco.",12,76,0.90,0.74,0.38,1,UIFont.Small)
  if d.lootSpawned then self:drawText("Busca junto a los dos cadáveres.",12,100,0.65,0.68,0.72,1,UIFont.Small) end
 elseif d.storyFlowVersion==2 and d.stage==11 then
  self:drawText("VUELVE AL REFUGIO",12,44,0.92,0.92,0.92,1,UIFont.Medium)
  if d.safehousePlaced and d.safehouseX then
   local dx=d.safehouseX-p:getX(); local dy=d.safehouseY-p:getY(); local distance=math.sqrt((dx*dx)+(dy*dy))
   self:drawText("La mesa marca tu base segura.",12,76,0.90,0.74,0.38,1,UIFont.Small)
   self:drawText(string.format("Distancia al refugio: %.0f m",distance),12,100,0.72,0.78,0.82,1,UIFont.Small)
  end
 elseif d.storyFlowVersion==2 and d.stage==12 then
  self:drawText("REVISA EL BOTÍN",12,44,0.45,0.72,1.00,1,UIFont.Medium)
  self:drawText("Has vuelto al refugio con vida.",12,76,0.45,0.86,0.55,1,UIFont.Small)
  self:drawText("Usa la mesa para revisar el botín.",12,100,0.72,0.78,0.82,1,UIFont.Small)
 elseif d.storyFlowVersion==2 and d.stage>=13 then
  self:drawText("GOLPE COMPLETADO",12,44,0.92,0.92,0.92,1,UIFont.Medium)
  self:drawText("Has vuelto al refugio con vida.",12,76,0.45,0.86,0.55,1,UIFont.Small)
  self:drawText("Recompensa asegurada.",12,100,0.72,0.78,0.82,1,UIFont.Small)
 elseif d.storyFlowVersion==2 and d.stage==10 then
  self:drawText("ESCAPA CON EL BOTÍN",12,44,0.45,0.72,1.00,1,UIFont.Medium)
  self:drawText("Botín del Knox Bank asegurado.",12,76,0.90,0.74,0.38,1,UIFont.Small)
  if d.ambushTriggered and not d.ambushCompleted then
   self:drawText("ALERTA: escapa del banco ahora.",12,100,0.92,0.32,0.28,1,UIFont.Small)
   self:drawText(string.format("Amenaza detectada: oleada %d / 5",tonumber(d.ambushWavesSpawned) or 0),12,124,0.82,0.68,0.58,1,UIFont.Small)
  else
   self:drawText("Sal de Louisville con vida.",12,100,0.92,0.32,0.28,1,UIFont.Small)
  end
 elseif d.storyFlowVersion~=2 and d.stage==4 then
 local heist=LastPurpose.ensureSelectedHeist(p)
  self:drawText("EL ÚLTIMO GOLPE",12,44,0.45,0.72,1.00,1,UIFont.Medium)
  self:drawText("Misión: "..(heist and heist.mission or "Trabajo desconocido"),12,76,0.90,0.74,0.38,1,UIFont.Small)
  self:drawText("Destino: "..(heist and heist.destination or "Desconocido"),12,100,0.72,0.78,0.82,1,UIFont.Small)
  if heist then
   local dx=heist.x-p:getX(); local dy=heist.y-p:getY(); local distance=math.sqrt((dx*dx)+(dy*dy))
   local vertical=dy<0 and "N" or "S"; local horizontal=dx<0 and "O" or "E"; local direction
   if math.abs(dx)>math.abs(dy)*2 then direction=horizontal elseif math.abs(dy)>math.abs(dx)*2 then direction=vertical else direction=vertical..horizontal end
   local distanceText=distance>=1000 and string.format("%.1f km",distance/1000) or string.format("%.0f m",distance)
   self:drawText("Dirección: "..direction.."  |  Distancia: "..distanceText,12,124,0.65,0.68,0.72,1,UIFont.Small)
  end
 elseif d.storyFlowVersion~=2 and d.stage==5 then
  local heist=LastPurpose.ensureSelectedHeist(p)
  self:drawText("LUGAR LOCALIZADO",12,44,0.92,0.92,0.92,1,UIFont.Medium)
  self:drawText(heist and heist.title or "El golpe",12,76,0.90,0.74,0.38,1,UIFont.Small)
  self:drawText("Encuentra el botín dentro del edificio.",12,100,0.72,0.78,0.82,1,UIFont.Small)
  if d.lootSpawned then
   self:drawText("Busca junto a los dos cadáveres.",12,124,0.65,0.68,0.72,1,UIFont.Small)
  end
 elseif d.storyFlowVersion~=2 and d.stage==7 then
  self:drawText("VUELVE AL REFUGIO",12,44,0.92,0.92,0.92,1,UIFont.Medium)
  if d.safehousePlaced and d.safehouseX then
   local dx=d.safehouseX-p:getX(); local dy=d.safehouseY-p:getY(); local distance=math.sqrt((dx*dx)+(dy*dy))
   self:drawText("La mesa marca tu base segura.",12,76,0.90,0.74,0.38,1,UIFont.Small)
   self:drawText(string.format("Distancia al refugio: %.0f m",distance),12,100,0.72,0.78,0.82,1,UIFont.Small)
  else
   self:drawText("Debes colocar otra mesa.",12,76,0.92,0.32,0.28,1,UIFont.Small)
  end
 elseif d.storyFlowVersion~=2 and d.stage>=9 then
  self:drawText("GOLPE COMPLETADO",12,44,0.92,0.92,0.92,1,UIFont.Medium)
  self:drawText("Has vuelto al refugio con vida.",12,76,0.45,0.86,0.55,1,UIFont.Small)
  self:drawText("Recompensa asegurada.",12,100,0.72,0.78,0.82,1,UIFont.Small)
 elseif d.storyFlowVersion~=2 and d.stage==8 then
  self:drawText("REVISA EL BOTÍN",12,44,0.45,0.72,1.00,1,UIFont.Medium)
  self:drawText("Has vuelto al refugio con vida.",12,76,0.45,0.86,0.55,1,UIFont.Small)
  self:drawText("Usa la mesa para revisar el botín.",12,100,0.72,0.78,0.82,1,UIFont.Small)
 elseif d.storyFlowVersion~=2 and d.stage>=6 then
 self:drawText("ESCAPA CON EL BOTÍN",12,44,0.45,0.72,1.00,1,UIFont.Medium)
  self:drawText("Botín del Knox Bank asegurado.",12,76,0.90,0.74,0.38,1,UIFont.Small)
  if d.ambushTriggered and not d.ambushCompleted then
   self:drawText("ALERTA: escapa del banco ahora.",12,100,0.92,0.32,0.28,1,UIFont.Small)
   self:drawText(string.format("Amenaza detectada: oleada %d / 5",tonumber(d.ambushWavesSpawned) or 0),12,124,0.82,0.68,0.58,1,UIFont.Small)
  else
   self:drawText("Sal de Louisville con vida.",12,100,0.72,0.78,0.82,1,UIFont.Small)
  end
 elseif d.completed then
  self:drawText("PREPARAR EL GOLPE",12,44,0.92,0.92,0.92,1,UIFont.Medium)
  self:drawText("Misión completada",12,76,0.45,0.86,0.55,1,UIFont.Small)
  self:drawText("Ya tienes todo lo necesario.",12,100,0.72,0.78,0.82,1,UIFont.Small)
 else
  self:drawText("EL ÚLTIMO GOLPE",12,44,0.45,0.72,1.00,1,UIFont.Medium)
  self:drawText("Misión: Preparar el golpe",12,70,0.90,0.74,0.38,1,UIFont.Small)
  for i,goal in ipairs(LastPurpose.OBJECTIVES) do local done=d.objectives[goal.key]==true; local r,g,b=0.72,0.75,0.78
   if done then r,g,b=0.45,0.86,0.55 end
   self:drawText((done and "[OK] " or "[  ] ")..goal.label,12,91+((i-1)*20),r,g,b,1,UIFont.Small)
  end
 end
end
function LPGoalTracker:new(x,y,w,h)
 local o=ISPanel:new(x,y,w,h); setmetatable(o,self); self.__index=self; o.background=false; o.border=false; o.moveWithMouse=false; o.dragging=false; return o
end
function LastPurpose.ensureTracker(i,p)
 p=p or LastPurpose.getPlayerSafe(i); if not p then print("[LastPurpose] OnCreatePlayer no entrego un jugador valido"); return end
 if not LastPurpose.isBurglar(p) then print("[LastPurpose] Personaje ignorado: no se detecto base:burglar"); return end
 LastPurpose.updateProgress(p)
 if not LastPurpose.tracker then
 print("[LastPurpose] Ladron detectado; creando tracker v"..LastPurpose.VERSION)
  local d=LastPurpose.getData(p)
  local defaultX=getCore():getScreenWidth()-370
  local savedX=tonumber(d.trackerX) or defaultX
  local savedY=tonumber(d.trackerY) or 90
  local x=math.max(0,math.min(getCore():getScreenWidth()-345,savedX))
  local y=math.max(0,math.min(getCore():getScreenHeight()-225,savedY))
  LastPurpose.tracker=LPGoalTracker:new(x,y,345,225)
  LastPurpose.tracker:initialise(); LastPurpose.tracker:addToUIManager()
 end
 LastPurpose.tracker:setVisible(LastPurpose.getData(p).trackerVisible~=false)
end
function LastPurpose.onKeyPressed(key)
 if key~=LastPurpose.TRACKER_KEY then return end; local p=LastPurpose.getPlayerSafe(0)
 if not p or not LastPurpose.isBurglar(p) then return end
 LastPurpose.ensureTracker(0,p); local d=LastPurpose.getData(p); d.trackerVisible=not LastPurpose.tracker:getIsVisible(); LastPurpose.tracker:setVisible(d.trackerVisible)
end
