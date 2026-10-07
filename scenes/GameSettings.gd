class_name GameSettings
extends RefCounted

## The player's settings: two volumes, a text size and fullscreen.
##
## These are `static var`s, so there is exactly one copy of each for the whole
## game and it survives every change of scene. That is why this needs no
## autoload: the title screen, the settings panel and the pause menu all just
## read and write `GameSettings.text_scale` and friends directly.
##
## The values are saved to `user://settings.cfg` (a small text file Godot keeps
## in the player's own app-data folder) every time one changes, and read back
## the first time anything asks for them.

const TEXT_SCALE_MIN := 0.8
const TEXT_SCALE_MAX := 1.5
const MUSIC_BUS := "Music"
const SOUND_BUS := "SFX"

## Where the settings live. Tests point this somewhere else so they never touch
## the player's real file.
static var save_path := "user://settings.cfg"

## 0 = silent, 1 = full volume.
static var music_volume := 0.8
static var sound_volume := 0.8
## 1 = the size every label was designed at.
static var text_scale := 1.0
static var fullscreen := false

static var _loaded := false

## The meta key a Label/Button keeps its original font size under, so scaling
## always starts from the designed size and never compounds.
const BASE_SIZE_META := &"base_font_size"


## Reads the file once. Safe to call from everywhere; only the first call reads.
static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	load_from_file()


static func load_from_file() -> void:
	var file := ConfigFile.new()
	if file.load(save_path) != OK:
		return  # No file yet: keep the defaults.
	music_volume = clampf(float(file.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sound_volume = clampf(float(file.get_value("audio", "sound", sound_volume)), 0.0, 1.0)
	text_scale = clampf(float(file.get_value("display", "text_scale", text_scale)),
		TEXT_SCALE_MIN, TEXT_SCALE_MAX)
	fullscreen = bool(file.get_value("display", "fullscreen", fullscreen))


static func save() -> void:
	var file := ConfigFile.new()
	file.set_value("audio", "music", music_volume)
	file.set_value("audio", "sound", sound_volume)
	file.set_value("display", "text_scale", text_scale)
	file.set_value("display", "fullscreen", fullscreen)
	file.save(save_path)


## Sets the Music and SFX bus volumes. The game has no sounds yet; once one is
## added, putting it on the "Music" or "SFX" bus is all it needs for these
## sliders to control it.
static func apply_audio() -> void:
	_set_bus_volume(MUSIC_BUS, music_volume)
	_set_bus_volume(SOUND_BUS, sound_volume)


static func _set_bus_volume(bus_name: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		# The bus does not exist yet, so make it, feeding into Master.
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")
	AudioServer.set_bus_mute(index, volume <= 0.0)
	if volume > 0.0:
		AudioServer.set_bus_volume_db(index, linear_to_db(volume))


static func apply_fullscreen() -> void:
	# A headless run (the test suites) has no window to resize.
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.window_get_mode()
	var is_fullscreen := mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if is_fullscreen == fullscreen:
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED)


## Resizes the text of every Label and Button under `root` to `text_scale` times
## the size it was designed at.
static func apply_text_scale(root: Node) -> void:
	if root == null:
		return
	for node in root.find_children("*", "Control", true, false):
		if not (node is Label or node is Button):
			continue
		var control := node as Control
		if not control.has_meta(BASE_SIZE_META):
			control.set_meta(BASE_SIZE_META, control.get_theme_font_size("font_size"))
		var base: int = control.get_meta(BASE_SIZE_META)
		control.add_theme_font_size_override("font_size", roundi(base * text_scale))
