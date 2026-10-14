class_name Ending
extends Node2D

## The ending, shown after Winter 2: a short animation that goes through the year
## once more, then congratulates the players.
##
## 1. A recap. The four seasons take turns, in the order they were played. Each
##    one is the same little season scene the title screen uses (its sky, ground,
##    props and its two animals hopping), with a caption saying what those friends
##    did and one sustainability fact that goes with it - the season-clear facts
##    from the proposal (Appendix C).
## 2. The finale. All four seasons side by side, all eight animals hopping,
##    confetti in the four season colours, "Congratulations!", and the closing
##    line of the story. Play again starts Spring again; Back to title goes home.
##
## Enter, Esc or a click during the recap skips straight to the finale.
##
## The season scenes are built by TitleScreen's own static helpers, so nothing is
## drawn twice and the ending always matches the title screen.

const PLAY_AGAIN_SCENE := "res://scenes/Level.tscn"
const TITLE_SCENE := "res://scenes/TitleScreen.tscn"

## How long each season stays in the recap, and how long one takes to fade into
## the next.
const BEAT_TIME := 5.5
const FADE_TIME := 1.2

## One recap beat per season: what the friends did, and the fact that goes with it.
const RECAP := [
	{
		"season": "spring",
		"achievement": "The cats grew a flower, and the garden came back to life.",
		"fact": "Did you know? Plants hold soil in place and give food and shelter to small animals.",
		"goal": "SDG 15 · Life on Land",
	},
	{
		"season": "summer",
		"achievement": "The dogs sorted the rubbish, and the beach is clean again.",
		"fact": "Did you know? Sorting lets materials be recycled, and the best way to cut waste is to use less.",
		"goal": "SDG 12 · Responsible Consumption and Production",
	},
	{
		"season": "autumn",
		"achievement": "The foxes returned every fallen leaf to the forest floor.",
		"fact": "Did you know? Fallen leaves break down and return nutrients to the soil.",
		"goal": "SDG 15 · Life on Land",
	},
	{
		"season": "winter",
		"achievement": "The penguins crossed the ice and made it home together.",
		"fact": "Did you know? A changing climate makes snow and ice less stable.",
		"goal": "SDG 13 · Climate Action",
	},
]

## How many pieces of confetti drift over the finale.
const CONFETTI_COUNT := 70

@onready var seasons_holder: Node2D = $Seasons
@onready var finale_holder: Node2D = $Finale
@onready var confetti_holder: Node2D = $Confetti
@onready var ui_root: Control = $UI/Root
@onready var caption: Control = $UI/Root/Caption
@onready var badge: Label = $UI/Root/Caption/Margin/Rows/Badge
@onready var achievement_label: Label = $UI/Root/Caption/Margin/Rows/Achievement
@onready var fact_label: Label = $UI/Root/Caption/Margin/Rows/Fact
@onready var goal_label: Label = $UI/Root/Caption/Margin/Rows/Goal
@onready var skip_hint: Label = $UI/Root/SkipHint
@onready var finale_box: Control = $UI/Root/FinaleBox
@onready var finale_panel: Control = $UI/Root/FinaleBox/Panel
@onready var play_again_button: Button = $UI/Root/FinaleBox/Panel/Margin/Rows/Buttons/PlayAgain
@onready var title_button: Button = $UI/Root/FinaleBox/Panel/Margin/Rows/Buttons/BackToTitle
@onready var fade: ColorRect = $UI/Root/Fade

## Which recap beat is showing (0 = Spring ... 3 = Winter).
var beat := 0
## True once the finale is up. After that the recap timer stops.
var finale_shown := false
## The recap's four season scenes, in RECAP order.
var season_layers: Array[Node2D] = []
var _beat_timer := BEAT_TIME
## Everything that drifts down - leaves, snow and confetti. See TitleScreen.add_faller.
var _fallers: Array[Dictionary] = []
var _time := 0.0


func _ready() -> void:
	# The season chain test presses Winter 2's Next Level button and then needs to
	# prove the ending arrived. With this user argument, say so and quit.
	if OS.get_cmdline_user_args().has("--ending-check"):
		print("NEXT LEVEL REACHED ENDING")
		get_tree().quit(0)
		return

	GameSettings.ensure_loaded()
	GameSettings.apply_audio()
	GameSettings.apply_fullscreen()

	for index in RECAP.size():
		var layer := TitleScreen.build_season(RECAP[index]["season"], _fallers)
		layer.modulate.a = 1.0 if index == 0 else 0.0
		seasons_holder.add_child(layer)
		season_layers.append(layer)

	finale_box.visible = false
	play_again_button.pressed.connect(_on_play_again_pressed)
	title_button.pressed.connect(_on_back_to_title_pressed)
	_show_caption(0)
	GameSettings.apply_text_scale(self)

	# Open on black and fade in, like the end of a film.
	fade.color.a = 1.0
	var fade_in := create_tween()
	fade_in.tween_property(fade, "color:a", 0.0, 1.0)


func _process(delta: float) -> void:
	_time += delta
	TitleScreen.move_fallers(_fallers, _time, delta)

	if finale_shown:
		return
	_beat_timer -= delta
	if _beat_timer <= 0.0:
		_beat_timer = BEAT_TIME
		if beat < RECAP.size() - 1:
			show_beat(beat + 1)
		else:
			show_finale()


## Fades the next season in over the last one and changes the caption to match.
func show_beat(next: int) -> void:
	var old_layer := season_layers[beat]
	var new_layer := season_layers[next]
	beat = next
	seasons_holder.move_child(new_layer, -1)  # Draw it on top while it fades in.
	new_layer.modulate.a = 0.0
	var cross := create_tween()
	cross.tween_property(new_layer, "modulate:a", 1.0, FADE_TIME)
	cross.tween_callback(func() -> void: old_layer.modulate.a = 0.0)
	_show_caption(next)


## The caption wears its season's colours, like every menu in the game.
func _show_caption(index: int) -> void:
	var entry: Dictionary = RECAP[index]
	var season: String = entry["season"]
	ui_root.theme = SeasonTheme.make_theme(season)
	badge.text = SeasonTheme.badge_text(season)
	achievement_label.text = entry["achievement"]
	fact_label.text = entry["fact"]
	goal_label.text = entry["goal"]
	caption.modulate.a = 0.0
	var appear := create_tween()
	appear.tween_property(caption, "modulate:a", 1.0, 0.5)


## The finale: all four seasons at once, and the congratulations.
func show_finale() -> void:
	if finale_shown:
		return
	finale_shown = true
	_build_finale()

	# After Winter comes Spring again, so the finale wears Spring's colours.
	ui_root.theme = SeasonTheme.make_theme("spring")
	caption.visible = false
	skip_hint.visible = false
	finale_box.visible = true
	GameSettings.apply_text_scale(self)

	var swap := create_tween().set_parallel(true)
	swap.tween_property(seasons_holder, "modulate:a", 0.0, 0.8)
	swap.tween_property(finale_holder, "modulate:a", 1.0, 0.8)
	swap.tween_property(confetti_holder, "modulate:a", 1.0, 0.8)

	# The panel pops in from slightly small, so it reads as a celebration.
	finale_panel.pivot_offset = finale_panel.size * 0.5
	finale_panel.scale = Vector2(0.6, 0.6)
	var pop := create_tween()
	pop.tween_property(finale_panel, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	play_again_button.grab_focus()


## Four columns, one per season (TitleScreen.build_four_seasons), plus confetti in
## the four season colours drifting over all of them.
func _build_finale() -> void:
	finale_holder.add_child(TitleScreen.build_four_seasons(_fallers))

	for index in CONFETTI_COUNT:
		var piece := ColorRect.new()
		piece.size = Vector2(10.0, 6.0)
		piece.color = SeasonTheme.MAIN[SeasonTheme.ORDER[index % SeasonTheme.ORDER.size()]]
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		confetti_holder.add_child(piece)
		TitleScreen.add_faller(_fallers, piece, randf_range(50.0, 110.0), 40.0)


## During the recap, Enter, Esc or a click skips to the finale.
func _unhandled_input(event: InputEvent) -> void:
	if finale_shown:
		return
	var skip := event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")
	if event is InputEventMouseButton:
		skip = skip or ((event as InputEventMouseButton).pressed
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	if skip:
		get_viewport().set_input_as_handled()
		show_finale()


func _on_play_again_pressed() -> void:
	get_tree().change_scene_to_file(PLAY_AGAIN_SCENE)


func _on_back_to_title_pressed() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE)
