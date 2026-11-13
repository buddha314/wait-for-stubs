## ADDED Requirements

### Requirement: Every machine is configured on the common rack
Every configurable machine SHALL be configured on the same rack screen, which SHALL be
built entirely from that machine's `configure` data (title, places, spare cables,
normalled output). Adding a machine SHALL need data, not a new screen.

#### Scenario: Data, not code
- **WHEN** a second machine with its own `configure` block is opened with E
- **THEN** it shows the rack screen with its own title, slots and cables, and no rack-screen code changed

### Requirement: Opening and closing
Pressing E within reach of a machine's interact point SHALL open its rack screen. E or
Escape SHALL close it. While it is open, the cursor SHALL be free, the player SHALL NOT
move or look, and world pickups SHALL NOT be collected. When a pickup is also in reach,
the nearer target SHALL win.

#### Scenario: Open and close
- **WHEN** the player presses E at the burbler, and then Escape
- **THEN** the rack screen opens with the cursor free and movement stopped, then closes with control returned

### Requirement: Satisfactory-style window
The screen SHALL be a framed window over the game with:
- a title bar showing the machine's title and its header (for the burbler,
  "{bpm} BPM · configure");
- a Relevant strip on the left;
- the rack in the centre;
- the player's inventory as a 4 × 4 grid of item boxes on the right;
- key prompts below.

The world behind the window SHALL be dimmed and blurred as `rack_frame`'s `screen`
block specifies (panel colour and alpha, border, blur radius, dim colour and amount).

#### Scenario: Window layout
- **WHEN** the burbler's rack opens
- **THEN** the title reads "MUDPIT BURBLER" with "60 BPM · configure" for a ×60 burbler, the rack is centred, and the world behind is blurred and dimmed

### Requirement: The rack is drawn from the 3D assets
The rack SHALL be rendered from the real models: `rack_frame`, the mounted modules,
`slot_outline_<hp>hp`, `slot_labels` and `patch_plug`. It SHALL be drawn by an
orthographic camera looking straight at the faceplates, in a scene isolated from the
game world, with the key light from `rack_frame`'s `screen.key_light`.

The rails SHALL stretch to the rack width plus `rail_margin_m`. The posts SHALL sit at
±(rack width / 2 + `post_inset_m`). The rack width SHALL be the sum of the slot widths,
at 0.0508 m per HP. The camera SHALL frame the rack's full width, its posts and its
comb inside the centre panel.

#### Scenario: Burbler width
- **WHEN** the burbler's rack (8 + 8 + 4 HP) opens
- **THEN** the modules span 1.016 m, the rails are 1.136 m long, and the posts stand at x = ±0.608 m

#### Scenario: World lighting does not leak in
- **WHEN** the rack is opened at night and again at noon
- **THEN** the rack looks identical both times

### Requirement: Slots and labelled outlines
Each place SHALL occupy its HP in order, left to right. A mounted place SHALL show its
module. An empty place SHALL show the outline for its width, labelled with its kind's
`Label_<kind>` word and glyph. A fixed place SHALL always show its module and SHALL
never be emptied.

#### Scenario: Empty VCO slot
- **WHEN** the burbler's VCO place is empty
- **THEN** an 8 HP outline labelled VCO stands between the clock and the volume

#### Scenario: Fixed clock
- **WHEN** the player tries to remove the burbler's clock
- **THEN** nothing is removed

### Requirement: Mounting from the inventory
The Relevant strip SHALL list, as icon boxes with counts, the items the player holds
that an open place accepts, numbered 1 to 0 in order. An item SHALL mount when the
player:
- presses its number;
- clicks it in the strip; or
- drags it from the strip or the grid onto its empty slot.

Mounting SHALL take one item from the inventory and place that item's module. An item
SHALL mount only in a place whose `accepts` lists it. Removing a non-fixed module SHALL
return its item to the inventory, and SHALL first unplug every cable on that module.
When the inventory can't take something back, the screen SHALL show INVENTORY FULL and
SHALL leave it in place.

#### Scenario: Mounting the VCO
- **WHEN** the burbler's VCO place is empty and the player holds 2 square waves and presses 1
- **THEN** a Square VCO is mounted in the VCO place and the player holds 1 square wave

#### Scenario: Wrong place
- **WHEN** the player drags a square wave onto the volume place
- **THEN** nothing mounts and the square wave stays in the inventory

### Requirement: The cable comb holds the rack's spare cables
The frame's comb SHALL hold the machine's `configure.cables`, in order, one per
`Comb_<n>`. Each cable SHALL hang folded over its slot, along the stored-cable curve
from `rack_frame`'s `cable_comb` block. Comb cables SHALL come with the rack and SHALL
NOT use the player's patch cables. Unplugging both ends of a comb cable SHALL hang it
back on its comb slot.

#### Scenario: Opening an unpatched burbler
- **WHEN** an unpatched burbler's rack opens
- **THEN** a verdigris and a rust cable hang on the comb

#### Scenario: Comb cables are free
- **WHEN** the player patches both comb cables while holding 10 patch cables
- **THEN** the player still holds 10 patch cables

### Requirement: Patching with cables
A cable SHALL join one output jack to one free input jack. The player SHALL patch by:
- dragging from a jack or a comb plug and releasing on another jack; or
- with a `patch_cable` from the inventory, using one per patch.

Unplugging a player cable SHALL return it to the inventory. The cable in hand SHALL
snap to a jack it can plug into when the pointer comes within 40 screen pixels of it.
Its plug SHALL show seated in that jack, and releasing there SHALL plug it in. Any
cable SHALL be able to join any compatible jacks: the jacks the configuration names are
only a suggestion. An input SHALL take at most one cable. An output MAY feed several.

#### Scenario: Snap
- **WHEN** the player releases a cable 25 px beside a free input jack
- **THEN** the cable plugs into that jack

#### Scenario: Any cable, any patch
- **WHEN** the player patches the rust cable from GATE to TRIG and the verdigris cable from OUT to IN
- **THEN** the burbler's configuration is complete

#### Scenario: Occupied input
- **WHEN** the player drops a cable on an input that already holds a cable
- **THEN** the drop is refused and the cable stays in hand

### Requirement: Elastic cables
Each cable SHALL be drawn as a tube of `patch_plug`'s radius and side count. It SHALL
follow a quadratic Bézier between the two plugs' `Cable_attach` points, with its
control point at midpoint + down × (1 − tension) × (`slump_base_m` + span), as in
VCV Rack. Its plugs and collar SHALL be tinted in the cable's colour from
`patch_plug`'s `colors`. The cable in hand SHALL hang from the pointer. Its sag SHALL
follow on a damped spring, so moving the pointer swings it and the swing dies away.

#### Scenario: Slack with distance
- **WHEN** a cable at tension 0.5 joins two jacks 0.4 m apart
- **THEN** its lowest point lies about 0.23 m below the line between them

#### Scenario: Swing settles
- **WHEN** the player moves the cable in hand quickly and then holds still
- **THEN** the cable swings and comes to rest within about one second

### Requirement: Patch guidance without text
The screen SHALL draw each suggested patch that isn't made yet as a ghost cable in the
build-ghost colour, between its two jacks. While a suggested patch isn't made, both of
its jacks' halos (`Jack_<port>_Halo`) SHALL pulse in that cable's colour: strength 0 to
2, over a 1.2 s period. Other halos SHALL rest, and a jack's halo SHALL rest once that
jack is patched. Guidance SHALL show only once both modules of a patch are mounted.

#### Scenario: Ready to patch
- **WHEN** the burbler has a VCO mounted and nothing patched
- **THEN** GATE and TRIG pulse verdigris, OUT and IN pulse rust, two ghost cables show the patch, and the PHASE and V/OCT halos rest

#### Scenario: Waiting for a module
- **WHEN** the VCO place is empty
- **THEN** no guidance involves the VCO's jacks

### Requirement: Knobs
Every mounted module's knobs SHALL be adjustable:
- dragging vertically, where 240 px sweeps the full range through the knob's taper;
- or scrolling over the knob.

The knob node SHALL rotate across its `rotation_degrees` to show the value. A
machine's configuration MAY narrow a knob's range and step. The value SHALL be held in
the rack state, so it survives closing and reopening.

#### Scenario: Gain
- **WHEN** the player drags the volume's knob up by 120 px from 0
- **THEN** the gain reads 0.5 and the knob is turned halfway through its sweep

### Requirement: The rack produces an engine-independent patch
The rack screen SHALL record the rack as data:
- the module mounted in each place;
- each knob's value;
- each cable, with its colour and its two (place, port) ends.

It SHALL announce every change to that data. When every suggested patch in the
configuration exists, made with any cables, it SHALL announce that the machine is
configured, once per completion. The data SHALL be saveable as a resource. The screen
SHALL NOT talk to the audio engine itself: the engine change turns this data into its
patch.

#### Scenario: Partial patch
- **WHEN** only GATE → TRIG is patched
- **THEN** the rack data lists one cable and the machine is not configured

#### Scenario: Complete
- **WHEN** the second suggested patch is made
- **THEN** a "configured" announcement is sent once, and unplugging and re-plugging a cable sends it once more

### Requirement: Snap sound has provenance
The plug-in click SHALL cycle through the `patch_snap` clips. Each clip SHALL carry a
provenance record that passes the sound-licence audit. Until the audio engine's sampler
exists, a non-spatial stand-in player MAY play it, and that stand-in SHALL be named as
such and removed when the sampler lands.

#### Scenario: Plugging in
- **WHEN** the player plugs in three cables in a row
- **THEN** three different snap clips play, each traceable to its CC0 source
