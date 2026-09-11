OpenRSC - LAN, controller
=========================

Copy this whole folder to any Windows machine on the same network,
then double-click:

    Play-OpenRSC.cmd

It checks it can reach the server first and tells you what it finds. If the
check fails it still offers to start the client, because the check is not the
game and can be wrong.

Nothing needs installing. NOTE: this build has no bundled Java. The machine needs Java 8 on its PATH.

Server
------

    192.168.1.98:43594

To point this copy at a different machine or port, run Set-Server.cmd. It
rewrites Cache\ip.txt and Cache\port.txt, which is where the client reads the
address from.

If it will not connect
----------------------

Two things account for almost every failure:

1.  The server is not running. On the server machine (192.168.1.98), that is
    Start-Server.cmd in C:\ORSC. It is up when TCP 43594 is listening.

2.  The server machine's firewall is blocking inbound TCP 43594.
    The LAN adapter is on the Private firewall profile and that
    profile is OFF, so inbound 43594 is not blocked. If it is ever
    turned back on, this needs an allow rule.

A third, rarer one: the server's address changed. It is set manually on that
machine, so it should not, but Set-Server.cmd is how you fix it if it does.

The window
----------

It opens at 3x - 1536x1038 - scaled in whole pixels so the art stays sharp.

If that is bigger than your screen, open the Settings tab, choose General, and
click [ - ] beside Scaling until it fits. It is remembered from then on. [ + ]
goes the other way, as far as your display allows.

Playing
-------

Log in with an account that exists on that server. If you are testing PvP
against the AI in the wilderness, your character has to be combat level 20-28 -
every AI is level 24, and RuneScape Classic only lets you fight someone within
`min(your wilderness level, theirs)` combat levels of you. A high-level
character will neither attack them nor be attacked, which looks exactly like a
broken connection and is not one.


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

Built 2026-09-11 from C:\ORSC by mod\tools\build-lan-client.py.
