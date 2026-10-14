extends Node

## Automated checks for the title screen, the settings panel and the pause menu.
##
## Run headless:
##   godot --headless --path <project> --scene res://tests/_menus_test.tscn
##
## It never presses Play, Restart or Back to title for real - each of those
## changes the scene, which would free this test - so for those it checks the
## button is wired to the right handler instead, the same way _summer_test does
## for the Next Level button.
##
## It saves settings to its own file, never to the player's settings.cfg.

const TITLE_SCENE := preload("res://scenes/TitleScreen.tscn")
const LEVELS := {
	"spring": preload("res://scenes/Level.tscn"),
	"summer": preload("res://scenes/SummerLevel.tscn"),
	"autumn": preload("res://scenes/AutumnLevel.tscn"),
	"winter": preload("res://scenes/WinterLevel.tscn"),
}
## Every season's second level has its own pause menu too.
const LEVEL_2S := {
	"spring": preload("res://scenes/SpringLevel2.tscn"),
	"summer": preload("res://scenes/SummerLevel2.tscn"),
	"autumn": preload("res://scenes/AutumnLevel2.tscn"),
	"winter": preload("res://scenes/WinterLevel2.tscn"),
}
const TEST_SETTINGS_PATH := "user://_menus_test_settings.cfg"
## The in-level help text's designed size. 16 until 2026-10-14, when the pixel font
## arrived and the help text went up to 18 to stay as readable as before.
const HELP_SIZE := 18

var failures: Array[String] = []
var _real_save_path := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_real_save_path = GameSettings.save_path
	GameSettings.save_path = TEST_SETTINGS_PATH
	# Read the (empty) test file now, so no later ensure_loaded() - the title's,
	# a pause menu's - can load a file this test wrote on purpose with odd values.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))
	GameSettings.ensure_loaded()
	_reset_settings()
	_run.call_deferred()


func _run() -> void:
	_test_theme()
	_test_settings_file()
	await _test_title_screen()
	for season in SeasonTheme.ORDER:
		await _test_pause_menu(season)
		await _test_pause_menu(season, 2)
	await _test_pause_really_stops_play()
	await _test_esc_key()
	await _test_text_size()
	_cleanup()
	_finish(failures.is_empty())


# --- 1. Season themes -----------------------------------------------------

func _test_theme() -> void:
	_emit("")
	_emit("=== 1. every season has its own look ===")
	var colours := {}
	var frames := {}
	for season in SeasonTheme.ORDER:
		var theme := SeasonTheme.make_theme(season)
		var primary := theme.get_stylebox("normal", "PrimaryButton") as StyleBoxFlat
		_check("%s: the primary button is filled with the season colour" % season,
			primary != null and primary.bg_color == SeasonTheme.MAIN[season])
		# Since 2026-10-14 a panel is the season's pixel-art frame: a picture, filled
		# with the pale tint in the middle, with the season's decorations round it.
		var panel := theme.get_stylebox("panel", "PanelContainer") as StyleBoxTexture
		var frame := panel.texture.get_image() if panel != null else null
		_check("%s: panels are the season's pixel-art frame, filled with its pale tint" % season,
			frame != null
			and frame.get_pixel(frame.get_width() / 2, frame.get_height() / 2)
				.is_equal_approx(SeasonTheme.PANEL[season]))
		frames[season] = frame
		var button := theme.get_stylebox("normal", "Button") as StyleBoxFlat
		_check("%s: buttons have the season's dark border and a pale season fill" % season,
			button != null and button.border_color == SeasonTheme.DARK[season]
			and button.bg_color == SeasonTheme.BUTTON[season])
		_check("%s: buttons are thicker at the bottom, and pressing one squashes it" % season,
			button != null and button.border_width_bottom > button.border_width_top
			and (theme.get_stylebox("pressed", "Button") as StyleBoxFlat).border_width_bottom
				< button.border_width_bottom)
		_check("%s: text is in the season's dark colour" % season,
			theme.get_color("font_color", "Label") == SeasonTheme.DARK[season]
			and theme.get_color("font_color", "Button") == SeasonTheme.DARK[season])
		var ring := theme.get_stylebox("focus", "Button") as StyleBoxFlat
		_check("%s: the keyboard focus ring stands out from the season colour" % season,
			ring != null and ring.border_color == SeasonTheme.FOCUS[season]
			and ring.border_color != SeasonTheme.MAIN[season])
		_check("%s: sliders have a round knob picture" % season,
			theme.get_icon("grabber", "HSlider") != null)
		_check("%s: the check box has an empty and a ticked picture" % season,
			theme.get_icon("checked", "CheckBox") != null
			and theme.get_icon("unchecked", "CheckBox") != null)
		colours[SeasonTheme.MAIN[season].to_html()] = true
	_check("the four seasons have four different colours", colours.size() == 4)
	# Each season's decorations make its frame picture different from every other.
	var different := true
	for a in SeasonTheme.ORDER:
		for b in SeasonTheme.ORDER:
			if a < b and frames[a] != null and frames[b] != null:
				different = different and frames[a].get_data() != frames[b].get_data()
	_check("the four seasons have four different frames", different)
	var corner: Image = frames["winter"]
	_check("decorations stick out past the box: the frame picture has a see-through ring",
		corner != null and corner.get_pixel(corner.get_width() / 2,
			SeasonTheme.FRAME_OUTSIDE * SeasonTheme.PIXEL_SCALE - 1).a > 0.0
		and frames["summer"].get_pixel(0, frames["summer"].get_height() / 2).a == 0.0)
	_check("the badge names the season and its animals",
		SeasonTheme.badge_text("winter") == "Winter · Penguins")
	_check("the seasons go round in the same order as the levels",
		SeasonTheme.next_season("spring") == "summer"
		and SeasonTheme.next_season("autumn") == "winter"
		and SeasonTheme.next_season("winter") == "spring")


# --- 2. Settings are saved and applied ------------------------------------

func _test_settings_file() -> void:
	_emit("")
	_emit("=== 2. settings are saved, read back and applied ===")
	_check("the test is not using the player's own settings file",
		GameSettings.save_path == TEST_SETTINGS_PATH and _real_save_path != TEST_SETTINGS_PATH)

	GameSettings.music_volume = 0.25
	GameSettings.sound_volume = 0.0
	GameSettings.text_scale = 1.3
	GameSettings.fullscreen = true
	GameSettings.save()

	GameSettings.music_volume = 0.8
	GameSettings.sound_volume = 0.8
	GameSettings.text_scale = 1.0
	GameSettings.fullscreen = false
	GameSettings.load_from_file()
	_check("music volume survives a save and a load", is_equal_approx(GameSettings.music_volume, 0.25))
	_check("sound volume survives a save and a load", is_equal_approx(GameSettings.sound_volume, 0.0))
	_check("text size survives a save and a load", is_equal_approx(GameSettings.text_scale, 1.3))
	_check("fullscreen survives a save and a load", GameSettings.fullscreen)

	GameSettings.apply_audio()
	var music := AudioServer.get_bus_index(GameSettings.MUSIC_BUS)
	var sound := AudioServer.get_bus_index(GameSettings.SOUND_BUS)
	_check("there is a Music bus", music != -1)
	_check("there is an SFX bus", sound != -1)
	_check("the Music bus is at the slider's volume",
		music != -1 and is_equal_approx(AudioServer.get_bus_volume_db(music), linear_to_db(0.25)),
		" db=%.2f" % AudioServer.get_bus_volume_db(music))
	_check("a sound volume of zero mutes the SFX bus", sound != -1 and AudioServer.is_bus_mute(sound))
	_check("both buses feed into Master",
		AudioServer.get_bus_send(music) == &"Master" and AudioServer.get_bus_send(sound) == &"Master")

	# A hand-edited file with silly values is pulled back into range.
	var file := ConfigFile.new()
	file.set_value("display", "text_scale", 9.0)
	file.set_value("audio", "music", -3.0)
	file.save(TEST_SETTINGS_PATH)
	GameSettings.load_from_file()
	_check("an out-of-range text size is clamped",
		is_equal_approx(GameSettings.text_scale, GameSettings.TEXT_SCALE_MAX))
	_check("an out-of-range volume is clamped", is_equal_approx(GameSettings.music_volume, 0.0))

	_reset_settings()


# --- 3. The title screen ---------------------------------------------------

func _test_title_screen() -> void:
	_emit("")
	_emit("=== 3. the title screen ===")
	var title := TITLE_SCENE.instantiate() as TitleScreen
	add_child(title)
	await _frames(3)

	_check("the main scene is the title screen",
		ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/TitleScreen.tscn")
	_check("it says Four Seasons", (title.get_node("UI/Root/Menu/Title") as Label).text == "Four Seasons")

	var names: Array[String] = []
	for button in title.get_node("UI/Root/Menu/Buttons").get_children():
		names.append((button as Button).text)
	_check("the buttons are Play, How to Play, Settings, Quit, in that order",
		names == ["Play", "How to Play", "Settings", "Quit"], " got=%s" % str(names))
	_check("Play is the highlighted button", title.play_button.theme_type_variation == &"PrimaryButton")
	_check("the keyboard starts on Play", title.play_button.has_focus())
	# 2026-10-14: Play opens the story intro first, and the intro starts Spring.
	_check("Play is wired to start the story intro, which starts Spring",
		title.play_button.pressed.is_connected(title._on_play_pressed)
		and TitleScreen.INTRO_SCENE == "res://scenes/StoryIntro.tscn"
		and ResourceLoader.exists(TitleScreen.INTRO_SCENE)
		and StoryIntro.SPRING_SCENE == TitleScreen.SPRING_SCENE
		and TitleScreen.SPRING_SCENE == "res://scenes/Level.tscn"
		and ResourceLoader.exists(TitleScreen.SPRING_SCENE))
	_check("Quit is wired to quit", title.quit_button.pressed.is_connected(title._on_quit_pressed))

	# Every button is on screen and the menu stays clear of the animals and props.
	var screen := Rect2(0, 0, 1280, 720)
	var all_on_screen := true
	for button in title.get_node("UI/Root/Menu/Buttons").get_children():
		all_on_screen = all_on_screen and screen.encloses((button as Control).get_global_rect())
	_check("every button is fully on screen", all_on_screen)
	var menu_rect := (title.get_node("UI/Root/Menu/Buttons") as Control).get_global_rect()
	_check("the buttons end above the ground", menu_rect.end.y < TitleScreen.GROUND_Y,
		" bottom=%.0f" % menu_rect.end.y)

	# The four seasons.
	_check("there are four season backgrounds", title.season_layers.size() == 4)
	for season in SeasonTheme.ORDER:
		var layer: Node2D = title.season_layers.get(season)
		var sprites := 0
		var animals := 0
		if layer != null:
			for child in layer.get_children():
				if child is Sprite2D:
					sprites += 1
					var texture := (child as Sprite2D).texture
					for animal in TitleScreen.ANIMALS[season]:
						if animal["texture"] == texture:
							animals += 1
		_check("%s background has its two animals" % season, animals == 2, " animals=%d" % animals)
		_check("%s background has ground across the whole screen" % season,
			sprites >= TitleScreen.COLUMNS * 3, " sprites=%d" % sprites)
		_check("%s background has nothing that collides" % season,
			layer != null and layer.find_children("*", "CollisionObject2D", true, false).is_empty())
	_check("it starts on Spring", title.season == "spring"
		and title.season_layers["spring"].modulate.a == 1.0
		and title.season_layers["summer"].modulate.a == 0.0)
	_check("the badge says Spring · Cats", title.badge.text == "Spring · Cats")
	_check("the menu is in Spring's colours", _primary_colour(title.ui_root) == SeasonTheme.MAIN["spring"])

	# Let the timer run out and the next season fade in on its own.
	title._season_timer = 0.05
	await _seconds(TitleScreen.FADE_TIME + 0.4)
	_check("after its turn, Summer takes over", title.season == "summer")
	_check("Summer has faded all the way in and Spring all the way out",
		title.season_layers["summer"].modulate.a == 1.0
		and title.season_layers["spring"].modulate.a == 0.0)
	_check("the badge now says Summer · Dogs", title.badge.text == "Summer · Dogs")
	_check("the menu changed to Summer's colours", _primary_colour(title.ui_root) == SeasonTheme.MAIN["summer"])
	title.show_season("autumn")
	title.show_season("winter")
	title.show_season("spring")
	_check("after Winter it goes back round to Spring", title.season == "spring")
	title.show_season("autumn")
	await _seconds(TitleScreen.FADE_TIME + 0.2)

	# How to Play.
	title.how_button.pressed.emit()
	_check("How to Play opens a panel", title.how_panel.visible)
	_check("it explains both players' keys",
		title.how_text.text.contains("A / D") and title.how_text.text.contains("Enter"))
	_check("the keyboard moves to its Back button", title.how_back.has_focus())
	title.how_back.pressed.emit()
	_check("Back closes it and returns to How to Play",
		not title.how_panel.visible and title.how_button.has_focus())

	# Settings from the title, dressed as the season on show.
	title.settings_button.pressed.emit()
	var settings := title.settings_menu
	_check("Settings opens from the title", settings.visible)
	_check("it wears the season that was showing (Autumn)",
		settings.season == "autumn" and _primary_colour(settings) == SeasonTheme.MAIN["autumn"]
		and settings.badge.text == "Autumn · Foxes")
	_check("it has Music, Sound, Text size and Fullscreen",
		settings.music_slider != null and settings.sound_slider != null
		and settings.text_slider != null and settings.fullscreen_check != null)
	_check("the keyboard starts on the first slider", settings.music_slider.has_focus())
	title.show_season("winter")
	_check("an open Settings panel keeps its colours while the background moves on",
		settings.season == "autumn")
	settings.music_slider.value = 0.5
	_check("moving a slider changes the setting straight away", is_equal_approx(GameSettings.music_volume, 0.5))
	var saved := ConfigFile.new()
	_check("and saves it straight away",
		saved.load(TEST_SETTINGS_PATH) == OK and is_equal_approx(float(saved.get_value("audio", "music")), 0.5))
	settings.back_button.pressed.emit()
	_check("Back closes Settings and returns to the Settings button",
		not settings.visible and title.settings_button.has_focus())

	_reset_settings()
	title.queue_free()
	await _frames(2)


# --- 4. The pause menu in every level ---------------------------------------

func _test_pause_menu(season: String, stage: int = 1) -> void:
	_emit("")
	_emit("=== 4. %s %d: the pause menu ===" % [season, stage])
	var level: Node = (LEVELS[season] if stage == 1 else LEVEL_2S[season]).instantiate()
	add_child(level)
	await _frames(3)

	var pause := level.get_node_or_null("PauseMenu") as PauseMenu
	_check("%s has a pause menu" % season, pause != null)
	if pause == null:
		level.queue_free()
		return
	_check("it is in %s's colours" % season,
		pause.season == season and _primary_colour(pause.root) == SeasonTheme.MAIN[season]
		and pause.badge.text == SeasonTheme.badge_text(season))
	_check("it keeps running while the game is paused", pause.process_mode == Node.PROCESS_MODE_ALWAYS)
	_check("it is drawn above the level and the completion screen", pause.layer > 1)
	_check("during play only the Pause button shows",
		pause.pause_button.visible and not pause.overlay.visible and not get_tree().paused)
	_check("the Pause button cannot be pressed by a jump key",
		pause.pause_button.focus_mode == Control.FOCUS_NONE)
	var button_rect := pause.pause_button.get_global_rect()
	_check("the Pause button is in the top-right corner, on screen",
		button_rect.position.x > 1000 and Rect2(0, 0, 1280, 720).encloses(button_rect))
	var help := level.find_child("P1Help", true, false) as Control
	_check("the Pause button does not cover the controls help",
		help != null and not help.get_global_rect().intersects(button_rect))

	pause.pause_button.pressed.emit()
	_check("pressing Pause pauses the game", get_tree().paused and pause.is_open())
	_check("the Pause button hides while the menu is up", not pause.pause_button.visible)
	var names: Array[String] = []
	for button in pause.main_buttons.get_children():
		names.append((button as Button).text)
	_check("the menu is Resume, Restart this season, Settings, Back to title",
		names == ["Resume", "Restart this season", "Settings", "Back to title"], " got=%s" % str(names))
	_check("Resume is highlighted and has the keyboard",
		pause.resume_button.theme_type_variation == &"PrimaryButton" and pause.resume_button.has_focus())
	_check("Restart is wired to restart the season",
		pause.restart_button.pressed.is_connected(pause.restart_season))

	pause.title_button.pressed.emit()
	_check("Back to title asks first", pause.confirm.visible and not pause.main_buttons.visible)
	_check("the keyboard is on 'No, stay', the safe answer", pause.confirm_no.has_focus())
	_check("'Yes, leave' is wired to go to the title",
		pause.confirm_yes.pressed.is_connected(pause.back_to_title)
		and ResourceLoader.exists(PauseMenu.TITLE_SCENE))
	pause.confirm_no.pressed.emit()
	_check("'No, stay' goes back to the menu", pause.main_buttons.visible and not pause.confirm.visible
		and get_tree().paused)

	pause.settings_button.pressed.emit()
	_check("Settings opens from the pause menu", pause.settings_menu.visible and not pause.overlay.visible)
	_check("and is in %s's colours" % season,
		pause.settings_menu.season == season
		and _primary_colour(pause.settings_menu) == SeasonTheme.MAIN[season])
	pause.settings_menu.back_button.pressed.emit()
	_check("Back returns to the pause menu", pause.overlay.visible and not pause.settings_menu.visible
		and get_tree().paused)

	pause.resume_button.pressed.emit()
	_check("Resume unpauses and hides the menu",
		not get_tree().paused and not pause.is_open() and pause.pause_button.visible)

	level.queue_free()
	await _frames(2)


## The point of pausing: nothing in the level moves.
func _test_pause_really_stops_play() -> void:
	_emit("")
	_emit("=== 5. a paused game really stands still ===")
	var level: Node = LEVELS["summer"].instantiate()
	# This test node keeps running while paused, and a child would inherit that.
	# In the game a level sits directly under the root and pauses, so make this
	# one behave the same way.
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	await _frames(10)
	var pause := level.get_node("PauseMenu") as PauseMenu
	var dog := level.players.get_child(0) as Node2D

	pause.open()
	var x := dog.position.x
	Input.action_press("p1_right")
	await _frames(20)
	Input.action_release("p1_right")
	_check("a dog told to walk while paused does not move", is_equal_approx(dog.position.x, x),
		" moved=%.1f" % (dog.position.x - x))

	pause.close()
	Input.action_press("p1_right")
	await _frames(20)
	Input.action_release("p1_right")
	_check("after Resume the same key walks it again", dog.position.x > x + 20.0,
		" moved=%.1f" % (dog.position.x - x))

	level.queue_free()
	await _frames(2)


## Esc steps in and out one level at a time.
func _test_esc_key() -> void:
	_emit("")
	_emit("=== 6. Esc ===")
	var level: Node = LEVELS["autumn"].instantiate()
	add_child(level)
	await _frames(3)
	var pause := level.get_node("PauseMenu") as PauseMenu

	await _press_esc()
	_check("Esc during play opens the pause menu", pause.is_open() and get_tree().paused)
	pause.settings_button.pressed.emit()
	await _press_esc()
	_check("Esc in Settings goes back to the pause menu",
		not pause.settings_menu.visible and pause.is_open())
	pause.title_button.pressed.emit()
	await _press_esc()
	_check("Esc on 'are you sure?' goes back to the pause menu",
		not pause.confirm.visible and pause.main_buttons.visible and pause.is_open())
	await _press_esc()
	_check("Esc in the pause menu resumes", not pause.is_open() and not get_tree().paused)

	level.queue_free()
	await _frames(2)

	var title := TITLE_SCENE.instantiate() as TitleScreen
	add_child(title)
	await _frames(3)
	title.settings_button.pressed.emit()
	await _press_esc()
	_check("Esc closes Settings on the title too", not title.settings_menu.visible)
	title.how_button.pressed.emit()
	await _press_esc()
	_check("Esc closes How to Play", not title.how_panel.visible)
	title.queue_free()
	await _frames(2)


# --- 7. Text size ---------------------------------------------------------

func _test_text_size() -> void:
	_emit("")
	_emit("=== 7. text size ===")
	GameSettings.text_scale = 1.5

	# A level built inside this test is not the game being played, so the saved
	# text size must leave it exactly as designed - the other suites rely on this.
	var level: Node = LEVELS["summer"].instantiate()
	add_child(level)
	await _frames(3)
	var help := level.get_node("P1Help") as Label
	_check("a level that is not the running game keeps its designed text size",
		help.get_theme_font_size("font_size") == HELP_SIZE, " size=%d" % help.get_theme_font_size("font_size"))

	# Applying it scales from the designed size every time, never compounding.
	GameSettings.apply_text_scale(level)
	_check("text size 1.5 makes the help text 1.5 times its designed size",
		help.get_theme_font_size("font_size") == roundi(HELP_SIZE * 1.5))
	GameSettings.apply_text_scale(level)
	_check("applying it twice does not grow it again",
		help.get_theme_font_size("font_size") == roundi(HELP_SIZE * 1.5))
	GameSettings.text_scale = 0.8
	GameSettings.apply_text_scale(level)
	_check("making it smaller works from the designed size too",
		help.get_theme_font_size("font_size") == roundi(HELP_SIZE * 0.8))
	var bin_label := level.find_child("BinLabel", true, false) as Label
	_check("labels the level built in code are scaled as well",
		bin_label != null and bin_label.has_meta(GameSettings.BASE_SIZE_META))
	var pause := level.get_node("PauseMenu") as PauseMenu
	_check("the pause menu's own buttons are scaled with everything else",
		pause.resume_button.has_meta(GameSettings.BASE_SIZE_META))

	_reset_settings()
	level.queue_free()
	await _frames(2)


# --- helpers ----------------------------------------------------------------

func _primary_colour(control: Control) -> Color:
	if control.theme == null:
		return Color.BLACK
	var box := control.theme.get_stylebox("normal", "PrimaryButton") as StyleBoxFlat
	return box.bg_color if box != null else Color.BLACK


func _press_esc() -> void:
	var press := InputEventAction.new()
	press.action = "ui_cancel"
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(2)
	var release := InputEventAction.new()
	release.action = "ui_cancel"
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(2)


func _reset_settings() -> void:
	GameSettings.music_volume = 0.8
	GameSettings.sound_volume = 0.8
	GameSettings.text_scale = 1.0
	GameSettings.fullscreen = false
	GameSettings.apply_audio()


func _cleanup() -> void:
	get_tree().paused = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))
	GameSettings.save_path = _real_save_path


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


## Real time, not frames: headless frame rate is not a fixed 60Hz.
func _seconds(time: float) -> void:
	await get_tree().create_timer(time, true).timeout


func _emit(line: String) -> void:
	print(line)


func _check(label: String, ok: bool, detail: String = "") -> bool:
	if ok:
		_emit("  PASS  %s %s" % [label, detail])
	else:
		failures.append(label)
		_emit("  FAIL  %s %s" % [label, detail])
	return ok


func _finish(ok: bool) -> void:
	_emit("")
	_emit("=".repeat(58))
	if ok:
		_emit("ALL CHECKS PASSED")
	else:
		_emit("FAILURES (%d): %s" % [failures.size(), ", ".join(failures)])
	_emit("=".repeat(58))
	get_tree().quit(0 if ok else 1)
