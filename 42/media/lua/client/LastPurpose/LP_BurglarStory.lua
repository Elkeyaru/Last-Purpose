LastPurpose = LastPurpose or {}
local function scan(c,o,seen)
 if not c or not c.getItems then return end; seen=seen or {}; if seen[c] then return end; seen[c]=true
 local items=c:getItems(); if not items then return end
 for i=0,items:size()-1 do local item=items:get(i); if item then
  local kind=LastPurpose.TOOL_TYPES[tostring(item.getFullType and item:getFullType() or "")]; if kind then o[kind]=true end
  if item.IsInventoryContainer and item:IsInventoryContainer() and item.canBeEquipped and tostring(item:canBeEquipped() or "")~="" then o.bag=true end
  if item.getInventory then scan(item:getInventory(),o,seen) end
 end end
end
local function vehicleReady(v)
 if not v or not v.getPartById or not v.isEngineWorking then return false end
 local ok,working=pcall(function() return v:isEngineWorking() end); if not ok or not working then return false end
 local tankOk,tank=pcall(function() return v:getPartById("GasTank") end); if not tankOk or not tank or not tank.getContainerContentAmount then return false end
 local fuelOk,fuel=pcall(function() return tank:getContainerContentAmount() end); return fuelOk and tonumber(fuel) and tonumber(fuel)>0
end
local function hasVehicle(p) local ok,v=pcall(function() return p:getVehicle() end); return ok and vehicleReady(v) end
local function complete(o) for _,goal in ipairs(LastPurpose.OBJECTIVES) do if o[goal.key]~=true then return false end end return true end
function LastPurpose.updateProgress(p)
 if not p or not LastPurpose.isBurglar(p) then return end
 local d=LastPurpose.getData(p)
 if not d.active and LastPurpose.getDaysSurvived(p)>=LastPurpose.ACTIVATION_DAYS then
  d.active=true; d.stage=1; d.activatedAtHours=p:getHoursSurvived()
  if HaloTextHelper then HaloTextHelper.addTextWithArrow(p,"Nuevo objetivo: El ultimo golpe",true,180,210,255) end
 end
 if not d.active or d.completed then return end
 scan(p:getInventory(),d.objectives); if p.getVehicle and hasVehicle(p) then d.objectives.vehicle=true end
 if complete(d.objectives) then d.completed=true; d.stage=2; d.completedAtHours=p:getHoursSurvived()
  if HaloTextHelper then HaloTextHelper.addTextWithArrow(p,"Mision completada: Preparar el golpe",true,120,220,140) end
 end
end
function LastPurpose.onEveryOneMinute()
 local p=LastPurpose.getPlayerSafe(0)
 if p then LastPurpose.updateProgress(p); LastPurpose.updateRadioStory(p) end
end
