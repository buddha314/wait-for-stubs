## ADDED Requirements

### Requirement: The moon travels with the stars
The moon SHALL move across the sky as simulation time passes, fixed among the
stars, at 15° of hour angle per simulated hour. Its position at the start of the
game SHALL come from data (a bearing and an altitude), and SHALL default to the
opening's view: NNW (bearing 330°), 20° above the horizon. The moon SHALL NOT be
timed from audio, and SHALL NOT time anything musical.

#### Scenario: In view at spawn
- **WHEN** a new game starts at solar midnight
- **THEN** the moon is at bearing 330° ± 1°, 20° ± 1° above the horizon

#### Scenario: It travels
- **WHEN** three simulated hours pass (225 s of night)
- **THEN** the moon has moved by more than 20° of arc, and its hour angle has advanced by 45°

#### Scenario: Data, not code
- **WHEN** the start position is set to bearing 100°, 10° up
- **THEN** the moon starts there and travels on that circle, with no code change

### Requirement: The sun, stars and clouds move with simulation time
The sun SHALL follow the Calendar's solar hour, the star field SHALL rotate with it,
and the clouds SHALL drift with the wind.

#### Scenario: A minute of night
- **WHEN** 60 s of night pass
- **THEN** the sun's position, the star rotation and the cloud positions have all changed
