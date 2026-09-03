# Changelog

All notable changes to Last Purpose are recorded here.

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
