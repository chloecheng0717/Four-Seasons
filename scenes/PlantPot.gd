class_name PlantPot
extends Area2D

## The Spring goal. A cat carries soil, then seeds, then water to this pot, in
## that order, and the plant grows into a flower. Anything else is refused, and
## a refused item is handed back if the cat jumps while standing at the pot, so
## a wrong pick-up can never dead-end a player.
##
## The stages, in the order they have to happen:
## EMPTY -> SOIL -> SEEDED -> SPROUT -> FLOWER.
## SEEDED deliberately reuses the soil picture. The seeds are down in the soil
## and nothing has come up yet, so there is nothing new to draw at that point.

signal level_complete()

enum Stage { EMPTY, SOIL, SEEDED, SPROUT, FLOWER }

## How long the sprout takes to grow into the flower on its own.
@export_range(0.5, 15.0, 0.1) var grow_time: float = 3.0

const STAGE_TEXTURES := {
	Stage.EMPTY: preload("res://assets/Spring/Pot_Empty.png"),
	Stage.SOIL: preload("res://assets/Spring/Pot_Soil.png"),
	Stage.SEEDED: preload("res://assets/Spring/Pot_Soil.png"),
	Stage.SPROUT: preload("res://assets/Spring/Pot_Sprout.png"),
	Stage.FLOWER: preload("res://assets/Spring/Pot_Flower.png"),
}

## The opaque part of each pot picture. The four pictures are four different
## sizes, and this is what keeps every stage standing on the same spot on the
## ground as the pot gets taller.
const STAGE_REGIONS := {
	Stage.EMPTY: Rect2(9, 4, 88, 56),
	Stage.SOIL: Rect2(9, 5, 88, 80),
	Stage.SEEDED: Rect2(9, 5, 88, 80),
	Stage.SPROUT: Rect2(8, 8, 104, 152),
	Stage.FLOWER: Rect2(7, 8, 104, 176),
}

@onready var sprite: Sprite2D = $Pot
@onready var status_label: Label = $Status

var stage: Stage = Stage.EMPTY

var _grow_timer: float = 0.0


func _ready() -> void:
	_apply_stage()


func _process(delta: float) -> void:
	if stage == Stage.FLOWER:
		return

	# Watered: the plant finishes growing by itself, nobody has to do anything.
	if stage == Stage.SPROUT:
		_grow_timer -= delta
		if _grow_timer <= 0.0:
			_set_stage(Stage.FLOWER)
		return

	# Polled rather than driven by body_entered, so a cat that is already
	# carrying the right thing can walk straight in and be served.
	var cats: Array[Player] = []
	for body in get_overlapping_bodies():
		if body is Player:
			cats.append(body as Player)
	if cats.is_empty():
		return

	# A cat carrying exactly what the pot wants next is served first. In Spring 2
	# the two cats bring the soil and the seeds to the pot together, and without
	# this the cat holding the seeds could stand in the way of the soil until it
	# walked off again. With only one cat here, this changes nothing.
	for cat in cats:
		if cat.carried_kind != &"" and cat.carried_kind == required_item():
			_serve(cat)
			return
	_serve(cats[0])


## The item this stage is waiting for, or &"" when it is not waiting for one.
func required_item() -> StringName:
	match stage:
		Stage.EMPTY:
			return &"soil"
		Stage.SOIL:
			return &"seeds"
		Stage.SEEDED:
			return &"water"
		_:
			return &""


func _next_stage() -> Stage:
	match stage:
		Stage.EMPTY:
			return Stage.SOIL
		Stage.SOIL:
			return Stage.SEEDED
		Stage.SEEDED:
			return Stage.SPROUT
		_:
			return stage


func _serve(player: Player) -> void:
	if player.carried_kind == &"":
		_refresh_status()
		return

	if player.carried_kind == required_item():
		_set_stage(_next_stage())
		# Only now, once the pot has actually taken it, is the item used up, and
		# used up means gone from the level for good rather than back where it was
		# found. This is the whole difference between the two ways an item leaves
		# a cat: drop_carried puts it back, this takes it out of the level.
		player.consume_carried()
		return

	# The wrong thing for this stage. Say what is wanted instead, and let the
	# player jump to put the item back, so nobody gets stuck holding it.
	status_label.text = "WRONG ITEM - JUMP TO PUT IT BACK"
	if Input.is_action_just_pressed(player.jump_action):
		player.drop_carried()
		_refresh_status()


func _set_stage(next_stage: Stage) -> void:
	stage = next_stage
	_grow_timer = grow_time
	_apply_stage()
	if stage == Stage.FLOWER:
		level_complete.emit()


## Redraws the pot for the current stage, standing on the ground the whole time.
func _apply_stage() -> void:
	var texture: Texture2D = STAGE_TEXTURES[stage]
	var region: Rect2 = STAGE_REGIONS[stage]

	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = region
	# Drawn from the bottom edge, so the pot grows upward out of the same spot.
	sprite.offset = Vector2(-region.size.x * 0.5, -region.size.y)

	status_label.position.y = -region.size.y - 34.0
	_refresh_status()


func _refresh_status() -> void:
	match stage:
		Stage.EMPTY:
			status_label.text = "NEEDS SOIL"
		Stage.SOIL:
			status_label.text = "NEEDS SEEDS"
		Stage.SEEDED:
			status_label.text = "NEEDS WATER"
		Stage.SPROUT:
			status_label.text = "GROWING..."
		_:
			status_label.text = ""
