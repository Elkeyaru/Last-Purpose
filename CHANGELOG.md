# Changelog — Last Purpose

Todas las versiones desde la 1.0.0 corresponden a la reescritura completa del
código Lua (arquitectura nueva, mismo contenido narrativo). Las versiones
0.1.x–0.7.2 son el desarrollo original y quedan documentadas aquí solo como
referencia histórica.

## Sin publicar

(nada pendiente de publicar)

## 1.3.1 — 2026-09-10

Build de prueba para creadores de contenido. Sin cambios de contenido ni de
lógica frente a la 1.3.0.

### Cambiado
- **El registro de depuración (consola) viene activado por defecto** para
  que el `console.txt` sea útil en los reportes de bugs. Solo eso: la
  activación del golpe sigue tardando sus 15 días reales y la frecuencia de
  radio no se revela. La casilla «Registro de depuración» en
  Opciones → Mods lo apaga.

## 1.3.0 — 2026-09-09

Reescritura de la GUI del ordenador sobre **KeyasCSS** y migración de los
sistemas propios a **KeyasLib**. `versionMin` se mantiene en 42.20.4.
Requiere **KeyasLib >= 1.2.5**. No rompe partidas de 1.2.0, pero el sello
del banco y la escena de la nota cambiaron internamente.

### Cambiado
- **`LP_Computer` — el contenido de la GUI ahora lo maqueta y pinta
  KeyasCSS** (KeyasLib >= 1.2.2), no primitivas a mano. El *chrome* fijo
  (bisel CRT, marco, barra de título con degradado, franja, logo, viñeta)
  sigue siendo `xcyos_chrome.png` horneado; lo que cambió es el interior:
  lista de misiones, panel de detalle, badges, tiles de recompensa y las
  apps Notas/Archivos/Sistema se describen como un árbol de cajas con hoja
  de estilos (`CONTENT_CSS`) y KeyasCSS resuelve flexbox, esquinas
  redondeadas, bordes y sombras. Los iconos y el mini-mapa se dibujan por
  hooks `onPaint`. La receta, el catálogo, `knoxStatus`, el flujo de
  entrega del botín (`reviewHeistLoot`) y `LastPurpose.openComputer` no
  cambian. Motivo: la mesa-ordenador es el primer consumidor real de
  KeyasCSS; su desarrollo endurece la librería (KeyasLib 1.2.2–1.2.4).
  Requiere **KeyasLib >= 1.2.4**.
- **La GUI abre a pantalla completa** (ocupa toda la ventana del juego). El
  chrome se estira a la pantalla; zonas escaladas por `sx`/`sy`.
- **La GUI ya no se cierra al hacer clic fuera de un elemento.** Solo
  cierra la **X** o **ESC**. El clic dentro se consume (no llega al mundo).
- Barra de título dinámica por app (Notas/Archivos/Sistema repintan el
  título horneado).
- Tipografía: atlas de glifos **VT323** (la fuente del mockup, `tools/bake_fonts.ps1`
  la hornea desde el `.ttf` del repo) a 4 tamaños — un solo peso, jerarquía
  por tamaño. Reemplaza al atlas VT323 de dos tamaños anterior.
- El rail y el título los dibuja el código (el `xcyos_chrome.png` nuevo los
  trae en blanco). Dock de profesión en el panel de lista (solo lectura).
  Notas/Archivos/Sistema con contenido real; Sistema sin configuración
  (las opciones siguen en Opciones → Mods).
- El árbol KeyasCSS se cachea: solo se reconstruye al cambiar de
  app/misión/profesión, no cada frame (quita el lag al clicar).
- Assets nuevos: `xcyos_chrome.png` rehecho, `lp_icon_00..16`,
  `lp_prof_{ladron,medico,ingeniero,veterano}`. `docs/GUI_ASSETS.md`
  especifica el chrome + iconos.
- **`KeyasZones.getEntries`**: `LP_BankSecurity` reutiliza la lista de
  entradas de KeyasZones para su cerrojo en vez de barrer el perímetro por
  su cuenta — un escaneo por minuto cerca del banco en vez de dos.
- **Bolsa del botín**: gris (`IconsForTexture = DuffelBag_Grey` + `model`
  propio con textura, porque el `DuffelBag_Ground` vanilla no trae textura).
  Se quitó el tinte por código, que dejaba icono/modelo en negro.
- **Escena de la nota**: 2 cadáveres con la nota dentro de uno (hay que
  saquearlo), ≥3 zombis custodiando, y nunca bajo un vehículo
  (`findClueSquare` busca casilla con suelo). Confirmar la lectura ahora
  exige la nota en el inventario + un rato leyéndola (~10 s), no depende
  solo de `getAlreadyReadPages`.
- El walkie militar del botín es ahora `LastPurpose.BandWalkieTalkie`
  («Walkie Takie de la banda»), sintonizado a su frecuencia; guardará las
  de otros golpes al descubrir sus mapas.

### Añadido
- **Interacción con la tecla E:** junto a la mesa, `E` abre la GUI (como
  los vehículos). `LP_SafehouseAnchor.lua` expone
  `LastPurpose.findNearbyTable(player)`. El menú contextual del mundo
  ("Usar el ordenador") sigue disponible.
- **Dependencia de KeyasLib** (`require=KeyasLib` en ambos `mod.info`). El
  renderizado de la fuente de terminal del ordenador (glifo a glifo desde el
  atlas) pasó de código propio en `LP_Computer.lua` a
  `KeyasUI.registerFont` + `KeyasUI.text/measure` de KeyasLib. Sin cambio de
  comportamiento; si KeyasLib no está o el atlas falla, cae a `UIFont`.

### Cambiado (migración a KeyasLib)
- **`LP_Options` → `KeyasOptions`.** El panel de Opciones → Mods → Last
  Purpose se crea con `KeyasOptions.createPanel` (envoltorio a prueba de
  doble registro). Se conservan los IDs `toggleTracker` y `debug` para no
  huérfanar los ajustes guardados. `getTrackerKey` y `refreshOptions`
  siguen igual; `refreshOptions` reintenta crear el panel si KeyasOptions
  cargó después.
- **`LP_BankSecurity` → `KeyasZones` (parcial).** El trabajo genérico
  -envolver `isValid()` en las 4 acciones cronometradas y el barrido que
  revierte roturas por combate directo/zombis- lo hace ahora
  `KeyasZones.register("knox_bank_seal", {bbox, active, warn})`. `LP_BankSecurity`
  se queda con lo específico: cerrojo real (`setPermaLocked`) + salvar/
  restaurar la salud original, el contador de cristales rotos → alarma
  anticipada, y los pensamientos al acercarse. Se retiró `onWeaponHitBankObject`
  (el evento `OnWeaponHitThumpable` no dispara en B42; el barrido de
  KeyasZones lo cubre). El archivo pasó de 366 a 264 líneas.
  **Verificar en juego que KeyasZones detecta las puertas/ventanas del
  banco** (`KeyasLib.DEBUG = true` y mirar el conteo).

### Pendiente (hito 2 del hub)
- Lógica de desbloqueo real: Louisville en cadena (completar uno abre el
  siguiente, 3 en total); otras ciudades gated por «haber estado allí» o
  tener el mapa vanilla de la región; líneas de profesión por prólogo +
  Nv. 2 de habilidad. Objetivo ~19 golpes para el Ladrón. El catálogo del
  ordenador pasará a `status` calculado, no hardcodeado.
- Scroll en la lista de misiones si algún día no cabe (KeyasCSS aún no
  tiene scroll).

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
