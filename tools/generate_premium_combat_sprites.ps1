Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$sprites = Join-Path $root "assets\sprites"

function C([string]$Hex, [int]$Alpha = 255) {
    $h = $Hex.TrimStart("#")
    [System.Drawing.Color]::FromArgb(
        $Alpha,
        [Convert]::ToInt32($h.Substring(0, 2), 16),
        [Convert]::ToInt32($h.Substring(2, 2), 16),
        [Convert]::ToInt32($h.Substring(4, 2), 16)
    )
}

function B([string]$Hex, [int]$Alpha = 255) { [System.Drawing.SolidBrush]::new((C $Hex $Alpha)) }
function P([string]$Hex, [int]$Width = 1, [int]$Alpha = 255) { [System.Drawing.Pen]::new((C $Hex $Alpha), $Width) }
function Pt([int]$X, [int]$Y) { [System.Drawing.Point]::new($X, $Y) }

function FillRect($G, [string]$Color, [int]$X, [int]$Y, [int]$W, [int]$H, [int]$Alpha = 255) {
    $b = B $Color $Alpha; $G.FillRectangle($b, $X, $Y, $W, $H); $b.Dispose()
}
function FillEllipse($G, [string]$Color, [int]$X, [int]$Y, [int]$W, [int]$H, [int]$Alpha = 255) {
    $b = B $Color $Alpha; $G.FillEllipse($b, $X, $Y, $W, $H); $b.Dispose()
}
function FillPoly($G, [string]$Color, [System.Drawing.Point[]]$Points, [int]$Alpha = 255) {
    $b = B $Color $Alpha; $G.FillPolygon($b, $Points); $b.Dispose()
}
function DrawLine($G, [string]$Color, [int]$X1, [int]$Y1, [int]$X2, [int]$Y2, [int]$Width = 2, [int]$Alpha = 255) {
    $p = P $Color $Width $Alpha; $G.DrawLine($p, $X1, $Y1, $X2, $Y2); $p.Dispose()
}
function DrawPathLine($G, [string]$Color, [System.Drawing.Point[]]$Points, [int]$Width = 2, [int]$Alpha = 255) {
    $p = P $Color $Width $Alpha; $G.DrawLines($p, $Points); $p.Dispose()
}

function SaveSprite([string]$Name, [scriptblock]$Draw) {
    $path = Join-Path $sprites $Name
    $bmp = [System.Drawing.Bitmap]::new(96, 96, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
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

function Shadow($G, [int]$X, [int]$Y, [int]$W, [int]$H, [int]$Alpha = 70) {
    FillEllipse $G "#090807" $X $Y $W $H $Alpha
}

function Boar($G, [int]$Frame, [hashtable]$Pal, [string]$Rank = "normal") {
    $leg = @(0, 2, -1, 1)[$Frame % 4]
    Shadow $G 16 69 64 12 78
    FillEllipse $G $Pal.outline 16 37 55 32
    FillEllipse $G $Pal.dark 19 40 50 28
    FillEllipse $G $Pal.mid 22 35 45 31
    FillEllipse $G $Pal.light 36 29 32 25
    FillEllipse $G $Pal.snout 55 39 24 17
    FillRect $G $Pal.outline 68 45 5 4
    FillRect $G "#19100d" 61 45 4 3
    FillRect $G "#19100d" 71 45 4 3
    FillRect $G "#fff1c7" 55 55 9 3
    FillRect $G "#fff1c7" 72 54 9 3
    FillPoly $G $Pal.dark @((Pt 26 36), (Pt 16 17), (Pt 38 31))
    FillPoly $G $Pal.dark @((Pt 59 35), (Pt 73 19), (Pt 69 42))
    FillPoly $G $Pal.light @((Pt 29 35), (Pt 21 22), (Pt 36 31)) 210
    foreach ($x in @(25, 39, 53, 65)) {
        FillRect $G $Pal.outline $x (63 + $leg) 6 12
        FillRect $G "#130d0a" $x (74 + $leg) 8 3
        $leg = -$leg
    }
    foreach ($x in @(25, 31, 38, 45, 52)) {
        DrawLine $G $Pal.bristle $x 33 ($x + 6) 26 2 210
    }
    DrawLine $G $Pal.highlight 35 37 55 35 2 180
    if ($Rank -eq "brute") {
        FillRect $G "#56321f" 31 29 30 5 230
        DrawLine $G "#b78d55" 25 38 63 30 2 190
    } elseif ($Rank -eq "king") {
        FillPoly $G "#d8a12b" @((Pt 43 23), (Pt 48 14), (Pt 52 23), (Pt 59 17), (Pt 57 29), (Pt 39 29), (Pt 37 17)) 255
        FillRect $G "#8b2632" 47 23 6 4
    }
}

function Wolf($G, [int]$Frame, [hashtable]$Pal, [string]$Rank = "normal") {
    $step = @(0, 2, -1, 1)[$Frame % 4]
    Shadow $G 13 70 67 12 80
    FillPoly $G $Pal.outline @((Pt 18 46), (Pt 35 34), (Pt 58 35), (Pt 74 45), (Pt 61 58), (Pt 28 59)) 255
    FillEllipse $G $Pal.dark 22 38 49 24
    FillEllipse $G $Pal.mid 34 29 29 23
    FillPoly $G $Pal.dark @((Pt 37 31), (Pt 33 15), (Pt 47 29))
    FillPoly $G $Pal.dark @((Pt 55 31), (Pt 67 17), (Pt 63 38))
    FillPoly $G $Pal.muzzle @((Pt 56 39), (Pt 82 44), (Pt 60 52)) 255
    FillRect $G "#111111" 51 36 4 4
    FillRect $G "#111111" 77 44 4 4
    DrawLine $G $Pal.light 32 39 52 34 2 170
    DrawLine $G $Pal.light 40 51 62 50 2 150
    DrawLine $G $Pal.tail 22 45 8 31 5
    DrawLine $G $Pal.light 18 42 8 31 2 150
    foreach ($x in @(27, 40, 55, 67)) {
        FillRect $G $Pal.outline $x (57 + $step) 6 16
        FillRect $G "#0f1112" $x (72 + $step) 8 3
        $step = -$step
    }
    if ($Rank -eq "alpha") {
        FillRect $G "#c72d2d" 50 37 3 3
        FillRect $G "#c72d2d" 77 44 3 3
        DrawLine $G "#8f1f2d" 36 35 58 36 2
    }
}

function Bat($G, [int]$Frame, [hashtable]$Pal, [string]$Rank = "normal") {
    $wing = @(0, -6, 2, -3)[$Frame % 4]
    Shadow $G 18 70 60 10 65
    FillPoly $G $Pal.outline @((Pt 45 38), (Pt 6 (32 + $wing)), (Pt 19 58), (Pt 32 51), (Pt 41 58)) 255
    FillPoly $G $Pal.outline @((Pt 51 38), (Pt 90 (32 + $wing)), (Pt 77 58), (Pt 64 51), (Pt 55 58)) 255
    FillPoly $G $Pal.wing @((Pt 44 40), (Pt 10 (34 + $wing)), (Pt 24 54), (Pt 34 48), (Pt 42 55)) 255
    FillPoly $G $Pal.wing @((Pt 52 40), (Pt 86 (34 + $wing)), (Pt 72 54), (Pt 62 48), (Pt 54 55)) 255
    DrawLine $G $Pal.edge 20 (38 + $wing) 43 48 2 190
    DrawLine $G $Pal.edge 76 (38 + $wing) 53 48 2 190
    FillEllipse $G $Pal.body 35 30 26 31
    FillEllipse $G $Pal.light 40 34 14 12 180
    FillPoly $G $Pal.outline @((Pt 38 32), (Pt 32 18), (Pt 46 30))
    FillPoly $G $Pal.outline @((Pt 56 32), (Pt 64 18), (Pt 50 30))
    FillRect $G $Pal.eye 42 40 3 3
    FillRect $G $Pal.eye 52 40 3 3
    if ($Rank -eq "shadow") {
        DrawLine $G "#7b3cff" 37 30 58 58 2 180
        DrawLine $G "#7b3cff" 58 30 37 58 2 120
    }
}

function Spider($G, [int]$Frame, [hashtable]$Pal, [string]$Rank = "normal") {
    $s = @(0, 2, -1, 1)[$Frame % 4]
    Shadow $G 17 73 62 10 78
    foreach ($side in @(-1, 1)) {
        $baseX = if ($side -lt 0) { 39 } else { 58 }
        DrawPathLine $G $Pal.outline @((Pt $baseX 45), (Pt ($baseX + $side * 24) (35 + $s)), (Pt ($baseX + $side * 33) (28 + $s))) 4
        DrawPathLine $G $Pal.outline @((Pt $baseX 50), (Pt ($baseX + $side * 29) (48 - $s)), (Pt ($baseX + $side * 39) (43 - $s))) 4
        DrawPathLine $G $Pal.outline @((Pt $baseX 56), (Pt ($baseX + $side * 27) (64 + $s)), (Pt ($baseX + $side * 36) (71 + $s))) 4
        DrawPathLine $G $Pal.outline @((Pt $baseX 60), (Pt ($baseX + $side * 20) (75 - $s)), (Pt ($baseX + $side * 27) (82 - $s))) 3
    }
    FillEllipse $G $Pal.dark 31 39 36 31
    FillEllipse $G $Pal.mid 40 31 26 22
    FillEllipse $G $Pal.mark 39 47 21 8 180
    FillRect $G $Pal.eye 43 39 3 3
    FillRect $G $Pal.eye 53 39 3 3
    DrawLine $G $Pal.highlight 42 33 58 35 2 170
    if ($Rank -eq "queen") {
        FillEllipse $G "#c25bea" 35 55 28 18 180
        DrawLine $G "#f0c4ff" 39 58 58 62 2 150
    } elseif ($Rank -eq "matriarch") {
        FillEllipse $G "#7a1f35" 34 55 30 18 190
        DrawLine $G "#ff7568" 39 58 58 62 2 160
    }
}

function Spirit($G, [int]$Frame, [hashtable]$Pal, [string]$Rank = "normal") {
    $bob = @(0, -2, 1, -1)[$Frame % 4]
    Shadow $G 22 74 52 8 55
    FillEllipse $G $Pal.aura 20 (16 + $bob) 58 58 58
    FillEllipse $G $Pal.body 27 (18 + $bob) 43 54 220
    FillPoly $G $Pal.body @((Pt 28 (48 + $bob)), (Pt 34 (79 + $bob)), (Pt 44 (63 + $bob)), (Pt 53 (80 + $bob)), (Pt 69 (50 + $bob))) 220
    FillEllipse $G $Pal.light 35 (22 + $bob) 20 18 180
    FillRect $G $Pal.eye 38 (40 + $bob) 4 4
    FillRect $G $Pal.eye 55 (40 + $bob) 4 4
    FillRect $G $Pal.mouth 44 (53 + $bob) 12 3 190
    DrawLine $G $Pal.rune 30 (34 + $bob) 20 (26 + $bob) 2 140
    DrawLine $G $Pal.rune 68 (35 + $bob) 79 (27 + $bob) 2 140
    if ($Rank -eq "arcane") {
        FillRect $G "#b569ff" 47 (31 + $bob) 6 6 190
        DrawLine $G "#824cff" 47 (31 + $bob) 25 (62 + $bob) 2 120
        DrawLine $G "#824cff" 53 (31 + $bob) 74 (62 + $bob) 2 120
    }
}

function MageMob($G, [int]$Frame, [hashtable]$Pal, [string]$Rank = "apprentice") {
    $bob = @(0, 1, 0, -1)[$Frame % 4]
    Shadow $G 23 75 50 9 75
    FillPoly $G $Pal.outline @((Pt 49 (17 + $bob)), (Pt 25 76), (Pt 76 76)) 255
    FillPoly $G $Pal.robe @((Pt 49 (20 + $bob)), (Pt 31 74), (Pt 71 74)) 255
    FillPoly $G $Pal.dark @((Pt 50 (25 + $bob)), (Pt 48 75), (Pt 72 75)) 220
    FillEllipse $G $Pal.skin 39 (21 + $bob) 19 16
    FillRect $G $Pal.hair 37 (19 + $bob) 23 7
    FillRect $G "#1b1115" 42 (30 + $bob) 3 3
    FillRect $G "#1b1115" 53 (30 + $bob) 3 3
    DrawLine $G $Pal.arm 33 (45 + $bob) 16 (62 + $bob) 4
    DrawLine $G $Pal.arm 65 (45 + $bob) 84 (62 + $bob) 4
    FillEllipse $G $Pal.orb 79 (57 + $bob) 11 11 220
    FillRect $G $Pal.trim 43 (45 + $bob) 16 6
    DrawLine $G $Pal.trim 39 (38 + $bob) 58 (69 + $bob) 2 190
    if ($Rank -eq "sentinel") {
        FillRect $G "#a98f43" 38 (40 + $bob) 24 6
        DrawLine $G "#d2b75f" 26 74 73 74 2
    } elseif ($Rank -eq "archmage") {
        FillPoly $G "#d1a543" @((Pt 41 (20 + $bob)), (Pt 49 (8 + $bob)), (Pt 57 (20 + $bob))) 255
        FillEllipse $G "#7cecff" 77 (53 + $bob) 15 15 230
        DrawLine $G "#7cecff" 32 (42 + $bob) 70 (69 + $bob) 2 180
    } elseif ($Rank -eq "knight") {
        FillRect $G "#4c5161" 34 (36 + $bob) 30 18
        FillRect $G "#1a1d25" 41 (24 + $bob) 18 7
    }
}

$palBoar = @{ outline="#2a1710"; dark="#5c3421"; mid="#8c552f"; light="#bd7a3f"; snout="#d08a48"; bristle="#3b2218"; highlight="#e3a563" }
$palBoarBrute = @{ outline="#20120d"; dark="#4b2a1e"; mid="#7c3e29"; light="#ad6036"; snout="#c77d3f"; bristle="#26160f"; highlight="#d18952" }
$palBoarKing = @{ outline="#21120d"; dark="#4a2a20"; mid="#81502f"; light="#c18445"; snout="#d69a56"; bristle="#1f120c"; highlight="#efc06d" }
$palWolf = @{ outline="#15191d"; dark="#3f4852"; mid="#69727d"; muzzle="#c8c4b8"; light="#aeb5bd"; tail="#535d66" }
$palWolfAlpha = @{ outline="#111317"; dark="#2d3039"; mid="#5f646f"; muzzle="#d5d2c7"; light="#c5ccd4"; tail="#3a3f48" }
$palBat = @{ outline="#160d26"; wing="#402872"; edge="#8a63c8"; body="#5c39a0"; light="#8060c8"; eye="#ffe878" }
$palBatShadow = @{ outline="#0d071a"; wing="#24164f"; edge="#7644df"; body="#392079"; light="#633bd1"; eye="#ff57e0" }
$palSpider = @{ outline="#190d22"; dark="#30203e"; mid="#5d3279"; mark="#a85cd9"; eye="#ff75db"; highlight="#cf9cff" }
$palSpirit = @{ aura="#86dbff"; body="#a7e9ff"; light="#effcff"; eye="#244b70"; mouth="#4f8eb6"; rune="#5ac7ff" }
$palSpecter = @{ aura="#ac75ff"; body="#8adfff"; light="#f1e8ff"; eye="#3a1b64"; mouth="#65429c"; rune="#9b5cff" }
$palMage = @{ outline="#140d18"; robe="#4a214f"; dark="#23102c"; skin="#c99670"; hair="#1e1420"; arm="#7c4bb0"; orb="#58dfff"; trim="#d1a343" }
$palSentinel = @{ outline="#10121b"; robe="#2f3757"; dark="#1c2034"; skin="#b18b6d"; hair="#101018"; arm="#4a6fc2"; orb="#76e8ff"; trim="#c8a856" }
$palArch = @{ outline="#11081b"; robe="#50185f"; dark="#1c0d30"; skin="#d1a07a"; hair="#251124"; arm="#a447d4"; orb="#75f4ff"; trim="#d8b557" }

foreach ($i in 0..3) {
    SaveSprite "enemy_javali_walk_$($i + 1).png" { param($G) Boar $G $i $palBoar }
    SaveSprite "enemy_lobo_walk_$($i + 1).png" { param($G) Wolf $G $i $palWolf }
    SaveSprite "enemy_morcego_walk_$($i + 1).png" { param($G) Bat $G $i $palBat }
    SaveSprite "enemy_aranha_walk_$($i + 1).png" { param($G) Spider $G $i $palSpider }
    SaveSprite "enemy_espirito_walk_$($i + 1).png" { param($G) Spirit $G $i $palSpirit }
    SaveSprite "enemy_aprendiz_walk_$($i + 1).png" { param($G) MageMob $G $i $palMage }
    SaveSprite "enemy_javali_bruto_walk_$($i + 1).png" { param($G) Boar $G $i $palBoarBrute "brute" }
    SaveSprite "enemy_javali_rei_walk_$($i + 1).png" { param($G) Boar $G $i $palBoarKing "king" }
    SaveSprite "enemy_lobo_alfa_walk_$($i + 1).png" { param($G) Wolf $G $i $palWolfAlpha "alpha" }
    SaveSprite "enemy_morcego_sombrio_walk_$($i + 1).png" { param($G) Bat $G $i $palBatShadow "shadow" }
    SaveSprite "enemy_aranha_rainha_walk_$($i + 1).png" { param($G) Spider $G $i $palSpider "queen" }
    SaveSprite "enemy_aranha_matriarca_walk_$($i + 1).png" { param($G) Spider $G $i $palSpider "matriarch" }
    SaveSprite "enemy_espirito_arcano_walk_$($i + 1).png" { param($G) Spirit $G $i $palSpecter "arcane" }
    SaveSprite "enemy_sentinela_arcano_walk_$($i + 1).png" { param($G) MageMob $G $i $palSentinel "sentinel" }
    SaveSprite "enemy_arquimago_corrompido_walk_$($i + 1).png" { param($G) MageMob $G $i $palArch "archmage" }
}

SaveSprite "enemy_javali.png" { param($G) Boar $G 0 $palBoar }
SaveSprite "enemy_javali_bruto.png" { param($G) Boar $G 0 $palBoarBrute "brute" }
SaveSprite "enemy_javali_rei.png" { param($G) Boar $G 0 $palBoarKing "king" }
SaveSprite "enemy_lobo.png" { param($G) Wolf $G 0 $palWolf }
SaveSprite "enemy_lobo_alfa.png" { param($G) Wolf $G 0 $palWolfAlpha "alpha" }
SaveSprite "enemy_morcego.png" { param($G) Bat $G 0 $palBat }
SaveSprite "enemy_morcego_sombrio.png" { param($G) Bat $G 0 $palBatShadow "shadow" }
SaveSprite "enemy_aranha.png" { param($G) Spider $G 0 $palSpider }
SaveSprite "enemy_aranha_rainha.png" { param($G) Spider $G 0 $palSpider "queen" }
SaveSprite "enemy_aranha_matriarca.png" { param($G) Spider $G 0 $palSpider "matriarch" }
SaveSprite "enemy_espirito.png" { param($G) Spirit $G 0 $palSpirit }
SaveSprite "enemy_espirito_arcano.png" { param($G) Spirit $G 0 $palSpecter "arcane" }
SaveSprite "enemy_aprendiz.png" { param($G) MageMob $G 0 $palMage }
SaveSprite "enemy_sentinela_arcano.png" { param($G) MageMob $G 0 $palSentinel "sentinel" }
SaveSprite "enemy_arquimago_corrompido.png" { param($G) MageMob $G 0 $palArch "archmage" }

SaveSprite "enemy_bandido_colinas.png" { param($G) MageMob $G 0 @{ outline="#150f0c"; robe="#4b3b22"; dark="#241c12"; skin="#be8c63"; hair="#2b1c13"; arm="#7a4f2c"; orb="#d89944"; trim="#8ba85b" } "apprentice" }
SaveSprite "enemy_golem_pedra.png" {
    param($G)
    Shadow $G 17 75 62 11 85
    FillPoly $G "#1b1f24" @((Pt 32 22),(Pt 56 18),(Pt 73 42),(Pt 63 73),(Pt 29 75),(Pt 16 46)) 255
    FillPoly $G "#59636a" @((Pt 34 25),(Pt 55 23),(Pt 67 43),(Pt 58 68),(Pt 33 70),(Pt 23 47)) 255
    FillRect $G "#1d2227" 37 39 7 5
    FillRect $G "#1d2227" 53 38 7 5
    DrawLine $G "#89949c" 35 30 56 25 3 180
    DrawLine $G "#333b43" 26 52 65 52 2
}
SaveSprite "enemy_guardiao_cristalino.png" {
    param($G)
    Shadow $G 18 75 62 10 70
    FillPoly $G "#14212c" @((Pt 49 9),(Pt 70 44),(Pt 58 78),(Pt 37 78),(Pt 25 44)) 255
    FillPoly $G "#37b8e6" @((Pt 49 14),(Pt 65 45),(Pt 55 72),(Pt 40 72),(Pt 31 45)) 220
    FillPoly $G "#d7ffff" @((Pt 49 15),(Pt 56 43),(Pt 47 35)) 175
    FillRect $G "#14466b" 40 42 5 5
    FillRect $G "#14466b" 55 42 5 5
}
SaveSprite "enemy_draco_jovem.png" {
    param($G)
    Shadow $G 12 73 72 12 85
    FillEllipse $G "#5b1010" 26 37 47 27
    FillPoly $G "#7c1717" @((Pt 41 39),(Pt 25 18),(Pt 20 52)) 255
    FillPoly $G "#a92717" @((Pt 59 39),(Pt 88 24),(Pt 72 55)) 255
    FillEllipse $G "#b52b19" 56 30 24 19
    FillRect $G "#ffd45f" 69 37 4 4
    FillPoly $G "#e0d6b8" @((Pt 76 43),(Pt 89 47),(Pt 77 50)) 255
    DrawLine $G "#351010" 32 63 27 76 4
    DrawLine $G "#351010" 58 63 65 76 4
}
SaveSprite "enemy_tita_cristal.png" {
    param($G)
    Shadow $G 14 77 68 11 78
    FillPoly $G "#101c2b" @((Pt 50 5),(Pt 80 45),(Pt 67 82),(Pt 29 82),(Pt 17 45)) 255
    FillPoly $G "#4fd6ff" @((Pt 50 11),(Pt 72 46),(Pt 62 76),(Pt 35 76),(Pt 25 46)) 225
    FillPoly $G "#ffffff" @((Pt 50 11),(Pt 59 42),(Pt 48 34)) 160
    DrawLine $G "#123f6b" 32 55 67 55 3
}
SaveSprite "enemy_cavaleiro_sombrio.png" { param($G) MageMob $G 0 @{ outline="#090b10"; robe="#252935"; dark="#11141d"; skin="#707075"; hair="#090a0e"; arm="#383f4d"; orb="#ff4747"; trim="#8b2332" } "knight" }
SaveSprite "enemy_general_infernal.png" { param($G) MageMob $G 0 @{ outline="#120606"; robe="#4e1411"; dark="#1f0908"; skin="#b36a4d"; hair="#0c0707"; arm="#a5281c"; orb="#ff7a26"; trim="#d2a34a" } "archmage" }

Write-Host "Premium combat sprites generated."
