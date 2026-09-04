# Last Purpose

> Private development repository — Work in progress.

Last Purpose is a narrative progression mod for **Project Zomboid Build 42 stable**. It gives survivors profession-based objectives for the mid-game and late-game.

The current prototype focuses on the Burglar story, **“The Last Heist”** (`El último golpe`).

## Current version

**0.6.0 (validated)** — Singleplayer, Project Zomboid Build 42 stable.

Latest validated release: **0.6.0**.

Implemented:

- Burglar detection through Build 42 profession and trait APIs.
- Prologue activation after 20 in-game minutes in the current debugging build.
- First mission: **“Prepare the Heist”**.
- Automatic tracking of a crowbar, screwdriver, flashlight, wearable bag/backpack, and a working vehicle with fuel.
- Persistent progression through `player:getModData()`.
- Movable objective tracker.
- `J` toggles the tracker.
- Backward-compatible save-data migration from versions 0.1.x and 0.2.x.
- Data-driven heist catalog with a persistent selected job.
- Blue X map marker for the first Louisville bank target.
- Automatic arrival detection around the selected building.
- Unique Knox Bank loot bag with gold, diamonds, and bundled money.
- Automatic detection when the player takes the heist loot.
- A 35-second bank alarm and a staged 200-zombie escape encounter.
- Craftable, rotatable wooden planning table with native Build 42 sprites and an open book.
- Automatic safehouse registration when the planning table is placed, indoors or outdoors.
- Dynamic return objective after escaping 520 tiles from the bank with the loot.
- Modular Lua architecture.
- Persistent random radio frequency and six-hour narrative broadcasts.
- Second story stage: intercept the conversation about the Louisville bank.

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
│   └── media/
│       ├── lastpurpose_planning_01.tiles
│       ├── texturepacks/lastpurpose_planning_01.pack
│       ├── textures/Item_LastPurpose_PlanningTable.png
│       └── lua/client/LastPurpose/
└── common/media/
    ├── scripts/LastPurpose_PlanningTable.txt
    └── lua/shared/
```

See `DOCUMENTACION_LastPurpose_0.6.0.txt` for the complete Spanish technical and design documentation.

## Development status

This project is under active private development. APIs, data structures, mission design, and visuals may change before release.

## Rights

Copyright © 2026 ElKeyaru. All rights reserved.

The source code is private and proprietary. Viewing or receiving access does not grant permission to copy, modify, redistribute, publish, sublicense, or create derivative works. See `LICENSE`.

Project Zomboid and related names and assets belong to their respective owners. This is an unofficial fan-made mod and is not affiliated with or endorsed by The Indie Stone.
