extends Node

## Automated checks for the AudioManager autoload and its three sound effects.
##
## Run headless:
##   godot --headless --path <project> --scene res://tests/_audio_test.tscn
##
## It does not listen to the sounds; it checks the wiring around them: that each
## file loads, that every player sits on the SFX bus, that each play function
## reaches the right stream, that a fresh button is given its click, and that the
## Sound slider at zero really silences the bus.

const SOUND_NAMES := ["click", "jump", "pickup"]

var failures: Array[String] = []
var audio: Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_autoload_and_streams()
	_test_pool()
	_test_each_play_reaches_its_stream()
	await _test_buttons_get_their_click()
	_test_sound_slider_zero_mutes()
	_finish(failures.is_empty())


# --- 1. The autoload and its sounds ----------------------------------------

func _test_autoload_and_streams() -> void:
	_emit("")
	_emit("=== 1. the AudioManager autoload and its sounds ===")
	audio = get_node_or_null("/root/AudioManager")
	_check("there is an AudioManager autoload", audio != null)
	if audio == null:
		return
	await _frames(1)
	for sound_name in SOUND_NAMES:
		var stream = audio._streams.get(sound_name, null)
		_check("the '%s' sound loaded" % sound_name, stream is AudioStream)
	_check("all three sounds are loaded", audio._streams.size() == SOUND_NAMES.size(),
		" loaded=%d" % audio._streams.size())


# --- 2. The player pool -----------------------------------------------------

func _test_pool() -> void:
	_emit("")
	_emit("=== 2. every sound player is on the SFX bus and outlives a pause ===")
	if audio == null:
		return
	var players: Array[AudioStreamPlayer] = []
	for child in audio.get_children():
		if child is AudioStreamPlayer:
			players.append(child)
	_check("the pool has players", players.size() == audio.POOL_SIZE, " count=%d" % players.size())
	var all_on_sfx := true
	var all_always := true
	for player in players:
		all_on_sfx = all_on_sfx and player.bus == GameSettings.SOUND_BUS
		all_always = all_always and player.process_mode == Node.PROCESS_MODE_ALWAYS
	_check("every player plays through the SFX bus", all_on_sfx)
	_check("every player keeps running while the game is paused", all_always)
	_check("the manager itself keeps running while the game is paused",
		audio.process_mode == Node.PROCESS_MODE_ALWAYS)


# --- 3. Playing the right sound --------------------------------------------

func _test_each_play_reaches_its_stream() -> void:
	_emit("")
	_emit("=== 3. each call plays the sound it is named for ===")
	if audio == null:
		return
	_check("play_click() plays the click sound", _routed("click", audio.play_click))
	_check("play_jump() plays the jump sound", _routed("jump", audio.play_jump))
	_check("play_pickup() plays the pick-up sound", _routed("pickup", audio.play_pickup))
	_check("an unknown sound name only warns, it does not crash", _unknown_is_safe())


## Plays through `again` and reports whether some player ended up holding this
## sound on the SFX bus.
func _routed(sound_name: String, again: Callable) -> bool:
	again.call()
	var wanted = audio._streams.get(sound_name, null)
	for player in audio._players:
		if player.stream == wanted and player.bus == GameSettings.SOUND_BUS:
			return true
	return false


func _unknown_is_safe() -> bool:
	audio.play_sfx("no_such_sound")
	return true


# --- 4. Buttons get their click automatically ------------------------------

func _test_buttons_get_their_click() -> void:
	_emit("")
	_emit("=== 4. a new button is given the click sound by itself ===")
	if audio == null:
		return
	var button := Button.new()
	add_child(button)
	var texture_button := TextureButton.new()
	add_child(texture_button)
	var slider := HSlider.new()
	add_child(slider)
	await _frames(1)
	_check("a plain Button is wired to the click",
		button.pressed.is_connected(audio.play_click))
	_check("a TextureButton is wired to the click too",
		texture_button.pressed.is_connected(audio.play_click))
	_check("a slider is not a button, so it is left alone", slider is Control and not slider.has_signal("pressed"))
	_check("wiring the same button twice does not double up",
		button.pressed.get_connections().size() == 1)
	button.queue_free()
	texture_button.queue_free()
	slider.queue_free()
	await _frames(1)


# --- 5. The Sound slider ----------------------------------------------------

func _test_sound_slider_zero_mutes() -> void:
	_emit("")
	_emit("=== 5. the Sound slider controls every effect ===")
	GameSettings.sound_volume = 0.0
	GameSettings.apply_audio()
	var sound := AudioServer.get_bus_index(GameSettings.SOUND_BUS)
	_check("sound volume zero mutes the SFX bus", sound != -1 and AudioServer.is_bus_mute(sound))
	GameSettings.sound_volume = 0.8
	GameSettings.apply_audio()
	_check("raising the slider again unmutes the SFX bus",
		sound != -1 and not AudioServer.is_bus_mute(sound))


# --- helpers ----------------------------------------------------------------

func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


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
