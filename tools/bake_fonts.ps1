<#
    bake_fonts.ps1 - regenerates the terminal-font atlases for LP_Computer.

    Build 42 has no clean API to register a new .fnt without stomping a
    vanilla one, so KeyasUI (KeyasLib) draws custom text glyph-by-glyph
    from a PNG atlas + a metrics Lua table. This bakes those, offline,
    with .NET System.Drawing from fonts already on the machine.

    Output:
      42/media/ui/LastPurpose/lp_ui_14.png   (labels, eyebrows, badges, tiles)
      42/media/ui/LastPurpose/lp_ui_18.png   (body text, mission rows)
      42/media/ui/LastPurpose/lp_ui_30.png   (detail-pane title)
      42/media/ui/LastPurpose/lp_mono_16.png (numbers, status bar, clock)
      42/media/lua/client/LastPurpose/LP_TermFontData.lua
        -> LP_TermFontData = { ui14={lh,base,g={...}}, ui18=..., ui30=..., mono16=... }
        each `g` entry is {x,y,w,h,xoff,yoff,xadv}, exactly what
        KeyasUI.registerFont expects (positional glyph arrays). The .lua
        lives under media/lua/ so `require "LastPurpose/LP_TermFontData"`
        resolves; the PNGs live under media/ui/ next to the other art.

    Regenerate:  powershell -ExecutionPolicy Bypass -File tools/bake_fonts.ps1
#>

param(
    [string]$OutDir = "$PSScriptRoot\..\42\media\ui\LastPurpose",
    [string]$LuaOut = "$PSScriptRoot\..\42\media\lua\client\LastPurpose\LP_TermFontData.lua",
    # VT323 (SIL OFL) - la fuente de terminal del mockup XCYOS. Sin instalar:
    # se carga desde el .ttf del repo de assets.
    [string]$FontFile = "$PSScriptRoot\..\..\..\Last Purpose\Assets Fuentes\VT323\VT323-Regular.ttf"
)

Add-Type -AssemblyName System.Drawing

$pfc = $null
$FontFamily = $null
if (Test-Path $FontFile) {
    $pfc = New-Object System.Drawing.Text.PrivateFontCollection
    $pfc.AddFontFile((Resolve-Path $FontFile).Path)
    $FontFamily = $pfc.Families[0]
    Write-Host "loaded font: $($FontFamily.Name)  <- $FontFile"
} else {
    Write-Host "WARN: no font file at $FontFile - falling back to Consolas"
}

# size, output basename, key in the LP_TermFontData table. VT323 solo tiene
# un peso: la jerarquia es puro tamano. Tamanos subidos respecto a un sans
# porque el pixel-font pide mas cuerpo para leerse bien.
$JOBS = @(
    @{ Size = 20; Name = "lp_ui_14";   Key = "ui14" },   # etiquetas, eyebrows, badges, tiles
    @{ Size = 24; Name = "lp_ui_18";   Key = "ui18" },   # cuerpo, filas de mision
    @{ Size = 40; Name = "lp_ui_30";   Key = "ui30" },   # titulo del detalle
    @{ Size = 22; Name = "lp_mono_16"; Key = "mono16" }  # numeros, barra de estado
)
$luaBlocks = New-Object System.Collections.Generic.List[string]

# Character set: printable ASCII + the accented Spanish letters the mod uses.
$cps = @()
for ($c = 0x20; $c -le 0x7E; $c++) { $cps += $c }
$cps += @(0x00A1, 0x00BF, 0x00C1, 0x00C9, 0x00CD, 0x00D1, 0x00D3, 0x00DA, 0x00DC,
          0x00E1, 0x00E9, 0x00ED, 0x00F1, 0x00F3, 0x00FA, 0x00FC, 0x2022, 0x2192, 0x2264)

function Get-InkBounds([System.Drawing.Bitmap]$bmp) {
    $w = $bmp.Width; $h = $bmp.Height
    $minX = $w; $minY = $h; $maxX = -1; $maxY = -1
    $rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
    $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $bytes = New-Object byte[] ($data.Stride * $h)
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
    $bmp.UnlockBits($data)
    for ($y = 0; $y -lt $h; $y++) {
        for ($x = 0; $x -lt $w; $x++) {
            if ($bytes[($y * $data.Stride) + ($x * 4) + 3] -gt 8) {
                if ($x -lt $minX) { $minX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }
    if ($maxX -lt 0) { return $null }
    return @{ X = $minX; Y = $minY; W = ($maxX - $minX + 1); H = ($maxY - $minY + 1) }
}

foreach ($job in $JOBS) {
    $size = [float]$job.Size; $name = $job.Name

    if ($FontFamily) {
        $font = New-Object System.Drawing.Font($FontFamily, $size, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    } else {
        $font = New-Object System.Drawing.Font("Consolas", $size, [System.Drawing.GraphicsUnit]::Pixel)
    }

    # Measure a probe bitmap big enough for any single glyph at this size.
    $cell = [int][Math]::Ceiling($size * 2.4)
    $probe = New-Object System.Drawing.Bitmap $cell, $cell, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $pg = [System.Drawing.Graphics]::FromImage($probe)
    $pg.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $fmt = [System.Drawing.StringFormat]::GenericTypographic
    $fmt.FormatFlags = [System.Drawing.StringFormatFlags]::MeasureTrailingSpaces

    $lineH = [int][Math]::Ceiling($font.GetHeight($pg))
    $ascent = [int][Math]::Round($size)   # good enough baseline for a UI atlas

    # First pass: render every glyph, find ink bounds, collect.
    $glyphs = @{}
    $maxW = 1; $maxH = 1
    foreach ($cp in $cps) {
        $ch = [char]$cp
        $s = [string]$ch
        $adv = $pg.MeasureString($s, $font, [System.Drawing.PointF]::new(0, 0), $fmt).Width
        $pg.Clear([System.Drawing.Color]::FromArgb(0, 255, 255, 255))
        $pg.DrawString($s, $font, [System.Drawing.Brushes]::White, [System.Drawing.PointF]::new(2, 2), $fmt)
        $b = Get-InkBounds $probe
        if ($null -eq $b) {
            # whitespace: no ink, but still advances the pen
            $glyphs[$cp] = @{ W = 0; H = 0; XOff = 0; YOff = 0; XAdv = [int][Math]::Round($adv); Bmp = $null }
        } else {
            $crop = New-Object System.Drawing.Bitmap $b.W, $b.H, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $cg = [System.Drawing.Graphics]::FromImage($crop)
            $cg.DrawImage($probe, (New-Object System.Drawing.Rectangle 0, 0, $b.W, $b.H),
                          $b.X, $b.Y, $b.W, $b.H, [System.Drawing.GraphicsUnit]::Pixel)
            $cg.Dispose()
            $glyphs[$cp] = @{
                W = $b.W; H = $b.H
                XOff = ($b.X - 2)          # ink left relative to pen
                YOff = ($b.Y - 2)          # ink top relative to line top
                XAdv = [int][Math]::Round($adv)
                Bmp = $crop
            }
            if ($b.W -gt $maxW) { $maxW = $b.W }
            if ($b.H -gt $maxH) { $maxH = $b.H }
        }
    }
    $pg.Dispose(); $probe.Dispose()

    # Second pass: pack into a fixed-cell grid atlas.
    $pad = 1
    $cw = $maxW + $pad * 2
    $chh = $maxH + $pad * 2
    $cols = [int][Math]::Ceiling([Math]::Sqrt($cps.Count))
    $rows = [int][Math]::Ceiling($cps.Count / [double]$cols)
    $atlasW = $cols * $cw
    $atlasH = $rows * $chh

    $atlas = New-Object System.Drawing.Bitmap $atlasW, $atlasH, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $ag = [System.Drawing.Graphics]::FromImage($atlas)
    $ag.Clear([System.Drawing.Color]::FromArgb(0, 255, 255, 255))

    $entries = New-Object System.Collections.Generic.List[string]
    $i = 0
    foreach ($cp in $cps) {
        $g = $glyphs[$cp]
        $col = $i % $cols; $row = [int][Math]::Floor($i / $cols)
        $gx = $col * $cw + $pad
        $gy = $row * $chh + $pad
        if ($g.Bmp) {
            $ag.DrawImage($g.Bmp, $gx, $gy)
            $g.Bmp.Dispose()
        }
        # {x,y,w,h,xoff,yoff,xadv}
        $entries.Add(("    [{0}] = {{ {1}, {2}, {3}, {4}, {5}, {6}, {7} }}," -f `
            $cp, $gx, $gy, $g.W, $g.H, $g.XOff, $g.YOff, $g.XAdv))
        $i++
    }
    $ag.Dispose()

    $pngPath = Join-Path $OutDir "$name.png"
    $atlas.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $atlas.Dispose()
    $font.Dispose()

    $luaBlocks.Add("  $($job.Key) = {")
    $luaBlocks.Add("    lh = $lineH, base = $ascent,")
    $luaBlocks.Add("    g = {")
    foreach ($e in $entries) { $luaBlocks.Add("  $e") }
    $luaBlocks.Add("    },")
    $luaBlocks.Add("  },")

    Write-Host ("wrote {0}.png  ({1}x{2}, {3} glyphs, lh={4})" -f $name, $atlasW, $atlasH, $cps.Count, $lineH)
}

$out = New-Object System.Collections.Generic.List[string]
$out.Add("-- Generated by tools/bake_fonts.ps1 - do not edit by hand.")
$out.Add("-- Glyph atlases for LP_Computer's terminal text (KeyasUI.registerFont).")
$out.Add("-- Each g entry is { x, y, w, h, xoff, yoff, xadv }.")
$out.Add("LP_TermFontData = {")
foreach ($l in $luaBlocks) { $out.Add($l) }
$out.Add("}")
$out.Add("return LP_TermFontData")
[System.IO.File]::WriteAllLines($LuaOut, $out)
Write-Host "wrote $LuaOut"
Write-Host "done."
