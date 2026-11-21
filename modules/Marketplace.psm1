
# ==========================================
# RH!NOIFY - Online Marketplace
# Version 0.3.0
# ==========================================

$script:MarketplaceBase = "https://raw.githubusercontent.com/Soraaaaaaaaaaa/RHINOIFY/main/marketplace"

function Get-RhinoCatalog {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("themes", "plugins", "apps")]
        [string]$Category
    )

    $url = "$script:MarketplaceBase/$Category.json"

    try {
        Write-Host "Connecting to RH!NOIFY Marketplace..." -ForegroundColor Cyan

        $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 15 -ErrorAction Stop

        $items = @($response)

        if ($items.Count -eq 0) {
            Write-Host "Marketplace catalog is empty." -ForegroundColor Yellow
            return
        }

        foreach ($item in $items) {
            Write-Output $item
        }
    }
    catch {
        Write-Host "Unable to connect to marketplace." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor DarkGray
    }
}

function Show-RhinoCatalog {
    param(
        [ValidateSet("themes", "plugins", "apps")]
        [string]$Category = "themes"
    )

    $items = @(Get-RhinoCatalog -Category $Category)

    if ($items.Count -eq 0) {
        Write-Host "No marketplace listings found." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "  RH!NOIFY MARKETPLACE" -ForegroundColor Red
    Write-Host "  Category: $Category" -ForegroundColor DarkGray
    Write-Host "  Listings: $($items.Count)" -ForegroundColor Green
    Write-Host ""

    $items | Format-Table id, name, description -AutoSize
}

function Search-RhinoCatalog {
    param(
        [ValidateSet("themes", "plugins", "apps")]
        [string]$Category = "themes",

        [Parameter(Mandatory = $true)]
        [string]$Query
    )

    $items = @(Get-RhinoCatalog -Category $Category)

    $Query = $Query.Trim()

    $results = @(
        $items | Where-Object {
            $_.name -like "*$Query*" -or
            $_.description -like "*$Query*" -or
            $_.id -like "*$Query*" -or
            $_.author -like "*$Query*"
        }
    )

    if ($results.Count -eq 0) {
        Write-Host "No matching listings found for '$Query'." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "SEARCH RESULTS" -ForegroundColor Red
    Write-Host "Found: $($results.Count)" -ForegroundColor Green
    Write-Host ""

    $results | Format-Table id, name, description -AutoSize
}

Export-ModuleMember -Function Get-RhinoCatalog, Show-RhinoCatalog, Search-RhinoCatalog
