extends CanvasLayer
## Weather over the arena, driven by the wave's AmbiencePreset (`rain`, `lightning`) through Events.weather_changed.
## Rain is three things that fade in and out together: fast streaks (rain.gdshader), water on the camera lens (rain_lens.gdshader:
## a light blur and drops that slide down) and rings splashing on the floor (RainSplashes). In a storm, lightning
## strikes every few seconds: a jagged bolt and a double white flash, then thunder after a delay (the farther, the quieter).

const RAIN_SHADER := preload("res://scripts/effects/rain.gdshader")
const LENS_SHADER := preload("res://scripts/effects/rain_lens.gdshader")
const ADDITIVE: Material = preload("res://resources/materials/additive.tres")
const STRIKE_MIN := 5.0
const STRIKE_MAX := 11.0
const FADE_SPEED := 0.5  ## rain intensity per second, so it takes a couple of seconds to build up

var _rain := 0.0
var _rain_target := 0.0
var _lightning := false
var _next_strike := 0.0
var _rain_rect: ColorRect
var _rain_mat: ShaderMaterial
var _lens_rect: ColorRect
var _lens_mat: ShaderMaterial
var _flash: ColorRect
var _bolt: Line2D


func _ready() -> void:
	layer = 8  # above the world, under the HUD
	_lens_mat = ShaderMaterial.new()
	_lens_mat.shader = LENS_SHADER
	_lens_rect = ColorRect.new()  # first, so the streaks are drawn over the lens
	_lens_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lens_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lens_rect.material = _lens_mat
	_lens_rect.visible = false
	add_child(_lens_rect)
	get_parent().add_child.call_deferred(RainSplashes.new())  # the floor rings live in the world, next to this layer
	_rain_mat = ShaderMaterial.new()
	_rain_mat.shader = RAIN_SHADER
	_rain_rect = ColorRect.new()
	_rain_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rain_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rain_rect.material = _rain_mat
	_rain_rect.visible = false
	add_child(_rain_rect)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.material = ADDITIVE
	_flash.color = Color(0.85, 0.92, 1.0, 0.0)
	add_child(_flash)
	_bolt = Line2D.new()
	_bolt.width = 2.5
	_bolt.default_color = Color(0.9, 0.95, 1.0)
	_bolt.material = ADDITIVE
	_bolt.visible = false
	add_child(_bolt)
	Events.weather_changed.connect(_on_weather_changed)


func _on_weather_changed(rain: float, lightning: bool) -> void:
	_rain_target = rain
	_lightning = lightning
	_next_strike = randf_range(2.0, 4.0)
	if rain > 0.0:
		_rain_rect.visible = true
		_lens_rect.visible = true


func _process(delta: float) -> void:
	if _rain != _rain_target:
		_rain = move_toward(_rain, _rain_target, delta * FADE_SPEED)
		_rain_mat.set_shader_parameter("intensity", _rain)
		_lens_mat.set_shader_parameter("wetness", _rain)
		if _rain <= 0.0:
			_rain_rect.visible = false
			_lens_rect.visible = false
	if _lightning:
		_next_strike -= delta
		if _next_strike <= 0.0:
			_strike()
			_next_strike = randf_range(STRIKE_MIN, STRIKE_MAX)


func _strike() -> void:
	var size := get_viewport().get_visible_rect().size
	var x := randf_range(size.x * 0.1, size.x * 0.9)
	var end_y := randf_range(size.y * 0.35, size.y * 0.85)
	var points := PackedVector2Array([Vector2(x, 0.0)])
	var y := 0.0
	while y < end_y:  # a jagged line from the top of the screen
		y = minf(y + randf_range(14.0, 30.0), end_y)
		x += randf_range(-14.0, 14.0)
		points.append(Vector2(x, y))
	_bolt.points = points
	_bolt.visible = true
	_bolt.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.5, 0.03)
	tw.tween_property(_flash, "color:a", 0.1, 0.07)
	tw.parallel().tween_property(_bolt, "modulate:a", 0.0, 0.14)
	tw.tween_property(_flash, "color:a", 0.38, 0.03)  # the second, weaker flash
	tw.tween_property(_flash, "color:a", 0.0, 0.3)
	tw.tween_callback(func(): _bolt.visible = false)
	var delay := randf_range(0.25, 1.4)
	get_tree().create_timer(delay).timeout.connect(_thunder.bind(delay))


func _thunder(delay: float) -> void:
	AudioManager.play_sfx("trovao", -2.0 - delay * 3.0, 0.08)
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null and delay < 0.7:  # a close one shakes the camera
		player.shake(2.5, 0.3)
