class_name ShopItemData
extends Resource
## Something the player can buy between waves with materials. A new item is a new .tres file in
## resources/data/shop/ (the shop scans that folder). WEAPON adds a weapon slot; ITEM adds numbers to the
## run's Stats and/or heals. Spells and pets can become new kinds later.

enum Kind { WEAPON, ITEM }

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var kind := Kind.ITEM
@export var price := 20  ## materials at wave 1; RunState.price_of() scales it with the wave
@export var weight := 1.0  ## relative chance of being stocked
@export var max_stacks := 0  ## 0 = unlimited (weapons are limited by RunState.MAX_WEAPONS instead)
@export var icon: Texture2D  ## falls back to the weapon's icon
@export var tags: PackedStringArray = []  ## families for synergies (a weapon item uses its weapon's tags)

@export_group("Weapon")
@export var weapon: WeaponData

@export_group("Item")
@export var modifiers: Dictionary = {}  ## stat id -> amount, see Stats.INFO
@export var heal := 0.0  ## HP restored on purchase


## The synergy tags this item adds when bought: a weapon brings its own plus "arma"; an item brings its own.
func all_tags() -> PackedStringArray:
	if kind == Kind.WEAPON and weapon:
		var out := PackedStringArray(weapon.tags)
		out.append("arma")
		return out
	return tags


func display_icon() -> Texture2D:
	if icon:
		return icon
	return weapon.icon if weapon else null


## The effect lines shown in the shop: stat modifiers, the heal, or every number of the weapon. Weapon lines also
## carry "label" and "value" so the shop can lay them out in two columns.
func effect_lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if kind == Kind.WEAPON and weapon:
		for row in weapon_rows(weapon):
			out.append({"label": row[0], "value": row[1], "text": "%s %s" % row, "positive": true})
		return out
	out.append_array(Stats.lines(modifiers))
	if heal > 0.0:
		out.append({"text": "Cura %s de vida" % Stats.number(heal), "positive": true})
	return out


## [label, value] for each stat of a weapon, at +0% (the run's stats scale them). Short labels: the card is narrow.
static func weapon_rows(w: WeaponData) -> Array:
	var shots_per_sec := 1.0 / w.cooldown
	var rows: Array = []
	if w.kind == WeaponData.Kind.MELEE:
		rows.append(["Dano", Stats.number(w.damage)])
		rows.append(["Cadência", "%s/s" % Stats.number(shots_per_sec)])
		rows.append(["Alcance", Stats.number(w.melee_reach)])
		rows.append(["Arco", "%d°" % roundi(w.melee_arc_deg)])
	else:
		rows.append(["Dano", "%s x%d" % [Stats.number(w.damage), w.projectiles] if w.projectiles > 1 else Stats.number(w.damage)])
		rows.append(["Cadência", "%s/s" % Stats.number(shots_per_sec)])
		rows.append(["Alcance", Stats.number(w.attack_range)])
		if w.explosion_radius > 0.0:
			rows.append(["Área", Stats.number(w.explosion_radius)])
		else:
			rows.append(["Dispersão", "±%s°" % Stats.number(w.spread_deg)])
			rows.append(["Perfura", str(w.pierce)])
	rows.append(["Empurra", Stats.number(w.knockback)])
	rows.append(["Crítico", "x%s" % Stats.number(w.crit_multiplier)])
	rows.append(["DPS", Stats.number(w.damage * w.projectiles * shots_per_sec)])
	return rows

