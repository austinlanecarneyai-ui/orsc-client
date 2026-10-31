@echo off
:# The FINAL update\Launch.cmd of a client_aws folder (launcher phase 5, LCH-047).
:#
:# publish-client.py --channel aws --retire publishes this in place of the real
:# Launch.cmd, beside retired.txt. The updater stages it as .new, so it takes
:# over from the launch AFTER the final update; on that first launch the new
:# jar (client patch 112) shows the same notice. From then on this says where
:# the launcher is, opens the page, and never starts the game.
title RS Classic Continuum
cd /d "%~dp0.."

set "URL="
if exist "retired.txt" set /p URL=<"retired.txt"

:# Where this folder is, for the launcher's "copy your controller settings" offer (LCH-048).
if not "%LOCALAPPDATA%"=="" >"%LOCALAPPDATA%\RSCX-old-client.txt" echo %CD%

echo.
echo  This game folder no longer updates.
echo  RS Classic Continuum has a launcher now. It keeps the game up to date.
echo.
if "%URL%"=="" (
  echo  Ask whoever runs the server for the download link.
) else (
  echo  Get it from:
  echo    %URL%
  start "" "%URL%"
)
echo.
echo  Your controller settings come with you.
echo.
pause
exit /b 0
