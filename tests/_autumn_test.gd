extends Node2D

## Automated regression suite for the Autumn level: the two foxes, the long
## side-scrolling map, the shared camera, the four leaves, the four visually
## matching frames, the wrong-frame refusal and the completion screen.
##
## It builds the real AutumnLevel.tscn exactly as the game does and drives it with
## simulated input, in the same style as _garden_test and _summer_test. Everything
## asserted here is read out of the live level, so a check cannot pass just
## because the level was never really built.
##
## Order matters. The rubbish-reachability checks and the twelve wrong-frame cases
## both run while all four leaves are still in the level, because after the last one
## is placed the level is finished and there is nothing left to carry.

const AUTUMN_SCENE := "res://scenes/AutumnLevel.tscn"
const SPRING_SCENE := "res://scenes/Level.tscn"
const SUMMER_SCENE := "res://scenes/SummerLevel.tscn"
const WINTER_SCENE := "res://scenes/WinterLevel.tscn"
const ENDING_SCENE := "res://scenes/Ending.tscn"

const FOX1_TEXTURE := preload("res://assets/Autumn/Fox1.png")
const FOX2_TEXTURE := preload("res://assets/Autumn/Fox2.png")
const CAT1_TEXTURE := preload("res://assets/Spring/Cat1.png")
const CAT2_TEXTURE := preload("res://assets/Spring/Cat2.png")
const DOG1_TEXTURE := preload("res://assets/Summer/Dog1.png")
const SAND_TEXTURE := preload("res://assets/Summer/Sand.png")
const TILE_TEXTURE := preload("res://assets/Autumn/Autumn Tile.png")
const TREE_TEXTURE := preload("res://assets/Autumn/Autumn_Tree.png")
const COMPLETE_TEXTURE := preload("res://assets/Level Complete.png")
const NEXT_TEXTURE := preload("res://assets/Next_Button.png")

const LEAF1_TEXTURE := preload("res://assets/Autumn/Leaf1.png")
const LEAF2_TEXTURE := preload("res://assets/Autumn/Leaf2.png")
const LEAF3_TEXTURE := preload("res://assets/Autumn/Leaf3.png")
const LEAF4_TEXTURE := preload("res://assets/Autumn/Leaf4.png")

const FRAME1_TEXTURE := preload("res://assets/Autumn/Leaf_frame1.png")
const FRAME2_TEXTURE := preload("res://assets/Autumn/Leaf_frame2.png")
const FRAME3_TEXTURE := preload("res://assets/Autumn/Leaf_frame3.png")
const FRAME4_TEXTURE := preload("res://assets/Autumn/Leaf_frame4.png")

const LEAF_REGIONS := {
	&"leaf1": Rect2(2, 6, 25, 24),
	&"leaf2": Rect2(2, 2, 25, 25),
	&"leaf3": Rect2(4, 2, 23, 28),
	&"leaf4": Rect2(3, 2, 25, 28),
}
const LEAF_TEXTURES := {
	&"leaf1": LEAF1_TEXTURE,
	&"leaf2": LEAF2_TEXTURE,
	&"leaf3": LEAF3_TEXTURE,
	&"leaf4": LEAF4_TEXTURE,
}
## The frame artwork each leaf belongs to, by measurement rather than by filename.
## If these ever disagree, the frame is showing a leaf the picture does not fit.
const FRAME_TEXTURES := {
	&"leaf1": FRAME1_TEXTURE,
	&"leaf2": FRAME2_TEXTURE,
	&"leaf3": FRAME3_TEXTURE,
	&"leaf4": FRAME4_TEXTURE,
}
const KINDS: Array[StringName] = [&"leaf1", &"leaf2", &"leaf3", &"leaf4"]

const FOX_REGION := Rect2(16, 40, 216, 168)
const PLAYER_H := 52.0
const PLAYER_W := 60.0
const GROUND_Y := 560.0
const SCREEN := Rect2(0.0, 0.0, 1280.0, 720.0)
## How close to the foxes' midpoint the smoothed camera has to be counted as
## "arrived". The camera is smoothed, so it approaches its target asymptotically
## and never lands on it exactly, so it cannot be compared with is_equal_approx:
## that allows about a hundredth of a pixel on a value near 2000, which no
## smoothed camera can ever reach.
const CAMERA_TOLERANCE := 8.0

## Where a fox jumps from to pick each leaf up: the shelf it floats above, and
## which way the fox leans as it goes. Every leaf is jumped for straight up from
## the shelf underneath it. These are the spots a player would use, not the only
## spots that happen to work.
const REACH_SPOTS := {
	&"leaf1": {"x": 832.0, "y": 448.0, "dir": 0},
	&"leaf2": {"x": 1824.0, "y": 336.0, "dir": 0},
	&"leaf3": {"x": 2432.0, "y": 448.0, "dir": 0},
	&"leaf4": {"x": 3200.0, "y": 224.0, "dir": 0},
}

## Flat open ground, clear of every leaf box and every shelf, so parking here can
## never be standing in an obstacle or picking something up. The trees have no
## colliders at all any more, so nothing on the floor can stop a fox; the first
## shelf starts at x = 128, so 200 and 660 are both well clear of everything.
const PARK_A := Vector2(200.0, GROUND_Y)
const PARK_B := Vector2(660.0, GROUND_Y)
const STACK_X := 200.0

## Every tree x, used to walk a fox straight through each one in turn. Reading them
## back out of the level's own TREES constant means this test cannot drift away
## from the map: if a tree moves, this follows it.
const TREE_X := 512.0
const TREE_BEFORE := 400.0
const TREE_AFTER := 600.0

var level: Node2D
var p1: Player
var p2: Player
var items: Dictionary = {}
var frames: Dictionary = {}
var item_spots: Dictionary = {}

var failures: Array[String] = []
var _elapsed := 0.0
var _placements_seen := 0
var _placed_at := 0
var _banner_on_place_frame := true


func _ready() -> void:
	level = (load(AUTUMN_SCENE) as PackedScene).instantiate()
	add_child(level)
	await get_tree().process_frame
	_gather()
	_run.call_deferred()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > 300.0:
		_emit("WATCHDOG: aborted")
		get_tree().quit(2)


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


func _gather() -> void:
	var foxes: Array[Player] = []
	for child in level.leaves.get_children():
		if child is GardenItem:
			var leaf := child as GardenItem
			items[leaf.item_kind] = leaf
			item_spots[leaf.item_kind] = leaf.position
	for child in level.frames.get_children():
		if child is LeafFrame:
			var frame := child as LeafFrame
			frames[frame.accepts_kind] = frame
			frame.leaf_placed.connect(_on_leaf_placed)
	for child in level.players.get_children():
		if child is Player:
			foxes.append(child as Player)
	p1 = foxes[0]
	p2 = foxes[1]


## Every placement is counted here, taken from the frame rather than from a flag the
## level sets for itself. It fires on the same frame as the placement, which is what
## makes the banner timing checkable.
func _on_leaf_placed(kind: StringName) -> void:
	_placements_seen += 1
	_placed_at = Time.get_ticks_msec()
	_banner_on_place_frame = level.level_complete_banner.visible


## The leaf of this kind as the test last knew it, or null once it has been placed.
## Read with get() on purpose: after a placement the entry is a freed object, and
## indexing a missing key would be an error rather than a null.
func _item(kind: StringName) -> Variant:
	return items.get(kind, null)


## How many leaves are still in the level. A placed one has its node removed, so
## this only ever goes down and must end at zero.
func _items_left() -> int:
	var count := 0
	for child in level.leaves.get_children():
		if child is GardenItem:
			count += 1
	return count


## Where the frame's pickup box actually is, from the collider rather than a
## hard-coded number, so "the frames are far enough apart" is measured on the thing
## a fox would actually touch.
func _frame_box(kind: StringName) -> Rect2:
	var frame := frames[kind] as LeafFrame
	var body := frame.get_node("CollisionShape2D") as CollisionShape2D
	var shape := body.shape as RectangleShape2D
	return Rect2(frame.position + body.position - shape.size * 0.5, shape.size)


## Where a sprite's artwork really lands on screen, from its own transform. Used
## for the foxes and the frames so "the frame is not drawn into a wall" is
## measured on pixels rather than on a guessed picture size.
func _art_of(sprite: Sprite2D) -> Rect2:
	var local := sprite.get_rect()
	var top_left: Vector2 = sprite.global_transform * local.position
	var bottom_right: Vector2 = sprite.global_transform * local.end
	return Rect2(top_left, bottom_right - top_left)


## Every Label under a node, at any depth. Used to prove there is no wording on the
## frames or the leaves at all.
func _labels_under(node: Node) -> Array[Label]:
	var found: Array[Label] = []
	for child in node.get_children():
		if child is Label:
			found.append(child as Label)
		found.append_array(_labels_under(child))
	return found


func _stand_in(p: Player, kind: StringName) -> void:
	var frame := frames[kind] as LeafFrame
	_place(p, Vector2(frame.position.x, frame.position.y))
	await _wait(6)


## Puts both foxes back on flat open ground with empty hands and no stack.
func _park() -> void:
	for p: Player in [p1, p2]:
		p.drop_carried()
		p._set_support(null)
		p.velocity = Vector2.ZERO
		p.collision_mask = 3
	_place(p1, PARK_A)
	_place(p2, PARK_B)
	await _wait(6)


## Drops one fox onto the other's head, in stages, and reports whether the ride link
## actually formed. The staging matters: the physics server needs a few frames after
## a teleport, and dropping a fox straight onto the spot the other still occupies
## makes the engine shove them apart sideways.
func _stack_at(top: Player, bottom: Player, at_x: float, base_y: float) -> bool:
	_place(top, Vector2(at_x - 90.0, base_y))
	_place(bottom, Vector2(at_x + 90.0, base_y))
	await _wait(5)
	_place(bottom, Vector2(at_x, base_y))
	_place(top, Vector2(at_x - 90.0, base_y))
	await _wait(5)
	_place(top, Vector2(at_x, base_y - PLAYER_H - 40.0))
	for _i in 90:
		if top._support == bottom and bottom._riders.has(top) \
				and absf((bottom.position.y - top.position.y) - PLAYER_H) < 2.0:
			return true
		await get_tree().physics_frame
	return false


## Waits until the "Wrong frame!" notice is showing or has gone, and reports whether
## it got there in time. Wall-clock, so headless frame rate does not matter.
func _wait_for_notice(showing: bool, seconds: float) -> bool:
	var started := Time.get_ticks_msec()
	while level.wrong_leaf_label.visible != showing:
		if float(Time.get_ticks_msec() - started) > seconds * 1000.0:
			return false
		await get_tree().process_frame
	return true


func _notice_is_saying(text: String) -> bool:
	return level.wrong_leaf_label.visible and level.wrong_leaf_label.text == text


## Counts the placements and stamps the wall clock, so the pause before the banner
## can be measured from the real moment the last leaf went in.
func _watch_for_completion() -> void:
	while _placements_seen < 4:
		await get_tree().process_frame


func _run() -> void:
	await _test_the_level_is_autumn()
	await _test_the_world_is_long_and_the_camera_follows()
	await _test_the_trees_are_decoration_only()
	await _test_every_leaf_can_be_reached()
	await _test_the_four_leaves_are_spread_out()
	await _test_the_frames_match_by_picture_alone()
	await _test_the_wrong_frames_refuse_everything()
	await _test_the_right_frames_place_for_good()
	await _test_the_completion_screen()
	_finish(failures.is_empty())


func _test_the_level_is_autumn() -> void:
	_emit("=== 1. Autumn is built: foxes, autumn tiles, a long map, no wording ===")

	_check("the scene is a level, not a placeholder",
		level is Node2D and level.get_child_count() > 0
		and not level.get_script().get_script_constant_map().has("SPRING_SCENE")
		and not level.get_script().get_script_constant_map().has("BINS"),
		" root=%s" % level.get_class())
	_check("the container nodes are all there",
		level.terrain != null and level.walls != null and level.trees != null
		and level.leaves != null and level.frames != null and level.players != null)
	_check("there are two foxes", p1 != null and p2 != null
		and level.players.get_child_count() == 2)

	# The artwork is the only thing that changed about the players.
	_check("P1 is Fox1", p1.sprite.texture == FOX1_TEXTURE)
	_check("P2 is Fox2", p2.sprite.texture == FOX2_TEXTURE)
	_check("neither fox is a cat or a dog",
		p1.sprite.texture != CAT1_TEXTURE and p2.sprite.texture != CAT2_TEXTURE
		and p1.sprite.texture != DOG1_TEXTURE)
	for fox: Player in [p1, p2]:
		_check("%s is cropped to the fox's artwork" % fox.label_text,
			fox.sprite.region_enabled and fox.sprite.region_rect == FOX_REGION,
			" region=%s" % fox.sprite.region_rect)
		_check("%s is not squashed" % fox.label_text,
			is_equal_approx(fox.sprite.scale.x, fox.sprite.scale.y),
			" scale=%.4f" % fox.sprite.scale.x)
		_check("%s stands on the collider base" % fox.label_text,
			is_equal_approx(fox.sprite.offset.y, -FOX_REGION.size.y * 0.5))
		_check("%s is the same size as a cat would be" % fox.label_text,
			is_equal_approx(fox.display_height, 56.0))

	# The controls are Spring's, unchanged, on the same two players.
	_check("P1 still uses the Spring controls",
		p1.left_action == &"p1_left" and p1.right_action == &"p1_right"
		and p1.jump_action == &"p1_jump")
	_check("P2 still uses the Spring controls",
		p2.left_action == &"p2_left" and p2.right_action == &"p2_right"
		and p2.jump_action == &"p2_jump")

	# Both foxes spawn on the floor at the left-hand end of the map, clear of the
	# wall and of the first tree.
	var constants: Dictionary = level.get_script().get_script_constant_map()
	var wall_width: float = constants.get("WALL_WIDTH", 16.0)
	var left_wall := Rect2(0.0, 0.0, wall_width, 720.0)
	for fox: Player in [p1, p2]:
		var spawn_art := _art_of(fox.sprite)
		_check("%s spawns on the ground" % fox.label_text,
			is_equal_approx(fox.position.y, GROUND_Y), " y=%.1f" % fox.position.y)
		_check("%s is not spawned inside the wall" % fox.label_text,
			not spawn_art.intersects(left_wall), " x=%.0f" % fox.position.x)
		_check("%s is clear of the first tree" % fox.label_text,
			fox.position.x < TREE_X - 100.0, " x=%.0f" % fox.position.x)

	# The ground is the autumn tile, on every single one of them.
	var tiles := 0
	var autumn_tiles := 0
	var buried := 0
	for child in level.terrain.get_children():
		if child is GroundTile:
			var tile := child as GroundTile
			tiles += 1
			if tile.sprite.texture == TILE_TEXTURE:
				autumn_tiles += 1
			if tile.buried:
				buried += 1
	# 75 columns x 3 ground rows, plus 15 columns x 2 terrace rows, plus the
	# 47 platform tiles.
	_check("the ground is built from GroundTile", tiles == 302, " tiles=%d" % tiles)
	_check("and every tile is the autumn tile", autumn_tiles == tiles,
		" autumn=%d/%d" % [autumn_tiles, tiles])
	_check("and it is not Spring's tile or Summer's sand",
		TILE_TEXTURE != preload("res://assets/Spring/BasicTile.png")
		and TILE_TEXTURE != SAND_TEXTURE)
	# The buried rows are the ones under a surface: two of the three ground rows and
	# the lower of the two terrace rows.
	_check("and the rows under a surface are flipped", buried == 150 + 15,
		" buried=%d" % buried)

	# The walls are at the two ends of the world, not at the old single-screen ones.
	var level_width: float = constants.get("LEVEL_WIDTH", 0.0)
	var right_wall := Rect2(level_width - wall_width, 0.0, wall_width, 720.0)
	var walls := 0
	for child in level.walls.get_children():
		if child is StaticBody2D:
			walls += 1
			_check("and it is solid", (child as StaticBody2D).collision_layer == 1)
	_check("there is a wall at each end of the world", walls == 2, " walls=%d" % walls)

	# Nothing on screen says which leaf goes in which frame.
	var offending: Array[String] = []
	for child in level.get_children():
		for label in _labels_under(child):
			var text := label.text.to_lower()
			for kind in KINDS:
				if text.contains(str(kind)) or text.contains("leaf_frame") \
						or text.contains("frame %d" % (KINDS.find(kind) + 1)):
					offending.append("%s=%s" % [label.name, label.text])
	_check("no wording anywhere names a leaf or a frame", offending.is_empty(),
		" found=%s" % ", ".join(offending))

	# The completion screen is there and, like Spring's and Summer's, out of the way.
	_check("the Level Complete picture is the shared one",
		level.level_complete_banner.texture == COMPLETE_TEXTURE)
	_check("and it starts hidden", not level.level_complete_banner.visible)
	_check("the Next Level button is the shared one",
		level.next_level_button.texture_normal == NEXT_TEXTURE)
	_check("and it starts hidden", not level.next_level_button.visible)
	_check("and inert", level.next_level_button.disabled)
	_check("the banner waits about 1.5s after the last leaf",
		level.complete_banner_delay >= 1.0 and level.complete_banner_delay <= 2.0,
		" delay=%.2fs" % level.complete_banner_delay)
	_check("the wrong-frame notice is a sensible length",
		level.wrong_leaf_notice_time >= 0.5 and level.wrong_leaf_notice_time <= 2.0,
		" time=%.2fs" % level.wrong_leaf_notice_time)
	_check("and it starts hidden", not level.wrong_leaf_label.visible)
	_check("the notice says exactly what it should",
		level.wrong_leaf_label.text == "Wrong frame!",
		" text=%s" % level.wrong_leaf_label.text)

	# The notice sits up in the top of the screen, clear of the help lines.
	var notice_rect := Rect2(level.wrong_leaf_label.position, level.wrong_leaf_label.size)
	_check("the notice sits up in the top of the screen",
		notice_rect.end.y <= 200.0, " bottom=%.0f" % notice_rect.end.y)
	_check("and it does not cover the help lines", notice_rect.position.y >= 90.0,
		" top=%.0f" % notice_rect.position.y)

	# The UI lives on a CanvasLayer, so it stays put while the camera scrolls.
	_check("the completion screen is not part of the scrolling world",
		level.get_node("UI") is CanvasLayer)
	_check("and the help labels are on it with it",
		level.get_node("UI/P1Help") is Label
		and level.get_node("UI/P2Help") is Label)
	_emit("")


func _test_the_world_is_long_and_the_camera_follows() -> void:
	_emit("=== 2. the map is longer than one screen and one camera follows both foxes ===")

	var constants: Dictionary = level.get_script().get_script_constant_map()
	var level_width: float = constants.get("LEVEL_WIDTH", 0.0)
	_check("the world is at least three screens wide",
		level_width >= 3.0 * 1280.0, " width=%.0f" % level_width)
	_check("and exactly one screen tall, so the camera cannot move up or down",
		is_equal_approx(constants.get("LEVEL_HEIGHT", 0.0), 720.0))

	var camera := level.camera as Camera2D
	_check("there is one camera", camera != null)
	_check("and it is the enabled one", camera.enabled)
	_check("its limits are the world's own edges",
		camera.limit_left == 0 and camera.limit_right == int(level_width)
		and camera.limit_top == 0 and camera.limit_bottom == 720,
		" x 0..%d y 0..%d" % [camera.limit_right, camera.limit_bottom])
	# The camera is smoothed by the level rather than by the engine, so that it can
	# be rounded to a whole pixel. The engine's own smoothing interpolates to
	# fractions, which opens a one pixel gap at every tile seam and shows up as
	# thin white lines while the camera moves.
	var smoothing: float = constants.get("CAMERA_SMOOTHING", 0.0)
	_check("and it is smoothed, so walking reads as a pan",
		smoothing > 0.0 and smoothing <= 20.0
		and not camera.position_smoothing_enabled,
		" level smoothing speed=%.1f, engine smoothing off" % smoothing)
	_check("the level moves it in _process", level.camera == camera)
	_check("and the camera only ever sits on whole pixels",
		camera.get_screen_center_position().x
			== roundf(camera.get_screen_center_position().x),
		" camera.x=%.4f" % camera.get_screen_center_position().x)

	# Walk the foxes right and the camera has to come with them.
	await _park()
	_place(p1, Vector2(2000.0, GROUND_Y))
	_place(p2, Vector2(2200.0, GROUND_Y))
	var settled := await _settle_camera(2100.0)
	var middle := camera.get_screen_center_position()
	_check("the camera follows the foxes to the middle of the map",
		settled and middle.x > 1400.0,
		" camera.x=%.0f" % middle.x)
	_check("and it never moves vertically",
		is_equal_approx(middle.y, 360.0), " y=%.1f" % middle.y)

	# It must not be able to show anything that is not part of the level.
	_place(p1, Vector2(40.0, GROUND_Y))
	_place(p2, Vector2(60.0, GROUND_Y))
	await _settle_camera(640.0)
	var at_left := camera.get_screen_center_position()
	_check("at the left end it stops half a screen in",
		is_equal_approx(at_left.x, 640.0), " camera.x=%.0f" % at_left.x)
	_check("so it never shows anything left of the world",
		at_left.x - 640.0 >= -0.5, " left edge=%.1f" % (at_left.x - 640.0))

	_place(p1, Vector2(level_width - 40.0, GROUND_Y))
	_place(p2, Vector2(level_width - 60.0, GROUND_Y))
	await _settle_camera(level_width - 640.0)
	var at_right := camera.get_screen_center_position()
	_check("at the right end it stops half a screen short",
		is_equal_approx(at_right.x, level_width - 640.0),
		" camera.x=%.0f" % at_right.x)
	_check("so it never shows anything right of the world",
		at_right.x + 640.0 <= level_width + 0.5, " right edge=%.1f" % (at_right.x + 640.0))

	# And it comes back, so it is following rather than stuck.
	_place(p1, Vector2(2000.0, GROUND_Y))
	_place(p2, Vector2(2100.0, GROUND_Y))
	var back := await _settle_camera(2050.0)
	var back_x: float = camera.get_screen_center_position().x
	_check("and it comes back again when they do",
		back and absf(back_x - 2050.0) <= CAMERA_TOLERANCE,
		" camera.x=%.0f target=2050 off by %.1fpx"
			% [back_x, absf(back_x - 2050.0)])

	# The white-line glitch this level had: a camera sitting on a fraction of a
	# pixel drags every seam between two tiles off the pixel grid, and the
	# rasteriser drops a column of background pixels along each seam. Sampled
	# while the camera is genuinely moving, which is when it used to go fractional.
	var fractional_frames := 0
	var moved_frames := 0
	for i in 60:
		var step := 1500.0 + float(i) * 40.0
		_place(p1, Vector2(step, GROUND_Y))
		_place(p2, Vector2(step + 100.0, GROUND_Y))
		await get_tree().physics_frame
		moved_frames += 1
		var cx: float = camera.get_screen_center_position().x
		if cx != roundf(cx):
			fractional_frames += 1
	_check("the camera never leaves the pixel grid while it is moving",
		moved_frames > 0 and fractional_frames == 0,
		" %d of %d frames were off-grid" % [fractional_frames, moved_frames])

	await _park()
	_emit("")


## Waits for the smoothed camera to travel to where the foxes actually are, and
## reports whether it ever got there.
##
## Two things this has to get right, both of which the first version got wrong.
## It used to read the camera's position and then return as soon as one frame had
## moved it less than three quarters of a pixel - but the level only moves the
## camera's target in its own _process, and the camera applies the smoothing
## afterwards, so on the very first frame after a teleport nothing had moved yet
## and it reported "settled" while the camera was still sitting at the far end of
## the map. And because a smoothed camera only ever approaches its target, ending
## on a per-frame threshold left it several pixels short, which is why the "comes
## back again" check could never be an exact one. So the wait is now against the
## place the camera is supposed to be, measured with CAMERA_TOLERANCE.
func _settle_camera(expected_x: float, tolerance: float = CAMERA_TOLERANCE) -> bool:
	var camera := level.camera as Camera2D
	for _i in 300:
		await get_tree().physics_frame
		if absf(camera.get_screen_center_position().x - expected_x) <= tolerance:
			return true
	return false


func _test_the_trees_are_decoration_only() -> void:
	_emit("=== 3. every tree is scenery, and a fox walks through all of them ===")

	var count := 0
	var wrong_picture := 0
	var with_body := 0
	var with_collider := 0
	var in_front := 0
	var tree_xs := PackedStringArray()
	for child in level.trees.get_children():
		count += 1
		tree_xs.append(str(int((child as Node2D).position.x)))
		if child is CollisionObject2D:
			with_body += 1
		if _has_a_collider(child):
			with_collider += 1
		if (child as Node2D).z_index >= 0:
			in_front += 1
		for sub in child.get_children():
			if sub is Sprite2D and (sub as Sprite2D).texture != TREE_TEXTURE:
				wrong_picture += 1

	_check("all ten trees are still there to be looked at", count == 10,
		" trees=%d at x=%s" % [count, ", ".join(tree_xs)])
	_check("every tree is the supplied autumn tree", wrong_picture == 0)
	_check("no tree is a physics body of any kind", with_body == 0,
		" bodies=%d" % with_body)
	_check("no tree has a collision shape or area anywhere under it", with_collider == 0,
		" colliders=%d" % with_collider)
	_check("every tree is drawn behind the level", in_front == 0)

	# Proof rather than proof-by-inspection: put a fox on the floor just before
	# each tree in turn and walk it right. With the old 72px collider a fox could
	# only have reached 66px past the trunk before being stopped, so clearing
	# 100px past every single tree cannot happen while any collider is there.
	#
	# Two things are kept out of the way first, so this measures the trees and
	# nothing else: P2 is parked far past the last tree, because otherwise it is
	# just another fox in the way, and each walk starts clear of the side wall so
	# a run can never begin inside one.
	var constants: Dictionary = level.get_script().get_script_constant_map()
	var wall_width: float = constants.get("WALL_WIDTH", 16.0)
	var clear_of_wall: float = wall_width + PLAYER_W * 0.5 + 10.0
	_place(p2, Vector2(constants.get("LEVEL_WIDTH", 4800.0) - 100.0, GROUND_Y))
	await _wait(2)

	var tree_list: Array = constants["TREES"]
	for entry in tree_list:
		var tx: float = entry
		var start_x: float = maxf(tx - 90.0, clear_of_wall)
		_place(p1, Vector2(start_x, GROUND_Y))
		await _wait(2)
		await _hold([p1.right_action], 70)
		await _wait(2)
		_check("a fox walks straight through the tree at x=%.0f" % tx,
			p1.position.x >= tx + 100.0,
			" reached x=%.0f, needs %.0f" % [p1.position.x, tx + 100.0])

	# Jumping through one too, since a tree must not hold a fox up either.
	var high_x: float = tree_list[2]
	_place(p1, Vector2(maxf(high_x - 90.0, clear_of_wall), GROUND_Y))
	await _wait(2)
	await _hold([p1.right_action, p1.jump_action], 70)
	await _wait(2)
	_check("and jumps straight through it as well", p1.position.x >= high_x + 100.0,
		" reached x=%.0f" % p1.position.x)

	# None of that walking may have disturbed anything else.
	_check("walking through the trees changed nothing else in the level",
		_items_left() == 4 and level.trees.get_child_count() == 10
			and p1.carried_kind == &"" and p2.carried_kind == &"",
		" leaves left=%d" % _items_left())
	await _park()
	_emit("")


## True if anything anywhere under `node` is something physics could collide with.
func _has_a_collider(node: Node) -> bool:
	for sub in node.get_children():
		if sub is CollisionShape2D or sub is CollisionPolygon2D or sub is CollisionObject2D:
			return true
		if _has_a_collider(sub):
			return true
	return false


func _test_every_leaf_can_be_reached() -> void:
	_emit("=== 4. every leaf is really jumped for, solo and stacked ===")

	for kind in KINDS:
		var spot: Dictionary = REACH_SPOTS[kind]
		var x: float = spot["x"]
		var y: float = spot["y"]
		var dir: int = spot["dir"]
		_check("the %s can be picked up off the shelf above it, on its own" % kind,
			await _can_reach(kind, x, y, dir, false),
			" from x=%.0f y=%.0f" % [x, y])
		_check("and the %s can still be picked up with the two foxes stacked" % kind,
			await _can_reach(kind, x, y, dir, true),
			" from x=%.0f y=%.0f" % [x, y])

	# Reaching a leaf and letting go of it again has to leave the level exactly as
	# it was, or the rest of the suite would be testing a level that is not the one
	# the game starts with.
	await _park()
	_check("all four leaves are still in the level after all that reaching",
		_items_left() == 4, " left=%d" % _items_left())
	_check("and neither fox is still holding anything",
		p1.carried_kind == &"" and p2.carried_kind == &"")
	_emit("")


## Whether a fox can really pick this leaf up from one standing spot. Both foxes are
## put back on clear ground first, one of them is stood where a player would stand,
## it jumps, and this only passes if the leaf genuinely changed hands: anything
## weaker than a real pickup would let a level nobody can finish look fine.
func _can_reach(kind: StringName, at_x: float, at_y: float, dir: int,
		stacked: bool) -> bool:
	await _park()
	var stored: Variant = _item(kind)
	if not is_instance_valid(stored):
		return false
	var leaf := stored as GardenItem
	# A leaf that has just been put back cannot be taken again straight away.
	for _i in 90:
		if leaf._respawn_timer <= 0.0:
			break
		await get_tree().physics_frame

	if stacked:
		if not await _stack_at(p1, p2, at_x, at_y):
			return false
	else:
		_place(p1, Vector2(at_x, at_y))
		await _wait(6)

	await _hold([p1.jump_action], 2)
	var steering: Array = []
	if dir > 0:
		steering = [p1.right_action]
	elif dir < 0:
		steering = [p1.left_action]
	for _i in 80:
		if not steering.is_empty():
			Input.action_press(steering[0])
		await get_tree().physics_frame
		if p1.carried_kind == kind:
			break
	for action in steering:
		Input.action_release(action)

	var picked_up := p1.carried_kind == kind
	# Away from the frames before dropping it, so the drop cannot be mistaken for a
	# placement and the leaf cannot be used up by accident.
	await _park()
	return picked_up


func _test_the_four_leaves_are_spread_out() -> void:
	_emit("=== 5. four leaves, each its own picture, spread right across the map ===")

	_check("there are four leaves", items.size() == 4
		and level.leaves.get_child_count() == 4 and _items_left() == 4)
	for kind in KINDS:
		var leaf := items[kind] as GardenItem
		_check("the %s has its own picture" % kind,
			leaf != null and leaf.sprite.texture == LEAF_TEXTURES[kind])
		_check("the %s is cropped to its own artwork" % kind,
			leaf != null and leaf.sprite.region_enabled
			and leaf.sprite.region_rect == LEAF_REGIONS[kind],
			" region=%s" % leaf.sprite.region_rect)
		_check("the %s is not squashed" % kind,
			leaf != null and is_equal_approx(leaf.sprite.scale.x, leaf.sprite.scale.y))
		_check("the %s carries no wording at all" % kind,
			leaf != null and _labels_under(leaf).is_empty())
	_check("no two leaves share a picture",
		(items[&"leaf1"] as GardenItem).sprite.texture
			!= (items[&"leaf2"] as GardenItem).sprite.texture
		and (items[&"leaf2"] as GardenItem).sprite.texture
			!= (items[&"leaf3"] as GardenItem).sprite.texture
		and (items[&"leaf3"] as GardenItem).sprite.texture
			!= (items[&"leaf4"] as GardenItem).sprite.texture)

	# Spread out: a level that has to be walked, not one screen of pickups.
	# The bound below is derived from the map, not guessed. Each leaf's x is
	# pinned to the shelf named in its comment, and the pickup box is 44 wide, so
	# the shelves give these legal ranges: 726..938, 1686..1962, 2326..2538,
	# 3094..3306. The widest leaf1..leaf2 gap any legal placement allows is
	# 1962-726 = 1236 only if both are pushed to their far ends, but that trades
	# against leaf2..leaf3; the best achievable closest pair is 748 (leaf2 hard
	# left against leaf1 hard right). A 900px bound is therefore impossible at any
	# position, so 900 was an outdated number, not a layout defect. 600 keeps the
	# real intent - no two leaves on the same screen - and the span check below
	# carries the part that actually forces a walk.
	var xs: Array[float] = []
	var xs_text := PackedStringArray()
	for kind in KINDS:
		xs.append((items[kind] as GardenItem).position.x)
		xs_text.append(str(int(xs[xs.size() - 1])))
	var tightest := INF
	for i in KINDS.size():
		for j in range(i + 1, KINDS.size()):
			tightest = minf(tightest, absf(xs[i] - xs[j]))
	_check("the leaves are spread right across the map", tightest >= 600.0,
		" closest pair=%.0fpx apart" % tightest)
	_check("and they reach from one end of the map to the other",
		xs[3] - xs[0] >= 2000.0,
		" spanning %.0fpx of a %.0fpx map" % [xs[3] - xs[0],
			level.get_script().get_script_constant_map().get("LEVEL_WIDTH", 0.0)])
	_check("the first leaf is off to the left of the last frame area",
		xs[0] < 1500.0 and xs[3] > 3000.0,
		" xs=%s" % ", ".join(xs_text))

	# Nothing is buried in the terrain, and nothing can be walked into by accident
	# from the floor: each leaf is above a shelf and out of reach of a plain walk.
	for kind in KINDS:
		var leaf := items[kind] as GardenItem
		var box := Rect2(leaf.position - Vector2(leaf.pickup_size, leaf.pickup_size) * 0.5,
			Vector2(leaf.pickup_size, leaf.pickup_size))
		var buried := false
		for child in level.terrain.get_children():
			if child is GroundTile:
				var tile_pos: Vector2 = (child as GroundTile).position
				if box.intersects(Rect2(tile_pos, Vector2(64.0, 56.0))):
					buried = true
		_check("the %s is not buried in a tile" % kind, not buried)
		# A fox standing on the floor sweeps y 374..560, so a leaf whose box is
		# entirely above that needs a jump and cannot be walked into.
		_check("the %s cannot be picked up by walking along the floor" % kind,
			box.end.y <= 374.0, " box bottom=%.0f" % box.end.y)
	_emit("")


func _test_the_frames_match_by_picture_alone() -> void:
	_emit("=== 6. four frames, no words, each shaped for one leaf ===")

	_check("there are four frames", frames.size() == 4
		and level.frames.get_child_count() == 4)
	for kind in KINDS:
		var frame := frames[kind] as LeafFrame
		_check("the %s frame has its own picture" % kind,
			frame != null and frame.frame_sprite.texture == FRAME_TEXTURES[kind])
		_check("the %s frame is not squashed" % kind,
			frame != null and is_equal_approx(frame.frame_sprite.scale.x,
				frame.frame_sprite.scale.y))
		_check("the %s frame carries no wording at all" % kind,
			frame != null and _labels_under(frame).is_empty(),
			" labels=%d" % _labels_under(frame).size())
		_check("the %s frame starts empty, showing no leaf" % kind,
			frame != null and not frame.is_filled
			and not frame.placed_leaf.visible)
	_check("no two frames share a picture",
		(frames[&"leaf1"] as LeafFrame).frame_sprite.texture
			!= (frames[&"leaf2"] as LeafFrame).frame_sprite.texture
		and (frames[&"leaf2"] as LeafFrame).frame_sprite.texture
			!= (frames[&"leaf3"] as LeafFrame).frame_sprite.texture
		and (frames[&"leaf3"] as LeafFrame).frame_sprite.texture
			!= (frames[&"leaf4"] as LeafFrame).frame_sprite.texture)

	# The whole rule is visual, so it has to hold on shape: each frame's ghosted
	# silhouette has to fit its own leaf better than it fits any of the others.
	for kind in KINDS:
		var frame := frames[kind] as LeafFrame
		var leaf_shape: Vector2 = (LEAF_REGIONS[kind] as Rect2).size
		var best_kind := &""
		var best := INF
		var runner_up := INF
		for other in KINDS:
			var other_frame := frames[other] as LeafFrame
			var sil: Vector2 = other_frame.silhouette_size
			var error := absf(log(sil.aspect() / leaf_shape.aspect()))
			if error < best:
				runner_up = best
				best = error
				best_kind = other
			elif error < runner_up:
				runner_up = error
		_check("the %s leaf fits the %s frame and no other" % [kind, best_kind],
			best_kind == kind, " its own error=%.4f next best=%.4f" % [best, runner_up])

	# So each leaf has exactly one frame, and one frame each.
	var closest: Array[StringName] = []
	for kind in KINDS:
		var frame := frames[kind] as LeafFrame
		var leaf_shape: Vector2 = (LEAF_REGIONS[kind] as Rect2).size
		var best := INF
		var best_kind := &""
		for other in KINDS:
			var sil: Vector2 = (frames[other] as LeafFrame).silhouette_size
			var error := absf(log(sil.aspect() / leaf_shape.aspect()))
			if error < best:
				best = error
				best_kind = other
		closest.append(best_kind)
	_check("every leaf has exactly one frame", closest.size() == 4)
	_check("and the four are four different frames", closest.size() == 4
		and closest[0] != closest[1] and closest[1] != closest[2]
		and closest[2] != closest[3] and closest[0] != closest[3])

	# They stand in a row on the raised shelf at the right-hand end, far enough
	# apart that a fox cannot place a leaf by walking past.
	var ordered: Array[LeafFrame] = []
	for kind in KINDS:
		ordered.append(frames[kind] as LeafFrame)
	ordered.sort_custom(func(a: LeafFrame, b: LeafFrame) -> bool:
		return a.position.x < b.position.x)
	_check("the four frames are in a row",
		ordered[3].position.x - ordered[0].position.x > 600.0,
		" x %.0f..%.0f" % [ordered[0].position.x, ordered[3].position.x])
	var left_to_right: Array[StringName] = []
	for frame in ordered:
		left_to_right.append(frame.accepts_kind)
	_check("and deliberately not in the order the leaves are numbered",
		left_to_right != KINDS, " order=%s" % ", ".join(left_to_right))

	var boxes: Array[Rect2] = []
	for kind in KINDS:
		boxes.append(_frame_box(kind))
	var touching := 0
	var smallest_gap := INF
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			if boxes[i].intersects(boxes[j]) or boxes[i].grow(24.0).intersects(boxes[j]):
				touching += 1
			smallest_gap = minf(smallest_gap, absf(boxes[i].position.x - boxes[j].position.x)
				- (boxes[i].size.x + boxes[j].size.x) * 0.5)
	_check("no two frames overlap or even touch", touching == 0,
		" closest boxes are %.0fpx apart" % smallest_gap)
	_check("and a fox cannot be in two at once", smallest_gap > PLAYER_W,
		" gap=%.0fpx, fox=%.0fpx" % [smallest_gap, PLAYER_W])

	# Each frame stands on the shelf, drawn from its own node, and is not drawn
	# into either wall or on top of a fox.
	var constants: Dictionary = level.get_script().get_script_constant_map()
	var wall_width: float = constants.get("WALL_WIDTH", 16.0)
	var level_width: float = constants.get("LEVEL_WIDTH", 0.0)
	var terrace_y: float = constants.get("TERRACE_SURFACE_Y", 448.0)
	var left_wall := Rect2(0.0, 0.0, wall_width, 720.0)
	var right_wall := Rect2(level_width - wall_width, 0.0, wall_width, 720.0)
	for kind in KINDS:
		var frame := frames[kind] as LeafFrame
		_check("the %s frame is standing on the shelf" % kind,
			is_equal_approx(frame.position.y, terrace_y), " y=%.1f" % frame.position.y)
		var drawn := frame.drawn_rect()
		_check("and the %s frame really is drawn standing on it" % kind,
			is_equal_approx(drawn.end.y, frame.position.y),
			" art bottom=%.1f node y=%.1f" % [drawn.end.y, frame.position.y])
		_check("and the %s frame is drawn over its own node, not beside it" % kind,
			is_equal_approx(drawn.get_center().x, frame.position.x),
			" centre x=%.1f node x=%.1f" % [drawn.get_center().x, frame.position.x])
		_check("the %s frame is not drawn into a wall" % kind,
			not drawn.intersects(left_wall) and not drawn.intersects(right_wall),
			" x %.0f..%.0f" % [drawn.position.x, drawn.end.x])
		# The pickup box runs from the middle of the ghosted leaf down to the
		# frame's own feet, so a fox standing on the shelf is inside it without
		# having to jump at all.
		var box := _frame_box(kind)
		_check("the %s frame's box reaches the shelf a fox stands on" % kind,
			is_equal_approx(box.end.y, terrace_y)
			and box.position.y < terrace_y - 100.0,
			" box y %.0f..%.0f" % [box.position.y, box.end.y])

	# No fox is drawn on top of a frame at either end of the map.
	var spawn_art: Array[Rect2] = []
	for fox: Player in [p1, p2]:
		spawn_art.append(_art_of(fox.sprite))
	var any_over := false
	for kind in KINDS:
		var frame := frames[kind] as LeafFrame
		for rect in spawn_art:
			if frame.drawn_rect().intersects(rect):
				any_over = true
	_check("and no frame is drawn on top of a fox", not any_over)

	# And the frames are on the world, not floating in front of a camera.
	var frame_spans := PackedStringArray()
	for kind in KINDS:
		var span := _frame_box(kind)
		frame_spans.append("%.0f..%.0f" % [span.position.x, span.end.x])
	_check("all four frames are inside the world",
		_frame_box(&"leaf1").position.x >= 0.0
		and _frame_box(&"leaf4").end.x <= level_width,
		" %s" % " ".join(frame_spans))
	_emit("")


func _test_the_wrong_frames_refuse_everything() -> void:
	_emit("=== 7. all twelve wrong-frame attempts are refused, with a notice ===")
	# Short notice for the twelve cases so the run does not sit through twelve 1.2s
	# pauses; the real 1.2s is checked at the end of this section.
	level.wrong_leaf_notice_time = 0.2

	var refused := 0
	for held in KINDS:
		for target in KINDS:
			if held == target:
				continue
			if await _wrong_frame_case(held, target):
				refused += 1

	_check("all twelve wrong frames refused it", refused == 12, " refused=%d" % refused)
	_check("nothing was consumed by any of the twelve attempts", _items_left() == 4,
		" left=%d" % _items_left())
	var any_filled := false
	for kind in KINDS:
		if (frames[kind] as LeafFrame).is_filled:
			any_filled = true
	_check("no frame was filled by a wrong attempt", not any_filled)
	_check("and the level is not finished", _placements_seen == 0
		and not level.level_complete_banner.visible
		and not level.next_level_button.visible)

	# The real notice length, and that it takes itself away again.
	_emit("--- and the notice clears on its own, at the real 1.2s ---")
	level.wrong_leaf_notice_time = 1.2
	await _park()
	var held_kind := await _grab_any_leaf(p1)
	if held_kind == &"":
		_check("a leaf was still there for the notice test", false)
	else:
		var target := &"leaf4" if held_kind != &"leaf4" else &"leaf1"
		await _stand_in(p1, target)
		_check("the notice is up", _notice_is_saying("Wrong frame!"))
		await _park()
		_check("and it goes away by itself once the fox has left",
			await _wait_for_notice(false, 3.0))
	_emit("")


## Picks a leaf up for real, by jumping for it from the shelf below, and reports
## which one it got. Used by the notice test, which needs a fox genuinely holding
## something rather than being handed one.
func _grab_any_leaf(p: Player) -> StringName:
	for kind in KINDS:
		var stored: Variant = _item(kind)
		if not is_instance_valid(stored):
			continue
		var leaf := stored as GardenItem
		for _i in 90:
			if leaf._respawn_timer <= 0.0:
				break
			await get_tree().physics_frame
		var spot: Dictionary = REACH_SPOTS[kind]
		var dir: int = spot["dir"]
		_place(p, Vector2(spot["x"], spot["y"]))
		await _wait(6)
		await _hold([p.jump_action], 2)
		var steering: Array = []
		if dir > 0:
			steering = [p.right_action]
		elif dir < 0:
			steering = [p.left_action]
		for _i in 80:
			if not steering.is_empty():
				Input.action_press(steering[0])
			await get_tree().physics_frame
			if p.carried_kind != &"":
				break
		for action in steering:
			Input.action_release(action)
		if p.carried_kind != &"":
			# Deliberately NOT parked here. _park() calls drop_carried(), which
			# would put the leaf straight back on its shelf and leave the fox
			# empty-handed - so the caller would walk up to the frame with
			# nothing to be refused, which is exactly what the notice test needs
			# to avoid. The fox is left where it picked the leaf up, holding it,
			# and the caller walks it into the frame from there.
			return p.carried_kind
	return &""


## Brings one leaf to the wrong frame and checks that nothing at all happened to it.
func _wrong_frame_case(held: StringName, target: StringName) -> bool:
	await _park()
	var stored: Variant = _item(held)
	if not is_instance_valid(stored):
		_check("%s could be picked up at all" % held, false)
		return false
	var leaf := stored as GardenItem
	for _i in 90:
		if leaf._respawn_timer <= 0.0:
			break
		await get_tree().physics_frame

	var spot: Dictionary = REACH_SPOTS[held]
	var dir: int = spot["dir"]
	_place(p1, Vector2(spot["x"], spot["y"]))
	await _wait(6)
	await _hold([p1.jump_action], 2)
	var steering: Array = []
	if dir > 0:
		steering = [p1.right_action]
	elif dir < 0:
		steering = [p1.left_action]
	for _i in 80:
		if not steering.is_empty():
			Input.action_press(steering[0])
		await get_tree().physics_frame
		if p1.carried_kind == held:
			break
	for action in steering:
		Input.action_release(action)

	if p1.carried_kind != held:
		_check("%s could be picked up at all" % held, false)
		await _park()
		return false

	await _stand_in(p1, target)
	var frame := frames[target] as LeafFrame

	_check("%s into the %s frame shows the notice" % [held, target],
		_notice_is_saying("Wrong frame!"))
	_check("%s is still in the fox's hands after the %s frame refused it"
		% [held, target], p1.carried_kind == held,
		" carrying=%s" % p1.carried_kind)
	_check("and the %s leaf was not consumed" % held,
		is_instance_valid(leaf) and not leaf.is_consumed)
	_check("and the %s frame did not fill" % target, not frame.is_filled)
	_check("and the %s frame is still showing no leaf" % target,
		not frame.placed_leaf.visible)
	await _park()
	return true


func _test_the_right_frames_place_for_good() -> void:
	_emit("=== 8. the matching frame takes each leaf, and it is gone for good ===")

	# P1 places two of them and P2 places the other two, so both foxes are proved to
	# be able to carry a leaf the whole way and place it.
	var carriers := {0: p1, 1: p2, 2: p1, 3: p2}
	for index in KINDS.size():
		var kind := KINDS[index]
		var carrier := carriers[index] as Player
		await _park()
		var item: Variant = await _deliver_leaf(carrier, kind)
		if item == null:
			_check("the %s was still there to be placed" % kind, false)
			continue
		_check("%s picked up the %s" % [carrier.label_text, kind],
			carrier.carried_kind == kind, " carrying=%s" % carrier.carried_kind)

		await _stand_in(carrier, kind)
		var frame := frames[kind] as LeafFrame
		_check("the %s frame took the %s" % [kind, kind], frame.is_filled)
		_check("and it is now showing the %s inside it" % kind,
			frame.placed_leaf.visible
			and frame.placed_leaf.texture == LEAF_TEXTURES[kind])
		_check("the %s is gone from the level for good" % kind,
			not is_instance_valid(item))
		_check("the fox's hands are empty again", carrier.carried_kind == &"")
		_check("and the %s frame is still in the level" % kind,
			is_instance_valid(frame) and frame.get_parent() == level.frames)
		_check("no notice for the right frame", not level.wrong_leaf_label.visible)

		# The placed leaf has to fill the ghosted silhouette, which is what makes the
		# frame read as "this leaf belongs here" rather than as a picture with
		# something dropped in front of it.
		var silhouette := frame.silhouette_rect()
		_check("the placed %s really is inside the %s frame's own outline"
			% [kind, kind],
			silhouette.size.x > 20.0 and silhouette.size.y > 20.0
			and _art_of(frame.placed_leaf).get_center().distance_to(
				silhouette.get_center()) < 1.0,
			" leaf=%.0fx%.0f" % [silhouette.size.x, silhouette.size.y])

		# The bug this whole thing exists to prevent: the leaf coming back to where
		# it was found and being picked up a second time.
		await _park()
		_place(carrier, item_spots[kind])
		await _wait(8)
		_check("nothing is left at the %s's old spot" % kind,
			carrier.carried_kind == &"", " carrying=%s" % carrier.carried_kind)
		_check("and no %s reappeared" % kind, not is_instance_valid(_item(kind)))

	# Only after the fourth may the completion screen be on its way.
	await _park()
	_check("all four were placed", _placements_seen == 4, " placements=%d" % _placements_seen)
	_check("no leaves are left in the level", _items_left() == 0,
		" left=%d" % _items_left())
	var all_shown := true
	for kind in KINDS:
		var frame := frames[kind] as LeafFrame
		if not frame.placed_leaf.visible or not frame.is_filled:
			all_shown = false
	_check("and all four frames are showing their own leaf", all_shown)
	_emit("")


## Picks a leaf up for real and carries it to its frame. Returns the leaf node, which
## is freed the moment it is placed, so the caller checks that with
## is_instance_valid.
func _deliver_leaf(p: Player, kind: StringName) -> Variant:
	var stored: Variant = _item(kind)
	if not is_instance_valid(stored):
		return null
	var leaf := stored as GardenItem
	for _i in 90:
		if leaf._respawn_timer <= 0.0:
			break
		await get_tree().physics_frame

	var spot: Dictionary = REACH_SPOTS[kind]
	var dir: int = spot["dir"]
	_place(p, Vector2(spot["x"], spot["y"]))
	await _wait(6)
	await _hold([p.jump_action], 2)
	var steering: Array = []
	if dir > 0:
		steering = [p.right_action]
	elif dir < 0:
		steering = [p.left_action]
	for _i in 80:
		if not steering.is_empty():
			Input.action_press(steering[0])
		await get_tree().physics_frame
		if p.carried_kind == kind:
			break
	for action in steering:
		Input.action_release(action)
	return leaf if p.carried_kind == kind else null


func _test_the_completion_screen() -> void:
	_emit("=== 9. the completion screen only arrives once all four are placed ===")

	var since_place := float(Time.get_ticks_msec() - _placed_at) / 1000.0
	_check("the banner is not up on the very frame the last leaf went in",
		not _banner_on_place_frame)
	_check("the Next Level button is still out of the way during the pause",
		not level.next_level_button.visible and level.next_level_button.disabled,
		" %.2fs on" % since_place)

	var delay: float = level.complete_banner_delay
	var left: float = delay + 0.3 - since_place
	if left > 0.0:
		await get_tree().create_timer(left).timeout

	_check("the Level Complete picture is up",
		level.level_complete_banner.visible
		and level.level_complete_banner.texture == COMPLETE_TEXTURE,
		" timer=%.3f shown=%s" % [level._banner_timer, str(level._banner_shown)])
	_check("and the Next Level button is up with it",
		level.next_level_button.visible and not level.next_level_button.disabled)

	var button: TextureButton = level.next_level_button
	_check("the button's middle is on the screen",
		SCREEN.has_point(button.get_global_rect().get_center()),
		" centre=%s" % button.get_global_rect().get_center())
	_check("and its pressed signal is really wired to the level's handler",
		button.pressed.is_connected(level._on_next_level_pressed))

	# The button is not pressed here. Pressing it would change the scene out from
	# under this test and free it, exactly as in _next_level_test, so where it would
	# go is checked from the level's own declared scene instead. The button really is
	# wired to the handler checked immediately above, and
	# tests/_season_chain_test.gd is what really drives that handler and proves
	# Winter arrives.
	#
	# 2026-10-04: a finished Autumn now leads to WINTER, not Spring. Winter exists,
	# so the old "go back to Spring" was the placeholder this replaced. These checks
	# were made stricter rather than swapped over: the old ones could be satisfied
	# by any scene at all, whereas these insist on Winter specifically AND insist
	# Autumn is no longer the end of the chain.
	var constants: Dictionary = level.get_script().get_script_constant_map()
	_check("and it leads on to Winter, which does exist",
		constants.get("NEXT_SCENE") == WINTER_SCENE and ResourceLoader.exists(WINTER_SCENE),
		" next=%s" % constants.get("NEXT_SCENE"))
	_check("and Autumn is no longer the end of the chain, so it does not skip back to Spring",
		constants.get("NEXT_SCENE") != SPRING_SCENE
		and constants.get("NEXT_SCENE") != SUMMER_SCENE)
	# The whole chain, read from each season's own declared constant rather than
	# typed in here, so the four legs are checked together and cannot disagree.
	# Instantiating without adding to the tree does not run _ready, so this reads the
	# constants without building a single tile.
	_check("Summer still leads on to Autumn",
		_next_scene_of(SUMMER_SCENE) == AUTUMN_SCENE,
		" summer next=%s" % _next_scene_of(SUMMER_SCENE))
	# 2026-10-14: Winter no longer loops straight back to Spring. Once Winter 2 is
	# done the ending plays, and its Play again button is the way back to Spring.
	_check("and Winter ends the year at the ending, which does exist",
		_next_scene_of(WINTER_SCENE) == ENDING_SCENE and ResourceLoader.exists(ENDING_SCENE),
		" winter next=%s" % _next_scene_of(WINTER_SCENE))
	_emit("")


## A season's declared Next Level target, read off its script without running it.
func _next_scene_of(path: String) -> String:
	if not ResourceLoader.exists(path):
		return "<missing scene %s>" % path
	var root: Node = (load(path) as PackedScene).instantiate()
	var found: Variant = root.get_script().get_script_constant_map().get("NEXT_SCENE")
	root.free()
	return str(found)


func _finish(ok: bool) -> void:
	_emit("")
	_emit("=".repeat(58))
	if ok:
		_emit("ALL CHECKS PASSED")
	else:
		_emit("FAILURES (%d): %s" % [failures.size(), ", ".join(failures)])
	_emit("=".repeat(58))
	get_tree().quit(0 if ok else 1)