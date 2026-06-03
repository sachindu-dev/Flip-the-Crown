class_name UI
extends CanvasLayer
# Port of ui.js — DOM overlays recreated as Godot Controls.

const INK := Color("#1d1626")
const INK_SOFT := Color("#2c2238")
const PAPER := Color("#f4ecdf")
const PAPER_DIM := Color("#d8ccb6")
const GOLD := Color("#f2c14e")
const GOLD_DEEP := Color("#c8932b")
const BLOOD := Color("#e0584b")

var game

var overlays := {}
var hearts: Array = []
var fruit_val: Label
var diamond_val: Label
var fruit_counter: Control
var diamond_counter: Control
var swap_chip: Control
var swap_portrait: TextureRect
var flash_rect: ColorRect
var end_title: Label
var end_stats: VBoxContainer
var end_buttons: VBoxContainer
var toast_label: Label
var toast_timer := 0.0

func setup(g) -> void:
	game = g
	layer = 10
	_build_hud()
	_build_main_menu()
	_build_pause()
	_build_end()
	_build_flash()
	_build_toast()

func _process(delta: float) -> void:
	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0:
			toast_label.get_parent().visible = false

# --------------------------------------------------------------- helpers
func _full(name: String) -> Control:
	var c := Control.new()
	c.name = name
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	overlays[name] = c
	return c

func _sbox(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(2)
	sb.border_color = border
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

func _btn(text: String, primary: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 52)
	b.add_theme_font_size_override("font_size", 18)
	b.focus_mode = Control.FOCUS_NONE
	var bg := GOLD if primary else INK_SOFT
	var border := Color("#fff3cf") if primary else PAPER_DIM
	b.add_theme_stylebox_override("normal", _sbox(bg, border))
	b.add_theme_stylebox_override("hover", _sbox(bg.lightened(0.12), border))
	b.add_theme_stylebox_override("pressed", _sbox(bg.darkened(0.12), border))
	b.add_theme_color_override("font_color", INK if primary else PAPER)
	b.add_theme_color_override("font_hover_color", INK if primary else PAPER)
	b.pressed.connect(cb)
	return b

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

# --------------------------------------------------------------- HUD
func _build_hud() -> void:
	var hud := _full("hud")

	var heart_box := HBoxContainer.new()
	heart_box.position = Vector2(16, 16)
	heart_box.add_theme_constant_override("separation", 6)
	hud.add_child(heart_box)
	var heart_tex := SheetUtil.first_frame("res://assets/Kings and Pigs/Sprites/12-Live and Coins/Small Heart Idle (18x14).png", 18, 14)
	for i in range(3):
		var tr := TextureRect.new()
		tr.texture = heart_tex
		tr.custom_minimum_size = Vector2(38, 30)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart_box.add_child(tr)
		hearts.append(tr)

	var counters := HBoxContainer.new()
	counters.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	counters.offset_left = -300
	counters.offset_right = -16
	counters.offset_top = 16
	counters.alignment = BoxContainer.ALIGNMENT_END
	counters.add_theme_constant_override("separation", 18)
	hud.add_child(counters)

	fruit_counter = _counter(SheetUtil.first_frame("res://assets/adventure/Items/Fruits/Apple.png", 32, 32), "0")
	fruit_val = fruit_counter.get_meta("val")
	counters.add_child(fruit_counter)

	diamond_counter = _counter(SheetUtil.first_frame("res://assets/Kings and Pigs/Sprites/12-Live and Coins/Small Diamond (18x14).png", 18, 14), "0/0")
	diamond_val = diamond_counter.get_meta("val")
	counters.add_child(diamond_counter)

	# swap chip bottom-left
	swap_chip = PanelContainer.new()
	(swap_chip as PanelContainer).add_theme_stylebox_override("panel", _sbox(Color(0.05, 0.035, 0.08, 0.6), Color(0.96, 0.93, 0.87, 0.2)))
	swap_chip.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	swap_chip.offset_left = 16
	swap_chip.offset_top = -60
	hud.add_child(swap_chip)
	var chip_row := HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 8)
	swap_chip.add_child(chip_row)
	var sl := _label("SWAP [X]", 13, PAPER)
	chip_row.add_child(sl)
	swap_portrait = TextureRect.new()
	swap_portrait.custom_minimum_size = Vector2(38, 38)
	swap_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	swap_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chip_row.add_child(swap_portrait)

func _counter(icon: Texture2D, val: String) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _sbox(Color(0.05, 0.035, 0.08, 0.55), Color(0.96, 0.93, 0.87, 0.18)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var ic := TextureRect.new()
	ic.texture = icon
	ic.custom_minimum_size = Vector2(26, 26)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(ic)
	var lbl := _label(val, 18, PAPER)
	row.add_child(lbl)
	panel.set_meta("val", lbl)
	return panel

# --------------------------------------------------------------- main menu
func _build_main_menu() -> void:
	var m := _full("mainMenu")
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	m.add_child(v)

	var t1 := _label("THE ROYAL", 44, PAPER)
	v.add_child(t1)
	var t2 := _label("SWAP", 80, GOLD)
	v.add_child(t2)
	var tag := _label("TWO CROWNS, ONE PATH", 22, PAPER_DIM)
	v.add_child(tag)
	v.add_child(_spacer(10))
	v.add_child(_btn("PLAY", true, func(): game.start_game()))
	v.add_child(_btn("QUIT", false, func(): _quit()))

	var hint := _label("← → / A D move    SPACE jump    X swap    C hammer    ESC pause", 18, PAPER_DIM)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -44
	m.add_child(hint)

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

# --------------------------------------------------------------- pause
func _build_pause() -> void:
	var p := _full("pauseMenu")
	var dim := ColorRect.new()
	dim.color = Color(0.043, 0.031, 0.063, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(dim)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.add_child(v)
	v.add_child(_label("PAUSED", 40, PAPER))
	v.add_child(_spacer(8))
	v.add_child(_btn("RESUME", true, func(): game.resume()))
	v.add_child(_btn("MAIN MENU", false, func(): game.to_menu()))

# --------------------------------------------------------------- end screen
func _build_end() -> void:
	var e := _full("endScreen")
	var dim := ColorRect.new()
	dim.color = Color(0.043, 0.031, 0.063, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	e.add_child(dim)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	e.add_child(v)
	end_title = _label("LEVEL CLEAR", 40, GOLD)
	v.add_child(end_title)
	end_stats = VBoxContainer.new()
	end_stats.alignment = BoxContainer.ALIGNMENT_CENTER
	end_stats.add_theme_constant_override("separation", 4)
	v.add_child(end_stats)
	v.add_child(_spacer(8))
	end_buttons = VBoxContainer.new()
	end_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	end_buttons.add_theme_constant_override("separation", 12)
	v.add_child(end_buttons)

func show_end(win: bool, s: Dictionary) -> void:
	if win:
		end_title.text = "YOU ESCAPED!" if s.last else "LEVEL CLEAR"
		end_title.add_theme_color_override("font_color", GOLD)
	else:
		end_title.text = "GAME OVER"
		end_title.add_theme_color_override("font_color", BLOOD)
	for c in end_stats.get_children():
		c.queue_free()
	end_stats.add_child(_label("LEVEL %02d" % (s.level + 1), 24, PAPER_DIM))
	end_stats.add_child(_label("FRUIT %d" % s.fruit, 24, PAPER_DIM))
	end_stats.add_child(_label("DIAMONDS %d/%d" % [s.diamonds, s.total], 24, PAPER_DIM))
	for c in end_buttons.get_children():
		c.queue_free()
	if win and not s.last:
		end_buttons.add_child(_btn("NEXT LEVEL", true, func(): game.next_level()))
		end_buttons.add_child(_btn("MAIN MENU", false, func(): game.to_menu()))
	elif win and s.last:
		end_buttons.add_child(_btn("PLAY AGAIN", true, func(): game.start_game()))
		end_buttons.add_child(_btn("MAIN MENU", false, func(): game.to_menu()))
	else:
		end_buttons.add_child(_btn("RESTART LEVEL", true, func(): game.restart_level()))
		end_buttons.add_child(_btn("MAIN MENU", false, func(): game.to_menu()))
	show_only(["endScreen"])

# --------------------------------------------------------------- flash + toast
func _build_flash() -> void:
	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_rect)

func _build_toast() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _sbox(Color(0.05, 0.035, 0.08, 0.85), Color(1, 1, 1, 0.15)))
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -360
	panel.offset_top = -56
	panel.offset_right = -14
	panel.offset_bottom = -14
	panel.visible = false
	add_child(panel)
	toast_label = _label("", 16, PAPER_DIM)
	panel.add_child(toast_label)

# --------------------------------------------------------------- API
func show_only(ids: Array) -> void:
	for id in overlays:
		overlays[id].visible = ids.has(id)

func set_hearts(n: int) -> void:
	for i in range(hearts.size()):
		hearts[i].modulate = Color.WHITE if i < n else Color(0.25, 0.2, 0.22, 0.55)

func pop_heart(idx: int) -> void:
	if idx < 0 or idx >= hearts.size():
		return
	var h: TextureRect = hearts[idx]
	var tw := create_tween()
	tw.tween_property(h, "scale", Vector2(1.35, 1.35), 0.06)
	tw.tween_property(h, "scale", Vector2(1, 1), 0.08)

func set_fruit(n: int) -> void:
	if fruit_val: fruit_val.text = str(n)

func set_diamonds(c: int, t: int) -> void:
	if diamond_val: diamond_val.text = "%d/%d" % [c, t]

func bump_fruit() -> void:
	_bump(fruit_counter)

func bump_diamond() -> void:
	_bump(diamond_counter)

func _bump(node: Control) -> void:
	if node == null: return
	node.pivot_offset = node.size / 2.0
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(1.18, 1.18), 0.1)
	tw.tween_property(node, "scale", Vector2(1, 1), 0.12)

func set_swap_portrait(kind: String) -> void:
	if swap_portrait == null: return
	if kind == "king":
		swap_portrait.texture = SheetUtil.first_frame("res://assets/Kings and Pigs/Sprites/01-King Human/Idle (78x58).png", 78, 58)
	else:
		swap_portrait.texture = SheetUtil.first_frame("res://assets/adventure/Main Characters/Ninja Frog/Idle (32x32).png", 32, 32)

func kick_swap_chip() -> void:
	if swap_chip == null: return
	swap_chip.pivot_offset = swap_chip.size / 2.0
	var tw := create_tween()
	tw.tween_property(swap_chip, "scale", Vector2(1.08, 1.08), 0.06)
	tw.tween_property(swap_chip, "scale", Vector2(1, 1), 0.08)

func flash() -> void:
	_do_flash(Color(1, 1, 1, 0.6))

func flash_red() -> void:
	_do_flash(Color(0.88, 0.35, 0.29, 0.6))

func _do_flash(c: Color) -> void:
	flash_rect.color = Color(c.r, c.g, c.b, c.a)
	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, 0.22)

func toast(text: String, ms: float) -> void:
	toast_label.text = text
	toast_label.get_parent().visible = true
	toast_timer = ms / 1000.0 if ms > 0.0 else 0.0

func door_unlocked() -> void:
	toast("DOOR UNLOCKED - reach the exit", 2600)

func _quit() -> void:
	get_tree().quit()
