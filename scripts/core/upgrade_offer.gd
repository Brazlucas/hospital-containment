class_name UpgradeOffer
extends RefCounted
## One card on the level-up screen: an upgrade at a rarity. The numbers it gives are the upgrade's scaled by the tier.

var upgrade: UpgradeData
var tier := Rarity.Tier.COMMON


func _init(u: UpgradeData = null, t := Rarity.Tier.COMMON) -> void:
	upgrade = u
	tier = t


func modifiers() -> Dictionary:
	return Rarity.scale(upgrade.modifiers, tier)
