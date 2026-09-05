LastPurpose = LastPurpose or {}

local BANK_X, BANK_Y = 12571, 1712
-- Limites tomados de las dos esquinas verificadas dentro del juego.
local BANK_MIN_X, BANK_MAX_X = 12560, 12583
local BANK_MIN_Y, BANK_MAX_Y = 1687, 1737
local BANK_MIN_Z, BANK_MAX_Z = 0, 3
local protectedEntrances = {}

local function isEntrance(object)
    if instanceof(object,"IsoWindow") or instanceof(object,"IsoDoor") then return true end
    if not instanceof(object,"IsoThumpable") then return false end
    local ok,result=pcall(function() return object:isDoor() or object:isWindow() end)
    return ok and result==true
end

local function eachEntrance(callback)
    local count=0
    for z=BANK_MIN_Z,BANK_MAX_Z do for y=BANK_MIN_Y,BANK_MAX_Y do for x=BANK_MIN_X,BANK_MAX_X do
        local square=getCell():getGridSquare(x,y,z)
        local objects=square and square:getObjects()
        if objects then for i=0,objects:size()-1 do
            local object=objects:get(i)
            if object and isEntrance(object) then count=count+1; callback(object) end
        end end
    end end end
    return count
end

local function protectEntrance(object)
    local md=object:getModData()
    if md.LastPurposeOriginalHealth==nil and object.getHealth then md.LastPurposeOriginalHealth=object:getHealth() end
    if md.LastPurposeOriginalSmashed==nil and instanceof(object,"IsoWindow") then
        local ok,smashed=pcall(function() return object:isSmashed() end)
        if ok then md.LastPurposeOriginalSmashed=smashed end
    end
    pcall(function() if object.setHealth then object:setHealth(100000) end end)
    pcall(function() if object.setIsLocked then object:setIsLocked(true) end end)
    pcall(function() if object.setLockedByKey then object:setLockedByKey(true) end end)
    pcall(function() if object.setPermaLocked then object:setPermaLocked(true) end end)
    -- La proteccion tambien repara daños hechos en una prueba anterior de esta partida.
    if instanceof(object,"IsoWindow") then
        pcall(function() if object:isSmashed() then object:setSmashed(false) end end)
    end
    md.LastPurposeBankProtected=true
    protectedEntrances[object]=true
end

local function releaseEntrance(object)
    local md=object:getModData()
    if not md.LastPurposeBankProtected then return end
    if md.LastPurposeOriginalHealth and object.setHealth then object:setHealth(md.LastPurposeOriginalHealth) end
    if object.setPermaLocked then object:setPermaLocked(false) end
    if object.setLockedByKey then object:setLockedByKey(false) end
    if object.setIsLocked then object:setIsLocked(false) end
    md.LastPurposeBankProtected=false
    protectedEntrances[object]=nil
end

local function shouldRemainProtected(player)
    if not player or not LastPurpose.isBurglar(player) then return false end
    local data=LastPurpose.getData(player)
    if data.storyFlowVersion~=2 or data.stage<6 or data.stage>=10 then return false end
    local hour=getGameTime():getHour()
    return not (data.stage>=8 and (hour>=20 or hour<5))
end

function LastPurpose.enforceBankSecurity()
    local player=LastPurpose.getPlayerSafe(0)
    if not shouldRemainProtected(player) then return end
    local dx,dy=player:getX()-BANK_X,player:getY()-BANK_Y
    if dx*dx+dy*dy>70*70 then return end
    for object in pairs(protectedEntrances) do protectEntrance(object) end
end

function LastPurpose.updateBankSecurity()
    local player=LastPurpose.getPlayerSafe(0)
    if not player or not LastPurpose.isBurglar(player) then return end
    local data=LastPurpose.getData(player)
    if data.storyFlowVersion~=2 or data.stage<6 or data.stage>=10 then return end
    local hour=getGameTime():getHour()
    local windowOpen=data.stage>=8 and (hour>=20 or hour<5)
    local count=eachEntrance(windowOpen and releaseEntrance or protectEntrance)
    if count==0 then
        if not data.bankSecurityMissingLogged then
            data.bankSecurityMissingLogged=true
            print("[LastPurpose] AVISO: el edificio del Knox Bank aun no esta cargado")
        end
        return
    elseif not windowOpen and data.bankSecurityObjectCount~=count then
        data.bankSecurityObjectCount=count
        data.bankSecurityMissingLogged=false
        print(string.format("[LastPurpose] Knox Bank protegido: %d puertas y ventanas",count))
    end
    if not windowOpen then
        local dx,dy=player:getX()-BANK_X,player:getY()-BANK_Y
        if dx*dx+dy*dy<55*55 and not data.bankSecurityThoughtShown then
            data.bankSecurityThoughtShown=true
            LastPurpose.showThought(player,{"Seria problematico activar la alarma","si rompo el cristal ahora."})
        end
        return
    end
    local smashed=0
    eachEntrance(function(object) if instanceof(object,"IsoWindow") and object:isSmashed() then smashed=smashed+1 end end)
    data.bankWindowsSmashed=smashed
    if smashed>2 and not data.ambushTriggered then
        data.ambushForced=true
        LastPurpose.heistEscapeActive=true
        print("[LastPurpose] Alarma anticipada: mas de dos ventanas destruidas")
    end
end
