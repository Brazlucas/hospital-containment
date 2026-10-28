class_name WaveData
extends Resource
## One wave of an arena: how long it lasts and what spawns while it runs.

@export var duration := 30.0  ## seconds
@export var spawn_interval := 1.4  ## seconds between spawn groups
@export var group_size := 2  ## enemies per spawn group
@export var hp_multiplier := 1.0
@export var damage_multiplier := 1.0
@export var enemies: Array[EnemyData] = []  ## pool, picked by EnemyData.spawn_weight
@export var ambience: AmbiencePreset  ## light, fog and lamp style of the wave
@export var arena: ArenaLayout  ## the room this wave is fought in (the arena fades into it); empty = the same room as the previous wave
