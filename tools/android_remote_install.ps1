param(
	[string]$DeviceIp = "",
	[int]$Port = 5555,
	[string]$ApkPath = "build/android/ArcadiaRealms2D-release.apk",
	[string]$PackageId = "com.arcadia.realms2d",
	[switch]$Launch,
	[switch]$Pair,
	[int]$PairPort = 0,
	[string]$PairCode = "",
	[switch]$EnableTcpipFromUsb,
	[string]$UsbSerial = ""
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
		try {
			if ($c -eq "adb.exe") {
				$cmd = Get-Command adb.exe -ErrorAction SilentlyContinue
				if ($cmd) { return $cmd.Source }
			} elseif (Test-Path $c) {
				return (Resolve-Path $c).Path
			}
		} catch { }
	}
	throw "ADB nao encontrado. Instale Android platform-tools e/ou ajuste ANDROID_SDK_ROOT."
}

function Invoke-Adb([string]$adb, [string[]]$adbArgs) {
	& $adb @adbArgs
	if ($LASTEXITCODE -ne 0) {
		throw "Falha ao executar adb $($adbArgs -join ' ')"
	}
}

function Get-ConnectedDevices([string]$adb) {
	$out = & $adb devices
	$devices = @()
	foreach ($line in $out) {
		if ($line -match "^\s*$") { continue }
		if ($line -match "^List of devices attached") { continue }
		if ($line -match "\tdevice$") {
			$devices += ($line -split "`t")[0].Trim()
		}
	}
	return $devices
}

$adb = Resolve-AdbPath
Write-Host "ADB: $adb" -ForegroundColor Cyan

Invoke-Adb $adb @("start-server")

if ($EnableTcpipFromUsb) {
	$devices = Get-ConnectedDevices $adb
	if ($devices.Count -eq 0) {
		throw "Nenhum aparelho USB conectado para habilitar tcpip."
	}
	$target = $UsbSerial
	if ([string]::IsNullOrWhiteSpace($target)) {
		$target = $devices[0]
	}
	Write-Host "Habilitando ADB tcpip em $target..." -ForegroundColor Yellow
	Invoke-Adb $adb @("-s", $target, "tcpip", "$Port")
}

if ($Pair) {
	if ([string]::IsNullOrWhiteSpace($DeviceIp) -or $PairPort -le 0 -or [string]::IsNullOrWhiteSpace($PairCode)) {
		throw "Para parear use -Pair -DeviceIp <ip> -PairPort <porta> -PairCode <codigo>."
	}
	Write-Host "Pareando em $DeviceIp`:$PairPort..." -ForegroundColor Yellow
	Invoke-Adb $adb @("pair", "$DeviceIp`:$PairPort", "$PairCode")
}

if (-not [string]::IsNullOrWhiteSpace($DeviceIp)) {
	Write-Host "Conectando em $DeviceIp`:$Port..." -ForegroundColor Yellow
	Invoke-Adb $adb @("connect", "$DeviceIp`:$Port")
}

$apkAbsolute = Resolve-Path $ApkPath -ErrorAction Stop
Write-Host "APK: $apkAbsolute" -ForegroundColor Cyan

$connected = Get-ConnectedDevices $adb
if ($connected.Count -eq 0) {
	throw "Nenhum dispositivo conectado. Conecte via USB ou use -DeviceIp para Wi-Fi ADB."
}

Write-Host "Instalando no dispositivo: $($connected[0])" -ForegroundColor Green
Invoke-Adb $adb @("install", "-r", "$apkAbsolute")

if ($Launch) {
	Write-Host "Abrindo app..." -ForegroundColor Green
	Invoke-Adb $adb @("shell", "monkey", "-p", $PackageId, "-c", "android.intent.category.LAUNCHER", "1")
}

Write-Host "Instalacao remota concluida." -ForegroundColor Green
