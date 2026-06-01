param(
	[string]$PhoneDir = "/sdcard/Download/ArcadiaSprites",
	[string]$LocalTempDir = "build/imported_phone_sprites",
	[string]$AssetsDir = "assets/sprites",
	[string]$DeviceSerial = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-AdbPath {
	$candidates = @()
	if ($env:ANDROID_SDK_ROOT) {
		$candidates += (Join-Path $env:ANDROID_SDK_ROOT "platform-tools\adb.exe")
	}
	if ($env:ANDROID_HOME) {
		$candidates += (Join-Path $env:ANDROID_HOME "platform-tools\adb.exe")
	}
	$candidates += "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
	$candidates += "adb.exe"
	foreach ($c in $candidates) {
		if ($c -eq "adb.exe") {
			$cmd = Get-Command adb.exe -ErrorAction SilentlyContinue
			if ($cmd) { return $cmd.Source }
		} elseif (Test-Path $c) {
			return (Resolve-Path $c).Path
		}
	}
	throw "ADB nao encontrado."
}

function Invoke-Adb([string]$adb, [string[]]$adbArgs) {
	& $adb @adbArgs
	if ($LASTEXITCODE -ne 0) {
		throw "Falha ao executar adb $($adbArgs -join ' ')"
	}
}

$adb = Resolve-AdbPath
New-Item -ItemType Directory -Path $LocalTempDir -Force | Out-Null
New-Item -ItemType Directory -Path $AssetsDir -Force | Out-Null

$adbBase = @()
if (-not [string]::IsNullOrWhiteSpace($DeviceSerial)) {
	$adbBase += @("-s", $DeviceSerial)
}

Write-Host "Puxando sprites de $PhoneDir..." -ForegroundColor Cyan
Invoke-Adb $adb ($adbBase + @("pull", "$PhoneDir/.", $LocalTempDir))

$classes = @("guerreiro", "mago", "arqueiro")
$directions = @("front", "side", "back")
$extensions = @(".png", ".jpg", ".jpeg", ".webp")
$copied = 0

foreach ($class in $classes) {
	foreach ($direction in $directions) {
		$source = $null
		foreach ($ext in $extensions) {
			$candidate = Join-Path $LocalTempDir "$class`_$direction$ext"
			if (Test-Path $candidate) {
				$source = $candidate
				break
			}
		}
		if ($null -eq $source) {
			Write-Host "Nao encontrado: $class`_$direction.(png/jpg/webp)" -ForegroundColor DarkYellow
			continue
		}
		$target = Join-Path $AssetsDir "player_$class`_art_$direction.png"
		if ([IO.Path]::GetExtension($source).ToLowerInvariant() -eq ".png") {
			Copy-Item $source $target -Force
		} else {
			Add-Type -AssemblyName System.Drawing
			$image = [System.Drawing.Bitmap]::FromFile((Resolve-Path $source).Path)
			$image.Save((Join-Path (Resolve-Path $AssetsDir).Path "player_$class`_art_$direction.png"), [System.Drawing.Imaging.ImageFormat]::Png)
			$image.Dispose()
		}
		$copied += 1
		Write-Host "Importado: player_$class`_art_$direction.png" -ForegroundColor Green
	}
}

Write-Host "Importacao concluida. Arquivos importados: $copied" -ForegroundColor Green
