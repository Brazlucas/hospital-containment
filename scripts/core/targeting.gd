class_name Targeting
extends RefCounted
## Enemy queries shared by weapons (and, later, anything that needs "the closest zombie").

## Nearest living enemy to `from` within `max_dist` px (measured to its hit position), or null.
static func nearest_enemy(tree: SceneTree, from: Vector2, max_dist := INF) -> Enemy:
	var best: Enemy = null
	var best_d2 := max_dist * max_dist
	for node in tree.get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e.dead:
			continue
		var d2 := from.distance_squared_to(e.hit_position())
		if d2 <= best_d2:
			best_d2 = d2
			best = e
	return best
