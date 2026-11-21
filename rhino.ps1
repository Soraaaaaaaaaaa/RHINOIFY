
# ==========================================
# RH!NOIFY - PowerShell CLI
# Version 0.1.0
# ==========================================

$ErrorActionPreference = "Stop"

$script:RhinoVersion = "0.1.0"
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
    Write-Host "  backup        Back up Spicetify"
    Write-Host "  update        Check for updates"
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
    } else {
        Write-Host "[INFO] Git not detected in PATH" -ForegroundColor Yellow
    }

    if (Test-Command "spicetify") {
        Write-Host "[OK] Spicetify detected" -ForegroundColor Green
    } else {
        Write-Host "[INFO] Spicetify not detected" -ForegroundColor Yellow
    }

    Write-Host ""
}

function Show-Marketplace {
    Show-Banner
    Write-Host "RH!NOIFY MARKETPLACE" -ForegroundColor Red
    Write-Host ""
    Write-Host "Marketplace is currently being developed."
    Write-Host "Themes, plugins and apps are coming soon."
    Write-Host ""
}

function Invoke-Backup {
    Show-Banner

    if (!(Test-Command "spicetify")) {
        Write-Host "Spicetify was not detected." -ForegroundColor Yellow
        return
    }

    Write-Host "Starting Spicetify backup..." -ForegroundColor Cyan
    & spicetify backup
}

function Invoke-Rhino {
    param([string[]]$Arguments)

    if (!$Arguments -or $Arguments.Count -eq 0) {
        Show-Help
        return
    }

    switch ($Arguments[0].ToLowerInvariant()) {
        "help"        { Show-Help }
        "version"     { Show-Banner }
        "doctor"      { Invoke-Doctor }
        "marketplace" { Show-Marketplace }
        "backup"      { Invoke-Backup }
        "update" {
            Show-Banner
            Write-Host "Update system coming soon." -ForegroundColor Yellow
        }
        default {
            Write-Host "Unknown command. Run .\rhino.ps1 help" -ForegroundColor Yellow
        }
    }
}

Invoke-Rhino -Arguments $args
