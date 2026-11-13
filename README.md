# wait-for-stubs

Godot Builder Game

## Godot port

This repository now includes a Godot 4 project scaffold:

- Project file: `/home/runner/work/wait-for-stubs/wait-for-stubs/project.godot`
- Main scene: `/home/runner/work/wait-for-stubs/wait-for-stubs/scenes/Main.tscn`

Existing repository files/assets are preserved.

## Use the latest Godot build from source

Build the latest Godot editor from source, then open this project:

```bash
git clone https://github.com/godotengine/godot.git /tmp/godot
cd /tmp/godot
scons platform=linuxbsd target=editor dev_build=yes -j"$(nproc)"
./bin/godot.linuxbsd.editor.* --path /home/runner/work/wait-for-stubs/wait-for-stubs
```
