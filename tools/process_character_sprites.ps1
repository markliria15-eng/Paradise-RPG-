param(
    [int]$NpcPixelHeight = 48,
    [int]$NpcUpscale = 2
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

function Test-BackgroundPixel {
    param([System.Drawing.Color]$Color)

    $max = [Math]::Max($Color.R, [Math]::Max($Color.G, $Color.B))
    $min = [Math]::Min($Color.R, [Math]::Min($Color.G, $Color.B))
    $range = $max - $min

    # Removes white/gray checkerboard backgrounds without eating saturated art.
    return ($Color.R -ge 205 -and $Color.G -ge 205 -and $Color.B -ge 205 -and $range -le 44)
}

function Copy-TransparentCrop {
    param(
        [string]$SourcePath,
        [string]$OutputPath,
        [int]$Pad = 8
    )

    $src = [System.Drawing.Bitmap]::FromFile((Resolve-Path $SourcePath).Path)
    $tmp = New-Object System.Drawing.Bitmap($src.Width, $src.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $minX = $src.Width
    $minY = $src.Height
    $maxX = 0
    $maxY = 0

    for ($y = 0; $y -lt $src.Height; $y++) {
        for ($x = 0; $x -lt $src.Width; $x++) {
            $p = $src.GetPixel($x, $y)
            if (Test-BackgroundPixel $p) {
                $tmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, $p.R, $p.G, $p.B))
            } else {
                $tmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, $p.R, $p.G, $p.B))
                if ($x -lt $minX) { $minX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }

    if ($maxX -le $minX -or $maxY -le $minY) {
        $tmp.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $src.Dispose()
        $tmp.Dispose()
        return
    }

    $minX = [Math]::Max(0, $minX - $Pad)
    $minY = [Math]::Max(0, $minY - $Pad)
    $maxX = [Math]::Min($src.Width - 1, $maxX + $Pad)
    $maxY = [Math]::Min($src.Height - 1, $maxY + $Pad)
    $rect = New-Object System.Drawing.Rectangle($minX, $minY, ($maxX - $minX + 1), ($maxY - $minY + 1))
    $crop = $tmp.Clone($rect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $crop.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $crop.Dispose()
    $src.Dispose()
    $tmp.Dispose()
}

function Resize-Nearest {
    param(
        [string]$SourcePath,
        [string]$OutputPath,
        [int]$TargetHeight,
        [int]$Upscale = 1
    )

    $src = [System.Drawing.Bitmap]::FromFile((Resolve-Path $SourcePath).Path)
    $smallHeight = [Math]::Max(1, $TargetHeight)
    $smallWidth = [Math]::Max(1, [int][Math]::Round($src.Width * ($smallHeight / [double]$src.Height)))
    $finalWidth = $smallWidth * $Upscale
    $finalHeight = $smallHeight * $Upscale

    $small = New-Object System.Drawing.Bitmap($smallWidth, $smallHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $gSmall = [System.Drawing.Graphics]::FromImage($small)
    $gSmall.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $gSmall.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $gSmall.Clear([System.Drawing.Color]::Transparent)
    $gSmall.DrawImage($src, 0, 0, $smallWidth, $smallHeight)
    $gSmall.Dispose()

    $final = New-Object System.Drawing.Bitmap($finalWidth, $finalHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $gFinal = [System.Drawing.Graphics]::FromImage($final)
    $gFinal.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $gFinal.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $gFinal.Clear([System.Drawing.Color]::Transparent)
    $gFinal.DrawImage($small, 0, 0, $finalWidth, $finalHeight)
    $gFinal.Dispose()

    $final.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $src.Dispose()
    $small.Dispose()
    $final.Dispose()
}

function New-WalkFrame {
    param(
        [string]$SourcePath,
        [string]$OutputPath,
        [int]$Phase
    )

    $src = [System.Drawing.Bitmap]::FromFile((Resolve-Path $SourcePath).Path)
    $out = New-Object System.Drawing.Bitmap($src.Width, $src.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($out)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $g.Clear([System.Drawing.Color]::Transparent)

    $topHeight = [int]($src.Height * 0.46)
    $midHeight = [int]($src.Height * 0.18)
    $bottomY = $topHeight + $midHeight
    $bottomHeight = $src.Height - $bottomY

    $bob = if ($Phase -eq 1) { -8 } else { -3 }
    $lean = if ($Phase -eq 1) { -5 } else { 5 }
    $leg = if ($Phase -eq 1) { 9 } else { -9 }

    $topSrc = New-Object System.Drawing.Rectangle(0, 0, $src.Width, $topHeight)
    $midSrc = New-Object System.Drawing.Rectangle(0, $topHeight, $src.Width, $midHeight)
    $bottomSrc = New-Object System.Drawing.Rectangle(0, $bottomY, $src.Width, $bottomHeight)

    $midX = [int]($lean / 2)
    $midY = [int]($topHeight + $bob)
    $topDst = New-Object System.Drawing.Rectangle($lean, $bob, $src.Width, $topHeight)
    $midDst = New-Object System.Drawing.Rectangle($midX, $midY, $src.Width, $midHeight)
    $bottomDst = New-Object System.Drawing.Rectangle($leg, $bottomY, $src.Width, $bottomHeight)

    $g.DrawImage($src, $topDst, $topSrc, [System.Drawing.GraphicsUnit]::Pixel)
    $g.DrawImage($src, $midDst, $midSrc, [System.Drawing.GraphicsUnit]::Pixel)
    $g.DrawImage($src, $bottomDst, $bottomSrc, [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()
    $out.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $src.Dispose()
    $out.Dispose()
}

$npcSources = Get-ChildItem "assets/sprites" -Filter "npc_custom_*.jpg" | Sort-Object Name
foreach ($source in $npcSources) {
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($source.Name)
    $tmp = Join-Path $env:TEMP "$baseName.transparent.png"
    $out = "assets/sprites/$($baseName)_pixel.png"
    Copy-TransparentCrop -SourcePath $source.FullName -OutputPath $tmp -Pad 10
    Resize-Nearest -SourcePath $tmp -OutputPath $out -TargetHeight $NpcPixelHeight -Upscale $NpcUpscale
    Remove-Item $tmp -ErrorAction SilentlyContinue
    Write-Host "NPC pixelado: $out"
}

$classes = @("guerreiro", "mago", "arqueiro")
$directions = @("front", "back", "side")
foreach ($class in $classes) {
    foreach ($direction in $directions) {
        $source = "assets/sprites/player_${class}_art_${direction}.png"
        if (!(Test-Path $source)) {
            continue
        }
        New-WalkFrame -SourcePath $source -OutputPath "assets/sprites/player_${class}_art_${direction}_walk_1.png" -Phase 1
        New-WalkFrame -SourcePath $source -OutputPath "assets/sprites/player_${class}_art_${direction}_walk_2.png" -Phase 2
        Write-Host "Frames caminhada: $class $direction"
    }
}
