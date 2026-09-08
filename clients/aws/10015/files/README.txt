OpenRSC
=======

Double-click:

    Play-OpenRSC.cmd

That is the whole thing. It brings the folder up to date, checks it can reach
the world, and starts the game.

It needs Java 8 on this machine and nothing else. If Java is missing,
the launcher says so, and where to get it.

The world
---------

    15.134.172.152:43594

This copy is locked to it. There is nothing to set up and nothing to point
anywhere - if the address ever changes, the next launch brings the new one
down with it.

It keeps itself up to date
--------------------------

Every launch, before the game starts, this folder checks for a new build and
installs only what changed - usually a second or two. You do not download the
client again.

If a login is ever refused saying the client is out of date, close the game and
run Play-OpenRSC.cmd again. The update happens before the client starts, so the
second run gets you in.

An update never touches what is yours: your controller bindings, your saved
login, your window size and this machine's identity all stay as they are. If
the update server cannot be reached, it says so and starts the game you have.

If it will not connect
----------------------

The launcher tells you what it found before the game starts. If it could not
reach the world:

  * Check your own internet first. A browser will tell you in a second.
  * The world is probably off or restarting. Wait a few minutes and run
    Play-OpenRSC.cmd again.
  * If it keeps failing, tell whoever runs the server. Nothing on your side
    needs fixing.

The window
----------

It opens at 3x - 1536x1038 - scaled in whole pixels so the art stays sharp.

If that is bigger than your screen, open the Settings tab, choose General, and
click [ - ] beside Scaling until it fits. It is remembered from then on. [ + ]
goes the other way, as far as your display allows.

Playing
-------

Make an account on the login screen and that is you, permanently - it lives on
the server, not in this folder, so it survives a reinstall.

One rule of the world catches everybody out. The AI in the wilderness are
combat level 24, and RuneScape Classic only lets two people fight when the
difference in their combat levels is no more than the wilderness level they are
both standing on. The AI post up at wilderness 1-4, so a character outside
about combat 20-28 will neither attack them nor be attacked. That is the game's
own rule, not a fault: they are not broken, you are out of range.


Controller
----------

An Xbox controller is picked up automatically when one is plugged in. With
none attached the client behaves exactly as it did before, so this folder is
usable either way.

    Left stick        walk
    Right stick       camera
    LB / RB           cycle target
    A                 act        Y  options       B  back, or hold to retreat
    Select            open the bag; press again to close anything back to the
                      game
    Start             teleports
    X                 accept a trade or duel; in a fight, change combat style
    D-pad             in the world, your four quick slots
                      in a panel, move around the grid

The triggers do two jobs, decided by whether a panel is open:

    LT / RT   panel open   page along the tab bar
              in the world switch which list LB and RB are cycling, between
                           People, Items and Objects

That last one is worth knowing about, because without it a cabbage on the
ground is unreachable while anybody is standing near you. Objects are doors,
ladders, levers, rocks and the like. Items of the same kind collapse into one
entry, so a cabbage patch is a single stop meaning the nearest cabbage.

The hints across the top of the screen say what the buttons do wherever you
are, including which spell you have armed and which list you are cycling.

Quick slots are empty until you put something in one. The easy way is in the
game: Select to open the bag, LT until you reach the magic tab, LB or RB to
turn between spells and prayers, then put the highlight on what you want and
press X. Pick an arm of the D-pad, press A, and it is bound - and saved, so it
is still there tomorrow. You can also write them into pad.conf by hand:

    quick.up = Superhuman strength
    quick.left = Wind strike

A prayer toggles. A spell is cast at whatever you have targeted, in that one
press, and in a fight that is whoever you are fighting. Anything the game would
refuse it still refuses, in its own words.

In a fight, X steps through the four combat styles and the strip along the top
says which one you are on. Outside a fight the styles are a list on Y in the
magic tab, and X goes back to accepting trades and duels.

Rebinding, deadzones and autocast are all in pad.conf, next to this file. It
is commented; every setting says what it is for.

If the controller does nothing, run Check-Controller.cmd. It starts the game
with an overlay drawn from what the driver actually returns, which separates
"the pad is not being read" from "the game is ignoring it" - two things that
look identical from the outside.

One thing the controller still cannot do, so you are not left guessing:

  * The bank's type-an-amount prompt needs the keyboard. The 1 / 5 / 10 / All
    chooser on Y covers most of what it was for.

If you ever need a fresh copy
-----------------------------

    https://austinlanecarneyai-ui.github.io/orsc-client/

Build 10015.
