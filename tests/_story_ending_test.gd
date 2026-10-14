extends Node

## Checks for the story intro (after Play) and the ending (after Winter 2).
##
## Both are built from their real scene files. The intro's pages are turned with
## its own Next button, the ending is left to play its recap by itself and is also
## skipped, and every button is checked to be wired to the right place.
##
## At the very end, with everything passed, the intro's last button ("Let's go!")
## is pressed for real. That frees this test along with the intro, and Spring 1
## sees the user argument --spring-check, prints "NEXT LEVEL REACHED SPRING" and
## quits 0. So run it as:
##   --scene res://tests/_story_ending_test.tscn -- --spring-check

const INTRO_SCENE := preload("res://scenes/StoryIntro.tscn")
const ENDING_SCENE := preload("res://scenes/Ending.tscn")
const TEST_SETTINGS_PATH := "user://_story_ending_test_settings.cfg"

var failures: Array[String] = []
var _real_save_path := ""
var _elapsed := 0.0
var _pressed_at_ms := 0


func _ready() -> void:
	# The player's own saved settings (a large text size, say) must not reach this
	# test, so it reads an empty settings file of its own.
	_real_save_path = GameSettings.save_path
	GameSettings.save_path = TEST_SETTINGS_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))
	GameSettings.ensure_loaded()

	if not OS.get_cmdline_user_args().has("--spring-check"):
		_check("this test needs the user argument --spring-check", false,
			" run: --scene res://tests/_story_ending_test.tscn -- --spring-check")
		_finish(false)
		return
	_run.call_deferred()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > 120.0:
		_emit("WATCHDOG: aborted after %.0fs" % _elapsed)
		get_tree().quit(2)
	# Pressed but still here a moment later means the scene never changed.
	if _pressed_at_ms > 0 and Time.get_ticks_msec() - _pressed_at_ms > 1000:
		_pressed_at_ms = -1
		_check("pressing Let's go! really left the intro", false)
		_finish(false)


func _run() -> void:
	await _test_the_ending()
	var intro := await _test_the_intro()
	GameSettings.save_path = _real_save_path
	if not failures.is_empty():
		_finish(false)
		return
	_emit("")
	_emit("=".repeat(58))
	_emit("ALL CHECKS PASSED - now pressing Let's go! for real")
	_emit("")
	_pressed_at_ms = Time.get_ticks_msec()
	intro.next_button.pressed.emit()


# ------------------------------------------------------------------- the intro


func _test_the_intro() -> StoryIntro:
	_emit("=== 1. the story intro ===")
	var intro := INTRO_SCENE.instantiate() as StoryIntro
	add_child(intro)
	await _frames(3)

	_check("it has five pages and starts on the first", StoryIntro.PAGES.size() == 5 and intro.page == 0)
	_check("the first page is showing, with its words and '1 / 5'",
		intro.text_label.text == StoryIntro.PAGES[0]["text"] and intro.page_label.text == "1 / 5")
	_check("Next is the highlighted button and the keyboard is on it",
		intro.next_button.theme_type_variation == &"PrimaryButton" and intro.next_button.has_focus())
	_check("Skip is wired to start the game", intro.skip_button.pressed.is_connected(intro.start_game))
	_check("and the game it starts is Spring 1",
		StoryIntro.SPRING_SCENE == "res://scenes/Level.tscn"
		and ResourceLoader.exists(StoryIntro.SPRING_SCENE))
	_check("the first picture is the spring scene",
		(intro.views["spring"] as Node2D).visible)

	var story := ""
	for entry in StoryIntro.PAGES:
		story += String(entry["text"]) + " "
	_check("the story names all four animal groups and their seasons",
		story.contains("cats") and story.contains("dogs") and story.contains("foxes")
		and story.contains("penguins") and story.contains("Spring") and story.contains("Winter"))
	_check("and it is about the wheel of the year, which the ending closes",
		story.contains("wheel") and Ending.RECAP.size() == 4)

	for index in range(1, StoryIntro.PAGES.size()):
		intro.next_button.pressed.emit()
		await _frames(2)
		var entry: Dictionary = StoryIntro.PAGES[index]
		_check("Next turns to page %d" % (index + 1),
			intro.page == index and intro.text_label.text == entry["text"]
			and intro.page_label.text == "%d / 5" % (index + 1))
		_check("page %d wears %s's colours" % [index + 1, entry["season"]],
			_primary_colour(intro.ui_root) == SeasonTheme.MAIN[entry["season"]])
		_check("page %d shows its picture" % (index + 1),
			(intro.views[entry["view"]] as Node2D).visible)
		if entry["view"] == "stuck":
			_check("the year-has-stopped picture is faded grey",
				(intro.views["stuck"] as Node2D).modulate.r < 0.7)
	await _seconds(StoryIntro.FADE_TIME + 0.3)
	var showing := 0
	for view_name: String in intro.views:
		if (intro.views[view_name] as Node2D).visible:
			showing += 1
	_check("pages turned quickly still leave exactly one picture: the last page's",
		showing == 1 and (intro.views[StoryIntro.PAGES[intro.page]["view"]] as Node2D).visible)
	_check("the last page's button says Let's go! and shows the controls",
		intro.next_button.text == "Let's go!" and intro.controls_label.visible)
	_check("the controls on it match the game's",
		intro.controls_label.text.contains("A / D") and intro.controls_label.text.contains("Enter"))
	return intro


# ------------------------------------------------------------------- the ending


func _test_the_ending() -> void:
	_emit("=== 2. the ending ===")
	var ending := ENDING_SCENE.instantiate() as Ending
	add_child(ending)
	await _frames(3)

	_check("it opens on black and fades in", ending.fade.color.a > 0.5)
	_check("the recap starts with Spring", ending.beat == 0 and not ending.finale_shown)
	_check("one season scene per season, Spring showing",
		ending.season_layers.size() == 4 and ending.season_layers[0].modulate.a == 1.0
		and ending.season_layers[1].modulate.a == 0.0)
	_check("the caption says what the cats did, in Spring's colours",
		ending.achievement_label.text == Ending.RECAP[0]["achievement"]
		and ending.badge.text == SeasonTheme.badge_text("spring")
		and _primary_colour(ending.ui_root) == SeasonTheme.MAIN["spring"])
	var goals := ""
	for entry in Ending.RECAP:
		goals += String(entry["goal"]) + " "
		_check("%s has a sustainability fact" % entry["season"],
			String(entry["fact"]).begins_with("Did you know?"))
	_check("the facts cover SDG 15, 12 and 13, as the proposal does",
		goals.contains("SDG 15") and goals.contains("SDG 12") and goals.contains("SDG 13"))
	await _seconds(1.2)
	_check("then the black fades away", ending.fade.color.a < 0.05)

	# Left alone, it goes through the four seasons and then the finale by itself.
	await _seconds(Ending.BEAT_TIME - 1.0)
	_check("after one beat it moves on to Summer, and the caption follows",
		ending.beat == 1 and ending.achievement_label.text == Ending.RECAP[1]["achievement"]
		and _primary_colour(ending.ui_root) == SeasonTheme.MAIN["summer"])
	await _seconds(Ending.BEAT_TIME * 2.0)
	_check("then Winter", ending.beat == 3 and not ending.finale_shown)
	await _seconds(Ending.BEAT_TIME + 0.6)
	_check("and then the finale comes up on its own", ending.finale_shown)
	_check_the_finale(ending)
	ending.queue_free()
	await _frames(2)

	# A second ending, skipped with Enter straight away.
	ending = ENDING_SCENE.instantiate() as Ending
	add_child(ending)
	await _frames(3)
	var enter := InputEventAction.new()
	enter.action = &"ui_accept"
	enter.pressed = true
	ending._unhandled_input(enter)
	await _frames(2)
	_check("Enter during the recap skips to the finale", ending.finale_shown)
	ending.queue_free()
	await _frames(2)


func _check_the_finale(ending: Ending) -> void:
	_check("the caption and the skip hint are gone, the congratulations are up",
		not ending.caption.visible and not ending.skip_hint.visible and ending.finale_box.visible)
	_check("all four seasons are shown side by side",
		ending.finale_holder.get_child_count() == 1
		and ending.finale_holder.get_child(0).get_child_count() == 4)
	_check("there is confetti", ending.confetti_holder.get_child_count() == Ending.CONFETTI_COUNT)
	var title := ending.find_child("Title", true, false) as Label
	_check("it says Congratulations!", title != null and title.text == "Congratulations!")
	_check("Play again has the keyboard and is wired to start Spring 1 again",
		ending.play_again_button.has_focus()
		and ending.play_again_button.pressed.is_connected(ending._on_play_again_pressed)
		and Ending.PLAY_AGAIN_SCENE == "res://scenes/Level.tscn")
	_check("Back to title is wired to the title screen",
		ending.title_button.pressed.is_connected(ending._on_back_to_title_pressed)
		and ResourceLoader.exists(Ending.TITLE_SCENE))
	var screen := Rect2(0, 0, 1280, 720)
	_check("both buttons are on screen",
		screen.encloses(ending.play_again_button.get_global_rect())
		and screen.encloses(ending.title_button.get_global_rect()))


# ------------------------------------------------------------------- helpers


func _primary_colour(control: Control) -> Color:
	var box := control.theme.get_stylebox("normal", "PrimaryButton") as StyleBoxFlat
	return box.bg_color if box != null else Color.BLACK


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


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
	GameSettings.save_path = _real_save_path
	_emit("")
	_emit("=".repeat(58))
	if ok and failures.is_empty():
		_emit("ALL CHECKS PASSED")
	else:
		_emit("FAILURES (%d): %s" % [failures.size(), ", ".join(failures)])
	_emit("")
	get_tree().quit(0 if ok and failures.is_empty() else 1)
