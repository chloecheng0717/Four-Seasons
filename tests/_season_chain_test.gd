extends Node2D

## End-to-end checks for the legs of the season chain that the other suites only
## ever read as constants.
##
## Spring -> Summer is already proven for real by _next_level_test, which plays a
## whole Spring run and presses the button. This file covers the other two legs:
##
##   -- --autumn-check   builds the real SummerLevel and drives its Next Level
##                       handler. AutumnLevel sees the flag, prints
##                       "NEXT LEVEL REACHED AUTUMN" and quits 0.
##   -- --winter-check   builds the real AutumnLevel and drives its Next Level
##                       handler. WinterLevel sees the flag, prints
##                       "NEXT LEVEL REACHED WINTER" and quits 0.
##
## The two legs cannot share a run, because --autumn-check makes Autumn quit the
## moment it loads, which would stop the Winter leg from ever starting.
##
## Why calling the handler counts as pressing the button: the suites for those two
## levels both assert, separately, that the Next Level TextureButton's `pressed`
## signal really is connected to this exact handler. So invoking the handler runs
## precisely the code a real click runs. What this file adds on top is the part
## those suites cannot check without freeing themselves: that the scene change
## really happens, and that the destination really loads, builds and runs.
##
## Before handing over it also checks the level's completion screen is genuinely up
## and the button genuinely pressable, so a handler invoked out of nowhere cannot
## pass this file on its own.
##
## Note on the press: the scene change frees this node along with the level, so
## after the handler is called the test awaits nothing and lets its _process
## watchdog complain if it is somehow still alive. Freed means the destination took
## over; still-alive means the change never happened.

const SUMMER_SCENE := "res://scenes/SummerLevel.tscn"
const AUTUMN_SCENE := "res://scenes/AutumnLevel.tscn"
const WINTER_SCENE := "res://scenes/WinterLevel.tscn"

var level: Node2D

var failures: Array[String] = []
var _elapsed := 0.0
var _handed_over := false
var _finished := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var to_winter := args.has("--winter-check")
	var to_autumn := args.has("--autumn-check")

	# Fail in a second with the invocation it needs, rather than hanging until the
	# runner's timeout kills a run that can never reach a destination's own quit.
	if not to_winter and not to_autumn:
		_check("this test needs --winter-check or --autumn-check", false,
			" run: --scene res://tests/_season_chain_test.tscn -- --winter-check")
		_finish(false)
		return

	var source := AUTUMN_SCENE if to_winter else SUMMER_SCENE
	level = (load(source) as PackedScene).instantiate()
	add_child(level)
	await get_tree().process_frame
	_gather.call_deferred()


## Safety net. If the scene change never happens this test is still alive at the end
## of its own run, which is the failure the destination's quit cannot report.
func _process(delta: float) -> void:
	if _finished or _handed_over:
		return
	_elapsed += delta
	if _elapsed > 90.0:
		_check("the scene change actually happened", false,
			" still running after %.0fs, so nothing was ever loaded" % _elapsed)
		_finish(false)


## The completion nodes are found by name rather than by path, because the seasons
## do not agree on where they live: Summer hangs LevelComplete and NextLevel
## straight off the root, while Autumn and Winter put them under a UI node. All of
## them are the same shared banner and the same shared button.
func _gather() -> void:
	var banner := level.find_child("LevelComplete", true, false) as Sprite2D
	var button := level.find_child("NextLevel", true, false) as TextureButton

	_check("the level really built", level.get_script() != null
		and level.get_child_count() > 0)
	_check("its completion banner and Next Level button are the shared ones",
		banner != null and button != null)
	if button == null or banner == null:
		_finish(false)
		return

	# Drive the level to its finished state through its own handler, then wait out the
	# banner pause it declares, so the completion screen goes up exactly as it does
	# for a real player. Autumn reaches this handler from its last leaf being placed
	# and Summer from its last piece of rubbish being sorted; both of those counting
	# paths are proven by their own suites, and this file is about what happens next.
	var delay: float = level.get("complete_banner_delay")
	_emit("-- finishing %s, then waiting out its %.2fs banner pause --"
		% [source_name(), delay])
	level.call("_finish_level")
	await _wait(delay + 0.75)
	await get_tree().process_frame

	_check("finishing really did put the completion screen up",
		banner.visible and button.visible and not button.disabled,
		" banner=%s button=%s disabled=%s" % [banner.visible, button.visible, button.disabled])
	_check("and the button really is wired to the handler this test calls",
		button.pressed.is_connected(level._on_next_level_pressed))

	_emit("-- pressing Next Level --")
	_handed_over = true
	level._on_next_level_pressed()


## Waits real time, in physics frames, so the level's own timers can run.
func _wait(seconds: float) -> void:
	for _i in maxi(int(seconds * 60.0), 1):
		await get_tree().physics_frame


func source_name() -> String:
	return "Autumn" if level.get_script().resource_path.ends_with("AutumnLevel.gd") else "Summer"


func _check(label: String, ok: bool, detail := "") -> void:
	if ok:
		_emit("  PASS  %s  %s" % [label, detail])
	else:
		failures.append(label)
		_emit("  FAIL  %s  %s" % [label, detail])


func _emit(line: String) -> void:
	print(line)


func _finish(ok: bool) -> void:
	if _finished:
		return
	_finished = true
	_emit("")
	_emit("=".repeat(58))
	if ok and failures.is_empty():
		_emit("ALL CHECKS PASSED")
		_emit("")
	else:
		_emit("FAILURES (%d): %s" % [failures.size(), ", ".join(failures)])
		_emit("")
	get_tree().quit(0 if ok and failures.is_empty() else 1)