class_name Character
extends Node2D
# Port of entities.js Player (King + Ninja Frog). Custom tile-grid physics,
# all pixel constants doubled for the 32px-tile world. Rendered with real
# PixelFrog sprites.

const TILE := 32

# Softer gravity than the doubled web values: jump heights are preserved
# (h = v^2 / 2g) but airtime is ~25% longer so jumps feel less twitchy.
const GRAVITY := 2600.0
const MAX_FALL := 900.0
const JUMP_CUT := 0.5
const COYOTE := 0.1
const BUFFER := 0.12

const STATS := {
	"king": {
		"w": 26, "h": 44,
		"max_run": 156.0, "accel": 1800.0, "friction": 2800.0, "air_accel": 1400.0,
		"jump": 700.0, "jumps": 1, "wall": false,
	},
	"frog": {
		"w": 24, "h": 34,
		"max_run": 304.0, "accel": 3400.0, "friction": 4000.0, "air_accel": 2400.0,
		"jump": 720.0, "jumps": 2, "wall": true,
	},
}

# Sprite placement: offset of the (centered) frame within the hitbox so the
# character's measured feet sit on the hitbox bottom. oy = h - (feet_y - frame_h/2),
# measured from the opaque bounding box of the idle frame.
const SPRITE := {
	"king": {"ox": 13, "oy": 29, "scale": 1.0},
	"frog": {"ox": 12, "oy": 18, "scale": 1.0},
}

var kind := "king"
var spawn_x := 0.0
var spawn_y := 0.0

var x := 0.0
var y := 0.0
var vx := 0.0
var vy := 0.0
var on_ground := false
var facing := 1
var jumps_left := 0
var coyote := 0.0
var buffer := 0.0
var wall_dir := 0
var wall_sliding := false
var anim_t := 0.0
var state := "idle"
var hammer := 0.0
var hammer_cooldown := 0.0
var invuln := 0.0
var jump_held := false
var did_double := false
var active := true

var sprite: AnimatedSprite2D
var marker: Polygon2D

func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.centered = true
	sprite.sprite_frames = _build_frames()
	var sp: Dictionary = SPRITE[kind]
	sprite.position = Vector2(sp.ox, sp.oy)
	sprite.scale = Vector2(sp.scale, sp.scale)
	add_child(sprite)
	sprite.play("idle")

	marker = Polygon2D.new()
	marker.color = Color("#f2c14e")
	marker.polygon = PackedVector2Array([Vector2(-4, -4), Vector2(4, -4), Vector2(0, 1)])
	marker.position = Vector2(stats().w / 2.0, -8)
	add_child(marker)

	reset(spawn_x, spawn_y)

func stats() -> Dictionary:
	return STATS[kind]

func _build_frames() -> SpriteFrames:
	if kind == "king":
		var base := "res://assets/Kings and Pigs/Sprites/01-King Human/"
		return SheetUtil.frames([
			{"name": "idle", "path": base + "Idle (78x58).png", "w": 78, "h": 58, "count": 11, "fps": 9.0, "loop": true},
			{"name": "run", "path": base + "Run (78x58).png", "w": 78, "h": 58, "count": 8, "fps": 12.0, "loop": true},
			{"name": "jump", "path": base + "Jump (78x58).png", "w": 78, "h": 58, "count": 1, "fps": 5.0, "loop": true},
			{"name": "fall", "path": base + "Fall (78x58).png", "w": 78, "h": 58, "count": 1, "fps": 5.0, "loop": true},
			{"name": "attack", "path": base + "Attack (78x58).png", "w": 78, "h": 58, "count": 3, "fps": 14.0, "loop": false},
			{"name": "hit", "path": base + "Hit (78x58).png", "w": 78, "h": 58, "count": 2, "fps": 8.0, "loop": false},
		])
	else:
		var base := "res://assets/adventure/Main Characters/Ninja Frog/"
		return SheetUtil.frames([
			{"name": "idle", "path": base + "Idle (32x32).png", "w": 32, "h": 32, "count": 11, "fps": 10.0, "loop": true},
			{"name": "run", "path": base + "Run (32x32).png", "w": 32, "h": 32, "count": 12, "fps": 14.0, "loop": true},
			{"name": "jump", "path": base + "Jump (32x32).png", "w": 32, "h": 32, "count": 1, "fps": 5.0, "loop": true},
			{"name": "fall", "path": base + "Fall (32x32).png", "w": 32, "h": 32, "count": 1, "fps": 5.0, "loop": true},
			{"name": "double_jump", "path": base + "Double Jump (32x32).png", "w": 32, "h": 32, "count": 6, "fps": 16.0, "loop": false},
			{"name": "wall_jump", "path": base + "Wall Jump (32x32).png", "w": 32, "h": 32, "count": 5, "fps": 12.0, "loop": false},
			{"name": "hit", "path": base + "Hit (32x32).png", "w": 32, "h": 32, "count": 7, "fps": 12.0, "loop": false},
		])

func reset(nx: float, ny: float) -> void:
	x = nx
	y = ny
	vx = 0.0
	vy = 0.0
	on_ground = false
	facing = 1
	jumps_left = 0
	coyote = 0.0
	buffer = 0.0
	wall_dir = 0
	wall_sliding = false
	anim_t = 0.0
	state = "idle"
	hammer = 0.0
	hammer_cooldown = 0.0
	invuln = 0.0
	jump_held = false
	did_double = false

func cx() -> float:
	return x + stats().w / 2.0

func cy() -> float:
	return y + stats().h / 2.0

func rect() -> Rect2:
	var s := stats()
	return Rect2(x, y, s.w, s.h)

func hammer_hitbox():
	if kind != "king" or hammer <= 0.0:
		return null
	var reach := 28.0
	var hh := 32.0
	var hx: float = (x + stats().w) if facing > 0 else (x - reach)
	return Rect2(hx, y + 4, reach, hh)

func update(dt: float, game, controllable: bool) -> void:
	var s := stats()
	var ax := 0.0
	if controllable:
		ax = Input.get_axis("move_left", "move_right")

	# ---- horizontal ----
	var on_g := on_ground
	var accel: float = s.accel if on_g else s.air_accel
	if ax != 0.0:
		facing = -1 if ax < 0.0 else 1
		vx += ax * accel * dt
		vx = clampf(vx, -s.max_run, s.max_run)
	else:
		var fr: float = (s.friction if on_g else s.air_accel * 0.6) * dt
		if vx > 0.0:
			vx = max(0.0, vx - fr)
		elif vx < 0.0:
			vx = min(0.0, vx + fr)

	# ---- timers ----
	if coyote > 0.0: coyote -= dt
	if buffer > 0.0: buffer -= dt
	if hammer > 0.0: hammer -= dt
	if hammer_cooldown > 0.0: hammer_cooldown -= dt
	if invuln > 0.0: invuln -= dt

	# ---- jump input ----
	if controllable and Input.is_action_just_pressed("jump"):
		buffer = BUFFER
	var jump_down := controllable and Input.is_action_pressed("jump")

	# ---- wall slide (frog) ----
	wall_sliding = false
	if s.wall and not on_g and wall_dir != 0 and vy > 0.0 and controllable and ax == float(wall_dir):
		vy = min(vy, 180.0)
		wall_sliding = true

	# ---- execute jump ----
	if buffer > 0.0:
		if on_g or coyote > 0.0:
			vy = -s.jump
			jumps_left = int(s.jumps) - 1
			buffer = 0.0
			coyote = 0.0
			on_ground = false
			did_double = false
			game.spawn_dust(cx(), y + s.h, 4, Color("#cfc4b0"))
		elif s.wall and wall_sliding:
			vy = -s.jump * 0.98
			vx = -wall_dir * s.max_run * 1.05
			facing = -wall_dir
			jumps_left = int(s.jumps) - 1
			buffer = 0.0
			game.spawn_dust(cx(), cy(), 5, Color("#cfeede"))
		elif jumps_left > 0:
			vy = -s.jump * 0.92
			jumps_left -= 1
			buffer = 0.0
			did_double = true
			game.spawn_dust(cx(), y + s.h, 6, Color("#cfeede"))

	# ---- variable jump height ----
	if vy < 0.0 and not jump_down and jump_held:
		vy *= JUMP_CUT
	jump_held = jump_down

	# ---- hammer (king) ----
	if controllable and kind == "king" and Input.is_action_just_pressed("attack") and hammer_cooldown <= 0.0:
		hammer = 0.26
		hammer_cooldown = 0.42
		game.on_hammer_start(self)

	# ---- gravity ----
	vy += GRAVITY * dt
	if vy > MAX_FALL: vy = MAX_FALL

	# ---- integrate + collide ----
	_move_x(vx * dt, game)
	_move_y(vy * dt, game)
	_probe_walls(game)

	# ---- anim state ----
	anim_t += dt
	if not on_ground:
		state = "wall" if wall_sliding else ("jump" if vy < 0.0 else "fall")
	elif abs(vx) > 6.0:
		state = "run"
	else:
		state = "idle"
	if on_ground or vy >= 0.0:
		did_double = false

	_apply_visuals(dt)

func _move_x(dx: float, game) -> void:
	x += dx
	var s := stats()
	var top := floori(y / TILE)
	var bot := floori((y + s.h - 1) / TILE)
	if dx > 0.0:
		var cr := floori((x + s.w - 1) / TILE)
		for ty in range(top, bot + 1):
			if game.solid(cr, ty):
				x = cr * TILE - s.w
				vx = 0.0
				break
	elif dx < 0.0:
		var cl := floori(x / TILE)
		for ty in range(top, bot + 1):
			if game.solid(cl, ty):
				x = (cl + 1) * TILE
				vx = 0.0
				break

func _move_y(dy: float, game) -> void:
	y += dy
	on_ground = false
	var s := stats()
	var left := floori(x / TILE)
	var right := floori((x + s.w - 1) / TILE)
	if dy > 0.0:
		var cb := floori((y + s.h - 1) / TILE)
		for tx in range(left, right + 1):
			if game.solid(tx, cb):
				y = cb * TILE - s.h
				vy = 0.0
				on_ground = true
				coyote = COYOTE
				jumps_left = int(s.jumps)
				break
	elif dy < 0.0:
		var ct := floori(y / TILE)
		for tx in range(left, right + 1):
			if game.solid(tx, ct):
				y = (ct + 1) * TILE
				vy = 0.0
				break

func _probe_walls(game) -> void:
	wall_dir = 0
	if on_ground:
		return
	var s := stats()
	var top := floori((y + 2) / TILE)
	var bot := floori((y + s.h - 2) / TILE)
	var rc := floori((x + s.w) / TILE)
	var lc := floori((x - 1) / TILE)
	for ty in range(top, bot + 1):
		if game.solid(rc, ty):
			wall_dir = 1
			return
		if game.solid(lc, ty):
			wall_dir = -1
			return

func _apply_visuals(_dt: float) -> void:
	position = Vector2(round(x), round(y))
	sprite.flip_h = facing < 0
	# choose animation
	var anim := "idle"
	if kind == "king":
		if hammer > 0.0:
			anim = "attack"
		elif state == "run":
			anim = "run"
		elif not on_ground:
			anim = "jump" if vy < 0.0 else "fall"
		else:
			anim = "idle"
	else:
		if state == "wall":
			anim = "wall_jump"
		elif did_double and vy < 0.0:
			anim = "double_jump"
		elif state == "run":
			anim = "run"
		elif not on_ground:
			anim = "jump" if vy < 0.0 else "fall"
		else:
			anim = "idle"
	if sprite.animation != anim:
		sprite.play(anim)

	# fade for inactive + invuln flicker
	var a := 1.0 if active else 0.55
	if invuln > 0.0 and int(invuln * 30.0) % 2 == 0:
		a *= 0.35
	sprite.modulate.a = a

	# swap marker over the inactive character
	marker.visible = not active
	if not active:
		marker.position.y = -8 + sin(Time.get_ticks_msec() / 250.0) * 1.5

func set_active(v: bool) -> void:
	active = v
	z_index = 4 if v else 3
