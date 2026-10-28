extends Node
## State of the current run: the character's stats, weapons, upgrades, materials and XP.
## start_run() resets everything; the HUD and upgrade screen read from here.

const XP_BASE := 10.0  ## XP needed for level 2
const XP_STEP := 8.0  ## extra XP needed per further level
const MAX_WEAPONS := 6
const PRICE_WAVE_STEP := 0.1  ## shop prices grow this much per wave after the first
const SYNERGIES_DIR := "res://resources/data/synergies"

var character: CharacterData
var stats: Stats
var weapons: Array[WeaponData] = []
var wave := 0  ## 1-based, 0 before the first wave
var materials := 0
var level := 1
var xp := 0.0
var kills := 0
var upgrades := {}  ## upgrade id -> times taken
var purchases := {}  ## shop item id -> times bought
var god_mode := false  ## trainer: the player takes no damage
var synergies: Array[SynergyData] = []  ## every synergy in the game
var active_synergies: Array[SynergyData] = []
var item_tags := {}  ## tag -> how many bought items carry it (weapons count through `weapons`)

var _synergy_mods := {}  ## stat id -> what the active synergies add right now


func start_run(c: CharacterData) -> void:
	character = c
	stats = Stats.new(c.base_stats)
	weapons.clear()
	weapons.append(c.starting_weapon)
	wave = 0
	materials = 0
	level = 1
	xp = 0.0
	kills = 0
	upgrades.clear()
	purchases.clear()
	god_mode = false
	if synergies.is_empty():
		for r in DataLibrary.load_all(SYNERGIES_DIR):
			synergies.append(r as SynergyData)
	item_tags.clear()
	active_synergies.clear()
	_synergy_mods.clear()
	Events.materials_changed.emit(materials)
	Events.xp_changed.emit(level, xp, xp_to_next())
	refresh_synergies()


func xp_to_next() -> float:
	return XP_BASE + (level - 1) * XP_STEP


## Picking up a material gives its value in materials and in XP, like Brotato.
func add_materials(amount: int) -> void:
	materials += amount
	Events.materials_changed.emit(materials)
	add_xp(float(amount))


func spend_materials(amount: int) -> void:
	materials -= amount
	Events.materials_changed.emit(materials)


func add_xp(amount: float) -> void:
	xp += amount
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
	Events.xp_changed.emit(level, xp, xp_to_next())


## `tier` (a Rarity.Tier) scales the upgrade's numbers.
func take_upgrade(u: UpgradeData, tier := Rarity.Tier.COMMON) -> void:
	stats.apply(Rarity.scale(u.modifiers, tier))
	upgrades[u.id] = stacks_of(u.id) + 1
	Events.stats_changed.emit()


func stacks_of(id: StringName) -> int:
	return upgrades.get(id, 0)


func price_of(item: ShopItemData) -> int:
	return roundi(item.price * (1.0 + PRICE_WAVE_STEP * maxi(wave - 1, 0)))


func has_weapon_slot() -> bool:
	return weapons.size() < MAX_WEAPONS


## False when the item is sold out for the run or a weapon would not fit.
func is_available(item: ShopItemData) -> bool:
	if item.max_stacks > 0 and purchases.get(item.id, 0) >= item.max_stacks:
		return false
	return item.kind != ShopItemData.Kind.WEAPON or has_weapon_slot()


func can_buy(item: ShopItemData) -> bool:
	return is_available(item) and materials >= price_of(item)


## Pays for the item and applies it. Returns false (and charges nothing) when it can't be bought.
func buy(item: ShopItemData) -> bool:
	if not can_buy(item):
		return false
	purchases[item.id] = purchases.get(item.id, 0) + 1
	spend_materials(price_of(item))
	if item.kind == ShopItemData.Kind.WEAPON:
		add_weapon(item.weapon)
	else:
		for t in item.tags:
			item_tags[t] = item_tags.get(t, 0) + 1
		if not item.modifiers.is_empty():
			stats.apply(item.modifiers)
			Events.stats_changed.emit()
		refresh_synergies()
	if item.heal > 0.0:
		Events.player_healed.emit(item.heal)
	return true


func add_weapon(w: WeaponData) -> void:
	weapons.append(w)
	Events.weapon_added.emit(w)
	refresh_synergies()


func remove_last_weapon() -> void:
	if weapons.is_empty():
		return
	weapons.pop_back()
	Events.weapon_removed.emit()
	refresh_synergies()


## How many of each synergy tag the player owns: weapons, bought items, and "arma" for the weapon count.
func tag_counts() -> Dictionary:
	var out := {"arma": weapons.size()}
	for w in weapons:
		for t in w.tags:
			out[t] = out.get(t, 0) + 1
	for t in item_tags:
		out[t] = out.get(t, 0) + item_tags[t]
	return out


## Works out which synergies are active now, gives (and takes back) their bonuses, and announces the new ones.
func refresh_synergies() -> void:
	var counts := tag_counts()
	var before := active_synergies.duplicate()
	active_synergies.clear()
	var mods := {}
	for s in synergies:
		if s.is_met(counts):
			active_synergies.append(s)
			for id in s.modifiers:
				mods[id] = mods.get(id, 0.0) + float(s.modifiers[id])
	var ids := {}
	for id in _synergy_mods:
		ids[id] = true
	for id in mods:
		ids[id] = true
	var changed := false
	for id in ids:
		var delta := float(mods.get(id, 0.0)) - float(_synergy_mods.get(id, 0.0))
		if delta != 0.0:
			stats.add(id, delta)
			changed = true
	_synergy_mods = mods
	for s in active_synergies:
		if not s in before:
			Events.synergy_activated.emit(s)
	if changed:
		Events.stats_changed.emit()
	Events.synergies_changed.emit()


## What buying `item` would do for the synergies: [text, colour, activates] for the first one it advances
## (an activation wins), or an empty array when it advances none.
func synergy_hint(item: ShopItemData) -> Array:
	var counts := tag_counts()
	var after := counts.duplicate()
	for t in item.all_tags():
		after[t] = after.get(t, 0) + 1
	var advance: Array = []
	for s in synergies:
		if s in active_synergies:
			continue
		if s.is_met(after):
			return ["★ ativa %s" % s.display_name, s.color, true]
		if advance.is_empty():
			for row in s.progress(after):
				if row[1] > counts.get(row[0], 0):
					advance = ["☆ %s %s" % [s.display_name, _progress_text(s, after)], s.color.darkened(0.15), false]
					break
	return advance


## Every synergy `item` would advance or switch on, as [text, colour] (the ones already on are left out).
func synergy_hints(item: ShopItemData) -> Array:
	var counts := tag_counts()
	var after := counts.duplicate()
	var tags := item.all_tags()
	for t in tags:
		after[t] = after.get(t, 0) + 1
	var out: Array = []
	for s in synergies:
		if s in active_synergies:
			continue
		var touches := false
		for t in tags:
			if s.requires.has(t) and counts.get(t, 0) < int(s.requires[t]):
				touches = true
		if not touches:
			continue
		if s.is_met(after):
			out.append(["★ ativa %s" % s.display_name, s.color])
		else:
			out.append(["☆ %s %s" % [s.display_name, _progress_text(s, after)], s.color.darkened(0.15)])
	return out


func _progress_text(s: SynergyData, counts: Dictionary) -> String:
	var parts := PackedStringArray()
	for row in s.progress(counts):
		parts.append("%d/%d" % [row[1], row[2]])
	return " ".join(parts)

