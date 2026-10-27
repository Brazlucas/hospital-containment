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
@export var materials := 1  ## pickups dropped on death
@export var hit_height := 24.0  ## px above the feet where bullets aim and the hurtbox sits
@export var hit_radius := 9.0
@export var spawn_weight := 1.0  ## relative chance inside a wave's enemy pool
