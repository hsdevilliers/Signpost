<#
.SYNOPSIS
Runs every check CI runs, locally: busted, luacheck, StyLua, the repository guards and the Python tool tests.
Setup is described in README "Development". Exits non-zero when any check fails.
#>
$ErrorActionPreference = 'Continue'
$repo = Split-Path $PSScriptRoot -Parent
Set-Location $repo

$checks = @(
    @{ Name = 'busted';     Run = { & "$repo\.venv\lua51\bin\busted.bat" } },
    @{ Name = 'luacheck';   Run = { & "$repo\.venv\lua51\bin\luacheck.bat" . --quiet } },
    @{ Name = 'stylua';     Run = { & "$repo\tools\bin\stylua.exe" --check . } },
    @{ Name = 'check_repo'; Run = { python "$repo\tools\check_repo.py" } },
    @{ Name = 'tool tests'; Run = { python -m unittest discover -s "$repo\tools\tests" -t "$repo\tools" } }
)

$failed = @()
foreach ($check in $checks) {
    Write-Output "== $($check.Name)"
    & $check.Run
    if ($LASTEXITCODE -ne 0) { $failed += $check.Name }
}
if ($failed.Count -gt 0) {
    Write-Output "FAILED: $($failed -join ', ')"
    exit 1
}
Write-Output 'All checks passed.'
