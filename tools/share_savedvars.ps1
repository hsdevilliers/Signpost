<#
.SYNOPSIS
Copies what Signpost recorded (the account-wide SavedVariables file Signpost.lua) into a folder you share, so it can be
merged into the guide data. Nothing is sent anywhere by this script or by the addon.

.DESCRIPTION
Run it after you have logged out of the game (the game writes the file on logout or /reload). It looks for the file in
every game folder (_retail_, _classic_, _classic_beta_ ...) under your World of Warcraft install and copies each one
into -Dest\<id>\Signpost-<game folder>-<date time>.lua, where <id> is a short code that stays the same for you and
says nothing about you (a hash of the computer and account folder names), so the maintainers can tell contributors
apart. The per-character file (SignpostCharDB, whose path holds the character's name and realm) is not copied.
Older copies are never overwritten.

Normally started through share_savedvars.cmd, which reads the destination from destination.txt next to it.

.PARAMETER Dest
The shared folder to copy into. Must exist.

.PARAMETER WowRoot
The World of Warcraft folder, if it is not in a usual place.
#>
param(
    [Parameter(Mandatory = $true)][string]$Dest,
    [string]$WowRoot
)
$ErrorActionPreference = 'Stop'

function Find-WowRoot {
    $candidates = @(
        "${env:ProgramFiles(x86)}\World of Warcraft",
        "$env:ProgramFiles\World of Warcraft",
        "C:\Games\World of Warcraft",
        "D:\Games\World of Warcraft",
        "D:\World of Warcraft"
    )
    return $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
}

if (-not (Test-Path -LiteralPath $Dest -PathType Container)) {
    Write-Output "The destination folder does not exist: $Dest"
    exit 1
}
if (-not $WowRoot) { $WowRoot = Find-WowRoot }
if (-not $WowRoot -or -not (Test-Path -LiteralPath $WowRoot)) {
    Write-Output 'Could not find World of Warcraft. Run again with -WowRoot "<your World of Warcraft folder>".'
    exit 1
}

if (Get-Process -Name 'Wow*' -ErrorAction SilentlyContinue) {
    Write-Output 'The game is still running. Log out (or close it) first so the latest data is written, then run this again.'
    exit 1
}

$files = @(Get-ChildItem -Path (Join-Path $WowRoot '_*\WTF\Account\*\SavedVariables\Signpost.lua') -File -ErrorAction SilentlyContinue)
if ($files.Count -eq 0) {
    Write-Output "No Signpost.lua found under $WowRoot. Log in with Signpost installed, then log out, and run this again."
    exit 1
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$copied = 0

# A short stable code per computer and account folder; it is not reversible.
function Get-ContributorId([string]$account) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes("$env:COMPUTERNAME|$account")
    return (($sha.ComputeHash($bytes) | Select-Object -First 4 | ForEach-Object { $_.ToString('x2') }) -join '')
}

foreach ($file in $files | Sort-Object FullName) {
    # ...\_classic_beta_\WTF\Account\<account>\SavedVariables\Signpost.lua: the game folder is five levels up
    $flavor = $file.Directory.Parent.Parent.Parent.Parent.Name.Trim('_')
    $account = $file.Directory.Parent.Name
    $folder = Join-Path $Dest (Get-ContributorId $account)
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
    $target = Join-Path $folder ("Signpost-{0}-{1}.lua" -f $flavor, $stamp)
    Copy-Item -LiteralPath $file.FullName -Destination $target -ErrorAction Stop
    Write-Output ("Copied {0} ({1:N0} KB) as {2}" -f $flavor, ($file.Length / 1KB), (Split-Path $target -Leaf))
    $copied++
}
Write-Output "Done: $copied file(s) copied to $Dest. Thank you!"
exit 0
