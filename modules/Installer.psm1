
# ==========================================
# RH!NOIFY - Installer
# Version 0.2.0
# ==========================================

$script:RhinoData = Join-Path $env:APPDATA "RHINOIFY"
$script:InstalledFile = Join-Path $script:RhinoData "installed.json"
$script:ThemeRoot = Join-Path $script:RhinoData "themes"

function Initialize-RhinoInstaller {
    foreach ($path in @($script:RhinoData, $script:ThemeRoot)) {
        if (!(Test-Path $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
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
        throw "Unable to read RH!NOIFY installed packages: $($_.Exception.Message)"
    }
}

function Save-RhinoInstalled {
    param([array]$Items)

    $Items | ConvertTo-Json -Depth 5 |
        Set-Content -Path $script:InstalledFile -Encoding UTF8
}

function Get-SpicetifyThemePath {
    $command = Get-Command spicetify -ErrorAction SilentlyContinue

    if (!$command) {
        throw "Spicetify was not found. Install Spicetify before installing themes."
    }

    $output = & spicetify path userdata 2>&1

    if ($LASTEXITCODE -ne 0 -or !$output) {
        throw "Could not locate the Spicetify userdata directory."
    }

    $userdata = ($output | Select-Object -Last 1).ToString().Trim()

    if (!(Test-Path $userdata)) {
        throw "Spicetify userdata directory does not exist: $userdata"
    }

    return (Join-Path $userdata "Themes")
}

function Test-RhinoPackageArchive {
    param([string]$ArchivePath)

    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $zip = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)

    try {
        if ($zip.Entries.Count -eq 0) {
            throw "The theme archive is empty."
        }

        foreach ($entry in $zip.Entries) {
            $name = $entry.FullName.Replace('\', '/')

            if ($name.StartsWith('/') -or $name -match '(^|/)\.\.(/|$)' -or $name -match '^[A-Za-z]:') {
                throw "Unsafe path found in theme archive: $name"
            }
        }

        $files = @($zip.Entries | Where-Object { !$_.FullName.EndsWith('/') })

        if (!($files | Where-Object { $_.Name -eq "color.ini" })) {
            throw "Theme archive is missing color.ini."
        }
    }
    finally {
        $zip.Dispose()
    }
}

function Install-RhinoTheme {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    Initialize-RhinoInstaller

    if ($Id -notmatch '^[a-z0-9-]+$') {
        throw "Invalid theme ID."
    }

    if ($Url -notmatch '^https://') {
        throw "Theme download URL must use HTTPS."
    }

    $items = @(Get-RhinoInstalled)

    if ($items | Where-Object { $_.id -eq $Id -and $_.status -eq "installed" }) {
        Write-Host "$Name is already installed." -ForegroundColor Yellow
        return
    }

    $themePath = Get-SpicetifyThemePath
    $destination = Join-Path $themePath $Id
    $managedDestination = Join-Path $script:ThemeRoot $Id
    $temp = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())

    try {
        New-Item -ItemType Directory -Path $temp -Force | Out-Null

        $archive = Join-Path $temp "theme.zip"

        Write-Host "Downloading $Name..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $Url -OutFile $archive -UseBasicParsing -ErrorAction Stop

        if (!(Test-Path $archive) -or (Get-Item $archive).Length -eq 0) {
            throw "Theme download was empty."
        }

        Test-RhinoPackageArchive -ArchivePath $archive

        $extract = Join-Path $temp "extracted"
        Expand-Archive -Path $archive -DestinationPath $extract -Force

        $colorFile = Get-ChildItem -Path $extract -Filter "color.ini" -Recurse -File |
            Select-Object -First 1

        if (!$colorFile) {
            throw "Could not locate color.ini after extraction."
        }

        $source = $colorFile.Directory.FullName

        if (Test-Path $destination) {
            throw "A theme folder already exists at $destination. RH!NOIFY will not overwrite it."
        }

        if (!(Test-Path $themePath)) {
            New-Item -ItemType Directory -Path $themePath -Force | Out-Null
        }

        Copy-Item -Path $source -Destination $destination -Recurse -Force

        # Record the installed package before applying it.
        $items = @($items | Where-Object { $_.id -ne $Id })

        $entry = [PSCustomObject]@{
            id = $Id
            name = $Name
            category = "themes"
            installedAt = (Get-Date).ToString("o")
            status = "installed"
            themePath = $destination
        }

        $items = @($items) + @($entry)
        Save-RhinoInstalled -Items $items

        Write-Host "Applying $Name..." -ForegroundColor Cyan

        & spicetify config current_theme $Id

        if ($LASTEXITCODE -ne 0) {
            throw "Could not set the Spicetify theme."
        }

        & spicetify apply

        if ($LASTEXITCODE -ne 0) {
            throw "Spicetify could not apply the theme. The theme files are still installed."
        }

        Write-Host "$Name installed and applied successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "Installation failed: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
    finally {
        if (Test-Path $temp) {
            Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Uninstall-RhinoTheme {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id
    )

    Initialize-RhinoInstaller

    if ($Id -notmatch '^[a-z0-9-]+$') {
        throw "Invalid theme ID."
    }

    $items = @(Get-RhinoInstalled)
    $entry = $items | Where-Object { $_.id -eq $Id -and $_.status -eq "installed" } |
        Select-Object -First 1

    if (!$entry) {
        Write-Host "Theme '$Id' is not installed by RH!NOIFY." -ForegroundColor Yellow
        return
    }

    $themePath = $entry.themePath
    $managedRoot = [System.IO.Path]::GetFullPath($script:ThemeRoot)
    $fullThemePath = [System.IO.Path]::GetFullPath($themePath)

    if (!$fullThemePath.StartsWith($managedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Safety check failed. Refusing to remove a folder outside RH!NOIFY's managed directory."
    }

    Write-Host "Removing $($entry.name)..." -ForegroundColor Cyan

    if (Test-Path $fullThemePath) {
        Remove-Item -Path $fullThemePath -Recurse -Force
    }

    $remaining = @($items | Where-Object { $_.id -ne $Id })
    Save-RhinoInstalled -Items $remaining

    Write-Host "RH!NOIFY files for '$Id' removed." -ForegroundColor Green
    Write-Host "Your active Spotify theme was not changed. Select another theme in Spicetify if needed." -ForegroundColor Yellow
}

function Add-RhinoInstalled {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$Category = "themes"
    )

    $items = @(Get-RhinoInstalled)

    if ($items | Where-Object { $_.id -eq $Id }) {
        Write-Host "$Name is already registered." -ForegroundColor Yellow
        return
    }

    $items = @($items) + @([PSCustomObject]@{
        id = $Id
        name = $Name
        category = $Category
        installedAt = (Get-Date).ToString("o")
        status = "registered"
    })

    Save-RhinoInstalled -Items $items
    Write-Host "$Name registered." -ForegroundColor Green
}

function Remove-RhinoInstalled {
    param([Parameter(Mandatory = $true)][string]$Id)

    $items = @(Get-RhinoInstalled)
    $remaining = @($items | Where-Object { $_.id -ne $Id })

    Save-RhinoInstalled -Items $remaining
    Write-Host "Registration for '$Id' removed." -ForegroundColor Green
}

function Show-RhinoInstalled {
    $items = @(Get-RhinoInstalled)

    Write-Host ""
    Write-Host "  RH!NOIFY INSTALLED PACKAGES" -ForegroundColor Red
    Write-Host ""

    if ($items.Count -eq 0) {
        Write-Host "No packages installed." -ForegroundColor Yellow
        return
    }

    $items | Format-Table id, name, category, status -AutoSize
}

Export-ModuleMember -Function Add-RhinoInstalled, Remove-RhinoInstalled, Show-RhinoInstalled, Install-RhinoTheme, Uninstall-RhinoTheme
