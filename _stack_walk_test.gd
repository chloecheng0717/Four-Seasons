extends Node2D

## Regression suite for "the bottom cat cannot walk while the top cat stands on
## it". Everything is measured with a monitor node parented after the players, so
## a sample only ever sees a pair whose physics have both already run this step.

class RideMonitor:
	extends Node2D
	var sample: Callable

	func _physics_process(_delta: float) -> void:
		if sample.is_valid():
			sample.call()


const PLAYER_H := 52.0
const PLAYER_W := 60.0
const GROUND_Y := 560.0
# 800 is a ground tile centre with no platform overhead and no wall nearby: the
# cat spans 770..830, clear of the ledge that ends at 768 and the one starting at
# 832. Stacking or walking anywhere else risks a platform edge reading as a
# movement failure.
const CLEAR_X := 800.0
# Somewhere on the flat ground that no section stacks at, used to park the two
# players apart from each other before a stack is built.
const PARK_X := 250.0
const FAR_X := 400.0
# One frame of walking is 260/60 = 4.33px, so 20 frames is ~87px.
const WALK_20 := 60.0

var level: Node2D
var p1: Player
var p2: Player
var failures: Array[String] = []
var _elapsed := 0.0
var _log: FileAccess


func _ready() -> void:
	_log = FileAccess.open("user://stack_walk_test.log", FileAccess.WRITE)
	level = (load("res://scenes/Level.tscn") as PackedScene).instantiate()
	add_child(level)
	_run.call_deferred()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > 180.0:
		_emit("WATCHDOG: aborted")
		get_tree().quit(2)


func _emit(line: String) -> void:
	print(line)
	if _log != null:
		_log.store_line(line)
		_log.flush()


func _check(label: String, ok: bool, detail: String = "") -> bool:
	if ok:
		_emit("  PASS  %s %s" % [label, detail])
	else:
		failures.append(label)
		_emit("  FAIL  %s %s" % [label, detail])
	return ok


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


func _reset_links() -> void:
	for p: Player in [p1, p2]:
		p._set_support(null)
		p._riders.clear()
		p.velocity = Vector2.ZERO


## The body collider hangs below the node origin, spanning y-52 to y.
func _overlap() -> float:
	var r1 := Rect2(p1.position - Vector2(PLAYER_W * 0.5, PLAYER_H), Vector2(PLAYER_W, PLAYER_H))
	var r2 := Rect2(p2.position - Vector2(PLAYER_W * 0.5, PLAYER_H), Vector2(PLAYER_W, PLAYER_H))
	var inter := r1.intersection(r2)
	return 0.0 if inter.size == Vector2.ZERO else minf(inter.size.x, inter.size.y)


## Drops `top` onto `bottom` at a given x and waits for the pair to settle.
## Both are parked clear of each other and of where they are coming from first.
## Teleporting one onto the spot the other is still standing in makes the two
## interpenetrate for a frame, and the engine can latch a ride link out of that
## overlap, which silently hands the test an upside down stack.
func _stack(top: Player, bottom: Player, at_x: float = CLEAR_X) -> void:
	_reset_links()
	_place(top, Vector2(PARK_X, GROUND_Y))
	_place(bottom, Vector2(PARK_X + PLAYER_W, GROUND_Y))
	await _wait(3)
	_reset_links()
	_place(bottom, Vector2(at_x, GROUND_Y))
	_place(top, Vector2(at_x + 200.0, GROUND_Y))
	await _wait(12)
	_place(top, Vector2(at_x, GROUND_Y - PLAYER_H - 40.0))
	await _wait(50)


## Walks `p` for `frames` and reports how far it got, plus anything it overlapped.
## GDScript lambdas capture locals by value, so anything the sampler writes has
## to live in a single element array to be visible out here.
func _walk(p: Player, action: StringName, frames: int = 20) -> Dictionary:
	var from := p.position
	var max_overlap := [0.0]
	var mon := RideMonitor.new()
	mon.sample = func() -> void:
		max_overlap[0] = maxf(max_overlap[0], _overlap())
	level.add_child(mon)
	await _hold([action], frames)
	mon.queue_free()
	await _wait(2)
	return {
		"dx": p.position.x - from.x,
		"from": from,
		"to": p.position,
		"overlap": max_overlap[0],
	}


## Whether `top` is riding `bottom`. The ride link is what counts, not contact:
## a rider deliberately ignores its supporter's collider during its own step, so
## there is no contact collision left for a floor query to find.
func _stacked(bottom: Player, top: Player) -> bool:
	return top._support == bottom and bottom._riders.has(top) \
		and absf((bottom.position.y - top.position.y) - PLAYER_H) < 2.0


func _run() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var kids: Array[Node] = (level.get_node("Players") as Node).get_children()
	p1 = kids[0] as Player
	p2 = kids[1] as Player

	_emit("")
	_emit("=== 1. P1 stands on P2 -> P2 can move left and right ===")
	await _stack(p1, p2)
	_check("P1 rests on P2", _stacked(p2, p1),
		" p1.y=%.2f p2.y=%.2f" % [p1.position.y, p2.position.y])
	var p2_right := &"p2_right"
	var p2_left := &"p2_left"
	var r := await _walk(p2, p2_right)
	_check("P2 (bottom) walked right", r["dx"] > WALK_20,
		" dx=%.2f  x %.1f -> %.1f" % [r["dx"], r["from"].x, r["to"].x])
	_check("P2 was not shoved sideways by the rider", absf(r["to"].y - GROUND_Y) < 1.5,
		" y=%.2f" % r["to"].y)
	_check("no interpenetration while walking", r["overlap"] < 0.5,
		" overlap=%.2f" % r["overlap"])
	await _stack(p1, p2)
	r = await _walk(p2, p2_left)
	_check("P2 (bottom) walked left", r["dx"] < -WALK_20,
		" dx=%.2f  x %.1f -> %.1f" % [r["dx"], r["from"].x, r["to"].x])

	_emit("")
	_emit("=== 2. P2 stands on P1 -> P1 can move left and right ===")
	await _stack(p2, p1)
	_check("P2 rests on P1", _stacked(p1, p2),
		" p1.y=%.2f p2.y=%.2f" % [p1.position.y, p2.position.y])
	r = await _walk(p1, &"p1_right")
	_check("P1 (bottom) walked right", r["dx"] > WALK_20,
		" dx=%.2f  x %.1f -> %.1f" % [r["dx"], r["from"].x, r["to"].x])
	_check("P1 was not shoved sideways by the rider", absf(r["to"].y - GROUND_Y) < 1.5,
		" y=%.2f" % r["to"].y)
	await _stack(p2, p1)
	r = await _walk(p1, &"p1_left")
	_check("P1 (bottom) walked left", r["dx"] < -WALK_20,
		" dx=%.2f  x %.1f -> %.1f" % [r["dx"], r["from"].x, r["to"].x])

	_emit("")
	_emit("=== 3. the top player is carried along by the walking bottom player ===")
	# Built out at x=400, away from the ledge, so the walk is not cut short by the
	# level. The stack is formed at the position it will be walked from rather than
	# moved there afterwards, which would pull the rider off the supporter's head.
	var walk_x := FAR_X + 100.0
	await _stack(p2, p1, walk_x)
	if _check("P2 starts out on P1's head for the carry test",
			_stacked(p1, p2), " P1=(%.1f,%.2f) P2=(%.1f,%.2f)" % [
				p1.position.x, p1.position.y, p2.position.x, p2.position.y]):
		var start_gap := p1.position.y - p2.position.y
		var start_top := p2.position
		r = await _walk(p1, &"p1_right", 24)
		var moved_top := p2.position.x - start_top.x
		_check("P1 (bottom) walked right", r["dx"] > 100.0, " dx=%.2f" % r["dx"])
		_check("P2 (top) rode along with P1", moved_top > 80.0,
			" top moved %.2f  (bottom moved %.2f)" % [moved_top, r["dx"]])
		_check("P2 stayed on P1's head, still stacked", _stacked(p1, p2),
			" gap=%.2f (was %.2f) p1.y=%.2f p2.y=%.2f" % [
				p1.position.y - p2.position.y, start_gap,
				p1.position.y, p2.position.y])
		_check("P2 stayed one body height above P1",
			absf((p1.position.y - p2.position.y) - PLAYER_H) < 2.0,
			" gap=%.2f" % (p1.position.y - p2.position.y))
		_check("P2 kept its footing on the way (never sank in)", _overlap() < 0.5,
			" overlap=%.2f" % _overlap())

	_emit("")
	_emit("=== 4. the top player can move away on its own ===")
	await _stack(p2, p1)
	var top_x := p2.position.x
	r = await _walk(p2, &"p2_right", 30)
	_check("P2 (top) walked right off P1's head", p2.position.x > top_x + 40.0,
		" x %.1f -> %.1f (dx=%.2f)" % [top_x, p2.position.x, r["dx"]])
	_check("P2 fell to the ground by itself",
		p2.is_on_floor() and absf(p2.position.y - GROUND_Y) < 1.5, " y=%.2f" % p2.position.y)
	_check("P2 faces right after walking off", p2.sprite.flip_h)
	_check("P2 is no longer linked to P1", p1._riders.is_empty() and p2._support == null,
		" p1.riders=%d p2.support=%s" % [p1._riders.size(), p2._support])
	await _stack(p2, p1)
	top_x = p2.position.x
	r = await _walk(p2, &"p2_left", 30)
	_check("P2 (top) walked left off P1's head", p2.position.x < top_x - 40.0,
		" x %.1f -> %.1f (dx=%.2f)" % [top_x, p2.position.x, r["dx"]])
	_check("P2 fell to the ground on the left too",
		p2.is_on_floor() and absf(p2.position.y - GROUND_Y) < 1.5, " y=%.2f" % p2.position.y)

	_emit("")
	_emit("=== 4b. the top player can jump off on its own ===")
	# A rider is grounded by its supporter, not by contact with it, so this checks
	# the coyote path a perched rider takes rather than a floor collision.
	for pair: Array in [[p1, p2, &"p1_jump"], [p2, p1, &"p2_jump"]]:
		var top: Player = pair[0]
		var bottom: Player = pair[1]
		var jump: StringName = pair[2]
		await _stack(top, bottom)
		# Assert the setup first, so a stack that failed to form is reported as
		# that rather than as a jump that did not happen.
		if not _check("%s starts out on %s's head" % [top.label_text, bottom.label_text],
				_stacked(bottom, top), " %s=(%.1f,%.2f) %s=(%.1f,%.2f) sup=%s rid=%d" % [
					top.label_text, top.position.x, top.position.y,
					bottom.label_text, bottom.position.x, bottom.position.y,
					"none" if top._support == null else top._support.label_text,
					bottom._riders.size()]):
			continue
		var top_start := top.position.y
		await _hold([jump], 2)
		var rose := [false]
		var escaped := [false]
		for _i in 34:
			await get_tree().physics_frame
			if top.position.y < top_start - 40.0:
				rose[0] = true
			if rose[0] and top.position.y < bottom.position.y - PLAYER_H - 5.0:
				escaped[0] = true
				break
		_check("%s (top) jumped on its own off %s" % [top.label_text, bottom.label_text],
			rose[0], " y %.1f -> %.1f" % [top_start, top.position.y])
		_check("%s rose clear of %s" % [top.label_text, bottom.label_text], escaped[0],
			" %s.y=%.2f %s.y=%.2f" % [top.label_text, top.position.y,
				bottom.label_text, bottom.position.y])
		_check("%s is no longer linked to %s" % [top.label_text, bottom.label_text],
			top._support == null and not bottom._riders.has(top))
		await _wait(80)
		# A straight up jump lands back on the same head it left, which is correct
		# and not a failure. What matters is that it settled onto a real surface
		# rather than being left hovering in mid-air.
		var on_ground := top.is_on_floor() and absf(top.position.y - GROUND_Y) < 1.5
		var back_on_head := _stacked(bottom, top)
		_check("%s came down onto something solid" % top.label_text,
			on_ground or back_on_head,
			" y=%.2f ground=%s back_on_head=%s" % [top.position.y, str(on_ground),
				str(back_on_head)])
		_check("%s unaffected and still grounded" % bottom.label_text,
			absf(bottom.position.y - GROUND_Y) < 1.5, " y=%.2f" % bottom.position.y)

	_emit("")
	_emit("=== 5. players still collide with each other ===")
	_reset_links()
	_place(p1, Vector2(FAR_X, GROUND_Y))
	_place(p2, Vector2(FAR_X + PLAYER_W, GROUND_Y))
	await _wait(25)
	_check("both on the ground, not stacked",
		absf(p1.position.y - GROUND_Y) < 1.0 and absf(p2.position.y - GROUND_Y) < 1.0,
		" p1.y=%.2f p2.y=%.2f" % [p1.position.y, p2.position.y])
	_check("neither is riding the other", p1._riders.is_empty() and p2._riders.is_empty())
	Input.action_press(&"p1_right")
	Input.action_press(&"p2_left")
	var min_gap := [9999.0]
	var pushed := [0]
	var mon := RideMonitor.new()
	mon.sample = func() -> void:
		min_gap[0] = minf(min_gap[0], p2.position.x - p1.position.x)
		pushed[0] = maxi(pushed[0], int(_overlap() > 0.5))
	level.add_child(mon)
	for _i in 60:
		await get_tree().physics_frame
	Input.action_release(&"p1_right")
	Input.action_release(&"p2_left")
	mon.queue_free()
	await _wait(30)
	_check("pushed apart, neither walked through the other", min_gap[0] > PLAYER_W - 1.0,
		" closest gap=%.2f" % min_gap[0])
	_check("P1 never ended up right of P2", p2.position.x > p1.position.x,
		" p1.x=%.1f p2.x=%.1f" % [p1.position.x, p2.position.x])
	_check("they never interpenetrated", pushed[0] == 0, " overlapping frames=%d" % pushed[0])
	_check("both still on the ground", p1.is_on_floor() and p2.is_on_floor())

	_emit("")
	_emit("=== 6. players can still stack, and can still jump ===")
	# Solo jump height, for reference.
	_reset_links()
	_place(p1, Vector2(CLEAR_X, GROUND_Y))
	await _wait(30)
	await _hold([&"p1_jump"], 2)
	var solo := 0.0
	for _i in 40:
		await get_tree().physics_frame
		solo = maxf(solo, GROUND_Y - p1.position.y)
	_check("P1 solo jump unchanged", solo > 90.0, " rise=%.1f" % solo)
	await _wait(70)
	_check("P1 landed", p1.is_on_floor() and absf(p1.position.y - GROUND_Y) < 1.5,
		" y=%.2f" % p1.position.y)

	# Stacked jump: the bottom player must get its full height with a rider on
	# its head, and the rider must come along.
	for pair: Array in [[p2, p1, &"p1_jump"], [p1, p2, &"p2_jump"]]:
		var top: Player = pair[0]
		var bottom: Player = pair[1]
		var jump: StringName = pair[2]
		await _stack(top, bottom)
		var rise_bottom := [0.0]
		var rise_top := [0.0]
		var base_bottom := bottom.position.y
		var base_top := top.position.y
		var overlap := [0.0]
		var stack_gap := [0.0]
		# The monitor is installed before the jump is pressed, and the press is
		# held across a physics frame, so the ascent is sampled from its first
		# frame rather than from a frame that starts after it.
		mon = RideMonitor.new()
		mon.sample = func() -> void:
			rise_bottom[0] = maxf(rise_bottom[0], base_bottom - bottom.position.y)
			rise_top[0] = maxf(rise_top[0], base_top - top.position.y)
			overlap[0] = maxf(overlap[0], _overlap())
			stack_gap[0] = maxf(stack_gap[0], bottom.position.y - top.position.y)
		level.add_child(mon)
		await _hold([jump], 2)
		for _i in 108:
			await get_tree().physics_frame
		mon.queue_free()
		await _wait(40)
		_check("%s (bottom) jumped with a rider on its head" % bottom.label_text,
			rise_bottom[0] > 90.0, " rise=%.1f" % rise_bottom[0])
		_check("%s was carried up too" % top.label_text, rise_top[0] > rise_bottom[0] * 0.75,
			" top rise=%.1f vs bottom %.1f" % [rise_top[0], rise_bottom[0]])
		_check("%s stayed on %s, never left behind" % [top.label_text, bottom.label_text],
			stack_gap[0] < 80.0, " max gap=%.1f" % stack_gap[0])
		_check("no interpenetration during the jump", overlap[0] < 1.0,
			" overlap=%.2f" % overlap[0])
		_check("still stacked after landing",
			_stacked(bottom, top) and absf((bottom.position.y - top.position.y) - PLAYER_H) < 2.0,
			" gap=%.2f %s.y=%.2f %s.y=%.2f" % [
				bottom.position.y - top.position.y,
				top.label_text, top.position.y, bottom.label_text, bottom.position.y])

	_emit("")
	_emit("=== 7. neither player gets stuck against the other ===")
	# Stacked, bottom walks into the level wall: it must stop at the wall, not
	# against the other cat, and the pair must still separate afterwards.
	# Formed at x=120 rather than walked there, so the rider is on the head before
	# the walk starts.
	await _stack(p1, p2, 120.0)
	r = await _walk(p2, &"p2_left", 40)
	_check("P2 walked left into the wall", r["dx"] < -40.0, " dx=%.2f" % r["dx"])
	_check("P2 stopped at the wall, not short of it",
		p2.position.x - PLAYER_W * 0.5 <= 16.5, " x=%.2f" % p2.position.x)
	_check("P1 is still standing on P2's head", _stacked(p2, p1),
		" p1.y=%.2f p2.y=%.2f" % [p1.position.y, p2.position.y])
	r = await _walk(p2, &"p2_right", 30)
	_check("P2 walked back right away from the wall", r["dx"] > 40.0, " dx=%.2f" % r["dx"])
	_check("P1 rode along, still on top", _stacked(p2, p1) and _overlap() < 0.5,
		" p1.y=%.2f p2.y=%.2f overlap=%.2f" % [p1.position.y, p2.position.y, _overlap()])

	_emit("")
	_emit("=== 8. nothing is glued together after separating ===")
	_reset_links()
	_place(p1, Vector2(CLEAR_X, GROUND_Y))
	_place(p2, Vector2(CLEAR_X - 200.0, GROUND_Y))
	await _wait(30)
	_check("both grounded and unlinked",
		p1.is_on_floor() and p2.is_on_floor()
		and p1._riders.is_empty() and p2._riders.is_empty()
		and p1._support == null and p2._support == null)
	await _stack(p2, p1)
	_check("a fresh stack forms again after separating", _stacked(p1, p2),
		" p1.y=%.2f p2.y=%.2f" % [p1.position.y, p2.position.y])
	# And a fresh stack can be broken again.
	await _walk(p2, &"p2_left", 30)
	_check("and can be broken again", not _stacked(p1, p2), " p2.y=%.2f" % p2.position.y)

	_emit("")
	_emit("=== 9. controls, facing, artwork, platforms unchanged ===")
	_reset_links()
	_place(p1, Vector2(CLEAR_X, GROUND_Y))
	_place(p2, Vector2(CLEAR_X - 200.0, GROUND_Y))
	await _wait(30)
	var x1 := p1.position.x
	await _hold([&"p1_right"], 20)
	_check("P1 D moves right and faces right",
		p1.position.x > x1 + 40.0 and p1.sprite.flip_h,
		" dx=%.1f flip=%s" % [p1.position.x - x1, p1.sprite.flip_h])
	x1 = p1.position.x
	await _hold([&"p1_left"], 20)
	_check("P1 A moves left and faces left",
		p1.position.x < x1 - 40.0 and not p1.sprite.flip_h,
		" dx=%.1f flip=%s" % [p1.position.x - x1, p1.sprite.flip_h])
	var x2 := p2.position.x
	await _hold([&"p2_right"], 20)
	_check("P2 Right arrow moves right and faces right",
		p2.position.x > x2 + 40.0 and p2.sprite.flip_h,
		" dx=%.1f flip=%s" % [p2.position.x - x2, p2.sprite.flip_h])
	x2 = p2.position.x
	await _hold([&"p2_left"], 20)
	_check("P2 Left arrow moves left and faces left",
		p2.position.x < x2 - 40.0 and not p2.sprite.flip_h,
		" dx=%.1f flip=%s" % [p2.position.x - x2, p2.sprite.flip_h])
	_check("artwork unchanged",
		p1.sprite.texture.resource_path.ends_with("Cat1.png")
		and p2.sprite.texture.resource_path.ends_with("Cat2.png"))
	_check("player masks are back to full collision",
		p1.collision_mask == 3 and p2.collision_mask == 3,
		" p1.mask=%d p2.mask=%d" % [p1.collision_mask, p2.collision_mask])
	# Row 8, columns 3..6 -> a ledge whose top is 448.
	_place(p1, Vector2(4.0 * 64.0 + 32.0, 8.0 * 56.0 - 30.0))
	await _wait(50)
	_check("platform collision intact",
		p1.is_on_floor() and absf(p1.position.y - 8.0 * 56.0) < 1.5, " y=%.2f" % p1.position.y)

	_emit("")
	_emit("=".repeat(58))
	if failures.is_empty():
		_emit("ALL CHECKS PASSED")
	else:
		_emit("FAILURES (%d): %s" % [failures.size(), ", ".join(failures)])
	_emit("=".repeat(58))
	get_tree().quit(0 if failures.is_empty() else 1)
