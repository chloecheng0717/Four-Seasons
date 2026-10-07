class_name PauseMenu
extends CanvasLayer

## The pause menu (wireframe C), dropped into every level as one node.
##
## Esc, or the small Pause button in the top-right corner, stops the game and
## shows: Resume, Restart this season, Settings, Back to title. Back to title asks
## first, because it throws the season's progress away (wireframe note 7).
##
## Each level sets `season` on its PauseMenu node, which is the only thing that
## differs between them: it decides the colours of the menu and of the settings
## panel opened from it.
##
## Pausing is Godot's own `get_tree().paused`. This node is set to keep running
## while paused (process_mode = Always), and everything in the level is not, so
## players, icicles and timers all simply stop.

const TITLE_SCENE := "res://scenes/TitleScreen.tscn"

@export_enum("spring", "summer", "autumn", "winter") var season := "spring"

@onready var root: Control = $Root
@onready var pause_button: Button = $Root/PauseButton
@onready var overlay: Control = $Root/Overlay
@onready var badge: Label = $Root/Overlay/Center/Panel/Margin/Rows/Badge
@onready var main_buttons: Control = $Root/Overlay/Center/Panel/Margin/Rows/Buttons
@onready var resume_button: Button = $Root/Overlay/Center/Panel/Margin/Rows/Buttons/Resume
@onready var restart_button: Button = $Root/Overlay/Center/Panel/Margin/Rows/Buttons/Restart
@onready var settings_button: Button = $Root/Overlay/Center/Panel/Margin/Rows/Buttons/Settings
@onready var title_button: Button = $Root/Overlay/Center/Panel/Margin/Rows/Buttons/BackToTitle
@onready var confirm: Control = $Root/Overlay/Center/Panel/Margin/Rows/Confirm
@onready var confirm_yes: Button = $Root/Overlay/Center/Panel/Margin/Rows/Confirm/Choices/Yes
@onready var confirm_no: Button = $Root/Overlay/Center/Panel/Margin/Rows/Confirm/Choices/No
@onready var settings_menu: SettingsMenu = $Root/Settings


func _ready() -> void:
	root.theme = SeasonTheme.make_theme(season)
	badge.text = SeasonTheme.badge_text(season)
	overlay.visible = false
	confirm.visible = false
	settings_menu.visible = false

	pause_button.pressed.connect(open)
	resume_button.pressed.connect(close)
	restart_button.pressed.connect(restart_season)
	settings_button.pressed.connect(_open_settings)
	title_button.pressed.connect(_ask_back_to_title)
	confirm_yes.pressed.connect(back_to_title)
	confirm_no.pressed.connect(_cancel_back_to_title)
	settings_menu.closed.connect(_on_settings_closed)

	# The player's saved settings only belong to the game actually being played.
	# The test suites build levels inside their own test scene, and a saved
	# "large text" must not be able to move what they measure, so nothing is
	# applied unless this level is the scene that is running. Deferred, so the
	# labels the level builds in its own _ready (bin labels, the pot's status)
	# exist by then.
	GameSettings.ensure_loaded()
	_apply_settings_if_playing.call_deferred()


func _apply_settings_if_playing() -> void:
	if get_parent() != get_tree().current_scene:
		return
	GameSettings.apply_audio()
	GameSettings.apply_fullscreen()
	GameSettings.apply_text_scale(get_parent())


func is_open() -> bool:
	return overlay.visible


## Esc does one step back at a time: out of Settings, out of the "are you
## sure?", out of the pause menu - or, during play, into it.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if settings_menu.visible:
		settings_menu.close()
	elif confirm.visible:
		_cancel_back_to_title()
	elif overlay.visible:
		close()
	else:
		open()


func open() -> void:
	get_tree().paused = true
	overlay.visible = true
	pause_button.visible = false
	_show_main_buttons()


func close() -> void:
	overlay.visible = false
	confirm.visible = false
	settings_menu.visible = false
	pause_button.visible = true
	get_viewport().gui_release_focus()
	get_tree().paused = false


## Starts this season again from scratch. `paused` must be switched off first:
## it belongs to the whole game, not to the scene, so it would otherwise still be
## on in the fresh copy of the level.
func restart_season() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func back_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)


func _show_main_buttons() -> void:
	main_buttons.visible = true
	confirm.visible = false
	resume_button.grab_focus()


func _ask_back_to_title() -> void:
	main_buttons.visible = false
	confirm.visible = true
	confirm_no.grab_focus()  # The safe answer is the one under the keyboard.


func _cancel_back_to_title() -> void:
	_show_main_buttons()
	title_button.grab_focus()


func _open_settings() -> void:
	overlay.visible = false
	settings_menu.open(season)


func _on_settings_closed() -> void:
	overlay.visible = true
	_show_main_buttons()
	settings_button.grab_focus()
