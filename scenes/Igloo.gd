class_name Igloo
extends Area2D

## The igloo at the end of Winter, and the goal box inside it.
##
## ## It counts penguins, it does not check a flag
##
## The igloo keeps its own set of the players currently standing inside its goal
## box, and reports the size of that set whenever it changes. It does not decide
## whether the level is finished and it does not know how many players there are -
## the level owns both of those, so the two cannot disagree about what "finished"
## means. Detection is real Area2D collision against the players' physics layer, so
## what counts as being at the igloo is exactly what is standing in the box.
##
## ## The same penguin twice
##
## The set is keyed on the body itself, not on a number that is added and subtracted.
## Area2D can report an entry for a body that is already inside when the area moves
## or when monitoring is refreshed, and a counter incremented that way would drift
## upwards and could reach two with only one penguin in the igloo. Adding to a set
## that already holds the body changes nothing, so the count can only ever be the
## number of genuinely different penguins inside.

## The igloo watches layer 2, which is where Player.gd puts every penguin. It sits
## on no layer itself: it is a goal, not a hazard, and nothing should detect it.
const PLAYER_LAYER := 2

## Emitted whenever the number of penguins inside the goal box changes, with the
## new count.
signal penguins_changed(count: int)

@export var igloo_texture: Texture2D
@export var art_region: Rect2 = Rect2()
## How tall the igloo is drawn. Its width follows from the artwork's proportions.
@export_range(32.0, 512.0, 1.0) var display_height: float = 152.0
## The goal box, centred on the igloo's node and raised so its floor is level with
## the snow the igloo stands on. A penguin 60x52 walking into this box is fully
## inside it, so reaching the igloo needs a walk and not a precise jump.
@export var goal_size: Vector2 = Vector2(168.0, 140.0)

@onready var art: Sprite2D = $Art
@onready var goal_shape: CollisionShape2D = $Goal

## The players currently inside, as bodies rather than as a count.
var _inside: Dictionary = {}


func _ready() -> void:
	var source_size := art_region.size
	if source_size == Vector2.ZERO and igloo_texture != null:
		source_size = igloo_texture.get_size()
		art.region_enabled = false

	var uniform_scale: float = display_height / source_size.y
	art.texture = igloo_texture
	art.texture_filter = 1
	if art_region.size != Vector2.ZERO:
		art.region_enabled = true
		art.region_rect = art_region
	art.scale = Vector2(uniform_scale, uniform_scale)
	art.flip_h = true
	# Bottom edge of the picture on the node, the same anchor Player.gd and Autumn's
	# trees use, so the igloo stands on the snow instead of hovering over it.
	art.offset = Vector2(0.0, -source_size.y * 0.5)

	var shape := RectangleShape2D.new()
	shape.size = goal_size
	goal_shape.shape = shape
	# Box centred on the igloo and sitting on the ground it stands on.
	goal_shape.position = Vector2(0.0, -goal_size.y * 0.5)

	collision_layer = 0
	collision_mask = PLAYER_LAYER
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## How many penguins are in the igloo right now.
func penguin_count() -> int:
	return _inside.size()


func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	if _inside.has(body):
		return
	_inside[body] = true
	penguins_changed.emit(_inside.size())


func _on_body_exited(body: Node2D) -> void:
	if not body is Player:
		return
	if not _inside.has(body):
		return
	_inside.erase(body)
	penguins_changed.emit(_inside.size())


## Forgets everybody inside. Called by the level whenever the penguins are sent
## back to the start, because a penguin teleported out of the goal box is not
## something Area2D reliably reports an exit for, and a stale penguin left in here
## would let the level finish with only one player really present.
func reset() -> void:
	if _inside.is_empty():
		return
	_inside.clear()
	penguins_changed.emit(0)