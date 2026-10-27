class_name Rarity
extends RefCounted
## The five rarities of the level-up cards: how much each scales an upgrade's numbers, how likely each is
## to be offered (by wave and luck) and the colour of its card. Tier values are plain ints (0 = common).

enum Tier { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

const NAMES: Array[String] = ["Comum", "Incomum", "Rara", "Épica", "Lendária"]
const ACCENTS: Array[Color] = [
	Color(0.66, 0.70, 0.72), Color(0.45, 0.78, 1.0), Color(0.72, 0.5, 1.0), Color(1.0, 0.45, 0.8), Color(1.0, 0.78, 0.25),
]
## An upgrade's bonuses are multiplied by this, like Brotato's tiers (penalties only grow at half the rate).
const MULTIPLIERS: Array[float] = [1.0, 1.5, 2.2, 3.2, 4.5]
## Offer weights per tier. Row = the wave just finished (1, 2, 3...; the last row repeats), column = tier.
const WEIGHTS: Array = [
	[100, 18, 0, 0, 0],
	[100, 30, 8, 0, 0],
	[100, 32, 18, 5, 0],
	[100, 32, 22, 10, 3],
	[100, 30, 25, 14, 6],
]


## Picks a tier for an offer after `wave`. Luck (a stat) makes every tier above common more likely.
static func roll(wave: int, luck: float) -> int:
	var row: Array = WEIGHTS[clampi(wave - 1, 0, WEIGHTS.size() - 1)]
	var boost := 1.0 + maxf(luck, 0.0) / 100.0
	var weights: Array[float] = []
	var total := 0.0
	for i in row.size():
		weights.append(float(row[i]) * (1.0 if i == 0 else boost))
		total += weights[i]
	var r := randf() * total
	for i in weights.size():
		r -= weights[i]
		if r <= 0.0:
			return i
	return Tier.COMMON


## The upgrade's modifiers at a given tier, rounded to one decimal.
static func scale(modifiers: Dictionary, tier: int) -> Dictionary:
	var m: float = MULTIPLIERS[tier]
	var out := {}
	for id in modifiers:
		var amount := float(modifiers[id])
		var k := m if amount >= 0.0 else 1.0 + (m - 1.0) * 0.5
		out[id] = snappedf(amount * k, 0.1)
	return out
