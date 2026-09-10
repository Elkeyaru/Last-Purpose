<#
    recolor_gold.ps1 - "baña en oro" la textura de MODELO de un item vanilla
    para el trofeo coleccionable de un golpe (ver
    common/media/scripts/LastPurpose_Trophies.txt).

    Solo genera la textura del MODELO 3D (la que se ve cuando el trofeo esta
    en el suelo o en la mano). El icono de inventario sigue siendo el vanilla
    -- las texturas de WorldItems/ son mapas UV, no iconos, y recortarlas da
    un churro dorado. Salida:

      common/media/textures/LastPurpose/<Nombre>.png

    y el .txt del item declara:
      model <Nombre> { mesh = WorldItems/<malla>, texture = LastPurpose/<Nombre>, scale = ... }

    Uso (desde la raiz del repo):
      powershell -ExecutionPolicy Bypass -File tools/recolor_gold.ps1

    PZ en otra ruta:
      ... -PzMedia "D:\Steam\steamapps\common\ProjectZomboid\media"

    Por defecto solo dora el marco de "La ultima exposicion" (el lingote del
    Knox y la copa del atico ya son dorados vanilla). Para forzar mas:
      ... -Only "LP_TrophyCrimsonLady,LP_TrophyPenthouseGoblet"
#>

param(
    [string]$PzMedia = "C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid\media",
    [string]$OutDir  = "$PSScriptRoot\..\common\media\textures\LastPurpose",
    [hashtable]$Map = @{
        "WorldItems\Frame.png"            = "LP_TrophyCrimsonLady";
        "WorldItems\Ingot_Gold.png"       = "LP_TrophyKnoxIngot";
        "WorldItems\GobletPlain_Gold.png" = "LP_TrophyPenthouseGoblet";
    },
    [string]$Only = "LP_TrophyCrimsonLady"
)

Add-Type -AssemblyName System.Drawing

# Rampa dorada: luminancia 0 / 0.35 / 0.70 / 1.0
$stops = @(
    @{ l = 0.00; r = 42;  g = 28;  b = 6   },
    @{ l = 0.35; r = 150; g = 102; b = 20  },
    @{ l = 0.70; r = 235; g = 183; b = 64  },
    @{ l = 1.00; r = 255; g = 244; b = 200 }
)
function Ramp([double]$l) {
    if ($l -le 0) { return $stops[0] }
    if ($l -ge 1) { return $stops[-1] }
    for ($i = 0; $i -lt $stops.Count - 1; $i++) {
        $a = $stops[$i]; $b = $stops[$i + 1]
        if ($l -ge $a.l -and $l -le $b.l) {
            $t = ($l - $a.l) / ($b.l - $a.l)
            return @{ r = [int]($a.r + ($b.r - $a.r) * $t)
                      g = [int]($a.g + ($b.g - $a.g) * $t)
                      b = [int]($a.b + ($b.b - $a.b) * $t) }
        }
    }
    return $stops[-1]
}

if (-not (Test-Path $PzMedia)) { Write-Error "No encuentro media/ de PZ en: $PzMedia (pasa -PzMedia)"; exit 1 }
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

$onlyList = @()
if ($Only.Trim().Length -gt 0) {
    $onlyList = $Only.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 }
}

foreach ($src in $Map.Keys) {
    $name = $Map[$src]
    if ($onlyList.Count -gt 0 -and ($onlyList -notcontains $name)) { continue }

    $srcPath = Join-Path (Join-Path $PzMedia "textures") $src
    if (-not (Test-Path $srcPath)) { Write-Warning "salto $name : no existe $srcPath"; continue }

    $bmp = New-Object System.Drawing.Bitmap((Resolve-Path $srcPath).Path)
    $w = $bmp.Width; $h = $bmp.Height
    $out = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

    for ($y = 0; $y -lt $h; $y++) {
        for ($x = 0; $x -lt $w; $x++) {
            $p = $bmp.GetPixel($x, $y)
            if ($p.A -eq 0 -or ($p.R -ge 250 -and $p.G -le 5 -and $p.B -ge 250)) {
                $out.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 0, 0, 0)); continue
            }
            $lum = (0.299 * $p.R + 0.587 * $p.G + 0.114 * $p.B) / 255.0
            $lum = [Math]::Max(0.0, [Math]::Min(1.0, ($lum - 0.5) * 1.25 + 0.5))
            $c = Ramp $lum
            $out.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($p.A, $c.r, $c.g, $c.b))
        }
    }

    $dst = Join-Path $OutDir "$name.png"
    $out.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose(); $out.Dispose()
    Write-Host "oro: $name  <- $src  ($w x $h)  ->  $dst"
}

Write-Host "Listo. Reinicia PZ por completo para que cargue las texturas nuevas."
