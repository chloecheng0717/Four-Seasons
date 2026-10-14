class_name Player
extends CharacterBody2D

const SPEED := 260.0
const GRAVITY := 1400.0
const JUMP_VELOCITY := -600.0
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.1
# Contact with the player underneath drops out for a frame or two while that
# player leaves the ground, so the ride link is held briefly across the gap.
const SUPPORT_GRACE := 0.1
# As the supporter rises it leaves a hair of space under a rider's feet, so a
# solid contact can drop out mid-ascent. Staying linked while we are still this
# close to our riding offset keeps the pair together without letting a rider
# that has genuinely walked away stick to a supporter standing on the ground.
const RIDE_CATCH := 10.0
const PLAYER_LAYER := 2
# How tall a carried gardening item is drawn beside the cat.
const CARRIED_ICON_HEIGHT := 40.0

# Ice, and only ice. A player standing on a slippery GroundTile takes time to
# build up to full speed and longer still to stop, which is what makes an ice
# patch feel different from the snow beside it. Acceleration is high so a patch
# is still perfectly playable; deceleration is far lower, so letting go of the
# direction on ice sends you sliding instead of stopping you dead. Both are
# compared against the same SPEED every other surface uses.
const ICE_ACCELERATION := 900.0
const ICE_DECELERATION := 260.0

@export var left_action: StringName = &"p1_left"
@export var right_action: StringName = &"p1_right"
@export var jump_action: StringName = &"p1_jump"
@export var label_text: String = "P1"

@export_group("Artwork")
@export var cat_texture: Texture2D
@export var cat_region: Rect2
@export_range(8.0, 512.0, 1.0) var display_height: float = 56.0

@onready var sprite: Sprite2D = $Cat
@onready var name_label: Label = $NameLabel
@onready var carried_icon: Sprite2D = $CarriedIcon

# The gardening item this player is holding, or &"" for empty hands. Only ever
# one, which is all the pot needs to keep the rule simple.
var carried_kind: StringName = &""
# Handed over by the item that was picked up, so putting it back does not mean
# this script has to know anything about the item scene. _use_up is the same
# thing for the other way an item can leave: the pot using it for good.
var _put_back: Callable = Callable()
var _use_up: Callable = Callable()
# Track carried fish separately so they don't interfere with normal item carrying
var _carried_fish: Array[Node2D] = []

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _support: Player = null
var _support_grace: float = 0.0
var _riders: Array[Player] = []
var _ride_offset := 0.0
var _body_height := 0.0
var _body_width := 0.0
# The height we finished our last physics step at, and whether we were moving
# riders on that step. A rider reads both to hold the height we actually reached,
# which is what makes the pair line up whichever of us the engine steps second.
var _seat_y := 0.0
var _carrying_riders := false
# Whether we are asking to move sideways ourselves this frame. A supporter leaves
# a rider that is steering on its own alone, instead of carrying it on top of the
# walk it is already doing.
var _steering := false


func _ready() -> void:
	_apply_artwork()
	name_label.text = label_text
	for child in get_children():
		var body := child as CollisionShape2D
		if body != null:
			var rect := body.shape as RectangleShape2D
			if rect != null:
				_body_height = rect.size.y
				_body_width = rect.size.x
			break


## Draws the assigned cat at a uniform scale (proportions are never distorted)
## with its feet exactly on the node origin, which is the collider's base.
func _apply_artwork() -> void:
	if cat_texture != null:
		sprite.texture = cat_texture

	var source_size: Vector2 = cat_region.size
	if source_size == Vector2.ZERO and sprite.texture != null:
		source_size = sprite.texture.get_size()
		sprite.region_enabled = false
	else:
		sprite.region_enabled = true
		sprite.region_rect = Rect2(cat_region.position, source_size)

	var uniform_scale: float = display_height / source_size.y
	sprite.scale = Vector2(uniform_scale, uniform_scale)
	sprite.offset = Vector2(0.0, -source_size.y * 0.5)


## Empty hands. A player already carrying something cannot pick up a second
## item, so the items are simply ignored until this one is delivered or handed
## back.
func can_pick_up() -> bool:
	return carried_kind == &""


## Called by a GardenItem the moment this player walks into it.
func pick_up(kind: StringName, texture: Texture2D, region: Rect2,
		put_back: Callable, use_up: Callable, item_node: Node2D = null) -> void:
	# The one place every pick-up passes through - garden items and fish alike -
	# so the sound is played once here and no item script needs to know about it.
	AudioManager.play_pickup()
	carried_kind = kind
	_put_back = put_back
	_use_up = use_up

	var source_size: Vector2 = region.size
	if source_size == Vector2.ZERO and texture != null:
		source_size = texture.get_size()
	carried_icon.texture = texture
	carried_icon.region_enabled = true
	carried_icon.region_rect = Rect2(region.position, source_size)
	var icon_scale: float = CARRIED_ICON_HEIGHT / source_size.y
	carried_icon.scale = Vector2(icon_scale, icon_scale)
	carried_icon.visible = true
	if item_node != null:
		_carried_fish.append(item_node)

	# The name label is left alone on purpose. The picture beside the cat already
	# says what is being carried, so there is no wording added here.


## Stops carrying the item and sends it back to wherever it came from. The pot
## hands an unwanted item back this way, and so does a player who jumps at the
## pot while holding one.
func drop_carried() -> void:
	if carried_kind == &"":
		return
	# Save callables before clearing
	var put_back = _put_back
	_clear_carrying()
	if put_back.is_valid():
		put_back.call()


## Stops carrying the item because the pot has actually taken it. The item is
## used up for good, so the put-back callback is deliberately never called and
## the item is not returned to the place it was found.
func consume_carried() -> void:
	if carried_kind == &"":
		return
	var use_up = _use_up
	_clear_carrying()
	if use_up.is_valid():
		use_up.call()


## Empties our hands. Deliberately calls neither callback: whether the item goes
## back to where it was found or gets used up is the caller's decision, not ours.
func _clear_carrying() -> void:
	carried_kind = &""
	_put_back = Callable()
	_use_up = Callable()
	carried_icon.visible = false
	name_label.text = label_text
	_carried_fish.clear()


## The other player, if any, that this one is resting on top of.
func _player_support() -> Player:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		# Floor normals point up the screen, i.e. negative y.
		if collision.get_normal().y < -0.7 and collision.get_collider() is Player:
			return collision.get_collider() as Player
	return null


## True when the surface we are actually standing on right now is a slippery tile.
##
## Read out of this step's own slide contacts rather than by looking around us, so
## it reports the ground under our feet and nothing else: standing on a slippery
## tile does not make us slippery in mid-air, and standing on snow right next to
## an ice patch does not either. Anything that is not a GroundTile - a plain wall,
## or another player we are riding - is not slippery.
func _on_slippery_surface() -> bool:
	if not is_on_floor():
		return false
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider is GroundTile and (collider as GroundTile).slippery:
			return true
	return false


## Puts this player back at a known-good spot with none of the co-op state left
## over, so a reset can never leave a pair half stacked, sliding on at the old
## speed, or still holding a link to a penguin that is no longer under them.
##
## Everything cleared here is state that a normal step manages on its own; doing it
## in one place means a reset and a level restart cannot disagree about what "clean"
## means. The carried item is deliberately left alone, because Winter has nothing
## to carry and reset is only ever about position and physics.
func reset_to_position(target: Vector2) -> void:
	# Drop both ends of any ride link first, so neither player is left holding a
	# reference to the other. Doing it for both in the level, not just for whoever
	# moved, is what stops a rider being welded to a supporter that has teleported
	# away underneath it.
	_set_support(null)
	_riders.clear()
	_steering = false
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_support_grace = 0.0
	_ride_offset = 0.0
	_carrying_riders = false
	_seat_y = 0.0
	velocity = Vector2.ZERO
	# A player that was mid-step with its player layer masked off would otherwise
	# come back unable to touch the other penguin.
	collision_mask |= PLAYER_LAYER
	global_position = target


func _set_support(new_support: Player) -> void:
	if _support == new_support:
		return
	if _support != null:
		_support._riders.erase(self)
	_support = new_support
	if _support != null:
		_support._riders.append(self)
		# A rider rests exactly one body height above us. Deriving that from the
		# collider rather than from where we happen to be keeps a link that forms
		# mid-jump from capturing a transient and flinging us later on.
		_ride_offset = -_body_height


## The riders still perched on our head. Horizontal overlap is what separates a
## player we are carrying from one that has stepped off to our side, so a rider
## that walks away stops being carried and is an ordinary collider again on the
## very next step instead of staying welded to us.
func _perched_riders() -> Array[Player]:
	var perched: Array[Player] = []
	for rider in _riders:
		if absf(rider.global_position.x - global_position.x) <= _body_width * 0.5:
			perched.append(rider)
	return perched


## Picks up or drops the ride link once this frame's movement has resolved.
func _update_support(delta: float) -> void:
	var found: Player = _player_support()

	# While we are riding a supporter it places us on top of itself and hides its
	# own collider from us, so it is the thing holding us up rather than a surface
	# we can run into. There is no contact left to detect, and the link has to be
	# kept off that instead or it would time out from under a standing rider.
	if found == null and _support != null and _support._riders.has(self) \
			and _support._perched_riders().has(self):
		found = _support

	# A supporter that has stopped carrying us leaves a hair of space under our
	# feet, and a solid contact can drop out from under us mid-ascent. Losing the
	# link there would make us collide with its head and cancel its jump, so a
	# supporter that is still rising keeps us for as long as we are this close to
	# our riding offset.
	if found == null and _support != null and _support.velocity.y < 0.0:
		var drift := global_position.y - _support.global_position.y - _ride_offset
		if absf(drift) <= RIDE_CATCH:
			found = _support

	if found != null:
		_support_grace = SUPPORT_GRACE
		_set_support(found)
	elif _support != null:
		_support_grace -= delta
		if _support_grace <= 0.0:
			_set_support(null)


func _physics_process(delta: float) -> void:
	var direction := Input.get_axis(left_action, right_action)
	_steering = not is_zero_approx(direction)

	# A player perched on our head is placed by us, not collided with by us, and
	# that goes both ways. Two player colliders resting face to face report a zero
	# collision normal, and move_and_slide cannot slide along that, so whichever of
	# the two is moving gets its motion cancelled and is shoved sideways by
	# depenetration instead. Ignoring the rider during our own step is not enough:
	# left colliding, the rider is the one that gets shoved off our head, and once
	# it has slid clear of us it is no longer a rider at all, which puts the player
	# layer straight back into our mask and freezes us mid-stride. So we ignore a
	# rider during our step and place it ourselves, and a rider ignores the
	# supporter it is on top of during its step for the same reason. Everybody
	# else, including a player we are not carrying, still collides exactly as
	# before.
	var carried := _perched_riders()
	var riding := _support != null and _support._riders.has(self) \
			and _support._perched_riders().has(self)
	var linked := not carried.is_empty() or riding
	if linked:
		collision_mask &= ~PLAYER_LAYER

	# The floor here can be another player, and a rider has no contact with its
	# supporter to query, so being carried counts as being grounded. Without this a
	# rider could never jump: its coyote timer would run out against a head it is
	# not allowed to touch, and its jump would be treated as mid-air.
	if is_on_floor() or riding:
		_coyote_timer = COYOTE_TIME
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	if Input.is_action_just_pressed(jump_action):
		_jump_buffer_timer = JUMP_BUFFER
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)

	# Snow, sand and Autumn's leaves all take this line, unchanged: full speed
	# immediately, and dead stop the instant the direction is released. Only a
	# tile that says it is slippery is allowed past it.
	if _on_slippery_surface():
		var target_speed: float = direction * SPEED
		var rate: float = ICE_ACCELERATION if not is_zero_approx(direction) else ICE_DECELERATION
		velocity.x = move_toward(velocity.x, target_speed, rate * delta)
	else:
		velocity.x = direction * SPEED
	velocity.y += GRAVITY * delta

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		# A jump of our own is deliberate, so leave the stack behind.
		_set_support(null)
		# Only a jump that actually happens makes the noise, so a held key in
		# mid-air stays silent.
		AudioManager.play_jump()

	# While rising we must not be snapped back down onto the surface we are
	# leaving, or the jump is cancelled before it has moved.
	var snap := floor_snap_length
	if velocity.y < 0.0:
		floor_snap_length = 0.0
	var step_from := global_position
	move_and_slide()
	floor_snap_length = snap

	if linked:
		collision_mask |= PLAYER_LAYER

	# We are the surface our riders stand on, so we own their height for as long
	# as they are perched on us, on the ground as much as in the air: they ignore
	# our layer during their own step, so contact is what used to hold them up
	# and it is gone. Holding them at one riding offset is also what makes them
	# keep their footing through a whole jump instead of sinking a step at a time
	# going up or sliding off the back of our head on the way down.
	_carrying_riders = not carried.is_empty()
	if _carrying_riders:
		_seat_y = global_position.y
		for rider in carried:
			rider.global_position.y = _seat_y + rider._ride_offset
			rider.velocity.y = 0.0

	# Walking takes a rider with it sideways, so it rides along instead of sliding
	# off the back of our head on our very first step. A rider pressing its own
	# direction is steering itself, so it is not carried a second time on top of
	# its own input; once it leaves our width it is no longer perched and this
	# stops applying to it at all.
	var step_x := global_position.x - step_from.x
	for rider in carried:
		if not rider._steering:
			rider.global_position.x += step_x

	_update_support(delta)

	# Being carried means our supporter owns our height, not us. It re-seats us at
	# the end of its own step, and it publishes the height that step ended at, so
	# repeating that here leaves the pair correctly spaced up no matter which of
	# the two the engine happens to step last.
	if _support != null and _support._carrying_riders and _support._riders.has(self):
		global_position.y = _support._seat_y + _ride_offset
		velocity.y = 0.0

	# Both cat textures are authored facing LEFT, so flipping is what turns them
	# right. The elif keeps the last facing while standing still.
	if direction > 0.0:
		sprite.flip_h = true
	elif direction < 0.0:
		sprite.flip_h = false
