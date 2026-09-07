LastPurpose = LastPurpose or {}

-- Recorre un inventario (y los contenedores dentro de el) sin repetir
-- contenedores ya visitados, marcando cada requisito de LastPurpose.OBJECTIVES
-- que encuentre.
local function scanForObjectives(container, objectives, seen)
    if not container or not container.getItems then return end
    seen = seen or {}
    if seen[container] then return end
    seen[container] = true

    local items = container:getItems()
    if not items then return end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            local fullType = item.getFullType and tostring(item:getFullType() or "")
            local objectiveKey = fullType and LastPurpose.TOOL_TYPES[fullType]
            if objectiveKey then objectives[objectiveKey] = true end

            local ok, canEquip = pcall(function() return item:canBeEquipped() end)
            if item.IsInventoryContainer and item:IsInventoryContainer() and ok and canEquip and canEquip ~= "" then
                objectives.bag = true
            end

            if item.getInventory then scanForObjectives(item:getInventory(), objectives, seen) end
        end
    end
end

local function vehicleIsReady(vehicle)
    if not vehicle or not vehicle.getPartById or not vehicle.isEngineWorking then return false end
    local okEngine, engineWorking = pcall(function() return vehicle:isEngineWorking() end)
    if not okEngine or not engineWorking then return false end
    local okTank, tank = pcall(function() return vehicle:getPartById("GasTank") end)
    if not okTank or not tank or not tank.getContainerContentAmount then return false end
    local okFuel, fuel = pcall(function() return tank:getContainerContentAmount() end)
    return okFuel and (tonumber(fuel) or 0) > 0
end

local function hasReadyVehicle(player)
    if not player.getVehicle then return false end
    local ok, vehicle = pcall(function() return player:getVehicle() end)
    return ok and vehicleIsReady(vehicle)
end

local function objectivesComplete(objectives)
    for _, goal in ipairs(LastPurpose.OBJECTIVES) do
        if objectives[goal.key] ~= true then return false end
    end
    return true
end

function LastPurpose.updateProgress(player)
    if not player or not LastPurpose.isBurglar(player) then return end
    local data = LastPurpose.getData(player)

    if LastPurpose.stageIs(data, "inactive") and LastPurpose.getDaysSurvived(player) >= LastPurpose.ACTIVATION_DAYS then
        LastPurpose.setStage(data, "prep_started")
        data.activatedAtHours = player:getHoursSurvived()
        if HaloTextHelper then
            HaloTextHelper.addTextWithArrow(player, "Nuevo objetivo: El ultimo golpe", true, 100, 190, 255)
        end
    end

    if not LastPurpose.stageIs(data, "prep_started") then return end

    scanForObjectives(player:getInventory(), data.objectives)
    if hasReadyVehicle(player) then data.objectives.vehicle = true end

    if objectivesComplete(data.objectives) then
        LastPurpose.setStage(data, "prep_completed")
        data.completedAtHours = player:getHoursSurvived()
        if HaloTextHelper then
            HaloTextHelper.addTextWithArrow(player, "Mision completada: Preparar el golpe", true, 120, 220, 140)
        end
    end
end
