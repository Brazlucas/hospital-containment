class_name WeaponData
extends Resource
## A weapon. Numbers are the weapon's own; the run's Stats scale them (damage_pct, attack_speed_pct, range_pct...).
## RANGED weapons shoot bullets at the nearest enemy; MELEE weapons swing at it and hit everything in the arc.

enum Kind { RANGED, MELEE }

@export var id: StringName
@export var display_name := ""
@export var tags: PackedStringArray = []  ## families for synergies ("bala", "branca", "pistola"...), see SynergyData
@export var kind := Kind.RANGED
@export var damage := 4.0
@export var cooldown := 0.55  ## seconds between attacks at +0% attack speed
@export var attack_range := 190.0  ## px at +0% range: how far away an enemy starts being attacked
@export var knockback := 60.0
@export var crit_multiplier := 2.0
@export var shot_sfx := "gunshot"  ## played when the weapon fires / swings

@export_group("Ranged")
@export var projectile_speed := 420.0
@export var projectiles := 1  ## bullets per shot
@export var spread_deg := 2.0  ## random cone half-angle
@export var pierce := 0  ## extra enemies a bullet goes through
@export var explosion_radius := 0.0  ## px; above 0 the shot bursts where it ends (first enemy hit or end of range) and hurts everything inside
@export var projectile_color := Color(1.0, 0.85, 0.4)
@export var projectile_size := 1.0
@export var firearm := true  ## muzzle flash, light and an ejected cartridge; off for grenades, flames, needles and the like

@export_group("Melee")
@export var melee_reach := 46.0  ## px from the player's centre that the blow reaches
@export var melee_arc_deg := 150.0  ## total width of the swing
@export var swing_time := 0.14  ## seconds the blow takes to cross the arc
@export var hit_sfx := "bat_hit"  ## played when the blow connects

@export_group("Look")
@export var icon: Texture2D  ## drawn next to the player
@export var icon_scale := 1.0
@export var icon_rotation_deg := 0.0  ## turns the art so it points right (the bat is drawn on a diagonal)
@export var icon_offset := Vector2.ZERO  ## px (after scale) from the hand to the art's centre
@export var muzzle_offset := Vector2(8, -2)  ## px from the hand to where bullets and the flash come out (the barrel tip)
