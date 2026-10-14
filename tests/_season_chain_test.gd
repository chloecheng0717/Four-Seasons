extends Node2D

## End-to-end checks for the legs of the level chain that the other suites only
## ever read as constants.
##
## The full chain is Spring 1 -> Spring 2 -> Summer 1 -> Summer 2 -> Autumn 1 ->
## Autumn 2 -> Winter 1 -> Winter 2 -> Ending. Spring 1 -> Spring 2 is already
## proven for real by _next_level_test, which plays a whole Spring run and presses
## the button. This file covers every other leg, one leg per run, picked by the
## user argument. Each argument is named after the DESTINATION, which sees it,
## prints "NEXT LEVEL REACHED ..." and quits 0:
##
##   -- --summer-check    Spring 2 -> Summer 1
##   -- --summer2-check   Summer 1 -> Summer 2
##   -- --autumn-check    Summer 2 -> Autumn 1
##   -- --autumn2-check   Autumn 1 -> Autumn 2
##   -- --winter-check    Autumn 2 -> Winter 1
##   -- --winter2-check   Winter 1 -> Winter 2
##   -- --ending-check    Winter 2 -> Ending
##
## The legs cannot share a run, because each destination quits the moment it
## loads, which would stop the next leg from ever starting.
##
## Why calling the handler counts as pressing the button: the suites for the
## levels assert, separately, that the Next Level TextureButton's `pressed` signal
## really is connected to this exact handler, and this file checks it again. So
## invoking the handler runs precisely the code a real click runs. What this file
## adds on top is the part those suites cannot check without freeing themselves:
## that the scene change really happens, and that the destination really loads.
##
## Before handing over it also checks the level's completion screen is genuinely up
## and the button genuinely pressable, so a handler invoked out of nowhere cannot
## pass this file on its own.
##
## Note on the press: the scene change frees this node along with the level, so
## after the handler is called the test awaits nothing and lets its _process
## watchdog complain if it is somehow still alive. Freed means the destination took
## over; still-alive means the change never happened.

## destination flag -> [the level the leg starts from, its name in the output]
const LEGS := {
	"--summer-check": ["res://scenes/SpringLevel2.tscn", "Spring 2"],
	"--summer2-check": ["res://scenes/SummerLevel.tscn", "Summer 1"],
	"--autumn-check": ["res://scenes/SummerLevel2.tscn", "Summer 2"],
	"--autumn2-check": ["res://scenes/AutumnLevel.tscn", "Autumn 1"],
	"--winter-check": ["res://scenes/AutumnLevel2.tscn", "Autumn 2"],
	"--winter2-check": ["res://scenes/WinterLevel.tscn", "Winter 1"],
	"--ending-check": ["res://scenes/WinterLevel2.tscn", "Winter 2"],
}

var level: Node2D
var source_name := ""

var failures: Array[String] = []
var _elapsed := 0.0
var _handed_over := false
var _finished := false


func _ready() -> void:
	var source := ""
	for flag: String in LEGS:
		if OS.get_cmdline_user_args().has(flag):
			source = LEGS[flag][0]
			source_name = LEGS[flag][1]

	# Fail in a second with the invocation it needs, rather than hanging until the
	# runner's timeout kills a run that can never reach a destination's own quit.
	if source == "":
		_check("this test needs one of: %s" % ", ".join(LEGS.keys()), false,
			" run: --scene res://tests/_season_chain_test.tscn -- --winter-check")
		_finish(false)
		return

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


## The completion nodes are found by name rather than by path, because the levels
## do not agree on where they live: the one-screen levels hang LevelComplete and
## NextLevel straight off the root, while the scrolling ones put them under a UI
## node. All of them are the same shared banner and the same shared button.
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
	# for a real player. Spring calls this handler _on_level_complete (the pot's
	# signal); every other season calls it _finish_level. The counting paths that
	# lead to it are proven by each season's own suite; this file is about what
	# happens next.
	var delay: float = level.get("complete_banner_delay")
	_emit("-- finishing %s, then waiting out its %.2fs banner pause --"
		% [source_name, delay])
	if level.has_method("_finish_level"):
		level.call("_finish_level")
	else:
		level.call("_on_level_complete")
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
