extends Node
## State of the current run: the character's stats, weapons, upgrades, materials and XP.
## start_run() resets everything; the HUD and upgrade screen read from here.

const XP_BASE := 10.0  ## XP needed for level 2
const XP_STEP := 8.0  ## extra XP needed per further level

var character: CharacterData
var stats: Stats
var weapons: Array[WeaponData] = []
var wave := 0  ## 1-based, 0 before the first wave
var materials := 0
var level := 1
var xp := 0.0
var pending_levels := 0  ## level-ups not yet spent in the upgrade screen
var kills := 0
var upgrades := {}  ## upgrade id -> times taken


func start_run(c: CharacterData) -> void:
	character = c
	stats = Stats.new(c.base_stats)
	weapons.clear()
	weapons.append(c.starting_weapon)
	wave = 0
	materials = 0
	level = 1
	xp = 0.0
	pending_levels = 0
	kills = 0
	upgrades.clear()
	Events.materials_changed.emit(materials)
	Events.xp_changed.emit(level, xp, xp_to_next())


func xp_to_next() -> float:
	return XP_BASE + (level - 1) * XP_STEP


## Picking up a material gives its value in materials and in XP, like Brotato.
func add_materials(amount: int) -> void:
	materials += amount
	Events.materials_changed.emit(materials)
	add_xp(float(amount))


func add_xp(amount: float) -> void:
	xp += amount
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		pending_levels += 1
	Events.xp_changed.emit(level, xp, xp_to_next())


## `tier` (a Rarity.Tier) scales the upgrade's numbers.
func take_upgrade(u: UpgradeData, tier := Rarity.Tier.COMMON) -> void:
	stats.apply(Rarity.scale(u.modifiers, tier))
	upgrades[u.id] = stacks_of(u.id) + 1
	Events.stats_changed.emit()


func stacks_of(id: StringName) -> int:
	return upgrades.get(id, 0)
