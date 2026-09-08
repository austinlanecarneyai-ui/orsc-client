@echo off
:# Repoint this client at a different server, without editing any file by hand.
title OpenRSC - LAN, controller - set server

cd /d "%~dp0"

set "HOST=%~1"
set "PORT=%~2"

if "%HOST%"=="" (
  set /p "HOST=Server address (name or IP): "
)
if "%PORT%"=="" (
  set "PORT=43594"
  set /p "PORT=Port [43594]: "
)
if "%PORT%"=="" set "PORT=43594"

if not exist "Cache" mkdir "Cache"
:# The client reads these two files at connect time - Cache\ip.txt and
:# Cache\port.txt, via ClientPort.loadIP/loadPort. They ARE the setting.
>"Cache\ip.txt" echo %HOST%
>"Cache\port.txt" echo %PORT%

echo.
echo  Server set to %HOST%:%PORT%
echo.
echo  Checking...
powershell -NoProfile -Command "$c=New-Object Net.Sockets.TcpClient; try { $r=$c.BeginConnect('%HOST%',%PORT%,$null,$null); if(-not $r.AsyncWaitHandle.WaitOne(3000)){ Write-Host '  UNREACHABLE - no answer within 3 seconds.'; exit 2 }; $c.EndConnect($r); Write-Host '  OK - the server answered.'; exit 0 } catch { Write-Host ('  FAILED - ' + $_.Exception.InnerException.Message); exit 3 } finally { $c.Close() }"

echo.
pause
