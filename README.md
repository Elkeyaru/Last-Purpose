# Last Purpose

> Repositorio de desarrollo privado — En curso.

Last Purpose es un mod de progresión narrativa para **Project Zomboid Build 42
estable**. Da a los supervivientes objetivos de mid-game y late-game según su
profesión.

El prototipo actual es la historia del Ladrón, **"El último golpe"**
(`The Last Heist`).

## Versión actual

**1.3.0 (estable)** — Singleplayer, Project Zomboid Build 42, `versionMin`
42.20.4. Requiere KeyasLib >= 1.2.5. "El último golpe" jugado de principio a
fin; la GUI del ordenador se reescribió sobre KeyasCSS y los sistemas propios
(opciones, sellado del banco) migraron a KeyasLib.

Ver `CHANGELOG.md` para el detalle versión por versión y
`documentacion_mod.txt` para la referencia técnica y de diseño completa.

## Instalación para pruebas locales

Coloca el contenido de este repositorio en:

```text
C:\Users\<usuario>\Zomboid\mods\LastPurpose
```

Inicia Project Zomboid Build 42 estable y activa **Last Purpose [B42]** en el
menú de mods y en la configuración de la partida.

## Estructura del proyecto

```text
LastPurpose/
├── mod.info
├── documentacion_mod.txt      (referencia técnica y de diseño completa)
├── CHANGELOG.md
├── 42/
│   ├── mod.info
│   └── media/
│       ├── lastpurpose_planning_01.tiles(.txt)
│       ├── texturepacks/lastpurpose_planning_01.pack
│       ├── textures/Item_LastPurpose_PlanningTable.png
│       └── lua/
│           ├── client/LastPurpose/    (12 archivos, uno por sistema)
│           └── server/LastPurpose/LP_RadioChannel.lua
└── common/media/
    ├── scripts/                (definiciones de mesa, nota y bolsas)
    └── lua/shared/LastPurpose/LP_Heists.lua   (único archivo compartido)
```

## Notas de arquitectura

`common/media/lua/shared/` contiene un único archivo Lua a propósito: el
motor de Project Zomboid carga cada archivo de forma independiente y
alfabética, y un archivo compartido que depende de otro archivo compartido
no tiene garantizado el orden de carga entre ambos. Ver la sección 12.1 de
`documentacion_mod.txt` para el detalle completo, incluido el bug real que
esto causó en la v1.0.0 y cómo se corrigió en la v1.0.1.

## Rights

Copyright © 2026 ElKeyaru. All rights reserved.

The source code is private and proprietary. Viewing or receiving access does
not grant permission to copy, modify, redistribute, publish, sublicense, or
create derivative works. See `LICENSE`.

Project Zomboid and related names and assets belong to their respective
owners. This is an unofficial fan-made mod and is not affiliated with or
endorsed by The Indie Stone.
