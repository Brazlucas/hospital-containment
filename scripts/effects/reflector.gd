class_name Reflector
extends Node2D
## Pixel-art floor reflection of a sibling AnimatedSprite2D: draws a vertically flipped copy below the
## object's feet with the shared reflection material (resources/materials/reflection.tres).
## Put it next to the sprite (the sprite's offset must put the feet at the node's origin, as the
## player's and the zombies' do). Where the copy shows is decided by the ReflectionMap.

const MATERIAL: ShaderMaterial = preload("res://resources/materials/reflection.tres")

@export var enabled := true
@export var source_path := NodePath("../Sprite")

var _src: AnimatedSprite2D
var _mirror: Sprite2D


func _ready() -> void:
	_src = get_node_or_null(source_path) as AnimatedSprite2D
	if _src == null:
		return
	_mirror = Sprite2D.new()
	_mirror.centered = false
	_mirror.flip_v = true
	_mirror.z_as_relative = false
	_mirror.z_index = -45  # above the floor and the stains, below everything that stands on it
	_mirror.material = MATERIAL
	_mirror.visible = enabled
	add_child(_mirror)


func set_enabled(value: bool) -> void:
	enabled = value
	if _mirror:
		_mirror.visible = value


func _process(_delta: float) -> void:
	if _mirror == null or not enabled:
		return
	var tex := _current_texture()
	_mirror.texture = tex
	if tex == null:
		return
	var h := float(tex.get_height())
	var feet := -_src.offset.y  # image row where the object touches the floor
	_mirror.position = _src.position
	_mirror.scale = _src.scale
	_mirror.flip_h = _src.flip_h
	# mirror the image about the feet line: the flipped rect starts right under the feet
	_mirror.offset = Vector2(_src.offset.x, _src.offset.y + 2.0 * feet - h)


func _current_texture() -> Texture2D:
	var frames := _src.sprite_frames
	if frames and frames.has_animation(_src.animation):
		return frames.get_frame_texture(_src.animation, _src.frame)
	return null
