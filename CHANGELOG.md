# Changelog — Last Purpose

Todas las versiones desde la 1.0.0 corresponden a la reescritura completa del
código Lua (arquitectura nueva, mismo contenido narrativo). Las versiones
0.1.x–0.7.2 son el desarrollo original y quedan documentadas aquí solo como
referencia histórica.

## 1.1.0 — 2026-09-07

### Cambiado
- Rediseño completo de `LP_Tracker.lua`: el rastreador ahora se presenta
  como un libro de dos páginas (tapa de cuero, páginas de pergamino) en vez
  del panel plano anterior.
- Índice de 7 capítulos narrativos en la página izquierda, con estado
  visual (completado / actual / bloqueado) y navegación por clic para
  releer la recapitulación de capítulos ya completados.
- Ningún otro archivo fue modificado en esta versión.

## 1.0.1 — 2026-09-07

### Corregido
- **Bug crítico de orden de carga.** Varios archivos leían
  `LastPurpose.World.*` a nivel de archivo (fuera de funciones), asumiendo
  que el archivo compartido que define esa tabla ya había cargado. Project
  Zomboid carga cada `.lua` de forma independiente y alfabética; `require()`
  no fuerza la carga de un archivo al que todavía no le tocaba turno. Esto
  rompía `LP_Heists.lua`, `LP_BankSecurity.lua`, `LP_HeistEscape.lua`,
  `LP_HeistLoot.lua` y `LP_SafehouseAnchor.lua` en cuanto el mod cargaba, y
  en cascada `LP_State.getData()` en cada `EveryOneMinute`.
- Consolidados `LP_Config.lua`, `LP_Stages.lua`, `LP_World.lua` y
  `LP_Heists.lua` en un único archivo compartido sin dependencias internas.
- Movida la lectura de `Keyboard.KEY_J` de un archivo compartido (contexto
  de carga incorrecto) a dentro de la función que lo usa, en un archivo de
  cliente.
- Diagnosticado y confirmado con `console.txt` real de una partida de
  prueba.

## 1.0.0 — 2026-09-06

### Cambiado
- Reescritura completa del código Lua del mod desde cero, a partir de la
  documentación de diseño de la v0.7.2. Mismo contenido narrativo
  (coordenadas, diálogos, catálogo de recompensas); arquitectura interna
  nueva:
  - `data.stage` pasa de número + bandera `storyFlowVersion` a un string
    con nombre (`"bank_scouted"`, etc.), comparado por posición en una
    lista ordenada en vez de números mágicos sueltos.
  - Sin ruta de migración heredada: esta versión no es compatible con
    partidas guardadas de 0.1.x–0.7.x.
  - Config y catálogo centralizados.
  - `pcall` alrededor de toda llamada a la API del motor en radio, mapa,
    seguridad del banco y emboscada.
  - Sin `print()` de depuración sin gatear: todo detrás de
    `LastPurpose.DEBUG` (por defecto `false`).

## 0.1.4 – 0.7.2 — 2026-09-02 a 2026-09-06

Desarrollo original por ElKeyaru con asistencia de ChatGPT. Estableció la
narrativa completa de "El último golpe": preparación, radio, investigación
con 21 puntos de reunión, reconocimiento del Knox Bank, seguridad diurna del
perímetro, robo, emboscada de escape y recompensa en el refugio. Ver el
`documentacion_mod.txt` de esa etapa (recuperable en el historial de git) para
el detalle version por versión.
