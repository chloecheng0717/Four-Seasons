extends Node2D

const PLAYER_H := 52.0
const GROUND_Y := 560.0

var level: Node2D
var p1: Player
var p2: Player
var _elapsed := 0.0


## Steps after the players it is parented behind, so its callback sees a pair
## whose physics have both already run this step.
class Mon:
	extends Node2D
	var sample: Callable

	func _physics_process(_delta: float) -> void:
		if sample.is_valid():
			sample.call()


func _ready() -> void:
	level = (load("res://scenes/Level.tscn") as PackedScene).instantiate()
	add_child(level)
	_run.call_deferred()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > 60.0:
		get_tree().quit(2)


func _place(p: Player, pos: Vector2) -> void:
	p.position = pos
	p.velocity = Vector2.ZERO


## Traces the failing ordering, sampling only after both players have stepped.
func _run() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var players_node: Node = level.get_node("Players")
	var kids: Array[Node] = players_node.get_children()
	p1 = kids[0] as Player
	p2 = kids[1] as Player

	for p: Player in [p1, p2]:
		p._set_support(null)
		p._riders.clear()
		p.velocity = Vector2.ZERO
		p.collision_mask = 3

	# Failing case: the supporter is the second node, so the rider steps first.
	var sup: Player = p2
	var rid: Player = p1

	var n := [0]
	var mon := Mon.new()
	mon.sample = func() -> void:
		var f: int = n[0]
		n[0] += 1
		if f > 70:
			return
		var gap: float = sup.position.y - rid.position.y
		var hits: Array[String] = []
		for i in sup.get_slide_collision_count():
			var c := sup.get_slide_collision(i)
			var who: Object = c.get_collider()
			var who_name := "?"
			if who is Node:
				who_name = (who as Node).name
			hits.append("%s[n=%.2f,pos=%s]" % [who_name, c.get_normal().y, (who as Node2D).position if who is Node2D else "-"])
		print("  %2d | %7.2f %7.2f %7.2f  %d | %7.2f %7.2f %7.2f   %d  | %5.2f %5.2f %6.2f  supHits=[%s]" % [
			f, sup.position.x, sup.position.y, sup.velocity.y, int(sup._carrying_riders),
			rid.position.x, rid.position.y, rid.velocity.y, int(rid.is_on_floor()),
			gap, absf(gap + rid._ride_offset), rid.position.x - sup.position.x, ", ".join(hits)])
	level.add_child(mon)

	_place(rid, Vector2(800, GROUND_Y))
	await get_tree().physics_frame
	_place(sup, Vector2(160, GROUND_Y))
	for _i in 12:
		await get_tree().physics_frame
	print("--- dropping rider onto supporter ---")
	_place(rid, Vector2(160, GROUND_Y - PLAYER_H - 40.0))
	for _i in 50:
		await get_tree().physics_frame
	print("--- jumping ---")
	Input.action_press(&"p2_jump")
	for _i in 8:
		await get_tree().physics_frame
		if _i == 1:
			Input.action_release(&"p2_jump")

	get_tree().quit(0)
