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
  echo Cache\ip.txt is missing or empty. Run Set-Server.cmd to set the server.
  echo.
  pause
  exit /b 1
)

echo  OpenRSC
echo  Server: %HOST%:%PORT%
echo.
echo  Checking the connection...

powershell -NoProfile -Command "$c=New-Object Net.Sockets.TcpClient; try { $r=$c.BeginConnect('%HOST%',%PORT%,$null,$null); if(-not $r.AsyncWaitHandle.WaitOne(3000)){ Write-Host '  UNREACHABLE - no answer within 3 seconds.'; Write-Host '  The host may be off or on another network, or a firewall is dropping it.'; exit 2 }; $c.EndConnect($r); Write-Host '  OK - the server answered.'; exit 0 } catch { Write-Host ('  FAILED - ' + $_.Exception.InnerException.Message); exit 3 } finally { $c.Close() }"
set "PROBE=%ERRORLEVEL%"

if not "%PROBE%"=="0" (
  echo.
  echo  Things to check, in order:
  echo    1. Is the server running on %HOST%?  Start-Server.cmd on that machine.
  echo    2. Is %HOST% still its address?      Run Set-Server.cmd here to change it.
  echo    3. Is a firewall blocking TCP %PORT% inbound on the server machine?
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
    echo  No Java found. This folder was built without a bundled runtime and
    echo  this machine has no java on its PATH.
    echo.
    echo  Either install Java 8, or rebuild the folder with the runtime
    echo  included - on the server machine, mod\tools\Build-Lan-Client.cmd
    echo  bundles it by default.
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
