## ADDED Requirements

### Requirement: Every module records its provenance
Every module definition SHALL record its DSP source (library, file or function, and
pinned commit), the source's licence, its block latency in samples, its native sample
rate, and, for hand-written DSP, the paper or reference it follows and why no library
was used.

#### Scenario: Missing provenance
- **WHEN** a definition lacks a source or licence
- **THEN** the definition check fails, naming the module

### Requirement: Only permissive code is linked
Vendored and generated code SHALL be MIT, BSD, ISC, Apache-2.0, zlib, BSL-1.0,
Unlicense, CC0 or public domain. GPL, LGPL, AGPL, MPL, non-commercial, no-derivatives,
share-alike and undeclared code SHALL be rejected. The check SHALL read per-file
headers where a repository mixes licences, and per-function declarations for Faust
libraries. Test folders and host wrappers carrying other licences SHALL NOT be
vendored.

#### Scenario: GPL file slips in
- **WHEN** a vendored directory contains a file whose header is GPL-3
- **THEN** the licence check fails, naming the file

#### Scenario: Faust function without a licence
- **WHEN** a generated Faust module's manifest includes a function with no licence declaration
- **THEN** the licence check fails, naming the function

### Requirement: Sample sets pass the same audit
Sample data shipped for modules SHALL be CC0, CC-BY or an allowed code licence,
SHALL have a provenance record, and SHALL be audited separately from code. This
covers drum hits, impulse responses, wavetables and DX banks.

#### Scenario: Unclear bank
- **WHEN** a third-party DX7 bank with no stated licence is added
- **THEN** the audit rejects it

### Requirement: Foreign sample rates are converted
A module whose library assumes a sample rate other than the engine's SHALL run at its
native rate behind a resampler (or with tables regenerated for the engine's rate), so
its pitch and time constants are correct at the engine's rate.

#### Scenario: 32 kHz library at 48 kHz
- **WHEN** a module built on 32 kHz code plays a 440 Hz note in a 48 kHz engine
- **THEN** its fundamental is 440 Hz ± 2 cents

### Requirement: Third-party plugins are not hosted
The shipped game SHALL NOT load third-party plugin binaries (VST3, CLAP, LV2, AU)
into the rack.

#### Scenario: Plugin file present
- **WHEN** a plugin binary sits in the game's folders
- **THEN** the game neither scans nor loads it
