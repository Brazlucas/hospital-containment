class_name CharacterData
extends Resource
## A playable character: starting stats and weapon. Different characters = different play styles, no new maps.

@export var id: StringName
@export var display_name := ""
@export var frames: SpriteFrames  ## "idle" + "walk", drawn facing right
@export var base_stats: Dictionary = {}  ## overrides of Stats.INFO base values
@export var starting_weapon: WeaponData
