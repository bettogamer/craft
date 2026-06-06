# deploy-local.ps1 - copies Craft and Craft_Browser to the local WoW AddOns folder
#
# Usage:
#   .\scripts\deploy-local.ps1             # deploy both addons
#   .\scripts\deploy-local.ps1 -DryRun    # show what would be copied, no changes
#
# What it does:
#   1. Copies Craft/ -> AddOns/Craft/  (standalone library)
#   2. Builds Craft_Browser/ with Craft embedded (mirrors CI packager logic):
#        AddOns/Craft_Browser/libs/LibStub/ <- Craft/libs/LibStub/
#        AddOns/Craft_Browser/libs/Craft/   <- Craft/ (without libs/)
#        AddOns/Craft_Browser/*             <- Craft_Browser/*
#   3. Replaces .toc packager tokens with local dev values

param(
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Paths
$RepoRoot   = Split-Path $PSScriptRoot -Parent
$WoWAddOns  = "F:\Games\World of Warcraft\_retail_\Interface\AddOns"
$CraftSrc   = Join-Path $RepoRoot "Craft"
$BrowserSrc = Join-Path $RepoRoot "Craft_Browser"

# Version tokens
$RawHash    = git -C $RepoRoot rev-parse --short HEAD 2>$null
$GitHash    = if ($RawHash) { $RawHash.Trim() } else { "unknown" }
$Version    = "dev-$GitHash"
$BuildDate  = Get-Date -Format "yyyyMMdd"

# Helpers
function Copy-Addon {
    param([string]$Src, [string]$Dest)
    if ($DryRun) {
        Write-Host "[dry-run] Would copy: $Src -> $Dest"
        return
    }
    if (Test-Path $Dest) { Remove-Item $Dest -Recurse -Force }
    Copy-Item $Src $Dest -Recurse -Force
    Write-Host "Copied: $Src -> $Dest"
}

function Set-TocTokens {
    param([string]$TocPath)
    if ($DryRun) {
        Write-Host "[dry-run] Would patch tokens in: $TocPath"
        return
    }
    $content = Get-Content $TocPath -Raw -Encoding UTF8
    $content = $content -replace '@project-version@', $Version
    $content = $content -replace '@build-date@',      $BuildDate
    [System.IO.File]::WriteAllText($TocPath, $content, [System.Text.Encoding]::UTF8)
    Write-Host "Patched tokens in: $TocPath"
}

# Fetch Inter font from GitHub Release if not present (CI downloads from rsms/inter v4.0)
$MediaDir    = Join-Path $CraftSrc "media"
$FontRegular = Join-Path $MediaDir "Inter-Regular.ttf"
$FontBold    = Join-Path $MediaDir "Inter-Bold.ttf"
if (-not (Test-Path $FontRegular) -or -not (Test-Path $FontBold)) {
    if ($DryRun) {
        Write-Host "[dry-run] Would download Inter font to $MediaDir"
    } else {
        Write-Host "Downloading Inter font v4.0 (SIL OFL 1.1)..."
        $ZipPath     = Join-Path $env:TEMP "inter-v4.zip"
        $ExtractPath = Join-Path $env:TEMP "inter-v4-extract"
        New-Item $MediaDir -ItemType Directory -Force | Out-Null
        Invoke-WebRequest -Uri "https://github.com/rsms/inter/releases/download/v4.0/Inter-4.0.zip" `
            -OutFile $ZipPath -UseBasicParsing
        if (Test-Path $ExtractPath) { Remove-Item $ExtractPath -Recurse -Force }
        Expand-Archive $ZipPath -DestinationPath $ExtractPath -Force
        $regular = Get-ChildItem $ExtractPath -Recurse -Filter "Inter-Regular.ttf" | Select-Object -First 1
        $bold    = Get-ChildItem $ExtractPath -Recurse -Filter "Inter-Bold.ttf"    | Select-Object -First 1
        if (-not $regular) { Write-Error "Inter-Regular.ttf not found in archive"; exit 1 }
        if (-not $bold)    { Write-Error "Inter-Bold.ttf not found in archive";    exit 1 }
        Copy-Item $regular.FullName $FontRegular -Force
        Copy-Item $bold.FullName    $FontBold    -Force
        Remove-Item $ZipPath     -Force
        Remove-Item $ExtractPath -Recurse -Force
        Write-Host "Downloaded Inter font -> $MediaDir"
    }
}

# Generate icon atlas if not present (CI runs export-icons.py; locally needs pycairo + svg.path)
$Atlas16 = Join-Path $MediaDir "lucide-16.tga"
$Atlas24 = Join-Path $MediaDir "lucide-24.tga"
if (-not (Test-Path $Atlas16) -or -not (Test-Path $Atlas24)) {
    if ($DryRun) {
        Write-Host "[dry-run] Would generate icon atlas"
    } else {
        Write-Host "Generating Lucide icon atlas..."
        $env:PYTHONIOENCODING = "utf-8"
        $result = python (Join-Path $PSScriptRoot "export-icons.py") 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Generated icon atlas -> $MediaDir"
        } else {
            Write-Warning "Icon atlas generation failed. Run: pip install pycairo svg.path"
            Write-Warning $result | Select-Object -Last 3
        }
    }
}

# Fetch LibStub from GitHub if not present locally (CI gets it via .pkgmeta externals)
$LibStubLocal = Join-Path $CraftSrc "libs\LibStub\LibStub.lua"
if (-not (Test-Path $LibStubLocal)) {
    if ($DryRun) {
        Write-Host "[dry-run] Would download LibStub.lua to $LibStubLocal"
    } else {
        Write-Host "Downloading LibStub (not in repo - CI external)..."
        $LibStubUrl = "https://repos.wowace.com/wow/libstub/trunk/LibStub.lua"
        New-Item (Split-Path $LibStubLocal) -ItemType Directory -Force | Out-Null
        Invoke-WebRequest -Uri $LibStubUrl -OutFile $LibStubLocal -UseBasicParsing
        Write-Host "Downloaded LibStub -> $LibStubLocal"
    }
}

# Validate source paths
if (-not (Test-Path $CraftSrc))   { Write-Error "Craft/ not found at $CraftSrc"; exit 1 }
if (-not (Test-Path $BrowserSrc)) { Write-Error "Craft_Browser/ not found at $BrowserSrc"; exit 1 }
if (-not (Test-Path $WoWAddOns))  { Write-Error "WoW AddOns folder not found at $WoWAddOns"; exit 1 }

Write-Host ""
Write-Host "=== Craft local deploy ==="
Write-Host "Version  : $Version"
Write-Host "BuildDate: $BuildDate"
Write-Host "Target   : $WoWAddOns"
if ($DryRun) { Write-Host "(dry-run - no changes will be made)" }
Write-Host ""

# 1. Deploy standalone Craft library
$CraftDest = Join-Path $WoWAddOns "Craft"
Copy-Addon $CraftSrc $CraftDest
if (-not $DryRun) { Set-TocTokens (Join-Path $CraftDest "Craft.toc") }

# 2. Build and deploy Craft_Browser with Craft embedded
$BrowserDest = Join-Path $WoWAddOns "Craft_Browser"

if ($DryRun) {
    Write-Host "[dry-run] Would build Craft_Browser at: $BrowserDest"
    Write-Host "[dry-run]   libs/LibStub/ <- Craft/libs/LibStub/"
    Write-Host "[dry-run]   libs/Craft/   <- Craft/ (without libs/)"
    Write-Host "[dry-run]   *             <- Craft_Browser/*"
} else {
    if (Test-Path $BrowserDest) { Remove-Item $BrowserDest -Recurse -Force }
    New-Item $BrowserDest -ItemType Directory | Out-Null

    # Copy Craft_Browser source files
    Get-ChildItem $BrowserSrc | ForEach-Object {
        Copy-Item $_.FullName (Join-Path $BrowserDest $_.Name) -Recurse -Force
    }

    # Embed LibStub
    $LibStubSrc  = Join-Path $CraftSrc "libs\LibStub"
    $LibStubDest = Join-Path $BrowserDest "libs\LibStub"
    if (Test-Path $LibStubSrc) {
        New-Item (Split-Path $LibStubDest) -ItemType Directory -Force | Out-Null
        Copy-Item $LibStubSrc $LibStubDest -Recurse -Force
        Write-Host "Embedded: LibStub -> libs/LibStub/"
    } else {
        Write-Error "LibStub not found at $LibStubSrc - deploy aborted"
        exit 1
    }

    # Embed Craft (without its own libs/ subfolder to avoid duplication)
    $EmbeddedCraftDest = Join-Path $BrowserDest "libs\Craft"
    New-Item $EmbeddedCraftDest -ItemType Directory -Force | Out-Null
    Get-ChildItem $CraftSrc | Where-Object { $_.Name -ne "libs" } | ForEach-Object {
        Copy-Item $_.FullName (Join-Path $EmbeddedCraftDest $_.Name) -Recurse -Force
    }
    Write-Host "Embedded: Craft -> libs/Craft/"

    Set-TocTokens (Join-Path $BrowserDest "Craft_Browser.toc")
    Write-Host "Copied: $BrowserSrc -> $BrowserDest"
}

Write-Host ""
Write-Host "Done. Reload WoW UI with /reload to pick up changes."
