# ORSC client

Game client downloads for a small private RuneScape Classic world, served by
GitHub Pages so the launcher can bring itself up to date.

**Players: you do not need this repository.** Go to
https://austinlanecarneyai-ui.github.io/orsc-client/ and follow the page.

## What is here

    clients/<channel>/latest.json                which version is current
    clients/<channel>/<version>/manifest.json    every file and its SHA-256
    clients/<channel>/<version>/files/...        the files themselves
    clients/<channel>/<version>/setup.zip        the one-time installer

`update/Update-Client.ps1`, inside the client folder, reads `latest.json`,
compares the SHA-256 of every local file against the manifest, and downloads
only what differs. It verifies all of them before it swaps any of them, so a
failed or corrupted update leaves the folder byte-identical and still playable.

## Source, and the licence

This client is a modification of **OpenRSC**, which is licensed under the **GNU
Affero General Public License v3**. The binaries published here are covered by
that licence, and anyone who receives them is entitled to the corresponding
source.

Upstream: https://github.com/Open-RSC/Core-Framework

If you have taken a client from here and want the source for the modifications,
open an issue on this repository and it will be provided.

## What is deliberately not here

No server code, no world data, and no player data of any kind. This repository
hands out a game client and nothing else.
