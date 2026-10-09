@echo off
:# OpenRSC client for the local DEV server (localhost:43599).
:#
:# Same jar as Play-OpenRSC.cmd, which plays PROD (localhost:43594). This one
:# works in C:\ORSC\client_dev\ so the two never overwrite each other's server
:# address, and sets the controller's clock to dev's tick every launch.
:# mod\tools\dev-client.py does the work; `dev-client.py stage` plays stage.
:#
:# Dev is not always running. Start it first: mod\tools\Rscx.cmd run dev
title OpenRSC Client - DEV

python "C:\ORSC\mod\tools\dev-client.py" %*
if errorlevel 1 pause
