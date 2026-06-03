extends Node2D
# Exit door. Opens (via open()) once all diamonds are collected; the engine
# checks whether the active character reaches it.

var anim: AnimatedSprite2D

func _ready() -> void:
	var icon := get_node_or_null("Icon")
	if icon:
		icon.queue_free()
	anim = AnimatedSprite2D.new()
	anim.centered = true
	var sc := (32.0 * 2.0) / 56.0
	anim.scale = Vector2(sc, sc)
	anim.position = Vector2(16, 0)
	anim.sprite_frames = SheetUtil.frames([
		{"name": "closed", "path": "res://assets/Kings and Pigs/Sprites/11-Door/Idle.png", "w": 46, "h": 56, "count": 1, "fps": 5.0, "loop": true},
		{"name": "opening", "path": "res://assets/Kings and Pigs/Sprites/11-Door/Opening (46x56).png", "w": 46, "h": 56, "count": 5, "fps": 10.0, "loop": false},
	])
	add_child(anim)
	anim.play("closed")

func open() -> void:
	if anim:
		anim.play("opening")
