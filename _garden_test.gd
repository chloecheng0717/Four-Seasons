extends Node2D

## Regression suite for the Spring gardening mechanic: picking up soil, seeds and
## water, the pot taking them in the right order and no other, the plant growing
## into the flower, and none of that disturbing the two-cat stacking.

const PLAYER_H := 52.0
const PLAYER_W := 60.0
const GROUND_Y := 560.0
const ROW4_Y := 4.0 * 56.0
const POT_X := 900.0
const WATER_X := 1024.0
## The screen the level is built to fill, and the middle of it, which is where
## the completion banner is parked.
const SCREEN := Rect2(0.0, 0.0, 1280.0, 720.0)
const SCREEN_CENTRE := Vector2(640.0, 360.0)
## The picture shown when the level is finished.
const COMPLETE_TEXTURE := preload("res://assets/Level Complete.png")
## The picture on the Next Level button that appears on the same screen.
const NEXT_TEXTURE := preload("res://assets/Next_Button.png")
## Flat open ground with no platform overhead, nothing to pick up, well clear of
## the pot and both walls.
const PARK_A := Vector2(150.0, GROUND_Y)
const PARK_B := Vector2(1120.0, GROUND_Y)
const CLEAR_X := 700.0
## A cat's collider is 52 tall, so its feet have to get above this to touch
## anything sitting at the top of the screen. This is the line the solo test
## measures against and the stacked test has to beat.
const REACH_Y := 84.0

var level: Node2D
var pot: PlantPot
var p1: Player
var p2: Player
var items: Dictionary = {}
## Where each item was lying when the level was built. Copied out in _gather()
## because the nodes themselves are gone by the time the last section runs.
var item_spots: Dictionary = {}

var failures: Array[String] = []
var _elapsed := 0.0
var _complete_count := 0
## Wall clock, in ms, for the moment the pot first became a flower. Recorded by a
## watcher rather than by the checks below, so the banner's pause is measured
## from the flower appearing rather than from when the test noticed it.
var _flower_seen_at: int = 0
## Whether the banner was on screen on the very frame the flower appeared. Caught
## by the watcher, because by the time the waits below notice the flower, well
## over a second of the pause has already gone by.
var _banner_on_flower_frame: bool = true
## Where the Next Level button was drawn before the level was finished, kept so
## the reveal can be checked for not nudging it off its authored position.
var _next_button_rect := Rect2()


func _ready() -> void:
	level = (load("res://scenes/Level.tscn") as PackedScene).instantiate()
	add_child(level)
	await get_tree().process_frame
	_gather()
	pot.level_complete.connect(_on_level_complete)
	_run.call_deferred()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > 240.0:
		_emit("WATCHDOG: aborted")
		get_tree().quit(2)


func _on_level_complete() -> void:
	_complete_count += 1


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
	var cats: Array[Player] = []
	for child in level.garden.get_children():
		if child is PlantPot:
			pot = child as PlantPot
		elif child is GardenItem:
			items[(child as GardenItem).item_kind] = child
			item_spots[(child as GardenItem).item_kind] = (child as GardenItem).position
	for child in level.players.get_children():
		if child is Player:
			cats.append(child as Player)
	p1 = cats[0]
	p2 = cats[1]


## How many collectables are still in the level. A used up item has its node
## removed, so this only ever goes down and must end at zero.
func _items_left() -> int:
	var count := 0
	for child in level.garden.get_children():
		if child is GardenItem:
			count += 1
	return count


## Every Label text under a node, so "this thing has no wording on it" can be
## checked properly instead of by eye.
func _labels_under(node: Node) -> Array[String]:
	var found: Array[String] = []
	for child in node.get_children():
		if child is Label:
			found.append((child as Label).text)
		found.append_array(_labels_under(child))
	return found


## Whether anything under a node is still saying "LEVEL COMPLETE", which is the
## text that used to be the completion display.
func _has_level_complete_text(node: Node) -> bool:
	for text in _labels_under(node):
		if text.to_upper().contains("LEVEL COMPLETE"):
			return true
	return false


## Watches for the flower and stamps the wall clock the first time it sees it,
## together with whether the banner was already up on that same frame.
func _watch_for_flower() -> void:
	while pot.stage != PlantPot.Stage.FLOWER:
		await get_tree().process_frame
	_flower_seen_at = Time.get_ticks_msec()
	_banner_on_flower_frame = level.level_complete_banner.visible


## How long it has been since the flower appeared, in seconds.
func _since_flower() -> float:
	return float(Time.get_ticks_msec() - _flower_seen_at) / 1000.0


## Waits until the given number of seconds have passed since the flower appeared.
func _wait_until(seconds: float) -> void:
	var left: float = seconds - _since_flower()
	if left > 0.0:
		await get_tree().create_timer(left).timeout


## Where the flower is actually drawn, worked out from the sprite itself rather
## than hard-coded, so it stays right if the pot artwork or position changes.
func _flower_rect() -> Rect2:
	return Rect2(pot.position + pot.sprite.offset, pot.sprite.region_rect.size)


## Whether the flower is genuinely on show: drawn, using the flower picture, and
## wholly inside the screen. This is what has to be true during the pause before
## the banner arrives.
func _flower_is_showing() -> bool:
	if not pot.sprite.visible:
		return false
	if pot.sprite.texture != PlantPot.STAGE_TEXTURES[PlantPot.Stage.FLOWER]:
		return false
	return SCREEN.encloses(_flower_rect())


## Puts both cats back on flat open ground with empty hands and no stack, and
## lets the physics server catch up. Dropping what they are holding puts the
## item back where it started, unless the pot has already used it up.
func _park() -> void:
	for p: Player in [p1, p2]:
		p.drop_carried()
		p._set_support(null)
		p.velocity = Vector2.ZERO
		p.collision_mask = 3
	_place(p1, PARK_A)
	_place(p2, PARK_B)
	await _wait(6)


## Stands a cat on an item until the pickup happens.
func _grab(p: Player, kind: StringName) -> GardenItem:
	var item: GardenItem = items[kind]
	# An item that has just been put back cannot be taken again straight away, so
	# wait that out rather than guessing at a frame count.
	for _i in 60:
		if item._respawn_timer <= 0.0:
			break
		await get_tree().physics_frame
	_place(p, item.position)
	await _wait(5)
	return item


## Stands a cat in the pot until the pot has had a look at it.
func _deliver(p: Player) -> void:
	_place(p, Vector2(POT_X, GROUND_Y))
	await _wait(6)


## Drops one cat onto the other's head. This has to be done in stages: the
## physics server needs a few frames to catch up with a teleport, and putting a
## cat straight down onto the spot the other one still occupies makes the engine
## shove them apart sideways. Returns whether the ride link actually formed.
func _stack_at(top: Player, bottom: Player, at_x: float, base_y: float) -> bool:
	_place(top, Vector2(at_x - 90.0, base_y))
	_place(bottom, Vector2(at_x + 90.0, base_y))
	await _wait(5)
	_place(bottom, Vector2(at_x, base_y))
	_place(top, Vector2(at_x - 90.0, base_y))
	await _wait(5)
	_place(top, Vector2(at_x, base_y - PLAYER_H - 40.0))
	return await _wait_for_stack(top, bottom)


## Waits for the ride link to actually close, so a test never measures a cat that
## is still falling towards its supporter's head.
func _wait_for_stack(top: Player, bottom: Player, max_frames: int = 90) -> bool:
	for _i in max_frames:
		if top._support == bottom and bottom._riders.has(top) \
				and absf((bottom.position.y - top.position.y) - PLAYER_H) < 2.0:
			return true
		await get_tree().physics_frame
	return false


## Jumps `frames` times and reports the highest its feet got, which is the
## number that says whether it can reach the top of the screen.
func _highest_feet(p: Player, action: StringName, jumps: int) -> float:
	var highest := 9999.0
	for _attempt in jumps:
		await _hold([action], 2)
		for _i in 75:
			await get_tree().physics_frame
			highest = minf(highest, p.position.y)
	return highest


func _run() -> void:
	# The order matters. There is only one lot of each item in the level, and a
	# used up item's node is removed for good, so every section that needs an
	# item to still be lying around has to run before the section that spends it.
	await _test_the_level_has_a_garden()
	await _test_nothing_is_buried_in_the_level()
	await _test_picking_things_up()
	await _test_the_wrong_item_is_refused()
	await _test_the_water_needs_two_cats()
	await _test_carrying_does_not_upset_stacking()
	await _test_the_right_order()
	await _test_growing_into_the_flower()
	await _test_used_up_items_are_gone()

	_emit("")
	_emit("=".repeat(58))
	if failures.is_empty():
		_emit("ALL CHECKS PASSED")
	else:
		_emit("FAILURES (%d): %s" % [failures.size(), ", ".join(failures)])
	_emit("=".repeat(58))
	get_tree().quit(0 if failures.is_empty() else 1)


func _test_the_level_has_a_garden() -> void:
	_emit("=== 1. the level has a garden and no exit door ===")
	_check("there is a pot", pot != null)
	_check("there are three items", items.size() == 3, " found %d" % items.size())
	for kind: StringName in [&"soil", &"seeds", &"water"]:
		_check("the %s is in the level" % kind, items.has(kind))
	_check("the exit door is gone", not ResourceLoader.exists("res://scenes/LevelExit.tscn"))
	_check("nothing is building a Props container any more",
		level.get_node_or_null("Props") == null)
	_check("the pot starts empty and wants soil",
		pot.stage == PlantPot.Stage.EMPTY and pot.required_item() == &"soil",
		" stage=%d" % pot.stage)

	# The item pictures are meant to speak for themselves, so no item may carry
	# any text at all.
	for kind: StringName in [&"soil", &"seeds", &"water"]:
		var labels := _labels_under(items[kind])
		_check("the %s has no wording on it" % kind, labels.is_empty(),
			" labels=%s" % ", ".join(labels))

	await _test_the_completion_banner()


## The banner that says the level is done used to be a LEVEL COMPLETE! label. It
## is now a picture, and it has to be the new one, hidden to begin with, sitting
## in the middle of the screen and big enough to read without falling off it.
func _test_the_completion_banner() -> void:
	_emit("")
	_emit("=== 1b. the completion banner is the picture, not the old text ===")
	var banner: Sprite2D = level.level_complete_banner
	var labels := _labels_under(level)

	var old_text: Array[String] = []
	for text in labels:
		if text.to_upper().contains("LEVEL COMPLETE"):
			old_text.append(text)
	_check("the old LEVEL COMPLETE! text is gone from the level", old_text.is_empty(),
		" still saying=%s" % ", ".join(old_text))
	_check("there is no Label standing in for the banner any more",
		level.get_node_or_null("LevelComplete") is Sprite2D)
	_check("the banner is the new picture", banner.texture == COMPLETE_TEXTURE)
	_check("and it is hidden before the level is finished", not banner.visible)

	# The picture comes with empty padding around it, so it is cropped to the
	# artwork the same way the cats, the items and the pot are.
	_check("the banner is cropped to its artwork",
		banner.region_enabled and banner.region_rect.size.x < COMPLETE_TEXTURE.get_width()
		and banner.region_rect.size.y == float(COMPLETE_TEXTURE.get_height()),
		" region=%s" % banner.region_rect)

	var drawn_size := banner.region_rect.size * banner.scale
	var drawn := Rect2(banner.position - drawn_size * 0.5, drawn_size)
	_check("the banner sits in the middle of the screen",
		banner.position == SCREEN_CENTRE, " at %s" % banner.position)
	_check("and is big enough to read",
		drawn_size.x > 400.0 and drawn_size.y > 200.0,
		" %.0fx%.0f" % [drawn_size.x, drawn_size.y])
	_check("and does not run off the screen", SCREEN.encloses(drawn), " %s" % drawn)
	_check("and is drawn on top of the level", banner.z_index > 0,
		" z_index=%d" % banner.z_index)

	# The Next Level button shares the completion screen, so it is checked here
	# with everything else about the finished-level display: a picture-based,
	# clickable button that exists before the level is done but stays out of the
	# way until the completion screen actually turns up.
	var next: TextureButton = level.next_level_button
	_check("the Next Level button is a real clickable button", next is TextureButton)
	_check("and carries the Next Level picture", next.texture_normal == NEXT_TEXTURE)
	_check("and is hidden before the level is finished", not next.visible)
	_check("and is inert while hidden", next.disabled)
	# A TextureButton draws its picture into its own rect, so a rect that matches
	# the PNG at a uniform scale is what proves the new artwork is shown pixel for
	# pixel - neither shrunk nor stretched, and never squashed sideways.
	var next_tex_size := Vector2(
		float(NEXT_TEXTURE.get_width()), float(NEXT_TEXTURE.get_height()))
	_check("and draws the new picture at its own size, undistorted",
		next.size * next.scale == next_tex_size,
		" drawn=%s texture=%s" % [next.size * next.scale, next_tex_size])
	_check("and is not squashed sideways",
		is_equal_approx(next.scale.x, next.scale.y), " scale=%s" % next.scale)
	var next_rect := next.get_global_rect()
	# The button sits low and to the right, and its middle - where the click
	# actually lands - is what has to be reachable. The new picture's whole rect
	# now fits inside the screen, so both are checked.
	_check("and its middle is on the screen, so it can be clicked",
		SCREEN.has_point(next_rect.get_center()),
		" centre=%s" % next_rect.get_center())
	_check("and the whole button is inside the screen",
		SCREEN.encloses(next_rect), " %s" % next_rect)
	_check("and is drawn above the banner", next.z_index > banner.z_index,
		" z_index=%d" % next.z_index)
	# Remembered so that section 8 can prove the reveal shows the button exactly
	# where it was authored, rather than nudging it.
	_next_button_rect = next_rect


func _test_picking_things_up() -> void:
	_emit("")
	_emit("=== 3. either cat can pick one thing up, and only one ===")
	await _park()

	var soil: GardenItem = await _grab(p1, &"soil")
	_check("P1 picked the soil up", p1.carried_kind == &"soil",
		" carrying=%s" % p1.carried_kind)
	_check("the soil is off the level while carried", not soil.visible)
	_check("P1 is showing what it is carrying", p1.carried_icon.visible
		and p1.carried_icon.texture != null and p1.carried_icon.scale != Vector2.ONE)
	_check("P1's label stays plain while carrying it", p1.name_label.text == "P1",
		" '%s'" % p1.name_label.text)
	_check("and does not name the item in any case",
		not p1.name_label.text.to_upper().contains("SOIL"),
		" '%s'" % p1.name_label.text)
	_check("P1 has empty hands to start with", p2.carried_kind == &"")

	# Walking into a second item while already holding one must change nothing.
	var seeds: GardenItem = await _grab(p1, &"seeds")
	_check("P1 cannot pick up a second item", p1.carried_kind == &"soil"
		and seeds.visible, " carrying=%s" % p1.carried_kind)

	# Step off the seeds first. Empty hands over an item means the item gets
	# picked up again on the very next frame, which is the game working, not a
	# bug, but it would hide what this check is actually about.
	_place(p1, PARK_A)
	await _wait(4)
	p1.drop_carried()
	await _wait(2)
	_check("putting it down empties P1's hands", p1.carried_kind == &"")
	_check("and hides the carried icon", not p1.carried_icon.visible)
	_check("and restores the name label", p1.name_label.text == "P1")
	_check("and the soil is back on the level", soil.visible)
	_check("and the seeds were never taken", seeds.visible)

	await _grab(p2, &"soil")
	_check("P2 can pick the same thing up", p2.carried_kind == &"soil",
		" carrying=%s" % p2.carried_kind)
	_check("P1's hands are still empty", p1.carried_kind == &"")
	p2.drop_carried()
	await _wait(2)


func _test_the_wrong_item_is_refused() -> void:
	_emit("")
	_emit("=== 4. the wrong thing is refused, and can be handed back ===")

	# Water first, on an empty pot.
	await _park()
	await _grab(p1, &"water")
	await _deliver(p1)
	_check("water on an empty pot does nothing", pot.stage == PlantPot.Stage.EMPTY,
		" stage=%d" % pot.stage)
	_check("and P1 is still holding the water", p1.carried_kind == &"water")

	# Jumping at the pot hands it back, so a wrong pick-up cannot dead-end.
	await _hold([&"p1_jump"], 3)
	await _wait(6)
	_check("jumping at the pot puts the water back", p1.carried_kind == &"",
		" carrying=%s" % p1.carried_kind)
	_check("and the water is back on the level", items[&"water"].visible)
	_check("and the pot has not moved on", pot.stage == PlantPot.Stage.EMPTY)

	# Seeds before soil.
	await _park()
	await _grab(p1, &"seeds")
	_check("P1 is holding the seeds to offer the pot", p1.carried_kind == &"seeds",
		" carrying=%s" % p1.carried_kind)
	await _deliver(p1)
	_check("seeds on an empty pot does nothing", pot.stage == PlantPot.Stage.EMPTY,
		" stage=%d" % pot.stage)
	await _hold([&"p1_jump"], 3)
	await _wait(6)
	_check("and the seeds go back too", p1.carried_kind == &"")


func _test_the_right_order() -> void:
	_emit("")
	_emit("=== 7. soil, then seeds, then water ===")

	# Soil first.
	await _park()
	var soil: GardenItem = await _grab(p1, &"soil")
	await _deliver(p1)
	_check("soil fills the pot", pot.stage == PlantPot.Stage.SOIL,
		" stage=%d" % pot.stage)
	_check("P1's hands are empty again", p1.carried_kind == &"")
	# This is the bug that was fixed: the soil used to be put back where it was
	# found, so it turned up again and could be picked up a second time.
	_check("the soil is gone from the level for good",
		not is_instance_valid(soil))
	_check("and the garden has one item fewer", _items_left() == 2,
		" left=%d" % _items_left())
	_check("the pot now wants seeds", pot.required_item() == &"seeds")
	_check("the pot is drawn differently now",
		pot.sprite.texture == PlantPot.STAGE_TEXTURES[PlantPot.Stage.SOIL])
	_check("and the banner is still hidden this early",
		not level.level_complete_banner.visible)

	# Water before seeds must still be refused at this stage.
	await _park()
	await _grab(p2, &"water")
	await _deliver(p2)
	_check("water before seeds is refused", pot.stage == PlantPot.Stage.SOIL,
		" stage=%d" % pot.stage)
	_check("and P2 keeps hold of it", p2.carried_kind == &"water")
	await _hold([&"p2_jump"], 3)
	await _wait(6)
	_check("a refused item is not used up, only put back",
		is_instance_valid(items[&"water"]) and _items_left() == 2,
		" left=%d" % _items_left())

	# Then seeds.
	await _park()
	var seeds: GardenItem = await _grab(p1, &"seeds")
	await _deliver(p1)
	_check("seeds go in next", pot.stage == PlantPot.Stage.SEEDED,
		" stage=%d" % pot.stage)
	_check("P1's hands are empty again", p1.carried_kind == &"")
	_check("the seeds are gone from the level for good",
		not is_instance_valid(seeds))
	_check("and the garden has one item fewer again", _items_left() == 1,
		" left=%d" % _items_left())
	_check("the pot now wants water", pot.required_item() == &"water")
	_check("the seeded pot reuses the soil picture on purpose",
		pot.sprite.texture == PlantPot.STAGE_TEXTURES[PlantPot.Stage.SEEDED])
	_check("and the banner is still hidden with only the seeds in",
		not level.level_complete_banner.visible)

	# There is only one lot of each item in the level, so "a second lot of soil
	# is refused" is not a thing that can be tested any more. The same guard can
	# still be checked with a cat that turns up with empty hands.
	await _park()
	await _deliver(p1)
	_check("an empty-handed cat leaves the pot where it is",
		pot.stage == PlantPot.Stage.SEEDED, " stage=%d" % pot.stage)
	_check("and does not take the water's place", _items_left() == 1,
		" left=%d" % _items_left())


func _test_growing_into_the_flower() -> void:
	_emit("")
	_emit("=== 8. water makes the flower, and the flower ends the level ===")
	await _park()
	var water: GardenItem = await _grab(p1, &"water")
	await _deliver(p1)
	_check("water makes a sprout", pot.stage == PlantPot.Stage.SPROUT,
		" stage=%d" % pot.stage)
	_check("the water was used up", not is_instance_valid(water))
	_check("nothing is left lying in the garden", _items_left() == 0,
		" left=%d" % _items_left())
	_check("P1's hands are empty again", p1.carried_kind == &"")
	_check("the pot is not waiting for anything now", pot.required_item() == &"")
	_check("the level is not complete yet", _complete_count == 0)
	# Watering is not finishing. The banner must not jump out before the flower.
	_check("and the banner is still hidden at the sprout",
		not level.level_complete_banner.visible)

	# The sprout grows on its own, so nothing has to be carried any more. A
	# watcher stamps the clock the moment the flower actually appears, because
	# these waits overshoot that moment by a frame or several.
	_watch_for_flower.call_deferred()
	await _wait(60)
	_check("it is not done after a second", pot.stage == PlantPot.Stage.SPROUT,
		" stage=%d" % pot.stage)
	_check("and the banner is still hidden while it grows",
		not level.level_complete_banner.visible)

	await _wait(180)
	_check("it grows into the flower", pot.stage == PlantPot.Stage.FLOWER,
		" stage=%d" % pot.stage)
	_check("the pot is drawn as a flower",
		pot.sprite.texture == PlantPot.STAGE_TEXTURES[PlantPot.Stage.FLOWER])
	_check("the level completed exactly once", _complete_count == 1,
		" count=%d" % _complete_count)

	# The whole point of the delay: the signboard must NOT turn up on the same
	# frame as the flower. The flower is the reward, so it gets a moment alone.
	var delay: float = level.complete_banner_delay
	_check("and the pause before the banner is a real one, in the 1-2s asked for",
		delay >= 1.0 and delay <= 2.0, " delay=%.2fs" % delay)
	_check("the banner was not on screen on the very frame the flower appeared",
		not _banner_on_flower_frame)
	_check("the banner did not arrive just because the flower did",
		not level.level_complete_banner.visible,
		" %.2fs on, banner off" % _since_flower())
	_check("the flower is on show by itself during the pause", _flower_is_showing())

	# Two boundaries inside the pause. These are anchored to the moment the flower
	# appeared, and timed in real seconds, because the countdown is driven by
	# delta and wall clock is the only clock that lines up with it.
	await _wait_until(delay * 0.5)
	_check("the banner is still away halfway through the pause",
		not level.level_complete_banner.visible, " %.2fs on" % _since_flower())
	_check("and the flower is still the thing being looked at",
		_flower_is_showing())

	await _wait_until(delay * 0.9)
	_check("and still away with the pause nearly over",
		not level.level_complete_banner.visible, " %.2fs on" % _since_flower())
	_check("with the flower still on show", _flower_is_showing())

	# Then it turns up, and it took about as long as it was asked to.
	var guard: int = 0
	while not level.level_complete_banner.visible and guard < 600:
		guard += 1
		await get_tree().process_frame
	_check("the Level Complete picture appears once the pause is up",
		level.level_complete_banner.visible
		and level.level_complete_banner.texture == COMPLETE_TEXTURE)
	_check("and the Next Level button turns up on the same screen",
		level.next_level_button.visible and not level.next_level_button.disabled)
	_check("without being moved from where it was authored",
		level.next_level_button.get_global_rect() == _next_button_rect,
		" was %s now %s" % [_next_button_rect,
			level.next_level_button.get_global_rect()])
	var took: float = _since_flower()
	_check("and it really did wait about as long as the pause asked for",
		absf(took - delay) < 0.3, " took=%.2fs, asked for %.2fs" % [took, delay])
	_check("and it is the only completion display there is",
		level.get_node_or_null("LevelComplete") is Sprite2D
		and not _has_level_complete_text(level))
	_check("with no exit door needed",
		not ResourceLoader.exists("res://scenes/LevelExit.tscn"))



func _test_the_water_needs_two_cats() -> void:
	_emit("")
	_emit("=== 5. the water in the top corner needs both cats ===")
	var water: GardenItem = items[&"water"]

	# One cat on its own on the highest platform in the level.
	await _park()
	_place(p1, Vector2(WATER_X, ROW4_Y))
	await _wait(8)
	_check("P1 is standing on the highest platform",
		p1.is_on_floor() and absf(p1.position.y - ROW4_Y) < 1.5, " y=%.1f" % p1.position.y)

	var solo_highest := await _highest_feet(p1, &"p1_jump", 3)
	_check("jumping on its own it never got its feet above y=84",
		solo_highest > REACH_Y, " highest=%.1f" % solo_highest)
	_check("so it never got the water", not water.is_collected)
	_check("and it came back down to the platform",
		p1.is_on_floor() and absf(p1.position.y - ROW4_Y) < 1.5, " y=%.1f" % p1.position.y)

	# The same spot with one cat standing on the other's head.
	await _park()
	var stacked := await _stack_at(p1, p2, WATER_X, ROW4_Y)
	_check("P1 settled onto P2's head on the high platform", stacked
		and p1._support == p2 and p2._riders.has(p1)
		and absf((p2.position.y - p1.position.y) - PLAYER_H) < 2.0,
		" p1.y=%.1f p2.y=%.1f" % [p1.position.y, p2.position.y])

	var stacked_highest := 9999.0
	for _attempt in 3:
		stacked_highest = minf(stacked_highest,
			await _highest_feet(p1, &"p1_jump", 1))
		if water.is_collected:
			break

	_check("stacked, the top cat got its feet above y=84",
		stacked_highest < REACH_Y, " highest=%.1f" % stacked_highest)
	_check("and picked the water up on the way past it", water.is_collected)
	_check("and is carrying it", p1.carried_kind == &"water",
		" carrying=%s" % p1.carried_kind)
	_check("while P2 stayed put underneath", p2._riders.has(p1)
		and absf(p2.position.y - ROW4_Y) < 1.5, " p2.y=%.1f" % p2.position.y)
	_check("and neither cat fell off the level",
		p1.position.y > -100.0 and p2.position.y > -100.0)


func _test_carrying_does_not_upset_stacking() -> void:
	_emit("")
	_emit("=== 6. carrying an item does not upset stacking ===")
	await _park()
	var soil: GardenItem = await _grab(p1, &"soil")
	_place(p1, Vector2(CLEAR_X, GROUND_Y))
	await _wait(8)
	_check("P1 carried the soil across the level", p1.carried_kind == &"soil"
		and p1.is_on_floor(), " carrying=%s y=%.1f" % [p1.carried_kind, p1.position.y])

	var stacked := await _stack_at(p2, p1, CLEAR_X, GROUND_Y)
	_check("P2 settled onto P1's head", stacked
		and p2._support == p1 and p1._riders.has(p2),
		" p1.y=%.1f p2.y=%.1f" % [p1.position.y, p2.position.y])

	var from_x := p1.position.x
	await _hold([&"p1_right"], 20)
	_check("P1 walked right with P2 on its head", p1.position.x - from_x > 40.0,
		" dx=%.1f" % (p1.position.x - from_x))
	_check("P2 rode along, still on top", p2._support == p1
		and absf((p1.position.y - p2.position.y) - PLAYER_H) < 2.0,
		" p1.y=%.1f p2.y=%.1f" % [p1.position.y, p2.position.y])
	_check("P1 is still carrying the soil", p1.carried_kind == &"soil",
		" carrying=%s" % p1.carried_kind)
	_check("and the soil is still off the level", not soil.visible)
	_check("P2 picked nothing up on the way past", p2.carried_kind == &"",
		" carrying=%s" % p2.carried_kind)

	# And the jump still works with a rider and a carried item on the same cat.
	var bottom_highest := await _highest_feet(p1, &"p1_jump", 1)
	_check("P1 still jumps with a rider on its head", bottom_highest < GROUND_Y - 80.0,
		" highest=%.1f" % bottom_highest)
	_check("and took P2 up with it", p2._support == p1)
	_check("and still has the soil", p1.carried_kind == &"soil")


## The pot is drawn upwards out of its own spot and the items are just left
## lying around, so both have to be checked against the terrain. Anything sitting
## inside a tile is either hidden or impossible to walk into. This runs early,
## while all three items are still in the level to be measured.
func _test_nothing_is_buried_in_the_level() -> void:
	_emit("")
	_emit("=== 2. nothing is buried in the level ===")
	var blockers: Array[Rect2] = []
	for child in level.terrain.get_children():
		if child is GroundTile:
			var shape := (child as GroundTile).get_node("CollisionShape2D") as CollisionShape2D
			var rect := shape.shape as RectangleShape2D
			blockers.append(Rect2((child as GroundTile).position + shape.position - rect.size / 2.0,
				rect.size))

	for kind: StringName in [&"soil", &"seeds", &"water"]:
		var item: GardenItem = items[kind]
		var box := Rect2(item.position - Vector2.ONE * item.pickup_size * 0.5,
			Vector2.ONE * item.pickup_size)
		var clashes: Array[String] = []
		for block in blockers:
			if box.intersects(block):
				clashes.append(str(block.position))
		_check("the %s is not inside a platform" % kind, clashes.is_empty(),
			" clashes=%s" % ", ".join(clashes))

	# The pot has to be clear at its tallest, and its status label sits above it,
	# so check the whole drawn height plus room for that label.
	for stage in PlantPot.Stage.values():
		var region: Rect2 = PlantPot.STAGE_REGIONS[stage]
		var drawn := Rect2(
			Vector2(pot.position.x - region.size.x * 0.5,
				pot.position.y - region.size.y - 34.0 - 24.0),
			Vector2(region.size.x, region.size.y + 34.0 + 24.0))
		var clashes: Array[String] = []
		for block in blockers:
			if drawn.intersects(block):
				clashes.append(str(block.position))
		_check("the pot is clear of the platforms at stage %d" % stage,
			clashes.is_empty(), " clashes=%s" % ", ".join(clashes))


## The bug this section exists for: a used up item used to be put back where it
## was found, so it turned up again in the level and could be picked up all over
## again. Each item now leaves for good the moment the pot takes it.
func _test_used_up_items_are_gone() -> void:
	_emit("")
	_emit("=== 9. a used up item is gone for good ===")

	_check("nothing is left lying in the garden", _items_left() == 0,
		" left=%d" % _items_left())
	for kind: StringName in [&"soil", &"seeds", &"water"]:
		_check("the %s node was removed from the level" % kind,
			not is_instance_valid(items[kind]))

	# Now walk a cat over the three spots the items used to be lying on. None of
	# them is anywhere near the pot, so nothing else could pick anything up and
	# a clean sweep really does mean the spots are empty.
	await _park()
	for kind: StringName in [&"soil", &"seeds", &"water"]:
		_place(p1, item_spots[kind])
		await _wait(12)
		_check("nothing can be picked up where the %s used to be" % kind,
			p1.carried_kind == &"" and _items_left() == 0,
			" carrying=%s left=%d" % [p1.carried_kind, _items_left()])
		await _park()

	# And a second cat coming back to the same spots changes nothing either.
	await _park()
	for kind: StringName in [&"soil", &"seeds", &"water"]:
		_place(p2, item_spots[kind])
		await _wait(12)
		_check("the other cat cannot pick up the %s either" % kind,
			p2.carried_kind == &"" and _items_left() == 0,
			" carrying=%s left=%d" % [p2.carried_kind, _items_left()])
		await _park()

	# A cat wandering back to the pot with empty hands also changes nothing.
	await _park()
	await _deliver(p1)
	_check("the finished pot is still finished",
		pot.stage == PlantPot.Stage.FLOWER, " stage=%d" % pot.stage)
	_check("and the level did not complete a second time", _complete_count == 1,
		" count=%d" % _complete_count)
