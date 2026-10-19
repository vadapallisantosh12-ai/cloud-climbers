class_name FxLayer
extends Node2D
## Lightweight batched particles drawn in one _draw call: dust puffs (hand-drawn
## cloud texture), sparkles, confetti, crumbs and speed streaks.

const PUFF := preload("res://assets/game/sky/cloud_puffy.webp")
const MAX_PARTICLES := 420

var parts: Array[Dictionary] = []

func _process(delta: float) -> void:
	if parts.is_empty():
		return
	var i := parts.size() - 1
	while i >= 0:
		var p: Dictionary = parts[i]
		p.life -= delta
		if p.life <= 0.0:
			parts.remove_at(i)
		else:
			p.vel += Vector2(0, p.gravity) * delta
			p.vel *= pow(p.drag, delta)
			p.pos += p.vel * delta
			p.rot += p.spin * delta
		i -= 1
	queue_redraw()

func _emit(p: Dictionary) -> void:
	if parts.size() >= MAX_PARTICLES:
		parts.remove_at(0)
	p.max_life = p.life
	parts.append(p)

func _count(n: int) -> int:
	var settings := get_node_or_null("/root/GameSettings")
	var scale := 1.0 if settings == null else float(settings.particle_scale())
	return maxi(1, roundi(n * scale))

func puff(pos: Vector2, count: int = 6, color: Color = Color(1, 1, 1, 0.9), spread: float = 60.0, size: float = 0.09) -> void:
	for i in _count(count):
		var a := randf_range(PI * 1.05, PI * 1.95) if randf() < 0.7 else randf() * TAU
		_emit({"kind": "puff", "pos": pos + Vector2(randf_range(-16, 16), randf_range(-4, 4)),
			"vel": Vector2.from_angle(a) * randf_range(spread * 0.4, spread), "gravity": -20.0, "drag": 0.08,
			"life": randf_range(0.35, 0.6), "size": size * randf_range(0.7, 1.3), "rot": randf() * TAU,
			"spin": randf_range(-2, 2), "color": color})

func sparkle(pos: Vector2, count: int = 8, color: Color = Color("fff3a0"), speed: float = 220.0) -> void:
	for i in _count(count):
		_emit({"kind": "spark", "pos": pos, "vel": Vector2.from_angle(randf() * TAU) * randf_range(speed * 0.3, speed),
			"gravity": 120.0, "drag": 0.2, "life": randf_range(0.3, 0.7), "size": randf_range(5.0, 10.0),
			"rot": randf() * TAU, "spin": randf_range(-6, 6), "color": color})

func confetti(pos: Vector2, count: int = 40, spread: float = 520.0) -> void:
	var palette := [Color("ff7a6b"), Color("ffd35c"), Color("7ed3a8"), Color("7cc8f2"), Color("c49cf0"), Color("fffaf0")]
	for i in _count(count):
		var a := randf_range(-PI * 0.92, -PI * 0.08)
		_emit({"kind": "confetti", "pos": pos + Vector2(randf_range(-30, 30), 0), "vel": Vector2.from_angle(a) * randf_range(spread * 0.45, spread),
			"gravity": 520.0, "drag": 0.35, "life": randf_range(1.2, 2.2), "size": randf_range(6.0, 11.0),
			"rot": randf() * TAU, "spin": randf_range(-10, 10), "color": palette[randi() % palette.size()]})

func crumbs(pos: Vector2, width: float, count: int = 12, color: Color = Color("d9a45a")) -> void:
	for i in _count(count):
		_emit({"kind": "crumb", "pos": pos + Vector2(randf_range(-width * 0.5, width * 0.5), randf_range(-4, 6)),
			"vel": Vector2(randf_range(-90, 90), randf_range(-160, 20)), "gravity": 1300.0, "drag": 0.6,
			"life": randf_range(0.6, 1.0), "size": randf_range(4.0, 9.0), "rot": randf() * TAU,
			"spin": randf_range(-8, 8), "color": color.darkened(randf_range(0.0, 0.3))})

func streak(pos: Vector2, color: Color = Color(1, 1, 1, 0.55)) -> void:
	_emit({"kind": "streak", "pos": pos, "vel": Vector2(0, 900), "gravity": 0.0, "drag": 1.0,
		"life": 0.25, "size": randf_range(30.0, 70.0), "rot": 0.0, "spin": 0.0, "color": color})

func flame(pos: Vector2) -> void:
	for i in _count(3):
		_emit({"kind": "spark", "pos": pos + Vector2(randf_range(-6, 6), 0), "vel": Vector2(randf_range(-50, 50), randf_range(260, 420)),
			"gravity": 0.0, "drag": 0.05, "life": randf_range(0.18, 0.32), "size": randf_range(7.0, 12.0),
			"rot": randf() * TAU, "spin": randf_range(-6, 6), "color": [Color("ffd35c"), Color("ff8a4c"), Color("fff3c0")][randi() % 3]})

func clear() -> void:
	parts.clear()
	queue_redraw()

func _draw() -> void:
	var puff_size := PUFF.get_size()
	for p: Dictionary in parts:
		var t: float = clampf(p.life / p.max_life, 0.0, 1.0)
		var c: Color = p.color
		match String(p.kind):
			"puff":
				var s: float = p.size * (1.6 - t * 0.6)
				c.a *= t
				draw_set_transform(p.pos, p.rot, Vector2(s, s))
				draw_texture(PUFF, -puff_size * 0.5, c)
			"spark":
				c.a *= minf(1.0, t * 2.0)
				draw_set_transform(p.pos, p.rot, Vector2.ONE * (0.4 + t * 0.6))
				var r: float = p.size
				draw_colored_polygon(PackedVector2Array([Vector2(0, -r), Vector2(r * 0.28, -r * 0.28), Vector2(r, 0),
					Vector2(r * 0.28, r * 0.28), Vector2(0, r), Vector2(-r * 0.28, r * 0.28), Vector2(-r, 0), Vector2(-r * 0.28, -r * 0.28)]), c)
			"confetti":
				c.a *= minf(1.0, t * 3.0)
				draw_set_transform(p.pos, p.rot, Vector2(1.0, absf(sin(p.rot * 1.7)) * 0.8 + 0.2))
				draw_rect(Rect2(-p.size * 0.5, -p.size * 0.3, p.size, p.size * 0.6), c)
			"crumb":
				c.a *= minf(1.0, t * 2.5)
				draw_set_transform(p.pos, p.rot, Vector2.ONE)
				draw_rect(Rect2(-p.size * 0.5, -p.size * 0.5, p.size, p.size * 0.8), c)
			"streak":
				c.a *= t
				draw_set_transform(p.pos, 0.0, Vector2.ONE)
				draw_line(Vector2.ZERO, Vector2(0, -p.size), c, 3.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
