# Changelog — Last Purpose

Todas las versiones desde la 1.0.0 corresponden a la reescritura completa del
código Lua (arquitectura nueva, mismo contenido narrativo). Las versiones
0.1.x–0.7.2 son el desarrollo original y quedan documentadas aquí solo como
referencia histórica.

## Sin publicar

### Pendiente
- Abrir la mesa con **E** (acción contextual, como los vehículos), solo al
  estar cerca. Además del menú contextual actual.
- Migrar `LP_Computer` / `LP_BankSecurity` / `LP_Options` a **KeyasLib**
  (`require=KeyasLib`), sin cambiar la narrativa ni los flujos validados.

## 1.2.0 — 2026-09-08

`versionMin` sube a 42.20.4. `mod.info` con nueva descripción y `poster.png`.
Nada de esto cambia partidas en curso salvo la receta de la mesa (afecta solo
a mesas nuevas).

### Añadido
- **Hub del ordenador — hito 1 (`LP_Computer.lua`, nuevo).** La mesa de
  planificación gana una opción de menú «Usar el ordenador» que abre una GUI
  de pantalla completa estilo terminal retro (archivo de misiones). Por ahora
  es de solo lectura: lista el catálogo por ciudad (solo «El último golpe»
  visible; el resto censurado como `?????????` hasta los hitos de desbloqueo)
  y, en la etapa `review_loot`, su botón «Entregar botín» llama al mismo
  `LastPurpose.reviewHeistLoot` de siempre. La opción directa «Revisar el
  botín» del menú se conserva mientras se prueba el botón de la GUI en juego.
  Se cierra con Escape, el botón X o un clic fuera de la ventana. La GUI
  reproduce la estructura del mockup (escritorio con barra lateral
  Misiones/Notas/Archivos/Sistema, franja de colores, ventana con relieve
  noventero, barra de estado).
- **Assets del terminal** en `42/media/ui/LastPurpose/`: hoja de iconos de
  Gemini procesada a 17 PNG transparentes (`lp_icon_00..16`), logo `xcyos_logo.png`
  y `crt_overlay.png` + `grad_title/grad_button` generados por código.
  `LP_Computer.lua` los carga con `getTexture` y cae al dibujo de
  rectángulos si algún PNG falta.
- **Fuente de terminal propia.** B42 no deja registrar una fuente de mod sin
  pisar las vanilla, así que la GUI del ordenador dibuja el texto glifo a
  glifo desde un atlas propio (`lp_term_18/26`, VT323 procesada con
  System.Drawing) vía `drawSubTexture`. Métricas en `LP_TermFontData.lua`.
  Si el atlas o los datos faltan, cae a `UIFont`. Solo afecta a esta GUI.
- **Receta de la mesa** cambiada a `2 tablones + 3 chatarra electrónica +
  1 pegamento/cinta` (antes libro + periódicos). El nombre del mueble no
  cambia: sigue siendo «Mesa de planificación».

- **Panel de opciones del mod** (Opciones → Mods → Last Purpose), con la API
  nativa `PZAPI.ModOptions` de B42, sin dependencias. Dos ajustes: la tecla
  para abrir/cerrar el diario (antes fija en `J`) y una casilla de registro
  de depuración que enciende `LastPurpose.DEBUG` en caliente
  (`LP_Options.lua`, nuevo).

### Cambiado
- **El diario deja de ser accesible al completar el golpe.** En la etapa
  `completed` el rastreador se cierra solo y ni la tecla ni `ensureTracker`
  lo vuelven a abrir (`LP_Tracker.lua`).

### Corregido
- **El perímetro del Knox Bank se abría al dar las 20:00.** `shouldRemainProtected`
  liberaba puertas y ventanas en cuanto era de noche y el banco estaba
  reconocido, aunque el jugador todavía no hubiera iniciado el golpe. Eso
  dejaba una franja (son las 20:00 pero el jugador aún no llegó al banco, o
  está en una esquina del perímetro fuera del radio de 35 casillas que
  dispara `heist_active`) con el banco abierto. Ahora la protección depende
  solo de la etapa (`note_read` hasta `heist_active`, exclusivo): el banco
  sigue sellado aunque sea de noche hasta que el jugador llega y el golpe
  arranca de verdad (`LP_BankSecurity.lua`).
- **La protección del banco no frenaba varias vías de entrada.** `setHealth()`
  no impide romper un cristal a mano (`ISPlayer:smashWindow()` es una llamada
  Java directa que ignora la salud del objeto), ni el mazo
  (`ISDestroyStuffAction`), ni forzar una cerradura, ni pasar por la ventana
  (`ISClimbThroughWindow`); solo se interceptaba el ítem del menú contextual.
  Ahora se envuelve `isValid()` de `ISSmashWindow`, `ISOpenCloseDoor`,
  `ISClimbThroughWindow` e `ISDestroyStuffAction`: si el objetivo es una
  entrada sellada del banco, la acción se rechaza antes de arrancar, venga de
  donde venga (`LP_BankSecurity.lua`). Se añadió traza (tras `DEBUG`) del
  estado del sellado y del número de entradas protegidas para diagnóstico.
- **Los cristales del banco se rompían igual por combate directo o por los
  zombis** (ninguna de esas vías pasa por una acción Lua interceptable).
  `LastPurpose.restoreEntranceIfBroken()` revierte en el siguiente tick de
  enforce cualquier entrada nuestra que se haya roto mientras el sello está
  activo: `setSmashed(false)` + `RecalcAllWithNeighbours` + salud alta, con un
  límite de ~3 reconstrucciones/segundo por objeto para no provocar el
  parpadeo de render que ya hubo en 0.7.1. No es infalible (si el cristal
  pierde el vidrio, `isGlassRemoved()`, no se puede reconstruir; y un zombi
  podría cruzar en el fotograma en que está roto) — la solución definitiva de
  zona protegida irá en KeyasLIB.
- **El rastreador (libro) cortaba las frases fuera de la página.** Project
  Zomboid no ajusta `drawText()` al ancho del contenedor y la página derecha
  del libro es la mitad de ancha que el panel anterior, así que las frases
  largas y las recapitulaciones de capítulo se salían por el borde. Todo el
  texto de la página pasa ahora por `drawWrapped()`, que parte la frase en
  líneas medidas y devuelve un cursor vertical; los renderers avanzan con ese
  cursor en vez de con desplazamientos fijos (`LP_Tracker.lua`).

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
