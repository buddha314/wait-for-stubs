## 1. Calendar speed

- [ ] 1.1 `Calendar.speed` (default 1), the step list, `faster()`, `slower()`, `reset_speed()`, and `speed_changed`
- [ ] 1.2 Calendar delta capped at 0.1 s × speed per frame (D4); `Calendar.delta(frame_delta)` for rate-based consumers
- [ ] 1.3 Headless test: steps and ends; 64× reaches day from the start in about 7 s of frame time (simulated deltas); a 2 s frame advances 6.4 s; `night_started` once per crossing

## 2. Keys and readout

- [ ] 2.1 Actions `time_slower` (`[`), `time_faster` (`]`), `time_reset` (`\`) in `project.godot`, handled during play and ignored while `controls_enabled` is false
- [ ] 2.2 HUD time readout, top left: `DAY`/`NIGHT`, `HH:MM`, speed (`¼×`, `½×`, `1×` … `64×`)
- [ ] 2.3 Headless test: keys through `Input.parse_input_event`; no change with the rack screen open; readout text at a set time and speed

## 3. What follows the calendar

- [ ] 3.1 Scrub oak growth steps with `Calendar.delta` (sway stays on frame time)
- [ ] 3.2 Check every `_process` and `_physics_process` delta use against D2; record any other system that should follow the calendar
- [ ] 3.3 Headless test: reeds regrow in about 15 s at 4×; an oak by a flowing stream reaches budding faster at 16× than at 1×; player speed unchanged at 64×; the burbler's clock multiple and the master clock's sample rate unchanged at 64×

## 4. Wrap-up

- [ ] 4.1 CLAUDE.md: keys, what follows the calendar (D2), the readout
- [ ] 4.2 `openspec validate --strict add-time-speed-controls`
