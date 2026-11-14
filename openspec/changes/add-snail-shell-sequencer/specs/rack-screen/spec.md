## ADDED Requirements

### Requirement: Buttons
Modules with buttons SHALL let the player toggle each button by clicking it, as pushing
a lit button on hardware does. A button's
light SHALL show its state, and the state SHALL be held in the rack state, so it
survives closing and reopening, and SHALL reach the engine as the button's parameter.

#### Scenario: Toggling a step
- **WHEN** the player clicks the Snail sequencer's step 2 button, which is off
- **THEN** its light comes on, the step's gate is on in the rack state and the engine, and it stays on after the rack is closed and reopened
