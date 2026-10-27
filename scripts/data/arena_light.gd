class_name ArenaLight
extends Resource
## A ceiling lamp of an arena. `position` is in the background texture's pixels, like ArenaLayout.blockers.
## Colour, strength and flicker are retinted per wave by the AmbienceDirector (see AmbiencePreset).

@export var position := Vector2.ZERO
@export var color := Color(0.82, 0.95, 0.88)
@export var energy := 0.7
@export var texture_scale := 1.5  ## the light's radius is 128 * texture_scale world px
