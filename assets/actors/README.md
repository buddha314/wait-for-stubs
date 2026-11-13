# Actors

## Player start marker (`tools/blender/create_player_start.py`)

![marker](player_start_marker/preview.png)

What the level designer sees where the player will begin; never drawn in play (a
Godot scene for it would hide the model outside the editor). Origin on the ground at the footprint's centre, so it
snaps to the floor when dropped.

- **Footprint:** a 0.4 m ring and faint disc, about a standing player's footprint.
- **Facing:** an arrow on the ground along forward (−Z, the same in Godot): the way the player
  looks at the start. Rotate the marker to aim it.
- **Eye:** a post to 1.65 m (`Player.EYE_HEIGHT`) with a forward sight tick: where
  the camera starts.

In the build colour (`#ffd39a`), emissive so it reads in dark scenes. 299 triangles.
No Godot scene uses it yet: the player spawns at the origin of `main.tscn`. A
`player_start.tscn` (this model, hidden in game, read by `main.gd`) is the next step.

```sh
~/.local/bin/blender -b --factory-startup -P tools/blender/create_player_start.py
```
