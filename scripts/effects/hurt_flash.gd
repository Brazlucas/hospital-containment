class_name HurtFlash
extends RefCounted
## "Slightly red" damage flash for any CanvasItem whose material has a `hurt`
## uniform (character_motion.gdshader or hurt_flash.gdshader).

static func play(item: CanvasItem, tree: SceneTree, strength := 1.0, time := 0.4) -> void:
	var mat := item.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("hurt", strength)
	var tw := tree.create_tween()
	tw.tween_method(func(v: float): mat.set_shader_parameter("hurt", v), strength, 0.0, time).set_ease(Tween.EASE_OUT)
