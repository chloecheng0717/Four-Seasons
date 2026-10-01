class_name GardenItem
extends Area2D

## One thing a cat can carry to the pot: soil, seeds or water.
##
## A cat picks an item up simply by standing in it, and can only hold one at a
## time. There is exactly one of each item in the level, so it only ever leaves
## the level in one of two ways. If the pot does not want it, the pot hands it
## back and it goes to its spawn point to be picked up again (see PlantPot), so
## a wrong pick-up can never leave a cat stuck holding something useless. If the
## pot does want it, the item is used up and is taken out of the level for good.
## It is never recreated and never comes back.

@export var item_kind: StringName = &"soil"
@export var item_texture: Texture2D
## The opaque part of item_texture. The pictures come with a lot of empty
## padding around them, so without this the item would be drawn mostly air.
@export var art_region: Rect2
@export_range(16.0, 256.0, 1.0) var display_height: float = 56.0
## The square box that picks this item up. Usually a little smaller than the
## picture, so what has to be touched is the item itself and not the air around
## it. The water up in the corner needs a small one to stay out of a single
## cat's reach.
@export_range(8.0, 128.0, 1.0) var pickup_size: float = 48.0
## A short pause after the item is put back, so the physics server has had a
## frame to forget where the item used to be before it can be picked up again.
@export_range(0.0, 2.0, 0.05) var respawn_delay: float = 0.35

@onready var sprite: Sprite2D = $Sprite
@onready var body: CollisionShape2D = $CollisionShape2D

var is_collected: bool = false
## True once the pot has used this item up. The node is removed from the level
## and never comes back, so this only exists so the script knows for certain that
## a freed item cannot be picked up, put back or offered to the pot again.
var is_consumed: bool = false

var _spawn_position: Vector2
var _respawn_timer: float = 0.0


func _ready() -> void:
	_spawn_position = global_position
	if item_texture != null:
		sprite.texture = item_texture
	sprite.region_enabled = true
	sprite.region_rect = art_region
	var uniform_scale: float = display_height / art_region.size.y
	sprite.scale = Vector2(uniform_scale, uniform_scale)

	# A shape of its own, so the box can be sized per item without editing the
	# scene by hand.
	var shape := RectangleShape2D.new()
	shape.size = Vector2(pickup_size, pickup_size)
	body.shape = shape


## Watched every frame rather than on body_entered, so a cat that walks away
## from an item and comes back, or simply stands still next to it, still gets it.
func _process(delta: float) -> void:
	if is_collected or is_consumed:
		return
	if _respawn_timer > 0.0:
		_respawn_timer -= delta
		return

	for body in get_overlapping_bodies():
		if body is Player and (body as Player).can_pick_up():
			_collect(body as Player)
			return


func _collect(by: Player) -> void:
	is_collected = true
	visible = false
	# The item hands over everything needed to show it on the cat, plus the only
	# two ways an item can leave a cat's hands: put back where it was found, or
	# used up for good. The cat never has to know what type of thing this is.
	by.pick_up(item_kind, item_texture, art_region,
		Callable(self, "respawn"), Callable(self, "consume"))


## Puts the item back where it started and lets it be picked up again. This is
## what happens to a thing the pot did not want.
func respawn() -> void:
	# A used up item is gone. There is nowhere left to put it back to.
	if is_consumed:
		return
	global_position = _spawn_position
	visible = true
	_respawn_timer = respawn_delay
	is_collected = false


## Used up by the pot, so it is not coming back. The node is taken out of the
## level for good instead of being put back on its spawn point, so the item can
## never be seen, picked up or offered to the pot a second time.
func consume() -> void:
	if is_consumed:
		return
	is_consumed = true
	is_collected = true
	# Stop the pickup box noticing anything before the node actually goes, so
	# there is no frame in which a cat could grab it again. Deferred, because
	# changing this while the physics server is busy is not allowed.
	set_deferred(&"monitoring", false)
	set_deferred(&"monitorable", false)
	visible = false
	queue_free()
