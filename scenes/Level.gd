extends Node2D

const TILE_WIDTH := 64
const TILE_HEIGHT := 56
const LEVEL_WIDTH := 1280
const LEVEL_HEIGHT := 720

const GROUND_ROW := 10
const GROUND_ROW_COUNT := 3
const COLUMN_COUNT := 20

const WALL_WIDTH := 16
const WALL_COLOR := Color(0.82, 0.8, 0.76)

# [row, first column, how many columns]
const PLATFORM_ROWS := [
	[8, 3, 4],
	[6, 8, 4],
	[4, 13, 4],
]

const CAT1_TEXTURE := preload("res://assets/Spring/Cat1.png")
const CAT2_TEXTURE := preload("res://assets/Spring/Cat2.png")

# cat_region crops each PNG down to its opaque artwork, so the visible cat is
# centred and its feet line up with the collider base.
const PLAYER_SPAWNS := [
	{
		"label_text": "P1",
		"position": Vector2(120, 559),
		"cat_texture": CAT1_TEXTURE,
		"cat_region": Rect2(11, 16, 129, 96),
		"left_action": &"p1_left",
		"right_action": &"p1_right",
		"jump_action": &"p1_jump",
	},
	{
		"label_text": "P2",
		"position": Vector2(232, 559),
		"cat_texture": CAT2_TEXTURE,
		"cat_region": Rect2(9, 15, 128, 96),
		"left_action": &"p2_left",
		"right_action": &"p2_right",
		"jump_action": &"p2_jump",
	},
]

# The Spring task: carry these three to the pot, in this order. Each entry is
# the kind of item, its picture, the opaque part of that picture, how big to draw
# it, how big a box picks it up, and where it is left lying around the level.
#
# The water is tucked into the top right corner on purpose. A single cat's feet
# never get above y=90, even jumping off the highest platform, so its box cannot
# reach y=32. Two cats can: the top cat starts on a head one body height up and
# the pair jumps about 134, which is enough. Either cat jumping is enough, and
# the top cat collects the water on the way past it, so no landing is needed.
const GARDEN_ITEMS := [
	{
		"kind": &"soil",
		"texture": preload("res://assets/Spring/Soil.png"),
		"region": Rect2(32, 64, 184, 144),
		"display_height": 56.0,
		"pickup_size": 48.0,
		"position": Vector2(460, 532),
	},
	{
		"kind": &"seeds",
		"texture": preload("res://assets/Spring/Seeds.png"),
		"region": Rect2(56, 56, 80, 96),
		"display_height": 56.0,
		"pickup_size": 48.0,
		"position": Vector2(640, 308),
	},
	{
		"kind": &"water",
		"texture": preload("res://assets/Spring/Water.png"),
		"region": Rect2(56, 48, 104, 160),
		"display_height": 32.0,
		"pickup_size": 32.0,
		"position": Vector2(1024, 16),
	},
]

# On the flat stretch of ground on the right, clear of everything overhead. The
# platforms run from x=192 to x=768, and the pot grows to 176 tall with a status
# label above it, so any closer in it would end up behind a platform.
const POT_POSITION := Vector2(900, 560)

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const TILE_SCENE := preload("res://scenes/GroundTile.tscn")
const ITEM_SCENE := preload("res://scenes/GardenItem.tscn")
const POT_SCENE := preload("res://scenes/PlantPot.tscn")

## Where the Next Level button sends the player. There is no Summer gameplay
## yet, only a placeholder scene that makes the transition real.
const SUMMER_SCENE := "res://scenes/SummerLevel.tscn"

## How long the Level Complete banner waits after the pot becomes a flower, so
## the flower is clearly visible on its own first. 1.5s sits in the middle of the
## 1-2s that was asked for; set it to 0 to bring the banner straight back.
@export_range(0.0, 5.0, 0.1) var complete_banner_delay: float = 1.5

@onready var terrain: Node2D = $Terrain
@onready var walls: Node2D = $Walls
@onready var garden: Node2D = $Garden
@onready var players: Node2D = $Players
@onready var level_complete_banner: Sprite2D = $LevelComplete
@onready var next_level_button: TextureButton = $NextLevel

## Counts down to the banner appearing. Negative means nothing is pending.
var _banner_timer: float = -1.0
var _banner_shown: bool = false


func _ready() -> void:
	# The Next Level button belongs to the completion screen and nowhere else, so
	# it is forced hidden and inert here as well as in the scene file. `disabled`
	# only stops clicks; the picture still draws while a button is disabled, so
	# `visible` is what keeps it off the screen during gameplay. Setting it in
	# code as well means an editor save that drops the scene's `visible = false`
	# cannot leave the button sitting in the level while the cats are still
	# gardening. _reveal_banner() is the only thing that ever turns it on, and
	# it runs only once the pot has become a flower.
	next_level_button.visible = false
	next_level_button.disabled = true
	next_level_button.pressed.connect(_on_next_level_pressed)
	_build_ground()
	_build_platforms()
	_build_walls()
	_build_players()
	_build_garden()


func _build_ground() -> void:
	for row_offset in GROUND_ROW_COUNT:
		for column in COLUMN_COUNT:
			_add_tile(column, GROUND_ROW + row_offset, row_offset > 0)


func _build_platforms() -> void:
	for platform in PLATFORM_ROWS:
		var row: int = platform[0]
		var first_column: int = platform[1]
		var column_count: int = platform[2]
		for index in column_count:
			_add_tile(first_column + index, row, false)


func _add_tile(column: int, row: int, buried: bool) -> void:
	var tile := TILE_SCENE.instantiate() as GroundTile
	tile.buried = buried
	tile.position = Vector2(column * TILE_WIDTH, row * TILE_HEIGHT)
	terrain.add_child(tile)


func _build_walls() -> void:
	_add_wall(Rect2(0, 0, WALL_WIDTH, LEVEL_HEIGHT))
	_add_wall(Rect2(LEVEL_WIDTH - WALL_WIDTH, 0, WALL_WIDTH, LEVEL_HEIGHT))


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


func _build_players() -> void:
	for spawn in PLAYER_SPAWNS:
		var player := PLAYER_SCENE.instantiate() as Player
		player.label_text = spawn["label_text"]
		player.left_action = spawn["left_action"]
		player.right_action = spawn["right_action"]
		player.jump_action = spawn["jump_action"]
		player.cat_texture = spawn["cat_texture"]
		player.cat_region = spawn["cat_region"]
		player.position = spawn["position"]
		players.add_child(player)


## Keeps the lower cat drawn behind the upper one, so a stacked pair reads
## clearly instead of the top cat being hidden behind the one underneath.
##
## Also runs the countdown that holds the Level Complete banner back, so the
## flower can be seen on its own first. A negative timer means "not counting".
func _process(delta: float) -> void:
	if _banner_timer >= 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0:
			_banner_timer = -1.0
			_reveal_banner()

	var ordered: Array[Node2D] = []
	for child in players.get_children():
		if child is Player:
			ordered.append(child)

	ordered.sort_custom(
		func(a: Node2D, b: Node2D) -> bool: return a.position.y > b.position.y
	)

	for index in ordered.size():
		ordered[index].z_index = index


func _build_garden() -> void:
	for item in GARDEN_ITEMS:
		var garden_item := ITEM_SCENE.instantiate() as GardenItem
		garden_item.item_kind = item["kind"]
		garden_item.item_texture = item["texture"]
		garden_item.art_region = item["region"]
		garden_item.display_height = item["display_height"]
		garden_item.pickup_size = item["pickup_size"]
		garden_item.position = item["position"]
		garden.add_child(garden_item)

	var pot := POT_SCENE.instantiate() as PlantPot
	pot.position = POT_POSITION
	pot.level_complete.connect(_on_level_complete)
	garden.add_child(pot)


## Growing the flower finishes Spring: it reveals the Level Complete banner and
## the Next Level button together, and the button is the door to Summer.
##
## The pot only emits level_complete once it reaches the flower, so this is the
## only thing that can ever start the countdown. The banner is deliberately NOT
## shown straight away: the flower itself is the reward, so it gets
## complete_banner_delay seconds on its own before the signboard drops in over
## the top of it.
func _on_level_complete() -> void:
	# Guarded, so a second signal can never start a second countdown or reshow
	# the banner. The pot only ever fires this once, but the guard makes that
	# guarantee local and obvious rather than something to remember.
	if _banner_shown or _banner_timer >= 0.0:
		return

	if complete_banner_delay <= 0.0:
		_reveal_banner()
		return

	_banner_timer = complete_banner_delay


func _reveal_banner() -> void:
	_banner_shown = true
	level_complete_banner.visible = true
	# The Next Level button is part of the same completion screen. It stays inert
	# (disabled) until now, so nothing can click it before the level is finished,
	# and it only exists once the player could actually leave.
	next_level_button.visible = true
	next_level_button.disabled = false


## The only door out of a finished Spring. Clicking/tapping the Next Level
## picture loads the Summer scene, which is still only a placeholder: the point
## of this is to make "Spring Complete -> Next Level -> Summer" work, not to
## build Summer's rubbish/sorting game yet.
func _on_next_level_pressed() -> void:
	get_tree().change_scene_to_file(SUMMER_SCENE)
