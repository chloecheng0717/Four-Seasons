extends Node2D

## End-to-end check for the Season ending: a real Spring run to the flower, the
## flower given its pause before the completion screen, both the Level Complete
## picture and the Next Level button turning up together, and then the Next Level
## button being pressed, which leaves Spring for the Summer placeholder.
##
## A mouse click arrives at a TextureButton as its pressed signal, so the test
## first proves that signal really is connected to the level's handler and then
## presses it. Everything that runs from the signal onwards - the scene swap out
## of Spring and into Summer - is exactly what a real click does. (Synthetic
## mouse events are deliberately not used: the control tree under --headless
## never receives them, so a "real" click cannot be simulated that way.)
##
## Once the swap happens the Summer placeholder (scenes/SummerLevel.gd) notices
## the user argument "--next-level-check", prints "NEXT LEVEL REACHED SUMMER"
## and quits with exit code 0. This test never presses the button unless every
## check so far has passed, so a clean exit really does mean the whole flow
## worked.
##
## Note on the press: the transition frees this very scene, so after the button
## is pressed the test does not await anything - it stamps the time and lets its
## _process watchdog complain if it is somehow still alive later. A still-alive
## test means the press never changed the scene; a freed test means the Summer
## placeholder took over and quits with its own message.

const LEVEL_SCENE := "res://scenes/Level.tscn"
const SUMMER_SCENE := "res://scenes/SummerLevel.tscn"
const NEXT_TEXTURE := preload("res://assets/Next Level.png")

const GROUND_Y := 560.0
const POT_X := 900.0
const SCREEN := Rect2(0.0, 0.0, 1280.0, 720.0)
const PARK_A := Vector2(150.0, GROUND_Y)
const PARK_B := Vector2(1120.0, GROUND_Y)

var level: Node2D
var pot: PlantPot
var p1: Player
var p2: Player
var items: Dictionary = {}

var failures: Array[String] = []
var _elapsed := 0.0
var _flower_seen_at := 0
var _banner_on_flower_frame := true
var _press_timestamp_ms := 0
var _finished := false


func _ready() -> void:
	level = (load(LEVEL_SCENE) as PackedScene).instantiate()
	add_child(level)
	await get_tree().process_frame
	_gather()
	_run.call_deferred()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > 180.0:
		_emit("WATCHDOG: aborted")
		get_tree().quit(2)
	# If the button was pressed but this test is still running a moment later,
	# the scene never changed - so the press failed. Once the scene does change,
	# this node is freed and _process stops (the Summer placeholder then reports
	# the success itself), so there is no overlap.
	if _press_timestamp_ms > 0 and Time.get_ticks_msec() - _press_timestamp_ms > 500:
		_press_timestamp_ms = -1
		_emit("FAIL  still in Spring: pressing the Next Level button did nothing")
		failures.append("the Next Level press")
		_finish(false)


func _emit(line: String) -> void:
	print(line)


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


func _place(p: Player, pos: Vector2) -> void:
	p.position = pos
	p.velocity = Vector2.ZERO


func _gather() -> void:
	var cats: Array[Player] = []
	for child in level.garden.get_children():
		if child is PlantPot:
			pot = child as PlantPot
		elif child is GardenItem:
			items[(child as GardenItem).item_kind] = child
	for child in level.players.get_children():
		if child is Player:
			cats.append(child as Player)
	p1 = cats[0]
	p2 = cats[1]


func _park() -> void:
	for p: Player in [p1, p2]:
		p.drop_carried()
		p._set_support(null)
		p.velocity = Vector2.ZERO
		p.collision_mask = 3
	_place(p1, PARK_A)
	_place(p2, PARK_B)
	await _wait(6)


func _grab(p: Player, kind: StringName) -> GardenItem:
	var item: GardenItem = items[kind]
	for _i in 60:
		if item._respawn_timer <= 0.0:
			break
		await get_tree().physics_frame
	_place(p, item.position)
	await _wait(5)
	return item


func _deliver(p: Player) -> void:
	_place(p, Vector2(POT_X, GROUND_Y))
	await _wait(6)


func _flower_rect() -> Rect2:
	return Rect2(pot.position + pot.sprite.offset, pot.sprite.region_rect.size)


func _flower_is_showing() -> bool:
	if not pot.sprite.visible:
		return false
	if pot.sprite.texture != PlantPot.STAGE_TEXTURES[PlantPot.Stage.FLOWER]:
		return false
	return SCREEN.encloses(_flower_rect())


func _watch_for_flower() -> void:
	while pot.stage != PlantPot.Stage.FLOWER:
		await get_tree().process_frame
	_flower_seen_at = Time.get_ticks_msec()
	_banner_on_flower_frame = level.level_complete_banner.visible


func _since_flower() -> float:
	return float(Time.get_ticks_msec() - _flower_seen_at) / 1000.0


func _wait_until(seconds: float) -> void:
	var left: float = seconds - _since_flower()
	if left > 0.0:
		await get_tree().create_timer(left).timeout


func _run() -> void:
	await _test_the_stage_is_set()
	await _test_the_whole_run()
	if failures.is_empty():
		await _test_the_click_leaves_for_summer()
	# If the button was pressed, the level either changed scene (freeing this test,
	# with the Summer placeholder reporting success) or the _process watchdog
	# reports the failure; nothing may touch this node in between, and it is
	# already gone in the first case. If the press never happened then no scene
	# changed, so it is safe to finish here with the summary.
	if not _finished and _press_timestamp_ms == 0:
		_finish(failures.is_empty())


func _test_the_stage_is_set() -> void:
	_emit("=== 1. Summer has somewhere to go, and the button is out of the way ===")
	# Shorten the sprout growth so the test does not sit through the full 3s:
	# the pause before the banner is what matters, not the growing itself. It has
	# to be set before the water is delivered, which is when the pot starts its
	# timer.
	pot.grow_time = 0.5
	_check("the Summer scene file exists", ResourceLoader.exists(SUMMER_SCENE))
	_check("the Next Level button starts hidden", not level.next_level_button.visible)
	_check("and inert", level.next_level_button.disabled)
	_check("carrying the Next Level picture",
		level.next_level_button.texture_normal == NEXT_TEXTURE)
	_emit("")


func _test_the_whole_run() -> void:
	_emit("=== 2. a real Spring run: soil, seeds, then water ===")

	# Watch for the flower from before any of it happens, so the moment it grows
	# is measured truly rather than from whenever this test gets around to it.
	_watch_for_flower.call_deferred()

	# Soil fills the pot first.
	await _park()
	var soil: GardenItem = await _grab(p1, &"soil")
	await _deliver(p1)
	_check("the soil fills the pot", pot.stage == PlantPot.Stage.SOIL,
		" stage=%d" % pot.stage)
	_check("and is gone for good", not is_instance_valid(soil))

	# Then the seeds.
	await _park()
	var seeds: GardenItem = await _grab(p1, &"seeds")
	await _deliver(p1)
	_check("the seeds go in next", pot.stage == PlantPot.Stage.SEEDED,
		" stage=%d" % pot.stage)
	_check("and are gone for good", not is_instance_valid(seeds))

	# Last, the water. The co-op stacked jump that makes the high water reachable
	# is proven in _stack_jump_test; here the cat just stands on it the same way
	# the garden suite does.
	await _park()
	var water: GardenItem = await _grab(p1, &"water")
	await _deliver(p1)
	_check("the water makes a sprout", pot.stage == PlantPot.Stage.SPROUT,
		" stage=%d" % pot.stage)
	_check("and the water was used up", not is_instance_valid(water))

	_emit("")


func _test_the_click_leaves_for_summer() -> void:
	_emit("=== 3. the completion screen appears, then a click leaves for Summer ===")
	var delay: float = level.complete_banner_delay
	_check("the pause is the intended 1-2s", delay >= 1.0 and delay <= 2.0,
		" delay=%.2fs" % delay)

	# Give the sprout its short grow time to finish (wall-clock, so frame rate in
	# headless mode does not matter).
	await _wait_until_flower(2.0)

	_check("the flower grew, all on its own", pot.stage == PlantPot.Stage.FLOWER,
		" stage=%d" % pot.stage)
	_check("the banner is not up on the very frame the flower appeared",
		not _banner_on_flower_frame)
	_check("and it is on show by itself during the pause", _flower_is_showing())
	_check("the banner has not arrived yet", not level.level_complete_banner.visible,
		" %.2fs on" % _since_flower())
	_check("and the Next Level button is still out of the way",
		not level.next_level_button.visible and level.next_level_button.disabled)

	# Give the whole pause room to finish, then the completion screen must be up
	# showing both pictures.
	await _wait_until(delay + 0.3)
	_check("the Level Complete picture is up",
		level.level_complete_banner.visible
		and level.level_complete_banner.texture == preload("res://assets/Level Complete.png"))
	_check("and the button is up with it", level.next_level_button.visible
		and not level.next_level_button.disabled)

	var button: TextureButton = level.next_level_button
	var click_pos: Vector2 = button.get_global_rect().get_center()
	# The button is placed low and to the right on purpose, so the check is that
	# its middle lands inside the screen - that is where the click goes.
	_check("the button's middle is on the screen", SCREEN.has_point(click_pos),
		" centre=%s" % click_pos)
	_check("and its pressed signal is really wired to the level's handler",
		button.pressed.is_connected(level._on_next_level_pressed))
	if not failures.is_empty():
		# Nothing has been pressed, so the scene cannot change and it is safe to
		# finish here rather than leave the outcome to the _process watchdog.
		_finish(false)
		return

	# A mouse click arrives at a TextureButton as its pressed signal, and this
	# is exactly that signal - what runs from here on is identical to a real
	# click. Pushing raw synthetic mouse events cannot reach the control tree
	# under --headless (verified), so the button is pressed through its own
	# signal instead. Nothing is awaited after it: the scene change frees this
	# node, so the press's outcome is left to the _process watchdog.
	button.pressed.emit()
	_press_timestamp_ms = Time.get_ticks_msec()


func _wait_until_flower(seconds: float) -> void:
	var started := Time.get_ticks_msec()
	while pot.stage != PlantPot.Stage.FLOWER \
			and float(Time.get_ticks_msec() - started) < seconds * 1000.0:
		await get_tree().process_frame


func _finish(ok: bool) -> void:
	# Guarded so that finishing through two different paths can only print and
	# quit once.
	if _finished:
		return
	_finished = true
	_emit("")
	_emit("=".repeat(58))
	if ok:
		_emit("ALL CHECKS PASSED")
	else:
		_emit("FAILURES (%d): %s" % [failures.size(), ", ".join(failures)])
	_emit("=".repeat(58))
	get_tree().quit(0 if ok else 1)
