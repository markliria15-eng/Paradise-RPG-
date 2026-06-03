Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$sprites = Join-Path $root "assets\sprites"

function New-Color([string]$Hex, [int]$Alpha = 255) {
    $clean = $Hex.TrimStart("#")
    return [System.Drawing.Color]::FromArgb(
        $Alpha,
        [Convert]::ToInt32($clean.Substring(0, 2), 16),
        [Convert]::ToInt32($clean.Substring(2, 2), 16),
        [Convert]::ToInt32($clean.Substring(4, 2), 16)
    )
}

function New-Brush([string]$Hex, [int]$Alpha = 255) {
    return [System.Drawing.SolidBrush]::new((New-Color $Hex $Alpha))
}

function New-Pen([string]$Hex, [int]$Width = 1, [int]$Alpha = 255) {
    return [System.Drawing.Pen]::new((New-Color $Hex $Alpha), $Width)
}

function Pt([int]$X, [int]$Y) {
    return [System.Drawing.Point]::new($X, $Y)
}

function Fill-Rect($G, [string]$Color, [int]$X, [int]$Y, [int]$W, [int]$H, [int]$Alpha = 255) {
    $b = New-Brush $Color $Alpha
    $G.FillRectangle($b, $X, $Y, $W, $H)
    $b.Dispose()
}

function Fill-Ellipse($G, [string]$Color, [int]$X, [int]$Y, [int]$W, [int]$H, [int]$Alpha = 255) {
    $b = New-Brush $Color $Alpha
    $G.FillEllipse($b, $X, $Y, $W, $H)
    $b.Dispose()
}

function Fill-Poly($G, [string]$Color, [System.Drawing.Point[]]$Points, [int]$Alpha = 255) {
    $b = New-Brush $Color $Alpha
    $G.FillPolygon($b, $Points)
    $b.Dispose()
}

function Draw-Rect($G, [string]$Color, [int]$X, [int]$Y, [int]$W, [int]$H, [int]$Width = 2, [int]$Alpha = 255) {
    $p = New-Pen $Color $Width $Alpha
    $G.DrawRectangle($p, $X, $Y, $W, $H)
    $p.Dispose()
}

function Draw-Line($G, [string]$Color, [int]$X1, [int]$Y1, [int]$X2, [int]$Y2, [int]$Width = 2, [int]$Alpha = 255) {
    $p = New-Pen $Color $Width $Alpha
    $G.DrawLine($p, $X1, $Y1, $X2, $Y2)
    $p.Dispose()
}

function Draw-ImageFile([string]$Name, [int]$Width, [int]$Height, [scriptblock]$Draw) {
    $path = Join-Path $sprites $Name
    $bmp = [System.Drawing.Bitmap]::new($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $g.Clear([System.Drawing.Color]::Transparent)
    & $Draw $g
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
}

function Draw-House($G, [string]$Roof, [string]$Wall, [string]$Door, [string]$Trim) {
    Fill-Ellipse $G "#111111" 8 78 80 15 80
    Fill-Poly $G "#2b1b16" @((Pt 12 36), (Pt 48 10), (Pt 86 36), (Pt 78 45), (Pt 19 45)) 255
    Fill-Poly $G $Roof @((Pt 15 34), (Pt 48 13), (Pt 82 34), (Pt 74 42), (Pt 22 42)) 255
    Fill-Poly $G "#f1c46a" @((Pt 48 13), (Pt 54 22), (Pt 42 22)) 255
    Fill-Rect $G $Wall 22 43 55 38
    Draw-Rect $G "#32231a" 22 43 55 38 2
    Fill-Rect $G "#16110d" 42 60 14 21
    Fill-Rect $G $Door 44 61 10 20
    Fill-Rect $G "#ffd47b" 30 52 10 9
    Fill-Rect $G "#ffd47b" 62 52 10 9
    Draw-Rect $G "#422b1e" 30 52 10 9 1
    Draw-Rect $G "#422b1e" 62 52 10 9 1
    Fill-Rect $G $Trim 18 78 63 5
    for ($i = 0; $i -lt 6; $i++) {
        Draw-Line $G "#5a3328" (22 + $i * 11) 39 (28 + $i * 11) 27 1 170
    }
}

Draw-ImageFile "decor_house.png" 96 96 {
    param($G)
    Draw-House $G "#7e3125" "#c99b68" "#744426" "#6b4c36"
}

Draw-ImageFile "decor_house_stone.png" 96 96 {
    param($G)
    Draw-House $G "#4d5d77" "#b2a996" "#5d3d28" "#8a6a2f"
}

Draw-ImageFile "decor_house_shop.png" 96 96 {
    param($G)
    Draw-House $G "#8a4c20" "#d0ad72" "#53331d" "#9b6d31"
    Fill-Rect $G "#2e1f13" 30 36 40 8
    Fill-Rect $G "#f2d47b" 33 37 34 5
}

Draw-ImageFile "decor_tree.png" 80 96 {
    param($G)
    Fill-Ellipse $G "#111111" 21 76 38 12 70
    Fill-Rect $G "#5f3820" 36 55 12 29
    Fill-Rect $G "#8a542c" 40 55 4 28
    Fill-Ellipse $G "#245a2d" 17 14 46 44
    Fill-Ellipse $G "#2f7a36" 8 30 34 37
    Fill-Ellipse $G "#367f3d" 37 29 35 38
    Fill-Ellipse $G "#1f4b27" 22 39 37 37
    Fill-Rect $G "#7fb65b" 25 26 6 6 180
    Fill-Rect $G "#79ad54" 52 36 5 5 150
}

Draw-ImageFile "decor_tree_dark.png" 80 96 {
    param($G)
    Fill-Ellipse $G "#111111" 21 76 38 12 80
    Fill-Rect $G "#4d2d1d" 36 55 12 29
    Fill-Rect $G "#6d4328" 40 55 4 28
    Fill-Ellipse $G "#163827" 17 14 46 44
    Fill-Ellipse $G "#1e5c38" 8 30 34 37
    Fill-Ellipse $G "#236743" 37 29 35 38
    Fill-Ellipse $G "#102b20" 22 39 37 37
    Fill-Rect $G "#5c9561" 25 26 6 6 150
}

Draw-ImageFile "decor_crate.png" 40 40 {
    param($G)
    Fill-Ellipse $G "#111111" 5 31 29 6 75
    Fill-Rect $G "#8d5b31" 7 8 26 26
    Draw-Rect $G "#3f2a1b" 7 8 26 26 2
    Draw-Line $G "#3f2a1b" 8 9 33 34 2
    Draw-Line $G "#3f2a1b" 33 9 8 34 2
    Fill-Rect $G "#bd7a3d" 11 12 7 5 170
}

Draw-ImageFile "decor_barrel.png" 40 44 {
    param($G)
    Fill-Ellipse $G "#111111" 7 35 27 6 70
    Fill-Ellipse $G "#7a4a27" 8 7 25 8
    Fill-Rect $G "#8c562d" 8 11 25 25
    Fill-Ellipse $G "#6b3f22" 8 31 25 8
    Draw-Rect $G "#332015" 8 10 25 28 2
    Draw-Line $G "#d19a53" 8 17 33 17 2
    Draw-Line $G "#d19a53" 8 28 33 28 2
}

Draw-ImageFile "decor_fence.png" 48 32 {
    param($G)
    Fill-Ellipse $G "#111111" 3 24 42 5 55
    foreach ($x in @(7, 23, 39)) {
        Fill-Poly $G "#8a5a2d" @((Pt $x 5), (Pt ($x + 5) 10), (Pt ($x + 5) 28), (Pt ($x - 5) 28), (Pt ($x - 5) 10)) 255
        Draw-Line $G "#3b2414" ($x - 5) 28 ($x + 5) 28 1
    }
    Fill-Rect $G "#9d6936" 2 13 44 6
    Fill-Rect $G "#7b4b28" 2 22 44 5
}

Draw-ImageFile "enemy_javali.png" 80 80 {
    param($G)
    Fill-Ellipse $G "#111111" 14 58 52 10 80
    Fill-Ellipse $G "#754323" 18 31 46 28
    Fill-Ellipse $G "#9b5a2f" 28 24 31 25
    Fill-Poly $G "#5b321f" @((Pt 25 31), (Pt 19 17), (Pt 34 26)) 255
    Fill-Poly $G "#5b321f" @((Pt 55 29), (Pt 65 18), (Pt 61 36)) 255
    Fill-Ellipse $G "#c57a3c" 45 36 22 16
    Fill-Rect $G "#241714" 55 42 4 3
    Fill-Rect $G "#241714" 62 42 4 3
    Fill-Rect $G "#111111" 34 33 4 4
    Fill-Rect $G "#f0e1b8" 50 50 7 3
    Fill-Rect $G "#f0e1b8" 63 49 7 3
    foreach ($x in @(25, 38, 51, 61)) {
        Fill-Rect $G "#3a2418" $x 55 5 11
        Fill-Rect $G "#17100c" $x 64 6 3
    }
    Draw-Line $G "#3a2418" 18 43 10 39 2
    Draw-Line $G "#c08446" 32 29 45 27 2 180
}

Draw-ImageFile "enemy_lobo.png" 80 80 {
    param($G)
    Fill-Ellipse $G "#111111" 13 59 55 10 80
    Fill-Ellipse $G "#48505a" 19 34 42 22
    Fill-Ellipse $G "#6f7884" 32 25 25 21
    Fill-Poly $G "#313840" @((Pt 36 27), (Pt 34 14), (Pt 44 26)) 255
    Fill-Poly $G "#313840" @((Pt 52 27), (Pt 60 15), (Pt 58 34)) 255
    Fill-Poly $G "#c6c2b8" @((Pt 53 34), (Pt 69 39), (Pt 55 44)) 255
    Fill-Rect $G "#111111" 48 32 3 3
    Fill-Rect $G "#111111" 66 38 3 3
    foreach ($x in @(24, 36, 50, 59)) {
        Fill-Rect $G "#2a2f35" $x 52 5 14
        Fill-Rect $G "#111111" $x 64 6 3
    }
    Draw-Line $G "#6f7884" 20 41 9 33 3
    Draw-Line $G "#aab0b9" 31 32 44 30 2 160
}

Draw-ImageFile "enemy_morcego.png" 80 80 {
    param($G)
    Fill-Ellipse $G "#111111" 16 58 48 9 70
    Fill-Poly $G "#36205e" @((Pt 39 35), (Pt 8 27), (Pt 19 45), (Pt 31 44)) 255
    Fill-Poly $G "#44286f" @((Pt 41 35), (Pt 72 27), (Pt 61 45), (Pt 49 44)) 255
    Fill-Ellipse $G "#5c3690" 29 27 22 28
    Fill-Poly $G "#2a1748" @((Pt 32 29), (Pt 27 18), (Pt 39 27)) 255
    Fill-Poly $G "#2a1748" @((Pt 47 29), (Pt 53 18), (Pt 41 27)) 255
    Fill-Rect $G "#ffe08a" 35 35 3 3
    Fill-Rect $G "#ffe08a" 44 35 3 3
    Draw-Line $G "#7d59ba" 20 34 8 27 2 180
    Draw-Line $G "#7d59ba" 59 34 72 27 2 180
}

Draw-ImageFile "enemy_aranha.png" 80 80 {
    param($G)
    Fill-Ellipse $G "#111111" 15 61 50 9 80
    Fill-Ellipse $G "#2c1a35" 28 31 28 27
    Fill-Ellipse $G "#5c2a72" 35 25 20 18
    foreach ($y in @(35, 43, 51)) {
        Draw-Line $G "#2c1a35" 32 $y 9 ($y - 7) 3
        Draw-Line $G "#2c1a35" 53 $y 72 ($y - 7) 3
        Draw-Line $G "#2c1a35" 32 $y 12 ($y + 8) 3
        Draw-Line $G "#2c1a35" 53 $y 68 ($y + 8) 3
    }
    Fill-Rect $G "#ff5fd2" 39 32 3 3
    Fill-Rect $G "#ff5fd2" 47 32 3 3
    Fill-Rect $G "#8f4eb4" 36 44 15 5 180
}

Draw-ImageFile "enemy_espirito.png" 80 80 {
    param($G)
    Fill-Ellipse $G "#111111" 19 61 43 8 70
    Fill-Ellipse $G "#9fd8ff" 23 19 34 42 220
    Fill-Poly $G "#9fd8ff" @((Pt 24 45), (Pt 31 66), (Pt 39 52), (Pt 48 67), (Pt 56 45)) 215
    Fill-Ellipse $G "#dff5ff" 30 24 17 15 210
    Fill-Rect $G "#245577" 33 36 4 4
    Fill-Rect $G "#245577" 45 36 4 4
    Fill-Rect $G "#5aa8dd" 38 47 8 3 180
}

Draw-ImageFile "enemy_aprendiz.png" 80 80 {
    param($G)
    Fill-Ellipse $G "#111111" 20 61 41 8 75
    Fill-Poly $G "#4b224e" @((Pt 40 18), (Pt 25 61), (Pt 56 61)) 255
    Fill-Poly $G "#2a1330" @((Pt 40 21), (Pt 34 62), (Pt 56 62)) 255
    Fill-Ellipse $G "#c58b68" 32 16 17 15
    Fill-Rect $G "#1b1120" 31 15 20 6
    Fill-Rect $G "#ffd36d" 35 31 10 6
    Draw-Line $G "#8a54c4" 28 39 16 55 3
    Draw-Line $G "#8a54c4" 52 39 66 55 3
    Fill-Ellipse $G "#52d9ff" 61 50 8 8 220
}

Write-Host "Visual regression assets regenerated in $sprites"
