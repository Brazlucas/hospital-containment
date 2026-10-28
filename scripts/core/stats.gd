class_name Stats
extends RefCounted
## Brotato-style stat block. Every stat is a flat number that upgrades add to; "_pct" stats are
## percentage points (damage_pct = 20 means +20%) and become multipliers through mult().
## Adding a stat = one line in INFO, then read it where it matters.

const INFO := {
	"max_hp": {"label": "Vida máxima", "base": 10.0, "suffix": ""},
	"hp_regen": {"label": "Regeneração", "base": 0.4, "suffix": "/s"},
	"damage_pct": {"label": "Dano", "base": 0.0, "suffix": "%"},
	"attack_speed_pct": {"label": "Vel. de ataque", "base": 0.0, "suffix": "%"},
	"range_pct": {"label": "Alcance", "base": 0.0, "suffix": "%"},
	"move_speed_pct": {"label": "Vel. de movimento", "base": 0.0, "suffix": "%"},
	"armor": {"label": "Armadura", "base": 0.0, "suffix": ""},
	"pickup_range_pct": {"label": "Alcance de coleta", "base": 0.0, "suffix": "%"},
	"crit_chance": {"label": "Crítico", "base": 0.0, "suffix": "%"},
	"luck": {"label": "Sorte", "base": 0.0, "suffix": ""},
	"pierce": {"label": "Perfuração", "base": 0.0, "suffix": ""},
	"explosion_pct": {"label": "Área de explosão", "base": 0.0, "suffix": "%"},
	"knockback_pct": {"label": "Empurrão", "base": 0.0, "suffix": "%"},
	"heal_on_kill": {"label": "Cura por abate", "base": 0.0, "suffix": ""},
}

var _values := {}


## `overrides` replaces the base value of some stats (a character's starting stats).
func _init(overrides: Dictionary = {}) -> void:
	for id in INFO:
		_values[id] = INFO[id]["base"]
	for id in overrides:
		_values[id] = float(overrides[id])


func get_value(id: String) -> float:
	return _values.get(id, 0.0)


func add(id: String, amount: float) -> void:
	_values[id] = get_value(id) + amount


## `modifiers` is {stat id: amount}, the shape UpgradeData.modifiers uses.
func apply(modifiers: Dictionary) -> void:
	for id in modifiers:
		add(id, float(modifiers[id]))


## 1.0 at +0%.
func mult(id: String) -> float:
	return maxf(0.0, 1.0 + get_value(id) / 100.0)


## Armor as damage reduction: 15 armor halves the damage, and negative armor makes it worse.
func damage_taken_mult() -> float:
	return 15.0 / (15.0 + maxf(get_value("armor"), -10.0))


## "+5 Vida máxima\n+12% Dano": the effect lines of a modifier set.
static func describe(modifiers: Dictionary) -> String:
	var texts := PackedStringArray()
	for line in lines(modifiers):
		texts.append(line["text"])
	return "\n".join(texts)


## 5 -> "5", 7.5 -> "7.5".
static func number(amount: float) -> String:
	var v := snappedf(amount, 0.1)
	return "%d" % int(v) if is_equal_approx(v, roundf(v)) else "%.1f" % v


## One entry per modifier, {"text": "+12% Dano", "positive": true}, so the cards can colour each line.
static func lines(modifiers: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in modifiers:
		var info: Dictionary = INFO.get(id, {"label": id, "suffix": ""})
		var amount := float(modifiers[id])
		out.append({
			"text": "%s%s%s %s" % ["+" if amount >= 0.0 else "", number(amount), info["suffix"], info["label"]],
			"positive": amount >= 0.0,
		})
	return out
