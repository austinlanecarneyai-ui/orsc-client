@echo off
:# Is the controller being seen? Run this before deciding the game is at fault.
:#
:# The overlay this turns on is drawn from what the driver actually returns:
:# both sticks as vectors, both triggers as bars, the buttons held, and the
:# name of the source feeding them. If it says "no pad" while a controller is
:# plugged in, the problem is the driver or the cable, not the game.
title OpenRSC - controller check
cd /d "%~dp0"

set "JAVA=jre\bin\java.exe"
if not exist "%JAVA%" set "JAVA=java"

echo.
echo  Starting with the controller overlay on.
echo  Look for a panel over the game showing sticks, triggers and buttons.
echo.
echo  Also printed once at startup:
echo    "input from XInput (xinput1_4, pad 0)"  - the controller is being read
echo    "input from XInput (xinput1_4, no pad)" - nothing is plugged in
echo.

"%JAVA%" -Xms312m -Dsun.java2d.opengl=true -Dpad.debug=1 -cp "Open_RSC_Client.jar;discord-rpc.jar" orsc.OpenRSC
echo.
pause
