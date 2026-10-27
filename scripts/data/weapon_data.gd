class_name WeaponData
extends Resource
## A weapon. Numbers are the weapon's own; the run's Stats scale them (damage_pct, attack_speed_pct, range_pct...).

@export var id: StringName
@export var display_name := ""
@export var icon: Texture2D  ## drawn next to the player, pointing right
@export var damage := 4.0
@export var cooldown := 0.55  ## seconds between shots at +0% attack speed
@export var attack_range := 190.0  ## px at +0% range
@export var projectile_speed := 420.0
@export var projectiles := 1  ## bullets per shot
@export var spread_deg := 2.0  ## random cone half-angle
@export var pierce := 0  ## extra enemies a bullet goes through
@export var knockback := 60.0
@export var crit_multiplier := 2.0
@export var shot_sfx := "gunshot"
