extends Node
## Global signals. Systems talk through these instead of holding references to each other.

@warning_ignore_start("unused_signal")
signal player_hp_changed(hp: float, max_hp: float)
signal player_died
signal enemy_killed(enemy: Node2D)
signal materials_changed(total: int)
signal xp_changed(level: int, xp: float, needed: float)
signal stats_changed
signal wave_started(wave: int, total: int)
signal wave_time_changed(seconds_left: float)
signal wave_finished(wave: int)
signal run_ended(victory: bool)
signal ambience_changed(display_name: String)
@warning_ignore_restore("unused_signal")
