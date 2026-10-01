class_name TrashBin
extends Area2D

## One Summer rubbish bin. A dog carries rubbish to the bin that takes it, the
## bin keeps it and the rubbish is used up for good. Anything else is refused:
## the dog keeps holding what it was carrying and the level says "Wrong bin!".
##
## This is deliberately the same shape as PlantPot rather than something new: it
## is an Area2D that watches which dogs are standing in it, decides what to do,
## and hands the item's fate back to the dog through the same two callables the
## gardening items use. The whole difference is that there are three bins, each
## taking one kind of rubbish, instead of one pot wanting three things in a row.
##
## A refused item is NOT put back, unlike Spring's pot, which hands a wrong item
## back when the dog jumps. Here the dog simply keeps carrying it and walks to
## the right bin, so there is nothing to undo and no hand-back to remember.

## Emitted when this bin takes a piece of rubbish, so the level can count towards
## the end of the level.
signal rubbish_sorted(kind: StringName)
## Emitted when a dog brings something this bin does not take. The level owns the
## single "Wrong bin!" notice, so there is only ever one message on screen.
signal wrong_bin(held_kind: StringName, bin_kind: StringName)

## The kind of rubbish this bin takes, which is also how the bin is identified.
## SummerLevel sets it from its BINS table: the paper bin takes paper, and so on.
@export var accepts_kind: StringName = &"paper"
@export var bin_texture: Texture2D
## The opaque part of bin_texture. The bin pictures come with empty padding, and
## without this the bin would be drawn mostly air.
@export var art_region: Rect2 = Rect2(48, 32, 160, 192)
@export_range(48.0, 256.0, 1.0) var display_height: float = 112.0

@onready var sprite: Sprite2D = $Bin
@onready var bin_label: Label = $BinLabel

## True once this bin has taken its rubbish. The bin itself stays in the level
## either way; only the rubbish leaves.
var is_filled: bool = false


func _ready() -> void:
	if bin_texture != null:
		sprite.texture = bin_texture
	sprite.region_enabled = true
	sprite.region_rect = art_region
	var uniform_scale: float = display_height / art_region.size.y
	sprite.scale = Vector2(uniform_scale, uniform_scale)
	# Drawn from the bottom edge, so the bin stands on the ground it is placed on.
	sprite.offset = Vector2(-art_region.size.x * 0.5, -art_region.size.y)
	
	# Set bin label based on accepted kind
	match accepts_kind:
		&"paper":
			bin_label.text = "Paper Bin"
		&"plastic":
			bin_label.text = "Plastic Bin"
		&"glass":
			bin_label.text = "Glass Bin"
		_:
			bin_label.text = str(accepts_kind)


## Watched every frame rather than on body_entered, for the same reason the pot
## does it: a dog already carrying the right thing can walk straight in and be
## served, and a dog standing still in here is still offered the chance.
func _process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body is Player:
			_serve(body as Player)
			return


func _serve(player: Player) -> void:
	# An empty dog is ignored: there is nothing to sort and nothing to complain
	# about, so standing next to a bin is never a problem.
	if player.carried_kind == &"":
		return

	if player.carried_kind != accepts_kind:
		# The wrong bin. Nothing is taken and nothing is put back - the dog is
		# left holding exactly what it was holding - and the level shows a short
		# "Wrong bin!" notice so the mistake is obvious.
		wrong_bin.emit(player.carried_kind, accepts_kind)
		return

	if is_filled:
		# This bin has already had its one piece of rubbish. The bin stays in the
		# level and takes nothing more.
		return

	# The right bin. The rubbish is used up for good, exactly as the pot uses an
	# item up: consume_carried() fires the item's own "consume" callback, which
	# takes the node out of the level instead of putting it back where it was
	# found. Only the rubbish leaves; the bin does not move or disappear.
	player.consume_carried()
	is_filled = true
	rubbish_sorted.emit(accepts_kind)


## Where the bin is actually drawn, worked out from the sprite rather than
## hard-coded, so a test can check it stays put.
func drawn_rect() -> Rect2:
	var drawn_size: Vector2 = art_region.size * sprite.scale
	return Rect2(global_position + sprite.offset, drawn_size)
