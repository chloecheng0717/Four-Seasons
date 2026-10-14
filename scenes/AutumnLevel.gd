extends Node2D

## Autumn: two foxes collect leaves and place each one in the frame it fits.
##
## A fox picks a leaf up by standing in it, carries one at a time, and brings it
## to a frame. The frame whose ghosted leaf outline matches the leaf takes it and
## shows it inside itself; every other frame refuses it and the fox keeps carrying
## it. Once all four are placed the Level Complete picture and the Next Level
## button turn up together, exactly as they do at the end of Spring and Summer.
##
## ## Everything here is reused rather than rebuilt
##
## The same tiles (GroundTile), the same two-player scene (Player.tscn, so the
## foxes move, jump, stack, carry and collide in precisely the way the cats and
## dogs do and only the artwork changes), the same collectable (GardenItem, which
## is already generic and already has "used up for good") and the same completion
## screen. The two genuinely new pieces are LeafFrame, which is TrashBin and
## PlantPot's role in the level with a visual rule instead of a named one, and the
## side-scrolling camera.
##
## ## The world is long on purpose
##
## Spring and Summer each fit on exactly one screen. Autumn is 4800px wide -
## three and three quarter screens - and is meant to be walked. The camera is one
## shared Camera2D that follows the middle of the two foxes and is clamped to the
## world's own edges by the usual camera limits, so the view can never wander off
## the map. The level is exactly one screen tall, so the camera never moves
## vertically at all, which is also why the help labels and the completion screen
## live in a CanvasLayer: as CanvasItems they would scroll away otherwise.
##
## Because this is the one level with a camera that actually travels, the camera
## is kept on whole pixels (see _follow_foxes). Every ground, terrace and platform
## tile is a 64x56 pixel-art picture drawn 1:1, so a camera sitting on a fraction
## of a pixel drags every seam between them off the pixel grid, and the rasteriser
## then drops a one pixel column of background along each one. At half a pixel of
## offset it drops one at every seam at once, which looks like thin white lines
## flickering across the level as the camera moves. Rounding the camera costs
## nothing: the motion is unchanged, just measured in whole pixels.
##
## ## The matching is visual and nothing else
##
## Every frame's artwork has a ghosted leaf silhouette in the middle of it, and
## every leaf's outline matches exactly one of those silhouettes. The frames carry
## no label, no number and no wording of any kind, and neither do the leaves. Which
## leaf a frame wants can only be seen.
##
## A note on names, as in Summer: Player's artwork fields are still called
## `cat_texture` and `cat_region` because they were named for the cats. Renaming
## them would mean editing Player.gd, Player.tscn and Level.gd, which is not worth
## it for a cosmetic rename, so the foxes are simply assigned to the cat fields.
## The foxes are authored facing LEFT exactly like the cats and the dogs, so
## `flip_h` still means "turn right" and Player.gd needs no change at all.

const TILE_WIDTH := 64
const TILE_HEIGHT := 56

## The world. 4800 x 720 is 75 columns of 64px, which is three and three quarter
## screens wide and exactly one screen tall.
const LEVEL_WIDTH := 4800
const LEVEL_HEIGHT := 720
const COLUMN_COUNT := 75

## The floor. Row 10's top edge is y=560, the same surface Spring and Summer use.
const GROUND_ROW := 10
const GROUND_ROW_COUNT := 3

## The frame terrace: two extra rows stacked on top of the ground across the last
## fifteen columns, so the four frames stand on a raised shelf at the right-hand
## end of the world instead of in the middle of the corridor. Its surface is row
## 8's top edge, y=448, which is a 112px step up from the floor - a clear jump for
## a fox, and a safe drop back down.
const TERRACE_FIRST_COLUMN := 60
const TERRACE_LAST_COLUMN := 74
const TERRACE_TOP_ROW := 8
const TERRACE_SURFACE_Y := 448.0

const WALL_WIDTH := 16
const WALL_COLOR := Color(0.45, 0.29, 0.16)

## A warm late-afternoon sky, the same trick Summer uses: one flat colour, no
## background art.
const SKY_COLOR := Color(0.96, 0.87, 0.72)

# [row, first column, how many columns]
# The map, read left to right. Everything is reachable by walking and jumping
# along the floor; the shelves are there to put a leaf out of a plain walk.
const PLATFORM_ROWS := [
	[8, 2, 4],     # A  starting ledge          x  128.. 384   surface 448
	[8, 11, 4],    # B  low shelf              x  704.. 960   surface 448
	[6, 16, 5],    # B  high shelf             x 1024..1344   surface 336
	[8, 21, 4],    # B/C low shelf             x 1344..1600   surface 448
	[6, 26, 5],    # C  mid shelf              x 1664..1984   surface 336
	[4, 31, 4],    # C  high shelf             x 1984..2240   surface 224
	[8, 36, 4],    # D  low shelf              x 2304..2560   surface 448
	[6, 43, 5],    # D  mid shelf              x 2752..3072   surface 336
	[4, 48, 4],    # D  high shelf             x 3072..3328   surface 224
	[8, 51, 4],    # E  approach ledge         x 3264..3520   surface 448
	[6, 55, 4],    # E  high step              x 3520..3776   surface 336
]

## Every ground and platform tile is the same 64x56 Autumn Tile picture, cropped to
## its opaque part. It comes with padding, so without the crop the tile would be
## drawn mostly air.
const TILE_TEXTURE := preload("res://assets/Autumn/Autumn Tile.png")
const TILE_REGION := Rect2(16, 13, 64, 56)

## The one tree picture. It is only 27x36, so it is drawn much larger than that.
const TREE_TEXTURE := preload("res://assets/Autumn/Autumn_Tree.png")
const TREE_REGION := Rect2(0, 0, 27, 36)
const TREE_DISPLAY_HEIGHT := 104.0
## Every tree is scenery: drawn behind everything, with no collider of any kind.
const TREE_BACK_Z := -5

## [x] - the ten trees are decoration only. Not one of them has a collision shape,
## a physics body or an area, so a fox walks and jumps straight through all of them;
## they are there to be looked at, not to be got past. They keep the spots they
## always had, and the map, the shelves and the leaf routes are untouched.
const TREES := [96.0, 400.0, 512.0, 1280.0, 1632.0, 2176.0, 2272.0, 2656.0, 2880.0, 3648.0]

const FOX1_TEXTURE := preload("res://assets/Autumn/Fox1.png")
const FOX2_TEXTURE := preload("res://assets/Autumn/Fox2.png")

## Both foxes are 256x256 pictures with their artwork in the same place, and both
## are drawn facing LEFT exactly like the cats and the dogs - so `flip_h` still
## means "turn right" and Player.gd needs no change at all for facing. They are
## the same 56px tall as a cat or a dog, so the collider and the whole ride system
## work exactly as they always have.
const FOX_REGION := Rect2(16, 40, 216, 168)

const PLAYER_SPAWNS := [
	{
		"label_text": "P1",
		"position": Vector2(140, 559),
		"fox_texture": FOX1_TEXTURE,
		"fox_region": FOX_REGION,
		"left_action": &"p1_left",
		"right_action": &"p1_right",
		"jump_action": &"p1_jump",
	},
	{
		"label_text": "P2",
		"position": Vector2(252, 559),
		"fox_texture": FOX2_TEXTURE,
		"fox_region": FOX_REGION,
		"left_action": &"p2_left",
		"right_action": &"p2_right",
		"jump_action": &"p2_jump",
	},
]

## The four leaves, one per area, spread right across the map so the level has to be
## explored. Each is the same GardenItem scene Spring's gardening things and
## Summer's rubbish use: a picture, a kind and a pickup box.
##
## The heights are not guesses. A fox standing on a surface at y = S sweeps its
## collider through every height from S-52 (standing) to S-186 (the top of a jump),
## so a leaf is gettable from that surface when its box overlaps that band. Each
## leaf below sits inside the band of the shelf named in its comment and outside
## the band of the floor, so it always takes a jump and never a walk.
const LEAVES := [
	{
		# Above the B low shelf (surface 448). Band 262..448; box is 318..362.
		"kind": &"leaf1",
		"texture": preload("res://assets/Autumn/Leaf1.png"),
		"region": Rect2(2, 6, 25, 24),
		"position": Vector2(832, 340),
	},
	{
		# Above the C mid shelf (surface 336). Band 150..336; box is 218..262.
		"kind": &"leaf2",
		"texture": preload("res://assets/Autumn/Leaf2.png"),
		"region": Rect2(2, 2, 25, 25),
		"position": Vector2(1824, 240),
	},
	{
		# Above the D low shelf (surface 448). Band 262..448; box is 278..322.
		"kind": &"leaf3",
		"texture": preload("res://assets/Autumn/Leaf3.png"),
		"region": Rect2(4, 2, 23, 28),
		"position": Vector2(2432, 300),
	},
	{
		# Above the D high shelf (surface 224). Band 38..224; box is 98..142.
		"kind": &"leaf4",
		"texture": preload("res://assets/Autumn/Leaf4.png"),
		"region": Rect2(3, 2, 25, 28),
		"position": Vector2(3200, 120),
	},
]

## How big every leaf is drawn in the world and beside the fox that carries it.
const LEAF_DISPLAY_HEIGHT := 48.0
const LEAF_PICKUP_SIZE := 44.0

## The four frames, standing in a row along the raised terrace at the right-hand
## side of the world. 240px apart, which leaves 156px of clear ground between their
## pickup boxes: a fox is 60px wide, so it cannot be inside two frames at once and
## cannot place a leaf by walking past.
##
## They are deliberately NOT in the order the leaves are numbered, so the row reads
## as four things to be matched rather than four things to be done in sequence. Each
## entry's `frame` is the artwork and the leaf that artwork belongs to; the leaf a
## frame takes is worked out from that pairing, not from its position.
const FRAMES := [
	{
		"frame": "Leaf_frame4",
		"kind": &"leaf4",
		"x": 3950.0,
	},
	{
		"frame": "Leaf_frame2",
		"kind": &"leaf2",
		"x": 4190.0,
	},
	{
		"frame": "Leaf_frame3",
		"kind": &"leaf3",
		"x": 4430.0,
	},
	{
		"frame": "Leaf_frame1",
		"kind": &"leaf1",
		"x": 4670.0,
	},
]

## The artwork of each frame, and the leaf that fits it. `region` and
## `silhouette` were measured out of the PNGs: `region` is the opaque part of the
## picture and `silhouette` is the size of the ghosted leaf drawn inside it, which
## is what the placed leaf is scaled to.
const FRAME_ART := {
	"Leaf_frame1": {
		"region": Rect2(74, 45, 406, 393),
		"silhouette": Vector2(161, 154),
	},
	"Leaf_frame2": {
		"region": Rect2(58, 29, 407, 396),
		"silhouette": Vector2(161, 161),
	},
	"Leaf_frame3": {
		"region": Rect2(68, 47, 408, 392),
		"silhouette": Vector2(147, 182),
	},
	"Leaf_frame4": {
		"region": Rect2(79, 39, 407, 396),
		"silhouette": Vector2(161, 182),
	},
}

## How tall a frame is drawn. Its artwork is about 400x395, so this makes it a
## large, unmissable object rather than a small ornament.
const FRAME_DISPLAY_HEIGHT := 168.0
## How wide a frame's pickup box is. Its height is worked out from the artwork so
## the box always runs from the middle of the ghosted leaf down to the frame's own
## feet, which is what lets a fox standing on the floor in front of a frame reach
## it without jumping.
const FRAME_BOX_WIDTH := 84.0

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const TILE_SCENE := preload("res://scenes/GroundTile.tscn")
const ITEM_SCENE := preload("res://scenes/GardenItem.tscn")
const FRAME_SCENE := preload("res://scenes/LeafFrame.tscn")

## Where the Next Level button goes once Autumn is finished. Winter exists (built
## 2026-10-04), so a finished Autumn now hands over to it and the chain is
## Spring -> Summer -> Autumn -> Winter -> Spring rather than dead-ending or
## skipping a finished season.
##
## This one constant is the whole change. Winter's own NEXT_SCENE is Spring, which
## closes the loop. See PROGRESS.md.
const NEXT_SCENE := "res://scenes/WinterLevel.tscn"

## --- Autumn 2 -----------------------------------------------------------------
## Autumn has two levels, and both use this script. Level 1 is AutumnLevel.tscn,
## the long walk above. Level 2 is AutumnLevel2.tscn, which sets `stage = 2` and
## gets the tables below instead: a short level that fits on one screen, with
## three leaves and three frames. Level 1's tables above are left exactly as they
## were.
##
## The Next Level button of level 1 goes to level 2, and level 2's goes to Winter
## (NEXT_SCENE, which still means "the next season").
const STAGE_2_SCENE := "res://scenes/AutumnLevel2.tscn"

## One screen: 20 columns of 64px.
const STAGE_2_WIDTH := 1280
const STAGE_2_COLUMN_COUNT := 20

## [row, first column, how many columns]. A low shelf (top at y 448) and, next
## to it, a high shelf (top at y 336), sharing an edge, on the left half of the
## screen. The right half is open floor for the frames.
const STAGE_2_PLATFORM_ROWS := [
	[8, 5, 3],     # low shelf     x 320..512   surface 448
	[6, 8, 3],     # high shelf    x 512..704   surface 336
]

## [x] - decoration only, as in level 1.
const STAGE_2_TREES := [40.0, 260.0]

## The three leaves. A fox sweeps its body from S-52 up to about S-186 when it
## jumps from a surface at y = S, and a fox on its friend's head reaches about
## S-238.
## - Leaf 1 (box 398..442) floats above the floor near the start: one jump.
## - Leaf 3 (box 308..352) is above the low shelf (448); from the floor a jump
##   only reaches 374, so it needs the shelf.
## - Leaf 2 (box 108..140) is above the high shelf (336), where one jump only
##   reaches 150. It takes two: one fox on the other's head. Its box is 32px, like
##   Spring's water, which leaves a clear margin either way.
const STAGE_2_LEAVES := [
	{
		"kind": &"leaf1",
		"texture": preload("res://assets/Autumn/Leaf1.png"),
		"region": Rect2(2, 6, 25, 24),
		"position": Vector2(96, 420),
	},
	{
		"kind": &"leaf3",
		"texture": preload("res://assets/Autumn/Leaf3.png"),
		"region": Rect2(4, 2, 23, 28),
		"position": Vector2(416, 330),
	},
	{
		"kind": &"leaf2",
		"texture": preload("res://assets/Autumn/Leaf2.png"),
		"region": Rect2(2, 2, 25, 25),
		"position": Vector2(608, 124),
		"pickup_size": 32.0,
	},
]

## The three frames, standing on the floor on the right, 180px apart. Each is
## drawn about 174px wide, so they just clear each other and the right-hand
## wall, and their 84px boxes leave 96px of floor between them: more than a
## fox's 60px, so a fox can never be in two at once. Again not in leaf order.
const STAGE_2_FRAMES := [
	{
		"frame": "Leaf_frame3",
		"kind": &"leaf3",
		"x": 815.0,
	},
	{
		"frame": "Leaf_frame1",
		"kind": &"leaf1",
		"x": 995.0,
	},
	{
		"frame": "Leaf_frame2",
		"kind": &"leaf2",
		"x": 1175.0,
	},
]
## Level 2's frames stand on the floor itself, not on a terrace.
const STAGE_2_FRAME_Y := 560.0

## Which of Autumn's two levels this is. AutumnLevel.tscn leaves it at 1;
## AutumnLevel2.tscn sets it to 2.
@export_range(1, 2) var stage: int = 1

## How long the Level Complete banner waits after the last leaf is placed, so the
## filled frames are visible on their own first. Same as Spring and Summer.
@export_range(0.0, 5.0, 0.1) var complete_banner_delay: float = 1.5
## How long the "Wrong frame!" notice stays up. It has to be long enough to be
## read and short enough to be out of the way.
@export_range(0.2, 5.0, 0.1) var wrong_leaf_notice_time: float = 1.2

## The camera sits at this height and never moves vertically, because the level is
## exactly one screen tall.
const CAMERA_Y := 360.0
## How briskly the camera catches up with the foxes. High enough to feel
## responsive, low enough that walking reads as a pan rather than a jump. This is
## the same number, and the same easing, the engine's own position smoothing used
## to be given: the level does the smoothing itself now so that it can round the
## result to a whole pixel. See _follow_foxes.
const CAMERA_SMOOTHING := 8.0
## Players are drawn above the terrain and above the frames, and the lower fox is
## always drawn behind the upper one.
const PLAYER_Z := 2

@onready var terrain: Node2D = $Terrain
@onready var walls: Node2D = $Walls
@onready var trees: Node2D = $Trees
@onready var leaves: Node2D = $Leaves
@onready var frames: Node2D = $Frames
@onready var players: Node2D = $Players
@onready var camera: Camera2D = $Camera2D
@onready var level_complete_banner: Sprite2D = $UI/LevelComplete
@onready var next_level_button: TextureButton = $UI/NextLevel
@onready var wrong_leaf_label: Label = $UI/WrongLeaf

## Counts down to the banner appearing. Negative means nothing is pending.
var _banner_timer: float = -1.0
var _banner_shown: bool = false
## The camera's own smoothed horizontal position, kept unrounded here and rounded
## only when it is handed to the camera. Set for real in _ready, once the foxes
## exist. See _follow_foxes.
var _camera_x: float = 0.0
## Counts down to the "Wrong frame!" notice going away. Negative means it is not up.
var _wrong_leaf_timer: float = -1.0
## The kinds placed so far, so the same leaf can never be counted twice.
var _placed: Dictionary = {}
## Every kind the level is waiting for, taken from the frames themselves, so the
## level and its frames cannot disagree about what "finished" means.
var _required_kinds: Array[StringName] = []

## The layout actually built. They start as level 1's tables, and _ready swaps
## in level 2's when `stage` is 2.
var level_width: int = LEVEL_WIDTH
var world_columns: int = COLUMN_COUNT
var platform_rows: Array = PLATFORM_ROWS
var tree_spots: Array = TREES
var leaf_table: Array = LEAVES
var frame_table: Array = FRAMES
## Level 1's frames stand on a raised terrace; level 2 has none.
var has_terrace: bool = true
var frame_y: float = TERRACE_SURFACE_Y


func _ready() -> void:
	# The Summer transition test drives a real scene change and then needs to
	# prove it arrived in Autumn. When run with that user argument, say so and quit
	# instead of building the level - exactly what SummerLevel does for Spring's
	# own transition test.
	var args := OS.get_cmdline_user_args()
	if stage == 1 and args.has("--autumn-check"):
		print("NEXT LEVEL REACHED AUTUMN")
		get_tree().quit(0)
		return
	# And the same again for arriving in Autumn 2 from Autumn 1.
	if stage == 2 and args.has("--autumn2-check"):
		print("NEXT LEVEL REACHED AUTUMN 2")
		get_tree().quit(0)
		return

	if stage == 2:
		level_width = STAGE_2_WIDTH
		world_columns = STAGE_2_COLUMN_COUNT
		platform_rows = STAGE_2_PLATFORM_ROWS
		tree_spots = STAGE_2_TREES
		leaf_table = STAGE_2_LEAVES
		frame_table = STAGE_2_FRAMES
		has_terrace = false
		frame_y = STAGE_2_FRAME_Y
	# The camera's limits are the world's own edges. Level 2 is exactly one
	# screen wide, so its camera simply never moves.
	camera.limit_right = level_width

	# The Next Level button belongs to the completion screen and nowhere else. The
	# scene hides it and this hides it again, for the same reason as in Spring and
	# Summer: a disabled button still draws, so `visible` is what keeps it off the
	# screen, and an editor save that loses the scene's `visible = false` cannot
	# leave it sitting in the level while the foxes are still collecting leaves.
	next_level_button.visible = false
	next_level_button.disabled = true
	next_level_button.pressed.connect(_on_next_level_pressed)

	for entry in frame_table:
		_required_kinds.append(entry["kind"])

	_build_ground()
	if has_terrace:
		_build_terrace()
	_build_platforms()
	_build_walls()
	_build_trees()
	_build_players()
	_build_leaves()
	_build_frames()

	# Put the camera on the foxes straight away, so the level does not open with the
	# view sweeping in from the middle of an empty map.
	_camera_x = _foxes_centre().x
	camera.global_position = Vector2(roundf(_camera_x), CAMERA_Y)


## The middle of the two foxes. One shared camera follows this, which is what makes
## a co-op level readable: walk together and the view is steady, and split up and it
## settles between them instead of leaving one player off the edge of the screen.
func _foxes_centre() -> Vector2:
	var sum := Vector2.ZERO
	var count := 0
	for child in players.get_children():
		if child is Player:
			sum += (child as Player).global_position
			count += 1
	if count == 0:
		return Vector2(level_width * 0.5, CAMERA_Y)
	return sum / float(count)


## One unbroken floor across the whole map. There are deliberately no holes in it:
## a fox that falls into a pit it cannot jump out of would be stuck, and this game
## has no way to lose and respawn, so the map is built so that falling always means
## landing somewhere you can walk off again.
func _build_ground() -> void:
	for row_offset in GROUND_ROW_COUNT:
		for column in world_columns:
			_add_tile(column, GROUND_ROW + row_offset, row_offset > 0)


func _build_terrace() -> void:
	for row in range(TERRACE_TOP_ROW, GROUND_ROW):
		for column in range(TERRACE_FIRST_COLUMN, TERRACE_LAST_COLUMN + 1):
			_add_tile(column, row, row > TERRACE_TOP_ROW)


func _build_platforms() -> void:
	for platform in platform_rows:
		var row: int = platform[0]
		var first_column: int = platform[1]
		var column_count: int = platform[2]
		for index in column_count:
			_add_tile(first_column + index, row, false)


## Every ground, terrace and platform tile is the same 64x56 Autumn Tile picture,
## cropped to its opaque part and drawn from the tile's own top left corner, exactly
## the way Spring's ground tile and Summer's sand tile are drawn.
func _add_tile(column: int, row: int, buried: bool) -> void:
	var tile := TILE_SCENE.instantiate() as GroundTile
	tile.buried = buried
	tile.surface_texture = TILE_TEXTURE
	tile.surface_region = TILE_REGION
	tile.position = Vector2(column * TILE_WIDTH, row * TILE_HEIGHT)
	terrain.add_child(tile)


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


## The trees, and every one of them is decoration. Each is a plain Node2D holding a
## single sprite, drawn behind the level, with no CollisionShape2D, no Area2D, no
## StaticBody2D and nothing else a fox could bump into or stand on. There is
## deliberately no collision branch here any more: the trees are scenery.
func _build_trees() -> void:
	for tree_x: float in tree_spots:
		var tree := Node2D.new()
		tree.z_index = TREE_BACK_Z
		tree.position = Vector2(tree_x, GROUND_ROW * TILE_HEIGHT)

		var sprite := Sprite2D.new()
		sprite.texture = TREE_TEXTURE
		sprite.texture_filter = 1
		sprite.region_enabled = true
		sprite.region_rect = TREE_REGION
		var uniform_scale: float = TREE_DISPLAY_HEIGHT / TREE_REGION.size.y
		sprite.scale = Vector2(uniform_scale, uniform_scale)
		# Bottom edge on the node, the same anchor Player.gd and LeafFrame.gd use,
		# so a tree stands on the floor instead of hovering over it.
		sprite.offset = Vector2(0.0, -TREE_REGION.size.y * 0.5)
		tree.add_child(sprite)

		trees.add_child(tree)


## The foxes are the same Player scene as the cats and the dogs, with their own
## artwork, their own controls and their own spawn. Nothing else about them differs,
## so they move, jump, stack, carry and collide in exactly the way the others do.
func _build_players() -> void:
	for spawn in PLAYER_SPAWNS:
		var player := PLAYER_SCENE.instantiate() as Player
		player.label_text = spawn["label_text"]
		player.left_action = spawn["left_action"]
		player.right_action = spawn["right_action"]
		player.jump_action = spawn["jump_action"]
		player.cat_texture = spawn["fox_texture"]
		player.cat_region = spawn["fox_region"]
		player.position = spawn["position"]
		players.add_child(player)


## The leaves are the same GardenItem scene Spring's gardening things and Summer's
## rubbish use. It is already generic - a picture, a kind and a pickup box - and it
## already has the guarantee Autumn needs most: a leaf that has been placed is taken
## out of the level for good and can never be picked up again where it was found.
func _build_leaves() -> void:
	for item in leaf_table:
		var leaf := ITEM_SCENE.instantiate() as GardenItem
		leaf.item_kind = item["kind"]
		leaf.item_texture = item["texture"]
		leaf.art_region = item["region"]
		leaf.display_height = LEAF_DISPLAY_HEIGHT
		leaf.pickup_size = item.get("pickup_size", LEAF_PICKUP_SIZE)
		leaf.position = item["position"]
		leaves.add_child(leaf)


## The frames are four instances of one LeafFrame scene, differing only in their
## artwork and in the leaf that artwork belongs to. There is no label, no number
## and no wording anywhere on them: which leaf a frame takes is only visible.
func _build_frames() -> void:
	for entry in frame_table:
		var art_name: String = entry["frame"]
		var art: Dictionary = FRAME_ART[art_name]
		var kind: StringName = entry["kind"]

		var leaf_texture: Texture2D = null
		var leaf_region := Rect2()
		for leaf in leaf_table:
			if leaf["kind"] == kind:
				leaf_texture = leaf["texture"]
				leaf_region = leaf["region"]
				break

		var frame := FRAME_SCENE.instantiate() as LeafFrame
		frame.accepts_kind = kind
		frame.frame_texture = load("res://assets/Autumn/%s.png" % art_name)
		frame.art_region = art["region"]
		frame.silhouette_size = art["silhouette"]
		frame.leaf_texture = leaf_texture
		frame.leaf_region = leaf_region
		frame.display_height = FRAME_DISPLAY_HEIGHT
		frame.box_width = FRAME_BOX_WIDTH
		frame.position = Vector2(entry["x"], frame_y)
		frame.leaf_placed.connect(_on_leaf_placed)
		frame.wrong_leaf.connect(_on_wrong_leaf)
		frames.add_child(frame)


## Keeps the lower fox drawn behind the upper one, runs the countdown that holds the
## Level Complete banner back, takes the "Wrong frame!" notice down again, and moves
## the one shared camera onto the middle of the two foxes.
func _process(delta: float) -> void:
	if _banner_timer >= 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0:
			_banner_timer = -1.0
			_reveal_banner()

	if _wrong_leaf_timer >= 0.0:
		_wrong_leaf_timer -= delta
		if _wrong_leaf_timer <= 0.0:
			_wrong_leaf_timer = -1.0
			wrong_leaf_label.visible = false

	var ordered: Array[Node2D] = []
	for child in players.get_children():
		if child is Player:
			ordered.append(child)

	ordered.sort_custom(
		func(a: Node2D, b: Node2D) -> bool: return a.position.y > b.position.y
	)

	for index in ordered.size():
		ordered[index].z_index = PLAYER_Z + index

	# One camera for both foxes, never two. Its horizontal limits are the world's
	# own edges and its vertical limits are the world's own height, so however far
	# the foxes walk the view cannot show anything that is not part of the level.
	_follow_foxes(delta)


## The one shared camera, moved onto the middle of the two foxes and kept on whole
## pixels.
##
## The engine's own position smoothing is deliberately not used here, and this is
## the whole reason for the function. That smoothing interpolates continuously, so
## during ordinary walking the camera sits on a fraction of a pixel for nearly
## every single frame. Every tile in this level is a 64x56 pixel-art picture drawn
## 1:1 at whole-pixel positions, so a fractional camera puts each seam between two
## tiles at a fractional screen position, and the rasteriser then fails to cover
## one column of pixels along it - exposing the background behind. Measured on a
## real render of this level, half a pixel of camera offset opens a one pixel gap
## at all twenty tile seams across the screen at once: thin white lines that come
## and go as the camera moves. Rounding the camera to a whole pixel removes the
## seams without touching a single tile.
##
## The easing is the engine's own, unchanged - the same exponential approach with
## the same CAMERA_SMOOTHING - so the camera still travels the same distance over
## the same time and walking still reads as a pan. The only difference is that the
## view now advances in whole pixel steps instead of fractions, which is how pixel
## art is meant to scroll.
func _follow_foxes(delta: float) -> void:
	var target_x: float = _foxes_centre().x
	var weight: float = 1.0 - exp(-CAMERA_SMOOTHING * delta)
	_camera_x = lerpf(_camera_x, target_x, weight)
	camera.global_position = Vector2(roundf(_camera_x), CAMERA_Y)


## A frame has taken a leaf. Count it, and finish the level once every frame is
## full.
##
## The Dictionary is the reason a leaf cannot be counted twice: a frame that is
## already full refuses to take anything more, so this runs exactly once per kind.
func _on_leaf_placed(kind: StringName) -> void:
	_placed[kind] = true
	if _placed.size() < _required_kinds.size():
		return
	_finish_level()


## The last leaf is placed, which finishes Autumn the same way the flower finishes
## Spring and the third sort finishes Summer: a pause first, then the completion
## screen.
func _finish_level() -> void:
	# Guarded, so a second signal can never start a second countdown or reshow the
	# banner.
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
	# and inert until now, so nothing can click it before the level is finished, and
	# it only exists once the player could actually leave.
	next_level_button.visible = true
	next_level_button.disabled = false


## Something has been brought to a frame that does not want it. Say so briefly.
##
## The leaf is deliberately left alone: the frame refused it, so the fox is still
## carrying exactly what it was carrying and can walk it to the frame it does fit.
## Nothing here touches the fox or the leaf, and nothing here says which frame that
## is - noticing that is the player's job.
func _on_wrong_leaf(_held_kind: StringName, _frame_kind: StringName) -> void:
	wrong_leaf_label.text = "Wrong frame!"
	wrong_leaf_label.visible = true
	_wrong_leaf_timer = wrong_leaf_notice_time


## The only door out of a finished Autumn level. Level 1 leads to level 2, and
## level 2 leads on to Winter.
func _on_next_level_pressed() -> void:
	if stage == 1:
		get_tree().change_scene_to_file(STAGE_2_SCENE)
	else:
		get_tree().change_scene_to_file(NEXT_SCENE)
