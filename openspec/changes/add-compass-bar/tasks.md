## 1. Compass bar

- [x] 1.1 `scenes/compass_bar/compass_bar.gd` + `.tscn`: a CanvasLayer with a Control drawing letters, intercardinals, 15° ticks and the centre caret from the active camera's heading (D2, D3); end fade; hidden while the controls are taken (D4).
- [x] 1.2 Instance it in `main.tscn`; move the build-mode label below it (`hud.gd`).

## 2. Opening facing east (D5)

- [x] 2.1 Rotate the world content −90° in `main.tscn` (oaks, bugs, reeds, mountain rings, burbler) and the Player; rename the reed bed nodes North/South (bed ids unchanged).
- [x] 2.2 Moon start bearing 330° → 60° (`moon_path.gd`, `test_sky.gd`).
- [x] 2.3 CLAUDE.md: spawn faces east, placements are `scene.bsn` turned −90°, the moon, the compass.

## 3. Checks

- [x] 3.1 `tests/test_compass_bar.gd`: heading maths (east → 90°, south → 180°, pitch ignored), "E" centred and the burbler ahead at spawn, hidden while controls are taken, the bar clears the build label.
- [x] 3.2 Windowed screenshots at spawn (night) and at dawn (06:18): "E" centred, moon up-left, sun rising ahead.
- [x] 3.3 All test suites pass.
- [ ] 3.4 Play check in a window: turn round once and read the bar; watch the sunrise.
