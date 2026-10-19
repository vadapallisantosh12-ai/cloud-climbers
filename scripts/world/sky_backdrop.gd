class_name SkyBackdrop
extends Node2D
## Full-screen backdrop behind the column. Colours come from TowerData.SKY so
## the day → sunset → starry night journey is data-driven.

const CLOUD_TEXTURES := [preload("res://assets/game/sky/cloud_puffy.webp"), preload("res://assets/game/sky/cloud_wisp.webp")]
const ROOFTOPS := preload("res://assets/game/sky/rooftops.webp")
const MOON := preload("res://assets/game/sky/moon.webp")
const PLANET := preload("res://assets/game/sky/planet.webp")

var cam_y := 0.0
var home_y := 0.0  ## Camera y at the start of the climb (rooftops rest here).
var meters := 0.0
var sky: Dictionary = TowerData.SKY[0]
var flash := 0.0
var _t := 0.0
var _stars: Array[Dictionary] = []
var _clouds: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 77
	for i in 150:
		_stars.append({"x": _rng.randf(), "y": _rng.randf() * 1600.0, "r": _rng.randf_range(0.8, 2.4),
			"tw": _rng.randf_range(1.0, 3.5), "ph": _rng.randf() * TAU, "big": _rng.randf() < 0.08})
	for i in 9:
		_clouds.append({"x": _rng.randf(), "y": _rng.randf() * 1800.0, "f": _rng.randf_range(0.12, 0.42),
			"tex": _rng.randi() % 2, "s": _rng.randf_range(0.35, 0.8), "drift": _rng.randf_range(6.0, 18.0), "flip": _rng.randf() < 0.5})

func update_view(camera_y: float, current_meters: float, delta: float) -> void:
	cam_y = camera_y
	meters = current_meters
	sky = TowerData.sky_at(meters)
	_t += delta
	flash = maxf(0.0, flash - delta * 1.8)
	queue_redraw()

func world_tint() -> Color:
	return sky.tint

func _draw() -> void:
	var size := get_viewport_rect().size
	var top: Color = sky.top
	var bottom: Color = sky.bottom
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
		PackedColorArray([top, top, bottom, bottom]))
	var climb := home_y - cam_y  # px climbed by the camera
	# Stars (screen-space with slight parallax).
	var star_alpha: float = sky.stars
	if star_alpha > 0.01:
		for s: Dictionary in _stars:
			var y := fposmod(float(s.y) + climb * 0.04, 1600.0) * size.y / 1600.0 * 1.0
			var a := star_alpha * (0.55 + 0.45 * sin(_t * float(s.tw) + float(s.ph)))
			var p := Vector2(float(s.x) * size.x, y)
			if bool(s.big):
				var r := float(s.r) * 2.6
				var c := Color(1, 0.97, 0.85, a)
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r * 2), p + Vector2(r * 0.4, -r * 0.4), p + Vector2(r * 2, 0), p + Vector2(r * 0.4, r * 0.4),
					p + Vector2(0, r * 2), p + Vector2(-r * 0.4, r * 0.4), p + Vector2(-r * 2, 0), p + Vector2(-r * 0.4, -r * 0.4)]), c)
			else:
				draw_circle(p, float(s.r), Color(1, 1, 0.95, a))
	# Moon rises with the night; the ringed planet joins in deep sky.
	if star_alpha > 0.05:
		var moon_y := lerpf(size.y * 0.55, size.y * 0.16, clampf((meters - 780.0) / 900.0, 0.0, 1.0))
		var ms := 0.62
		draw_texture_rect(MOON, Rect2(Vector2(size.x * 0.86 - MOON.get_width() * ms * 0.5, moon_y), MOON.get_size() * ms), false, Color(1, 1, 1, clampf(star_alpha * 1.3, 0, 1)))
	if meters > 1250.0:
		var pa := clampf((meters - 1250.0) / 300.0, 0.0, 1.0)
		var py := lerpf(size.y * 0.8, size.y * 0.42, clampf((meters - 1250.0) / 1200.0, 0.0, 1.0))
		var ps := 0.55
		draw_texture_rect(PLANET, Rect2(Vector2(size.x * 0.1, py), PLANET.get_size() * ps), false, Color(1, 1, 1, pa))
	# Parallax clouds.
	var cloud_color: Color = sky.cloud
	var cloud_alpha := lerpf(0.95, 0.28, clampf(star_alpha, 0.0, 1.0))
	for c: Dictionary in _clouds:
		var tex: Texture2D = CLOUD_TEXTURES[int(c.tex)]
		var s := float(c.s)
		var w := tex.get_width() * s
		var span := size.y + 700.0
		var y := fposmod(float(c.y) + climb * float(c.f), span) - 350.0
		var x := fposmod(float(c.x) * (size.x + w) + _t * float(c.drift), size.x + w) - w
		var col := cloud_color
		col.a = cloud_alpha * (0.55 + float(c.f))
		draw_texture_rect(tex, Rect2(Vector2(x, y), Vector2(w if not bool(c.flip) else -w, tex.get_height() * s)), false, col)
	# Storybook rooftops at the start, sinking away as the camera climbs.
	var roof_scale := 0.78
	var roof_w := ROOFTOPS.get_width() * roof_scale
	var roof_h := ROOFTOPS.get_height() * roof_scale
	var roof_y := size.y - roof_h + 40.0 + climb * 0.55
	if roof_y < size.y:
		var tint: Color = (sky.tint as Color).lerp(Color.WHITE, 0.4)
		var count := int(ceil(size.x / roof_w)) + 1
		var start_x := (size.x - count * roof_w) * 0.5
		for i in count:
			var flip := i % 2 == 1
			draw_texture_rect(ROOFTOPS, Rect2(Vector2(start_x + i * roof_w + (roof_w if flip else 0.0), roof_y), Vector2(-roof_w if flip else roof_w, roof_h)), false, tint)
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.98, 0.85, flash * 0.35))
