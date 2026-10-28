class_name SynergyData
extends Resource
## A synergy: a bonus that switches on while the player owns enough weapons and items of the right families.
## Every weapon and item carries tags ("branca", "pistola", "explosivo"...); `requires` says how many of each tag are
## needed. A new synergy is a new .tres in resources/data/synergies/, nothing to register.

const TAG_NAMES := {
	"arma": "armas", "bala": "armas de fogo", "branca": "armas brancas", "pistola": "pistolas", "smg": "SMGs",
	"fuzil": "fuzis", "escopeta": "escopetas", "sniper": "snipers", "explosivo": "explosivos",
	"quimico": "químicos", "medico": "médicos", "energia": "energia", "chama": "chamas",
}

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var requires: Dictionary = {}  ## tag -> how many owned (weapons plus shop items); the special tag "arma" counts every weapon
@export var modifiers: Dictionary = {}  ## stat id -> amount while active, see Stats.INFO
@export var color := Color(1.0, 0.8, 0.3)


static func tag_name(tag: String) -> String:
	return TAG_NAMES.get(tag, tag)


func is_met(counts: Dictionary) -> bool:
	for tag in requires:
		if counts.get(tag, 0) < int(requires[tag]):
			return false
	return true


## [tag, have, need] for each requirement.
func progress(counts: Dictionary) -> Array:
	var out: Array = []
	for tag in requires:
		out.append([tag, mini(counts.get(tag, 0), int(requires[tag])), int(requires[tag])])
	return out


## "+20% Dano, +10% Crítico"
func effect_text() -> String:
	return Stats.describe(modifiers).replace("\n", ", ")
