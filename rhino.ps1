
# ==========================================
# RH!NOIFY - PowerShell CLI
# Version 0.2.0
# ==========================================

$ErrorActionPreference = "Stop"

$script:RhinoVersion = "0.2.0"
$script:Root = $PSScriptRoot

function Show-Banner {
    Write-Host ""
    Write-Host "  RH!NOIFY" -ForegroundColor Red
    Write-Host "  Spotify Customization Platform" -ForegroundColor DarkGray
    Write-Host "  Version $script:RhinoVersion" -ForegroundColor Gray
    Write-Host ""
}

function Show-Help {
    Show-Banner

    Write-Host "COMMANDS" -ForegroundColor Red
    Write-Host "  help          Show commands"
    Write-Host "  version       Show version"
    Write-Host "  doctor        Check system"
    Write-Host "  marketplace   Browse marketplace"
    Write-Host "  install       Install a theme"
    Write-Host "  uninstall     Uninstall a theme"
    Write-Host "  installed     Show installed themes"
    Write-Host "  backup        Back up Spicetify"
    Write-Host "  update        Check for updates"
    Write-Host ""
    Write-Host "MARKETPLACE" -ForegroundColor Red
    Write-Host "  marketplace themes"
    Write-Host "  marketplace plugins"
    Write-Host "  marketplace apps"
    Write-Host "  marketplace search themes rose"
    Write-Host ""
    Write-Host "INSTALLATION" -ForegroundColor Red
    Write-Host "  .\rhino.ps1 install rose-night"
    Write-Host "  .\rhino.ps1 uninstall rose-night"
    Write-Host "  .\rhino.ps1 installed"
    Write-Host ""
}

function Test-Command {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Invoke-Doctor {
    Show-Banner

    Write-Host "SYSTEM DIAGNOSTICS" -ForegroundColor Red
    Write-Host ""

    Write-Host "[OK] PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor Green

    if (Test-Command "git") {
        Write-Host "[OK] Git detected" -ForegroundColor Green
    }
    else {
        Write-Host "[INFO] Git not detected in PATH" -ForegroundColor Yellow
    }

    if (Test-Command "spicetify") {
        Write-Host "[OK] Spicetify detected" -ForegroundColor Green
    }
    else {
        Write-Host "[INFO] Spicetify not detected" -ForegroundColor Yellow
    }

    Write-Host ""
}

function Show-Marketplace {
    param(
        [string]$Category = "themes",
        [string]$Query = ""
    )

    Show-Banner

    $modulePath = Join-Path $script:Root "modules\Marketplace.psm1"

    if (!(Test-Path $modulePath)) {
        Write-Host "Marketplace module not found." -ForegroundColor Red
        return
    }

    Import-Module $modulePath -Force -ErrorAction Stop

    if ($Query) {
        Search-RhinoCatalog -Category $Category -Query $Query
    }
    else {
        Show-RhinoCatalog -Category $Category
    }
}

function Invoke-Backup {
    Show-Banner

    if (!(Test-Command "spicetify")) {
        Write-Host "Spicetify is not installed." -ForegroundColor Red
        return
    }

    Write-Host "Starting Spicetify backup..." -ForegroundColor Cyan
    & spicetify backup

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Backup command completed." -ForegroundColor Green
    }
    else {
        Write-Host "Backup command failed." -ForegroundColor Red
    }
}

function Invoke-RhinoInstall {
    param([string]$Id)

    $marketplacePath = Join-Path $script:Root "modules\Marketplace.psm1"
    $installerPath = Join-Path $script:Root "modules\Installer.psm1"

    if (!(Test-Path $marketplacePath) -or !(Test-Path $installerPath)) {
        throw "Marketplace or installer module is missing."
    }

    Import-Module $marketplacePath -Force -ErrorAction Stop
    Import-Module $installerPath -Force -ErrorAction Stop

    $items = @(Get-RhinoCatalog -Category "themes")
    $match = $items | Where-Object { $_.id -eq $Id } | Select-Object -First 1

    if (!$match) {
        throw "Theme '$Id' was not found in the marketplace."
    }

    if (!$match.url) {
        throw "Theme '$Id' does not have a download URL."
    }

    Install-RhinoTheme -Id $match.id -Name $match.name -Url $match.url
}

function Invoke-RhinoUninstall {
    param([string]$Id)

    $installerPath = Join-Path $script:Root "modules\Installer.psm1"

    if (!(Test-Path $installerPath)) {
        throw "Installer module is missing."
    }

    Import-Module $installerPath -Force -ErrorAction Stop
    Uninstall-RhinoTheme -Id $Id
}

function Invoke-Rhino {
    param([string[]]$Arguments)

    if (!$Arguments -or $Arguments.Count -eq 0) {
        Show-Help
        return
    }

    $command = $Arguments[0].ToLowerInvariant()

    switch ($command) {
        "help" {
            Show-Help
        }

        "version" {
            Show-Banner
        }

        "doctor" {
            Invoke-Doctor
        }

        "marketplace" {
            $category = "themes"
            $query = ""

            if ($Arguments.Count -ge 2) {
                if ($Arguments[1].ToLowerInvariant() -eq "search") {
                    if ($Arguments.Count -lt 4) {
                        Write-Host "Usage: .\rhino.ps1 marketplace search <themes|plugins|apps> <query>" -ForegroundColor Yellow
                        return
                    }

                    $category = $Arguments[2].ToLowerInvariant()
                    $query = [string]::Join(" ", $Arguments[3..($Arguments.Count - 1)])
                }
                else {
                    $category = $Arguments[1].ToLowerInvariant()
                }
            }

            if ($category -notin @("themes", "plugins", "apps")) {
                Write-Host "Invalid marketplace category." -ForegroundColor Red
                return
            }

            Show-Marketplace -Category $category -Query $query
        }

        "install" {
            if ($Arguments.Count -lt 2) {
                Write-Host "Usage: .\rhino.ps1 install <theme-id>" -ForegroundColor Yellow
                return
            }

            Invoke-RhinoInstall -Id $Arguments[1]
        }

        "uninstall" {
            if ($Arguments.Count -lt 2) {
                Write-Host "Usage: .\rhino.ps1 uninstall <theme-id>" -ForegroundColor Yellow
                return
            }

            Invoke-RhinoUninstall -Id $Arguments[1]
        }

        "installed" {
            Import-Module (Join-Path $script:Root "modules\Installer.psm1") -Force
            Show-RhinoInstalled
        }

        "backup" {
            Invoke-Backup
        }

        "update" {
            Show-Banner
            Write-Host "Update system coming soon." -ForegroundColor Yellow
        }

        default {
            Write-Host "Unknown command: $command" -ForegroundColor Red
            Show-Help
        }
    }
}

Invoke-Rhino -Arguments $args
