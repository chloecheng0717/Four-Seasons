extends Node2D

## Winter: two penguins cross a long frozen level and finish together at the igloo.
##
## The level is a straight corridor of snow one screen tall, with ice patches that
## cannot be stopped quickly and icicles that come down when a penguin walks under
## them. Two fish are scattered along it, out of reach of a single jump, and the igloo
## at the far right does not count until both are in AND both penguins are standing in
## it at the same time - so the level cannot be finished by one player rushing ahead,
## and cannot be finished without crossing it.
##
## ## Everything here is reused rather than rebuilt
##
## The tiles are the same GroundTile the other three seasons use, the penguins are
## the same Player.tscn (so they move, jump, stack and collide exactly as the cats,
## the dogs and the foxes do, and only the artwork changes), and the completion
## screen is the same Level Complete picture and the same single Next Level button
## the other seasons end with. There is no second button and no second banner.
##
## The genuinely new parts are the ice, the icicles, the fish and the goal.
##
## ## Where the fish sit, and why
##
## Both float with the bottom of their pickup box 198px above the floor, while a jump
## rises only about 134px, so neither can be walked up to and neither can be taken from
## the floor. Fish 1 is a shelf jump followed by a jump made while sliding on ice. Fish 2
## is over the ice run-up past the last shelf, so the only way up to it is for one
## penguin to stand on the other's head and jump. See FISHES for the full reasoning; the
## test suite proves all of it rather than taking this on trust.
##
## ## The world is long on purpose
##
## Like Autumn, Winter is 4800x720 - three and three quarter screens - and is meant
## to be walked. It borrows Autumn's camera exactly: one shared Camera2D that
## follows the middle of the two penguins, is clamped to the world's own edges by
## the usual camera limits, never moves vertically because the level is exactly one
## screen tall, and is rounded to a whole pixel every frame so the 64x56 pixel-art
## tile seams cannot open white lines as the view pans. See _follow_penguins.
##
## ## The map is built so nothing can trap you
##
## There are no holes in the floor and no ledge more than 112px above the one below
## it, which is inside the 128px a jump reaches, so every platform in the level can
## be got to by walking and jumping. That is deliberate: a penguin that fell into a
## pit it could not jump out of would be stuck, and this game has no way to lose and
## respawn, so every fall in Winter has to land somewhere you can walk off again.
## Every platform is therefore also reachable straight off the floor, and no
## platform overlaps an icicle's drop line.
##
## ## A note on names, as in Autumn
##
## Player's artwork fields are still called `cat_texture` and `cat_region` because
## they were named for the cats. Renaming them would mean editing Player.gd,
## Player.tscn and Level.gd, which is not worth it for a cosmetic rename, so the
## penguins are simply assigned to the cat fields. The penguin artwork is
## front/back symmetric, so `flip_h` is invisible on it and harmless.

const TILE_WIDTH := 64
const TILE_HEIGHT := 56

## The world. 4800 x 720 is 75 columns of 64px, three and three quarter screens wide
## and exactly one screen tall, the same shape as Autumn.
const LEVEL_WIDTH := 4800
const LEVEL_HEIGHT := 720
const COLUMN_COUNT := 75

## The floor. Row 10's top edge is y=560, the same surface Spring, Summer and Autumn
## all use, and it is unbroken from wall to wall.
const GROUND_ROW := 10
const GROUND_ROW_COUNT := 3

const WALL_WIDTH := 16
const WALL_COLOR := Color(0.58, 0.7, 0.82)

## A flat cold sky, the same trick Summer and Autumn use: one colour, no background
## art, so nothing behind the level can be mistaken for part of it.
const SKY_COLOR := Color(0.85, 0.9, 0.96)

# [row, first column, how many columns]
## The shelves, read left to right. They only ever use rows 8 and 6 (surfaces 448
## and 336), and 336 to 448 is 112px, which is inside the 128px a jump reaches, so no
## step in the map asks for a jump the players cannot make. Each high shelf shares
## an edge with the low shelf below it, so it can be climbed from the shelf rather
## than only from the floor.
##
## Between them the shelves leave four clear vertical corridors - chamber A, B, C
## and D below - with nothing at any height, which is where the icicles hang. That
## is why the columns are laid out in fours: a platform, then a gap wide enough to
## drop a 104px icicle through without it ever passing through a shelf.
const PLATFORM_ROWS := [
	[8, 2, 4],     # A  ledge          cols  2.. 5   x  128.. 384   surface 448
	[8, 10, 4],    # B  low shelf      cols 10..13   x  640.. 960   surface 448
	[6, 14, 5],    # B  high shelf     cols 14..18   x  896..1216   surface 336
	[8, 23, 4],    # C  low shelf      cols 23..26   x 1472..1728   surface 448
	[6, 27, 5],    # C  high shelf     cols 27..31   x 1728..2048   surface 336
	[8, 36, 4],    # D  low shelf      cols 36..39   x 2304..2560   surface 448
	[6, 40, 5],    # D  high shelf     cols 40..44   x 2560..2880   surface 336
	[8, 49, 4],    # E  low shelf      cols 49..52   x 3136..3392   surface 448
	[6, 53, 5],    # E  high step      cols 53..57   x 3392..3712   surface 336
]

## Snow is the Snow Tile picture cropped to its opaque part. The PNG is 80x88 and
## arrives with transparent padding, so without the crop the tile would be drawn
## mostly air.
##
## The crop is 64x64, taller than the 64x56 collider, and that is deliberate. Every
## tile in the game ends with 8 rows of shaded underside: Spring and Autumn put
## theirs at rows 48..55 and Winter's are at rows 56..63. Trimming the crop to the
## collider's 56 rows would quietly delete that underside, and a ledge would then be
## drawn with no bottom face at all. Keeping all 64 rows lets the underside show, and
## costs nothing in play because the top of the picture still lines up exactly with
## the top of the collider, which is the surface players actually stand on.
const SNOW_TEXTURE := preload("res://assets/Winter/Snow Tile.png")
const SNOW_REGION := Rect2(9, 12, 64, 64)

## Ice is the same idea as snow, cropped to its opaque part out of a 90x90 PNG that
## arrives with transparent padding. What makes a tile ice rather than snow is not the
## artwork alone - it is that the tile is also marked slippery, which is the flag
## Player.gd reads to change how it accelerates.
const ICE_TEXTURE := preload("res://assets/Winter/Ice tile.png")
const ICE_REGION := Rect2(13, 12, 64, 64)

## Where the ice is. Every patch sits on a row players actually walk on - row 10 is
## the floor, rows 8 and 6 are shelf tops - and never on a buried row, so ice is
## always somewhere a penguin's feet can find it.
##
## [row, first column, how many columns]
##
## Most of the ice is on the FLOOR, so the slippery surface is met during ordinary
## walking rather than only by going off a shelf. The elevated patches are kept
## because dropping onto ice is a different problem from running onto it, and both
## are worth having.
##
## Two rules decide where a patch may go. It must not cover an icicle's drop line,
## so no icicle ever has to be crossed on ice you cannot stop on. And the floor is
## left as snow between patches, so the level is never one long slide: the six floor
## patches below are 4, 4, 3, 3, 4 and 4 tiles with 7, 9, 3, 5 and 12 tiles of clear
## snow between them.
const ICE_PATCHES := [
	[10, 12, 4],    # floor, before the B shelves   x  768..1024   surface 560
	[6, 15, 4],     # on the B high shelf          x  960..1216   surface 336
	[10, 23, 4],    # floor, under the C low shelf  x 1472..1728   surface 560
	[8, 24, 3],     # on the C low shelf           x 1536..1728   surface 448
	[6, 29, 3],     # on the C high shelf          x 1856..2048   surface 336
	[10, 36, 3],    # floor, under the D low shelf  x 2304..2496   surface 560
	[8, 37, 3],     # on the D low shelf           x 2368..2560   surface 448
	[10, 42, 3],    # floor, below the D high step  x 2688..2880   surface 560
	[6, 42, 3],     # on the D high shelf          x 2688..2880   surface 336
	[10, 50, 4],    # floor, under the E low shelf  x 3200..3456   surface 560
	[8, 50, 3],     # on the E low shelf           x 3200..3392   surface 448
	[10, 66, 4],    # floor, run-up to igloo       x 4224..4480   surface 560
]


## Is this tile inside one of the ice patches? Read from the same table the level is
## built from, so the picture a penguin sees and the surface it slides on can never
## disagree about where the ice is.
func _is_ice(column: int, row: int) -> bool:
	for patch in ice_patches:
		var patch_row: int = patch[0]
		var first_column: int = patch[1]
		var last_column: int = first_column + int(patch[2]) - 1
		if row == patch_row and column >= first_column and column <= last_column:
			return true
	return false

const PENGUIN1_TEXTURE := preload("res://assets/Winter/Penguin1.png")
const PENGUIN2_TEXTURE := preload("res://assets/Winter/Penguin2.png")

## Both penguins are 23x28 pictures with no transparent padding at all, so the
## region is the whole image. They are drawn at the same 56px tall as a cat, a dog
## or a fox, so the collider and the whole ride system work exactly as they always
## have. 56/28 is exactly 2, so the artwork is doubled cleanly rather than scaled
## to a fraction, which matters for pixel art.
const PENGUIN_REGION := Rect2(0, 0, 23, 28)

const PLAYER_SPAWNS := [
	{
		"label_text": "P1",
		"position": Vector2(140, 559),
		"penguin_texture": PENGUIN1_TEXTURE,
		"penguin_region": PENGUIN_REGION,
		"left_action": &"p1_left",
		"right_action": &"p1_right",
		"jump_action": &"p1_jump",
	},
	{
		"label_text": "P2",
		"position": Vector2(252, 559),
		"penguin_texture": PENGUIN2_TEXTURE,
		"penguin_region": PENGUIN_REGION,
		"left_action": &"p2_left",
		"right_action": &"p2_right",
		"jump_action": &"p2_jump",
	},
]

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const TILE_SCENE := preload("res://scenes/GroundTile.tscn")
const ICICLE_SCENE := preload("res://scenes/Icicle.tscn")
const IGLOO_SCENE := preload("res://scenes/Igloo.tscn")
const FISH_SCENE := preload("res://scenes/Fish.tscn")

## The two icicle pictures, measured: 192x496 and 208x464, both with no transparent
## padding at all, so the region is the whole image.
const ICICLE1_TEXTURE := preload("res://assets/Winter/Icicle1.png")
const ICICLE2_TEXTURE := preload("res://assets/Winter/Icicle2.png")
const ICICLE1_REGION := Rect2(0, 0, 192, 496)
const ICICLE2_REGION := Rect2(0, 0, 208, 464)

## How tall every icicle is drawn. Both are scaled from their own artwork's height,
## so the two come out 96x248 and 104x232 - a uniform half-size, which keeps the
## pixel art on a clean scale instead of stretching it by an arbitrary factor.
const ICICLE_DISPLAY_HEIGHT := 248.0

## Every icicle hangs from the very top of the world, y=0, and drops to the floor.
## There is nothing above row 0 to hang from and the level is one screen tall, so
## hanging from the top edge is both the simplest thing that works and the honest
## reading of the artwork, which is drawn tapering downward from a wide top.
const ICICLE_HANG_Y := 0.0

## The igloo and its goal box.
##
## The igloo picture is 44x38 with no padding, drawn 152px tall - exactly 4x, so the
## artwork lands on clean doubled pixels - which makes it 176px wide. It stands on
## the floor at the far right of the level, past every icicle, on solid snow rather
## than on the last ice patch, so the finish is a walk and not a fight.
##
## There is deliberately no solid collider on the igloo itself, only the goal box.
## A solid dome with a doorway narrower than a 60px penguin would either be
## unenterable or a pocket a penguin could get stuck in, and this game has no way to
## lose and respawn. A goal box you can walk into and stand in cannot do either.
const IGLOO_TEXTURE := preload("res://assets/Winter/Igloo.png")
const IGLOO_REGION := Rect2(0, 0, 44, 38)
const IGLOO_DISPLAY_HEIGHT := 152.0
const IGLOO_POSITION := Vector2(4600.0, 560.0)
## The goal box is 168x140 and its floor is level with the snow, so a penguin's whole
## 60x52 collider fits inside it with room to spare.
const IGLOO_GOAL_SIZE := Vector2(168.0, 140.0)

## The two fish, and the only thing Winter collects.
##
## Spring, Summer and Autumn all put their objective at the goal itself - the pot, the
## bin, the frame. Winter is the first season to put its objective out in the level
## instead, so the igloo does not count until both fish are in. There are exactly two
## and they are a long way apart, so the level cannot be finished without crossing it.
##
## ## Why they are both in the air
##
## A jump is nominally 128px - JUMP_VELOCITY 600 against GRAVITY 1400 - but a jump
## actually rises about 134px, because Godot integrates velocity before it moves the
## body and so overshoots the analytic apex by half a frame's worth. Both fish float
## with the bottom of their pickup box at y=362, which is **198px above the floor** at
## y=560. 198 is well over 134, so **neither fish can be taken from the floor** by
## walking up to it and jumping: both have to be climbed to, which is the whole reason
## they are in the air rather than sitting on a shelf.
##
## A stacked penguin is 52px higher again, which puts its collider right in that band -
## and that is the difference between Fish 2 and Fish 1. The test suite measures all of
## this on the running level rather than trusting the arithmetic here.
##
## ## Fish 1 - climb, and jump while sliding
##
## Sits above the C low shelf, whose surface is y=448, so it is a shelf jump followed
## by a second jump, and the shelf's right half is an ice patch so the second jump is
## made while sliding - a different problem from jumping on snow. It is roughly a third
## of the way across the level, so it is met early.
##
## Standing on that shelf does NOT reach it - a penguin standing on it has their head at
## y=396, well under the box - so it has to be jumped for rather than walked into. There
## is a second way in, stepping off the left edge of the C high shelf above, which the
## test suite pins down as well; that one is no cheaper, because it means climbing to the
## high shelf first. Which of the two a player uses is up to them.
##
## ## Fish 2 - stack, and do it on ice
##
## Sits over the ice run-up in the last stretch before the igloo, more than 500px past
## the nearest shelf. There is nothing at all there to climb to, so the only way up is
## for one penguin to stand on the other's head and jump. That makes it the harder of
## the two, and it has to be solved while sliding on ice.
##
## Neither fish is above an icicle's drop line, so neither one ever asks a player to be
## standing under a falling icicle while they work out how to reach it.
const FISH_TEXTURE := preload("res://assets/Winter/Fish.png")

## The fish artwork, measured: 29x30 with no transparent border at all, so the region
## is the whole image. It is drawn 60px tall, which is exactly 2x, so the pixel art
## lands on clean doubled pixels the way the penguins' does.
const FISH_REGION := Rect2(0, 0, 29, 30)
const FISH_DISPLAY_HEIGHT := 60.0

## The pickup box, 64x64 - one terrain tile, the unit this whole level is built in. It
## is deliberately a little larger than the 58x60 the fish is drawn at: a collectible
## you have to aim at pixel by pixel is not a collectible, it is a trap.
const FISH_PICKUP_SIZE := 64.0

## The two fish, read left to right, as the middle of each one. This table is the only
## place either the level or its tests learn where they are, so the two cannot disagree.
## y=330 puts the bottom of each 64px pickup box at 362; see the note above for why that
## single number is the one that decides whether either fish is reachable from the floor.
const FISHES := [
	Vector2(1560.0, 330.0),      # fish 1: above the C low shelf, over its ice
	Vector2(4300.0, 330.0),      # fish 2: over the ice run-up, stack required
]

## [x, artwork] - the icicles, read left to right. Every x is in one of the four
## clear vertical corridors the map leaves between its shelves, so an icicle's drop
## line never crosses a platform at any height and it never lands on a shelf. Each
## corridor is at least 256px wide and an icicle at most 104px across, so there is
## always a way to walk round one that has already dropped.
const ICICLES := [
	[512.0, 1],      # chamber A   x  384.. 640   hangs over snow
	[1344.0, 2],     # chamber B   x 1216..1472   hangs over snow
	[2176.0, 1],     # chamber C   x 2048..2304   hangs over snow
	[3008.0, 2],     # chamber D   x 2880..3136   hangs over snow
	[3904.0, 1],     # open right, before the igloo stretch
	[4096.0, 2],     # open right, off the ice run-up
]

## Where the Next Level button goes once Winter 2 is finished: the ending, which
## congratulates the players and shows all four seasons. Its Play again button is
## what takes them back to Spring.
const NEXT_SCENE := "res://scenes/Ending.tscn"

## --- Winter 2 -----------------------------------------------------------------
## Winter has two levels, and both use this script. Level 1 is WinterLevel.tscn,
## the long frozen corridor above. Level 2 is WinterLevel2.tscn, which sets
## `stage = 2` and gets the tables below instead: a short level that fits on one
## screen, with the same rules - two icicles, two fish, and the igloo, which only
## counts once both fish are in and both penguins are standing in it. Level 1's
## tables above are left exactly as they were.
##
## The Next Level button of level 1 goes to level 2, and level 2's goes to the
## ending (NEXT_SCENE).
const STAGE_2_SCENE := "res://scenes/WinterLevel2.tscn"

## One screen: 20 columns of 64px.
const STAGE_2_WIDTH := 1280
const STAGE_2_COLUMN_COUNT := 20

## [row, first column, how many columns]. A low shelf (top at y 448) and a high
## shelf (top at y 336) beside it, sharing an edge, in the middle of the screen.
## Nothing hangs over the two icicle corridors (x 400..500 and x 968..1064).
const STAGE_2_PLATFORM_ROWS := [
	[8, 9, 3],     # low shelf     x 576..768   surface 448
	[6, 12, 3],    # high shelf    x 768..960   surface 336
]

## [row, first column, how many columns]. One patch on the floor under the low
## shelf and one on the high shelf, and neither under an icicle.
const STAGE_2_ICE_PATCHES := [
	[10, 9, 3],    # floor, under the low shelf   x 576..768   surface 560
	[6, 13, 2],    # on the high shelf            x 832..960   surface 336
]

## Both fish have the bottom of their box at y 362, 198px above the floor, which
## one jump from the floor (up to 374) cannot reach - the same height as level 1.
## - Fish 1 is above the low shelf (448), whose jump reaches up to 262: climb,
##   then jump.
## - Fish 2 is over open snow near the start, far from any shelf, so the only way
##   up is for one penguin to stand on the other's head and jump (that reaches
##   up to 322).
const STAGE_2_FISHES := [
	Vector2(640.0, 330.0),      # fish 1: above the low shelf
	Vector2(230.0, 330.0),      # fish 2: over the snow near the start, stack required
]

## [x, artwork]. Icicle 1 is between the start and the shelves; icicle 2 is
## between the high shelf and the igloo, so the walk home passes under it.
const STAGE_2_ICICLES := [
	[448.0, 1],
	[1016.0, 1],
]

## On the floor at the right, clear of the second icicle and of the wall.
const STAGE_2_IGLOO_POSITION := Vector2(1170.0, 560.0)

## Which of Winter's two levels this is. WinterLevel.tscn leaves it at 1;
## WinterLevel2.tscn sets it to 2.
@export_range(1, 2) var stage: int = 1

## How long the Level Complete banner waits after the igloo is filled, so the two
## penguins standing in it are visible on their own first. Same as every other
## season.
@export_range(0.0, 5.0, 0.1) var complete_banner_delay: float = 1.5

## The camera sits at this height and never moves vertically, because the level is
## exactly one screen tall.
const CAMERA_Y := 360.0
## How briskly the camera catches up with the penguins. The same number and the same
## easing Autumn uses; the level still does the smoothing itself so that it can round
## the result to a whole pixel. See _follow_penguins.
const CAMERA_SMOOTHING := 8.0
## Players are drawn above the terrain, and the lower penguin is always drawn behind
## the upper one.
const PLAYER_Z := 2

@onready var terrain: Node2D = $Terrain
@onready var walls: Node2D = $Walls
@onready var icicles: Node2D = $Icicles
@onready var fish: Node2D = $Fish
@onready var goals: Node2D = $Goals
@onready var players: Node2D = $Players
@onready var camera: Camera2D = $Camera2D
@onready var level_complete_banner: Sprite2D = $UI/LevelComplete
@onready var next_level_button: TextureButton = $UI/NextLevel

## Counts down to the banner appearing. Negative means nothing is pending.
var _banner_timer: float = -1.0
var _banner_shown: bool = false
## The camera's own smoothed horizontal position, kept unrounded here and rounded
## only when it is handed to the camera. Set for real in _ready, once the penguins
## exist. See _follow_penguins.
var _camera_x: float = 0.0
## Counts down to the reset actually happening, so the player who was hit sees the
## icicle land before the screen jumps. Negative means no reset is pending.
var _reset_timer: float = -1.0
## Every icicle this level built, so a reset can put all of them back on their
## chains and not just the players.
var _icicle_nodes: Array[Icicle] = []
## Every fish this level built, in the same order as FISHES, so a reset can put them
## all back and the tests can talk about fish 1 and fish 2 without relying on the
## order children happened to be added in.
var _fish_nodes: Array[Fish] = []
## Which fish have been collected, held as a set of indexes rather than as a count.
## Area2D can report the same body more than once, and a count incremented that way
## would drift upwards; putting a key in a Dictionary that already holds it does
## nothing. This is Igloo's trick, for the same reason.
var _collected_fish: Dictionary = {}
## Where each player goes back to on a reset, read from the same table the spawns
## came from so the two can never disagree.
var _spawn_positions: Array[Vector2] = []
## The igloo, held here once built rather than as an @onready, because it is built in
## code and not read out of the scene.
var igloo: Igloo = null

## The layout actually built. They start as level 1's tables, and _ready swaps
## in level 2's when `stage` is 2.
var level_width: int = LEVEL_WIDTH
var world_columns: int = COLUMN_COUNT
var platform_rows: Array = PLATFORM_ROWS
var ice_patches: Array = ICE_PATCHES
var fishes: Array = FISHES
var icicle_table: Array = ICICLES
var igloo_position: Vector2 = IGLOO_POSITION


func _ready() -> void:
	# The season chain test drives a real scene change into Winter and then needs to
	# prove it arrived. When run with that user argument, say so and quit instead of
	# building the level - exactly what AutumnLevel does, and what SummerLevel does
	# for Spring's own transition test.
	var args := OS.get_cmdline_user_args()
	if stage == 1 and args.has("--winter-check"):
		print("NEXT LEVEL REACHED WINTER")
		get_tree().quit(0)
		return
	# And the same again for arriving in Winter 2 from Winter 1.
	if stage == 2 and args.has("--winter2-check"):
		print("NEXT LEVEL REACHED WINTER 2")
		get_tree().quit(0)
		return

	if stage == 2:
		level_width = STAGE_2_WIDTH
		world_columns = STAGE_2_COLUMN_COUNT
		platform_rows = STAGE_2_PLATFORM_ROWS
		ice_patches = STAGE_2_ICE_PATCHES
		fishes = STAGE_2_FISHES
		icicle_table = STAGE_2_ICICLES
		igloo_position = STAGE_2_IGLOO_POSITION
	# The camera's limits are the world's own edges. Level 2 is exactly one
	# screen wide, so its camera simply never moves.
	camera.limit_right = level_width

	# The Next Level button belongs to the completion screen and nowhere else. The
	# scene hides it and this hides it again, for the same reason as in the other
	# three seasons: a disabled button still draws, so `visible` is what keeps it
	# off the screen, and an editor save that loses the scene's `visible = false`
	# cannot leave it sitting in the level before the level is finished.
	next_level_button.visible = false
	next_level_button.disabled = true
	next_level_button.pressed.connect(_on_next_level_pressed)

	_build_ground()
	_build_platforms()
	_build_walls()
	_build_players()
	_build_icicles()
	_build_fish()
	_build_igloo()

	# Put the camera on the penguins straight away, so the level does not open with
	# the view sweeping in from the middle of an empty map.
	_camera_x = _penguins_centre().x
	camera.global_position = Vector2(roundf(_camera_x), CAMERA_Y)


## The middle of the two penguins. One shared camera follows this, which is what
## makes a co-op level readable: walk together and the view is steady, and split up
## and it settles between them instead of leaving one player off the edge.
func _penguins_centre() -> Vector2:
	var sum := Vector2.ZERO
	var count := 0
	for child in players.get_children():
		if child is Player:
			sum += (child as Player).global_position
			count += 1
	if count == 0:
		return Vector2(level_width * 0.5, CAMERA_Y)
	return sum / float(count)


## One unbroken floor across the whole map, with no holes in it at all. A penguin
## that fell into a pit it could not jump out of would be stuck, and this game has
## no way to lose and respawn, so falling always means landing somewhere you can
## walk off again.
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


## Every snow tile is the same 64x56 picture, cropped to its opaque part and drawn
## from the tile's own top left corner, exactly the way Spring's ground tile,
## Summer's sand tile and Autumn's leaf tile are drawn. A tile that falls inside an
## ice patch gets the ice picture instead and is marked slippery - the same GroundTile
## scene, the same collider, the same 64x56 grid, just a different surface. That is
## why there is no second set of ice nodes overlapping the snow and no chance of the
## two disagreeing about where the surface is.
func _add_tile(column: int, row: int, buried: bool) -> void:
	var tile := TILE_SCENE.instantiate() as GroundTile
	tile.buried = buried
	if _is_ice(column, row):
		tile.surface_texture = ICE_TEXTURE
		tile.surface_region = ICE_REGION
		tile.slippery = true
	else:
		tile.surface_texture = SNOW_TEXTURE
		tile.surface_region = SNOW_REGION
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


## The penguins are the same Player scene as the cats, the dogs and the foxes, with
## their own artwork, their own controls and their own spawn. Nothing else about
## them differs, so they move, jump, stack and collide exactly as the others do.
##
## The spawn positions are also kept, in the same order, so a reset puts each
## penguin back on its OWN spawn rather than on whichever one is first in the list.
func _build_players() -> void:
	for spawn in PLAYER_SPAWNS:
		var player := PLAYER_SCENE.instantiate() as Player
		player.label_text = spawn["label_text"]
		player.left_action = spawn["left_action"]
		player.right_action = spawn["right_action"]
		player.jump_action = spawn["jump_action"]
		player.cat_texture = spawn["penguin_texture"]
		player.cat_region = spawn["penguin_region"]
		player.position = spawn["position"]
		players.add_child(player)
		_spawn_positions.append(spawn["position"])


## The icicles are instances of one Icicle scene and differ only in which of the two
## pictures they carry and where they hang. Nothing here decides when one falls or
## what a hit does - the icicle detects its own player through its own Area2D and
## reports it, and this only listens.
func _build_icicles() -> void:
	for entry in icicle_table:
		var icicle := ICICLE_SCENE.instantiate() as Icicle
		if int(entry[1]) == 1:
			icicle.icicle_texture = ICICLE1_TEXTURE
			icicle.art_region = ICICLE1_REGION
		else:
			icicle.icicle_texture = ICICLE2_TEXTURE
			icicle.art_region = ICICLE2_REGION
		icicle.display_height = ICICLE_DISPLAY_HEIGHT
		icicle.ground_y = GROUND_ROW * TILE_HEIGHT
		icicle.position = Vector2(entry[0], ICICLE_HANG_Y)
		icicle.player_hit.connect(_on_icicle_hit)
		icicles.add_child(icicle)
		_icicle_nodes.append(icicle)


## The igloo, and the only way Winter can be finished. One instance of the Igloo
## scene, told its artwork, how big to draw it and how big its goal box is.
##
## It is built here rather than placed in WinterLevel.tscn on purpose. A node that
## lives in the scene file is readied BEFORE the level's own _ready runs, so an
## igloo sitting in the scene would already have worked out its own scale - from a
## texture it had not been given yet - before a single line of this function had
## run. Instantiating it here means every export is filled in before it is ever
## added to the tree, which is the same order Autumn's leaves and frames use.
func _build_igloo() -> void:
	igloo = IGLOO_SCENE.instantiate() as Igloo
	igloo.igloo_texture = IGLOO_TEXTURE
	igloo.art_region = IGLOO_REGION
	igloo.display_height = IGLOO_DISPLAY_HEIGHT
	igloo.goal_size = IGLOO_GOAL_SIZE
	igloo.position = igloo_position
	igloo.penguins_changed.connect(_on_penguins_at_igloo)
	goals.add_child(igloo)


## How many penguins are in the igloo. This counts the level's own players, never a
## fixed number, so the goal cannot be met by one penguin standing in the box twice.
func _required_penguins() -> int:
	var count := 0
	for child in players.get_children():
		if child is Player:
			count += 1
	return count


## How many fish have to be collected. Read from the level's own table, so the goal and
## the fish can never disagree about how many of them there are.
func _required_fish() -> int:
	return fishes.size()


## The two fish, and the reason the igloo does not count yet.
##
## Built here rather than placed in WinterLevel.tscn, for the same reason the igloo is:
## a node that lives in the scene file is readied BEFORE this level's own _ready runs, so
## it would already have worked out its own scale from a texture it had not been given.
## Every export is filled in before the fish is ever added to the tree.
##
## The fish detect a penguin themselves and report it, and this only listens - exactly
## as it does for the icicles and the igloo.
func _build_fish() -> void:
	for index in fishes.size():
		var one := FISH_SCENE.instantiate() as Fish
		one.fish_texture = FISH_TEXTURE
		one.art_region = FISH_REGION
		one.display_height = FISH_DISPLAY_HEIGHT
		one.pickup_size = FISH_PICKUP_SIZE
		one.fish_index = index
		one.position = fishes[index]
		one.collected.connect(_on_fish_collected)
		fish.add_child(one)
		_fish_nodes.append(one)


## A fish was collected. Note which one, then ask the igloo the same question it asks
## every time somebody walks in or out of it.
##
## Asking again is not decoration. The igloo only speaks when a penguin enters or leaves
## it, so if both penguins were already standing in the igloo waiting and the last fish
## was collected afterwards, nothing would ever speak again and the level would sit
## there looking finished and not being finished for good.
func _on_fish_collected(index: int) -> void:
	_collected_fish[index] = true
	if _collected_fish.size() < _required_fish():
		return
	if igloo == null:
		return
	_on_penguins_at_igloo(igloo.penguin_count())


## Somebody entered or left the igloo. Winter is finished when the box holds every
## player in the level AND both fish have been collected. The penguin half is what stops
## a single player sprinting to the end and finishing a two-player level on their own;
## the fish half is what stops the level being a straight walk to the igloo.
##
## The banner can only ever appear once: the countdown is guarded, and a player who
## then walks back out cannot take it away again.
func _on_penguins_at_igloo(count: int) -> void:
	if count < _required_penguins():
		return
	if _collected_fish.size() < _required_fish():
		return
	_finish_level()


## The last penguin is in. Winter finishes the same way the flower finishes Spring
## and the last sort finishes Summer: a pause first, then the completion screen.
func _finish_level() -> void:
	# Guarded, so a second signal can never start a second countdown or reshow the
	# banner.
	if _banner_shown or _banner_timer >= 0.0:
		return

	if complete_banner_delay <= 0.0:
		_reveal_banner()
		return

	_banner_timer = complete_banner_delay


## An icicle touched a penguin. Both penguins go back to the start together, never
## one at a time, so the level can never be left in a state where one player is back
## at the start and the other is still out past the icicles.
##
## Guarded, and deliberately not cancelled by anything: once an icicle has hit
## somebody, the reset is going to happen, and a second icicle landing in the same
## moment cannot start a second countdown or cut the pause short.
func _on_icicle_hit() -> void:
	if _reset_timer >= 0.0:
		return
	_reset_timer = RESET_PAUSE


## The pause before the reset. Enough to see the icicle finish falling, short enough
## that being hit does not feel like a punishment.
const RESET_PAUSE := 0.35


## Sends both penguins back to their own spawn and puts every icicle back on its
## chain. Both halves matter: resetting only the players would leave spent icicles
## hanging for the rest of the attempt, and resetting only the icicles would leave
## somebody standing past a hazard that is no longer there.
##
## The order is deliberate and is the whole reason this function is written the way
## it is. Putting an icicle back re-arms the trigger area under it, and Godot has
## an area report every body already overlapping it at the moment monitoring is
## switched back on. So the penguins have to be moved BEFORE the icicles are
## re-armed, or the re-armed trigger finds the penguin still standing where it was
## hit - the body the physics server has not yet been told about - and starts that
## same icicle falling again on the very frame the level was trying to reset it.
func _reset_winter() -> void:
	_reset_timer = -1.0

	# The penguins go first, each to its OWN spawn rather than to whichever one is
	# first in the list.
	var index := 0
	for child in players.get_children():
		if child is Player:
			if index < _spawn_positions.size():
				(child as Player).reset_to_position(_spawn_positions[index])
			index += 1

	# Only now, with nobody under them, do the icicles go back on their chains.
	for icicle in _icicle_nodes:
		icicle.reset()

	# And the igloo forgets them too, so a penguin that was standing in the goal box
	# cannot be counted as still being there after it has been teleported away.
	igloo.reset()

	# The fish go back on the ice as well, and for the same reason: being hit by an
	# icicle is this attempt ending, not a fish being lost for good. If the fish did
	# not return, one player walking under a falling icicle could cost the other
	# player work they had already done, and there is no way in this game to get a
	# collectible back once it has gone. This is why the Fish scene is never freed,
	# only hidden - see Fish.gd.
	for one in _fish_nodes:
		one.reset()
	_collected_fish.clear()

	# The camera is put straight back on the penguins too, rather than left to pan
	# the whole length of the level back at smoothing speed, which would mean
	# playing several seconds of the level from the wrong end after every reset.
	_camera_x = _penguins_centre().x
	camera.global_position = Vector2(roundf(_camera_x), CAMERA_Y)


## A penguin that somehow ended up below the world goes back to the start too. The
## map has no holes in it, so this should never fire; it is here because a level
## that cannot lose must still have an answer for a player that somehow does, and a
## penguin stuck under the map would be a soft-lock.
func _rescue_fallen() -> void:
	for child in players.get_children():
		var player := child as Player
		if player != null and player.global_position.y > LEVEL_HEIGHT + 200.0:
			_reset_winter()
			return


## Keeps the lower penguin drawn behind the upper one, runs the countdown that holds
## the Level Complete banner back, runs the countdown that sends a hit penguin back
## to the start, and moves the one shared camera onto the middle of the two penguins.
func _process(delta: float) -> void:
	if _banner_timer >= 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0:
			_banner_timer = -1.0
			_reveal_banner()

	if _reset_timer >= 0.0:
		_reset_timer -= delta
		if _reset_timer <= 0.0:
			_reset_winter()

	_rescue_fallen()

	var ordered: Array[Node2D] = []
	for child in players.get_children():
		if child is Player:
			ordered.append(child)

	ordered.sort_custom(
		func(a: Node2D, b: Node2D) -> bool: return a.position.y > b.position.y
	)

	for index in ordered.size():
		ordered[index].z_index = PLAYER_Z + index

	_follow_penguins(delta)


## The one shared camera, moved onto the middle of the two penguins and kept on
## whole pixels.
##
## The engine's own position smoothing is deliberately not used, which is the whole
## reason for this function. That smoothing interpolates continuously, so during
## ordinary walking the camera sits on a fraction of a pixel for nearly every
## frame. Every tile in this level is a 64x56 pixel-art picture drawn 1:1 at
## whole-pixel positions, so a fractional camera puts each seam between two tiles at
## a fractional screen position and the rasteriser fails to cover one column of
## pixels along it, exposing the background behind: thin white lines that come and go
## as the camera moves. Rounding to a whole pixel removes the seams without touching
## a single tile.
##
## The easing is the engine's own, unchanged - the same exponential approach with the
## same CAMERA_SMOOTHING Autumn uses - so the camera still travels the same distance
## over the same time and walking still reads as a pan.
func _follow_penguins(delta: float) -> void:
	var target_x: float = _penguins_centre().x
	var weight: float = 1.0 - exp(-CAMERA_SMOOTHING * delta)
	_camera_x = lerpf(_camera_x, target_x, weight)
	camera.global_position = Vector2(roundf(_camera_x), CAMERA_Y)


func _reveal_banner() -> void:
	_banner_shown = true
	level_complete_banner.visible = true
	# The Next Level button is part of the same completion screen. It stays hidden
	# and inert until now, so nothing can click it before the level is finished, and
	# it only exists once the player could actually leave.
	next_level_button.visible = true
	next_level_button.disabled = false


## The only door out of a finished Winter level. Level 1 leads to level 2, and
## level 2 leads to the ending.
func _on_next_level_pressed() -> void:
	if stage == 1:
		get_tree().change_scene_to_file(STAGE_2_SCENE)
	else:
		get_tree().change_scene_to_file(NEXT_SCENE)