extends Node2D

## Checks for the four levels added on 2026-10-14: Spring 2, Summer 2, Autumn 1 and
## Winter 1. Every season goes short level first, long level second, so the new
## Spring and Summer levels are the long level 2s, and the new Autumn and Winter
## levels are the short level 1s.
##
## Each one is built from its real scene file, exactly as the game builds it, and
## driven with the real controls. For every level this proves:
##   1. it really is the right level - its stage, the layout from its STAGE_ tables,
##      the right width, walls at both edges, and a camera whose limits are the
##      world's own edges;
##   2. the camera scrolls in the long levels (Spring 2, Summer 2) and stays still
##      in the short ones (Autumn 1, Winter 1), and the completion screen of a long
##      level is in a UI layer so it cannot scroll away;
##   3. every collectable is reachable the way its table comment says it is - from a
##      shelf, or only by stacking - and NOT from the place that comment says it is
##      out of reach from. Each claim is tested by parking the players and pressing
##      jump, never by arithmetic;
##   4. bringing everything to its goal finishes the level, and nothing less does;
##   5. the completion screen comes up with the Next Level button wired to the
##      level's handler, and the level knows which level comes next.
##
## The real press of each Next Level button is proven by tests/_season_chain_test,
## because pressing it here would change the scene out from under this test.

const SPRING2_SCENE := "res://scenes/SpringLevel2.tscn"
const SUMMER2_SCENE := "res://scenes/SummerLevel2.tscn"
const AUTUMN1_SCENE := "res://scenes/AutumnLevel.tscn"
const WINTER1_SCENE := "res://scenes/WinterLevel.tscn"
## Where the two short level 1s lead: the long Autumn and Winter levels.
const AUTUMN2_SCENE := "res://scenes/AutumnLevel2.tscn"
const WINTER2_SCENE := "res://scenes/WinterLevel2.tscn"

## The four season scripts. They have no class_name, so they are named here.
const SPRING_GD := preload("res://scenes/Level.gd")
const SUMMER_GD := preload("res://scenes/SummerLevel.gd")
const AUTUMN_GD := preload("res://scenes/AutumnLevel.gd")
const WINTER_GD := preload("res://scenes/WinterLevel.gd")

const GROUND_Y := 560.0
const PLAYER_H := 52.0
const SCREEN_W := 1280.0
## The three shelf heights the levels use, by name, so a trial reads as a sentence.
const FLOOR := 560.0
const LOW := 448.0
const MID := 336.0
const TOP := 224.0

var level: Node2D
var p1: Player
var p2: Player
## Where the player who is not taking part in a trial waits, out of the way.
var away := Vector2(150.0, GROUND_Y - 1.0)

var failures: Array[String] = []
var _elapsed := 0.0


func _ready() -> void:
	_run.call_deferred()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > 300.0:
		_emit("WATCHDOG: aborted after %.0fs" % _elapsed)
		get_tree().quit(2)


func _run() -> void:
	_check_the_enter_key()
	await _test_spring2()
	await _test_summer2()
	await _test_autumn1()
	await _test_winter1()
	_finish(failures.is_empty())


# ------------------------------------------------------------------- Spring 2


func _test_spring2() -> void:
	_emit("=== 1. Spring 2: the long meadow ===")
	await _load(SPRING2_SCENE)
	away = Vector2(150.0, GROUND_Y - 1.0)
	_check_the_frame(SPRING_GD, "spring", 2)
	await _check_enter_waits_for_the_finish()
	await _check_the_camera_scrolls()

	var items := _children_of_type(level.garden, "GardenItem")
	var soil: GardenItem = _by_kind(items, &"soil")
	var seeds: GardenItem = _by_kind(items, &"seeds")
	var water: GardenItem = _by_kind(items, &"water")
	_check("there are exactly three things to find: soil, seeds and water",
		items.size() == 3 and soil != null and seeds != null and water != null)

	_emit("-- reaching each one --")
	await _reach(soil, "the soil", Vector2(512, FLOOR), false, false)
	await _reach(soil, "the soil", Vector2(512, LOW), false, true)
	await _reach(seeds, "the seeds", Vector2(2048, FLOOR), false, false)
	await _reach(seeds, "the seeds", Vector2(2048, TOP), false, true)
	await _reach(water, "the water", Vector2(2976, MID), false, false)
	await _reach(water, "the water", Vector2(2976, MID), true, true)

	_emit("-- two cats at the pot at once --")
	var pot := _children_of_type(level.garden, "PlantPot")[0] as PlantPot
	pot.grow_time = 0.5
	# The co-op route: both cats arrive carrying, and the one with the seeds happens
	# to be standing in the pot too. The soil must still go in, then the seeds.
	await _pick_up(p1, soil)
	await _pick_up(p2, seeds)
	_park(p2, Vector2(pot.position.x - 10.0, GROUND_Y - 1.0))
	_park(p1, Vector2(pot.position.x + 10.0, GROUND_Y - 1.0))
	await _wait(12)
	_check("the cat holding the seeds does not block the soil, and then the seeds go in too",
		pot.stage == PlantPot.Stage.SEEDED and p1.carried_kind == &"" and p2.carried_kind == &"",
		" stage=%s p1=%s p2=%s" % [pot.stage, p1.carried_kind, p2.carried_kind])
	_park(p2, away)

	_check("the flower has not grown and the level is not finished before the water",
		not level._banner_shown and level._banner_timer < 0.0)
	await _pick_up(p1, water)
	_park(p1, Vector2(pot.position.x, GROUND_Y - 1.0))
	await _wait(6)
	await _wait(int((pot.grow_time + 0.2) * 60.0))
	_check("the water grows the flower", pot.stage == PlantPot.Stage.FLOWER)
	await _check_the_completion_screen()
	_check("and after Spring 2 comes Summer",
		_const("SUMMER_SCENE") == "res://scenes/SummerLevel.tscn"
		and _const("STAGE_2_SCENE") == SPRING2_SCENE)
	_emit("")


# ------------------------------------------------------------------- Summer 2


func _test_summer2() -> void:
	_emit("=== 2. Summer 2: the long beach with six pieces of rubbish ===")
	await _load(SUMMER2_SCENE)
	away = Vector2(150.0, GROUND_Y - 1.0)
	_check_the_frame(SUMMER_GD, "summer", 2)
	await _check_enter_waits_for_the_finish()
	await _check_the_camera_scrolls()

	var pieces := _children_of_type(level.trash, "GardenItem")
	var bins := _children_of_type(level.bins, "TrashBin")
	var kinds := {}
	for piece: GardenItem in pieces:
		kinds[piece.item_kind] = int(kinds.get(piece.item_kind, 0)) + 1
	_check("there are six pieces of rubbish, two of each kind",
		pieces.size() == 6 and kinds.get(&"paper") == 2 and kinds.get(&"plastic") == 2
		and kinds.get(&"glass") == 2, " %s" % str(kinds))
	var all_take_two := bins.size() == 3
	for bin: TrashBin in bins:
		all_take_two = all_take_two and bin.capacity == 2 and bin.sorted_count == 0
	_check("there are three bins and each one takes two", all_take_two)
	var leftmost_bin := INF
	var rightmost_bin := -INF
	for bin: TrashBin in bins:
		leftmost_bin = minf(leftmost_bin, bin.position.x)
		rightmost_bin = maxf(rightmost_bin, bin.position.x)
	var left := 0
	var right := 0
	for piece: GardenItem in pieces:
		if piece.position.x < leftmost_bin:
			left += 1
		elif piece.position.x > rightmost_bin:
			right += 1
	_check("the bins are in the middle, with three pieces on each side of them",
		left == 3 and right == 3, " left=%d right=%d" % [left, right])

	_emit("-- reaching each one --")
	await _reach(pieces[0], "the first paper", Vector2(384, FLOOR), false, false)
	await _reach(pieces[0], "the first paper", Vector2(384, LOW), false, true)
	await _reach(pieces[1], "the first glass", Vector2(960, FLOOR), false, false)
	await _reach(pieces[1], "the first glass", Vector2(960, MID), false, true)
	await _reach(pieces[2], "the first plastic", Vector2(1280, LOW), false, true, false)
	await _reach(pieces[3], "the second plastic", Vector2(2496, FLOOR), false, false)
	await _reach(pieces[3], "the second plastic", Vector2(2496, LOW), false, true)
	await _reach(pieces[4], "the second paper", Vector2(3232, FLOOR), false, false)
	await _reach(pieces[4], "the second paper", Vector2(3232, TOP), false, true)
	await _reach(pieces[5], "the second glass", Vector2(3584, MID), false, false)
	await _reach(pieces[5], "the second glass", Vector2(3584, MID), true, true)

	_emit("-- sorting --")
	var by_kind := {}
	for bin: TrashBin in bins:
		by_kind[bin.accepts_kind] = bin
	# A wrong bin first: nothing is taken and the dog keeps the paper.
	await _pick_up(p1, pieces[0])
	_park(p1, Vector2((by_kind[&"glass"] as TrashBin).position.x, GROUND_Y - 1.0))
	await _wait(8)
	_check("the glass bin refuses paper, and says so",
		p1.carried_kind == &"paper" and (by_kind[&"glass"] as TrashBin).sorted_count == 0
		and level.wrong_bin_label.visible)
	_check("the Wrong bin! notice is on screen in the UI layer",
		level.wrong_bin_label.get_parent() is CanvasLayer)

	for index in pieces.size():
		var piece: GardenItem = pieces[index]
		if p1.carried_kind == &"":
			await _pick_up(p1, piece)
		_park(p1, Vector2((by_kind[piece.item_kind] as TrashBin).position.x, GROUND_Y - 1.0))
		await _wait(8)
		_park(p1, away)
		await _wait(2)
		if index == pieces.size() - 2:
			_check("after five pieces the level is not finished yet",
				not level._banner_shown and level._banner_timer < 0.0)
	var all_full := true
	for bin: TrashBin in bins:
		all_full = all_full and bin.sorted_count == 2 and bin.is_filled
	_check("every bin now holds two pieces and is full", all_full)
	await _check_the_completion_screen()
	_check("and after Summer 2 comes Autumn",
		_const("NEXT_SCENE") == "res://scenes/AutumnLevel.tscn"
		and _const("STAGE_2_SCENE") == SUMMER2_SCENE)
	_emit("")


# ------------------------------------------------------------------- Autumn 1


func _test_autumn1() -> void:
	_emit("=== 3. Autumn 1: one screen, three leaves, three frames ===")
	await _load(AUTUMN1_SCENE)
	away = Vector2(1100.0, GROUND_Y - 1.0)
	_check_the_frame(AUTUMN_GD, "autumn", 1)
	await _check_enter_waits_for_the_finish()
	await _check_the_camera_stays_still()

	var leaves := _children_of_type(level.leaves, "GardenItem")
	var frames := _children_of_type(level.frames, "LeafFrame")
	_check("there are three leaves and three frames",
		leaves.size() == 3 and frames.size() == 3)
	var apart := true
	for index in range(1, frames.size()):
		var gap: float = absf(frames[index].position.x - frames[index - 1].position.x) - 84.0
		apart = apart and gap > 60.0
	_check("the frames' boxes leave more than a fox's width between them", apart)
	var on_screen := true
	for frame: LeafFrame in frames:
		var drawn := frame.drawn_rect()
		on_screen = on_screen and drawn.position.x >= 16.0 and drawn.end.x <= SCREEN_W - 16.0
	_check("every frame is drawn fully on screen, inside the walls", on_screen)

	var leaf1: GardenItem = _by_kind(leaves, &"leaf1")
	var leaf2: GardenItem = _by_kind(leaves, &"leaf2")
	var leaf3: GardenItem = _by_kind(leaves, &"leaf3")
	_emit("-- reaching each one --")
	await _reach(leaf1, "leaf 1", Vector2(96, FLOOR), false, false, false)
	await _reach(leaf1, "leaf 1", Vector2(96, FLOOR), false, true)
	await _reach(leaf3, "leaf 3", Vector2(416, FLOOR), false, false)
	await _reach(leaf3, "leaf 3", Vector2(416, LOW), false, true)
	await _reach(leaf2, "leaf 2", Vector2(608, MID), false, false)
	await _reach(leaf2, "leaf 2", Vector2(608, MID), true, true)

	_emit("-- placing --")
	var frame_for := {}
	for frame: LeafFrame in frames:
		frame_for[frame.accepts_kind] = frame
	await _pick_up(p1, leaf1)
	_park(p1, Vector2((frame_for[&"leaf3"] as LeafFrame).position.x, GROUND_Y - 1.0))
	await _wait(8)
	_check("a leaf in the wrong frame is refused, and the fox keeps it",
		p1.carried_kind == &"leaf1" and not (frame_for[&"leaf3"] as LeafFrame).is_filled)
	# Counted, not compared: a placed leaf is freed, and a freed leaf must not be
	# compared against the next one.
	var placed := 0
	for leaf: GardenItem in [leaf1, leaf3, leaf2]:
		var kind := leaf.item_kind
		if p1.carried_kind == &"":
			await _pick_up(p1, leaf)
		_park(p1, Vector2((frame_for[kind] as LeafFrame).position.x, GROUND_Y - 1.0))
		await _wait(8)
		_park(p1, away)
		await _wait(2)
		placed += 1
		if placed == 2:
			_check("after two leaves the level is not finished yet",
				not level._banner_shown and level._banner_timer < 0.0)
	var all_filled := true
	for frame: LeafFrame in frames:
		all_filled = all_filled and frame.is_filled
	_check("every frame now holds its leaf", all_filled)
	await _check_the_completion_screen()
	_check("and after Autumn 1 comes Autumn 2, the long walk",
		_const("STAGE_2_SCENE") == AUTUMN2_SCENE and ResourceLoader.exists(AUTUMN2_SCENE))
	_emit("")


# ------------------------------------------------------------------- Winter 1


func _test_winter1() -> void:
	_emit("=== 4. Winter 1: one screen, two icicles, two fish, the igloo ===")
	await _load(WINTER1_SCENE)
	away = Vector2(100.0, GROUND_Y - 1.0)
	_check_the_frame(WINTER_GD, "winter", 1)
	await _check_enter_waits_for_the_finish()
	await _check_the_camera_stays_still()

	var fishes: Array = level._fish_nodes
	var icicles: Array = level._icicle_nodes
	_check("there are two fish and two icicles", fishes.size() == 2 and icicles.size() == 2)
	var clear := true
	for one: Fish in fishes:
		for ic: Icicle in icicles:
			clear = clear and absf(ic.position.x - one.position.x) > 150.0
	_check("no fish is anywhere near an icicle's drop line", clear)
	var ice := 0
	for tile in level.terrain.get_children():
		if (tile as GroundTile).slippery:
			ice += 1
	_check("there is ice", ice == 5, " ice tiles=%d" % ice)

	_emit("-- reaching each fish --")
	await _reach(fishes[0], "fish 1", Vector2(640, FLOOR), false, false)
	await _reach(fishes[0], "fish 1", Vector2(640, LOW), false, true)
	await _reach(fishes[1], "fish 2", Vector2(230, FLOOR), false, false)
	await _reach(fishes[1], "fish 2", Vector2(230, FLOOR), true, true)

	_emit("-- an icicle sends everybody back --")
	_reset_winter_bits()
	await _wait(4)
	_park(p1, (fishes[0] as Fish).position + Vector2(0.0, 26.0))
	await _wait(6)
	_check("a penguin takes fish 1", (fishes[0] as Fish).is_collected)
	_park(p1, Vector2((icicles[1] as Icicle).position.x, GROUND_Y - 1.0))
	_park(p2, Vector2(1180.0, GROUND_Y - 1.0))
	var reset_seen := false
	for _i in 240:
		await get_tree().physics_frame
		if p1.global_position.x < 300.0 and p2.global_position.x < 300.0:
			reset_seen = true
			break
	await _wait(6)
	_check("standing under the second icicle gets both penguins sent back to the start",
		reset_seen, " p1=%s p2=%s" % [p1.global_position, p2.global_position])
	_check("and fish 1 is back, so nothing is lost for good",
		not (fishes[0] as Fish).is_collected and level._collected_fish.is_empty())

	_emit("-- the igloo --")
	_reset_winter_bits()
	await _wait(4)
	var igloo_x: float = level.igloo.position.x
	_park(p1, Vector2(igloo_x - 30.0, GROUND_Y - 1.0))
	_park(p2, Vector2(igloo_x + 30.0, GROUND_Y - 1.0))
	await _wait(10)
	_check("both penguins in the igloo without the fish does not finish the level",
		not level._banner_shown and level._banner_timer < 0.0)
	_park(p1, (fishes[0] as Fish).position + Vector2(0.0, 26.0))
	await _wait(6)
	_park(p1, (fishes[1] as Fish).position + Vector2(0.0, 26.0))
	await _wait(6)
	_check("both fish are collected", level._collected_fish.size() == 2)
	_check("with only one penguin in the igloo it still is not finished",
		not level._banner_shown and level._banner_timer < 0.0)
	_park(p1, Vector2(igloo_x - 30.0, GROUND_Y - 1.0))
	await _wait(10)
	await _check_the_completion_screen()
	_check("and after Winter 1 comes Winter 2, the long way home",
		_const("STAGE_2_SCENE") == WINTER2_SCENE and ResourceLoader.exists(WINTER2_SCENE))
	_emit("")


func _reset_winter_bits() -> void:
	for ic: Icicle in level._icicle_nodes:
		ic.reset()
	for one: Fish in level._fish_nodes:
		one.reset()
	level._collected_fish.clear()
	level.igloo.reset()


# ------------------------------------------------------------------- shared checks


## Builds a level from its scene file, freeing the one before it.
func _load(path: String) -> void:
	if level != null:
		level.queue_free()
		await _wait(4)
	_check("%s exists" % path.get_file(), ResourceLoader.exists(path))
	level = (load(path) as PackedScene).instantiate()
	add_child(level)
	await get_tree().process_frame
	var cats: Array[Player] = []
	for child in level.players.get_children():
		if child is Player:
			cats.append(child as Player)
	p1 = cats[0]
	p2 = cats[1]
	await _wait(10)


## What every new level must be: the right stage, built from that stage's tables
## (STAGE_1_* or STAGE_2_*), walled at both ends of its own width, with a camera
## clamped to that width and a pause menu in the right season.
func _check_the_frame(script: Script, season: String, stage: int) -> void:
	var tables := script.get_script_constant_map()
	var prefix := "STAGE_%d_" % stage
	var width: int = tables[prefix + "WIDTH"]
	_check("it is level %d of its season" % stage, level.stage == stage)
	_check("it is built %dpx wide from its %s tables" % [width, prefix],
		level.level_width == width and level.platform_rows == tables[prefix + "PLATFORM_ROWS"])
	_check("the camera's limits are the world's own edges",
		level.camera.limit_left == 0 and level.camera.limit_right == width)
	var walls: Array = level.walls.get_children()
	_check("there is a wall at each end of the world",
		walls.size() == 2 and is_equal_approx((walls[1] as Node2D).position.x, width - 16.0))
	var floor_tiles := 0
	for tile in level.terrain.get_children():
		if is_equal_approx((tile as Node2D).position.y, GROUND_Y):
			floor_tiles += 1
	_check("the floor runs unbroken from wall to wall", floor_tiles == width / 64,
		" floor tiles=%d" % floor_tiles)
	var pause := level.get_node_or_null("PauseMenu") as PauseMenu
	_check("it has a pause menu in %s's colours" % season,
		pause != null and pause.season == season)
	_check("the completion screen starts hidden and the button inert",
		not level.level_complete_banner.visible and not level.next_level_button.visible
		and level.next_level_button.disabled)
	var banner_parent: Node = level.level_complete_banner.get_parent()
	if width > SCREEN_W:
		_check("the banner and the button are in a UI layer, so they cannot scroll away",
			banner_parent is CanvasLayer and level.next_level_button.get_parent() is CanvasLayer)
	_check("both players start on the floor at the left",
		p1.global_position.x < 300.0 and p2.global_position.x < 300.0
		and absf(p1.global_position.y - GROUND_Y) < 3.0)


## Enter and keypad Enter are the next_level key, and nothing else is.
func _check_the_enter_key() -> void:
	_emit("=== 0. the Enter key ===")
	var keys: Array[int] = []
	for event in InputMap.action_get_events(&"next_level"):
		if event is InputEventKey:
			keys.append((event as InputEventKey).physical_keycode)
	_check("there is a next_level action, on Enter and keypad Enter",
		InputMap.has_action(&"next_level") and keys.size() == 2
		and keys.has(KEY_ENTER) and keys.has(KEY_KP_ENTER), " keys=%s" % str(keys))
	_emit("")


## Enter is also P2's jump, so pressing it during play must only make P2 jump. If it
## moved on to the next level instead, the scene change would free this test and the
## run would end with no verdict at all - which the runner reports as a failure.
func _check_enter_waits_for_the_finish() -> void:
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	Input.parse_input_event(enter)
	await _wait(6)
	var release := enter.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	await _wait(30)
	_check("Enter during play does not leave the level",
		is_instance_valid(level) and level.is_inside_tree()
		and not level.next_level_button.visible)


func _check_the_camera_scrolls() -> void:
	var width: float = level.level_width
	_check("the camera starts on the players, at the left-hand end",
		is_equal_approx(level.camera.get_screen_center_position().x, SCREEN_W * 0.5))
	_park(p1, Vector2(width - 150.0, GROUND_Y - 1.0))
	_park(p2, Vector2(width - 250.0, GROUND_Y - 1.0))
	await _wait(150)
	var centre: Vector2 = level.camera.get_screen_center_position()
	_check("walking to the far end takes the camera with them, up to the right edge",
		absf(centre.x - (width - SCREEN_W * 0.5)) <= 1.0, " centre=%s" % centre)
	_check("the camera stays on whole pixels",
		level.camera.global_position.x == roundf(level.camera.global_position.x))
	_check("and it never moves up or down", is_equal_approx(centre.y, 360.0))
	_park(p1, Vector2(120.0, GROUND_Y - 1.0))
	_park(p2, Vector2(232.0, GROUND_Y - 1.0))
	await _wait(150)
	_check("and walking back brings it back",
		absf(level.camera.get_screen_center_position().x - SCREEN_W * 0.5) <= 1.0)


func _check_the_camera_stays_still() -> void:
	_park(p1, Vector2(SCREEN_W - 120.0, GROUND_Y - 1.0))
	_park(p2, Vector2(SCREEN_W - 200.0, GROUND_Y - 1.0))
	await _wait(60)
	var centre: Vector2 = level.camera.get_screen_center_position()
	_check("the whole level fits on one screen, so the camera never moves",
		is_equal_approx(centre.x, SCREEN_W * 0.5) and is_equal_approx(centre.y, 360.0),
		" centre=%s" % centre)
	_park(p1, Vector2(120.0, GROUND_Y - 1.0))
	_park(p2, Vector2(232.0, GROUND_Y - 1.0))
	await _wait(6)


## Waits out the level's banner pause and checks the completion screen came up.
func _check_the_completion_screen() -> void:
	_check("finishing starts the pause before the banner, and the banner waits for it",
		level._banner_timer >= 0.0 or level._banner_shown)
	await _wait(int((level.complete_banner_delay + 0.3) * 60.0))
	_check("then the Level Complete picture and the Next Level button come up together",
		level.level_complete_banner.visible and level.next_level_button.visible
		and not level.next_level_button.disabled)
	_check("and the button is wired to the level's Next Level handler",
		level.next_level_button.pressed.is_connected(level._on_next_level_pressed))


## One reach trial. `stand` is the spot on a surface the jumping player starts from
## (its feet go on `stand.y`). With `stacked`, a second player stands on the first
## one's head and that top player jumps. With `jump` false, nobody jumps at all and
## the claim is about simply standing there. `expect` is the claim being proved:
## that the thing is taken, or that it is not.
func _reach(item: Node2D, label: String, stand: Vector2, stacked: bool, expect: bool,
		jump: bool = true) -> void:
	_reset_item(item)
	await _wait(30)
	var spot := Vector2(stand.x, stand.y - 1.0)
	_park(p2, away)
	_park(p1, spot)
	await _wait(10)
	if stacked:
		_park(p2, spot - Vector2(0.0, PLAYER_H))
		await _wait(24)
	if jump:
		await _hold([p2.jump_action if stacked else p1.jump_action], 90)
	await _wait(24)
	var taken: bool = item.get("is_collected")
	var how := "standing"
	if jump:
		how = "a stacked jump" if stacked else "one jump"
	var where := "the floor" if stand.y == FLOOR else "the shelf at y=%.0f" % stand.y
	_check("%s %s %s from %s" % [label, ("IS taken by" if expect else "is NOT taken by"),
		how, where], taken == expect, " taken=%s" % taken)
	_reset_item(item)
	_park(p1, away + Vector2(80.0, 0.0))
	_park(p2, away)
	await _wait(30)


## Puts a collectable back where it started, whichever kind it is.
func _reset_item(item: Node2D) -> void:
	for p: Player in [p1, p2]:
		p.drop_carried()
	if item is Fish:
		_reset_winter_bits()


## Picks a thing up by walking the player straight into it.
func _pick_up(p: Player, item: GardenItem) -> void:
	for _i in 60:
		if item._respawn_timer <= 0.0:
			break
		await get_tree().physics_frame
	_park(p, item.global_position + Vector2(0.0, 20.0))
	await _wait(5)
	_check("picked up the %s" % item.item_kind, p.carried_kind == item.item_kind,
		" carrying=%s" % p.carried_kind)


func _park(p: Player, spot: Vector2) -> void:
	if level.get_script() == WINTER_GD:
		for ic: Icicle in level._icicle_nodes:
			ic.reset()
	p.reset_to_position(spot)


func _children_of_type(holder: Node, type_name: String) -> Array:
	var found: Array = []
	for child in holder.get_children():
		if child.is_class(type_name) or (child.get_script() != null
				and child.get_script().get_global_name() == type_name):
			found.append(child)
	return found


func _by_kind(items: Array, kind: StringName) -> GardenItem:
	for item: GardenItem in items:
		if item.item_kind == kind:
			return item
	return null


func _const(name: String) -> Variant:
	return level.get_script().get_script_constant_map().get(name)


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


func _emit(line: String) -> void:
	print(line)


func _check(label: String, ok: bool, detail: String = "") -> bool:
	if ok:
		_emit("  PASS  %s %s" % [label, detail])
	else:
		failures.append(label)
		_emit("  FAIL  %s %s" % [label, detail])
	return ok


func _finish(ok: bool) -> void:
	_emit("")
	_emit("=".repeat(58))
	if ok:
		_emit("ALL CHECKS PASSED")
	else:
		_emit("FAILURES (%d): %s" % [failures.size(), ", ".join(failures)])
	_emit("")
	get_tree().quit(0 if ok else 1)
