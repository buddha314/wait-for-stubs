## Why

The mudflat is wide, flat and dark, and the player has nothing to steer by: no
landmark reads at night, and the mountains are ridges without names. Satisfactory puts a
compass bar across the top of the screen. It's on our backlog (user, 2026-11-13: "a
compass bar across the top of the screen, as in Satisfactory, to help navigation"), and
the user asked for it now. They also asked for the opening to face east, so the first
thing the player can watch is the sun coming up over the ridges. That's about
7.5 minutes in, since the game starts at solar midnight.

## What Changes

- A **compass bar** at the top centre of the screen, as in Satisfactory. Cardinal
  letters N, E, S and W, smaller intercardinals (NE, SE, SW, NW) and tick marks scroll
  as the view turns, and a centre caret marks the heading. Bearings follow the game's
  existing convention: 0° north (−Z), 90° east (+X, where the sun rises).
- It fades out towards its ends. It hides while a screen (rack, inventory) has the
  controls, like the goal bar, and stays visible in build mode.
- The build-mode label moves down so it no longer shares the top centre with the bar.
- **The opening view faces east** (bearing 90°), toward the sunrise. The user wants
  the original scene itself to face east, not the player turned away from it. So the
  world content (burbler, bugs, reed beds, scrub oaks, mountain rings) rotates −90°
  about the vertical. What lay ahead along −Z now lies ahead along +X, and the player
  spawns facing +X. The sky doesn't turn: the sun still rises at +X, now dead ahead.
- The moon keeps its place in the view (30° left of it, 20° up), so its start bearing
  moves from 330° to 60°.
- **Not in this change:** markers on the bar (discovered sites, machines, beacons).
  The bar is built so markers can be added later, but nothing is placed on it yet.

## Capabilities

### New Capabilities
- `compass-bar`: the heading bar, its bearings, its look and when it shows; the spawn
  heading.

### Modified Capabilities
- `sky-motion`: "The moon travels with the stars" defaults to bearing 60° (was 330°),
  still 20° up and 30° left of the opening view.

## Impact

- New `scenes/compass_bar/` (`compass_bar.tscn` + `.gd`), instanced in `main.tscn`.
- `scenes/main/main.tscn`: yaw −90° on the Player, `ScrubOaks`, `LightningBugs`,
  `Reeds` and `MountainRings`; the burbler's transform rotated the same way. The
  ground planes are symmetric and stay. Reed bed nodes `ReedBedWest`/`East` are renamed
  `ReedBedNorth`/`South` to match where they now lie. Their `bed_id`s, which seed
  them, are unchanged.
- `scenes/hud/hud.gd`: the build-mode label moves below the bar.
- `scenes/sky/moon_path.gd` (default bearing 60°), `tests/test_sky.gd`; CLAUDE.md.
- A test in `tests/`.
- **Existing tools used:** Godot `Control._draw` (`draw_line`, `draw_string`) and the
  project font, the active `Camera3D`'s basis for the heading, and the player's
  `controls_enabled`. **Written from scratch:** the bar itself, about 100 lines. The one
  addon found (vi4hu/godot_compass, MIT) was rejected; see design.md.
