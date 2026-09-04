LastPurpose = LastPurpose or {}
function LastPurpose.getPlayerSafe(i) if i~=nil then return getSpecificPlayer(i) end return getPlayer() end
function LastPurpose.isBurglar(p)
 if not p then return false end
 local profession=nil
 if p.getDescriptor and p:getDescriptor() and p:getDescriptor().getProfession then profession=p:getDescriptor():getProfession() end
 if not profession and p.getProfession then profession=p:getProfession() end
 profession=string.lower(tostring(profession or ""))
 if string.find(profession,"burglar",1,true) then return true end
 if p.getCharacterTraits then
  local traits=p:getCharacterTraits()
  if traits and CharacterTrait and CharacterTrait.BURGLAR and traits.get then
   local ok,value=pcall(function() return traits:get(CharacterTrait.BURGLAR) end)
   if ok and value then return true end
  end
  if traits and traits.getKnownTraits then
   local known=traits:getKnownTraits()
   if known and known.size and known.get then for i=0,known:size()-1 do
    if string.find(string.lower(tostring(known:get(i) or "")),"burglar",1,true) then return true end
   end end
  end
 end
 if p.getTraits then
  local traits=p:getTraits()
  if traits and traits.size and traits.get then for i=0,traits:size()-1 do
   if string.find(string.lower(tostring(traits:get(i) or "")),"burglar",1,true) then return true end
  end end
 end
 if p.HasTrait then for _,id in ipairs({"Burglar","burglar","base:burglar"}) do
  local ok,value=pcall(function() return p:HasTrait(id) end); if ok and value then return true end
 end end
 return false
end
function LastPurpose.getData(p)
 local root=p:getModData()
 if type(root[LastPurpose.SAVE_KEY])~="table" then root[LastPurpose.SAVE_KEY]={schema=7,storyFlowVersion=2,active=false,completed=false,stage=0,trackerVisible=true,objectives={}} end
 local d=root[LastPurpose.SAVE_KEY]
 if (tonumber(d.schema) or 0)<7 then
  -- Solo conservamos la ruta directa si el jugador ya habia descubierto el banco.
  d.storyFlowVersion=(tonumber(d.stage) or 0)>=4 and 1 or 2
 end
 d.schema=7
 if d.storyFlowVersion==nil then d.storyFlowVersion=2 end
 if d.stage==nil then d.stage=d.active and 1 or 0 end
 if d.completed==nil then d.completed=false end
 if d.trackerVisible==nil then d.trackerVisible=true end
 if type(d.objectives)~="table" then d.objectives={} end
 return d
end
function LastPurpose.getDaysSurvived(p) if not p or not p.getHoursSurvived then return 0 end return math.max(0,p:getHoursSurvived()/24) end
