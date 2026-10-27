class_name UpgradeData
extends Resource
## A level-up choice. It only adds numbers to the run's Stats, so a new upgrade is a new .tres file in
## resources/data/upgrades/ (the upgrade screen scans that folder).

@export var id: StringName
@export var display_name := ""
@export_multiline var flavor := ""
@export var modifiers: Dictionary = {}  ## stat id -> amount, see Stats.INFO (negative values make trade-offs)
@export var weight := 1.0  ## relative chance of being offered
@export var max_stacks := 0  ## 0 = unlimited


func effect_text() -> String:
	return Stats.describe(modifiers)
