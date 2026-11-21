
# ==========================================
# RH!NOIFY - Installer
# Version 0.1.0
# ==========================================

$script:RhinoData = Join-Path $env:APPDATA "RHINOIFY"
$script:InstalledFile = Join-Path $script:RhinoData "installed.json"

function Initialize-RhinoInstaller {
    if (!(Test-Path $script:RhinoData)) {
        New-Item -ItemType Directory -Path $script:RhinoData -Force | Out-Null
    }

    if (!(Test-Path $script:InstalledFile)) {
        "[]" | Set-Content -Path $script:InstalledFile -Encoding UTF8
    }
}

function Get-RhinoInstalled {
    Initialize-RhinoInstaller

    try {
        $items = @(Get-Content $script:InstalledFile -Raw | ConvertFrom-Json)
        return $items
    }
    catch {
        Write-Host "Unable to read installed packages." -ForegroundColor Red
        return @()
    }
}

function Add-RhinoInstalled {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [string]$Category = "themes"
    )

    Initialize-RhinoInstaller

    $items = @(Get-RhinoInstalled)

    if ($items | Where-Object { $_.id -eq $Id }) {
        Write-Host "$Name is already registered." -ForegroundColor Yellow
        return
    }

    $entry = [PSCustomObject]@{
        id = $Id
        name = $Name
        category = $Category
        installedAt = (Get-Date).ToString("o")
        status = "registered"
    }

    $items = @($items) + @($entry)

    $items | ConvertTo-Json -Depth 5 |
        Set-Content -Path $script:InstalledFile -Encoding UTF8

    Write-Host "$Name registered successfully." -ForegroundColor Green
    Write-Host "Note: Registration does not install theme files yet." -ForegroundColor Yellow
}

function Remove-RhinoInstalled {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id
    )

    Initialize-RhinoInstaller

    $items = @(Get-RhinoInstalled)
    $remaining = @($items | Where-Object { $_.id -ne $Id })

    if ($remaining.Count -eq $items.Count) {
        Write-Host "Package '$Id' is not registered as installed." -ForegroundColor Yellow
        return
    }

    $remaining | ConvertTo-Json -Depth 5 |
        Set-Content -Path $script:InstalledFile -Encoding UTF8

    Write-Host "Registration for '$Id' removed." -ForegroundColor Green
    Write-Host "No theme files were deleted." -ForegroundColor Yellow
}

function Show-RhinoInstalled {
    $items = @(Get-RhinoInstalled)

    Write-Host ""
    Write-Host "  RH!NOIFY INSTALLED PACKAGES" -ForegroundColor Red
    Write-Host ""

    if ($items.Count -eq 0) {
        Write-Host "No packages registered." -ForegroundColor Yellow
        return
    }

    $items | Format-Table id, name, category, status -AutoSize
}

Export-ModuleMember -Function Add-RhinoInstalled, Remove-RhinoInstalled, Show-RhinoInstalled
