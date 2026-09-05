# Changelog

All notable changes to Last Purpose are recorded here.

## [Unreleased]

- Added 21 persistent possible meeting-point locations across Louisville.
- Required the coded note to be read with Project Zomboid's vanilla reading action before revealing Knox Bank.
- Removed the mandatory getaway-vehicle parking stage after reconnaissance.
- Prepared the loot scene from 20:00 whenever its world cell is loaded.
- Added a locked and damage-resistant security perimeter covering x 12560–12583, y 1687–1737, floors 0–3 before the robbery window.
- Added support for regular and thumpable Build 42 doors and windows, including immediate protected-window restoration near the bank.
- Released the bank protection between 20:00 and 05:00 after reconnaissance.
- Added an early alarm when more than two windows are broken during the robbery window.
- Added a fresh second 35-second, 200-zombie ambush on leaving the bank if the player already completed an early alarm before taking the loot.
- Added diagnostic logging for the number of protected entrances.

## [0.7.0] - 2026-09-04

- Extended the Knox Bank story with a secondary meeting point and a recoverable coded note.
- Added bank reconnaissance before the player can begin the robbery.
- Added a marked getaway zone that requires a stopped, functional vehicle with fuel.
- Restricted entry into the bank to the night window between 20:00 and 05:00.
- Restored the intended 15-day prologue activation.
- Changed both versions of the unique loot bag to a consistent black burglar-bag appearance.
- Added save migration so existing 0.6.x stories keep their original stage progression.
- Replaced the exact radio frequency in the tracker with ten possible signals.
- Changed the mysterious caller to repeat the transmission every 30 in-game minutes and end by asking whether the listener copied the message.
- Corrected Spanish grammar and accents throughout the player-facing story text.
- Strengthened the blue visual hierarchy used by mission headings and character thoughts.
- Hardened tracker dragging when the cursor leaves the panel.
- Reduced permanent per-frame work by moving map progression checks to minute events and sleeping the ambush updater outside active assaults.
- Removed development-only starter-kit files from the distributable mod.

## [0.6.1] - development

- Made the return to the planning table the definitive end of the first heist.
- Added a persistent, one-time reward of two Nimble levels, capped at level 10.
- Added mid/late-game supplies to the Knox Bank loot on completion: medicine, bandages, batteries, repair materials, fuel can, military radio, preserved food, and three random ammunition boxes.
- Required the unique loot bag to still be carried when completing the return objective.
- Kept the annotated-map continuation out of this mission; version 0.6.1 ends the heist at the safehouse.
- Recorded the future design as one random heist per playthrough, followed by access to other profession stories.
- Added a world-context action on the planning table so the reward is granted only when the player explicitly reviews the loot.
- Replaced the accessible bank container during the escape with a sealed, fixed-weight loot object.
- Opening the loot at the planning table now replaces the seal with a usable 28-capacity bag, below Build 42's 35-capacity best vanilla backpack.
- Delayed creation of valuables and survival supplies until the sealed loot is reviewed at the safehouse.

## [0.6.0] - 2026-09-04

- Added a planning table under the new persistent ID `LastPurpose.SafehousePlanningTableV2`.
- Added a dedicated native Build 42 tile for the planning table, with its own placement preview and furniture properties.
- Added an integrated open book and papers to the table sprite, scaled to match vanilla furniture.
- Added English and Spanish names for the moveable so it no longer appears as a brown low table.
- Added automatic visual migration for planning tables already placed in existing saves.
- Removed the loose-texture overlay that could remain visible through rooms and cutaway walls.
- Fixed the Build 42 tile-definition ID so the planning table can be placed normally.
- Removed the special "place as safehouse" inventory action; a nearby placed planning table is now detected automatically.
- Allowed the planning table to establish a safehouse outdoors and changed its recipe to inventory crafting.
- Corrected the planning-table sprite baseline so it rests naturally on its selected world tile.
- Packed each planning-table face on a standard 128x256 Build 42 furniture canvas.
- Rebuilt the table silhouette on the exact footprint, perspective, and 94x83 visible bounds of vanilla low furniture.
- Added native south/east furniture faces so the planning table can be rotated in all four placement directions.
- Added the safehouse as the sixth preparation requirement.
- Added the return-to-safehouse objective after escaping 520 tiles from Knox Bank.
- Kept the validated 0.5.2 release and existing save data untouched.
- Validated the complete sequence in-game: preparation, radio clue, bank, loot, ambush, escape, and return to the planning table.

## [0.5.2] - testing

- Added a 35-second house alarm when the unique loot bag is taken.
- Added a performance-controlled 200-zombie encounter around the bank.
- Added a one-time test-save migration for encounter tuning.
- Persisted the wave count so saving and loading cannot duplicate completed waves.
- Replaced delayed virtual hordes with directly spawned active zombies.
- Concentrated the encounter into five waves of forty, each split into five surrounding groups.
- Reduced the spawn ring to 30-50 tiles and the wave delay to 0.75 seconds.
- Ordered every spawned zombie to move toward the bank immediately.

## [0.5.1] - testing

- Added the unique Knox Bank loot bag after reaching the heist location.
- The bag contains five small gold bars, four diamonds, and six bundles of money.
- Added a fixed narrative loot scene at 12562, 1690, level 1.
- Added two dead zombies beside the loot bag, created only once per save.
- Added recursive pickup detection and the escape-with-the-loot mission stage.
- Kept existing 0.5.0 saves compatible without resetting story progress.
- Fixed the minute-event callback so it obtains the local player correctly before creating the scene.

## [0.5.0] - testing

- Added a data-driven heist catalog shared by client and server.
- Added persistent heist selection with a safe migration for 0.4.1 saves.
- Added the first catalog entry: Knox Bank in Louisville.
- Added a blue X map marker after the complete radio clue is heard.
- Added automatic arrival detection and a new location-reached stage.
- Reveals only the small target sector so mission symbols remain visible in unexplored areas.
- Replaced the unreliable persisted annotation with a large map overlay controlled by Last Purpose.
- The map centers on the objective once, while the tracker shows direction and approximate distance.
- Changed character thoughts to blue with a subtle simulated bold effect.
- Kept the temporary 20-minute activation threshold for rapid debugging.

## [0.4.1] - 2026-09-03

- Narrative thoughts now remain visible for eight seconds with a larger font.
- The second thought appears only after the final transmission line is heard.
- Story broadcasts now air at 02:00, 08:00, 14:00, and 20:00.
- The channel remains silent outside the four scheduled story broadcasts.
- The tracker no longer reveals the broadcast interval.
- Removed the thought background box while retaining the larger floating text.
- Added a five-second pause between the final radio line and the character reaction.
- Temporarily reduced prologue activation to 20 in-game minutes for debugging.
- Radio frequency selection now scans all registered vanilla and mod channels and only uses a free frequency.
- A persisted frequency is automatically replaced if another channel occupies it on a later load.
- Removed the experimental soundtrack playback to keep the radio system focused and compatible.
- Tracker X/Y coordinates are now saved on drag release and restored safely on the next load.

## [0.4.0] - 2026-09-03

### Added

- Added a persistent random Bandit-category radio channel.
- Added a native radio conversation broadcast every six in-game hours.
- Added the “Interceptar la transmisión” story stage and frequency tracker.
- Added detection of the final received radio line through `OnDeviceText`.
- Added the transition to “Adelantarse a la competencia” at the Louisville bank.

## [0.3.1] - 2026-09-03

### Fixed

- Reworked tracker dragging to use mouse capture and absolute cursor position.
- Added safe release inside and outside the panel.
- Prevented the tracker from moving beyond screen boundaries.

## [0.3.0] - 2026-09-03

### Changed

- Split the client implementation into configuration, state, Burglar story, tracker, and entry-point modules.
- Preserved existing save keys and mission behavior.

## [0.2.1] - 2026-09-03

### Fixed

- Removed an incompatible global vehicle-list traversal that caused repeated Lua errors.
- Vehicle readiness is now checked safely when the player enters a vehicle.

## [0.2.0] - 2026-09-02

### Added

- Added the first mission, “Prepare the Heist”.
- Added persistent tracking for tools, a bag or backpack, and a functional fueled vehicle.
- Added save-data migration support.

### Changed

- Restored prologue activation to 15 survived days.

## [0.1.4] - 2026-09-02

### Fixed

- Replaced the incompatible `drawProgressBar` call with manually drawn rectangles.

### Added

- Burglar detection, prologue, movable tracker, `J` visibility toggle, and persistent ModData state.
