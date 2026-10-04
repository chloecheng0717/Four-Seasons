class_name Icicle
extends Area2D

## One hanging icicle: a Winter hazard that drops when a penguin walks underneath
## it, can hit them, and is then finished for good.
##
## ## Why it is an Area2D and not a StaticBody2D
##
## Every other solid thing in this game - tiles, walls - is a body you stand on. An
## icicle is not that: it is something to avoid, and touching it sends both
## penguins back to the start rather than shoving them aside. So it detects with
## real Area2D collision against the players' own physics layer and never resolves
## as a surface. The detection is engine collision, not a hand-rolled distance or
## rectangle check in _process, so it cannot disagree with where the picture is.
##
## ## The node that hangs, and the node that moves
##
## The root never moves. It is the place on the ceiling the icicle hangs from, and
## the ground zone that starts the icicle is its child, sitting still on the floor
## for the whole level. Only an inner `Moving` node carries the picture and the
## falling hazard, and only that node is ever moved.
##
## That split is not tidiness, it is a bug fix. An earlier version moved the whole
## icicle, trigger included, and putting it back on its chain teleported the trigger
## from below the world back up onto the floor. Godot re-tests an area against the
## bodies it was overlapping the moment that area moves, and the body it was still
## holding was the penguin that had just been sent back to the start - whose
## position the physics engine had not caught up with yet. So the reset re-triggered
## the very icicle it was resetting, and the level could never settle. A trigger that
## never moves cannot be re-tested by its own motion, so it reports a penguin only
## when a penguin really is under the icicle.
##
## ## Three areas, on purpose
##
## The root does the bookkeeping and emits the signals, and two child areas sense:
##
##  - Trigger watches the ground under the icicle and is the only thing that can
##    start it. It is never switched on or off, so a trigger event always means what
##    it says. `state` is what decides, not the area's own monitoring.
##  - Hazard covers the icicle's own drawn body and only becomes live once the
##    icicle is FALLING, so a hanging icicle is never a hazard and a spent one can
##    never hit anybody again.
##  - The art between them is the picture, and is not itself anything.
##
## Separating them is what makes "not repeatedly killing the player forever" true by
## construction: once the icicle has fallen or has hit somebody, the hazard is
## switched off and it will not detect anything again until the level calls reset.

## The icicle is a hazard you avoid, not a surface. It sits on no layer at all - a
## nonzero layer would let other areas detect it - and it watches layer 2, which is
## where Player.gd puts every penguin.
const PLAYER_LAYER := 2

## How long the icicle rattles on the end of its chain before it lets go. Long
## enough to be a real warning and to be reacted to, short enough that standing
## under it is never a hiding place.
const WARNING_TIME := 0.9
## Downward acceleration while falling. Faster than the player's own 1400 so it
## genuinely catches them, but still readable.
const FALL_GRAVITY := 1800.0
## Terminal speed, deliberately modest: at 900px/s an icicle moves 15px in a physics
## frame, which is far less than the 60px width of a penguin, so the hazard area
## cannot step over a player between two frames without ever registering them. A
## faster fall would risk tunnelling and, with it, a hazard that silently misses.
const MAX_FALL_SPEED := 900.0
## The widest the icicle swings while warning, in pixels at full swing.
const SHAKE_MAX := 5.0
## How fast it rattles.
const SHAKE_HZ := 26.0
## How wide the ground zone is. Wider than the icicle itself, so it starts falling
## while the player is still clear of it rather than once they are already under it.
const TRIGGER_WIDTH := 150.0
## How tall the ground zone is. It reaches up far enough to catch a penguin who is
## mid-jump over the spot, not just one standing on it.
const TRIGGER_HEIGHT := 160.0

enum State { HANGING, WARNING, FALLING, SPENT }

## Emitted once, when this icicle's falling hazard touches a penguin. The level
## listens for this to send both penguins back to the start.
signal player_hit

@export var icicle_texture: Texture2D
@export var art_region: Rect2 = Rect2()
## How tall the icicle is drawn in the world. Its width follows from the artwork's
## own proportions, so the two are never distorted apart.
@export_range(32.0, 512.0, 1.0) var display_height: float = 248.0
## The surface the tip falls to. Normally the floor's top edge.
@export var ground_y: float = 560.0

@onready var moving: Node2D = $Moving
@onready var art: Sprite2D = $Moving/Art
@onready var trigger: Area2D = $Trigger
@onready var hazard: Area2D = $Moving/Hazard

var state: State = State.HANGING

var _warning_left := 0.0
var _warning_elapsed := 0.0
var _fall_speed := 0.0
## The drawn size of the picture, kept so the hazard area is always exactly the
## picture and cannot drift away from it.
var _art_size := Vector2.ZERO


func _ready() -> void:
	_art_size = art_region.size
	if _art_size == Vector2.ZERO and icicle_texture != null:
		_art_size = icicle_texture.get_size()

	var uniform_scale: float = display_height / _art_size.y
	art.texture = icicle_texture
	art.texture_filter = 1
	if art_region.size != Vector2.ZERO:
		art.region_enabled = true
		art.region_rect = art_region
	art.scale = Vector2(uniform_scale, uniform_scale)
	# Top edge of the picture on the moving node, so the node's y is where the
	# icicle hangs from and its tip is exactly display_height below it.
	art.offset = Vector2(0.0, _art_size.y * 0.5)

	# The ground zone under this icicle, sized and placed from the height it hangs
	# at so it works anywhere in the level. It is a child of the node that never
	# moves, so this is where it stays for the whole level.
	var trigger_shape := _box(TRIGGER_WIDTH, TRIGGER_HEIGHT)
	trigger.add_child(trigger_shape)
	trigger_shape.position = Vector2(
		0.0, ground_y - TRIGGER_HEIGHT * 0.5 - position.y)

	# The hazard area is exactly the drawn icicle: full drawn width, full drawn
	# height, hanging from the moving node.
	var hazard_shape := _box(_art_size.x * uniform_scale, display_height)
	hazard.add_child(hazard_shape)
	hazard_shape.position = Vector2(0.0, display_height * 0.5)

	trigger.collision_layer = 0
	trigger.collision_mask = PLAYER_LAYER
	trigger.body_entered.connect(_on_trigger_body_entered)

	hazard.collision_layer = 0
	hazard.collision_mask = PLAYER_LAYER
	hazard.body_entered.connect(_on_hazard_body_entered)

	# Only the hazard is switched off to begin with. A hanging icicle is scenery.
	hazard.set_deferred("monitoring", false)


func _box(width: float, height: float) -> CollisionShape2D:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, height)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	return collision


func _physics_process(delta: float) -> void:
	match state:
		State.WARNING:
			_tick_warning(delta)
		State.FALLING:
			_tick_fall(delta)


## The rattle. The swing grows as the warning runs out, so an icicle that has been
## hanging a while is visibly closer to going than one that has just been reached.
## Only the picture and the hazard shake; the ground zone stays under the icicle.
func _tick_warning(delta: float) -> void:
	_warning_left -= delta
	_warning_elapsed += delta
	var progress: float = clampf(1.0 - _warning_left / WARNING_TIME, 0.0, 1.0)
	var swing: float = SHAKE_MAX * progress
	moving.position.x = sin(_warning_elapsed * SHAKE_HZ) * swing
	moving.rotation = sin(_warning_elapsed * SHAKE_HZ * 0.5) * 0.03 * progress
	if _warning_left <= 0.0:
		_drop()


## The fall. The tip stops at ground_y, which is where the floor's surface is, so
## the icicle ends up lying along the ground it was hanging over rather than sinking
## into it.
func _tick_fall(delta: float) -> void:
	_fall_speed = minf(_fall_speed + FALL_GRAVITY * delta, MAX_FALL_SPEED)
	moving.position.y += _fall_speed * delta
	if moving.position.y + display_height >= ground_y - position.y:
		moving.position.y = ground_y - position.y - display_height
		_spend()


## Something walked into the ground zone under a hanging icicle. Only a hanging
## icicle can be started this way, and the `state` check is the only thing standing
## between a penguin and an icicle that has already gone, which is why the trigger
## area itself never has to be switched off and on again.
func _on_trigger_body_entered(body: Node2D) -> void:
	if state != State.HANGING:
		return
	if not body is Player:
		return
	state = State.WARNING
	_warning_left = WARNING_TIME
	_warning_elapsed = 0.0


## The falling icicle touched a penguin.
func _on_hazard_body_entered(body: Node2D) -> void:
	if state != State.FALLING:
		return
	if not body is Player:
		return
	player_hit.emit()
	_spend()


func _drop() -> void:
	state = State.FALLING
	moving.position = Vector2.ZERO
	moving.rotation = 0.0
	_fall_speed = 0.0
	# The hazard comes live exactly as the icicle starts moving. Nothing can be
	# inside it yet - it starts at the top of the level, far above the top of any
	# jump a penguin can make - so switching it on here cannot hit somebody who was
	# merely standing nearby.
	hazard.set_deferred("monitoring", true)


## This icicle is finished. It stops existing as a hazard and stays that way until
## the level resets it, which is what stops one icicle from killing the players over
## and over for the rest of the attempt.
func _spend() -> void:
	state = State.SPENT
	_fall_speed = 0.0
	moving.rotation = 0.0
	art.visible = false
	hazard.set_deferred("monitoring", false)


## Puts the icicle back on its chain exactly as it was found. Called by the level
## for every icicle whenever the penguins are sent back to the start, so a reset
## really does clear Winter's temporary hazard state and not just the players'.
##
## Only the inner moving node is touched. The ground zone is not moved at all, which
## is what makes a reset safe: nothing here can drag a sensing area back across a
## penguin and make the engine report an overlap that is not really there.
func reset() -> void:
	state = State.HANGING
	moving.position = Vector2.ZERO
	moving.rotation = 0.0
	_fall_speed = 0.0
	_warning_left = 0.0
	_warning_elapsed = 0.0
	art.visible = true
	hazard.set_deferred("monitoring", false)