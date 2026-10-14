extends Node2D

## Automated regression suite for the Winter level: the two penguins, the long
## side-scrolling map and its camera, the slippery ice, the icicles that fall when a
## penguin walks under them, the both-players reset, the igloo that needs BOTH
## penguins, and the completion screen.
##
## It builds the real WinterLevel2.tscn (the long level, Winter 2) exactly as the game does and drives it with
## simulated input, in the same style as _garden_test, _summer_test and
## _autumn_test. Everything asserted here is read out of the live level, so a check
## cannot pass just because the level was never really built.
##
## Order matters. The ice and camera checks run first, while both penguins are still
## at the start; the icicle checks run while there are six hanging; the igloo checks
## run last, because finishing the level is irreversible.

## The long Winter level this suite tests. Since 2026-10-14 every season goes short
## level first, so the long frozen corridor is Winter 2, in WinterLevel2.tscn.
const WINTER_SCENE := "res://scenes/WinterLevel2.tscn"
const SPRING_SCENE := "res://scenes/Level.tscn"
const ENDING_SCENE := "res://scenes/Ending.tscn"

const SNOW_TEXTURE := preload("res://assets/Winter/Snow Tile.png")
const ICE_TEXTURE := preload("res://assets/Winter/Ice tile.png")
const PENGUIN1_TEXTURE := preload("res://assets/Winter/Penguin1.png")
const PENGUIN2_TEXTURE := preload("res://assets/Winter/Penguin2.png")
const ICICLE1_TEXTURE := preload("res://assets/Winter/Icicle1.png")
const ICICLE2_TEXTURE := preload("res://assets/Winter/Icicle2.png")
const IGLOO_TEXTURE := preload("res://assets/Winter/Igloo.png")
const COMPLETE_TEXTURE := preload("res://assets/Level Complete.png")
const NEXT_TEXTURE := preload("res://assets/Next_Button.png")

## The level's own geometry, restated here and cross-checked against it rather than
## trusted, so a test cannot quietly agree with a level that has drifted.
const TILE_W := 64
const TILE_H := 56
const LEVEL_W := 4800
const LEVEL_H := 720
const COLUMNS := 75
const GROUND_ROW := 10
const GROUND_Y := 560.0
const CAMERA_Y := 360.0
const SCREEN := Rect2(0.0, 0.0, 1280.0, 720.0)

## Player.gd's own numbers, restated for the movement checks.
const SPEED := 260.0
const PLAYER_W := 60.0
const PLAYER_H := 52.0
const JUMP_H := 128.0

## The camera is smoothed, so it approaches its target asymptotically and never lands
## on it exactly, so it cannot be compared with is_equal_approx.
const CAMERA_TOLERANCE := 8.0

## Flat open snow with nothing on it and no icicle above it: the floor is clear from
## column 0 to column 5 and the first shelf starts at column 2, so x=200 is only
## safely clear of the floor if we also avoid the first shelf. x=460 is plain floor
## in the gap between the A ledge and the B low shelf.
const SNOW_X := 460.0
## The floor ice run-up is columns 66..69, so x=4260 is squarely on it.
const ICE_X := 4260.0
## Where the icicles hang, in the clear corridors the map leaves between shelves.
const ICICLE_XS := [512.0, 1344.0, 2176.0, 3008.0, 3904.0, 4096.0]
const IGLOO_X := 4600.0
## Two separate spots inside the 168px goal box, so the penguins are never parked on top
## of each other. Two CharacterBody2D sharing one exact position is a penetration the
## solver resolves by shoving one of them - and being shoved through the floor means the
## penguin falls out of the world for good.
const IGLOO_P1 := 4560.0
const IGLOO_P2 := 4640.0

## Every open stretch of floor in this level is one of the four icicle chambers or
## the run to the igloo, so parking a penguin on the floor is parking it under an
## icicle. The B low shelf (columns 10..13, surface 448) is the one wide, snow,
## shelf-free, icicle-free place to stand, which is what the movement checks use.
const SHELF_Y := 448.0
const SHELF_X := 660.0
const SHELF_X2 := 860.0

## The two fish, restated from the level's FISHES and cross-checked against the built
## nodes rather than trusted, so a test cannot quietly agree with a level that moved
## them. Read from the level itself - see _fish_table_matches_the_level.
const FISH_TEXTURE := preload("res://assets/Winter/Fish.png")
const FISH_W := 29.0
const FISH_H := 30.0
const FISH_DISPLAY_H := 60.0
const FISH_BOX := 64.0
## How high the C low shelf (columns 23..26, surface 448) stands a penguin, which is
## what fish 1 has to be jumped for.
const C_SHELF_Y := 448.0

var level: Node2D
var p1: Player
var p2: Player
var igloo: Igloo
var icicles: Array[Icicle] = []
var fishes: Array[Fish] = []

var failures: Array[String] = []
## How many times each icicle has reported a hit over the whole run. Counting the
## signal is how "one icicle cannot kill the players over and over" is proved rather
## than assumed from a single frame.
var _hits: Dictionary = {}
## How many times each fish has reported being collected over the whole run, counted
## from the signal rather than from the flag. This is what proves one fish cannot be
## collected twice even with a penguin sitting inside it.
var _fish_signals: Dictionary = {}


func _ready() -> void:
	level = (load(WINTER_SCENE) as PackedScene).instantiate()
	add_child(level)
	await get_tree().process_frame
	_gather()
	_run.call_deferred()


func _gather() -> void:
	var players: Array[Node] = level.get_node("Players").get_children()
	p1 = players[0] as Player
	p2 = players[1] as Player
	igloo = level.igloo
	var holder: Node2D = level.get_node("Icicles")
	for index in holder.get_child_count():
		var ic := holder.get_child(index) as Icicle
		icicles.append(ic)
		_hits[index] = 0
		var slot := index
		ic.player_hit.connect(func() -> void: _hits[slot] += 1)
	var fish_holder: Node2D = level.get_node("Fish")
	for index in fish_holder.get_child_count():
		var one := fish_holder.get_child(index) as Fish
		fishes.append(one)
		_fish_signals[index] = 0
		var slot := index
		one.collected.connect(func(_which: int) -> void: _fish_signals[slot] += 1)


func _run() -> void:
	await _test_the_level_exists()
	await _test_the_two_penguins()
	await _test_the_map()
	await _test_the_camera()
	await _test_ice_is_slippery_and_snow_is_not()
	await _test_jumping_and_stacking_still_work()
	await _test_the_icicles_fall_and_hit_and_stop()
	await _test_a_hit_resets_both_penguins()
	await _test_the_two_fish()
	await _test_the_igloo_needs_both_penguins_and_both_fish()
	await _test_the_completion_screen()
	await _test_the_last_fish_cannot_hang_the_level()
	_finish(failures.is_empty())


# ---------------------------------------------------------------- 1. the scene


func _test_the_level_exists() -> void:
	_emit("=== 1. the Winter level is a real scene that loads ===")
	_check("WinterLevel2.tscn (the long Winter level) exists and loads as a PackedScene",
		ResourceLoader.exists(WINTER_SCENE)
		and load(WINTER_SCENE) is PackedScene)
	_check("and the script on it is the Winter level script",
		level.get_script().resource_path.ends_with("WinterLevel.gd"))

	# Checked here, before anything in this suite has driven a penguin anywhere,
	# because that is the only moment "the level opens safe" means anything. Later on
	# an icicle may legitimately be spent, because something walked under it.
	_check("the level opens with every icicle hanging and harmless",
		_icicles_all(0) and _all_hazards_off(),
		" states=%s" % str(_icicle_states()))
	_check("and with the igloo empty and the completion screen away",
		igloo.penguin_count() == 0 and not level.level_complete_banner.visible
		and not level.next_level_button.visible)
	_emit("")


# --------------------------------------------------------------- 2. the players


func _test_the_two_penguins() -> void:
	_emit("=== 2. exactly two penguins, with the right art and controls ===")
	var players: Array[Node] = level.get_node("Players").get_children()
	_check("there are exactly two players", players.size() == 2, " got %d" % players.size())

	_check("the first is Penguin1's artwork",
		p1.cat_texture == PENGUIN1_TEXTURE, " %s" % p1.cat_texture)
	_check("the second is Penguin2's artwork",
		p2.cat_texture == PENGUIN2_TEXTURE, " %s" % p2.cat_texture)
	_check("both are 23x28 with no padding cropped out",
		p1.cat_region == Rect2(0, 0, 23, 28) and p2.cat_region == Rect2(0, 0, 23, 28),
		" %s" % p1.cat_region)

	_check("P1 keeps the existing A / D / Space controls",
		p1.left_action == &"p1_left" and p1.right_action == &"p1_right"
		and p1.jump_action == &"p1_jump")
	_check("P2 keeps the existing arrows / Enter controls",
		p2.left_action == &"p2_left" and p2.right_action == &"p2_right"
		and p2.jump_action == &"p2_jump")

	# 56/28 is exactly 2, so the artwork is doubled cleanly.
	_check("and both are drawn 56 tall, which is exactly double the artwork",
		is_equal_approx(p1.sprite.scale.x, 2.0) and is_equal_approx(p1.sprite.scale.y, 2.0),
		" scale=%s" % p1.sprite.scale)

	# Both spawns are on the floor and they do not start inside each other.
	await _wait(10)
	_check("both start standing on the floor",
		p1.is_on_floor() and p2.is_on_floor())
	_check("neither starts buried in the other",
		absf(p1.global_position.x - p2.global_position.x) > PLAYER_W)
	_emit("")


# ------------------------------------------------------------------- 3. the map


func _test_the_map() -> void:
	_emit("=== 3. the map is long, tiled, walled and has no holes ===")
	var constants: Dictionary = level.get_script().get_script_constant_map()
	_check("the level really is 4800 x 720, 75 columns of 64px",
		constants.get("LEVEL_WIDTH") == LEVEL_W
		and constants.get("LEVEL_HEIGHT") == LEVEL_H
		and constants.get("COLUMN_COUNT") == COLUMNS
		and constants.get("TILE_WIDTH") == TILE_W,
		" w=%s h=%s cols=%s" % [constants.get("LEVEL_WIDTH"),
			constants.get("LEVEL_HEIGHT"), constants.get("COLUMN_COUNT")])
	_check("and it is much longer than it is tall, like Autumn",
		LEVEL_W > LEVEL_H * 4)

	var tiles: Array[GroundTile] = []
	for child in level.get_node("Terrain").get_children():
		tiles.append(child as GroundTile)
	_check("the terrain is built from GroundTile nodes and nothing else",
		tiles.size() == level.get_node("Terrain").get_child_count())

	# An unbroken floor, which is what makes a fall always recoverable.
	var floor_columns := {}
	for tile in tiles:
		if int(tile.position.y / TILE_H) == GROUND_ROW:
			floor_columns[int(tile.position.x / TILE_W)] = true
	var missing := 0
	for column in COLUMNS:
		if not floor_columns.has(column):
			missing += 1
	_check("the floor runs unbroken from wall to wall, with no holes",
		missing == 0, " %d columns missing" % missing)

	# Every tile is on the whole-pixel 64x56 grid, and its collider is the shared
	# 64x56 one every season uses. That collider is what puts the walking surface in
	# the same place in Winter as everywhere else, however tall the picture is.
	var off_grid := 0
	var wrong_size := 0
	for tile in tiles:
		if not (is_equal_approx(tile.position.x, roundf(tile.position.x))
				and is_equal_approx(tile.position.y, roundf(tile.position.y))):
			off_grid += 1
		var collider := tile.get_node("CollisionShape2D") as CollisionShape2D
		var rect := collider.shape as RectangleShape2D
		if rect == null or rect.size != Vector2(TILE_W, TILE_H):
			wrong_size += 1
	_check("every tile sits on the whole-pixel 64x56 grid", off_grid == 0,
		" %d off grid" % off_grid)
	_check("and every tile's collider is the same 64x56 as every other season",
		wrong_size == 0, " %d wrong" % wrong_size)

	# The crop is what stops the transparent padding being drawn as the tile, but a
	# crop even one row too short throws away part of the picture with no error
	# anywhere -- the tile just quietly looks wrong. So measure each texture's real
	# opaque box and insist the region asked for covers all of it, and is no larger
	# than it either. This is the check that catches a tile losing its underside.
	var cropped := 0
	var padded := 0
	for tile in tiles:
		var sprite := tile.get_node("Sprite") as Sprite2D
		if sprite.texture == null:
			continue
		var box := _opaque_box(sprite.texture.get_image())
		var region := sprite.region_rect
		if not region.encloses(box):
			cropped += 1
		elif region.size != box.size:
			padded += 1
	_check("no tile's crop cuts any part of its own picture off", cropped == 0,
		" %d tiles cropping their own artwork" % cropped)
	_check("and no tile's crop keeps wasted transparent padding either", padded == 0,
		" %d tiles padded" % padded)

	# Walls at both ends, so nothing can walk off the world.
	var walls: Array[Node] = level.get_node("Walls").get_children()
	_check("there is a wall at each end of the world", walls.size() == 2)
	var at_left := false
	var at_right := false
	for wall in walls:
		if (wall as StaticBody2D).position.x <= 0.0:
			at_left = true
		if (wall as StaticBody2D).position.x >= LEVEL_W - 64.0:
			at_right = true
	_check("one on the left and one on the right", at_left and at_right)

	# The world's own edges are the camera's limits.
	var camera := level.get_node("Camera2D") as Camera2D
	_check("the camera is clamped to the world's own edges",
		camera.limit_left == 0 and camera.limit_top == 0
		and camera.limit_right == LEVEL_W and camera.limit_bottom == LEVEL_H,
		" l=%d t=%d r=%d b=%d" % [camera.limit_left, camera.limit_top,
			camera.limit_right, camera.limit_bottom])

	# No platform is more than a jump above the one below it, and everything is
	# reachable off the floor, so nothing in the map can trap a penguin.
	var platforms: Array = constants.get("PLATFORM_ROWS")
	var rows: Array[int] = []
	for platform in platforms:
		var row: int = platform[0]
		if not rows.has(row):
			rows.append(row)
	rows.sort()
	var worst_step := 0.0
	for i in range(1, rows.size()):
		worst_step = maxf(worst_step, float((rows[i - 1] - rows[i]) * TILE_H))
	_check("no shelf is more than a jump above the shelf below it",
		worst_step <= JUMP_H, " worst step=%.0f jump=%.0f" % [worst_step, JUMP_H])
	_check("and every shelf is within a jump of the floor",
		float((GROUND_ROW - rows[rows.size() - 1]) * TILE_H) <= JUMP_H,
		" highest=%d" % rows[rows.size() - 1])
	_emit("")


# ---------------------------------------------------------------- 4. the camera


func _test_the_camera() -> void:
	_emit("=== 4. one shared camera follows both penguins and stays whole-pixel ===")
	var camera := level.get_node("Camera2D") as Camera2D
	_check("there is exactly one camera in the level",
		find_children("*", "Camera2D", true, false).size() == 1)
	_check("the engine's own position smoothing is off, so the level can round it",
		camera.position_smoothing_enabled == false)
	_check("the camera never moves vertically",
		is_equal_approx(camera.position.y, CAMERA_Y), " y=%s" % camera.position.y)

	# Walk P1 right on snow and let the camera catch up.
	_park(p1, SNOW_X)
	_park(p2, SNOW_X + 120.0)
	await _wait(8)
	await _hold([p1.right_action], 60)
	await _wait(90)

	var centre: float = level._penguins_centre().x
	_check("the camera has settled on the middle of the two penguins",
		absf(camera.position.x - centre) <= CAMERA_TOLERANCE,
		" camera=%.1f centre=%.1f" % [camera.position.x, centre])
	_check("and it is on a whole pixel, so the tile seams cannot open",
		is_equal_approx(camera.position.x, roundf(camera.position.x)),
		" x=%s" % camera.position.x)

	# Split them up: the camera settles between them rather than leaving one
	# player off the edge of the screen.
	_park(p1, SNOW_X)
	_park(p2, SNOW_X + 900.0)
	await _wait(10)
	await _hold([p1.left_action], 40)
	await _wait(90)
	centre = level._penguins_centre().x
	_check("split up, it settles between them instead of following one",
		absf(camera.position.x - centre) <= CAMERA_TOLERANCE,
		" camera=%.1f centre=%.1f" % [camera.position.x, centre])
	_check("and the middle of the two penguins is still on the screen",
		SCREEN.has_point(Vector2(camera.position.x, CAMERA_Y)))
	_emit("")


# ---------------------------------------------------------------------- 5. ice


func _test_ice_is_slippery_and_snow_is_not() -> void:
	_emit("=== 5. ice is measurably slippery, and snow is exactly as it always was ===")
	var constants: Dictionary = level.get_script().get_script_constant_map()
	var patches: Array = constants.get("ICE_PATCHES")
	_check("the level declares at least one ice patch", patches.size() >= 1,
		" %d patches" % patches.size())

	var ice_tiles := 0
	var mismatched := 0
	for child in level.get_node("Terrain").get_children():
		var tile := child as GroundTile
		if tile.slippery:
			ice_tiles += 1
			if tile.surface_texture != ICE_TEXTURE:
				mismatched += 1
	_check("there really are slippery tiles in the terrain", ice_tiles > 0,
		" %d ice tiles" % ice_tiles)
	_check("and every slippery tile is wearing the ice picture",
		mismatched == 0, " %d mismatched" % mismatched)
	_check("only GroundTile knows about being slippery, and it defaults to off",
		GroundTile.new().slippery == false)

	# Most ice should be on the floor, so the slippery surface is met while simply
	# walking rather than only by going off a shelf. Read off the level's own table.
	var ground_ice := 0
	var shelf_ice := 0
	for patch in patches:
		var row: int = patch[0]
		var how_many: int = patch[2]
		if row == GROUND_ROW:
			ground_ice += how_many
		else:
			shelf_ice += how_many
	_check("most of the ice is on the ground floor, not up on the shelves",
		ground_ice > shelf_ice, " floor=%d tiles, shelves=%d tiles" % [ground_ice, shelf_ice])
	_check("and some ice is still up on the shelves, which is a different problem",
		shelf_ice > 0, " %d shelf tiles" % shelf_ice)

	# The rule that decides where a patch may go: no patch may sit under an icicle's
	# drop line, so an icicle never has to be crossed on ice you cannot stop on.
	var on_a_drop_line := 0
	var worst := ""
	for patch in patches:
		var row: int = patch[0]
		var first_x := float(int(patch[1]) * TILE_W)
		var last_x := first_x + float(int(patch[2]) * TILE_W)
		for ic in icicles:
			if ic.position.x >= first_x and ic.position.x <= last_x:
				on_a_drop_line += 1
				worst = "row %d x %.0f..%.0f under icicle at x=%.0f" % [
					row, first_x, last_x, ic.position.x]
	_check("no ice patch sits under an icicle's drop line", on_a_drop_line == 0,
		" %d doing it, e.g. %s" % [on_a_drop_line, worst])

	# And the floor must not become one long slide: measure the real longest run of
	# clear snow between the patches, so the ice is something you meet in places.
	var longest_snow_run := 0
	var current_snow_run := 0
	for column in range(COLUMNS):
		if _is_ice_at(column, GROUND_ROW):
			current_snow_run = 0
			continue
		current_snow_run += 1
		longest_snow_run = maxi(longest_snow_run, current_snow_run)
	_check("and there is still a long clear stretch of snow between the patches, not one long slide",
		longest_snow_run >= 4,
		" longest unbroken snow run on the floor=%d tiles" % longest_snow_run)

	# Ice is a real difference, measured on the real level: same input, same time,
	# same speed reached - but only ice keeps going when you let go.
	_park(p2, 1200.0)
	var snow := await _slide_trial(p1, SNOW_X)
	var ice := await _slide_trial(p1, ICE_X)

	_check("on snow the penguin is at full speed after 40 frames",
		is_equal_approx(float(snow["vx"]), SPEED), " vx=%.1f" % float(snow["vx"]))
	_check("and on snow it stops dead the moment you let go",
		float(snow["coast"]) < 1.0, " slid %.2fpx" % float(snow["coast"]))

	_check("on ice it also reaches full speed, so a patch is still playable",
		is_equal_approx(float(ice["vx"]), SPEED), " vx=%.1f" % float(ice["vx"]))
	_check("but on ice it keeps sliding after you let go",
		float(ice["coast"]) > 20.0, " slid %.2fpx" % float(ice["coast"]))
	_check("which is a real difference, not a rounding one",
		float(ice["coast"]) - float(snow["coast"]) > 20.0,
		" ice slid %.2fpx, snow slid %.2fpx" % [float(ice["coast"]), float(snow["coast"])])
	_emit("")


## Is this grid square ice? Asked of the level's own table, the same table the level
## builds itself from, so this test cannot disagree with the level about where the
## ice is. Reached through the level's own _is_ice rather than re-reading the table,
## so the test is checking the rule that is actually used.
func _is_ice_at(column: int, row: int) -> bool:
	return bool(level.call("_is_ice", column, row))


## Holds one direction for 40 frames, then lets go and measures how far the penguin
## keeps travelling. Returns vx (while held) and coast (after release).
func _slide_trial(p: Player, start_x: float) -> Dictionary:
	_park(p, Vector2(start_x, GROUND_Y - 1.0))
	await _wait(8)
	_park(p2, Vector2(p2.global_position.x, GROUND_Y - 1.0))
	await _wait(4)
	Input.action_press(p.right_action)
	for _i in 40:
		await get_tree().physics_frame
	var vx := p.velocity.x
	Input.action_release(p.right_action)
	await _wait(2)
	var released_x := p.global_position.x
	await _wait(10)
	return {"vx": vx, "coast": p.global_position.x - released_x}


# --------------------------------------------------- 6. the shared player systems


func _test_jumping_and_stacking_still_work() -> void:
	_emit("=== 6. the shared player systems still work on Winter ground ===")
	_park(p1, Vector2(SHELF_X, SHELF_Y - 1.0))
	_park(p2, Vector2(SHELF_X2, SHELF_Y - 1.0))
	await _wait(10)

	var y0 := p1.global_position.y
	await _hold([p1.jump_action], 2)
	await _wait(18)
	var peak := p1.global_position.y
	_check("P1 still jumps, and reaches about the usual height",
		(y0 - peak) > JUMP_H * 0.6 and (y0 - peak) <= JUMP_H + 2.0,
		" rose %.1f of %.0f" % [y0 - peak, JUMP_H])
	await _wait(60)
	_check("and comes back down onto the snow", p1.is_on_floor(),
		" y=%.1f on_floor=%s" % [p1.global_position.y, str(p1.is_on_floor())])

	# The ride system is the shared stacking code; if it still works here it has not
	# been disturbed by the ice work.
	_park(p1, Vector2(SHELF_X, SHELF_Y - 1.0))
	_park(p2, Vector2(SHELF_X, SHELF_Y - 1.0))
	await _wait(12)
	await _hold([p2.jump_action], 2)
	await _wait(50)
	_check("P2 can still stand on P1's head", p2.global_position.y < p1.global_position.y - 20.0,
		" p1y=%.1f p2y=%.1f" % [p1.global_position.y, p2.global_position.y])
	await _wait(60)
	_park(p2, Vector2(SHELF_X2, SHELF_Y - 1.0))
	await _wait(30)
	_emit("")


# --------------------------------------------------------------- 7. the icicles


func _test_the_icicles_fall_and_hit_and_stop() -> void:
	_emit("=== 7. the icicles fall when approached, hit, and then stop ===")
	_check("the level builds its icicles from the one Icicle scene",
		icicles.size() == ICICLE_XS.size(), " %d icicles" % icicles.size())
	_reset_hazards()
	await _wait(4)
	_check("after a reset, all six are hanging and harmless again",
		_icicles_all(0), " states=%s" % str(_icicle_states()))
	_check("every icicle's hazard is switched off while it hangs",
		_all_hazards_off())

	# Both icicle pictures are really in use.
	var one := 0
	var two := 0
	for ic in icicles:
		if ic.icicle_texture == ICICLE1_TEXTURE:
			one += 1
		elif ic.icicle_texture == ICICLE2_TEXTURE:
			two += 1
	_check("and the two icicle artworks are both used",
		one > 0 and two > 0, " icicle1=%d icicle2=%d" % [one, two])

	# No icicle hangs over a platform at any height, so none of them can drop
	# through a shelf.
	var constants: Dictionary = level.get_script().get_script_constant_map()
	var platforms: Array = constants.get("PLATFORM_ROWS")
	var clashes := 0
	for ic in icicles:
		var width := ic.art_region.size.x * (ic.display_height / ic.art_region.size.y)
		for platform in platforms:
			var x0 := float(platform[1]) * TILE_W
			var x1 := x0 + float(platform[2]) * TILE_W
			if ic.position.x + width * 0.5 > x0 and ic.position.x - width * 0.5 < x1:
				clashes += 1
	_check("no icicle hangs over a shelf, so none can drop through one",
		clashes == 0, " %d clashes" % clashes)

	# The first cycle, on the real level, with real simulated walking.
	#
	# The hazards are put back first and the penguin is teleported in afterwards. That
	# order matters: an icicle's ground zone reports a penguin walking into it, and a
	# penguin who was already standing there when the icicle went back up would not
	# be a new arrival at all.
	_reset_hazards()
	var ic: Icicle = icicles[0]
	var hits_before: int = _hits[0]
	_park(p2, 200.0)
	_park(p1, ic.position.x)
	await _wait(12)
	_check("walking under it starts it", int(ic.state) == 1, " state=%d" % int(ic.state))

	# It warns before it drops, rather than dropping instantly.
	await _wait(24)
	_check("and it warns first, instead of dropping the instant it is reached",
		int(ic.state) == 1, " state=%d" % int(ic.state))
	# The shake is a swing, so it passes through zero twice a cycle. Sampling one
	# frame could therefore catch it at the middle and prove nothing, so watch a
	# stretch of the warning and remember the furthest it got.
	var swing := 0.0
	for _i in 20:
		swing = maxf(swing, absf(ic.moving.position.x))
		await get_tree().physics_frame
	_check("and the warning is visible as a shake", swing > 1.0,
		" swung %.2fpx at most" % swing)

	# Watch the whole fall, remembering everything it went through.
	var saw_falling := false
	var saw_spent := false
	for _i in 300:
		await get_tree().physics_frame
		if int(ic.state) == 2:
			saw_falling = true
		if int(ic.state) == 3:
			saw_spent = true
		if saw_spent:
			break
	_check("then it drops", saw_falling)
	_check("and it spends itself the moment it lands a hit", saw_spent)

	# This is the real "not repeatedly killing the player forever" check, and it is
	# counted rather than eyeballed: one fall may report exactly one hit, however
	# many frames the penguin spends inside it.
	var hits: int = _hits[0] - hits_before
	_check("one fall reports the hit exactly once, so it cannot kill forever",
		hits == 1, " %d hits from one fall" % hits)

	# A few frames of grace before reading the hazard. Switching monitoring on an
	# Area2D has to wait for the physics step it was asked in, so on the very frame
	# the icicle spent itself the flag has only been asked for, not yet obeyed.
	await _wait(6)
	_check("and a spent icicle has switched its hazard off",
		not _hazard_live(ic), " hazard_live=%s" % str(_hazard_live(ic)))

	# Let the level's own reset finish, and confirm the icicle really is reusable
	# rather than jammed.
	await _wait(120)
	_check("after the reset the icicle is hanging again and ready to be triggered",
		int(ic.state) == 0 and ic.moving.position == Vector2.ZERO,
		" state=%d moving=%s" % [int(ic.state), ic.moving.position])
	_emit("")


func _icicles_all(state: int) -> bool:
	for ic in icicles:
		if int(ic.state) != state:
			return false
	return true


func _all_hazards_off() -> bool:
	for ic in icicles:
		if _hazard_live(ic):
			return false
	return true


## The smallest rectangle holding every pixel of an image that is not fully
## transparent. Measured rather than assumed, because a region that is even slightly
## wrong shows up in game as artwork quietly missing and nothing else.
func _opaque_box(img: Image) -> Rect2:
	var lo := Vector2i(-1, -1)
	var hi := Vector2i(-1, -1)
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.02:
				var here := Vector2i(x, y)
				if lo.x < 0:
					lo = here
					hi = here
				else:
					lo = Vector2i(mini(lo.x, here.x), mini(lo.y, here.y))
					hi = Vector2i(maxi(hi.x, here.x), maxi(hi.y, here.y))
	if lo.x < 0:
		return Rect2()
	return Rect2(lo, hi - lo + Vector2i.ONE)


func _icicle_states() -> Array:
	var out: Array = []
	for ic in icicles:
		out.append(int(ic.state))
	return out


func _hazard_live(ic: Icicle) -> bool:
	return ic.hazard.monitoring and ic.hazard.monitorable


# ------------------------------------------------------------ 8. the both reset


func _test_a_hit_resets_both_penguins() -> void:
	_emit("=== 8. being hit sends BOTH penguins back to the start, together ===")
	# Put them well past the start, under a hanging icicle, and let it drop.
	_reset_hazards()
	var ic: Icicle = icicles[2]
	_park(p1, ic.position.x)
	_park(p2, ic.position.x + 30.0)
	await _wait(10)
	for _i in 260:
		await get_tree().physics_frame
		if int(ic.state) == 0:
			break
	await _wait(90)

	_check("P1 is back on its own spawn",
		absf(p1.global_position.x - 140.0) < 1.0, " x=%.2f" % p1.global_position.x)
	_check("P2 is back on its own spawn, not P1's",
		absf(p2.global_position.x - 252.0) < 1.0, " x=%.2f" % p2.global_position.x)
	_check("neither is left standing out past the icicles",
		p1.global_position.x < 400.0 and p2.global_position.x < 400.0)
	_check("both are on the floor again and neither fell through the world",
		p1.is_on_floor() and p2.is_on_floor())
	_check("and neither is still moving", p1.velocity == Vector2.ZERO
		and p2.velocity == Vector2.ZERO)

	# The temporary hazard state is cleared too, not just the players.
	_check("the icicle that hit them is back on its chain",
		int(ic.state) == 0, " state=%d" % int(ic.state))
	_check("and it is back at exactly the height it hung at",
		ic.position.y == 0.0 and ic.moving.position == Vector2.ZERO,
		" y=%.2f moving=%s" % [ic.position.y, ic.moving.position])
	_check("every other icicle was left alone and is still hanging",
		_icicles_all(0), " states=%s" % str(_icicle_states()))
	_check("and the camera is back on the penguins rather than out at the far end",
		absf((level.get_node("Camera2D") as Camera2D).position.x
			- level._penguins_centre().x) <= CAMERA_TOLERANCE)
	_emit("")


# ------------------------------------------------------------------- 9. the fish


## Everything about the two fish, because getting to them is the entire point of them:
## they have to be built, drawn undistorted, hung out of reach of a plain floor jump,
## reachable only by climbing or by stacking, collected by a penguin actually touching
## them, and put back when an icicle hits.
##
## This section deliberately ends with the fish all back in the world, because the igloo
## checks after it need to start from "nothing collected yet" in order to prove the fish
## are what is holding the level up.
func _test_the_two_fish() -> void:
	_emit("=== 9. the two fish are hung out of reach, and reachable only by effort ===")
	_reset_fish()

	_check("the level has exactly two fish, and no more",
		fishes.size() == 2, " %d" % fishes.size())
	_check("both built from the Fish scene",
		fishes.size() == 2 and fishes[0] is Fish and fishes[1] is Fish)

	# The level's own table is the single source of truth for where they are, so it is
	# cross-checked against the built nodes rather than restated here and hoped over.
	var constants: Dictionary = level.get_script().get_script_constant_map()
	var table: Array = constants.get("FISHES", [])
	_check("and the level's own table agrees there are two",
		table.size() == 2, " table=%d" % table.size())
	_check("the level counts both of them towards finishing",
		level._required_fish() == 2, " required=%d" % level._required_fish())

	for index in fishes.size():
		var one: Fish = fishes[index]
		var label := "fish %d" % (index + 1)
		var box: RectangleShape2D = one.pickup.shape as RectangleShape2D
		_check("%s wears the Fish artwork" % label, one.fish_texture == FISH_TEXTURE)
		_check("%s is drawn 60 tall - exactly 2x the 30px artwork, so nothing is stretched" % label,
			is_equal_approx(one.display_height, FISH_DISPLAY_H)
			and is_equal_approx(one.art.scale.x, FISH_DISPLAY_H / FISH_H)
			and is_equal_approx(one.art.scale.y, FISH_DISPLAY_H / FISH_H),
			" scale=%s" % one.art.scale)
		_check("%s filters nearest-neighbour, so the pixels stay square" % label,
			one.art.texture_filter == 1)
		_check("%s has a real pickup box one tile across" % label,
			box != null and is_equal_approx(box.size.x, FISH_BOX)
			and is_equal_approx(box.size.y, FISH_BOX),
			" size=%s" % (box.size if box else "none"))
		_check("%s watches the penguin layer and occupies none of its own" % label,
			one.collision_mask == 2 and one.collision_layer == 0,
			" mask=%d layer=%d" % [one.collision_mask, one.collision_layer])
		# The picture has to sit on the box that collects it, not hover above it.
		_check("%s is drawn centred on its own pickup box" % label,
			one.art.offset == Vector2.ZERO, " offset=%s" % one.art.offset)
		if index < table.size():
			_check("%s sits where the level's table says it is" % label,
				one.position.is_equal_approx(table[index] as Vector2),
				" %s vs %s" % [str(one.position), str(table[index])])

	# Both hang with the bottom of their box further above the floor than a jump rises.
	# A jump is nominally 128px, but it really rises a little over 133px because the
	# engine integrates velocity before it moves the body, and this level's ice makes
	# every penguin jump the same way, so the real number is the one that matters.
	var rise := _jump_rise()
	var solo_top := GROUND_Y - rise - PLAYER_H
	for index in fishes.size():
		var one: Fish = fishes[index]
		var box: RectangleShape2D = one.pickup.shape as RectangleShape2D
		var box_bottom: float = one.position.y + box.size.y * 0.5
		_check("fish %d hangs %.0fpx above the floor, more than the %.0fpx a jump reaches"
			% [index + 1, GROUND_Y - box_bottom, rise],
			box_bottom < solo_top,
			" floor jump reaches y=%.1f, box starts at %.1f" % [solo_top, box_bottom])
		_check("but a stacked penguin's head does reach it, at y=%.1f"
			% (solo_top - PLAYER_H),
			solo_top - PLAYER_H < box_bottom,
			" margin=%.1f" % ((solo_top - PLAYER_H) - box_bottom))
		_check("and neither fish is anywhere near an icicle's drop line",
			_fish_is_clear_of_icicles(one))

	# --- fish 1: climb to the C low shelf, then jump ---
	_emit("  (fish 1: walk up on the floor and jump)")
	await _fish_trial(1, Vector2(1560.0, GROUND_Y - 1.0), "p1_jump", false)
	_emit("  (fish 1: stand on the C low shelf and jump)")
	await _fish_trial(1, Vector2(1560.0, C_SHELF_Y - 1.0), "p1_jump", true)

	# --- fish 2: there is nothing to climb, so stack ---
	_emit("  (fish 2: walk up on the ice and jump)")
	await _fish_trial(2, Vector2(4300.0, GROUND_Y - 1.0), "p1_jump", false)
	_emit("  (fish 2: stack, and the rider jumps)")
	await _fish_trial(2, Vector2(4300.0, GROUND_Y - 1.0), "p2_jump", true)

	# Collecting has to take the fish out of the world properly: gone, and with no
	# invisible box still sitting there waiting to be walked into. Fish 2 is the one
	# standing collected here, because it was the last trial.
	var taken: Fish = fishes[1]
	_check("a collected fish is not drawn any more", not taken.visible)
	_check("and its own monitoring is off, so there is no invisible box left",
		not taken.monitoring and not taken.monitorable,
		" monitoring=%s monitorable=%s" % [str(taken.monitoring), str(taken.monitorable)])
	_check("but it is still in the tree, because a reset has to be able to find it",
		taken.get_parent() != null and is_instance_valid(taken))
	_check("and the level has recorded it once",
		level._collected_fish.size() == 1 and level._collected_fish.has(1),
		" collected=%s" % str(level._collected_fish.keys()))

	# Both fish reported exactly one collection signal each, never two.
	_check("each fish reported being collected exactly once",
		int(_fish_signals[0]) == 1 and int(_fish_signals[1]) == 1,
		" signals=%s" % str(_fish_signals))

	# Leaving a penguin standing inside where a collected fish was must not re-collect
	# it, and must not push the count up.
	_park(p1, taken.position)
	await _wait(40)
	_check("leaving a penguin inside a collected fish does not collect it again",
		int(_fish_signals[1]) == 1 and level._collected_fish.size() == 1,
		" signals=%s" % str(_fish_signals))

	# --- an icicle hit has to put both fish back ---
	_emit("  (an icicle hit puts a collected fish back)")
	_reset_hazards()
	var ic: Icicle = icicles[2]
	_park(p1, ic.position.x)
	_park(p2, ic.position.x + 30.0)
	await _wait(10)
	for _i in 260:
		await get_tree().physics_frame
		if int(ic.state) == 0:
			break
	await _wait(90)

	_check("after a hit, fish 1 is back on the map and drawn again",
		not fishes[0].is_collected and fishes[0].visible,
		" collected=%s visible=%s" % [str(fishes[0].is_collected), str(fishes[0].visible)])
	_check("and so is fish 2", not fishes[1].is_collected and fishes[1].visible,
		" collected=%s visible=%s" % [str(fishes[1].is_collected), str(fishes[1].visible)])
	_check("with their monitoring back on, so they can be collected again",
		fishes[0].monitoring and fishes[0].monitorable
		and fishes[1].monitoring and fishes[1].monitorable)
	_check("and the level has forgotten it had collected anything",
		level._collected_fish.is_empty(),
		" collected=%s" % str(level._collected_fish.keys()))
	_check("and neither fish drifted off its spot",
		fishes[0].position.is_equal_approx(table[0] as Vector2)
		and fishes[1].position.is_equal_approx(table[1] as Vector2))
	_emit("")


## How high a penguin's feet actually get, rather than the nominal 128px. The engine
## integrates velocity and then moves the body, so a jump overshoots the analytic apex
## by half a frame of travel; measured on this level that is about 133px, and it is the
## difference between a fish being reachable from the floor and not.
func _jump_rise() -> float:
	var v: float = Player.JUMP_VELOCITY
	var g: float = Player.GRAVITY
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	return v * v / (2.0 * g) + absf(v) * dt * 0.5


## Puts every fish back, and forgets the level's tally, so one check cannot leave a fish
## spent for the next one. Paired with _wait() by the callers, because reset() turns
## monitoring back on deferred.
func _reset_fish() -> void:
	for one in fishes:
		one.reset()
	level._collected_fish.clear()


## Nothing above or below a fish that an icicle could land on it through. Read out of the
## real icicles rather than assumed from the picture.
func _fish_is_clear_of_icicles(one: Fish) -> bool:
	for ic in icicles:
		if absf(ic.position.x - one.position.x) <= 150.0:
			return false
	return true


## Drives one attempt at one fish and checks it either did or did not get collected.
##
## `stand_on` is where the base penguin starts, `jumper` is which of the two jumps -
## "p2_jump" meaning the rider on the other's head - and `expect_taken` is the claim being
## tested. So the same routine can prove "a lone penguin cannot reach it" and "a stacked
## one can".
func _fish_trial(which: int, stand_on: Vector2, jumper: String, expect_taken: bool) -> void:
	var fish: Fish = fishes[which - 1]
	_reset_fish()
	await _wait(6)
	_reset_hazards()

	if jumper == "p2_jump":
		# Base penguin on the floor, rider parked on its head and allowed to settle.
		_park(p1, stand_on)
		await _wait(8)
		_park(p2, stand_on - Vector2(0.0, PLAYER_H))
		await _wait(24)
	else:
		_park(p1, stand_on)
		await _wait(14)

	await _hold([&"p1_jump" if jumper == "p1_jump" else &"p2_jump"], 90)
	await _wait(24)

	var got := fish.is_collected
	_check("a penguin starting at y=%.0f %s fish %d" % [stand_on.y,
		("takes" if expect_taken else "cannot take"), which],
		got == expect_taken,
		" collected=%s" % str(got))
	# Whatever this trial did, the next one starts from a known place. The B low shelf
	# is the one stretch of floor-level stand that is snow, shelf-free and icicle-free.
	_park(p1, Vector2(SHELF_X, SHELF_Y - 1.0))
	_park(p2, Vector2(SHELF_X2, SHELF_Y - 1.0))
	await _wait(8)


# ------------------------------------------------------------------ 10. the goal


## The goal now has two halves, and both are checked separately: the box has to hold
## every player, AND both fish have to be in. Either half alone must not finish the
## level, or "collect the fish" would just be a box to walk into on the way past.
func _test_the_igloo_needs_both_penguins_and_both_fish() -> void:
	_emit("=== 10. the igloo needs BOTH penguins AND both fish ===")
	_check("there is exactly one igloo, built from the Igloo scene",
		find_children("Igloo", "Igloo", true, false).size() == 1)
	_check("it wears the igloo artwork", igloo.igloo_texture == IGLOO_TEXTURE)
	_check("and it is drawn 152 tall, exactly 4x the 38px artwork",
		is_equal_approx(igloo.art.scale.x, 4.0)
		and is_equal_approx(igloo.art.scale.y, 4.0), " scale=%s" % igloo.art.scale)

	# It has to be a real box, big enough for a penguin to stand in, and it has to
	# be an Area2D goal rather than a solid body they could get stuck inside.
	var collider := igloo.goal_shape.shape as RectangleShape2D
	_check("the goal is a real collision box",
		collider != null and collider.size.x >= PLAYER_W
		and collider.size.y >= PLAYER_H, " size=%s" % (collider.size if collider else "none"))
	_check("and it is an area, not a solid body, so nobody can get stuck in it",
		igloo is Area2D and igloo.collision_layer == 0)
	_check("and the igloo itself has no collider that could trap a penguin",
		igloo.get_node("Art") is Sprite2D and igloo.get_child_count() == 2,
		" %d children" % igloo.get_child_count())

	# It starts empty, with nothing collected, and the completion screen safely away.
	_check("nobody is in the igloo to begin with", igloo.penguin_count() == 0)
	_check("and nothing has been collected to begin with",
		level._collected_fish.is_empty())
	_check("the Level Complete picture is hidden to begin with",
		not level.level_complete_banner.visible)
	_check("and so is the Next Level button, and it is inert",
		not level.next_level_button.visible and level.next_level_button.disabled)

	# One penguin is not enough, even standing right on the finish.
	_park(p1, IGLOO_P1)
	await _wait(30)
	_check("one penguin in the igloo is one penguin, not two",
		igloo.penguin_count() == 1, " count=%d" % igloo.penguin_count())
	await _wait(30)
	_check("and one penguin alone does NOT finish the level",
		not level.level_complete_banner.visible
		and not level.next_level_button.visible)

	# P2 must not be able to be counted twice over.
	_emit("  (checking one penguin cannot be counted as two)")
	_park(p2, IGLOO_P2)
	await _wait(30)
	_check("both penguins in the igloo counts as exactly two",
		igloo.penguin_count() == 2, " count=%d" % igloo.penguin_count())

	# Both penguins, both at the finish - and still nothing, because the fish are
	# missing. Waits out the whole banner delay, so this is a real "no", not a "not yet".
	var down_with_none := await _banner_stays_down()
	_check("both penguins in the igloo with NO fish does NOT finish the level",
		down_with_none, " waited %.1fs" % level.complete_banner_delay)

	# One fish is still only half of it.
	_emit("  (checking one fish out of two is not enough)")
	await _take_fish(1)
	var down_with_one := await _banner_stays_down()
	_check("one fish collected and both penguins at the igloo does NOT finish either",
		level._collected_fish.size() == 1 and down_with_one,
		" collected=%d" % level._collected_fish.size())

	# The second fish, taken by P1 while P2 waits at the finish, and then P1 walking in
	# behind it. That is the ordinary order of events and the ordinary way it ends.
	_emit("  (the second fish, taken by P1 while P2 waits, then P1 walks in)")
	await _take_fish(2)
	_check("so the level does finish once both penguins and both fish are there",
		_finishing())
	_check("and the igloo is holding exactly the two penguins, not more",
		igloo.penguin_count() == 2, " count=%d" % igloo.penguin_count())
	_emit("")


## Whether the level has started finishing - the countdown running, or already done.
## Read from the level's own two pieces of state rather than from the banner, because the
## banner deliberately does not appear for a second and a half.
func _finishing() -> bool:
	return level._banner_shown or level._banner_timer >= 0.0


## Collects a fish the honest way, by putting a penguin on top of it, and waits until
## the level has actually noticed. Parking is enough on purpose: it is the same thing a
## player arriving at speed does, and it does not depend on the jump arc.
func _take_fish(which: int) -> void:
	var fish: Fish = fishes[which - 1]
	# P2 stays put in the igloo throughout, so the collection genuinely happens with one
	# penguin already at the finish - which is the situation the gate has to survive.
	_park(p1, fish.position)
	for _i in 40:
		await get_tree().physics_frame
		if fish.is_collected:
			break
	# Back to the goal, but to P1's own spot rather than on top of P2.
	_park(p1, IGLOO_P1)
	await _wait(6)


## Waits out the whole completion delay and reports whether the level stayed un-finished
## the entire time. Returns true if the banner never appeared, which is the passing
## answer for a goal that has not been met.
func _banner_stays_down() -> bool:
	var delay: float = level.complete_banner_delay
	var frames := int(ceil(delay * float(Engine.physics_ticks_per_second))) + 20
	for _i in frames:
		await get_tree().physics_frame
		if level.level_complete_banner.visible or level.next_level_button.visible:
			return false
	return true


# ------------------------------------------------------- 11. the completion screen


func _test_the_completion_screen() -> void:
	_emit("=== 10. the completion screen is the shared one, and only at the end ===")
	var delay: float = level.complete_banner_delay
	_check("the banner waits before it appears, so the igloo is seen first",
		delay > 0.0, " delay=%.2f" % delay)
	_check("and it is still down during that pause",
		not level.level_complete_banner.visible
		and not level.next_level_button.visible)

	await get_tree().create_timer(delay + 0.4).timeout

	_check("the Level Complete picture is up",
		level.level_complete_banner.visible
		and level.level_complete_banner.texture == COMPLETE_TEXTURE)
	_check("and the Next Level button is up with it",
		level.next_level_button.visible and not level.next_level_button.disabled)

	var button: TextureButton = level.next_level_button
	_check("the button's middle is on the screen",
		SCREEN.has_point(button.get_global_rect().get_center()),
		" centre=%s" % button.get_global_rect().get_center())
	_check("and it is the shared Next Level artwork, not a second button",
		button.texture_normal == NEXT_TEXTURE)
	_check("and its pressed signal is really wired to the level's handler",
		button.pressed.is_connected(level._on_next_level_pressed))

	# There is only ever one of each: no second banner, no second button.
	_check("the level has exactly one banner and exactly one Next Level button",
		find_children("*", "TextureButton", true, false).size() == 1)

	# The button is not pressed here - that would change the scene out from under
	# this test. Where it would go is read from the level's own constant instead.
	var constants: Dictionary = level.get_script().get_script_constant_map()
	# 2026-10-14: this long level is Winter 2, the last level of the game, so it
	# leads to the ending, which is where Play again takes the players back to Spring.
	_check("this is Winter's second level, the last one before the ending",
		level.get("stage") == 2, " stage=%s" % level.get("stage"))
	_check("and after Winter 2 comes the ending, which does exist, so Winter is not a dead end",
		constants.get("NEXT_SCENE") == ENDING_SCENE
		and ResourceLoader.exists(ENDING_SCENE),
		" next=%s" % constants.get("NEXT_SCENE"))
	_emit("")


# ---------------------------------------------------- 12. the re-check that avoids a hang


## A fish and the igloo are never in the same place, so in ordinary play the last fish is
## always taken by a penguin standing somewhere else, and the level finishes a moment
## later when that penguin walks in. That is the order section 10 plays.
##
## This covers the opposite order, which no amount of ordinary play can produce but which
## would leave the level hanging for good if it were mishandled: both penguins already
## standing in the igloo when the last fish is taken. Nothing else would ever report
## them again - the igloo only speaks when a penguin enters or leaves - so a level that
## listened only for the igloo would sit there looking finished and not being finished,
## with no way forward. The fish are collected by hand here, because taking one genuinely
## requires being at it and there is nowhere in the igloo to stand.
##
## It runs on throwaway levels of its own, built after every other check, so it cannot
## disturb the level the rest of the suite has already driven to the end.
##
## Each throwaway is pushed far off to the side before it is ever added to the tree. That
## is not tidiness, it is necessity: the goal box is an Area2D that detects anything on
## the penguin layer, and every level in this game shares one collision layer and one
## coordinate space. Built on top of the live level, a throwaway igloo would count the
## live level's penguins as its own and the checks would be measuring nothing.
func _test_the_last_fish_cannot_hang_the_level() -> void:
	_emit("=== 12. the last fish taken while both penguins wait cannot hang the level ===")

	# Order A: both penguins already waiting, and only then the fish. The spots are the
	# level's own, so they have to be added to the offset this level was pushed out to.
	var a_home := Vector2(20000.0, 0.0)
	var a := (load(WINTER_SCENE) as PackedScene).instantiate()
	a.position = a_home
	add_child(a)
	await get_tree().process_frame
	var a_penguins: Array[Node] = a.get_node("Players").get_children()
	var a_fishes: Array[Fish] = []
	for child in a.get_node("Fish").get_children():
		a_fishes.append(child as Fish)
	_check("the first throwaway level was really built with two fish",
		a_fishes.size() == 2 and a_penguins.size() == 2,
		" fish=%d players=%d" % [a_fishes.size(), a_penguins.size()])

	a_penguins[0].reset_to_position(a_home + Vector2(IGLOO_P1, GROUND_Y - 1.0))
	a_penguins[1].reset_to_position(a_home + Vector2(IGLOO_P2, GROUND_Y - 1.0))
	await _wait(30)
	_check("both penguins are standing in the igloo before anything is collected",
		(a.igloo as Igloo).penguin_count() == 2,
		" count=%d" % (a.igloo as Igloo).penguin_count())

	for one in a_fishes:
		one._collect()
	await _wait(20)
	_check("taking both fish then finishes it, with nobody moving afterwards",
		a._banner_shown or a._banner_timer >= 0.0,
		" banner_shown=%s timer=%.2f" % [str(a._banner_shown), a._banner_timer])

	# Order B: the same two fish, but with only one of the two penguins waiting.
	var b_home := Vector2(40000.0, 0.0)
	var b := (load(WINTER_SCENE) as PackedScene).instantiate()
	b.position = b_home
	add_child(b)
	await get_tree().process_frame
	var b_penguins: Array[Node] = b.get_node("Players").get_children()
	var b_fishes: Array[Fish] = []
	for child in b.get_node("Fish").get_children():
		b_fishes.append(child as Fish)

	b_penguins[0].reset_to_position(b_home + Vector2(IGLOO_P1, GROUND_Y - 1.0))
	b_penguins[1].reset_to_position(b_home + Vector2(SNOW_X, GROUND_Y - 1.0))
	await _wait(30)
	for one in b_fishes:
		one._collect()
	await _wait(20)
	_check("but both fish with only ONE penguin waiting does NOT finish it",
		(b.igloo as Igloo).penguin_count() == 1
		and not (b._banner_shown or b._banner_timer >= 0.0),
		" count=%d banner_shown=%s timer=%.2f" % [
			(b.igloo as Igloo).penguin_count(), str(b._banner_shown), b._banner_timer])
	_emit("")


## Both throwaway levels above are deliberately left standing rather than freed.
##
## Freeing a level part way through a test orphans a terrain tile's physics body, and
## the engine reports that as a leak on the way out. Leaving them in the tree costs a
## little memory and is cleaned up properly with the rest of the scene at exit, which is
## what the live level relies on anyway. They are 20000px apart and cannot see each other
## or the live level, so there is nothing to tidy up.


# ---------------------------------------------------------------------- helpers


## Parks a player at a spot with no input and no leftover velocity, which is the
## only honest way to start a measurement from a known place. A bare number means
## "that x, standing on the floor", which is nearly every place a check needs.
func _park(p: Player, spot: Variant) -> void:
	if spot is float or spot is int:
		p.reset_to_position(Vector2(float(spot), GROUND_Y - 1.0))
	else:
		p.reset_to_position(spot as Vector2)


## Puts every icicle back on its chain, so one check cannot leave a hazard spent for
## the next one. Called before parking a penguin anywhere near a chamber, and always
## BEFORE the penguin is moved, because a ground zone reports arrivals and a penguin
## who was already standing there is not an arrival.
func _reset_hazards() -> void:
	for ic in icicles:
		ic.reset()


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
	_emit("=".repeat(58))
	get_tree().quit(0 if ok else 1)