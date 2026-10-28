class_name ArenaLayout
extends Resource
## An arena's art and collision. Every rect and point is in the background texture's own pixels; the
## arena multiplies them by `art_scale`, so changing that one number resizes the whole room.

@export var display_name := ""
@export var background: Texture2D  ## one painted image: floor, walls and furniture
@export var art_scale := 0.5  ## world px per texture px (0.5 keeps the painted furniture in scale with the player)
@export var view_rect := Rect2()  ## camera limits; an empty rect means the whole texture
@export var blockers: Array[Rect2] = []  ## walls and furniture footprints that stop the player and the zombies
@export var player_start := Vector2.ZERO
@export var exit_point := Vector2.ZERO  ## the floor right in front of the exit door; the player walks here when a wave is won (zero = no walk)
@export var exit_into := Vector2.ZERO  ## a point inside the doorway, where the player fades away
@export var lights: Array[ArenaLight] = []  ## ceiling lamps (flicker and tint come from the wave's AmbiencePreset)
@export var puddles := PackedVector3Array()  ## x, y = centre and z = radius, in texture px; each one gets a leak above it
