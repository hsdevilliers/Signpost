@echo off
rem Double-click after logging out of the game: copies Signpost's recorded data into the shared folder named in
rem destination.txt (one line: the folder's path), or given as the first argument. See share_savedvars.ps1.
setlocal
set "DEST=%~1"
if "%DEST%"=="" if exist "%~dp0destination.txt" set /p DEST=<"%~dp0destination.txt"
if "%DEST%"=="" (
    echo No destination folder. Put the shared folder's path on one line in destination.txt next to this file,
    echo or run:  share_savedvars.cmd "C:\path\to\shared folder"
    pause
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0share_savedvars.ps1" -Dest "%DEST%"
pause
