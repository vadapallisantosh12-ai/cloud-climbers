class_name TowerGenerator
extends RefCounted
## Deterministic, seed-driven tower layout. The same seed always yields the same
## tower (that is what makes the Daily Challenge fair), independent of how the
## player moves: rows are produced strictly in order from one RNG stream.
##
## Output specs are plain dictionaries consumed by `game.gd`:
##   {"type": "platform", "kind", "x", "y", "scale", "move_speed", "phase", "spring_x"}
##   {"type": "pickup", "kind", "x", "y"}
##   {"type": "fish", "x", "y"}
##   {"type": "enemy", "x", "y", "speed", "phase"}

const W := GameConfig.COLUMN_WIDTH
const EDGE := 8.0

var rng := RandomNumberGenerator.new()
var seed_value := 0
var next_y := 0.0
var last_x := W * 0.5
var last_kind := "grass"
var last_enemy_m := -1000.0
var last_rocket_m := -1000.0
var rows := 0

func _init(tower_seed: int) -> void:
	seed_value = tower_seed
	rng.seed = tower_seed
	next_y = GameConfig.START_Y - 96.0

## FNV-1a so the daily seed is identical on every platform and engine version.
static func seed_from_text(text: String) -> int:
	var h := 2166136261
	for byte in text.to_utf8_buffer():
		h = ((h ^ byte) * 16777619) & 0xffffffff
	return h

static func daily_key(unix_time: float = -1.0) -> String:
	var t := Time.get_unix_time_from_system() if unix_time < 0.0 else unix_time
	var d := Time.get_date_dict_from_unix_time(int(t))
	return "%04d%02d%02d" % [d.year, d.month, d.day]

static func daily_seed(key: String) -> int:
	return seed_from_text("cloud-climber-daily-" + key)

## Produce every spec whose row lies at or below `top_y` (world y, upwards negative).
func generate_until(top_y: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	while next_y > top_y:
		_row(out)
	return out

func _row(out: Array[Dictionary]) -> void:
	var meters := GameConfig.meters(next_y)
	var band := TowerData.band_for(meters)
	var gap := rng.randf_range(float(band.gap[0]), float(band.gap[1]))
	var y := next_y
	next_y -= gap
	rows += 1
	# --- Route platform (always reachable from the previous one) ----------------
	var kind := TowerData.weighted_pick(rng, band.route)
	if rows <= 3:
		kind = "grass"
	if kind == "moving" and last_kind == "cloud":
		kind = "grass" # a one-use cloud cannot be used to wait for a moving platform
	var scale := rng.randf_range(float(band.width[0]), float(band.width[1]))
	var half := float(TowerData.PLATFORM_KINDS[kind].width) * scale * 0.5
	var reach := float(band.reach)
	var x := fposmod(last_x + rng.randf_range(-reach, reach), W)
	x = clampf(x, half + EDGE, W - half - EDGE)
	var platform := {"type": "platform", "kind": kind, "x": x, "y": y, "scale": scale,
		"move_speed": 0.0, "phase": 0.0, "spring_x": 0.0, "row": rows}
	if kind == "moving":
		platform.move_speed = rng.randf_range(float(band.move_speed[0]), float(band.move_speed[1]))
		platform.phase = rng.randf()
	if kind == "spring":
		platform.spring_x = rng.randf_range(-half * 0.45, half * 0.45)
	out.append(platform)
	# --- Decoy / alternative platform -------------------------------------------
	if rows > 2 and rng.randf() < float(band.decoy):
		var decoy_kind := TowerData.weighted_pick(rng, band.decoy_kinds)
		var decoy_scale := rng.randf_range(float(band.width[0]), float(band.width[1]))
		var decoy_half := float(TowerData.PLATFORM_KINDS[decoy_kind].width) * decoy_scale * 0.5
		var min_sep := half + decoy_half + 30.0
		var dx := x
		for attempt in 6:
			dx = rng.randf_range(decoy_half + EDGE, W - decoy_half - EDGE)
			if absf(dx - x) >= min_sep:
				break
		if absf(dx - x) >= min_sep:
			var dy := y + rng.randf_range(-gap * 0.35, gap * 0.25)
			out.append({"type": "platform", "kind": decoy_kind, "x": dx, "y": dy, "scale": decoy_scale,
				"move_speed": 0.0, "phase": 0.0, "spring_x": 0.0, "row": rows})
	# --- Fish trail between the previous and this route platform ----------------
	if rng.randf() < float(band.fish):
		var count := rng.randi_range(3, 5)
		var from := Vector2(last_x, y + gap - 70.0)
		var to := Vector2(x, y - 70.0)
		if absf(to.x - from.x) > W * 0.5:
			from.x = to.x # never draw a trail across the whole column
		for i in count:
			var t := (float(i) + 0.5) / float(count)
			var p := from.lerp(to, t) + Vector2(0, -sin(t * PI) * 60.0)
			out.append({"type": "fish", "x": p.x, "y": p.y})
	# --- Power-up resting on a static route platform ------------------------------
	if meters > TowerData.SAFE_START_METERS and kind == "grass" and rng.randf() < float(band.pickup):
		var pickup := TowerData.weighted_pick(rng, TowerData.PICKUP_WEIGHTS)
		if pickup == "rocket" and meters - last_rocket_m < 90.0:
			pickup = "magnet"
		if pickup == "rocket":
			last_rocket_m = meters
		out.append({"type": "pickup", "kind": pickup, "x": x + rng.randf_range(-half * 0.4, half * 0.4), "y": y - 46.0})
	# --- Gloomling patrolling the gap above this platform --------------------------
	if meters > TowerData.SAFE_START_METERS and meters - last_enemy_m > TowerData.ENEMY_SPACING_METERS \
			and rng.randf() < float(band.enemy):
		last_enemy_m = meters
		var speed := rng.randf_range(70.0, 120.0) * (1.0 + clampf(meters / 2000.0, 0.0, 0.8))
		out.append({"type": "enemy", "x": rng.randf_range(60.0, W - 60.0), "y": y - gap * 0.55 - 30.0,
			"speed": speed, "phase": rng.randf() * TAU})
	last_x = x
	last_kind = kind
