extends Node2D

## Automated regression suite for the Summer level: the dogs, the rubbish, the
## three bins, the wrong-bin refusal and the completion screen.
##
## It builds the real SummerLevel.tscn exactly as the game does and drives it
## with simulated input, in the same style as _garden_test. Everything asserted
## here is read out of the live level, so a check cannot pass just because the
## level was never really built.
##
## Order matters. The rubbish-reachability checks and the six wrong-bin cases both
## run while all three pieces of rubbish are still in the level, because after the
## last one is sorted the level is finished and there is nothing left to carry.

const SUMMER_SCENE := "res://scenes/SummerLevel.tscn"
const SPRING_SCENE := "res://scenes/Level.tscn"

const DOG1_TEXTURE := preload("res://assets/Summer/Dog1.png")
const DOG2_TEXTURE := preload("res://assets/Summer/Dog2.png")
const CAT1_TEXTURE := preload("res://assets/Spring/Cat1.png")
const CAT2_TEXTURE := preload("res://assets/Spring/Cat2.png")
const SAND_TEXTURE := preload("res://assets/Summer/Sand.png")
const WATER_TEXTURE := preload("res://assets/Summer/Water.png")
const PAPER_TEXTURE := preload("res://assets/Summer/Paper.png")
const PLASTIC_TEXTURE := preload("res://assets/Summer/Plastic bag.png")
const GLASS_TEXTURE := preload("res://assets/Summer/Glass bottle.png")
const PAPER_BIN_TEXTURE := preload("res://assets/Summer/Paper Bin.png")
const PLASTIC_BIN_TEXTURE := preload("res://assets/Summer/Plastic Bin.png")
const GLASS_BIN_TEXTURE := preload("res://assets/Summer/Glass bin.png")
const COMPLETE_TEXTURE := preload("res://assets/Level Complete.png")
const NEXT_TEXTURE := preload("res://assets/Next Level.png")

const DOG_REGION := Rect2(8, 24, 240, 208)
const BIN_REGION_SIZE := Vector2(90, 110)

const PLAYER_H := 52.0
const GROUND_Y := 560.0
const SCREEN := Rect2(0.0, 0.0, 1280.0, 720.0)
const SCREEN_CENTRE := Vector2(640.0, 360.0)

## Flat open ground, clear of every bin box and every piece of rubbish, so
## parking here can never be standing in a bin or standing on an item. The bins
## sit at x=560, 860 and 1120 and each reaches 45px either side of that, so
## 150 and 750 are both well clear of the nearest one.
const PARK_A := Vector2(150.0, GROUND_Y)
const PARK_B := Vector2(750.0, GROUND_Y)

## Where the two-dog stack test stands them. Also clear of every bin box and
## every piece of rubbish: a dog that drifts a little either way while being
## stacked must not brush a bin or pick something up, or the test would be
## measuring the wrong thing.
const STACK_X := 150.0

## Where a player jumps from to pick each piece of rubbish up: the sand shelf it
## is sitting above, and which way the dog leans as it goes. The paper and the
## plastic are jumped for straight up from the shelf under them; the glass bottle
## is jumped for from the top shelf, which is the only shelf near it. These are
## the spots a player would use, not the only spots that happen to work.
const REACH_SPOTS := {
	&"paper": {"x": 432.0, "y": 448.0, "dir": 0},
	&"plastic": {"x": 752.0, "y": 336.0, "dir": 0},
	&"glass": {"x": 912.0, "y": 224.0, "dir": 1},
}

const ITEM_TEXTURES := {
	&"paper": PAPER_TEXTURE,
	&"plastic": PLASTIC_TEXTURE,
	&"glass": GLASS_TEXTURE,
}
const BIN_TEXTURES := {
	&"paper": PAPER_BIN_TEXTURE,
	&"plastic": PLASTIC_BIN_TEXTURE,
	&"glass": GLASS_BIN_TEXTURE,
}
const KINDS: Array[StringName] = [&"paper", &"plastic", &"glass"]

var level: Node2D
var p1: Player
var p2: Player
var items: Dictionary = {}
var bins: Dictionary = {}
var item_spots: Dictionary = {}

var failures: Array[String] = []
var _elapsed := 0.0
var _sorts_seen := 0
var _sorted_at := 0
var _banner_on_sort_frame := true


func _ready() -> void:
	level = (load(SUMMER_SCENE) as PackedScene).instantiate()
	add_child(level)
	await get_tree().process_frame
	_gather()
	_run.call_deferred()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > 240.0:
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
	var dogs: Array[Player] = []
	for child in level.trash.get_children():
		if child is GardenItem:
			var item := child as GardenItem
			items[item.item_kind] = item
			item_spots[item.item_kind] = item.position
	for child in level.bins.get_children():
		if child is TrashBin:
			var bin := child as TrashBin
			bins[bin.accepts_kind] = bin
			bin.rubbish_sorted.connect(_on_sorted)
	for child in level.players.get_children():
		if child is Player:
			dogs.append(child as Player)
	p1 = dogs[0]
	p2 = dogs[1]


## Every bin reports a real sort here, so this is the test's own count, taken
## from the bin rather than from a flag the level sets for itself. It fires on
## the same frame as the sort, which is what makes the banner timing checkable.
func _on_sorted(kind: StringName) -> void:
	_sorts_seen += 1
	_sorted_at = Time.get_ticks_msec()
	_banner_on_sort_frame = level.level_complete_banner.visible


## The rubbish of this kind as the test last knew it, or null once it has been
## sorted away. Read with get() on purpose: after a sort the entry is a freed
## object, and indexing a missing key would be an error rather than a null.
func _item(kind: StringName) -> Variant:
	return items.get(kind, null)


## How many pieces of rubbish are still in the level. A sorted one has its node
## removed, so this only ever goes down and must end at zero.
func _items_left() -> int:
	var count := 0
	for child in level.trash.get_children():
		if child is GardenItem:
			count += 1
	return count


## Where the bin's pickup box actually is, from the collider rather than a
## hard-coded number, so "the bins are far enough apart" is measured on the thing
## a dog would actually touch.
func _bin_box(kind: StringName) -> Rect2:
	var bin := bins[kind] as TrashBin
	var body := bin.get_node("CollisionShape2D") as CollisionShape2D
	var shape := body.shape as RectangleShape2D
	return Rect2(bin.position + body.position - shape.size * 0.5, shape.size)


## Where a sprite's artwork really lands on screen, from its own transform. Used
## for the dogs here so "the bin is not drawn over a dog" is measured on pixels
## rather than on a guessed picture size.
func _art_of(sprite: Sprite2D) -> Rect2:
	var local := sprite.get_rect()
	var top_left: Vector2 = sprite.global_transform * local.position
	var bottom_right: Vector2 = sprite.global_transform * local.end
	return Rect2(top_left, bottom_right - top_left)


func _stand_in(p: Player, kind: StringName) -> void:
	var bin := bins[kind] as TrashBin
	_place(p, Vector2(bin.position.x, bin.position.y))
	await _wait(6)


## Puts both dogs back on flat open ground with empty hands and no stack.
func _park() -> void:
	for p: Player in [p1, p2]:
		p.drop_carried()
		p._set_support(null)
		p.velocity = Vector2.ZERO
		p.collision_mask = 3
	_place(p1, PARK_A)
	_place(p2, PARK_B)
	await _wait(6)


## Stands a dog on a piece of rubbish until the pickup happens. Returns null if the
## piece is no longer in the level, so a test that runs out of rubbish reports a
## failed check instead of tripping over a freed node.
func _grab(p: Player, kind: StringName) -> GardenItem:
	var stored: Variant = _item(kind)
	if not is_instance_valid(stored):
		return null
	var item := stored as GardenItem
	# A piece that has just been put back cannot be taken again straight away, so
	# wait that out rather than guessing at a frame count.
	for _i in 60:
		if item._respawn_timer <= 0.0:
			break
		await get_tree().physics_frame
	_place(p, item.position)
	await _wait(5)
	return item


## Drops one dog onto the other's head, in stages, and reports whether the ride
## link actually formed. The staging matters: the physics server needs a few
## frames after a teleport, and dropping a dog straight onto the spot the other
## still occupies makes the engine shove them apart sideways.
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


## Waits until the "Wrong bin!" notice is showing or has gone, and reports whether
## it got there in time. Wall-clock, so headless frame rate does not matter.
func _wait_for_notice(showing: bool, seconds: float) -> bool:
	var started := Time.get_ticks_msec()
	while level.wrong_bin_label.visible != showing:
		if float(Time.get_ticks_msec() - started) > seconds * 1000.0:
			return false
		await get_tree().process_frame
	return true


func _notice_is_saying(text: String) -> bool:
	return level.wrong_bin_label.visible and level.wrong_bin_label.text == text


## Counts the sorts and stamps the wall clock, so the pause before the banner can
## be measured from the real moment the last piece was sorted.
func _watch_for_completion() -> void:
	while _sorts_seen < 3:
		await get_tree().process_frame


func _run() -> void:
	await _test_the_level_is_summer()
	await _test_the_dogs_still_play()
	await _test_every_piece_of_rubbish_can_be_reached()
	await _test_the_wrong_bins_refuse_everything()
	await _test_the_right_bins_sort_for_good()
	await _test_the_completion_screen()
	_finish(failures.is_empty())


func _test_the_level_is_summer() -> void:
	_emit("=== 1. Summer is built: dogs, sand, sea, three bins, three rubbish ===")

	_check("the scene is a level, not the old placeholder",
		level is Node2D and level.get_child_count() > 0
		and not level.get_script().get_script_constant_map().has("SPRING_SCENE"),
		" root=%s" % level.get_class())
	_check("the container nodes are all there",
		level.terrain != null and level.walls != null and level.water != null
		and level.trash != null and level.bins != null and level.players != null)
	_check("there are two dogs", p1 != null and p2 != null
		and level.players.get_child_count() == 2)

	# The artwork is the only thing that changed about the players.
	_check("P1 is Dog1", p1.sprite.texture == DOG1_TEXTURE)
	_check("P2 is Dog2", p2.sprite.texture == DOG2_TEXTURE)
	_check("neither dog is a cat",
		p1.sprite.texture != CAT1_TEXTURE and p2.sprite.texture != CAT2_TEXTURE)
	for dog: Player in [p1, p2]:
		_check("%s is cropped to the dog's artwork" % dog.label_text,
			dog.sprite.region_enabled and dog.sprite.region_rect == DOG_REGION,
			" region=%s" % dog.sprite.region_rect)
		_check("%s is not squashed" % dog.label_text,
			is_equal_approx(dog.sprite.scale.x, dog.sprite.scale.y),
			" scale=%.4f" % dog.sprite.scale.x)
		_check("%s stands on the collider base" % dog.label_text,
			is_equal_approx(dog.sprite.offset.y, -DOG_REGION.size.y * 0.5))
		_check("%s is the same size as a cat would be" % dog.label_text,
			is_equal_approx(dog.display_height, 56.0))

	# The controls are Spring's, unchanged, on the same two players.
	_check("P1 still uses the Spring controls",
		p1.left_action == &"p1_left" and p1.right_action == &"p1_right"
		and p1.jump_action == &"p1_jump")
	_check("P2 still uses the Spring controls",
		p2.left_action == &"p2_left" and p2.right_action == &"p2_right"
		and p2.jump_action == &"p2_jump")

	# The ground is sand, and it is the same tile scene Spring uses.
	var tiles := 0
	var sand_tiles := 0
	for child in level.terrain.get_children():
		if child is GroundTile:
			tiles += 1
			if (child as GroundTile).sprite.texture == SAND_TEXTURE:
				sand_tiles += 1
	_check("the ground is built from GroundTile", tiles == 69, " tiles=%d" % tiles)
	_check("and every tile is the summer sand", sand_tiles == tiles,
		" sand=%d/%d" % [sand_tiles, tiles])

	# The sea is scenery: sprites only, nothing that can collide or be picked up.
	var water_sprites := 0
	var water_solid := 0
	var water_in_front := 0
	for child in level.water.get_children():
		if child is Sprite2D:
			water_sprites += 1
			if (child as Sprite2D).texture != WATER_TEXTURE:
				water_solid += 1
			if (child as Sprite2D).z_index >= 0:
				water_in_front += 1
		else:
			water_solid += 1
	_check("the sea is drawn from Water.png", water_sprites == 80,
		" sprites=%d" % water_sprites)
	_check("and it is scenery only, with nothing solid in it", water_solid == 0)
	_check("drawn behind the level, not over it", water_in_front == 0)

	# The three bins: right picture for each, far enough apart to be unusable by
	# mistake, standing on the ground and inside the screen.
	_check("there are three bins", bins.size() == 3 and level.bins.get_child_count() == 3)
	for kind in KINDS:
		var bin := bins[kind] as TrashBin
		_check("the %s bin has its own picture" % kind,
			bin != null and bin.sprite.texture == BIN_TEXTURES[kind])
		_check("the %s bin is on the flat ground" % kind,
			bin != null and is_equal_approx(bin.position.y, GROUND_Y),
			" y=%.1f" % bin.position.y)
		# The sprite is centred, so it is lifted by half its own height and by
		# nothing sideways: that puts the artwork's bottom edge on the node and
		# its middle over the node, which is what makes the bin stand on the
		# ground instead of hovering over it or hanging off to one side.
		_check("the %s bin is anchored bottom edge to its node" % kind,
			bin != null and is_equal_approx(bin.sprite.offset.y, -bin.art_region.size.y * 0.5)
			and is_zero_approx(bin.sprite.offset.x),
			" offset=%s" % bin.sprite.offset)
		var drawn: Rect2 = bin.drawn_rect()
		_check("and the %s bin really is drawn standing on the ground" % kind,
			is_equal_approx(drawn.end.y, bin.position.y),
			" art bottom=%.1f node y=%.1f" % [drawn.end.y, bin.position.y])
		_check("and the %s bin is drawn over its own node, not beside it" % kind,
			is_equal_approx(drawn.get_center().x, bin.position.x),
			" art centre x=%.1f node x=%.1f" % [drawn.get_center().x, bin.position.x])
		_check("the %s bin is inside the screen" % kind,
			bin != null and SCREEN.has_point(bin.position + Vector2(0.0, -56.0)))
	_check("the bins do not all share one picture",
		(bins[&"paper"] as TrashBin).sprite.texture
			!= (bins[&"plastic"] as TrashBin).sprite.texture
		and (bins[&"plastic"] as TrashBin).sprite.texture
			!= (bins[&"glass"] as TrashBin).sprite.texture)

	var paper_box := _bin_box(&"paper")
	var plastic_box := _bin_box(&"plastic")
	var glass_box := _bin_box(&"glass")
	_check("no two bins overlap", not paper_box.intersects(plastic_box)
		and not plastic_box.intersects(glass_box) and not paper_box.intersects(glass_box))
	_check("and no two bins are touching", not paper_box.grow(24.0).intersects(plastic_box)
		and not plastic_box.grow(24.0).intersects(glass_box),
		" gaps=%.0fpx, %.0fpx" % [plastic_box.position.x - paper_box.end.x,
			glass_box.position.x - plastic_box.end.x])
	_check("the bins are far apart across the level",
		plastic_box.position.x - paper_box.end.x >= 150.0
		and glass_box.position.x - plastic_box.end.x >= 150.0)
	_check("a dog cannot be in two bins at once",
		BIN_REGION_SIZE.x < plastic_box.position.x - paper_box.end.x)

	# A bin standing on the ground can still look wrong without the physics
	# noticing anything: drawn into a wall, or drawn on top of a dog. Both were
	# real here once, so both are checked against the artwork's real pixels.
	var constants: Dictionary = level.get_script().get_script_constant_map()
	var wall_width: float = constants.get("WALL_WIDTH", 16.0)
	var level_width: float = constants.get("LEVEL_WIDTH", 1280.0)
	var left_wall := Rect2(0.0, 0.0, wall_width, 720.0)
	var right_wall := Rect2(level_width - wall_width, 0.0, wall_width, 720.0)
	var spawn_art: Array[Rect2] = []
	for dog: Player in [p1, p2]:
		spawn_art.append(_art_of(dog.sprite))
	for kind in KINDS:
		var bin := bins[kind] as TrashBin
		var drawn: Rect2 = bin.drawn_rect()
		_check("the %s bin is not drawn into a wall" % kind,
			not drawn.intersects(left_wall) and not drawn.intersects(right_wall),
			" art x %.0f..%.0f" % [drawn.position.x, drawn.end.x])
		var over_dog := false
		for rect in spawn_art:
			if drawn.intersects(rect):
				over_dog = true
		_check("and the %s bin is not drawn on top of a dog" % kind, not over_dog)
		_check("and the %s bin's own collider is off the walls too" % kind,
			not _bin_box(kind).intersects(left_wall)
			and not _bin_box(kind).intersects(right_wall))

	# The rubbish: the right picture for each kind, one of each, nothing else.
	_check("there are three pieces of rubbish", items.size() == 3
		and level.trash.get_child_count() == 3 and _items_left() == 3)
	for kind in KINDS:
		var item := items[kind] as GardenItem
		_check("the %s rubbish has its own picture" % kind,
			item != null and item.sprite.texture == ITEM_TEXTURES[kind])
	_check("every kind sits nearest its own bin, by a clear margin",
		_nearest_bin(&"paper") == &"paper" and _nearest_bin(&"plastic") == &"plastic"
		and _nearest_bin(&"glass") == &"glass",
		" paper->%s plastic->%s glass->%s" % [_nearest_bin(&"paper"),
			_nearest_bin(&"plastic"), _nearest_bin(&"glass")])

	# The completion screen is there and, like Spring's, is out of the way.
	_check("the Level Complete picture is the shared one",
		level.level_complete_banner.texture == COMPLETE_TEXTURE)
	_check("and it starts hidden", not level.level_complete_banner.visible)
	_check("the Next Level button is the shared one",
		level.next_level_button.texture_normal == NEXT_TEXTURE)
	_check("and it starts hidden", not level.next_level_button.visible)
	_check("and inert", level.next_level_button.disabled)
	_check("the banner waits about 1.5s after the last sort",
		level.complete_banner_delay >= 1.0 and level.complete_banner_delay <= 2.0,
		" delay=%.2fs" % level.complete_banner_delay)
	_check("the wrong-bin notice is a sensible length",
		level.wrong_bin_notice_time >= 0.5 and level.wrong_bin_notice_time <= 2.0,
		" time=%.2fs" % level.wrong_bin_notice_time)
	_check("and it starts hidden", not level.wrong_bin_label.visible)
	_check("the notice says exactly what it should",
		level.wrong_bin_label.text == "Wrong bin!", " text=%s" % level.wrong_bin_label.text)

	# The notice has to be readable without sitting on top of what is being played.
	var notice_rect := Rect2(level.wrong_bin_label.position, level.wrong_bin_label.size)
	_check("the notice sits up in the top of the screen",
		notice_rect.end.y <= 200.0, " bottom=%.0f" % notice_rect.end.y)
	var over_something := false
	for kind in KINDS:
		var bin := bins[kind] as TrashBin
		if notice_rect.intersects(bin.drawn_rect()):
			over_something = true
		if notice_rect.intersects(Rect2(item_spots[kind] - Vector2(40.0, 40.0),
				Vector2(80.0, 80.0))):
			over_something = true
	_check("and it covers neither a bin nor any rubbish", not over_something)
	_emit("")


## Which bin a piece of rubbish is closest to. A tie would mean the picture alone
## could not tell a player where it goes.
func _nearest_bin(kind: StringName) -> StringName:
	var spot: Vector2 = item_spots[kind]
	var best := &""
	var best_distance := INF
	for bin_kind in KINDS:
		var bin := bins[bin_kind] as TrashBin
		var distance: float = absf(spot.x - bin.position.x)
		if distance < best_distance:
			best_distance = distance
			best = bin_kind
	return best


func _test_the_dogs_still_play() -> void:
	_emit("=== 2. both dogs move, jump, face the right way and stack ===")
	await _park()

	# Movement, on each player's own keys.
	_place(p1, PARK_A)
	var start_x := p1.position.x
	await _hold([p1.right_action], 20)
	_check("P1 walks right on its own key", p1.position.x > start_x + 50.0,
		" %.0f -> %.0f" % [start_x, p1.position.x])

	_place(p2, PARK_B)
	var start_x2 := p2.position.x
	await _hold([p2.left_action], 20)
	_check("P2 walks left on its own key", p2.position.x < start_x2 - 50.0,
		" %.0f -> %.0f" % [start_x2, p2.position.x])

	# Facing. Both dogs are drawn facing left, exactly like the cats, so flipping
	# is still what turns them right.
	_place(p1, PARK_A)
	await _wait(4)
	await _hold([p1.right_action], 8)
	_check("P1 faces right when it walks right", p1.sprite.flip_h)
	await _hold([p1.left_action], 8)
	_check("and faces left when it walks left", not p1.sprite.flip_h)

	# Jumping, on each player's own key.
	_place(p1, PARK_A)
	await _wait(6)
	var floor_y := p1.position.y
	var highest := floor_y
	await _hold([p1.jump_action], 2)
	for _i in 60:
		await get_tree().physics_frame
		highest = minf(highest, p1.position.y)
	_check("P1 jumps", highest < floor_y - 80.0,
		" %.0f -> %.0f" % [floor_y, highest])

	_place(p2, PARK_B)
	await _wait(6)
	var floor_y2 := p2.position.y
	var highest2 := floor_y2
	await _hold([p2.jump_action], 2)
	for _i in 60:
		await get_tree().physics_frame
		highest2 = minf(highest2, p2.position.y)
	_check("P2 jumps", highest2 < floor_y2 - 80.0,
		" %.0f -> %.0f" % [floor_y2, highest2])

	# Stacking: the whole reason the two players share a keyboard.
	await _park()
	_check("one dog can stand on the other", await _stack_at(p1, p2, STACK_X, GROUND_Y))
	_check("and the link is the supporter's rider list",
		(p2 as Player)._riders.has(p1) and (p1 as Player)._support == p2)
	_check("a rider rests one body height up",
		is_equal_approx((p2 as Player).position.y - (p1 as Player).position.y, PLAYER_H),
		" %.1f" % ((p2 as Player).position.y - (p1 as Player).position.y))

	# And carrying rubbish does not break the stack, which is the one thing that
	# has to hold for Summer to be playable the way Spring is.
	await _park()
	await _grab(p1, &"paper")
	_check("P1 is carrying the paper", p1.carried_kind == &"paper")
	_check("and can still stack while carrying it",
		await _stack_at(p1, p2, STACK_X, GROUND_Y))
	_check("still carrying it after stacking", p1.carried_kind == &"paper")
	_emit("")


## Every piece of rubbish has to be gettable at, by jumping for it the way a
## player does: standing on the sand shelf underneath and jumping. Rubbish that
## can only be reached from one lucky pixel of floor, or not at all, leaves a
## level that cannot be finished, so each piece is checked twice - once with one
## dog on its own, and once with the two dogs stacked, which is the other way
## this game is meant to be played.
func _test_every_piece_of_rubbish_can_be_reached() -> void:
	_emit("=== 3. every piece of rubbish can be jumped for, solo and stacked ===")

	for kind in KINDS:
		var spot: Dictionary = REACH_SPOTS[kind]
		var x: float = spot["x"]
		var y: float = spot["y"]
		var dir: int = spot["dir"]
		_check("the %s can be picked up off the shelf above it, on its own" % kind,
			await _can_reach(kind, x, y, dir, false),
			" from x=%.0f y=%.0f dir=%+d" % [x, y, dir])
		_check("and the %s can still be picked up with the two dogs stacked" % kind,
			await _can_reach(kind, x, y, dir, true),
			" from x=%.0f y=%.0f dir=%+d" % [x, y, dir])

	# Reaching a piece of rubbish and letting go of it again has to leave the level
	# exactly as it was, or the rest of the suite would be testing a level that is
	# not the one the game starts with.
	await _park()
	_check("all three pieces are still in the level after all that reaching",
		_items_left() == 3, " left=%d" % _items_left())
	_check("and neither dog is still holding anything",
		p1.carried_kind == &"" and p2.carried_kind == &"")
	_emit("")


## Whether a dog can really pick this piece of rubbish up from one standing spot.
## Both dogs are put back on clear ground first, one of them is stood where a
## player would stand, it jumps, and this only passes if the rubbish genuinely
## changed hands: anything weaker than a real pickup would let a level nobody can
## finish look fine.
func _can_reach(kind: StringName, at_x: float, at_y: float, dir: int,
		stacked: bool) -> bool:
	await _park()
	var stored: Variant = _item(kind)
	if not is_instance_valid(stored):
		return false
	var item := stored as GardenItem
	# A piece that has just been put back cannot be taken again straight away.
	for _i in 60:
		if item._respawn_timer <= 0.0:
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
	# Away from the bins before dropping it, so the drop cannot be mistaken for a
	# delivery and the piece cannot be used up by accident.
	await _park()
	return picked_up


func _test_the_wrong_bins_refuse_everything() -> void:
	_emit("=== 4. all six wrong-bin attempts are refused, with a notice ===")
	# Short notice for the six cases so the run does not sit through six 1.2s
	# pauses; the real 1.2s is checked at the end of this section.
	level.wrong_bin_notice_time = 0.2

	for held in KINDS:
		for target in KINDS:
			if held == target:
				continue
			await _wrong_bin_case(held, target)

	_check("nothing was consumed by any of the six attempts", _items_left() == 3,
		" left=%d" % _items_left())
	_check("no bin was filled by a wrong attempt",
		not (bins[&"paper"] as TrashBin).is_filled
		and not (bins[&"plastic"] as TrashBin).is_filled
		and not (bins[&"glass"] as TrashBin).is_filled)
	_check("and the level is not finished", _sorts_seen == 0
		and not level.level_complete_banner.visible
		and not level.next_level_button.visible)

	# The real notice length, and that it takes itself away again.
	_emit("--- and the notice clears on its own, at the real 1.2s ---")
	level.wrong_bin_notice_time = 1.2
	await _park()
	var held := await _grab(p1, &"glass")
	if held == null:
		_check("the glass was still there for the notice test", false)
	else:
		await _stand_in(p1, &"paper")
		_check("the notice is up", _notice_is_saying("Wrong bin!"))
		await _park()
		_check("and it goes away by itself once the dog has left",
			await _wait_for_notice(false, 3.0))
	_emit("")


## Brings one piece of rubbish to the wrong bin and checks that nothing at all
## happened to it.
func _wrong_bin_case(held: StringName, target: StringName) -> void:
	await _park()
	var item := await _grab(p1, held)
	if item == null or p1.carried_kind != held:
		_check("%s could be picked up at all" % held, false)
		return

	await _stand_in(p1, target)
	var bin := bins[target] as TrashBin

	_check("%s into the %s bin shows the notice" % [held, target],
		_notice_is_saying("Wrong bin!"))
	_check("%s is still in the dog's hands after the %s bin refused it"
		% [held, target], p1.carried_kind == held, " carrying=%s" % p1.carried_kind)
	_check("and the %s piece was not consumed" % held,
		is_instance_valid(item) and not item.is_consumed)
	_check("and the %s bin did not fill" % target, not bin.is_filled)
	await _park()


func _test_the_right_bins_sort_for_good() -> void:
	_emit("=== 5. the matching bin sorts each kind, and it is gone for good ===")

	for kind in KINDS:
		await _park()
		var item := await _grab(p1, kind)
		if item == null:
			_check("the %s was still there to be sorted" % kind, false)
			continue
		_check("P1 picked up the %s" % kind, p1.carried_kind == kind,
			" carrying=%s" % p1.carried_kind)

		await _stand_in(p1, kind)
		var bin := bins[kind] as TrashBin
		_check("the %s bin took the %s" % [kind, kind], bin.is_filled)
		_check("the %s is gone from the level for good" % kind,
			not is_instance_valid(item))
		_check("the dog's hands are empty again", p1.carried_kind == &"")
		_check("and the %s bin is still in the level" % kind,
			is_instance_valid(bin) and bin.get_parent() == level.bins)
		_check("no notice for the right bin", not level.wrong_bin_label.visible)

		# The bug this whole thing exists to prevent: the rubbish coming back to
		# where it was found and being picked up a second time.
		await _park()
		_place(p1, item_spots[kind])
		await _wait(8)
		_check("nothing is left at the %s's old spot" % kind, p1.carried_kind == &"",
			" carrying=%s" % p1.carried_kind)
		_check("and no %s reappeared" % kind, not is_instance_valid(_item(kind)))

	# Only after the third sort may the completion screen be on its way.
	await _park()
	_check("all three were sorted", _sorts_seen == 3, " sorts=%d" % _sorts_seen)
	_check("no rubbish is left in the level", _items_left() == 0,
		" left=%d" % _items_left())
	_emit("")


func _test_the_completion_screen() -> void:
	_emit("=== 6. the completion screen only arrives once all three are sorted ===")

	var since_sort := float(Time.get_ticks_msec() - _sorted_at) / 1000.0
	_check("the banner is not up on the very frame the last sort happened",
		not _banner_on_sort_frame)
	_check("the Next Level button is still out of the way during the pause",
		not level.next_level_button.visible and level.next_level_button.disabled,
		" %.2fs on" % since_sort)

	var delay: float = level.complete_banner_delay
	var left: float = delay + 0.3 - since_sort
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
	# under this test and free it, exactly as in _next_level_test, so where it
	# would go is checked from the level's own declared scene instead. Autumn and
	# Winter are deliberately not built, so a finished Summer returns to Spring.
	var constants: Dictionary = level.get_script().get_script_constant_map()
	_check("and it leads back to Spring, which does exist",
		constants.get("NEXT_SCENE") == SPRING_SCENE and ResourceLoader.exists(SPRING_SCENE),
		" next=%s" % constants.get("NEXT_SCENE"))
	_emit("")


func _finish(ok: bool) -> void:
	_emit("")
	_emit("=".repeat(58))
	if ok:
		_emit("ALL CHECKS PASSED")
	else:
		_emit("FAILURES (%d): %s" % [failures.size(), ", ".join(failures)])
	_emit("=".repeat(58))
	get_tree().quit(0 if ok else 1)
