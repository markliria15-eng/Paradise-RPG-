param(
	[string]$ApkPath = "build/android/ArcadiaRealms2D-release.apk",
	[string]$SiteDir = "site",
	[string]$Version = "Release Android"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$apk = Resolve-Path $ApkPath -ErrorAction Stop
$site = Resolve-Path $SiteDir -ErrorAction Stop
$downloads = Join-Path $site "downloads"
New-Item -ItemType Directory -Path $downloads -Force | Out-Null

$targetApk = Join-Path $downloads "ArcadiaRealms2D-release.apk"
Copy-Item $apk $targetApk -Force

$file = Get-Item $targetApk
$metadata = [ordered]@{
	version = $Version
	file = "downloads/ArcadiaRealms2D-release.apk"
	size_bytes = $file.Length
	size_mb = [math]::Round($file.Length / 1MB, 2)
	published_at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$metadataPath = Join-Path $site "app-version.json"
$metadata | ConvertTo-Json | Set-Content -Path $metadataPath -Encoding UTF8

Write-Host "Site atualizado:" -ForegroundColor Green
Write-Host "  APK: $targetApk"
Write-Host "  Metadata: $metadataPath"
