@echo off
:# The real OpenRSC launcher. Play-OpenRSC.cmd in the folder above calls this
:# after the updater has run, so by the time we get here the folder is current.
:#
:# Pre-flights the connection before starting the client, because a client that
:# opens on a blank login screen has not told you whether the network, the
:# firewall or the server is the problem.
title OpenRSC

:# One level up from update\, which is where this file lives. Everything below
:# is relative to the folder, so it works from any drive or folder name.
cd /d "%~dp0.."

set "HOST="
set "PORT="
if exist "Cache\ip.txt"   set /p HOST=<"Cache\ip.txt"
if exist "Cache\port.txt" set /p PORT=<"Cache\port.txt"
if "%HOST%"=="" (
  :# This copy is locked to one world, so a missing address is repaired rather
  :# than reported. The updater writes the same two files from the manifest;
  :# this is the offline path, and the value is built in at 2026-09-12.
  if not exist "Cache" mkdir "Cache"
  >"Cache\ip.txt"   echo 15.134.172.152
  >"Cache\port.txt" echo 43594
  set "HOST=15.134.172.152"
  set "PORT=43594"
  echo  Restored the server address: 15.134.172.152:43594
)

echo  OpenRSC
echo  Server: %HOST%:%PORT%
echo.
echo  Checking the connection...

powershell -NoProfile -Command "$c=New-Object Net.Sockets.TcpClient; try { $r=$c.BeginConnect('%HOST%',%PORT%,$null,$null); if(-not $r.AsyncWaitHandle.WaitOne(3000)){ Write-Host '  UNREACHABLE - no answer within 3 seconds.'; Write-Host '  The host may be off or on another network, or a firewall is dropping it.'; exit 2 }; $c.EndConnect($r); Write-Host '  OK - the server answered.'; exit 0 } catch { Write-Host ('  FAILED - ' + $_.Exception.InnerException.Message); exit 3 } finally { $c.Close() }"
set "PROBE=%ERRORLEVEL%"

if not "%PROBE%"=="0" (
  echo.
  echo  Nothing on your side needs changing - this copy is locked to the world
  echo  and the address is correct.
  echo.
  echo    1. Check your own internet. A browser will tell you in a second.
  echo    2. The world is probably off or restarting. Wait a few minutes and
  echo       run Play-OpenRSC.cmd again.
  echo    3. If it keeps failing, tell whoever runs the server.
  echo.
  :# A probe is not the game, and it can be wrong. It warns; it does not decide.
  choice /C YN /N /M "  Start the client anyway? [Y/N] "
  if errorlevel 2 exit /b %PROBE%
)

:# The bundled runtime if this build has one, otherwise whatever is on PATH.
:# Checked BEFORE launching, so "no Java on this machine" is a sentence rather
:# than a 9009 exit code the person has to interpret.
set "JAVA=%~dp0jre\bin\java.exe"
if not exist "%JAVA%" (
  where java >nul 2>&1
  if errorlevel 1 (
    echo.
    echo  No Java found. The game needs Java 8 and this machine does not have
    echo  it on its PATH.
    echo.
    echo  Install it from either of these, then run Play-OpenRSC.cmd again:
    echo    https://adoptium.net/temurin/releases/?version=8
    echo    https://www.azul.com/downloads/?version=java-8-lts^&package=jre
    echo.
    pause
    exit /b 9009
  )
  set "JAVA=java"
)

echo.
echo  Starting...

"%JAVA%" -Xms312m -Dsun.java2d.opengl=true -cp "Open_RSC_Client.jar;discord-rpc.jar" orsc.OpenRSC
set "RC=%ERRORLEVEL%"

if not "%RC%"=="0" (
  echo.
  echo  The client exited with code %RC%.
  echo  If it never drew a window, the server was probably not reachable after
  echo  all - re-run and read the connection check above.
  echo.
  pause
)
exit /b %RC%
