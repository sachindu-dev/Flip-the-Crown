extends Node2D
# Spinning saw trap. Lethal on contact (the engine reads its position).

func _ready() -> void:
	var icon := get_node_or_null("Icon")
	if icon:
		icon.queue_free()
	var a := AnimatedSprite2D.new()
	a.centered = true
	a.position = Vector2(16, 16)
	a.sprite_frames = SheetUtil.frames([
		{"name": "spin", "path": "res://assets/adventure/Traps/Saw/On (38x38).png", "w": 38, "h": 38, "count": 8, "fps": 24.0, "loop": true},
	])
	var s := 32.0 / 38.0 * 1.4
	a.scale = Vector2(s, s)
	add_child(a)
	a.play("spin")
