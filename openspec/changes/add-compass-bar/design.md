## Context

The HUD already uses the top of the screen. The time readout is at the top left
("NIGHT 03:12 · 64×"), the goal bar at the top right, the build-mode label at the top
centre (y 24) and the "INVENTORY FULL" notice at the top centre (y 96). Bearings are already
a convention in the code: `MoonPath` and `MountainRings` measure 0° north (−Z), 90°
east (+X), with the sun rising at +X and crossing south (+Z). The player spawns at the
origin with no rotation, facing −Z (north). stubby-music had no compass, so there's
nothing to port. The look follows Satisfactory (user: "default to Satisfactory when
uncertain").

## Goals / Non-Goals

**Goals:** a Satisfactory-style heading bar; spawn facing east; no overlap with
existing HUD; heading from the camera, so it keeps working when the camera is an XR
headset.

**Non-Goals:** markers (sites, machines, beacons, the burbler) and distance readouts,
which come with the change that first needs them; a minimap or map screen; degree
numbers (Satisfactory shows none).

## Decisions

**D1. Our own `Control` with `_draw`, not an addon.**
- *Rejected: vi4hu/godot_compass (MIT; Compass3D, Compass2D, CompassBar).* Its bar
  documents no markers and no styling beyond a north offset, and it lerps the heading
  (default 0.1 per frame), so the bar trails the view. Satisfactory's doesn't. We'd
  vendor an addon and still restyle it, for about 100 lines of drawing.
- *Rejected: poplava's "nibble compass" (itch.io).* The free tier is MIT, but markers are
  only in the paid tier, and it's distributed outside git.
- *Rejected: a scrolling texture strip.* Letters and ticks would be baked into an
  image, so they couldn't follow the HUD font or theme, and markers would need drawing
  anyway.

**D2. Heading from the active camera.** bearing = atan2(f.x, −f.z) of the camera's
forward, projected to the ground. In VR the camera is the headset, so this keeps
working. Each item (letter, tick) is drawn at x = centre + Δ·(width / span), where
Δ is its bearing minus the heading, wrapped to ±180°. Items beyond ±span/2 aren't
drawn. Alpha falls off over the outer quarter, so the ends fade the way
Satisfactory's do.

**D3. Size and placement.** 320 px wide, showing 180° (about 1.8 px per degree), at
the top centre (y 12–44). It sits between the time readout and the goal bar at 1280 px
wide. Ticks every 15°, letters on the cardinals, smaller intercardinals, a caret at the
centre. Colours are the HUD's text colour (`#f2f0e6`) with a dark outline, and the
caret is amber, the signal colour. The build-mode label moves from y 24 to y 56.

**D4. Visibility.** The bar is a `CanvasLayer` like `GoalBar`. It hides while the player's
controls are taken (`controls_enabled == false`) and shows in build mode, where
heading matters most.

**D5. The opening faces east: rotate the world, not the player alone.** The user asked
for "the original scene to be facing east, so maybe rotate everything if needed". The
composition (burbler ahead at 35 m, oaks either side, the moon up and to the left) is
kept, and its direction becomes east. The world content groups get yaw −90°, which maps
−Z to +X: `ScrubOaks`, `LightningBugs`, `Reeds`, `MountainRings`, the burbler (its
transform pre-multiplied), and the Player. The flat ground planes are rotation-symmetric.
Seeds are by instance id, not position, so every seeded thing comes out the same.
- *Rejected: turn only the player.* The opening view would have been empty mudflat,
  with the burbler and moon behind.
- *Rejected: rotate the sky instead (sun rising at −Z).* Sky3D computes the sun, moon
  and stars in world space from latitude and time. Turning it would put a non-standard
  rotation into the addon's frame and break the "+X east" convention that `MoonPath`,
  `MountainRings` and now the compass share.
- The moon keeps its place in the view: 30° left of the spawn view is now bearing 60°
  (was 330°), still 20° up. That needs a declination near 35°, so it's no longer
  circumpolar. It climbs from the north-east and is near the zenith at dawn (86° up at
  06:18), still in the sky as the sun rises ahead.

## Risks / Trade-offs

- [At narrow window widths the bar can touch the goal bar] → the bar's width is a
  constant, easy to shrink. At 1280 px there's a 20 px gap.
- [Placements no longer match stubby-music's `scene.bsn` coordinates] → they're that
  layout turned −90°. CLAUDE.md says so, so a future port from the archive applies the
  same turn.
