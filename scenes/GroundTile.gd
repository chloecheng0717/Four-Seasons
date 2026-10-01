class_name GroundTile
extends StaticBody2D

@export var buried: bool = false
## Replaces the tile's own picture when set, so one tile scene can be a Spring
## ground tile or a Summer sand tile. Left empty it keeps whatever the scene
## already holds, which is how Spring is unaffected by this.
@export var surface_texture: Texture2D
## The opaque part of surface_texture. Only needed when the texture comes with
## empty padding, because the scene's own crop belongs to the scene's own
## texture and would be in the wrong place for a different one.
@export var surface_region: Rect2 = Rect2()

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	if surface_texture != null:
		sprite.texture = surface_texture
	if surface_region.size != Vector2.ZERO:
		sprite.region_enabled = true
		sprite.region_rect = surface_region
	sprite.flip_v = buried
