# Changelog

All notable changes to Last Purpose are recorded here.

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
