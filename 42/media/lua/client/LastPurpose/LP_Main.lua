require "LastPurpose/LP_Config"
require "LastPurpose/LP_Heists"
require "LastPurpose/LP_State"
require "LastPurpose/LP_SafehouseAnchor"
require "LastPurpose/LP_BurglarStory"
require "LastPurpose/LP_Thought"
require "LastPurpose/LP_RadioStory"
require "LastPurpose/LP_HeistStory"
require "LastPurpose/LP_Investigation"
require "LastPurpose/LP_BankSecurity"
require "LastPurpose/LP_HeistLoot"
require "LastPurpose/LP_HeistEscape"
require "LastPurpose/LP_Tracker"
if not LastPurpose.eventsRegistered then
 Events.OnCreatePlayer.Add(LastPurpose.ensureTracker)
 Events.EveryOneMinute.Add(LastPurpose.onEveryOneMinute)
 Events.OnKeyPressed.Add(LastPurpose.onKeyPressed)
 Events.OnDeviceText.Add(LastPurpose.onDeviceText)
 Events.OnFillWorldObjectContextMenu.Add(LastPurpose.fillPlanningTableWorldMenu)
 Events.OnTick.Add(LastPurpose.updatePendingRadioReaction)
 Events.OnTick.Add(LastPurpose.updateHeistEscape)
 Events.OnTick.Add(LastPurpose.enforceBankSecurity)
 Events.EveryOneMinute.Add(LastPurpose.updateHeistMapAndArrival)
 Events.EveryOneMinute.Add(LastPurpose.updateHeistLoot)
 Events.EveryOneMinute.Add(LastPurpose.updateInvestigation)
 Events.EveryOneMinute.Add(LastPurpose.updateBankSecurity)
 Events.EveryOneMinute.Add(LastPurpose.updateSafehouseAnchor)
 Events.EveryOneMinute.Add(LastPurpose.refreshHeistEscape)
 LastPurpose.eventsRegistered=true
end
