# LHA — Logan's Hunter Addon

Hunter quality-of-life features for **WoW Forever** (Interface `16001`).

## Modules

### Too-close alert

A red **!!** appears above your character when your target is too close to shoot, either in melee range or in the deadzone just outside it. This covers the whole gap where Auto Shot won't fire.

- It only checks while you have an attackable target.
- An optional sound plays when it appears (off by default).
- It can be moved and resized.

### Growl warning

A **"Growl is ON"** banner shows while you're in a dungeon or raid and your pet has Growl on autocast, so you don't steal threat from the tank.

- It works solo or grouped, and updates instantly, including in combat.
- A warning sound plays when it appears.
- It's display-only. You turn Growl off yourself.

### Pet loyalty

A record of your history with each pet. Open it with `/lha pet` or by left-clicking the minimap button.

**The pet card** shows:
- the pet's model, name, family, level and loyalty (e.g. *Best Friend*)
- **Met at**: the level and place you tamed it, plus the original beast's name. Pets you had before installing LHA say *"Together since before LHA"*.
- **Time together** (and time in combat), **battles together**, and **bosses**, **rares** and **world bosses** defeated together
- **Memories**: a dated log of moments like first boss kills, rares and milestones
- every pet you own, including stabled pets that haven't been summoned yet. Abandoned pets are kept and shown as *retired*.

**Milestones** are celebrated with a chat message, a center-screen flash and a sound:
- 100 / 500 / 1,000 / 2,500 / 5,000 battles, then every 5,000
- 10 / 25 / 50 / 100 / 250 / 500 hours together
- the first kill of each boss, rare and world boss together
- taming a new pet

You can also announce milestones to **party/raid** and/or **guild** chat, e.g.
*"[LHA] Ryn and I defeated Taragaman the Hungerer together for the first time!"* Both are off by default.

## Commands

| Command | Action |
|---|---|
| `/lha` | Open settings |
| `/lha pet` | Open/close the pet card |
| `/lha retire <name>` | Mark a pet as retired (for pets abandoned while LHA wasn't running) |
| `/lha minimap` | Show/hide the minimap button |
| `/lha unlock` / `/lha lock` | Unlock frames to drag them / lock them again |
| `/lha test` | Show all alerts for 10 seconds, for positioning |
| `/lha reset` | Reset frame positions |

## Settings

Open them with `/lha`, by right-clicking the minimap button, or from **Options → AddOns → LHA**. Each module can be turned on or off, and sounds, milestone announcements and the minimap button are configurable.

Settings and pet history are saved **per character**.

## Credits

Bundled libraries, each under its own license:
- [LibStub](https://www.wowace.com/projects/libstub)
- [CallbackHandler-1.0](https://www.wowace.com/projects/callbackhandler)
- [LibDataBroker-1.1](https://github.com/tekkub/libdatabroker-1-1)
- [LibDBIcon-1.0](https://www.wowace.com/projects/libdbicon-1-0)
