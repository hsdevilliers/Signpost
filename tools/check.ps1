<#
.SYNOPSIS
Runs every check CI runs, locally: busted, luacheck, StyLua, the repository guards and the Python tool tests.
Works in the main checkout and in git worktrees: .venv and tools/bin are gitignored, so a worktree uses the main
checkout's toolchain. Setup is described in README "Development". Exits non-zero when any check fails.
#>
$ErrorActionPreference = 'Continue'
$repo = Split-Path $PSScriptRoot -Parent
Set-Location $repo

$toolRoot = $repo
if (-not (Test-Path "$toolRoot\.venv\lua51\bin\busted.bat")) {
    $common = git rev-parse --path-format=absolute --git-common-dir 2>$null
    if ($common) { $toolRoot = Split-Path $common -Parent }
}
$busted = "$toolRoot\.venv\lua51\bin\busted.bat"
$luacheck = "$toolRoot\.venv\lua51\bin\luacheck.bat"
$stylua = "$toolRoot\tools\bin\stylua.exe"
foreach ($tool in $busted, $luacheck, $stylua) {
    if (-not (Test-Path $tool)) {
        Write-Output "missing $tool (see README 'Development')"
        exit 1
    }
}

$checks = @(
    @{ Name = 'busted';     Run = { & $busted } },
    @{ Name = 'luacheck';   Run = { & $luacheck . --quiet } },
    @{ Name = 'stylua';     Run = { & $stylua --check . } },
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
