extends SceneTree
# One-off generator (run headless):
#   godot --headless --script res://tools/build_level_scenes.gd
# Produces res://tilesets/terrain.tres and res://levels/Level1.tscn from the
# existing grid in Levels.DATA[0], so the level becomes editable in the 2D view.

const TILE := 32
const TERRAIN_PNG := "res://assets/adventure/Terrain/Terrain (16x16).png"
const TOP_TILE := Vector2i(1, 0)
const FILL_TILE := Vector2i(1, 1)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://tilesets")
	DirAccess.make_dir_recursive_absolute("res://levels")
	_build_tileset()
	_build_level(0, "res://levels/Level1.tscn")
	print("DONE building tileset + Level1.tscn")
	quit()

func _build_tileset() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	var src := TileSetAtlasSource.new()
	src.texture = load(TERRAIN_PNG)
	src.texture_region_size = Vector2i(16, 16)
	var tex: Texture2D = src.texture
	var cols := int(tex.get_width() / 16)
	var rows := int(tex.get_height() / 16)
	for ty in range(rows):
		for tx in range(cols):
			src.create_tile(Vector2i(tx, ty))
	ts.add_source(src, 0)
	var err := ResourceSaver.save(ts, "res://tilesets/terrain.tres")
	print("tileset save: ", err, " (", cols, "x", rows, " tiles)")

func _build_level(index: int, path: String) -> void:
	var grid: Array = Levels.DATA[index].grid
	var root := Node2D.new()
	root.name = "Level%d" % (index + 1)

	var tml := TileMapLayer.new()
	tml.name = "Terrain"
	tml.tile_set = load("res://tilesets/terrain.tres")
	tml.scale = Vector2(2, 2)
	root.add_child(tml)
	tml.owner = root

	var box_s := load("res://entities/Box.tscn")
	var spike_s := load("res://entities/Spike.tscn")
	var saw_s := load("res://entities/Saw.tscn")
	var fruit_s := load("res://entities/Fruit.tscn")
	var diamond_s := load("res://entities/Diamond.tscn")
	var door_s := load("res://entities/Door.tscn")
	var pig_s := load("res://entities/Pig.tscn")

	for r in range(Levels.H):
		var row: String = grid[r]
		for c in range(Levels.W):
			var ch := row[c]
			var px := c * TILE
			var py := r * TILE
			match ch:
				"#":
					var is_top: bool = (r == 0) or (String(grid[r - 1][c]) != "#")
					tml.set_cell(Vector2i(c, r), 0, TOP_TILE if is_top else FILL_TILE)
				"B":
					_add(root, box_s, px, py)
				"^":
					_add(root, spike_s, px, py)
				"~":
					_add(root, saw_s, px, py)
				"o":
					_add(root, fruit_s, px, py)
				"*":
					_add(root, diamond_s, px, py)
				"X":
					_add(root, door_s, px, py)
				"p":
					_add(root, pig_s, px + 2, py + 4)
				"K":
					_add_marker(root, "KingSpawn", px, py)
				"F":
					_add_marker(root, "FrogSpawn", px, py)

	var packed := PackedScene.new()
	var perr := packed.pack(root)
	print("pack ", path, ": ", perr)
	var serr := ResourceSaver.save(packed, path)
	print("save ", path, ": ", serr)

func _add(root: Node2D, scene: PackedScene, x: int, y: int) -> void:
	var n: Node2D = scene.instantiate()
	n.position = Vector2(x, y)
	root.add_child(n)
	n.owner = root

func _add_marker(root: Node2D, mname: String, x: int, y: int) -> void:
	var m := Marker2D.new()
	m.name = mname
	m.position = Vector2(x, y)
	m.add_to_group("spawn")
	root.add_child(m)
	m.owner = root
