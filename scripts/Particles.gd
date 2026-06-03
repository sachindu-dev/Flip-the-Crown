class_name Particles
extends Node2D
# Lightweight particle layer (port of entities.js Particle). Drawn as snapped
# rects so it reads as pixel-art dust.

var list: Array = []

func clear_all() -> void:
	list.clear()
	queue_redraw()

func add(px: float, py: float, vx: float, vy: float, life: float, color: Color, size: float) -> void:
	list.append({
		"x": px, "y": py, "vx": vx, "vy": vy,
		"life": life, "max": life, "color": color, "size": size,
	})

func step(dt: float) -> void:
	for i in range(list.size() - 1, -1, -1):
		var p: Dictionary = list[i]
		p.life -= dt
		p.vy += 480.0 * dt
		p.x += p.vx * dt
		p.y += p.vy * dt
		p.vx *= 0.92
		if p.life <= 0.0:
			list.remove_at(i)
	queue_redraw()

func _draw() -> void:
	for p in list:
		var k: float = clampf(p.life / p.max, 0.0, 1.0)
		var col: Color = p.color
		col.a = k
		var s: float = p.size
		draw_rect(Rect2(round(p.x - s / 2.0), round(p.y - s / 2.0), s, s), col)
