class_name StoryIntro
extends Node2D

## The story intro, shown after Play on the title screen and before Spring 1.
##
## Five short pages tell the story the game is built on (proposal §6.1): four
## groups of animal friends look after their valley, one season each, but this
## year the wheel of the year has stopped, and only the friends working together
## can get it turning again. The ending closes the same story ("The wheel of the
## year is turning again").
##
## Each page has a picture behind it, made from the same season scenes the title
## screen uses (TitleScreen.build_season / build_four_seasons), so nothing new had
## to be drawn. Next (the highlighted button, and the one the keyboard is on) turns
## the page; the last page's button is "Let's go!" and starts Spring 1. Skip, or
## Esc, starts Spring 1 straight away.

const SPRING_SCENE := "res://scenes/Level.tscn"

## How long one picture takes to fade into the next.
const FADE_TIME := 0.6

## "spring": the spring scene; "four": all four seasons side by side; "stuck":
## the same four, faded grey, for the page where the year has stopped.
const PAGES := [
	{
		"view": "spring",
		"season": "spring",
		"text": "In a little valley, the year turns like a wheel: Spring, Summer, Autumn, Winter, and round again.",
	},
	{
		"view": "four",
		"season": "summer",
		"text": "Each season has its own friends. The cats look after Spring, the dogs Summer, the foxes Autumn, and the penguins Winter.",
	},
	{
		"view": "stuck",
		"season": "autumn",
		"text": "But this year the wheel has stopped. The garden is bare, the beach is covered in rubbish, the leaves are scattered, and the ice is cracking.",
	},
	{
		"view": "four",
		"season": "winter",
		"text": "A season can only pass on to the next when its friends have put their part of the world right. And nobody can do it alone.",
	},
	{
		"view": "spring",
		"season": "spring",
		"text": "Two friends, one keyboard. Help each other, stand on each other's heads, and get the year turning again!",
	},
]

## The colour the "stuck" picture is faded to.
const STUCK_TINT := Color(0.55, 0.55, 0.6)

@onready var views_holder: Node2D = $Views
@onready var ui_root: Control = $UI/Root
@onready var text_label: Label = $UI/Root/Panel/Margin/Rows/Text
@onready var controls_label: Label = $UI/Root/Panel/Margin/Rows/Controls
@onready var page_label: Label = $UI/Root/Panel/Margin/Rows/Bottom/Page
@onready var skip_button: Button = $UI/Root/Panel/Margin/Rows/Bottom/Skip
@onready var next_button: Button = $UI/Root/Panel/Margin/Rows/Bottom/Next

## Which page is showing, counting from 0.
var page := 0
## The pictures, by name ("spring", "four", "stuck"), built once each.
var views := {}
var _fallers: Array[Dictionary] = []
var _time := 0.0
## The picture fade in progress, if there is one.
var _fade: Tween = null


func _ready() -> void:
	GameSettings.ensure_loaded()
	GameSettings.apply_audio()
	GameSettings.apply_fullscreen()

	views["spring"] = TitleScreen.build_season("spring", _fallers)
	views["four"] = TitleScreen.build_four_seasons(_fallers)
	views["stuck"] = TitleScreen.build_four_seasons(_fallers)
	(views["stuck"] as Node2D).modulate = STUCK_TINT
	for view_name: String in views:
		var view: Node2D = views[view_name]
		view.visible = false
		views_holder.add_child(view)

	next_button.pressed.connect(_on_next_pressed)
	skip_button.pressed.connect(start_game)
	show_page(0)
	next_button.grab_focus()


func _process(delta: float) -> void:
	_time += delta
	TitleScreen.move_fallers(_fallers, _time, delta)


## Shows one page: its words, its picture and its season's colours.
func show_page(index: int) -> void:
	var old_view: Node2D = views[PAGES[page]["view"]]
	page = index
	var entry: Dictionary = PAGES[index]
	var new_view: Node2D = views[entry["view"]]

	text_label.text = entry["text"]
	page_label.text = "%d / %d" % [index + 1, PAGES.size()]
	var last := index == PAGES.size() - 1
	next_button.text = "Let's go!" if last else "Next"
	# The last page also shows the controls, right before the game starts.
	controls_label.visible = last
	ui_root.theme = SeasonTheme.make_theme(entry["season"])
	GameSettings.apply_text_scale(self)

	# A page turned before the last fade finished: stop that fade where it is, so
	# its "hide the old picture" step cannot run later and hide the wrong one.
	if _fade != null and _fade.is_valid():
		_fade.kill()
		old_view.modulate.a = 1.0
		_hide_all_but(old_view)

	# Fade the new picture in over the old one, unless it is the same picture.
	if new_view == old_view and new_view.visible:
		return
	views_holder.move_child(new_view, -1)
	new_view.visible = true
	new_view.modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(new_view, "modulate:a", 1.0, FADE_TIME)
	_fade.tween_callback(func() -> void: _hide_all_but(new_view))


## Hides every picture except one.
func _hide_all_but(keep: Node2D) -> void:
	for view_name: String in views:
		var view: Node2D = views[view_name]
		view.visible = view == keep


func _on_next_pressed() -> void:
	if page < PAGES.size() - 1:
		show_page(page + 1)
	else:
		start_game()


func start_game() -> void:
	get_tree().change_scene_to_file(SPRING_SCENE)


## Esc skips the story.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		start_game()
