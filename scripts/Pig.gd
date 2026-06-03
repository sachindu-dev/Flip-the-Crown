class_name Pig
extends Node2D
# Port of entities.js Pig: patrols its platform (turns at walls & ledges),
# lethal on contact, dies to the King's hammer.

const TILE := 32
const GRAVITY := 4000.0
const MAX_FALL := 1120.0

const W := 28
const H := 28

var spawn_x := 0.0
var spawn_y := 0.0
var x := 0.0
var y := 0.0
var vx := 68.0
var vy := 0.0
var facing := -1
var dead := false
var dead_t := 0.0
var anim_t := 0.0

var sprite: AnimatedSprite2D

func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.centered = true
	# feet (frame-y 25 of 28) aligned to hitbox bottom (H=28)
	sprite.position = Vector2(14, 17)
	sprite.sprite_frames = _build_frames()
	add_child(sprite)
	reset()

func _build_frames() -> SpriteFrames:
	var base := "res://assets/Kings and Pigs/Sprites/03-Pig/"
	return SheetUtil.frames([
		{"name": "run", "path": base + "Run (34x28).png", "w": 34, "h": 28, "count": 6, "fps": 10.0, "loop": true},
		{"name": "idle", "path": base + "Idle (34x28).png", "w": 34, "h": 28, "count": 11, "fps": 8.0, "loop": true},
		{"name": "dead", "path": base + "Dead (34x28).png", "w": 34, "h": 28, "count": 4, "fps": 10.0, "loop": false},
	])

func reset() -> void:
	x = spawn_x
	y = spawn_y
	vx = 68.0
	vy = 0.0
	facing = -1
	dead = false
	dead_t = 0.0
	anim_t = 0.0
	if sprite:
		sprite.modulate.a = 1.0
		sprite.rotation = 0.0
		sprite.play("run")

func rect() -> Rect2:
	return Rect2(x, y, W, H)

func cx() -> float:
	return x + W / 2.0

func cy() -> float:
	return y + H / 2.0

func kill() -> void:
	if dead:
		return
	dead = true
	sprite.play("dead")

func update(dt: float, game) -> void:
	if dead:
		dead_t += dt
		sprite.modulate.a = max(0.0, 1.0 - dead_t * 2.0)
		sprite.rotation += dt * 4.0
		position = Vector2(round(x), round(y))
		return

	anim_t += dt
	vy += GRAVITY * dt
	if vy > MAX_FALL: vy = MAX_FALL

	facing = -1 if vx < 0.0 else 1
	var nx := x + vx * dt

	var top := floori(y / TILE)
	var bot := floori((y + H - 1) / TILE)
	var blocked := false
	if vx > 0.0:
		var cr := floori((nx + W - 1) / TILE)
		for ty in range(top, bot + 1):
			if game.solid(cr, ty): blocked = true
	else:
		var cl := floori(nx / TILE)
		for ty in range(top, bot + 1):
			if game.solid(cl, ty): blocked = true

	# ledge ahead? turn around to stay on the platform
	var foot_y := floori((y + H + 1) / TILE)
	var foot_x: int = floori((nx + W) / TILE) if vx > 0.0 else floori(nx / TILE)
	var ledge: bool = not game.solid(foot_x, foot_y)

	if blocked or ledge:
		vx = -vx
	else:
		x = nx

	# vertical collide
	y += vy * dt
	var left := floori(x / TILE)
	var right := floori((x + W - 1) / TILE)
	var cc := floori((y + H - 1) / TILE)
	for tx in range(left, right + 1):
		if game.solid(tx, cc):
			y = cc * TILE - H
			vy = 0.0
			break

	sprite.flip_h = facing < 0
	if sprite.animation != "run":
		sprite.play("run")
	position = Vector2(round(x), round(y))
