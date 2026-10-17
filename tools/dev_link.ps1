<#
.SYNOPSIS
Junction-links the Signpost and Signpost_Data repositories into the game's AddOns folder, using the paths in
tools/dev.local.json. The client only notices new addon folders when it starts.

.PARAMETER Unlink
Remove the two junctions instead. Only junctions or symlinks are ever removed; a real folder is never touched.

.EXAMPLE
pwsh -File tools/dev_link.ps1
#>
[CmdletBinding()]
param(
    [switch]$Unlink,
    [string]$Config = (Join-Path $PSScriptRoot 'dev.local.json')
)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Config)) {
    throw "$Config not found: copy tools/dev.local.example.json to it and fill in the paths."
}
$cfg = Get-Content -LiteralPath $Config -Raw | ConvertFrom-Json
$addOns = Join-Path (Join-Path $cfg.wowDir $cfg.flavorDir) 'Interface\AddOns'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$links = [ordered]@{
    'Signpost'      = $repo
    'Signpost_Data' = Join-Path (Split-Path $repo -Parent) 'Signpost_Data'
}

function Get-LinkTarget($item) {
    # Windows PowerShell 5.1 returns the target as an array, PowerShell 7 as a string.
    $target = @($item.Target)[0]
    if ($target) { return $target.TrimEnd('\') }
    return $null
}

function Remove-Link($path) {
    # rmdir removes the junction itself, never the folder it points to.
    cmd /c rmdir "$path" | Out-Null
    if (Test-Path -LiteralPath $path) { throw "Could not remove the link $path" }
}

if (-not $Unlink) {
    New-Item -ItemType Directory -Force -Path $addOns | Out-Null
}

foreach ($name in $links.Keys) {
    $link = Join-Path $addOns $name
    $target = $links[$name].TrimEnd('\')
    $item = Get-Item -LiteralPath $link -Force -ErrorAction SilentlyContinue
    if ($item) {
        if (-not $item.LinkType) {
            Write-Warning "$link is a real folder, not a link; leaving it alone. Move it out of AddOns and run this again."
            continue
        }
        if ($Unlink) {
            Remove-Link $link
            Write-Output "removed $link"
            continue
        }
        if ((Get-LinkTarget $item) -ieq $target) {
            Write-Output "ok      $link -> $target"
            continue
        }
        Remove-Link $link
    }
    elseif ($Unlink) {
        continue
    }
    if (-not (Test-Path -LiteralPath $target)) {
        Write-Warning "$target does not exist; skipping $name"
        continue
    }
    New-Item -ItemType Junction -Path $link -Target $target | Out-Null
    Write-Output "linked  $link -> $target"
}
