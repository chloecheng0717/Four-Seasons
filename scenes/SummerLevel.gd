extends Node2D

## Summer: two dogs sort rubbish into the right bin.
##
## A dog picks rubbish up by standing in it, carries one piece at a time, and
## takes it to the bin that wants it. The bin that matches keeps it and the
## rubbish is used up for good; every other bin refuses it and the dog keeps
## carrying it, with a short "Wrong bin!" notice so the mistake is obvious.
## Once all three kinds have been sorted the Level Complete picture and the Next
## Level button turn up together, exactly as they do at the end of Spring.
##
## Everything here is Spring's, reused rather than rebuilt: the same tiles
## (GroundTile), the same two-player scene (Player.tscn, so the dogs move, jump,
## stack, carry and collide in precisely the way the cats do and only the
## artwork changes), the same collectable (GardenItem, which is already generic)
## and the same completion screen. The one genuinely new thing is TrashBin, which
## is PlantPot's role in the level with three instances instead of one, and the
## matching rule is the only rule it has.
##
## A note on names: Player's artwork fields are still called `cat_texture` and
## `cat_region` because they were named for the cats. Renaming them would mean
## editing Player.gd, Player.tscn and Level.gd, which is not worth it for a
## cosmetic rename, so the dogs are simply assigned to the cat fields.

const TILE_WIDTH := 64
const TILE_HEIGHT := 56
const LEVEL_WIDTH := 1280
const LEVEL_HEIGHT := 720

const GROUND_ROW := 10
const GROUND_ROW_COUNT := 3
const COLUMN_COUNT := 20

const WALL_WIDTH := 16
const WALL_COLOR := Color(0.87, 0.79, 0.55)

# [row, first column, how many columns]
# Layout approximating the PNG - platforms forming steps
const PLATFORM_ROWS := [
	[8, 5, 3],    # left platform area
	[6, 9, 3],    # middle-upper
	[4, 13, 3],   # right upper platform
]

const SAND_TEXTURE := preload("res://assets/Summer/Sand.png")
const SAND_REGION := Rect2(15, 13, 64, 56)
const WATER_TEXTURE := preload("res://assets/Summer/Water.png")
const WATER_REGION := Rect2(13, 13, 64, 56)

const DOG1_TEXTURE := preload("res://assets/Summer/Dog1.png")
const DOG2_TEXTURE := preload("res://assets/Summer/Dog2.png")

## Both dogs are 256x256 pictures with their artwork in the same place, and both
## are drawn facing LEFT exactly like the cats - so `flip_h` still means "turn
## right" and Player.gd needs no change at all for facing.
const DOG_REGION := Rect2(8, 24, 240, 208)

const PLAYER_SPAWNS := [
	{
		"label_text": "P1",
		"position": Vector2(120, 559),
		"dog_texture": DOG1_TEXTURE,
		"dog_region": DOG_REGION,
		"left_action": &"p1_left",
		"right_action": &"p1_right",
		"jump_action": &"p1_jump",
	},
	{
		"label_text": "P2",
		"position": Vector2(232, 559),
		"dog_texture": DOG2_TEXTURE,
		"dog_region": DOG_REGION,
		"left_action": &"p2_left",
		"right_action": &"p2_right",
		"jump_action": &"p2_jump",
	},
]

# The sea behind the beach. Drawn as plain sprites with no collider at all, so it
# is scenery and can never affect where a dog can stand or jump.
const WATER_ROWS := [3, 4, 5, 6]
const WATER_Z := -10

# Positions based on Summer layout.png, then measured in the built level: every
# piece of rubbish is where the picture puts it on the sand shelves, and every one
# of them was checked by actually jumping for it from the shelf below (see
# _summer_test's reachability checks).
const TRASH_ITEMS := [
	{
		"kind": &"paper",
		"texture": preload("res://assets/Summer/Paper.png"),
		"region": Rect2(24, 48, 224, 176),
		"display_height": 56.0,
		"pickup_size": 48.0,
		"position": Vector2(434, 322),
	},
	{
		"kind": &"plastic",
		"texture": preload("res://assets/Summer/Plastic bag.png"),
		"region": Rect2(24, 16, 184, 232),
		"display_height": 56.0,
		"pickup_size": 48.0,
		"position": Vector2(752, 200),
	},
	{
		"kind": &"glass",
		"texture": preload("res://assets/Summer/Glass bottle.png"),
		"region": Rect2(88, 32, 88, 184),
		"display_height": 64.0,
		"pickup_size": 44.0,
		"position": Vector2(1136, 230),
	},
]

# The three bins, all standing on the flat ground at its surface, y=560.
#
# They cannot be spread anywhere across the beach, because the ground is already
# taken: the two dogs start at x=120 and x=232 and their pictures reach to x=264,
# and the lowest sand shelf sits over x=320..512, which is exactly the band a bin
# standing on the ground would be drawn into. That leaves the beach from x=560
# rightwards, so the bins are spaced along it, each with its rubbish above and
# slightly to the left of it, and each nearest to its own rubbish by a clear
# margin. The glass bin's file on disk is "Glass bin.png", with a lower case b.
const BINS := [
	{
		"kind": &"paper",
		"texture": preload("res://assets/Summer/Paper Bin.png"),
		"region": Rect2(40, 40, 160, 192),
		"position": Vector2(560, 560),
	},
	{
		"kind": &"plastic",
		"texture": preload("res://assets/Summer/Plastic Bin.png"),
		"region": Rect2(48, 32, 160, 192),
		"position": Vector2(860, 560),
	},
	{
		"kind": &"glass",
		"texture": preload("res://assets/Summer/Glass bin.png"),
		"region": Rect2(48, 32, 160, 192),
		"position": Vector2(1120, 560),
	},
]

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const TILE_SCENE := preload("res://scenes/GroundTile.tscn")
const ITEM_SCENE := preload("res://scenes/GardenItem.tscn")
const BIN_SCENE := preload("res://scenes/TrashBin.tscn")

## Where the Next Level button goes once Summer is finished. Autumn exists, so
## the chain now runs Spring -> Summer -> Autumn. Winter still does not, so a
## finished Autumn goes back to Spring rather than becoming a dead end.
const NEXT_SCENE := "res://scenes/AutumnLevel.tscn"

## --- Summer 2 -----------------------------------------------------------------
## Summer has two levels, and both use this script. Level 1 is SummerLevel.tscn,
## the one-screen beach above. Level 2 is SummerLevel2.tscn, which sets
## `stage = 2` and gets the tables below instead: a long beach, three screens
## wide, that scrolls, with six pieces of rubbish and the three bins in the middle.
## Level 1's tables above are left exactly as they were.
##
## The Next Level button of level 1 goes to level 2, and level 2's goes to Autumn
## (NEXT_SCENE, which still means "the next season").
const STAGE_2_SCENE := "res://scenes/SummerLevel2.tscn"

## 3840 x 720 is 60 columns of 64px: three screens wide, one screen tall.
const STAGE_2_WIDTH := 3840
const STAGE_2_COLUMN_COUNT := 60

## [row, first column, how many columns], read left to right. Rows 8, 6 and 4
## have their tops at y = 448, 336 and 224, and no step is more than 112px. The
## middle of the beach (x 1408..2368) is left open, because the bins stand there.
const STAGE_2_PLATFORM_ROWS := [
	[8, 4, 4],     # left: low shelf, paper above it      x  256.. 512
	[8, 10, 3],    # left: step                           x  640.. 832
	[6, 13, 4],    # left: high shelf, glass above it     x  832..1088
	[8, 18, 4],    # left: low shelf, plastic on it       x 1152..1408
	[8, 37, 4],    # right: low shelf, plastic above it   x 2368..2624
	[8, 42, 3],    # right: step                          x 2688..2880
	[6, 45, 4],    # right: middle step                   x 2880..3136
	[4, 49, 3],    # right: top step, paper above it      x 3136..3328
	[6, 54, 4],    # right: last shelf, glass high above  x 3456..3712
]

## Six pieces of rubbish, two of each kind, three on each side of the bins, so
## the dogs have to decide which bin each one belongs in. A dog sweeps its body
## from S-52 up to about S-186 when it jumps from a surface at y = S, and a dog on
## its friend's head reaches about S-238.
## - The first paper and the second plastic (boxes 306..354) need a jump from
##   their low shelf (448); from the floor a jump only reaches 374.
## - The first glass (box 198..242) needs the high shelf (336); the low step next
##   to it only reaches 262.
## - The first plastic sits on its low shelf and can be had from the floor.
## - The second paper (box 86..134) needs the top step (224); the middle step
##   only reaches 150.
## - The second glass (box 108..140) is above the last shelf (336), where one
##   jump only reaches 150. It takes two: one dog on the other's head. Its box is
##   32px, like Spring's water, which leaves a clear margin either way.
const STAGE_2_TRASH_ITEMS := [
	{
		"kind": &"paper",
		"texture": preload("res://assets/Summer/Paper.png"),
		"region": Rect2(24, 48, 224, 176),
		"display_height": 56.0,
		"pickup_size": 48.0,
		"position": Vector2(384, 330),
	},
	{
		"kind": &"glass",
		"texture": preload("res://assets/Summer/Glass bottle.png"),
		"region": Rect2(88, 32, 88, 184),
		"display_height": 64.0,
		"pickup_size": 44.0,
		"position": Vector2(960, 220),
	},
	{
		"kind": &"plastic",
		"texture": preload("res://assets/Summer/Plastic bag.png"),
		"region": Rect2(24, 16, 184, 232),
		"display_height": 56.0,
		"pickup_size": 48.0,
		"position": Vector2(1280, 420),
	},
	{
		"kind": &"plastic",
		"texture": preload("res://assets/Summer/Plastic bag.png"),
		"region": Rect2(24, 16, 184, 232),
		"display_height": 56.0,
		"pickup_size": 48.0,
		"position": Vector2(2496, 330),
	},
	{
		"kind": &"paper",
		"texture": preload("res://assets/Summer/Paper.png"),
		"region": Rect2(24, 48, 224, 176),
		"display_height": 56.0,
		"pickup_size": 48.0,
		"position": Vector2(3232, 110),
	},
	{
		"kind": &"glass",
		"texture": preload("res://assets/Summer/Glass bottle.png"),
		"region": Rect2(88, 32, 88, 184),
		"display_height": 64.0,
		"pickup_size": 32.0,
		"position": Vector2(3584, 124),
	},
]

## The same three bins as level 1, standing on the open floor in the middle of the
## beach. Each one takes two pieces.
const STAGE_2_BINS := [
	{
		"kind": &"paper",
		"texture": preload("res://assets/Summer/Paper Bin.png"),
		"region": Rect2(40, 40, 160, 192),
		"position": Vector2(1680, 560),
	},
	{
		"kind": &"plastic",
		"texture": preload("res://assets/Summer/Plastic Bin.png"),
		"region": Rect2(48, 32, 160, 192),
		"position": Vector2(1920, 560),
	},
	{
		"kind": &"glass",
		"texture": preload("res://assets/Summer/Glass bin.png"),
		"region": Rect2(48, 32, 160, 192),
		"position": Vector2(2160, 560),
	},
]
const STAGE_2_BIN_CAPACITY := 2

## The camera follows the dogs only in a level wider than one screen. It never
## moves vertically, because every level is exactly one screen tall.
const CAMERA_Y := 360.0
## The same easing Autumn and Winter use. See _follow_players.
const CAMERA_SMOOTHING := 8.0

## Which of Summer's two levels this is. SummerLevel.tscn leaves it at 1;
## SummerLevel2.tscn sets it to 2.
@export_range(1, 2) var stage: int = 1

## How long the Level Complete banner waits after the last piece of rubbish is
## sorted, so the sorted beach is visible on its own first. Same as Spring.
@export_range(0.0, 5.0, 0.1) var complete_banner_delay: float = 1.5
## How long the "Wrong bin!" notice stays up. It has to be long enough to be read
## and short enough to be out of the way.
@export_range(0.2, 5.0, 0.1) var wrong_bin_notice_time: float = 1.2

@onready var terrain: Node2D = $Terrain
@onready var walls: Node2D = $Walls
@onready var water: Node2D = $Water
@onready var trash: Node2D = $Trash
@onready var bins: Node2D = $Bins
@onready var players: Node2D = $Players
@onready var camera: Camera2D = $Camera2D
# Found by unique name (%), not by path: level 1 keeps these straight under the
# root, but level 2 scrolls, so it keeps them in a UI layer that stays on screen.
@onready var level_complete_banner: Sprite2D = %LevelComplete
@onready var next_level_button: TextureButton = %NextLevel
@onready var wrong_bin_label: Label = %WrongBin

## Counts down to the banner appearing. Negative means nothing is pending.
var _banner_timer: float = -1.0
var _banner_shown: bool = false
## Counts down to the "Wrong bin!" notice going away. Negative means it is not up.
var _wrong_bin_timer: float = -1.0
## How many pieces of rubbish have been sorted so far. A full bin takes nothing
## more and a sorted piece is used up for good, so nothing is counted twice.
var _sorted_count: int = 0

## The layout actually built. They start as level 1's tables, and _ready swaps
## in level 2's when `stage` is 2.
var level_width: int = LEVEL_WIDTH
var world_columns: int = COLUMN_COUNT
var platform_rows: Array = PLATFORM_ROWS
var trash_items: Array = TRASH_ITEMS
var bin_table: Array = BINS
var bin_capacity: int = 1
## The camera's smoothed position, kept unrounded. See _follow_players.
var _camera_x: float = 0.0


func _ready() -> void:
	# The automated Spring transition test drives a real scene change and then
	# needs to prove it arrived. When run with this user argument, say so and quit
	# instead of building the level - exactly what the old placeholder did, so the
	# Spring suite still works.
	# --summer-check is the same thing under the name the season chain test uses.
	var args := OS.get_cmdline_user_args()
	if stage == 1 and (args.has("--next-level-check") or args.has("--summer-check")):
		print("NEXT LEVEL REACHED SUMMER")
		get_tree().quit(0)
		return
	# And the same again for arriving in Summer 2 from Summer 1.
	if stage == 2 and args.has("--summer2-check"):
		print("NEXT LEVEL REACHED SUMMER 2")
		get_tree().quit(0)
		return

	if stage == 2:
		level_width = STAGE_2_WIDTH
		world_columns = STAGE_2_COLUMN_COUNT
		platform_rows = STAGE_2_PLATFORM_ROWS
		trash_items = STAGE_2_TRASH_ITEMS
		bin_table = STAGE_2_BINS
		bin_capacity = STAGE_2_BIN_CAPACITY
	camera.limit_right = level_width

	# The Next Level button belongs to the completion screen and nowhere else. The
	# scene hides it and this hides it again, for the same reason as in Spring: a
	# disabled button still draws, so `visible` is what keeps it off the screen,
	# and an editor save that loses the scene's `visible = false` cannot leave it
	# sitting in the level while the dogs are still sorting.
	next_level_button.visible = false
	next_level_button.disabled = true
	next_level_button.pressed.connect(_on_next_level_pressed)

	_build_ground()
	_build_platforms()
	_build_water()
	_build_walls()
	_build_players()
	_build_trash()
	_build_bins()

	# Put the camera on the dogs straight away, so a long level does not open with
	# the view sweeping in from somewhere else.
	if level_width > LEVEL_WIDTH:
		_camera_x = _players_centre().x
		camera.global_position = Vector2(roundf(_camera_x), CAMERA_Y)


func _build_ground() -> void:
	for row_offset in GROUND_ROW_COUNT:
		for column in world_columns:
			_add_tile(column, GROUND_ROW + row_offset, row_offset > 0)


func _build_platforms() -> void:
	for platform in platform_rows:
		var row: int = platform[0]
		var first_column: int = platform[1]
		var column_count: int = platform[2]
		for index in column_count:
			_add_tile(first_column + index, row, false)


## Every ground and platform tile is the same 64x56 sand picture, cropped to its
## opaque part and drawn from the tile's own top left corner, exactly like Spring's
## ground tile is drawn.
func _add_tile(column: int, row: int, buried: bool) -> void:
	var tile := TILE_SCENE.instantiate() as GroundTile
	tile.buried = buried
	tile.surface_texture = SAND_TEXTURE
	tile.surface_region = SAND_REGION
	tile.position = Vector2(column * TILE_WIDTH, row * TILE_HEIGHT)
	terrain.add_child(tile)


## The sea behind the beach. Plain sprites, no collider and no area, so it is
## purely scenery: it cannot catch a dog, hold one up or be picked up.
func _build_water() -> void:
	for row in WATER_ROWS:
		for column in world_columns:
			var sprite := Sprite2D.new()
			sprite.texture = WATER_TEXTURE
			sprite.texture_filter = 1
			sprite.region_enabled = true
			sprite.region_rect = WATER_REGION
			sprite.centered = false
			sprite.position = Vector2(column * TILE_WIDTH, int(row) * TILE_HEIGHT)
			sprite.z_index = WATER_Z
			water.add_child(sprite)


func _build_walls() -> void:
	_add_wall(Rect2(0, 0, WALL_WIDTH, LEVEL_HEIGHT))
	_add_wall(Rect2(level_width - WALL_WIDTH, 0, WALL_WIDTH, LEVEL_HEIGHT))


func _add_wall(rect: Rect2) -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = rect.position

	var wall_shape := RectangleShape2D.new()
	wall_shape.size = rect.size

	var wall_collision := CollisionShape2D.new()
	wall_collision.shape = wall_shape
	wall_collision.position = rect.size / 2.0
	wall.add_child(wall_collision)

	var wall_polygon := Polygon2D.new()
	wall_polygon.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(rect.size.x, 0),
		rect.size,
		Vector2(0, rect.size.y),
	])
	wall_polygon.color = WALL_COLOR
	wall.add_child(wall_polygon)

	walls.add_child(wall)


## The dogs are the same Player scene as the cats, with their own artwork, their
## own controls and their own spawn. Nothing else about them differs, so they
## move, jump, stack, carry and collide in exactly the way the cats do.
func _build_players() -> void:
	for spawn in PLAYER_SPAWNS:
		var player := PLAYER_SCENE.instantiate() as Player
		player.label_text = spawn["label_text"]
		player.left_action = spawn["left_action"]
		player.right_action = spawn["right_action"]
		player.jump_action = spawn["jump_action"]
		player.cat_texture = spawn["dog_texture"]
		player.cat_region = spawn["dog_region"]
		player.position = spawn["position"]
		players.add_child(player)


## The rubbish is the same GardenItem scene Spring uses. It is already generic -
## a picture, a kind and a pickup box - so a piece of rubbish needs nothing new
## from it, and it keeps Spring's guarantee that a used-up item leaves the level
## for good rather than going back where it was found.
func _build_trash() -> void:
	for item in trash_items:
		var rubbish := ITEM_SCENE.instantiate() as GardenItem
		rubbish.item_kind = item["kind"]
		rubbish.item_texture = item["texture"]
		rubbish.art_region = item["region"]
		rubbish.display_height = item["display_height"]
		rubbish.pickup_size = item["pickup_size"]
		rubbish.position = item["position"]
		trash.add_child(rubbish)


func _build_bins() -> void:
	for entry in bin_table:
		var bin := BIN_SCENE.instantiate() as TrashBin
		bin.accepts_kind = entry["kind"]
		bin.capacity = bin_capacity
		bin.bin_texture = entry["texture"]
		bin.art_region = entry["region"]
		bin.position = entry["position"]
		bin.rubbish_sorted.connect(_on_rubbish_sorted)
		bin.wrong_bin.connect(_on_wrong_bin)
		bins.add_child(bin)


## Keeps the lower dog drawn behind the upper one, runs the countdown that holds
## the Level Complete banner back, and takes the "Wrong bin!" notice down again.
func _process(delta: float) -> void:
	if _banner_timer >= 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0:
			_banner_timer = -1.0
			_reveal_banner()

	if _wrong_bin_timer >= 0.0:
		_wrong_bin_timer -= delta
		if _wrong_bin_timer <= 0.0:
			_wrong_bin_timer = -1.0
			wrong_bin_label.visible = false

	var ordered: Array[Node2D] = []
	for child in players.get_children():
		if child is Player:
			ordered.append(child)

	ordered.sort_custom(
		func(a: Node2D, b: Node2D) -> bool: return a.position.y > b.position.y
	)

	for index in ordered.size():
		ordered[index].z_index = index

	# Only a level wider than one screen scrolls. Level 1 is exactly one screen,
	# so its camera never moves at all.
	if level_width > LEVEL_WIDTH:
		_follow_players(delta)


## The middle of the two dogs, which the one shared camera follows.
func _players_centre() -> Vector2:
	var sum := Vector2.ZERO
	var count := 0
	for child in players.get_children():
		if child is Player:
			sum += (child as Player).global_position
			count += 1
	if count == 0:
		return Vector2(level_width * 0.5, CAMERA_Y)
	return sum / float(count)


## Moves the camera towards the middle of the two dogs and keeps it on whole
## pixels. This is Autumn's camera (see AutumnLevel._follow_foxes for the full
## story): the tiles are pixel art drawn 1:1, and a camera sitting on a fraction
## of a pixel opens thin white lines between them as it pans. The easing is the
## same as the engine's own smoothing; only the rounding is added.
func _follow_players(delta: float) -> void:
	var target_x: float = _players_centre().x
	var weight: float = 1.0 - exp(-CAMERA_SMOOTHING * delta)
	_camera_x = lerpf(_camera_x, target_x, weight)
	camera.global_position = Vector2(roundf(_camera_x), CAMERA_Y)


## A bin has taken a piece of rubbish. Count it, and finish the level once every
## piece in the level has been sorted.
##
## A piece cannot be counted twice: `_on_wrong_bin` never gets here, a sorted
## piece is used up for good, and a full bin refuses to take anything more.
func _on_rubbish_sorted(_kind: StringName) -> void:
	_sorted_count += 1
	if _sorted_count < trash_items.size():
		return
	_finish_level()


## The last piece of rubbish is sorted, which finishes Summer the same way the
## flower finishes Spring: a pause first, then the completion screen.
func _finish_level() -> void:
	# Guarded, so a second signal can never start a second countdown or reshow
	# the banner.
	if _banner_shown or _banner_timer >= 0.0:
		return

	if complete_banner_delay <= 0.0:
		_reveal_banner()
		return

	_banner_timer = complete_banner_delay


func _reveal_banner() -> void:
	_banner_shown = true
	level_complete_banner.visible = true
	# The Next Level button is part of the same completion screen. It stays hidden
	# and inert until now, so nothing can click it before the level is finished,
	# and it only exists once the player could actually leave.
	next_level_button.visible = true
	next_level_button.disabled = false


## Something has been brought to a bin that does not want it. Say so briefly.
##
## The rubbish is deliberately left alone: the bin refused it, so the dog is
## still carrying exactly what it was carrying and can walk it to the right bin.
## Nothing here touches the dog or the rubbish.
func _on_wrong_bin(_held_kind: StringName, _bin_kind: StringName) -> void:
	wrong_bin_label.text = "Wrong bin!"
	wrong_bin_label.visible = true
	_wrong_bin_timer = wrong_bin_notice_time


## The only door out of a finished Summer level. Level 1 leads to level 2, and
## level 2 leads on to Autumn.
func _on_next_level_pressed() -> void:
	if stage == 1:
		get_tree().change_scene_to_file(STAGE_2_SCENE)
	else:
		get_tree().change_scene_to_file(NEXT_SCENE)
