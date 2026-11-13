## Context

stubby-music's `setup()` (crates/stubby_game/src/lib.rs) builds three ridge rings at
radius 480 + 110·layer m, 192 segments each. Each segment is a quad from y = −3 m up
to a ridge height of 8 + 12·hash(i/4) + 10·hash(i) m, in slate (0.18, 0.17, 0.20),
rough, double-sided. A 1600 m plane of dark mud (0.19, 0.13, 0.085) sits at
y = −0.15 m. Its HDR sky was a generated gradient cubemap with no mountains in it;
here Sky3D draws the sky.

In this port, Sky3D runs REALISTIC celestial maths at latitude 37° on the equinox,
and `main.gd` writes `Calendar.solar_hour()` into it. Stars already rotate (deep
space coordinates), and clouds already drift (`process_tick`, `wind_speed` 1 m/s).
The moon has `compute_moon_coords = false` and is pinned at SkyDome azimuth −150°
and zenith angle 70°, which is compass bearing 330° (NNW), 20° up.

## Goals / Non-Goals

**Goals:** echoed, seeded mountain rings; an outer ground; a moon that travels; a
check that the sun, stars and clouds move with simulation time.

**Non-Goals:** weather (rain, dust storms, gusts), tuning Sky3D toward Bevy's
amber haze, Terrain3D terrain, and mountain sound (written with the acoustics
change).

## Decisions

**D1. The mountains are our own seeded meshes, not an add-on.**

Rejected:
- **Terrain3D:** it's for walkable ground. At 500 m+ a heightmap gains nothing
  over a ring of quads, and it's a C++ GDExtension that hits the 4.8 beta import
  abort.
- **A baked HDRI or sky panorama:** no parallax, and it can't catch the moving sun
  or moon.
- **Sky3D:** it has no horizon geometry.

**D2. Echoes in angle, not in metres.**

The base waveform is
f(θ) = Σₖ aₖ sin(nₖθ + φₖ) + roughness:
- the harmonics nₖ are integers (whole cycles around the ring, so the skyline is
  seamless), for example 3, 5, 8 and 13;
- the amplitudes aₖ fall off as 1/k, with seeded phases φₖ;
- the roughness is a low-amplitude seeded value noise;
- f is normalised to 0..1.

Ring r draws f(θ − r·Δ), shifted by Δ around the circle, as an elevation angle:

e_r(θ) = base_r + amp_r · f(θ − r·Δ)

Its height is R_r·tan(e_r). base_r rises with r and amp_r falls with r, so each
farther ring peeks over the nearer one as a softer, attenuated copy, like an echo
decaying. If the rings were scaled in metres, the farther ones would hide behind
the nearer ones. Colour lightens toward the haze with distance (aerial
perspective), because Sky3D's fog alone doesn't separate the layers at night.

Defaults keep stubby-music's scale: the near ring is about 1–4° high (8–30 m at
480 m).

**D3. The moon is fixed among the stars.**

A start bearing and altitude, at the Calendar's start hour, give a declination δ
and an hour angle H₀:
- sin δ = sin φ sin h + cos φ cos h cos A;
- H₀ comes from the east component and the altitude.

Each frame, H = H₀ + 15°·(solar_hour − start_hour), and alt/az follow by the
standard transform. The result is written to SkyDome's `moon_azimuth` and
`moon_altitude`, using Sky3D's convention (x = sin θ sin az, y = cos θ,
z = sin θ cos az, with +X east and −Z north). Then `update_moon_coords()` is
called.

Sky3D's own moon modes were rejected:
- **REALISTIC** places the moon by date. At latitude 37° it can never stand NNW at
  20°, so the moon would leave the opening view (the user chose that view).
- **SIMPLE** only takes an offset, and forces the SIMPLE sun maths, a cruder sun
  that moves the sunrise.

**Consequence (flagged):** a start at NNW 20° needs δ ≈ 59°, so this moon is
circumpolar. It never sets: it sinks to about 6° over the northern mountains before
dawn, then climbs in the northeast. A real moon (|δ| ≤ 28.6°) would set. The start
position is an export, so a plausible path is one value away.

**D4. The sun, stars and clouds stay Sky3D's.** No change: the realistic sun from
`current_time`, sidereal star rotation, and cloud drift. The headless test checks
that they move.

## Risks / Trade-offs

- [The circumpolar moon is unrealistic] → a data value; the design says so.
- [Rings at 700 m beyond the camera far plane or fog] → the Player camera far is
  4000 m; check Sky3D's fog doesn't erase the far ring at night (screenshot task).
- [The moon's phase comes from the sun's geometry, so it may look like a crescent at
  the start] → it's the same as the pinned moon today; revisit with the art pass.

## Migration Plan

Additive. The moon's pinned SkyDome values stay as the editor fallback. Rollback
is removing the two nodes.

## Open Questions

- Whether the moon should keep the opening view (circumpolar) or follow a real
  path. The default keeps the view.
