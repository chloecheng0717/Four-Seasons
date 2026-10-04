class_name LeafFrame
extends Area2D

## One Autumn leaf frame. A fox carries a leaf to the frame it fits, the frame
## takes it and shows it inside itself, and the leaf is used up for good.
## Anything else is refused: the fox keeps holding what it was carrying and walks
## on to try another frame.
##
## This is deliberately the same shape as Summer's TrashBin rather than something
## new: an Area2D that watches which foxes are standing in it, decides what to do,
## and hands the leaf's fate back to the fox through the same two callables the
## gardening items and the rubbish use. The whole difference is the rule.
##
## The rule is visual and nothing else. Each frame's own artwork has a ghosted
## leaf silhouette burned into the middle of it, and every leaf's outline matches
## exactly one of those silhouettes, so the picture alone says where a leaf goes.
## There is deliberately no Label on this scene, no number and no wording: the
## frame says nothing at all, and which leaf it wants is only ever visible.
##
## A refused leaf is NOT put back, exactly as in Summer. The fox simply keeps
## carrying it and tries another frame, so there is nothing to undo.

## Emitted when this frame takes a leaf, so the level can count towards the end of
## the level.
signal leaf_placed(kind: StringName)
## Emitted when a fox brings a leaf this frame does not fit. The level owns the
## single notice, so there is only ever one message on screen.
signal wrong_leaf(held_kind: StringName, frame_kind: StringName)

## The kind of leaf this frame takes, which is also how the frame is identified.
## AutumnLevel sets it from its FRAMES table: the frame drawn with Leaf_frame3's
## artwork takes Leaf3, and so on.
@export var accepts_kind: StringName = &"leaf1"
@export var frame_texture: Texture2D
## The opaque part of frame_texture. The frame pictures come with a lot of empty
## padding around them, and without this the frame would be drawn mostly air.
@export var art_region: Rect2 = Rect2(74, 45, 406, 393)
## The leaf that belongs in this frame, held back until it is actually placed.
@export var leaf_texture: Texture2D
## The opaque part of leaf_texture.
@export var leaf_region: Rect2 = Rect2(2, 6, 25, 24)
## The size of the ghosted leaf silhouette inside the frame's artwork, in the
## artwork's own pixels. Measured out of the four frame PNGs. The placed leaf is
## scaled with this so it fills the silhouette exactly, which is what makes the
## match look right.
@export var silhouette_size: Vector2 = Vector2(161, 154)
@export_range(48.0, 320.0, 1.0) var display_height: float = 168.0
## How wide the frame's pickup box is. It is derived from the artwork's height
## (see _ready), so this only controls how much room either side of the silhouette
## counts as "at the frame".
@export_range(24.0, 160.0, 1.0) var box_width: float = 84.0

@onready var frame_sprite: Sprite2D = $Frame
@onready var placed_leaf: Sprite2D = $PlacedLeaf
@onready var body: CollisionShape2D = $CollisionShape2D

## Where the ghosted leaf sits inside the frame's artwork, as a fraction of the
## artwork's width and height. Measured in all four frame PNGs, and the same in
## every one of them to within 0.003, so one value covers all four frames.
const SILHOUETTE_CENTRE := Vector2(0.5, 0.51)

## True once this frame has taken its leaf. The frame itself stays in the level
## either way; only the leaf leaves.
var is_filled: bool = false


func _ready() -> void:
	if frame_texture != null:
		frame_sprite.texture = frame_texture
	frame_sprite.region_enabled = true
	frame_sprite.region_rect = art_region
	var uniform_scale: float = display_height / art_region.size.y
	frame_sprite.scale = Vector2(uniform_scale, uniform_scale)
	# Anchored the same way Player.gd and TrashBin.gd anchor their artwork: the
	# sprite is centred, so lifting it by half its own height puts the artwork's
	# bottom edge on the node and its middle over it. That is what makes a frame
	# stand on the terrace instead of hovering over it.
	frame_sprite.offset = Vector2(0.0, -art_region.size.y * 0.5)

	# The leaf that will appear inside the frame. It is scaled to exactly fill the
	# frame's own ghosted silhouette and centred on it, so a correct leaf lands in
	# the shape it belongs to. It stays hidden until a fox brings that leaf.
	if leaf_texture != null:
		placed_leaf.texture = leaf_texture
	placed_leaf.region_enabled = true
	placed_leaf.region_rect = leaf_region
	var leaf_scale: float = silhouette_size.x * uniform_scale / leaf_region.size.x
	placed_leaf.scale = Vector2(leaf_scale, leaf_scale)
	placed_leaf.position = _silhouette_centre()
	placed_leaf.visible = false

	# The pickup box runs from the middle of the ghosted leaf down to the frame's
	# own base, so a fox standing on the ground in front of the frame is inside it
	# without having to jump, and one that jumps up to it is inside it too. It is
	# derived from the artwork rather than typed in, so it cannot drift away from
	# where the silhouette actually is.
	var top: float = art_region.size.y * (SILHOUETTE_CENTRE.y - 1.0)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(box_width, -top)
	body.shape = shape
	body.position = Vector2(0.0, top * 0.5)


## Where the ghosted leaf sits, in this node's own coordinates. Negative y,
## because it is up inside the artwork rather than below the node.
func _silhouette_centre() -> Vector2:
	return Vector2(
		art_region.size.x * (SILHOUETTE_CENTRE.x - 0.5),
		art_region.size.y * (SILHOUETTE_CENTRE.y - 1.0))


## Watched every frame rather than on body_entered, for the same reason the pot
## and the bins do it: a fox already carrying the right leaf can walk straight in
## and be served, and a fox standing still in here is still offered the chance.
##
## Every fox in here is served, not just the first one: two foxes can stand in the
## same frame, and if the lower one is carrying a leaf this frame does not fit
## while the upper one is carrying exactly what it does want, stopping at the first
## fox would refuse the leaf that was actually being delivered.
func _process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body is Player:
			_serve(body as Player)


func _serve(player: Player) -> void:
	# Empty hands are ignored: there is nothing to place and nothing to complain
	# about, so standing next to a frame is never a problem.
	if player.carried_kind == &"":
		return

	if player.carried_kind != accepts_kind:
		# The wrong frame. Nothing is taken and nothing is put back - the fox is
		# left holding exactly what it was holding - and the level shows a short
		# notice so the attempt is obvious rather than silent.
		wrong_leaf.emit(player.carried_kind, accepts_kind)
		return

	if is_filled:
		# This frame has already had its one leaf. The frame stays in the level and
		# takes nothing more.
		return

	# The right frame. The leaf is used up for good, exactly as the pot uses an
	# item up and a bin uses a piece of rubbish up: consume_carried() fires the
	# leaf's own "consume" callback, which takes the node out of the level instead
	# of putting it back where it was found. Only the leaf leaves; the frame does
	# not move or disappear, it just shows the leaf inside itself from now on.
	player.consume_carried()
	is_filled = true
	placed_leaf.visible = true
	leaf_placed.emit(accepts_kind)


## Where the frame's artwork actually lands on screen, taken from the sprite's own
## transform rather than from the region and offset by hand, so it stays correct
## whatever the artwork or the anchor is changed to. Measured against a real
## render: these are the pixels the frame is drawn on.
func drawn_rect() -> Rect2:
	return _sprite_rect(frame_sprite)


## Where the ghosted leaf sits on screen, in the same measured way. Used to check
## that a placed leaf really is inside its own frame and not overlapping a
## neighbour's.
func silhouette_rect() -> Rect2:
	return _sprite_rect(placed_leaf)


func _sprite_rect(sprite: Sprite2D) -> Rect2:
	var local := sprite.get_rect()
	var top_left: Vector2 = sprite.global_transform * local.position
	var bottom_right: Vector2 = sprite.global_transform * local.end
	return Rect2(top_left, bottom_right - top_left)
