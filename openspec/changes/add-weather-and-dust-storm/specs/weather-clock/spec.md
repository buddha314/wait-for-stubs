## ADDED Requirements

### Requirement: Weather events land on the master clock grid
Every discrete weather event SHALL happen on a tick of a grid that is a whole
multiple of the master clock. This covers rain patter (individual audible drops
near the listener), lightning strikes, thunder arrivals, gust onsets and storm
calm troughs. Each event kind SHALL have a configured grid multiple. No weather
event SHALL be timed from frame time or wall time, except through the named
stand-in clock until the audio engine exists.

#### Scenario: Patter on the grid
- **WHEN** rain falls at a steady rate for 10 s on a ×480 patter grid
- **THEN** every drop event's sample time is an exact multiple of the grid period (6,000 samples at 48 kHz and a 1 BPM master)

#### Scenario: Frame-rate independence
- **WHEN** the same seed and weather run once at 30 fps and once at 144 fps
- **THEN** the event lists (kind and sample time) are identical

### Requirement: Rain rate sets patter density, not timing
The rain rate SHALL decide, per grid tick, whether drops land and how many, using a
seeded generator. Drop sizes SHALL be drawn per event, so the engine can voice each
drop by its Minnaert pitch. Heavier rain SHALL fill more ticks and SHALL never move
a drop off the grid. Dense rain beyond the grid's capacity SHALL go into a
continuous rain texture parameter, not into extra off-grid events.

#### Scenario: Light and heavy rain
- **WHEN** the rain rate rises from light to heavy
- **THEN** a larger share of grid ticks carry drops, every drop is still on a tick, and the texture level rises

#### Scenario: Deterministic patter
- **WHEN** the same seed and rain rate run twice
- **THEN** the same ticks carry the same drop sizes

### Requirement: Lightning and thunder both land on the grid
A lightning strike SHALL happen on a grid tick. Its distance from the listener SHALL
be chosen so that the thunder delay (distance / 343 m/s) is a whole number of grid
ticks, so the thunder also lands on the grid without breaking the physics. The flash
SHALL be shown at the strike's predicted audible instant, and thunder SHALL be
scheduled on the engine clock, never started from the visual.

#### Scenario: Thunder on the beat
- **WHEN** a strike is scheduled on a ×60 grid (one tick a second)
- **THEN** its distance is a multiple of 343 m (within 1%), and its thunder event lands exactly a whole number of ticks after the strike

#### Scenario: Flash at the audible instant
- **WHEN** a strike is scheduled at sample S
- **THEN** the flash is shown on the frame nearest S's predicted audible instant

### Requirement: Event visuals follow their events
The visual for a weather event (a lightning flash, a rain splash ripple) SHALL appear
at that event's audible instant, from the event list, and SHALL NOT generate events
of its own. Continuous visuals (falling rain, blowing sand, fog) MAY run at frame
rate from the continuous state.

#### Scenario: Splash on the patter
- **WHEN** a drop event lands near the listener
- **THEN** its splash ripple appears at the drop's audible instant, at a seeded spot near the listener

### Requirement: Continuous weather is parameters, not timing
Wind, storm intensity, rain rate, fog density and wetness SHALL be continuous state.
It SHALL change smoothly between keyframes placed on grid ticks, and SHALL be sent
to the audio engine as slowly changing parameters. It SHALL NOT be used to time any
sound.

#### Scenario: Gust as a parameter
- **WHEN** a gust onset fires on its grid tick
- **THEN** wind speed ramps smoothly from that tick, and the engine receives the new wind as a parameter

### Requirement: Stand-in clock until the engine exists
Weather events SHALL be computed as pure functions of master-clock time (a sample
count) and the seed. Until the audio engine provides its sample counter, a named
stand-in SHALL supply that time from wall time, and SHALL be removed when the engine
lands. With the stand-in, the game SHALL make no weather sound.

#### Scenario: Swapping the clock
- **WHEN** the engine's sample counter replaces the stand-in
- **THEN** no weather code changes beyond the time source, and the event lists for a given sample range are unchanged

### Requirement: Weather accepts requests from play
The weather controller SHALL accept weather requests from game systems (for
example, a target rain rate or storm level with a ramp time, aligned to a grid
tick), on top of its seeded baseline. This is so player-built recipes, such as a
"rain song" or dance patched on a rack, can call or calm weather in a later
change. A request SHALL ramp the continuous state from a grid tick, and SHALL keep
every event on the grid. With no requests, the seeded baseline SHALL be unchanged.

#### Scenario: A requested shower
- **WHEN** a system requests light rain from the next bar, ramping over 8 beats
- **THEN** the rain rate starts ramping on that bar's tick, the patter thickens on grid ticks, and the request is reported to the engine as a parameter

#### Scenario: No requests
- **WHEN** nothing requests weather
- **THEN** the weather follows the seeded baseline exactly as for the same seed without the request API
