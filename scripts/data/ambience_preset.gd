class_name AmbiencePreset
extends Resource
## The atmosphere of a wave: how dark the room is, what colour and flicker the lamps have, how thick the fog
## is and how strong the player's torch is. WaveData.ambience picks one; the AmbienceDirector fades into it.

@export var display_name := ""  ## announced on the HUD when the wave starts
@export var ambient := Color(0.82, 0.88, 0.9)  ## the room's base light: near black = blackout, red = alarm
@export var light_tint := Color.WHITE  ## multiplied into every lamp's colour
@export var light_energy := 1.0  ## multiplier on every lamp's strength
@export var light_style := Lamp.Style.FLICKER
@export_range(0.0, 1.0) var fog_density := 0.0
@export var fog_color := Color(0.75, 0.85, 0.82)
@export var torch_energy := 0.35  ## the player's own light
@export var torch_scale := 1.0
@export var ambient_flicker := true  ## the whole room dims for a blink now and then, like failing tubes
@export var transition := 1.5  ## seconds to fade in from the previous atmosphere
