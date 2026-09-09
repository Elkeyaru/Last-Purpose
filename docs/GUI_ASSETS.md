# GUI del ordenador — especificación de assets

Reparto acordado: **tú generas el chrome nuevo y los iconos**; yo hago el
código (layout, estado, interacción, tipografía) y encajo tus assets.

Todo se dibuja en un panel con **proporción 16:9**. El código trabaja en un
espacio de diseño de **1920 × 1080** y lo escala a la resolución real, así
que **todos los tamaños de abajo son en píxeles de ese espacio 1920×1080**.

---

## 1. Chrome — `xcyos_chrome.png`

- **Archivo:** `42/media/ui/LastPurpose/xcyos_chrome.png` (reemplaza el actual).
- **Tamaño:** 1920 × 1080 px, PNG RGBA. (Si lo haces a 2560×1440 o 3840×2160
  para más nitidez, avísame y ajusto una constante — pero mantén la
  proporción exacta 16:9 y las zonas proporcionales.)
- **Qué lleva el chrome (todo esto va horneado en el PNG):**
  - Bisel/carcasa CRT, con su degradado y esquinas redondeadas.
  - Escritorio (fondo tras la ventana).
  - **Barra lateral izquierda (rail)** con los 4 huecos de icono + su
    etiqueta debajo (MISIONES / NOTAS / ARCHIVOS / SISTEMA). Los iconos van
    *dentro* del PNG; el código solo dibuja un resaltado encima del hueco
    activo, no el icono.
  - Marco de la ventana + **barra de título** con degradado y el texto
    `LAST PURPOSE // ARCHIVO DE MISIONES` (puede ir horneado; el código
    puede cambiarlo pero por ahora es fijo).
  - Botones de ventana arriba a la derecha: `_  []  X` (horneados; el
    código pone una zona de clic invisible sobre la X).
  - **Barra de estado** abajo: `XCYOS v1.0.3 | LAST PURPOSE TERMINAL` +
    reloj a la derecha.
  - Marca de agua del logo, viñeta, líneas de escaneo — lo que quieras.
- **Qué NO lleva (lo pinta el código encima, déjalo vacío / plano):**
  - El **área de contenido de la ventana**: el rectángulo donde van la
    lista de misiones y el panel de detalle. Déjalo como una superficie
    plana (un color liso) o transparente. **No** dibujes ahí paneles,
    divisiones ni texto de ejemplo.

### Zonas exactas (espacio 1920×1080)

| Zona | x | y | w | h | Qué es |
|---|---|---|---|---|---|
| `win` | 172 | 60 | 1372 | 918 | Contorno exterior de la ventana |
| `content` | 202 | 112 | 1310 | 828 | **Área que pinta el código.** Deja esto vacío/plano en el PNG. |
| `rail[1]` | 20 | 40 | 132 | 92 | Hueco icono MISIONES (activo por defecto) |
| `rail[2]` | 20 | 150 | 132 | 92 | Hueco icono NOTAS |
| `rail[3]` | 20 | 262 | 132 | 92 | Hueco icono ARCHIVOS |
| `rail[4]` | 20 | 374 | 132 | 92 | Hueco icono SISTEMA |
| `titleClose` | 1500 | 62 | 40 | 30 | Zona de clic sobre la X |

Si mueves algo de esto en tu diseño, pásame las coords nuevas y actualizo
`SKIN` en `LP_Computer.lua` — es una sola tabla.

> El código divide `content` en dos: panel de lista (~300 px de ancho a la
> izquierda) y panel de detalle (el resto). Ambos con su propio fondo y
> borde dibujados por el código, así que el PNG solo necesita que ese
> rectángulo esté limpio.

---

## 2. Iconos

- **Carpeta:** `42/media/ui/LastPurpose/`
- **Formato:** PNG RGBA, cuadrados, **línea blanca sobre transparente**
  (el código los tiñe al color que toque en cada sitio — si los haces de
  color no podré recolorearlos).
- **Tamaño de archivo recomendado:** 64 × 64 px (se escalan hacia abajo).
- **Nombres:** `lp_icon_NN.png` con NN de dos dígitos, **exactamente** este
  índice (el código los referencia por número):

| NN | Nombre | Dónde se usa | Tamaño de dibujo | Notas de estilo |
|---|---|---|---|---|
| 00 | misiones | (rail — ya va en el chrome; icono suelto por si acaso) | 30 | monitor / pantalla con líneas |
| 01 | notas | (rail) | 30 | hoja con renglones |
| 02 | archivos | (rail) | 30 | carpeta |
| 03 | sistema | (rail) | 30 | engranaje |
| 04 | folder | barra de título de la ventana | 18 | carpeta pequeña, amarilla al teñir |
| 05 | compass | (reserva, sin uso aún) | 18 | brújula |
| 06 | crosshair | mini-mapa (marcador objetivo) | 16 | mira |
| 07 | finger | botón de acción (CTA) | 28 | dedo señalando / mano |
| 08 | cash | tile de recompensa "EFECTIVO" | 34 | fajo de billetes |
| 09 | gold | tile "LINGOTES" | 34 | lingotes apilados |
| 10 | crate | tile "SUMINISTROS" | 34 | caja / cajón |
| 11 | art | tile (golpe de la galería) | 34 | cuadro con marco |
| 12 | watch | tile (joyería) | 34 | reloj de pulsera |
| 13 | car | tile (golpe del coche) | 34 | coche visto de lado |
| 14 | min | botón `_` de ventana | 16 | guion / minimizar |
| 15 | max | botón `[]` de ventana | 16 | recuadro |
| 16 | close | botón `X` de ventana | 16 | equis |

Los del rail (00–03) y los de ventana (14–16) idealmente van horneados en
el chrome; mándalos igual como icono suelto y el código los usa de reserva
si algún día el chrome no los trae.

### Iconos nuevos opcionales (para el hito siguiente: dock de profesión)

Si te animas, en la misma carpeta, mismo estilo, 64×64 línea blanca:

| Nombre | Uso |
|---|---|
| `lp_prof_ladron.png` | perfil Ladrón (antifaz) |
| `lp_prof_medico.png` | perfil Médico (cruz) |
| `lp_prof_ingeniero.png` | perfil Ingeniero (llave inglesa) |
| `lp_prof_veterano.png` | perfil Veterano (placa / munición) |

No son necesarios ahora; el dock de profesión aún no está implementado.

---

## 3. Lo que hago yo (no necesitas tocar)

- Tipografía: regenero los atlas de fuente del terminal a tamaños con
  jerarquía real (título grande, cuerpo, etiqueta, mono) para que se lea
  bien. Ships como PNG + `.lua` dentro del mod, sin dependencia nueva.
- Todo el layout, el estado, los clics, el resaltado del rail, la
  selección de misión, el badge de estado, el botón de acción, la entrega
  del botín, cerrar con ESC / clic fuera.
- Encajar tus zonas: si tu chrome nuevo mueve el área de contenido o el
  rail, me pasas las coords y actualizo `SKIN`.

---

## 4. Cómo me pasas los assets

Déjalos en `42/media/ui/LastPurpose/` (sobrescribiendo) y avísame. O
mándamelos y los coloco yo. Con el chrome, dime a qué resolución lo hiciste
y si moviste alguna zona.
