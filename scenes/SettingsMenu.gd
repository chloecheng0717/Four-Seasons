class_name SettingsMenu
extends Control

## The settings panel (wireframe D): music volume, sound volume, text size and
## fullscreen, plus Back.
##
## The same scene is used on the title screen and inside the pause menu. Whoever
## opens it calls `open(season)`, so it is dressed in that season's colours, and
## listens for `closed` to know when Back was pressed.
##
## Every change takes effect straight away (wireframe note 8: "sliders respond
## immediately") and is saved straight away, so there is no Apply button and
## nothing to forget.

signal closed

@onready var panel: PanelContainer = $Center/Panel
@onready var badge: Label = $Center/Panel/Margin/Rows/Badge
@onready var music_slider: HSlider = $Center/Panel/Margin/Rows/Grid/MusicSlider
@onready var sound_slider: HSlider = $Center/Panel/Margin/Rows/Grid/SoundSlider
@onready var text_slider: HSlider = $Center/Panel/Margin/Rows/Grid/TextSlider
@onready var fullscreen_check: CheckBox = $Center/Panel/Margin/Rows/Grid/FullscreenCheck
@onready var back_button: Button = $Center/Panel/Margin/Rows/Back

var season := "spring"


func _ready() -> void:
	GameSettings.ensure_loaded()
	text_slider.min_value = GameSettings.TEXT_SCALE_MIN
	text_slider.max_value = GameSettings.TEXT_SCALE_MAX
	_show_current_values()
	music_slider.value_changed.connect(_on_music_changed)
	sound_slider.value_changed.connect(_on_sound_changed)
	text_slider.value_changed.connect(_on_text_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	back_button.pressed.connect(close)
	set_season(season)


## Shows the panel in a season's colours, with the keyboard on the first slider.
func open(for_season: String) -> void:
	set_season(for_season)
	_show_current_values()
	visible = true
	music_slider.grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func set_season(for_season: String) -> void:
	season = for_season
	theme = SeasonTheme.make_theme(season)
	if badge != null:
		badge.text = SeasonTheme.badge_text(season)


## Puts the saved values on the controls without firing their change signals,
## so opening the panel never re-saves or re-applies anything.
func _show_current_values() -> void:
	music_slider.set_value_no_signal(GameSettings.music_volume)
	sound_slider.set_value_no_signal(GameSettings.sound_volume)
	text_slider.set_value_no_signal(GameSettings.text_scale)
	fullscreen_check.set_pressed_no_signal(GameSettings.fullscreen)


func _on_music_changed(value: float) -> void:
	GameSettings.music_volume = value
	GameSettings.apply_audio()
	GameSettings.save()


func _on_sound_changed(value: float) -> void:
	GameSettings.sound_volume = value
	GameSettings.apply_audio()
	GameSettings.save()


## Text size applies to the whole running scene at once - the level's help text,
## the menus, everything - so the player sees the result while dragging.
func _on_text_changed(value: float) -> void:
	GameSettings.text_scale = value
	GameSettings.apply_text_scale(get_tree().current_scene)
	GameSettings.save()


func _on_fullscreen_toggled(on: bool) -> void:
	GameSettings.fullscreen = on
	GameSettings.apply_fullscreen()
	GameSettings.save()
