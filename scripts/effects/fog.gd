class_name Fog
extends Node2D
## Drifting fog over a room (world space, so it moves with the camera like real mist). Place it at the
## room's centre; tune density / color / speed / size in the Inspector (they feed the shader).
## Sits above the actors and below the dust, and ignores walls: it is only a visual layer.

@export_range(0.0, 1.0) var density := 0.55:
	set(v):
		density = v
		_apply()
@export var color := Color(0.82, 0.9, 1.0):
	set(v):
		color = v
		_apply()
@export var speed := 0.012:
	set(v):
		speed = v
		_apply()
@export var noise_scale := 3.0:  ## bigger = smaller, denser wisps
	set(v):
		noise_scale = v
		_apply()
@export var size := Vector2(1600, 1600):  ## world px covered
	set(v):
		size = v
		_apply()

@onready var _sprite: Sprite2D = $Mist


func _ready() -> void:
	z_index = 15
	_apply()


func _apply() -> void:
	if not is_node_ready():
		return
	var mat := _sprite.material as ShaderMaterial
	mat.set_shader_parameter("density", density)
	mat.set_shader_parameter("fog_color", color)
	mat.set_shader_parameter("speed", speed)
	mat.set_shader_parameter("scale", noise_scale)
	mat.set_shader_parameter("area", size)
	_sprite.scale = size / Vector2(_sprite.texture.get_size())
