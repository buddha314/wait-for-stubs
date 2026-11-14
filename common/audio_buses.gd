class_name AudioBuses
extends RefCounted
## The game's audio buses (default_bus_layout.tres). World and music stems (every
## RackEmitter) play on WORLD; the engine's non-spatial UI stem plays on UI (project
## setting audio/stubby_rack/ui_bus). Both send to Master. The field recorder's meter
## reads WORLD, so UI sounds never move it (add-field-recorder D5).

const WORLD := &"World"
const UI := &"UI"
