extends CanvasLayer
## Screen artifacts when the player is hurt (see pain.gdshader). It sits above the HUD, so the HUD is torn too.
## The overlay only exists on screen while the effect lasts: it copies the screen, which is not free.

const SHADER := preload("res://scripts/ui/pain.gdshader")
const DECAY := 2.2  ## pain lost per second

var _pain := 0.0
var _rect: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	layer = 12
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)
	Events.player_hurt.connect(_on_hurt)


func _on_hurt(amount: float) -> void:
	_pain = maxf(_pain, clampf(0.45 + amount * 0.12, 0.45, 1.0))
	_rect.visible = true


func _process(delta: float) -> void:
	if _pain <= 0.0:
		return
	_pain = maxf(0.0, _pain - delta * DECAY)
	_mat.set_shader_parameter("pain", _pain)
	_mat.set_shader_parameter("seed", randf() * 10.0)
	if _pain <= 0.0:
		_rect.visible = false
