extends Node2D

## Steps after the players it is parented behind, so its callback sees a pair
## whose physics have both already run this step.
class RideMonitor:
	extends Node2D
	var sample: Callable

	func _physics_process(_delta: float) -> void:
		if sample.is_valid():
			sample.call()

const PLAYER_H := 52.0
const PLAYER_W := 60.0
const GROUND_Y := 560.0
# Ground tiles are 64 wide, so a 60 wide body only sits square on the floor when it
# is centred over one tile. 160 and 800 are both tile centres; a straddling spot
# lets the engine shove the body sideways as it depenetrates the tile edge.
const CLEAR_X1 := 160.0
const CLEAR_X2 := 800.0
# Open ground to walk apart and push together in, well clear of both walls.
const FAR_X := 400.0
# Somewhere on the flat ground that no section stacks at, used to park the two
# players apart from each other and from their spawns while a stack is built.
const PARK_X := 600.0
# Full jump apex is ~128px, so a carried rider should stay within this of its
# support instead of being left behind by the whole jump height.
const MAX_STACK_GAP := 80.0

var level: Node2D
var p1: Player
var p2: Player
var failures: Array[String] = []
var _elapsed := 0.0
var _log: FileAccess


func _ready() -> void:
	_log = FileAccess.open("user://stack_jump_test.log", FileAccess.WRITE)
	level = (load("res://scenes/Level.tscn") as PackedScene).instantiate()
	add_child(level)
	_run.call_deferred()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > 120.0:
		_emit("WATCHDOG: aborted")
		get_tree().quit(2)


func _emit(line: String) -> void:
	print(line)
	if _log != null:
		_log.store_line(line)
		_log.flush()


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_emit("  PASS  %s %s" % [label, detail])
	else:
		failures.append(label)
		_emit("  FAIL  %s %s" % [label, detail])


func _wait(frames: int) -> void:
	for _i in frames:
		await get_tree().physics_frame


func _hold(actions: Array, frames: int) -> void:
	for action in actions:
		Input.action_press(action)
	for _i in frames:
		await get_tree().physics_frame
	for action in actions:
		Input.action_release(action)


func _place(p: Player, pos: Vector2) -> void:
	p.position = pos
	p.velocity = Vector2.ZERO


## Drops any ride link left over from a previous section so each one starts clean.
func _reset_links() -> void:
	for p: Player in [p1, p2]:
		p._set_support(null)
		p._riders.clear()
		p.velocity = Vector2.ZERO


## Whether `top` is riding `bottom`. The ride link is what counts, not contact:
## a rider deliberately ignores its supporter's collider during its own step, so
## there is no contact collision left for a floor query to find, and is_on_floor()
## is false for a perched rider by design.
func _rides(bottom: Player, top: Player) -> bool:
	return top._support == bottom and bottom._riders.has(top) \
		and absf((bottom.position.y - top.position.y) - PLAYER_H) < 2.0


## The body collider hangs below the node origin, spanning y-52 to y, rather than
## being centred on it, so the rects have to be built that way to be honest.
func _overlap_amount() -> float:
	var r1 := Rect2(p1.position - Vector2(PLAYER_W * 0.5, PLAYER_H), Vector2(PLAYER_W, PLAYER_H))
	var r2 := Rect2(p2.position - Vector2(PLAYER_W * 0.5, PLAYER_H), Vector2(PLAYER_W, PLAYER_H))
	var inter := r1.intersection(r2)
	return 0.0 if inter.size == Vector2.ZERO else minf(inter.size.x, inter.size.y)


## Stacks top on bottom at a clear x with no platform overhead. `at_x` is a
## parameter because a spot that is fine for a jump is not fine for a walk: the
## ledge at x=192 is out of jump range but stops a walking rider dead.
func _stack(top: Player, bottom: Player, at_x: float = CLEAR_X1) -> void:
	_reset_links()
	# Park both clear of their spawns and of each other, and let the physics server
	# catch up, before moving them to the spot under test. Teleporting one onto the
	# place the other is still standing in the physics server leaves the two
	# interpenetrating for a frame, and the engine separates them by shoving the
	# supporter sideways, which would then read as the rider not being over its
	# head or as a jump being blocked.
	_place(top, Vector2(PARK_X, GROUND_Y))
	_place(bottom, Vector2(PARK_X + PLAYER_W * 2.0, GROUND_Y))
	await _wait(3)
	_reset_links()
	_place(bottom, Vector2(at_x, GROUND_Y))
	_place(top, Vector2(at_x + 200.0, GROUND_Y))
	var n := [0]
	var mon := RideMonitor.new()
	mon.sample = func() -> void:
		var f: int = n[0]
		n[0] += 1
		if f > 70:
			return
		var hits: Array[String] = []
		for i in bottom.get_slide_collision_count():
			var c := bottom.get_slide_collision(i)
			var who: Object = c.get_collider()
			var who_name := "?"
			if who is Node:
				who_name = (who as Node).name
			hits.append("%s[n=%.2f,pos=%s]" % [who_name, c.get_normal().y, (who as Node2D).position if who is Node2D else "-"])
		_emit("    [t%02d] bottom(%s) x=%.2f y=%.2f vx=%.2f | top(%s) x=%.2f y=%.2f  hits=[%s]" % [
			f, bottom.label_text, bottom.position.x, bottom.position.y, bottom.velocity.x,
			top.label_text, top.position.x, top.position.y, ", ".join(hits)])
	level.add_child(mon)
	await _wait(12)
	_place(top, Vector2(at_x, GROUND_Y - PLAYER_H - 40.0))
	await _wait(50)
	mon.queue_free()
	_emit("    [stack] top(%s).x=%.2f y=%.2f   bottom(%s).x=%.2f y=%.2f" % [
		top.label_text, top.position.x, top.position.y,
		bottom.label_text, bottom.position.x, bottom.position.y])


func _faces_right(p: Player) -> bool:
	return p.sprite.flip_h


## Bottom player jumps; returns how the pair behaved over the whole arc.
##
## Measuring from a coroutine is not good enough here: the two players are
## physics-processed in turn, and a coroutine resumed on physics_frame can land
## in between them, showing the supporter already moved while its rider has not
## been placed yet. A monitor node parented after the players is stepped after
## both of them, so it only ever sees a fully resolved pair.
func _bottom_jumps(bottom: Player, top: Player, action: StringName) -> Dictionary:
	var start_bottom := bottom.position.y
	var start_top := top.position.y
	var stats := {
		"peak_bottom": start_bottom,
		"peak_top": start_top,
		"max_gap": 0.0,
		"max_overlap": 0.0,
		"max_drift": 0.0,
		"max_dx": 0.0,
	}

	var seen := [0]
	var mon := RideMonitor.new()
	mon.name = "RideMonitor"
	mon.sample = func() -> void:
		seen[0] += 1
		if seen[0] <= 2:
			return
		var gap: float = bottom.position.y - top.position.y
		stats["peak_bottom"] = minf(stats["peak_bottom"], bottom.position.y)
		stats["peak_top"] = minf(stats["peak_top"], top.position.y)
		stats["max_gap"] = maxf(stats["max_gap"], gap)
		stats["max_overlap"] = maxf(stats["max_overlap"], _overlap_amount())
		# How far the rider strayed from the spot it rides at. This, rather than
		# is_on_floor(), is what proves it stayed standing: being carried moves the
		# rider directly, so the engine's floor flag is not meaningful here.
		stats["max_drift"] = maxf(stats["max_drift"], absf(gap + top._ride_offset))
		stats["max_dx"] = maxf(stats["max_dx"], absf(bottom.position.x - top.position.x))
	# Parented after the players, so the engine steps it after both of them.
	level.add_child(mon)

	await _hold([action], 2)
	while seen[0] < 112:
		await get_tree().physics_frame
	mon.queue_free()

	return {
		"rise_bottom": start_bottom - stats["peak_bottom"],
		"rise_top": start_top - stats["peak_top"],
		"max_gap": stats["max_gap"],
		"max_overlap": stats["max_overlap"],
		"max_drift": stats["max_drift"],
		"max_dx": stats["max_dx"],
		"end_gap": bottom.position.y - top.position.y,
		"stacked_end": _rides(bottom, top),
		"bottom_y": bottom.position.y,
		"top_y": top.position.y,
		"bottom_x": bottom.position.x,
		"top_x": top.position.x,
	}


func _run() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var players_node: Node = level.get_node("Players")
	var kids: Array[Node] = players_node.get_children()
	p1 = kids[0] as Player
	p2 = kids[1] as Player

	_emit("")
	_emit("=== 1. P1 stands on P2, then P2 jumps -> P1 carried up ===")
	await _stack(p1, p2)
	_check("pre-jump: P1 rests on P2", _rides(p2, p1), " p1.y=%.2f p2.y=%.2f" % [p1.position.y, p2.position.y])
	var r := await _bottom_jumps(p2, p1, &"p2_jump")
	_emit("    P2 rise=%.1f  P1 rise=%.1f  max gap=%.1f  max overlap=%.2f  max dx=%.2f  sup.x=%.2f top.x=%.2f" % [r["rise_bottom"], r["rise_top"], r["max_gap"], r["max_overlap"], r["max_dx"], r["bottom_x"], r["top_x"]])
	_check("P2 actually jumped", r["rise_bottom"] > 90.0, " rise=%.1f" % r["rise_bottom"])
	_check("P1 was carried upward too", r["rise_top"] > r["rise_bottom"] * 0.75, " P1 rise=%.1f vs P2 %.1f" % [r["rise_top"], r["rise_bottom"]])
	_check("P1 stayed on P2 during the jump (never left behind)", r["max_gap"] < MAX_STACK_GAP, " max gap=%.1f (uncarried would be ~%.0f)" % [r["max_gap"], PLAYER_H + 128.0])
	_check("P1 never interpenetrated P2", r["max_overlap"] < 1.0, " max overlap=%.2f" % r["max_overlap"])
	_check("P1 stayed latched to P2 (never sank off its head)", r["max_drift"] <= 6.0, " max drift=%.2fpx (uncarried would be ~180)" % r["max_drift"])
	_check("still stacked after landing", r["stacked_end"] and absf(r["end_gap"] - PLAYER_H) < 2.0, " gap=%.2f p1.y=%.2f p2.y=%.2f" % [r["end_gap"], r["top_y"], r["bottom_y"]])
	_check("both back on the ground", absf(p1.position.y - (GROUND_Y - PLAYER_H)) < 2.0 and absf(p2.position.y - GROUND_Y) < 1.0, " p1.y=%.2f p2.y=%.2f" % [p1.position.y, p2.position.y])

	_emit("")
	_emit("=== 2. P2 stands on P1, then P1 jumps -> P2 carried up ===")
	await _stack(p2, p1)
	_check("pre-jump: P2 rests on P1", _rides(p1, p2), " p1.y=%.2f p2.y=%.2f" % [p1.position.y, p2.position.y])
	r = await _bottom_jumps(p1, p2, &"p1_jump")
	_emit("    P1 rise=%.1f  P2 rise=%.1f  max gap=%.1f  max overlap=%.2f" % [r["rise_bottom"], r["rise_top"], r["max_gap"], r["max_overlap"]])
	_check("P1 actually jumped", r["rise_bottom"] > 90.0, " rise=%.1f" % r["rise_bottom"])
	_check("P2 was carried upward too", r["rise_top"] > r["rise_bottom"] * 0.75, " P2 rise=%.1f vs P1 %.1f" % [r["rise_top"], r["rise_bottom"]])
	_check("P2 stayed on P1 during the jump (never left behind)", r["max_gap"] < MAX_STACK_GAP, " max gap=%.1f" % r["max_gap"])
	_check("P2 never interpenetrated P1", r["max_overlap"] < 1.0, " max overlap=%.2f" % r["max_overlap"])
	_check("P2 stayed latched to P1 (never sank off its head)", r["max_drift"] <= 6.0, " max drift=%.2fpx (uncarried would be ~180)" % r["max_drift"])
	_check("still stacked after landing", r["stacked_end"] and absf(r["end_gap"] - PLAYER_H) < 2.0, " gap=%.2f p1.y=%.2f p2.y=%.2f" % [r["end_gap"], r["top_y"], r["bottom_y"]])

	_emit("")
	_emit("=== 3. top player moves away -> separate normally ===")
	# Stacked at x=800: a walk from x=160 runs into the ledge that starts at
	# x=192, which stops the rider for reasons that have nothing to do with riding.
	await _stack(p2, p1, CLEAR_X2)
	var top_x := p2.position.x
	await _hold([&"p2_right"], 30)
	_check("P2 walked off P1's head", p2.position.x > top_x + 40.0, " x %.1f -> %.1f" % [top_x, p2.position.x])
	_check("P2 fell to the ground on its own", p2.is_on_floor() and absf(p2.position.y - GROUND_Y) < 1.0, " y=%.2f" % p2.position.y)
	_check("P2 faces right after walking off", _faces_right(p2))
	_check("P1 never moved", absf(p1.position.x - CLEAR_X2) < 1.0 and absf(p1.position.y - GROUND_Y) < 1.0, " x=%.2f y=%.2f" % [p1.position.x, p1.position.y])

	_emit("")
	_emit("=== 4. top player jumps separately -> leaves the stack ===")
	await _stack(p2, p1)
	var p2_start := p2.position.y
	await _hold([&"p2_jump"], 2)
	var rose := false
	var escaped := false
	for _i in 30:
		await get_tree().physics_frame
		if p2.position.y < p2_start - 40.0:
			rose = true
		if rose and p2.position.y < p1.position.y - PLAYER_H - 5.0:
			escaped = true
			break
	_check("P2 jumped on its own", rose, " y %.1f -> %.1f" % [p2_start, p2.position.y])
	_check("P2 rose above P1 (broke out of the stack)", escaped, " p1.y=%.2f p2.y=%.2f" % [p1.position.y, p2.position.y])
	await _wait(70)
	# A jump straight up lands back on the head it left, which is correct. What
	# matters is that it settled onto a real surface rather than hanging in mid-air.
	_check("P2 came down onto something solid",
		p2.is_on_floor() or _rides(p1, p2), " y=%.2f on_floor=%s on_p1=%s" % [
			p2.position.y, str(p2.is_on_floor()), str(_rides(p1, p2))])
	_check("P1 unaffected and grounded", absf(p1.position.y - GROUND_Y) < 1.0, " y=%.2f" % p1.position.y)

	_emit("")
	_emit("=== 5. independent jumps when NOT stacked ===")
	_reset_links()
	_place(p1, Vector2(CLEAR_X1, GROUND_Y))
	_place(p2, Vector2(CLEAR_X2, GROUND_Y))
	await _wait(45)
	_check("both on the ground, not stacked", absf(p1.position.y - GROUND_Y) < 1.0 and absf(p2.position.y - GROUND_Y) < 1.0)
	await _hold([&"p1_jump", &"p2_jump"], 2)
	var b1 := GROUND_Y
	var b2 := GROUND_Y
	var r1 := 0.0
	var r2 := 0.0
	for _i in 40:
		await get_tree().physics_frame
		r1 = maxf(r1, b1 - p1.position.y)
		r2 = maxf(r2, b2 - p2.position.y)
	_check("P1 jumped alone", r1 > 90.0, " rise=%.1f" % r1)
	_check("P2 jumped alone", r2 > 90.0, " rise=%.1f" % r2)
	await _wait(60)
	_check("both landed", p1.is_on_floor() and p2.is_on_floor(), " p1.y=%.2f p2.y=%.2f" % [p1.position.y, p2.position.y])

	_emit("")
	_emit("=== 6. not permanently attached or stuck ===")
	# Walk apart freely, then confirm a fresh stack still forms afterwards.
	await _hold([&"p1_left"], 40)
	_check("P1 walked away left", p1.position.x < CLEAR_X1 - 40.0, " x=%.1f" % p1.position.x)
	_check("P1 not glued to P2", absf(p1.position.x - p2.position.x) > 100.0, " dx=%.1f" % absf(p1.position.x - p2.position.x))
	_check("P1 on the ground, not floating", p1.is_on_floor() and absf(p1.position.y - GROUND_Y) < 1.0, " y=%.2f" % p1.position.y)
	await _stack(p2, p1)
	_check("a fresh stack still forms after separating", _rides(p1, p2), " p1.y=%.2f p2.y=%.2f" % [p1.position.y, p2.position.y])
	# Push towards each other out in open ground. Starting them against the left
	# wall just pins the one being pushed into the wall.
	_place(p1, Vector2(FAR_X, GROUND_Y))
	_place(p2, Vector2(FAR_X + PLAYER_W, GROUND_Y))
	await _wait(20)
	var min_gap := 9999.0
	for _i in 60:
		Input.action_press(&"p1_right")
		Input.action_press(&"p2_left")
		await get_tree().physics_frame
		min_gap = minf(min_gap, p2.position.x - p1.position.x)
	Input.action_release(&"p1_right")
	Input.action_release(&"p2_left")
	await _wait(40)
	_check("still solid side-to-side", p2.position.x > p1.position.x, " p1.x=%.1f p2.x=%.1f" % [p1.position.x, p2.position.x])
	_check("no interpenetration", _overlap_amount() < 0.5, " overlap=%.2f" % _overlap_amount())

	_emit("")
	_emit("=== 7. regression: controls, facing, gravity, platforms ===")
	_reset_links()
	_place(p1, Vector2(CLEAR_X1, GROUND_Y))
	_place(p2, Vector2(CLEAR_X2, GROUND_Y))
	await _wait(45)
	var x1 := p1.position.x
	await _hold([&"p1_right"], 20)
	_check("P1 D moves right and faces right", p1.position.x > x1 + 40.0 and _faces_right(p1), " dx=%.1f flip=%s" % [p1.position.x - x1, p1.sprite.flip_h])
	x1 = p1.position.x
	await _hold([&"p1_left"], 20)
	_check("P1 A moves left and faces left", p1.position.x < x1 - 40.0 and not _faces_right(p1), " dx=%.1f flip=%s" % [p1.position.x - x1, p1.sprite.flip_h])
	var x2 := p2.position.x
	await _hold([&"p2_right"], 20)
	_check("P2 Right arrow moves right and faces right", p2.position.x > x2 + 40.0 and _faces_right(p2), " dx=%.1f flip=%s" % [p2.position.x - x2, p2.sprite.flip_h])
	x2 = p2.position.x
	await _hold([&"p2_left"], 20)
	_check("P2 Left arrow moves left and faces left", p2.position.x < x2 - 40.0 and not _faces_right(p2), " dx=%.1f flip=%s" % [p2.position.x - x2, p2.sprite.flip_h])
	_check("artwork unchanged", p1.sprite.texture.resource_path.ends_with("Cat1.png") and p2.sprite.texture.resource_path.ends_with("Cat2.png"))
	_check("no overlap after walking into each other", _overlap_amount() < 0.5, " overlap=%.2f" % _overlap_amount())
	_place(p1, Vector2(4.0 * 64.0 + 32.0, 8.0 * 56.0 - 30.0))
	await _wait(50)
	_check("platform collision intact", p1.is_on_floor() and absf(p1.position.y - 8.0 * 56.0) < 1.5, " y=%.2f" % p1.position.y)
	# A jump from a standing start on the ground must still reach full height.
	_place(p1, Vector2(CLEAR_X1, GROUND_Y))
	await _wait(30)
	await _hold([&"p1_jump"], 2)
	var solo := 0.0
	for _i in 40:
		await get_tree().physics_frame
		solo = maxf(solo, GROUND_Y - p1.position.y)
	_check("solo jump height unchanged", solo > 90.0, " rise=%.1f" % solo)

	_emit("")
	_emit("=".repeat(52))
	if failures.is_empty():
		_emit("ALL CHECKS PASSED")
	else:
		_emit("FAILURES (%d): %s" % [failures.size(), ", ".join(failures)])
	_emit("=".repeat(52))
	get_tree().quit(0 if failures.is_empty() else 1)
