extends Node2D
# Fruit (score) or Diamond (key). Placed in a level scene; the engine reads
# its position and handles collection. The editor "Icon" child is a static
# preview; at runtime it's replaced with the animated sprite.

@export_enum("fruit", "diamond") var kind := "fruit"

func _ready() -> void:
	var icon := get_node_or_null("Icon")
	if icon:
		icon.queue_free()
	var a := AnimatedSprite2D.new()
	a.centered = true
	a.position = Vector2(16, 16)
	if kind == "fruit":
		a.sprite_frames = SheetUtil.frames([
			{"name": "idle", "path": "res://assets/adventure/Items/Fruits/Apple.png", "w": 32, "h": 32, "count": 17, "fps": 18.0, "loop": true},
		])
	else:
		a.sprite_frames = SheetUtil.frames([
			{"name": "idle", "path": "res://assets/Kings and Pigs/Sprites/12-Live and Coins/Small Diamond (18x14).png", "w": 18, "h": 14, "count": 8, "fps": 10.0, "loop": true},
		])
		a.scale = Vector2(1.6, 1.6)
	add_child(a)
	a.play("idle")
