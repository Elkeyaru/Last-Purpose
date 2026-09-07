require "LastPurpose/LP_Heists"
require "LastPurpose/LP_Options"
require "LastPurpose/LP_State"
require "LastPurpose/LP_Thought"
require "LastPurpose/LP_BurglarStory"
require "LastPurpose/LP_RadioStory"
require "LastPurpose/LP_HeistStory"
require "LastPurpose/LP_Investigation"
require "LastPurpose/LP_BankSecurity"
require "LastPurpose/LP_HeistLoot"
require "LastPurpose/LP_HeistEscape"
require "LastPurpose/LP_SafehouseAnchor"
require "LastPurpose/LP_Tracker"

if not LastPurpose.eventsRegistered then
    -- Una vez por minuto: progreso, radio, mapa, investigacion, seguridad
    -- completa del banco, mesa y reactivacion de la alarma tras cargar.
    Events.EveryOneMinute.Add(function()
        local player = LastPurpose.getPlayerSafe(0)
        if not player then return end
        if LastPurpose.refreshOptions then LastPurpose.refreshOptions() end
        LastPurpose.updateProgress(player)
        LastPurpose.updateRadioStory(player)
    end)
    Events.EveryOneMinute.Add(LastPurpose.updateHeistMapAndArrival)
    Events.EveryOneMinute.Add(LastPurpose.updateInvestigation)
    Events.EveryOneMinute.Add(LastPurpose.updateBankSecurity)
    Events.EveryOneMinute.Add(LastPurpose.updateSafehouseAnchor)
    Events.EveryOneMinute.Add(LastPurpose.refreshHeistEscape)

    -- Por fotograma, pero cada uno se duerme solo fuera de su etapa: reaccion
    -- de radio pendiente, alarma activa, proteccion cercana del banco y
    -- deteccion inmediata de la bolsa.
    Events.OnTick.Add(LastPurpose.updatePendingRadioReaction)
    Events.OnTick.Add(LastPurpose.updateHeistEscape)
    Events.OnTick.Add(LastPurpose.enforceBankSecurity)
    Events.OnTick.Add(LastPurpose.updateHeistLootPickup)

    -- Eventos puntuales.
    Events.OnCreatePlayer.Add(LastPurpose.ensureTracker)
    Events.OnKeyPressed.Add(LastPurpose.onKeyPressed)
    Events.OnDeviceText.Add(LastPurpose.onDeviceText)
    Events.OnWeaponHitThumpable.Add(LastPurpose.onWeaponHitBankObject)
    Events.OnFillWorldObjectContextMenu.Add(LastPurpose.fillPlanningTableWorldMenu)

    LastPurpose.eventsRegistered = true
    LastPurpose.debugPrint("Eventos registrados (v" .. LastPurpose.VERSION .. ")")
end
