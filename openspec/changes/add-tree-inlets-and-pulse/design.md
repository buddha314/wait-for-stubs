## Context

`add-stream-building` lets the player lay streams of reeds from the burbler's
`Outlet_0`. A stream carries the burbler's beat as notes (`StreamFlow`, one per clock
tick, integrated from the heard clock), and the burbler's voice is heard from the
nearest point of it or its streams. A scrub oak counts as watered when any flowing
stream comes within `water_reach_m` (3 m) of it (`GrowthLevels.water_at`), and mud water
wakes it to budding over about a minute. Nothing at the tree shows or sounds: the
growth is slow and small, and the 3 m rule gives no target to aim at.

The burbler's outlet is authored in its Blender generator: `Outlet_0` (+X along the
flow) and `Outlet_0_Halo` (rings, exported at scale 1 with `start_scale: 0`). The stream
builder finds free ports in group `stream_port` and shows the nearest one's halo.

The lightning bugs flash at the instant their click is heard: `RackServer.clock_ticked`
gives the tick's sample, `sample_to_ticks_usec` turns it into wall time, and the flash
waits for it. Tempo clocks run at whole multiples of the 1 BPM master, so two racks on
the same multiple tick together.

## Goals / Non-Goals

**Goals:**
- A visible target for the stream's end, and an unambiguous connection.
- Feedback at the tree, seen and heard, timed by the audio engine.
- No new DSP: the knock is a patch of existing modules.

**Non-Goals:**
- Inlets on reeds or other growing assets (the same pattern later).
- Delaying the pulse and knock by the water's travel time (open question).
- Faster growth: the pulse and knock are feedback; growth rates stay in `growth.json`.

## Decisions

**D1. Inlets are authored in the model.** `create_scrub_oak.py` adds `Inlet_<n>`
empties (n = 0…2) at the roots, around the trunk at the root flare's radius plus a
margin, each facing the trunk (+X into the tree), extras `stream: inlet`, and an
`Inlet_<n>_Halo` of rings exported at scale 1 with `start_scale: 0` (the burbler's
outlet halo, reused). The angles come from the variant, so instances differ.
- Rejected: inlet positions computed at runtime from the profile. They wouldn't show in
  previews or the asset viewer, and they'd differ from how the burbler's outlet works.
- Rejected: a separate `inlets.json`. Positions belong with the geometry they sit on.

**D2. The builder snaps the end to a free inlet.** While anchored, if a free inlet is
within 3 m of the aim point (the same radius as start ports), it shows its halo and
the plan ends exactly at the inlet, arriving along its +X. The rest of planning (whole
4 m segments, bend limit, cost) is unchanged; the plan's last segment is stretched or
shrunk to land on the inlet, within the bend limit, or the plan is invalid. Laying
connects the stream's end to the inlet: the end port is consumed (no extending past a
tree), and the inlet is taken. Dismantling the last segment frees both.
- Rejected: keeping the 3 m proximity rule with markers only. The user chose inlets
  (2026-11-13): an explicit connection, like a machine's input.

**D3. Watering is by connection.** A tree with inlets is watered by the flowing streams
connected to them, at their clarity (the clearest). `GrowthLevels.water_at` keeps the
proximity rule for growing assets without inlets. `watered_changed` and the goal
reports are unchanged.

**D4. The pulse is on the source's heard beat.** The tree listens to
`RackServer.clock_ticked` for its watering source's clock module. Each tick schedules a
pulse at the tick's heard instant (`sample_to_ticks_usec`), as the bugs' flashes are.
The pulse is an envelope (attack 0.03 s, decay 0.35 s) driving a slight swell of the
canopy pivot (scale × 1.04 at peak) and emission on the bark and buds (per-instance
material copies, as the field recorder's light). It runs only while watered by a
sounding source.
- Rejected: pulsing on frame time at the source's BPM: un-clocked, drifts from what's
  heard.
- Rejected: pulsing when a stream note reaches the inlet: notes arrive at a phase set
  by the stream's length, so the pulse would sit between beats.

**D5. The knock is a rack on the master grid.** Each oak has a `Rack`: `tempo_clock`
(`multiple` = its source's clock multiple, so it ticks with the source) → `envelope`
(attack 2 ms, decay 0.25 s) → `vca` ← `vco_sine` at the trunk's quarter-wave frequency,
heard through a `RackEmitter` at the trunk on the World bus (hearing radius 15 m, quiet
beside the burbler). The emitter is paused unless the tree is watered by a sounding
source; the clock multiple follows the source's BPM knob.
- Rejected: a sampled knock. It would need a CC0 recording and provenance, and couldn't
  follow the trunk's size.
- Rejected: triggering the knock from the source's clock through a cable between racks.
  The engine has no cross-rack cables, and the same multiple already lands on the
  same samples.

**D6. The knock's pitch comes from the trunk.** f = c / (4 · L): a fixed-free bar's
quarter-wave, with c ≈ 3800 m/s (longitudinal wave speed along the grain of oak; a
textbook value, cited in `acoustics.json`) and L the instance's trunk height after its
height stretch. About 2.4 m of trunk gives about 400 Hz. Confidence: "simplified
simulation" (a real trunk's knock is a mix of modes; one sine is a legible stand-in).
The constants live in `knock.json` beside the profile, not in code.

**D7. Acoustic profile.** `assets/flora/scrub_oak/acoustics.json` lists the trunk's
resonance (formula, parameters, confidence, citation), no emission of its own (it is
excited by a source), and the canopy's absorption as "not modelled yet". It follows the
`add-acoustic-asset-profiles` format when that lands, as the field recorder's does.

## Risks / Trade-offs

- [The end snap can make a valid plan invalid near a tree] → the halo and the
  invalid tint show why; the player aims at another inlet or approaches differently.
- [Many oaks, many racks] → racks are cheap (the spike measured about 10 µs per emitter
  per step), and only watered oaks' emitters play.
- [Pulse and knock on the beat while the notes arrive between beats] → accepted (D4);
  see the open question.

## Migration Plan

Regenerate the oak with the generator, reimport, and lay streams again (laid streams
aren't saved). Rollback restores the generator and the 3 m rule.

## Open Questions

- Should the pulse and knock wait for the water's travel time, rounded to whole beats,
  so they follow the notes down the stream?
- How many inlets per oak (three drafted)?
