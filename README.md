# Last Purpose

> Private development repository — Work in progress.

Last Purpose is a narrative progression mod for **Project Zomboid Build 42 stable**. It gives survivors profession-based objectives for the mid-game and late-game.

The current prototype focuses on the Burglar story, **“The Last Heist”** (`El último golpe`).

## Current version

**0.3.1** — Singleplayer, Project Zomboid Build 42 stable.

Implemented:

- Burglar detection through Build 42 profession and trait APIs.
- Prologue activation after 15 survived days.
- First mission: **“Prepare the Heist”**.
- Automatic tracking of a crowbar, screwdriver, flashlight, wearable bag/backpack, and a working vehicle with fuel.
- Persistent progression through `player:getModData()`.
- Movable objective tracker.
- `J` toggles the tracker.
- Backward-compatible save-data migration from versions 0.1.x and 0.2.x.
- Modular Lua architecture.

## Planned direction

The long-term design includes immersive radio transmissions, map clues, profession-specific story chains, important locations, unique rewards, and post-year-one repeatable events.

Planned profession stories include Burglar, Lumberjack, Veteran, Mechanic, Doctor, and Unemployed.

Integrations with other mods may be added later, but they should remain optional so Last Purpose can run independently.

## Installation for local testing

Place the repository at:

```text
C:\Users\<username>\Zomboid\mods\LastPurpose
```

Start Project Zomboid Build 42 stable and enable **Last Purpose [B42]** in the Mods menu and in the selected save configuration.

## Project structure

```text
LastPurpose/
├── mod.info
├── 42/
│   ├── mod.info
│   └── media/lua/client/LastPurpose/
│       ├── LP_Main.lua
│       ├── LP_Config.lua
│       ├── LP_State.lua
│       ├── LP_BurglarStory.lua
│       └── LP_Tracker.lua
└── common/media/lua/shared/LastPurpose/
    └── LP_Common.lua
```

See `DOCUMENTACION_LastPurpose_0.3.1.txt` for the complete Spanish technical and design documentation.

## Development status

This project is under active private development. APIs, data structures, mission design, and visuals may change before release.

## Rights

Copyright © 2026 ElKeyaru. All rights reserved.

The source code is private and proprietary. Viewing or receiving access does not grant permission to copy, modify, redistribute, publish, sublicense, or create derivative works. See `LICENSE`.

Project Zomboid and related names and assets belong to their respective owners. This is an unofficial fan-made mod and is not affiliated with or endorsed by The Indie Stone.
