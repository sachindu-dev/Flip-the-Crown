extends Node2D
# The Royal Swap — engine, world building, swap mechanic, state machine.
# Port of game.js + main.js. Root node of Main.tscn.

const TILE := 32
const VW := 960
const VH := 540

# Per-level editable scenes; "" falls back to the text grid in Levels.gd.
const LEVEL_SCENES := ["res://levels/Level1.tscn", "", ""]

# state: "menu" | "play" | "pause" | "end"
var state := "menu"
var level_index := 0

var hearts := 3
var fruit := 0
var diamonds_collected := 0
var total_diamonds := 0

var swap_cooldown := 0.0
var freeze := 0.0
var active_kind := "king"

# world data
var terrain: Array = []        # terrain[r][c] -> bool
var boxmap: Array = []         # boxmap[r][c] -> Dictionary or null
var fruits: Array = []         # { x, y, got, node, base_y }
var diamond_list: Array = []   # { x, y, got, node, base_y }
var spikes: Array = []         # { x, y }
var saws: Array = []           # { x, y }
var pigs: Array = []           # Pig
var door: Dictionary           # { x, y, node, opened } (empty if none)

var king: Character
var frog: Character

var world: Node2D
var fx: Particles
var ui

func _ready() -> void:
	_setup_input()
	world = Node2D.new()
	world.position = Vector2(0, (VH - Levels.H * TILE) / 2)
	add_child(world)
	fx = Particles.new()
	fx.position = world.position
	fx.z_index = 50
	add_child(fx)
	ui = UI.new()
	add_child(ui)
	ui.setup(self)
	state = "menu"
	ui.show_only(["mainMenu"])
	queue_redraw()

# ----------------------------------------------------------------- input
func _setup_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("jump", [KEY_SPACE, KEY_Z])
	_add_action("attack", [KEY_C, KEY_J])
	_add_action("swap", [KEY_X, KEY_SHIFT])
	_add_action("pause", [KEY_ESCAPE])

func _add_action(name: String, keys: Array) -> void:
	if InputMap.has_action(name):
		InputMap.action_erase_events(name)
	else:
		InputMap.add_action(name)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(name, ev)

# ----------------------------------------------------------------- level load
func load_level(i: int) -> void:
	level_index = i
	for child in world.get_children():
		child.queue_free()
	fx.clear_all()
	terrain = []
	boxmap = []
	fruits = []
	diamond_list = []
	spikes = []
	saws = []
	pigs = []
	door = {}
	king = null
	frog = null

	var spawns := {
		"kx": float(TILE), "ky": float(TILE),
		"fx": float(TILE * 2), "fy": float(TILE),
	}
	var scene_path: String = LEVEL_SCENES[i] if i < LEVEL_SCENES.size() else ""
	if scene_path != "" and ResourceLoader.exists(scene_path):
		_build_from_scene(load(scene_path), spawns)
	else:
		_build_from_grid(Levels.DATA[i].grid, spawns)

	king = Character.new()
	king.kind = "king"
	king.spawn_x = spawns.kx
	king.spawn_y = spawns.ky
	world.add_child(king)
	frog = Character.new()
	frog.kind = "frog"
	frog.spawn_x = spawns.fx
	frog.spawn_y = spawns.fy
	world.add_child(frog)

	active_kind = "king"
	king.set_active(true)
	frog.set_active(false)

	total_diamonds = diamond_list.size()
	diamonds_collected = 0
	fruit = 0
	swap_cooldown = 0.0
	freeze = 0.0

	_sync_hud()
	_update_swap_portrait()
	_redraw_background()

# Build from the editable scene: terrain from the TileMapLayer, entities from
# the placed child nodes (tagged by group).
func _build_from_scene(packed: PackedScene, spawns: Dictionary) -> void:
	for r in range(Levels.H):
		var tr := []
		var br := []
		for c in range(Levels.W):
			tr.append(false)
			br.append(null)
		terrain.append(tr)
		boxmap.append(br)

	var inst: Node2D = packed.instantiate()
	world.add_child(inst)

	var tml := inst.get_node_or_null("Terrain") as TileMapLayer
	if tml:
		for cell in tml.get_used_cells():
			if cell.x >= 0 and cell.x < Levels.W and cell.y >= 0 and cell.y < Levels.H:
				terrain[cell.y][cell.x] = true

	for n in inst.get_children():
		if n.is_in_group("box"):
			var bc := floori(n.position.x / TILE)
			var br := floori(n.position.y / TILE)
			if br >= 0 and br < Levels.H and bc >= 0 and bc < Levels.W:
				boxmap[br][bc] = {"broken": false, "node": n}
		elif n.is_in_group("spike"):
			spikes.append({"x": n.position.x, "y": n.position.y})
		elif n.is_in_group("saw"):
			saws.append({"x": n.position.x, "y": n.position.y})
		elif n.is_in_group("fruit"):
			fruits.append({"x": n.position.x + TILE / 2.0, "y": n.position.y + TILE / 2.0, "got": false, "node": n, "base_y": n.position.y})
		elif n.is_in_group("diamond"):
			diamond_list.append({"x": n.position.x + TILE / 2.0, "y": n.position.y + TILE / 2.0, "got": false, "node": n, "base_y": n.position.y})
		elif n.is_in_group("door"):
			door = {"x": n.position.x, "y": n.position.y, "node": n, "opened": false}
		elif n.is_in_group("pig"):
			n.z_index = 2
			pigs.append(n)
		elif n.name == "KingSpawn":
			spawns.kx = n.position.x
			spawns.ky = n.position.y - (Character.STATS.king.h - TILE)
		elif n.name == "FrogSpawn":
			spawns.fx = n.position.x
			spawns.fy = n.position.y - (Character.STATS.frog.h - TILE)

# Build from the text grid (Levels.gd) — fallback for levels not yet converted.
func _build_from_grid(grid: Array, spawns: Dictionary) -> void:
	for r in range(Levels.H):
		terrain.append([])
		boxmap.append([])
		var row: String = grid[r]
		for c in range(Levels.W):
			var ch := row[c]
			var px := c * TILE
			var py := r * TILE
			terrain[r].append(ch == "#")
			boxmap[r].append(null)
			match ch:
				"#":
					_make_tile(px, py, r, c, grid)
				"B":
					var node := _make_box(px, py)
					boxmap[r][c] = {"broken": false, "node": node}
				"^":
					spikes.append({"x": px, "y": py})
					_make_spike(px, py)
				"~":
					saws.append({"x": px, "y": py})
					_make_saw(px, py)
				"o":
					var fn := _make_fruit(px, py)
					fruits.append({"x": px + TILE / 2.0, "y": py + TILE / 2.0, "got": false, "node": fn, "base_y": fn.position.y})
				"*":
					var dn := _make_diamond(px, py)
					diamond_list.append({"x": px + TILE / 2.0, "y": py + TILE / 2.0, "got": false, "node": dn, "base_y": dn.position.y})
				"X":
					_make_door(px, py)
				"p":
					var pig := Pig.new()
					pig.spawn_x = px + 2
					pig.spawn_y = py + 4
					pig.z_index = 2
					world.add_child(pig)
					pigs.append(pig)
				"K":
					spawns.kx = px
					spawns.ky = py - (Character.STATS.king.h - TILE)
				"F":
					spawns.fx = px
					spawns.fy = py - (Character.STATS.frog.h - TILE)

# ---- world piece builders ----
func _make_tile(px: int, py: int, r: int, c: int, grid: Array) -> void:
	var top: bool = (r == 0) or (String(grid[r - 1][c]) != "#")
	var spr := Sprite2D.new()
	spr.texture = SheetUtil.first_frame("res://assets/adventure/Terrain/Terrain (16x16).png", 16, 16)
	(spr.texture as AtlasTexture).region = Rect2(16, 0 if top else 16, 16, 16)
	spr.centered = false
	spr.scale = Vector2(2, 2)
	spr.position = Vector2(px, py)
	world.add_child(spr)

func _make_box(px: int, py: int) -> Node2D:
	var spr := Sprite2D.new()
	spr.texture = load("res://assets/Kings and Pigs/Sprites/08-Box/Idle.png")
	spr.centered = false
	spr.scale = Vector2(TILE / 22.0, TILE / 16.0)
	spr.position = Vector2(px, py)
	spr.z_index = 1
	world.add_child(spr)
	return spr

func _make_spike(px: int, py: int) -> void:
	var spr := Sprite2D.new()
	spr.texture = load("res://assets/adventure/Traps/Spikes/Idle.png")
	spr.centered = false
	spr.scale = Vector2(2, 2)
	spr.position = Vector2(px, py)
	spr.z_index = 1
	world.add_child(spr)

func _make_saw(px: int, py: int) -> void:
	var spr := AnimatedSprite2D.new()
	spr.centered = true
	spr.sprite_frames = SheetUtil.frames([
		{"name": "spin", "path": "res://assets/adventure/Traps/Saw/On (38x38).png", "w": 38, "h": 38, "count": 8, "fps": 24.0, "loop": true},
	])
	spr.scale = Vector2(TILE / 38.0 * 1.4, TILE / 38.0 * 1.4)
	spr.position = Vector2(px + TILE / 2.0, py + TILE / 2.0)
	spr.z_index = 1
	world.add_child(spr)
	spr.play("spin")

func _make_fruit(px: int, py: int) -> AnimatedSprite2D:
	var spr := AnimatedSprite2D.new()
	spr.centered = true
	spr.sprite_frames = SheetUtil.frames([
		{"name": "idle", "path": "res://assets/adventure/Items/Fruits/Apple.png", "w": 32, "h": 32, "count": 17, "fps": 18.0, "loop": true},
	])
	spr.scale = Vector2(1, 1)
	spr.position = Vector2(px + TILE / 2.0, py + TILE / 2.0)
	spr.z_index = 1
	world.add_child(spr)
	spr.play("idle")
	return spr

func _make_diamond(px: int, py: int) -> AnimatedSprite2D:
	var spr := AnimatedSprite2D.new()
	spr.centered = true
	spr.sprite_frames = SheetUtil.frames([
		{"name": "idle", "path": "res://assets/Kings and Pigs/Sprites/12-Live and Coins/Small Diamond (18x14).png", "w": 18, "h": 14, "count": 8, "fps": 10.0, "loop": true},
	])
	spr.scale = Vector2(1.6, 1.6)
	spr.position = Vector2(px + TILE / 2.0, py + TILE / 2.0)
	spr.z_index = 1
	world.add_child(spr)
	spr.play("idle")
	return spr

func _make_door(px: int, py: int) -> void:
	var spr := AnimatedSprite2D.new()
	spr.centered = true
	spr.sprite_frames = SheetUtil.frames([
		{"name": "closed", "path": "res://assets/Kings and Pigs/Sprites/11-Door/Idle.png", "w": 46, "h": 56, "count": 1, "fps": 5.0, "loop": true},
		{"name": "opening", "path": "res://assets/Kings and Pigs/Sprites/11-Door/Opening (46x56).png", "w": 46, "h": 56, "count": 5, "fps": 10.0, "loop": false},
	])
	var sc := (TILE * 2.0) / 56.0
	spr.scale = Vector2(sc, sc)
	spr.position = Vector2(px + TILE / 2.0, py)
	spr.z_index = 1
	world.add_child(spr)
	spr.play("closed")
	door = {"x": float(px), "y": float(py), "node": spr, "opened": false}

# ----------------------------------------------------------------- world query
func solid(tx: int, ty: int) -> bool:
	if tx < 0 or tx >= Levels.W:
		return true
	if ty >= Levels.H:
		return true
	if ty < 0:
		return false
	if terrain[ty][tx]:
		return true
	var b = boxmap[ty][tx]
	return b != null and not b.broken

func active_char() -> Character:
	return king if active_kind == "king" else frog

func inactive_char() -> Character:
	return frog if active_kind == "king" else king

# ----------------------------------------------------------------- flow
func start_game() -> void:
	hearts = 3
	load_level(0)
	state = "play"
	ui.show_only(["hud"])

func restart_level() -> void:
	hearts = 3
	load_level(level_index)
	state = "play"
	ui.show_only(["hud"])

func next_level() -> void:
	if level_index + 1 < Levels.DATA.size():
		hearts = 3
		load_level(level_index + 1)
		state = "play"
		ui.show_only(["hud"])
	else:
		to_menu()

func to_menu() -> void:
	state = "menu"
	for c in world.get_children():
		c.queue_free()
	fx.clear_all()
	ui.show_only(["mainMenu"])
	_redraw_background()

func pause() -> void:
	state = "pause"
	ui.show_only(["hud", "pauseMenu"])

func resume() -> void:
	state = "play"
	ui.show_only(["hud"])

# ----------------------------------------------------------------- swap
func do_swap() -> void:
	# Control-only swap: neither character moves; control just toggles between
	# them (each keeps its own position). The per-frame loop routes input to
	# whichever is active, so flipping active_kind is all that's needed.
	var leaving := active_char()
	active_kind = "frog" if active_kind == "king" else "king"
	var taking := active_char()
	swap_cooldown = 0.2
	freeze = 0.05
	# a little juice at both characters so the control hand-off reads clearly
	spawn_dust(leaving.cx(), leaving.y + leaving.stats().h, 6, Color("#efe7d6"))
	spawn_dust(taking.cx(), taking.cy(), 12, Color.WHITE)
	leaving.set_active(false)
	taking.set_active(true)
	ui.flash()
	ui.kick_swap_chip()
	_update_swap_portrait()

# ----------------------------------------------------------------- damage
func hurt() -> void:
	var a := active_char()
	if a.invuln > 0.0 or state != "play":
		return
	hearts -= 1
	_sync_hud()
	ui.pop_heart(hearts)
	spawn_dust(a.cx(), a.cy(), 14, Color("#e0584b"))
	if hearts <= 0:
		_game_over()
		return
	king.reset(king.spawn_x, king.spawn_y)
	frog.reset(frog.spawn_x, frog.spawn_y)
	active_char().invuln = 1.4
	ui.flash_red()

func _game_over() -> void:
	state = "end"
	ui.show_end(false, {"fruit": fruit, "diamonds": diamonds_collected, "total": total_diamonds, "level": level_index, "last": false})

func _level_clear() -> void:
	state = "end"
	var last := level_index + 1 >= Levels.DATA.size()
	ui.show_end(true, {"fruit": fruit, "diamonds": diamonds_collected, "total": total_diamonds, "level": level_index, "last": last})

# ----------------------------------------------------------------- loop
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		if state == "play":
			pause()
		elif state == "pause":
			resume()
	var dt: float = min(0.033, delta)
	if state == "play":
		_update(dt)

func _update(dt: float) -> void:
	if freeze > 0.0:
		freeze -= dt
		fx.step(dt)
		return
	if swap_cooldown > 0.0:
		swap_cooldown -= dt

	if Input.is_action_just_pressed("swap") and swap_cooldown <= 0.0:
		do_swap()

	var a := active_char()
	var o := inactive_char()
	a.update(dt, self, true)
	o.update(dt, self, false)

	# king hammer vs boxes & pigs
	var hb = king.hammer_hitbox()
	if hb != null:
		_break_boxes(hb)
		for p in pigs:
			if not p.dead and hb.intersects(p.rect()):
				p.kill()
				spawn_dust(p.cx(), p.cy(), 10, Color("#f0a6c0"))

	for p in pigs:
		p.update(dt, self)

	_check_hazards(a)
	_check_pickups(a)

	# door
	if not door.is_empty():
		var open := diamonds_collected >= total_diamonds
		if open and not door.opened:
			door.opened = true
			if door.node.has_method("open"):
				door.node.open()
			elif door.node.has_method("play"):
				door.node.play("opening")
		if open:
			var d_rect := Rect2(door.x + 4, door.y - 28, TILE - 8, TILE * 2 - 8)
			if d_rect.intersects(a.rect()):
				_level_clear()

	# item bob
	var bob := sin(Time.get_ticks_msec() / 240.0) * 2.0
	for f in fruits:
		if not f.got:
			f.node.position.y = f.base_y + bob
	for d in diamond_list:
		if not d.got:
			d.node.position.y = d.base_y + bob

	fx.step(dt)

func _break_boxes(hb: Rect2) -> void:
	var x0 := floori(hb.position.x / TILE)
	var x1 := floori((hb.position.x + hb.size.x) / TILE)
	var y0 := floori(hb.position.y / TILE)
	var y1 := floori((hb.position.y + hb.size.y) / TILE)
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			if ty < 0 or ty >= Levels.H or tx < 0 or tx >= Levels.W:
				continue
			var b = boxmap[ty][tx]
			if b != null and not b.broken:
				_smash_column(tx, ty)

func _smash_column(tx: int, ty: int) -> void:
	var to_break: Array = [[tx, ty]]
	var yy := ty - 1
	while yy >= 0 and boxmap[yy][tx] != null and not boxmap[yy][tx].broken:
		to_break.append([tx, yy])
		yy -= 1
	yy = ty + 1
	while yy < Levels.H and boxmap[yy][tx] != null and not boxmap[yy][tx].broken:
		to_break.append([tx, yy])
		yy += 1
	var cols := [Color("#a9762f"), Color("#c79a55"), Color("#6e4a1c")]
	for cell in to_break:
		var bx: int = cell[0]
		var by: int = cell[1]
		var b: Dictionary = boxmap[by][bx]
		b.broken = true
		b.node.visible = false
		for i in range(6):
			spawn_dust(bx * TILE + 16, by * TILE + 16, 1, cols[i % 3])

func _check_hazards(a: Character) -> void:
	if a.invuln > 0.0:
		return
	for s in spikes:
		var rs := Rect2(s.x + 4, s.y + 10, TILE - 8, TILE - 10)
		if rs.intersects(a.rect()):
			hurt()
			return
	for sw in saws:
		var rw := Rect2(sw.x + 2, sw.y + 2, TILE - 4, TILE - 4)
		if rw.intersects(a.rect()):
			hurt()
			return
	for p in pigs:
		if p.dead:
			continue
		if p.rect().intersects(a.rect()):
			var hb = a.hammer_hitbox() if a == king else null
			if hb != null and hb.intersects(p.rect()):
				p.kill()
				spawn_dust(p.cx(), p.cy(), 10, Color("#f0a6c0"))
			else:
				hurt()
				return

func _check_pickups(a: Character) -> void:
	var ar := a.rect()
	for f in fruits:
		if f.got:
			continue
		if _point_in_rect(f.x, f.y, ar, 14):
			f.got = true
			f.node.visible = false
			fruit += 1
			_sync_hud()
			ui.bump_fruit()
			spawn_dust(f.x, f.y, 5, Color("#ff8a7a"))
	for d in diamond_list:
		if d.got:
			continue
		if _point_in_rect(d.x, d.y, ar, 16):
			d.got = true
			d.node.visible = false
			diamonds_collected += 1
			_sync_hud()
			ui.bump_diamond()
			spawn_dust(d.x, d.y, 10, Color("#7fe0ff"))
			if diamonds_collected >= total_diamonds:
				ui.door_unlocked()

func _point_in_rect(px: float, py: float, rct: Rect2, pad: float) -> bool:
	return px > rct.position.x - pad and px < rct.position.x + rct.size.x + pad \
		and py > rct.position.y - pad and py < rct.position.y + rct.size.y + pad

# ----------------------------------------------------------------- fx
func spawn_dust(px: float, py: float, n: int, color: Color) -> void:
	for i in range(n):
		var ang := randf() * TAU
		var sp := 60.0 + randf() * 140.0
		fx.add(px, py, cos(ang) * sp, sin(ang) * sp - 40.0, 0.3 + randf() * 0.3, color, randf_range(2.0, 5.0))

func on_hammer_start(k: Character) -> void:
	var hb = k.hammer_hitbox()
	if hb != null:
		spawn_dust(hb.position.x + hb.size.x / 2.0, hb.position.y + hb.size.y / 2.0, 4, Color("#cfc4b0"))

# ----------------------------------------------------------------- hud
func _sync_hud() -> void:
	ui.set_hearts(hearts)
	ui.set_fruit(fruit)
	ui.set_diamonds(diamonds_collected, total_diamonds)

func _update_swap_portrait() -> void:
	ui.set_swap_portrait(inactive_char().kind)

# ----------------------------------------------------------------- background
func _redraw_background() -> void:
	queue_redraw()

func _draw() -> void:
	var tints := [[Color("#1a2440"), Color("#0d1326")], [Color("#241a30"), Color("#120c1c")], [Color("#0f2630"), Color("#08161c")]]
	var pal: Array = tints[level_index % tints.size()]
	draw_rect(Rect2(0, 0, VW, VH), pal[1])
	# vertical gradient via a few bands
	for i in range(12):
		var k := i / 12.0
		var col: Color = pal[0].lerp(pal[1], k)
		draw_rect(Rect2(0, i * (VH / 12.0), VW, VH / 12.0 + 1), col)
	# stars
	for i in range(60):
		var sx := (i * 97) % VW
		var sy := (i * 53) % (VH - 40)
		draw_rect(Rect2(sx, sy, 2, 2), Color(1, 1, 1, 0.10))
	# back wall behind the play field
	if state != "menu":
		var oy := (VH - Levels.H * TILE) / 2.0
		draw_rect(Rect2(0, oy, Levels.W * TILE, Levels.H * TILE), Color(0, 0, 0, 0.18))
