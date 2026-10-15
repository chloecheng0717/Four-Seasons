extends Node

## The game's sound effects, in one place.
##
## Sounds play through a small pool of AudioStreamPlayer nodes on the "SFX" bus,
## so two starting at once - a jump and a pick-up - do not cut each other off,
## and the Sound slider in Settings controls every one of them. The pool stays
## awake while the game is paused, so the click from Resume or Back is heard.
##
## The streams are loaded and checked at start-up: a sound whose file is missing
## is skipped with a warning instead of stopping the game. Play one with
## AudioManager.play_click(), play_jump() or play_pickup().

## The file behind each sound name, the keys play_sfx() takes.
const SOUND_PATHS := {
	"click": "res://assets/SoundEffects/Click.wav",
	"jump": "res://assets/SoundEffects/Jump.wav",
	"pickup": "res://assets/SoundEffects/Pick_Up_Item.wav",
}

## How many sounds may overlap before the oldest player is borrowed again.
const POOL_SIZE := 8

var _streams := {}
var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	# Make the SFX bus and the saved volumes exist now, even if the settings menu
	# has never been opened, so the very first sound is already at the right level.
	GameSettings.ensure_loaded()
	GameSettings.apply_audio()
	_load_sounds()

	# The pool and this node keep working while the tree is paused; otherwise the
	# click on Resume would be swallowed by the pause it is meant to end.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for _i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = GameSettings.SOUND_BUS
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_players.append(player)

	# Every button in the game gets its click this way, wherever it lives, so no
	# scene has to be edited by hand. node_added fires for the buttons of a scene
	# as it loads, which covers the title and every level's menus.
	get_tree().node_added.connect(_on_node_added)


## Reads each sound once. A missing or unreadable file is warned about and only
## that sound is unavailable; the others still play.
func _load_sounds() -> void:
	for sound_name in SOUND_PATHS:
		var path: String = SOUND_PATHS[sound_name]
		if not ResourceLoader.exists(path):
			push_warning("AudioManager: sound '%s' is missing (%s)" % [sound_name, path])
			continue
		var stream := load(path) as AudioStream
		if stream == null:
			push_warning("AudioManager: '%s' is not an audio stream (%s)" % [sound_name, path])
			continue
		_streams[sound_name] = stream


## Plays one sound by name. An unknown name does nothing but warn.
func play_sfx(sound_name: String) -> void:
	var stream: AudioStream = _streams.get(sound_name, null)
	if stream == null:
		push_warning("AudioManager: no sound called '%s'" % sound_name)
		return
	var player := _next_player()
	player.stream = stream
	player.play()


func play_click() -> void:
	play_sfx("click")


func play_jump() -> void:
	play_sfx("jump")


func play_pickup() -> void:
	play_sfx("pickup")


## The next free player, so a new sound does not cut off one still playing. When
## every player is busy the first is reused.
func _next_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	return _players[0]


## Gives a button its click. Sliders and other controls are not BaseButtons, so
## they are left alone and a dragged slider stays silent.
func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button == null:
		return
	if not button.pressed.is_connected(play_click):
		button.pressed.connect(play_click)

