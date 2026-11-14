## 1. Engine (stubby-rack)

- [ ] 1.1 `step_sequencer` kind (`core/modules/sequencers.h`, D3): params `steps`, `cv_n`, `gate_n`; `clock`, `reset` in; `gate`, `cv` out; registry entry
- [ ] 1.2 `step_changed(module, sample, step)` through the event path, exposed on `RackServer` like `clock_ticked`
- [ ] 1.3 Core tests: steps 1→4→1 on edges; reset; gate follows the clock pulse on gated steps only; CV holds; step change on the edge's sample
- [ ] 1.4 Sync into `addons/stubby_rack/` (`tools/sync_stubby_rack.sh`), reimport

## 2. Shell in the world

- [ ] 2.1 `tools/blender/create_snail_shell.py`: four-whorl helicospiral after the reference (glossy translucent brown, sutures), LODs, previews, `asset.json`; `colliders.json`
- [ ] 2.2 `assets/creatures/snail_shell/snail_shell.tscn` + `.gd`: a `ResourceNode` pickup, gone once collected
- [ ] 2.3 `items.json` (`snail_shell`, description of its use), `resources.json` (`snail_shell`, yields 1, never returns), `ids.lock`; item icon (`tools/icons/`)
- [ ] 2.4 Seeded scatter of shells at the reed beds' edges, each with an `instance_id`; instanced in `main.tscn`
- [ ] 2.5 `acoustics.json` (D8)
- [ ] 2.6 Headless test: shells placed from the seed, same seed same places; E collects one empty-handed; never returns

## 3. Module and rack

- [ ] 3.1 Panel generator (module kit): `Knob_cv_<n>`, `Button_<n>` each with its one light (no separate step lights), `Port_clock`, `Port_reset`, `Port_gate`, `Port_cv`; spiral motif; `assets/modules/snail_sequencer/` with `asset.json` (`buttons` listed) and `engine.json` (`step_sequencer`)
- [ ] 3.2 `RackState`: optional places; buttons as params (`"place/gate_n"`); path-based completion (D7) with loop protection
- [ ] 3.3 Rack screen: button picking and toggling; each button's light steady when on, inverted while the playhead passes, from `step_changed` at the heard instant (D4)
- [ ] 3.4 `RackLink`: buttons → engine params; step events to the view
- [ ] 3.5 `create_burbler.py`: the optional `seq` place (D6); widen the rack frame if needed; regenerate
- [ ] 3.6 Headless tests: mount from a shell (all steps dark); toggle a button (state and engine); completion through the sequencer; optional place not required; a loop doesn't hang completion
- [ ] 3.7 Windowed check: patch clock → sequencer → volume, steps 2 and 4 on, hear the backbeat; CV → V/OCT plays a line; screenshot of the panel

## 4. Wrap-up

- [ ] 4.1 Move the snail-shell entry on the wall of bad ideas to "proposed"; CLAUDE.md (shells, the sequencer, buttons, path-based completion)
- [ ] 4.2 `openspec validate --strict add-snail-shell-sequencer`
