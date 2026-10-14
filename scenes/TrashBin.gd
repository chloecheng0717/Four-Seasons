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
## How many pieces of rubbish this bin takes before it is full. Summer 1 has one
## piece of each kind, so its bins take 1; Summer 2 has two of each, so its bins
## take 2.
@export_range(1, 10) var capacity: int = 1

@onready var sprite: Sprite2D = $Bin
@onready var bin_label: Label = $BinLabel

## How many pieces this bin has taken so far.
var sorted_count: int = 0
## True once this bin has taken all the rubbish it is waiting for (`capacity`).
## The bin itself stays in the level either way; only the rubbish leaves.
var is_filled: bool = false


func _ready() -> void:
	if bin_texture != null:
		sprite.texture = bin_texture
	sprite.region_enabled = true
	sprite.region_rect = art_region
	var uniform_scale: float = display_height / art_region.size.y
	sprite.scale = Vector2(uniform_scale, uniform_scale)
	# Drawn so the artwork's bottom edge lands exactly on the node origin and its
	# middle sits over it, which is how Player.gd anchors the dogs. The sprite is
	# centred, so the offset only has to lift it by half its height: offsetting by
	# the full height would float the bin a whole display_height above the ground,
	# and offsetting sideways as well would slide it off to the left of its node.
	sprite.offset = Vector2(0.0, -art_region.size.y * 0.5)
	
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
##
## Every dog in here is served, not just the first one: two dogs can stand in the
## same bin, and if the lower one is holding something this bin does not want
## while the upper one is holding exactly what it does want, stopping at the first
## dog would refuse the rubbish that was actually being delivered.
func _process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body is Player:
			_serve(body as Player)


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
		# This bin already has all the rubbish it takes. The bin stays in the
		# level and takes nothing more.
		return

	# The right bin. The rubbish is used up for good, exactly as the pot uses an
	# item up: consume_carried() fires the item's own "consume" callback, which
	# takes the node out of the level instead of putting it back where it was
	# found. Only the rubbish leaves; the bin does not move or disappear.
	player.consume_carried()
	sorted_count += 1
	is_filled = sorted_count >= capacity
	rubbish_sorted.emit(accepts_kind)


## Where the bin's artwork actually lands on screen, taken from the sprite's own
## transform rather than from the region and offset by hand, so it stays correct
## whatever the artwork or the anchor is changed to. Measured against a real
## render: these are the pixels the bin is drawn on.
func drawn_rect() -> Rect2:
	var local := sprite.get_rect()
	var top_left: Vector2 = sprite.global_transform * local.position
	var bottom_right: Vector2 = sprite.global_transform * local.end
	return Rect2(top_left, bottom_right - top_left)
