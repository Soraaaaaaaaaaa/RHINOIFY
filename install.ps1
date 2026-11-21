# RH!NOIFY Windows installer
# Usage after publishing: iwr -useb https://raw.githubusercontent.com/OWNER/RHINOIFY/main/install.ps1 | iex

$ErrorActionPreference = "Stop"
$Owner = "YOUR_GITHUB_USERNAME"
$Repo = "RHINOIFY"
$AssetName = "RHINOIFY-Setup.exe"
$InstallDir = Join-Path $env:TEMP "RHINOIFY-Installer"
$InstallerPath = Join-Path $InstallDir $AssetName

Write-Host ""
Write-Host "  RH!NOIFY INSTALLER" -ForegroundColor Red
Write-Host "  Spotify customization manager" -ForegroundColor DarkGray
Write-Host ""

if ($Owner -eq "YOUR_GITHUB_USERNAME") {
    throw "Set the GitHub owner in install.ps1 before publishing this installer."
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$ApiUrl = "https://api.github.com/repos/$Owner/$Repo/releases/latest"
Write-Host "[1/3] Checking latest release..." -ForegroundColor Cyan
$Release = Invoke-RestMethod -Uri $ApiUrl -Headers @{ "User-Agent" = "RHINOIFY-Installer" }
$Asset = $Release.assets | Where-Object { $_.name -eq $AssetName } | Select-Object -First 1
if (-not $Asset) { throw "The latest GitHub release does not contain $AssetName." }

Write-Host "[2/3] Downloading RH!NOIFY $($Release.tag_name)..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $Asset.browser_download_url -OutFile $InstallerPath

Write-Host "[3/3] Starting setup..." -ForegroundColor Cyan
$process = Start-Process -FilePath $InstallerPath -ArgumentList "/S" -Wait -PassThru
if ($process.ExitCode -ne 0) {
    Write-Warning "The installer exited with code $($process.ExitCode). You can run the downloaded installer manually:"
    Write-Host $InstallerPath
} else {
    Write-Host "RH!NOIFY setup finished." -ForegroundColor Green
}
