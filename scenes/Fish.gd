class_name Fish
extends Area2D

## One of Winter's two fish: the thing a penguin has to collect before the igloo is
## allowed to finish the level.
##
## ## It is polled, not driven by body_entered
##
## GardenItem reads get_overlapping_bodies() every frame instead of listening for
## body_entered, and this does the same for the same reason. A penguin that is
## already inside the box when monitoring comes back on has not "entered" anything,
## so a signal would miss it - and a penguin who walks into the box, walks out, and
## walks back in has to be collected either way. Polling means a penguin is collected
## the moment it is genuinely touching the fish, however it got there.
##
## ## It is not freed when it is collected
##
## GardenItem ends in queue_free(), because a used-up gardening item never comes back
## and there is nowhere to put it. A Winter fish does come back: an icicle hit is the
## level restarting, and the fish have to be lying there again for the attempt that
## follows. So collecting hides the fish and switches its own monitoring off, and
## reset() puts both back. Same shape as Igloo.reset(), which is the other Winter
## object that has to survive a reset.

## The fish watches layer 2, which is where Player.gd puts every penguin. It sits on no
## layer of its own: a collectible is something the player finds, not something the
## world can bump into.
const PLAYER_LAYER := 2

## Emitted exactly once, when a penguin collects this fish, carrying this fish's own
## index in the level's FISHES table so the level never has to rely on child order to
## tell the two apart.
signal collected(index: int)

@export var fish_texture: Texture2D
@export var art_region: Rect2 = Rect2()
## How tall the fish is drawn. Its width follows from the artwork's proportions.
@export_range(16.0, 256.0, 1.0) var display_height: float = 60.0
## The pickup box, centred on the fish.
@export_range(8.0, 128.0, 1.0) var pickup_size: float = 64.0
## Which fish this is, handed in by the level.
@export var fish_index: int = 0

@onready var art: Sprite2D = $Art
@onready var pickup: CollisionShape2D = $Pickup

## True once a penguin has this one. It is the flag the whole fish turns on, and the
## thing reset() has to put back.
var is_collected: bool = false
var _spawn_position: Vector2
var _carried_by: Player = null
var _put_back: Callable = Callable()
var _use_up: Callable = Callable()


func _ready() -> void:
	_spawn_position = global_position
	var source_size := art_region.size
	if source_size == Vector2.ZERO and fish_texture != null:
		source_size = fish_texture.get_size()
		art.region_enabled = false

	var uniform_scale: float = display_height / source_size.y
	art.texture = fish_texture
	art.texture_filter = 1
	if art_region.size != Vector2.ZERO:
		art.region_enabled = true
		art.region_rect = art_region
	art.scale = Vector2(uniform_scale, uniform_scale)
	# Deliberately NOT offset the way Igloo does. Igloo shifts its picture up by half its
	# own height because the node it hangs from is the ground the igloo stands ON, and
	# the drawing wants to sit above that point. A fish hangs in mid-air and its position
	# is the middle of it, so the picture wants to be centred on the node and the
	# pickup box with it. Offsetting here would float the artwork a whole body-height
	# above the box that actually collects it.
	art.offset = Vector2.ZERO

	var shape := RectangleShape2D.new()
	shape.size = Vector2(pickup_size, pickup_size)
	pickup.shape = shape

	collision_layer = 0
	collision_mask = PLAYER_LAYER


## Watched every frame, so a penguin is collected the moment it is really touching the
## fish - including one that was teleported straight onto it by a reset.
##
## The monitoring check is not redundant with is_collected. reset() clears the flag
## immediately but turns monitoring back on deferred, because the physics server will not
## let it change mid-step. For that one frame the flag says "available" and the server
## says "asleep", and asking an area that is not monitoring for overlaps is an error, not
## an empty list. Asking anyway is worse than the error: it could report a penguin as
## touching a fish that is not switched on yet.
##
## Every overlapping penguin counts, and deliberately NOT one that has to pass
## can_pick_up() first. That gate belongs to the Spring gardening items, where a cat
## may hold only one thing because it has to carry it to one pot and be told "wrong
## item" if it brings the wrong one. A fish has no destination and no wrong answer: it
## is collected by touching it and it is gone from the world. Winter has exactly two of
## them and the igloo needs both, so a penguin that has already picked one up has to be
## able to pick the other one up too - otherwise a single penguin could lock itself out
## of finishing the level by collecting the first fish, and the second player would have
## to cross the whole level again to undo it. The fish is still shown in the penguin's
## hands; it just does not reserve them.
func _process(_delta: float) -> void:
	if is_collected or not monitoring:
		return

	for body in get_overlapping_bodies():
		if body is Player:
			_collect(body as Player)
			return


## Taken. The fish is attached to the collecting penguin and does not leave the tree,
## because the level has to be able to put it back.
func _collect(by: Player = null) -> void:
	# Guarded, so a second overlapping body on the same frame cannot report it twice.
	if is_collected:
		return

	is_collected = true
	visible = false
	_carried_by = by
	_put_back = Callable(self, "respawn")
	_use_up = Callable(self, "respawn")
	# Handed to the penguin so the fish is visibly being carried, and so this node is
	# tracked as what that penguin is holding: reset() uses _carried_by to empty the
	# hands before putting the fish back. Both callables are respawn(), because a fish
	# is never used up for good - an icicle hit brings it back - so there is only one
	# way out of a penguin's hands.
	if by != null:
		by.pick_up(StringName("fish_%d" % fish_index), fish_texture, art_region,
			_put_back, _use_up, self)
	# Monitoring off as well as invisible, so there is no frame in which an invisible
	# fish could still be picked up. Deferred, because changing this while the physics
	# server is busy is not allowed.
	set_deferred(&"monitoring", false)
	set_deferred(&"monitorable", false)
	collected.emit(fish_index)


## Puts the fish back where it was, exactly as it started, for when an icicle sends
## both penguins back to the beginning and the attempt starts again.
func respawn() -> void:
	global_position = _spawn_position
	is_collected = false
	visible = true
	_carried_by = null
	set_deferred(&"monitoring", true)
	set_deferred(&"monitorable", true)


## The whole reset for this fish, and the way an icicle hit puts a collected one back.
##
## If a penguin is holding it, its hands are emptied first, so no penguin is left
## holding a picture of a fish that is lying back on the ice where it started. The two
## are done in that order because _clear_carrying() drops the carried node's callbacks
## and this fish is one of the things that could call respawn() through them.
func reset() -> void:
	if _carried_by != null:
		_carried_by._clear_carrying()
		_carried_by = null
	respawn()