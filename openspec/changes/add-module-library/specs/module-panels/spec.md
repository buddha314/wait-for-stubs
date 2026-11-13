## ADDED Requirements

### Requirement: Panels are generated from definitions
Each module's 3D panel SHALL be generated from its definition: width in HP, one jack
per port, one knob or switch per parameter, one light per light, all labelled. A
definition MAY override placement. The generated panel's jack and knob names SHALL
match the definition's port and parameter names, so the rack screen can patch and
turn them.

#### Scenario: Ports match
- **WHEN** a panel is generated for a definition with inputs `voct`, `fm` and output `out`
- **THEN** the model has sockets named for `voct`, `fm` and `out` at their laid-out positions

#### Scenario: Definition changes
- **WHEN** a parameter is added to a definition and the generator reruns
- **THEN** the panel gains a knob for it, and the definition check passes

### Requirement: Two visual families
Panels SHALL follow one of two families, chosen by the definition:
- **east coast:** dark or brushed panels, 3.5 mm jacks, round knobs;
- **west coast:** colour-coded panels, banana jacks coloured by signal type (audio,
  CV, gate).

Both SHALL follow the project's art style guide.

#### Scenario: West-coast jack colours
- **WHEN** a west-coast panel has an audio output, a CV input and a gate input
- **THEN** their jacks carry the three signal-type colours

### Requirement: Panels go through the asset pipeline
Generated panels SHALL be exported, given LODs and colliders, and previewed through
the same pipeline as other assets, one folder per module under `assets/modules/<id>/`.

#### Scenario: New module asset
- **WHEN** a module's panel is generated
- **THEN** its folder holds the model, definition, previews and README, and the import sets its LODs
