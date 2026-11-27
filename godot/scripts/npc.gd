extends Node3D
class_name Pedestrian
## Kaldırımda dolaşan yaya: blok çevresinde döngü, önü kapalıysa bekler.

var path: Array = []
var idx := 0
var speed := 1.35
var visual: CharacterVisual
var _wait := 0.0

const TOPS := [Color(0.85, 0.2, 0.25), Color(0.2, 0.45, 0.8), Color(0.95, 0.95, 0.92), Color(0.15, 0.15, 0.17), Color(0.3, 0.6, 0.4), Color(0.95, 0.7, 0.2), Color(0.6, 0.35, 0.6), Color(0.85, 0.55, 0.45)]
const BOTTOMS := [Color(0.18, 0.22, 0.35), Color(0.25, 0.25, 0.27), Color(0.55, 0.45, 0.3), Color(0.85, 0.82, 0.75), Color(0.1, 0.1, 0.12)]


func _ready() -> void:
	add_to_group("people")
	visual = CharacterVisual.new()
	add_child(visual)
	visual.setup(TOPS[randi() % TOPS.size()], BOTTOMS[randi() % BOTTOMS.size()], [Color(0.08, 0.06, 0.05), Color(0.35, 0.22, 0.1), Color(0.8, 0.65, 0.35), Color(0.6, 0.6, 0.6)][randi() % 4], "short" if randf() < 0.5 else "braid")
	speed = randf_range(1.1, 1.6)


func _physics_process(delta: float) -> void:
	if path.is_empty() or Game.paused:
		return
	var target: Vector3 = path[idx]
	var to_t := target - global_position
	to_t.y = 0.0
	if to_t.length() < 0.6:
		idx = (idx + 1) % path.size()
		return
	var dir := to_t.normalized()
	var blocked := false
	for p in get_tree().get_nodes_in_group("player"):
		var rel: Vector3 = (p as Node3D).global_position - global_position
		if rel.length() < 1.3 and rel.normalized().dot(dir) > 0.5:
			blocked = true
	if blocked:
		visual.set_motion(0.0)
		return
	global_position += dir * speed * delta
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(dir.x, dir.z), min(1.0, delta * 6.0))
	visual.set_motion(speed)
