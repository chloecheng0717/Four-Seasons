class_name TitleScreen
extends Node2D

## The title screen (wireframe A): the game's name, a season badge, and Play,
## How to Play, Settings, Quit.
##
## Behind the menu the four seasons take turns. Each season is one "scene" -
## sky, ground, its two animals and a few of its own props - built in code from
## the same pictures and crops the levels use, so nothing new had to be drawn.
## Every SEASON_TIME seconds the next one fades in over the last, in the order
## the levels are played, and the menu's colours change with it.

const SPRING_SCENE := "res://scenes/Level.tscn"
## Play goes here first: the short story intro, which then starts Spring.
const INTRO_SCENE := "res://scenes/StoryIntro.tscn"

const SEASON_TIME := 5.0
const FADE_TIME := 1.2
const GROUND_Y := 560.0
const TILE_WIDTH := 64
const COLUMNS := 20

## The ground tile of each season and its crop, copied from the levels
## (Level.tscn's GroundTile, SummerLevel.SAND_REGION, AutumnLevel.TILE_REGION,
## WinterLevel.SNOW_REGION / ICE_REGION). Winter's crop is 64 tall, not 56: its
## last 8 rows are the tile's shaded underside (see PROGRESS.md §2.4).
const TILES := {
	"spring": {"texture": preload("res://assets/Spring/BasicTile.png"), "region": Rect2(18, 13, 64, 56)},
	"summer": {"texture": preload("res://assets/Summer/Sand.png"), "region": Rect2(15, 13, 64, 56)},
	"autumn": {"texture": preload("res://assets/Autumn/Autumn Tile.png"), "region": Rect2(16, 13, 64, 56)},
	"winter": {"texture": preload("res://assets/Winter/Snow Tile.png"), "region": Rect2(9, 12, 64, 64)},
}
const ICE_TEXTURE := preload("res://assets/Winter/Ice tile.png")
const ICE_REGION := Rect2(13, 12, 64, 64)
const ICE_COLUMNS := [13, 14, 15]

## The two animals of each season, with the crop each level uses for them, and
## how tall to draw them here. All of them are drawn facing LEFT in their PNGs,
## so flip_h turns one round to face the other.
const ANIMALS := {
	"spring": [
		{"texture": preload("res://assets/Spring/Cat1.png"), "region": Rect2(11, 16, 129, 96), "height": 96.0},
		{"texture": preload("res://assets/Spring/Cat2.png"), "region": Rect2(9, 15, 128, 96), "height": 96.0},
	],
	"summer": [
		{"texture": preload("res://assets/Summer/Dog1.png"), "region": Rect2(8, 24, 240, 208), "height": 104.0},
		{"texture": preload("res://assets/Summer/Dog2.png"), "region": Rect2(8, 24, 240, 208), "height": 104.0},
	],
	"autumn": [
		{"texture": preload("res://assets/Autumn/Fox1.png"), "region": Rect2(16, 40, 216, 168), "height": 105.0},
		{"texture": preload("res://assets/Autumn/Fox2.png"), "region": Rect2(16, 40, 216, 168), "height": 105.0},
	],
	"winter": [
		{"texture": preload("res://assets/Winter/Penguin1.png"), "region": Rect2(0, 0, 23, 28), "height": 112.0},
		{"texture": preload("res://assets/Winter/Penguin2.png"), "region": Rect2(0, 0, 23, 28), "height": 112.0},
	],
}
## Where the two animals stand: on the left of the menu, facing each other.
const ANIMAL_X := [190.0, 330.0]

## Each season's own things, standing on the ground (or hanging from the top)
## on the right-hand side of the menu.
const PROPS := {
	"spring": [
		{"texture": preload("res://assets/Spring/Pot_Flower.png"), "region": Rect2(7, 8, 104, 176), "height": 200.0, "x": 1040.0},
		{"texture": preload("res://assets/Spring/Soil.png"), "region": Rect2(32, 64, 184, 144), "height": 64.0, "x": 1180.0},
		{"texture": preload("res://assets/Spring/Seeds.png"), "region": Rect2(56, 56, 80, 96), "height": 56.0, "x": 900.0},
	],
	"summer": [
		{"texture": preload("res://assets/Summer/Paper Bin.png"), "region": Rect2(40, 40, 160, 192), "height": 120.0, "x": 920.0},
		{"texture": preload("res://assets/Summer/Plastic Bin.png"), "region": Rect2(48, 32, 160, 192), "height": 120.0, "x": 1050.0},
		{"texture": preload("res://assets/Summer/Glass bin.png"), "region": Rect2(48, 32, 160, 192), "height": 120.0, "x": 1180.0},
	],
	"autumn": [
		{"texture": preload("res://assets/Autumn/Autumn_Tree.png"), "region": Rect2(0, 0, 27, 36), "height": 180.0, "x": 70.0},
		{"texture": preload("res://assets/Autumn/Autumn_Tree.png"), "region": Rect2(0, 0, 27, 36), "height": 216.0, "x": 1010.0},
		{"texture": preload("res://assets/Autumn/Autumn_Tree.png"), "region": Rect2(0, 0, 27, 36), "height": 180.0, "x": 1180.0},
	],
	"winter": [
		{"texture": preload("res://assets/Winter/Igloo.png"), "region": Rect2(0, 0, 44, 38), "height": 152.0, "x": 1080.0},
		{"texture": preload("res://assets/Winter/Fish.png"), "region": Rect2(0, 0, 29, 30), "height": 60.0, "x": 910.0},
	],
}
const ICICLE_TEXTURE := preload("res://assets/Winter/Icicle1.png")
const ICICLE_REGION := Rect2(0, 0, 192, 496)

const SEA_TEXTURE := preload("res://assets/Summer/Water.png")
const SEA_REGION := Rect2(13, 13, 64, 56)
const SEA_ROWS := 3

const LEAF_TEXTURES := [
	{"texture": preload("res://assets/Autumn/Leaf1.png"), "region": Rect2(2, 6, 25, 24)},
	{"texture": preload("res://assets/Autumn/Leaf2.png"), "region": Rect2(2, 2, 25, 25)},
	{"texture": preload("res://assets/Autumn/Leaf3.png"), "region": Rect2(4, 2, 23, 28)},
	{"texture": preload("res://assets/Autumn/Leaf4.png"), "region": Rect2(3, 2, 25, 28)},
]
const LEAF_COUNT := 10
const SNOW_COUNT := 60

const HOW_TO_PLAY_TEXT := """Two players share one keyboard.
P1:  A / D to move,  Space to jump
P2:  Left / Right to move,  Enter to jump

Stand on your friend's head to reach high places.
Walk into something to pick it up, then carry it to where it belongs.

Spring - grow a flower: soil, then seeds, then water.
Summer - put each piece of rubbish in the matching bin.
Autumn - carry each leaf to the frame with the same outline.
Winter - dodge the icicles, collect both fish, then go into the igloo together.

Press Esc in any season to pause."""

@onready var seasons_holder: Node2D = $Seasons
@onready var ui_root: Control = $UI/Root
@onready var badge: Label = $UI/Root/Menu/Badge
@onready var play_button: Button = $UI/Root/Menu/Buttons/Play
@onready var how_button: Button = $UI/Root/Menu/Buttons/HowToPlay
@onready var settings_button: Button = $UI/Root/Menu/Buttons/Settings
@onready var quit_button: Button = $UI/Root/Menu/Buttons/Quit
@onready var buttons_box: Control = $UI/Root/Menu/Buttons
@onready var how_panel: Control = $UI/Root/HowToPlay
@onready var how_text: Label = $UI/Root/HowToPlay/Center/Panel/Margin/Rows/Text
@onready var how_back: Button = $UI/Root/HowToPlay/Center/Panel/Margin/Rows/Back
@onready var settings_menu: SettingsMenu = $UI/Root/Settings

## The season now showing, and the four season scenes by name.
var season := "spring"
var season_layers := {}
var _season_timer := SEASON_TIME
## Falling things: each entry is {"node", "speed", "sway", "phase", "base_x"}.
var _fallers: Array[Dictionary] = []
var _time := 0.0


func _ready() -> void:
	GameSettings.ensure_loaded()
	GameSettings.apply_audio()
	GameSettings.apply_fullscreen()

	for each_season in SeasonTheme.ORDER:
		var layer := build_season(each_season, _fallers)
		layer.modulate.a = 1.0 if each_season == season else 0.0
		seasons_holder.add_child(layer)
		season_layers[each_season] = layer

	how_text.text = HOW_TO_PLAY_TEXT
	how_panel.visible = false
	settings_menu.visible = false
	play_button.pressed.connect(_on_play_pressed)
	how_button.pressed.connect(_open_how_to_play)
	how_back.pressed.connect(_close_how_to_play)
	settings_button.pressed.connect(_open_settings)
	settings_menu.closed.connect(_on_settings_closed)
	quit_button.pressed.connect(_on_quit_pressed)

	_add_button_decorations()
	_apply_season_to_menu()
	GameSettings.apply_text_scale(self)
	play_button.grab_focus()


func _process(delta: float) -> void:
	_time += delta
	move_fallers(_fallers, _time, delta)

	_season_timer -= delta
	if _season_timer <= 0.0:
		_season_timer = SEASON_TIME
		show_season(SeasonTheme.next_season(season))


## Fades the given season in over the one showing now.
func show_season(next: String) -> void:
	# Already showing: nothing to fade. Fading a layer in over itself would end by
	# hiding it, and leave the title with no background at all.
	if next == season:
		return
	var old_layer: Node2D = season_layers[season]
	var new_layer: Node2D = season_layers[next]
	season = next
	seasons_holder.move_child(new_layer, -1)  # Draw it on top while it fades in.
	new_layer.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(new_layer, "modulate:a", 1.0, FADE_TIME)
	fade.tween_callback(func() -> void: old_layer.modulate.a = 0.0)
	_apply_season_to_menu()


## The menu wears the colours of the season behind it. An open Settings panel
## keeps the colours it was opened with, so it does not flicker while in use.
func _apply_season_to_menu() -> void:
	ui_root.theme = SeasonTheme.make_theme(season)
	badge.text = SeasonTheme.badge_text(season)
	_update_button_decorations()


## Puts two empty picture holders on every menu button, one on each top corner.
## _update_button_decorations() fills them with the season's pictures. They ignore
## the mouse, so clicking on one still clicks the button underneath.
func _add_button_decorations() -> void:
	for button in buttons_box.get_children():
		for corner in ["DecorLeft", "DecorRight"]:
			var picture := TextureRect.new()
			picture.name = corner
			picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			picture.stretch_mode = TextureRect.STRETCH_KEEP
			if corner == "DecorRight":
				# Pinned to the button's right-hand edge, whatever its width.
				picture.anchor_left = 1.0
				picture.anchor_right = 1.0
			button.add_child(picture)


## Gives every button the current season's two pictures, each one centred on its
## corner so it sits half on the button and half off it.
func _update_button_decorations() -> void:
	var pictures := SeasonTheme.button_decorations(season)
	for button in buttons_box.get_children():
		for index in 2:
			var picture := button.get_node(["DecorLeft", "DecorRight"][index]) as TextureRect
			var texture: ImageTexture = pictures[index]
			var size := texture.get_size()
			picture.texture = texture
			picture.offset_left = -size.x * 0.5
			picture.offset_top = -size.y * 0.5
			picture.offset_right = size.x * 0.5
			picture.offset_bottom = size.y * 0.5


# --- Buttons ---------------------------------------------------------------

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(INTRO_SCENE)


func _open_how_to_play() -> void:
	how_panel.visible = true
	how_back.grab_focus()


func _close_how_to_play() -> void:
	how_panel.visible = false
	how_button.grab_focus()


func _open_settings() -> void:
	settings_menu.open(season)


func _on_settings_closed() -> void:
	settings_button.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().quit()


## Esc closes whichever panel is open.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if settings_menu.visible:
		settings_menu.close()
		get_viewport().set_input_as_handled()
	elif how_panel.visible:
		_close_how_to_play()
		get_viewport().set_input_as_handled()


# --- Building one season's background -------------------------------------
#
# These are static, so the story intro and the ending can build exactly the same
# season backgrounds without a copy of this code: they call
# `TitleScreen.build_season("autumn", their_fallers)` and, every frame,
# `TitleScreen.move_fallers(their_fallers, time, delta)`. `fallers` is the list
# the falling leaves and snowflakes are added to, owned by whoever is drawing.

static func build_season(for_season: String, fallers: Array[Dictionary]) -> Node2D:
	var layer := Node2D.new()
	layer.name = for_season.capitalize()

	var sky := ColorRect.new()
	sky.color = SeasonTheme.SKY[for_season]
	sky.size = Vector2(COLUMNS * TILE_WIDTH, 720)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(sky)

	if for_season == "summer":
		_add_sea(layer)
	if for_season == "winter":
		_add_icicle(layer)

	for prop in PROPS[for_season]:
		layer.add_child(_standing_sprite(prop["texture"], prop["region"], prop["height"],
			Vector2(prop["x"], GROUND_Y)))

	_add_ground(layer, for_season)

	for index in 2:
		var animal: Dictionary = ANIMALS[for_season][index]
		var sprite := _standing_sprite(animal["texture"], animal["region"], animal["height"],
			Vector2(ANIMAL_X[index], GROUND_Y))
		# The left animal turns round to face its friend.
		sprite.flip_h = index == 0
		layer.add_child(sprite)
		_start_hop(sprite, index * 0.45)

	if for_season == "autumn":
		_add_falling_leaves(layer, fallers)
	if for_season == "winter":
		_add_falling_snow(layer, fallers)

	return layer


## All four seasons at once, side by side: four 320px columns, each a window onto
## one whole season scene, shifted so the window lands on its two animals (they
## stand at x 190 and 330). Used by the story intro and the ending.
static func build_four_seasons(fallers: Array[Dictionary]) -> Node2D:
	var holder := Node2D.new()
	for index in SeasonTheme.ORDER.size():
		var window := Control.new()
		window.clip_contents = true
		window.mouse_filter = Control.MOUSE_FILTER_IGNORE
		window.position = Vector2(index * 320.0, 0.0)
		window.size = Vector2(320.0, 720.0)
		var scene := build_season(SeasonTheme.ORDER[index], fallers)
		scene.position.x = -100.0
		window.add_child(scene)
		holder.add_child(window)
	return holder


static func _add_ground(layer: Node2D, for_season: String) -> void:
	var tile: Dictionary = TILES[for_season]
	var region: Rect2 = tile["region"]
	for row in 3:
		for column in COLUMNS:
			var sprite := Sprite2D.new()
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.centered = false
			sprite.region_enabled = true
			sprite.texture = tile["texture"]
			sprite.region_rect = region
			if for_season == "winter" and row == 0 and column in ICE_COLUMNS:
				sprite.texture = ICE_TEXTURE
				sprite.region_rect = ICE_REGION
			# Rows below the top are flipped, as the levels do, so the ground
			# reads as one solid block.
			sprite.flip_v = row > 0
			sprite.position = Vector2(column * TILE_WIDTH, GROUND_Y + row * 56)
			layer.add_child(sprite)


static func _add_sea(layer: Node2D) -> void:
	for row in SEA_ROWS:
		for column in COLUMNS:
			var sprite := Sprite2D.new()
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.centered = false
			sprite.region_enabled = true
			sprite.texture = SEA_TEXTURE
			sprite.region_rect = SEA_REGION
			sprite.position = Vector2(column * TILE_WIDTH, GROUND_Y - (SEA_ROWS - row) * 56)
			layer.add_child(sprite)


static func _add_icicle(layer: Node2D) -> void:
	var icicle := Sprite2D.new()
	icicle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icicle.texture = ICICLE_TEXTURE
	icicle.region_enabled = true
	icicle.region_rect = ICICLE_REGION
	icicle.centered = false
	var scale_factor := 220.0 / ICICLE_REGION.size.y
	icicle.scale = Vector2(scale_factor, scale_factor)
	icicle.position = Vector2(1200 - ICICLE_REGION.size.x * scale_factor * 0.5, 0)
	layer.add_child(icicle)


static func _add_falling_leaves(layer: Node2D, fallers: Array[Dictionary]) -> void:
	for index in LEAF_COUNT:
		var leaf: Dictionary = LEAF_TEXTURES[index % LEAF_TEXTURES.size()]
		var sprite := _sprite(leaf["texture"], leaf["region"], 36.0)
		layer.add_child(sprite)
		add_faller(fallers, sprite, randf_range(40.0, 70.0), 30.0)


static func _add_falling_snow(layer: Node2D, fallers: Array[Dictionary]) -> void:
	for index in SNOW_COUNT:
		var flake := ColorRect.new()
		var size := randf_range(4.0, 8.0)
		flake.size = Vector2(size, size)
		flake.color = Color(1, 1, 1, 0.9)
		flake.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(flake)
		add_faller(fallers, flake, randf_range(30.0, 70.0), 12.0)


## Something that drifts down, sways side to side, and starts again at the top.
static func add_faller(fallers: Array[Dictionary], node: CanvasItem, speed: float, sway: float) -> void:
	var start_x := randf_range(0.0, COLUMNS * TILE_WIDTH)
	node.set("position", Vector2(start_x, randf_range(-40.0, GROUND_Y)))
	fallers.append({
		"node": node, "speed": speed, "sway": sway,
		"phase": randf_range(0.0, TAU), "base_x": start_x,
	})


static func move_fallers(fallers: Array[Dictionary], time: float, delta: float) -> void:
	for faller in fallers:
		var node: CanvasItem = faller["node"]
		var spot: Vector2 = node.get("position")
		spot.y += faller["speed"] * delta
		if spot.y > GROUND_Y:
			spot.y = -40.0
			faller["base_x"] = randf_range(0.0, COLUMNS * TILE_WIDTH)
		spot.x = faller["base_x"] + sin(time * 1.5 + faller["phase"]) * faller["sway"]
		node.set("position", spot)
		if node is Sprite2D:
			(node as Sprite2D).rotation = sin(time * 2.0 + faller["phase"]) * 0.5


## A small happy hop, over and over, so the animals feel alive.
static func _start_hop(sprite: Sprite2D, delay: float) -> void:
	var ground := sprite.position.y
	var hop := sprite.create_tween().set_loops()
	hop.tween_interval(delay + 1.2)
	hop.tween_property(sprite, "position:y", ground - 18.0, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop.tween_property(sprite, "position:y", ground, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	hop.tween_interval(1.2 - delay)


## A picture cropped to its art and scaled evenly to a height, centred on its
## node.
static func _sprite(texture: Texture2D, region: Rect2, height: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = region
	var scale_factor := height / region.size.y
	sprite.scale = Vector2(scale_factor, scale_factor)
	return sprite


## The same, but with its bottom edge on `feet`, the way the levels stand
## players and bins on the ground.
static func _standing_sprite(texture: Texture2D, region: Rect2, height: float, feet: Vector2) -> Sprite2D:
	var sprite := _sprite(texture, region, height)
	sprite.offset = Vector2(0, -region.size.y * 0.5)
	sprite.position = feet
	return sprite
