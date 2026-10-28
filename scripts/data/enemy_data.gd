class_name EnemyData
extends Resource
## An enemy type. All enemies share enemy.tscn / enemy.gd; only this data (and the art) differs.

@export var id: StringName
@export var display_name := ""
@export var frames: SpriteFrames  ## "walk" required, "idle" / "attack" optional; drawn facing down-right (3/4 view), mirrored by the enemy
@export var sprite_scale := 1.0
@export var max_hp := 10.0
@export var speed := 35.0
@export var contact_damage := 1.0
@export var contact_range := 16.0  ## px from the player at which it starts a bite
@export var attack_windup := 0.25  ## seconds from the start of the bite to the hit
@export var attack_cooldown := 0.9
@export var lunge_range := 80.0  ## px from the player inside which it breaks into a faster rush
@export var lunge_speed_mult := 1.4
@export var materials := 1  ## pickups dropped on death
@export_range(0.0, 1.0) var drop_chance := 1.0  ## chance that a death drops anything at all
@export var hit_height := 24.0  ## px above the feet where bullets aim and the hurtbox sits
@export var hit_radius := 9.0
@export var spawn_weight := 1.0  ## relative chance inside a wave's enemy pool

enum Throw { SYRINGE, BILE }

@export_group("Ghost")
@export var ghost := false  ## floats, drawn translucent with a glowing trail; passes through walls and furniture and leaves no blood
@export var hover_height := 0.0  ## px the body floats above the floor (it also bobs a little)

@export_group("Ranged")
@export_range(0.0, 1.0) var throw_chance := 0.0  ## each zombie rolls this when it spawns; throwers keep their distance and throw
@export var throw_kind := Throw.SYRINGE
@export var throw_damage := 1.0
@export var throw_range := 150.0  ## px from the player inside which it throws
@export var throw_hold := 90.0  ## px from the player at which it stops walking closer
@export var throw_cooldown := 2.4
@export var throw_windup := 0.4  ## seconds from raising its arm to letting go
@export var throw_speed := 140.0
