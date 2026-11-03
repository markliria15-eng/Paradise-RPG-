[CmdletBinding()]
param(
    [ValidateSet("local", "staging", "production")]
    [string]$Environment = "staging",
    [switch]$MobilePreview,
    [switch]$Offline,
    [switch]$SmokeTest
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$godot = Join-Path $repoRoot ".tools\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe"

if (-not (Test-Path -LiteralPath $godot)) {
    throw "Godot 4.6.3 nao encontrado em $godot"
}

$previousEnvironment = $env:PARADISE_MMO_ENV
$exitCode = 1
$effectiveEnvironment = $Environment
if ($Offline) {
    $effectiveEnvironment = "local"
}

try {
	$env:PARADISE_MMO_ENV = $effectiveEnvironment
    $arguments = @("--path", $repoRoot)
    if ($MobilePreview) {
        $arguments += @("--resolution", "1280x720", "--position", "80,50")
    }
    if ($SmokeTest) {
        $arguments += @("--headless", "--quit-after", "12")
    }
	if ($Offline) {
		$arguments += @("--", "--offline-test")
	}

$mode = "online"
if ($Offline) {
    $mode = "offline"
}
	Write-Host "Paradise RPG - ambiente: $effectiveEnvironment - modo: $mode"
    Write-Host "Mouse simula toque; viewport mobile: 1280x720."
    & $godot @arguments
    $exitCode = $LASTEXITCODE
}
finally {
    if ($null -eq $previousEnvironment) {
        Remove-Item Env:PARADISE_MMO_ENV -ErrorAction SilentlyContinue
    }
    else {
        $env:PARADISE_MMO_ENV = $previousEnvironment
    }
}

exit $exitCode
