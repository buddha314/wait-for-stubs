## 1. Mountains

- [x] 1.1 `scenes/mountains/mountain_rings.gd` (`@tool`): seeded waveform (whole-cycle harmonics + roughness), three echo rings by elevation angle, quad strips from below ground to the ridge, per-ring colour toward haze; children generated in `_ready`, no `owner` (design D2)
- [x] 1.2 Outer ground: 1600 m dark mud plane at y = −0.15 m in `main.tscn`
- [x] 1.3 Headless test: same seed same heights; seam matches; ring 1 correlates with ring 0 shifted; farther rings stand above nearer ones at most bearings; amplitude falls

## 2. Moon

- [x] 2.1 `scenes/sky/moon_path.gd`: start bearing/altitude → declination and hour angle; per-frame alt/az from `Calendar.solar_hour()` into SkyDome (design D3)
- [x] 2.2 Headless test: in view at start (330°, 20°); 45° of hour angle after 3 simulated hours; moves more than 20° of arc

## 3. Sky check and look

- [x] 3.1 Headless test: sun position, star rotation and cloud positions change over 60 s of night
- [x] 3.2 Screenshots at night start, mid-night and dawn; check the far ring isn't lost in fog; tune colours
- [ ] 3.3 Mountain acoustic profile: note the delays in the design; write `acoustics.json` when `add-acoustic-asset-profiles` 1.1 defines the format (left open here)
- [x] 3.4 CLAUDE.md (mountains, moon path; the pinned moon is gone) and `openspec validate --strict add-sky-motion-and-mountains`
