class_name ClimbGame
extends Node2D
## Core climb: auto-bouncing kitten, platforms, power-ups, gloomlings, camera,
## streaming tower generation and run summary. UI and menus live in main.gd.

signal run_finished(summary: Dictionary)
signal milestone_reached(milestone: Dictionary)
signal hint_requested(kind: String)
signal fish_changed(total: int)
signal powerups_changed

enum State { ATTRACT, PLAYING, DYING, OVER }

const STEP := 1.0 / 120.0
const SPAWN_AHEAD := 900.0
const GENERATE_AHEAD := 1300.0
const DESPAWN_BELOW := 500.0
const DISPLAY_FONT := preload("res://assets/template/fonts/display/display_doodle.tres")

var state := State.ATTRACT
var mode := "daily"
var daily_key := ""
var seed_value := 0
var generator: TowerGenerator
var pending: Array[Dictionary] = []
var platforms: Array[TowerPlatform] = []
var items: Array[TowerItem] = []
var enemies: Array[Gloomling] = []

var camera := Camera2D.new()
var column := ColumnClip.new()
var markers := Markers.new()
var frame := ColumnFrame.new()
var fx := FxLayer.new()
var cat := CatActor.new()
var sky: SkyBackdrop

var view_size := Vector2(1280, 720)
var cam_y := 0.0
var cam_home := 0.0
var best_y := 0.0
var meters := 0
var run_time := 0.0
var fish := 0
var fish_toward_shield := 0
var stomps := 0
var springs := 0
var powerups_used := 0
var cause := "fall"
var rocket_time := 0.0
var shield_time := 0.0
var magnet_time := 0.0
var next_milestone := 0
var local_best_m := 0
var input_axis := 0.0
var pointer_active := false
var pointer_screen_x := 0.0
var _accum := 0.0
var _hitstop := 0.0
var _shake := 0.0
var _over_timer := 0.0
var _seen_kinds: Dictionary = {}
var _rocket_fx_timer := 0.0
var _last_wrap_x := 0.0

func _ready() -> void:
	add_child(camera)
	camera.position = Vector2(GameConfig.COLUMN_WIDTH * 0.5, 0)
	camera.make_current()
	column.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	add_child(column)
	column.add_child(markers)
	for layer_name in ["Platforms", "Items", "Enemies"]:
		var layer := Node2D.new()
		layer.name = layer_name
		column.add_child(layer)
	column.add_child(cat)
	column.add_child(fx)
	add_child(frame)
	markers.game = self
	frame.game = self

func _layer(layer_name: String) -> Node2D:
	return column.get_node(layer_name) as Node2D

## Build a fresh tower for `tower_seed` and put the cat on the start rooftop.
func build(tower_seed: int, run_mode: String, key: String, best_m: int) -> void:
	seed_value = tower_seed
	mode = run_mode
	daily_key = key
	local_best_m = best_m
	for layer_name in ["Platforms", "Items", "Enemies"]:
		for child in _layer(layer_name).get_children():
			child.queue_free()
	platforms.clear()
	items.clear()
	enemies.clear()
	pending.clear()
	fx.clear()
	generator = TowerGenerator.new(tower_seed)
	_update_view_size()
	# Wide starting ledge across the column.
	_spawn_platform({"type": "platform", "kind": "grass", "x": GameConfig.COLUMN_WIDTH * 0.5, "y": GameConfig.START_Y,
		"scale": 3.9, "move_speed": 0.0, "phase": 0.0, "spring_x": 0.0, "row": 0})
	cat.reset_visual()
	cat.position = Vector2(GameConfig.COLUMN_WIDTH * 0.5, GameConfig.START_Y)
	cam_y = GameConfig.START_Y - view_size.y * (0.5 - 0.2)
	cam_home = cam_y
	if sky != null:
		sky.home_y = cam_home
	best_y = GameConfig.START_Y
	meters = 0
	run_time = 0.0
	fish = 0
	fish_toward_shield = 0
	stomps = 0
	springs = 0
	powerups_used = 0
	cause = "fall"
	rocket_time = 0.0
	shield_time = 0.0
	magnet_time = 0.0
	next_milestone = 0
	_hitstop = 0.0
	_shake = 0.0
	_seen_kinds.clear()
	state = State.ATTRACT
	_stream_world()
	_apply_camera()
	powerups_changed.emit()
	fish_changed.emit(0)

func start_run() -> void:
	state = State.PLAYING
	cat.velocity = Vector2(0, -GameConfig.tuned("jump_speed", GameConfig.JUMP_SPEED))
	cat.landed()
	_sfx("bounce", 1.1)
	fx.puff(cat.position + Vector2(0, 4), 6)

func is_playing() -> bool:
	return state == State.PLAYING or state == State.DYING

func _update_view_size() -> void:
	view_size = get_viewport_rect().size

func _process(delta: float) -> void:
	_update_view_size()
	_purge_freed()
	delta = minf(delta, 1.0 / 20.0)
	if state == State.PLAYING or state == State.DYING:
		if _hitstop > 0.0:
			_hitstop -= delta
		else:
			_accum += delta
			var steps := 0
			while _accum >= STEP and steps < 6:
				_step(STEP)
				_accum -= STEP
				steps += 1
			if steps == 6:
				_accum = 0.0
			run_time += delta
		_tick_timers(delta)
	elif state == State.OVER:
		_over_timer -= delta
	for p: TowerPlatform in platforms:
		p.tick(delta)
	for e: Gloomling in enemies:
		e.tick(delta)
	for it: TowerItem in items:
		it.tick(delta)
	cat.animate(delta, state == State.ATTRACT)
	_update_camera(delta)
	_stream_world()
	_check_hints()
	if sky != null:
		sky.update_view(cam_y, maxf(0.0, GameConfig.meters(cam_y + view_size.y * 0.2)), delta)
		column.modulate = sky.world_tint()
	column.queue_redraw()
	markers.queue_redraw()
	frame.queue_redraw()

# --- Simulation ----------------------------------------------------------------

func _purge_freed() -> void:
	platforms.assign(platforms.filter(func(n): return is_instance_valid(n) and not n.is_queued_for_deletion()))
	items.assign(items.filter(func(n): return is_instance_valid(n) and not n.collected))
	enemies.assign(enemies.filter(func(n): return is_instance_valid(n) and not n.is_queued_for_deletion()))

func _step(dt: float) -> void:
	var move_speed := GameConfig.tuned("move_speed", GameConfig.MOVE_SPEED)
	var accel := GameConfig.tuned("move_accel", GameConfig.MOVE_ACCEL)
	var gravity := GameConfig.tuned("gravity", GameConfig.GRAVITY)
	var axis := input_axis
	if state == State.PLAYING and pointer_active:
		var target_x := GameConfig.COLUMN_WIDTH * 0.5 + (pointer_screen_x - view_size.x * 0.5)
		var diff := target_x - cat.position.x
		axis = 0.0 if absf(diff) < GameConfig.MOUSE_DEADZONE else clampf(diff / 70.0, -1.0, 1.0)
	if state == State.DYING:
		axis = 0.0
	var v := cat.velocity
	var target_vx := axis * move_speed
	v.x = move_toward(v.x, target_vx, (accel if absf(axis) > 0.01 else GameConfig.MOVE_DECEL) * dt)
	if rocket_time > 0.0:
		v.y = -GameConfig.ROCKET_SPEED
	else:
		v.y = minf(v.y + gravity * dt, GameConfig.MAX_FALL_SPEED)
	var prev_y := cat.position.y
	cat.position += v * dt
	var wrapped := fposmod(cat.position.x, GameConfig.COLUMN_WIDTH)
	if absf(wrapped - cat.position.x) > 1.0:
		fx.puff(Vector2(wrapped, cat.position.y - 40.0), 3, Color(1, 1, 1, 0.7), 40.0, 0.06)
	cat.position.x = wrapped
	cat.velocity = v
	if state == State.PLAYING:
		if v.y > 0.0 and rocket_time <= 0.0:
			_check_landing(prev_y)
		_check_enemies()
		_check_items(dt)
		if cat.position.y < best_y:
			best_y = cat.position.y
			var m := int(floor(maxf(0.0, GameConfig.meters(best_y))))
			if m != meters:
				meters = m
				_check_milestones()
	# Out of the bottom of the screen: the climb is over.
	if cat.position.y > cam_y + view_size.y * 0.5 + GameConfig.DEATH_MARGIN and state != State.OVER:
		_end_run()

func _check_landing(prev_y: float) -> void:
	var best: TowerPlatform = null
	for p: TowerPlatform in platforms:
		if not p.solid:
			continue
		if prev_y <= p.position.y + 2.0 and cat.position.y >= p.position.y - 0.5 and cat.position.y <= p.position.y + GameConfig.COYOTE_PX + cat.velocity.y * STEP:
			if absf(cat.position.x - p.position.x) <= p.half_width + GameConfig.CAT_HALF_WIDTH * 0.6:
				if best == null or p.position.y < best.position.y:
					best = p
	if best == null:
		return
	var result := best.land(cat.position.x, fx)
	var speed := float(result.speed)
	match String(result.event):
		"crack":
			_sfx("crack")
			cat.velocity.y *= 0.35
			_shake_add(2.0)
			return
		"spring":
			springs += 1
			_sfx("spring")
			_shake_add(GameConfig.SHAKE_SPRING)
			fx.sparkle(cat.position + Vector2(0, -10), 10, Color("fff3a0"), 260.0)
		"poof":
			_sfx("poof")
			_sfx("bounce", 1.15)
		_:
			_sfx("bounce", 1.0 + clampf(meters / 3000.0, 0.0, 0.25))
	cat.position.y = best.position.y
	cat.velocity.y = -speed
	cat.landed()
	fx.puff(cat.position + Vector2(0, 2), 4 if result.event != "spring" else 7, Color(1, 1, 1, 0.85), 55.0, 0.07)

func _cat_center() -> Vector2:
	return cat.position + Vector2(0, -42)

func _check_enemies() -> void:
	var center := _cat_center()
	for e: Gloomling in enemies:
		if not e.alive:
			continue
		var d := center - e.position
		if absf(d.x) > GameConfig.ENEMY_RADIUS + 26.0 or absf(d.y) > GameConfig.ENEMY_RADIUS + 40.0:
			continue
		if d.length() > GameConfig.ENEMY_RADIUS + 34.0:
			continue
		var feet_above := cat.position.y <= e.position.y + GameConfig.ENEMY_STOMP_WINDOW
		if rocket_time > 0.0 or cat.velocity.y < -1300.0:
			_defeat_enemy(e, false)
		elif cat.velocity.y > 0.0 and feet_above:
			_defeat_enemy(e, true)
		elif cat.grace > 0.0:
			continue
		elif shield_time > 0.0:
			shield_time = 0.0
			cat.shield = false
			cat.grace = GameConfig.HIT_GRACE_SECONDS
			_sfx("shield_pop")
			fx.sparkle(center, 16, Color("bff3ff"), 300.0)
			e.defeat(cat.position.x)
			_shake_add(8.0)
			cat.velocity.y = minf(cat.velocity.y, -650.0)
			powerups_changed.emit()
		else:
			_hurt(e)
			return

func _defeat_enemy(e: Gloomling, stomp: bool) -> void:
	e.defeat(cat.position.x)
	stomps += 1
	_sfx("stomp")
	fx.puff(e.position, 7, Color(0.55, 0.55, 0.7, 0.9), 90.0, 0.08)
	fx.sparkle(e.position, 8, Color("fff3a0"), 220.0)
	_shake_add(GameConfig.SHAKE_STOMP)
	if stomp:
		cat.velocity.y = -GameConfig.STOMP_SPEED
		cat.landed()
		_hitstop = GameConfig.HITSTOP_STOMP

func _hurt(e: Gloomling) -> void:
	state = State.DYING
	cause = "enemy"
	cat.hurt = true
	cat.velocity = Vector2(signf(cat.position.x - e.position.x) * 220.0, 120.0)
	_sfx("hurt")
	fx.sparkle(_cat_center(), 12, Color("ffe066"), 260.0)
	_shake_add(GameConfig.SHAKE_HURT)
	_hitstop = 0.12
	_clear_powerups()

func _check_items(dt: float) -> void:
	var center := _cat_center()
	for it: TowerItem in items:
		if it.collected:
			continue
		var d := it.position.distance_to(center)
		if it.kind == "fish" and magnet_time > 0.0 and d < GameConfig.MAGNET_RADIUS:
			it.homing = true
		if it.homing:
			it.position = it.position.move_toward(center, GameConfig.MAGNET_PULL * dt)
			d = it.position.distance_to(center)
		if d < it.radius + 30.0:
			_collect(it)

func _collect(it: TowerItem) -> void:
	it.collected = true
	match it.kind:
		"fish":
			fish += 1
			fish_toward_shield += 1
			_sfx("fish", 1.0 + float(fish % 5) * 0.06)
			fx.sparkle(it.position, 5, Color("ffd35c"), 160.0)
			if fish_toward_shield >= GameConfig.FISH_FOR_SHIELD:
				fish_toward_shield = 0
				_activate("shield")
				hint_requested.emit("fish_shield")
			fish_changed.emit(fish)
		_:
			powerups_used += 1
			_activate(it.kind)
			fx.sparkle(it.position, 14, Color("fffaf0"), 280.0)
	var tw := it.create_tween().set_parallel(true)
	tw.tween_property(it, "scale", Vector2.ONE * 1.6, 0.18)
	tw.tween_property(it, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(it.queue_free)

func _activate(kind: String) -> void:
	match kind:
		"rocket":
			rocket_time = GameConfig.ROCKET_SECONDS
			cat.rocket = true
			cat.hurt = false
			_sfx("rocket")
			_shake_add(GameConfig.SHAKE_ROCKET * 2.0)
		"shield":
			shield_time = GameConfig.SHIELD_SECONDS
			cat.shield = true
			_sfx("powerup")
		"magnet":
			magnet_time = GameConfig.MAGNET_SECONDS
			cat.magnet = true
			_sfx("powerup", 1.1)
	powerups_changed.emit()

func _tick_timers(delta: float) -> void:
	if rocket_time > 0.0:
		rocket_time -= delta
		_rocket_fx_timer -= delta
		if _rocket_fx_timer <= 0.0:
			_rocket_fx_timer = 0.03
			fx.flame(cat.position + Vector2(0, 8))
			fx.streak(cat.position + Vector2(randf_range(-GameConfig.COLUMN_WIDTH * 0.5, GameConfig.COLUMN_WIDTH * 0.5), randf_range(-view_size.y * 0.6, 0)))
		_shake = maxf(_shake, GameConfig.SHAKE_ROCKET)
		if rocket_time <= 0.0:
			rocket_time = 0.0
			cat.rocket = false
			cat.velocity.y = -GameConfig.ROCKET_EXIT_SPEED
			_drop_rocket_shell()
			powerups_changed.emit()
	if shield_time > 0.0:
		shield_time -= delta
		if shield_time <= 0.0:
			shield_time = 0.0
			cat.shield = false
			_sfx("shield_pop", 1.2)
			powerups_changed.emit()
	if magnet_time > 0.0:
		magnet_time -= delta
		if magnet_time <= 0.0:
			magnet_time = 0.0
			cat.magnet = false
			powerups_changed.emit()

func _drop_rocket_shell() -> void:
	var shell := Sprite2D.new()
	shell.texture = CatActor.ROCKET_TEX
	shell.scale = cat.rocket_sprite.scale
	shell.position = cat.position + Vector2(0, -26)
	column.add_child(shell)
	var tw := shell.create_tween().set_parallel(true)
	tw.tween_property(shell, "position", shell.position + Vector2(randf_range(-80, 80), 700), 1.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(shell, "rotation", randf_range(-4, 4), 1.1)
	tw.tween_property(shell, "modulate:a", 0.0, 1.1)
	tw.chain().tween_callback(shell.queue_free)
	fx.puff(shell.position, 6)

func _clear_powerups() -> void:
	rocket_time = 0.0
	magnet_time = 0.0
	shield_time = 0.0
	cat.rocket = false
	cat.magnet = false
	cat.shield = false
	powerups_changed.emit()

func _check_milestones() -> void:
	while next_milestone < TowerData.MILESTONES.size() and meters >= int(TowerData.MILESTONES[next_milestone].m):
		var ms: Dictionary = TowerData.MILESTONES[next_milestone]
		next_milestone += 1
		_sfx("milestone")
		_shake_add(GameConfig.SHAKE_MILESTONE)
		fx.sparkle(_cat_center(), 24, Color("fff3a0"), 380.0)
		if sky != null:
			sky.flash = 1.0
		milestone_reached.emit(ms)

func _end_run() -> void:
	if state == State.OVER:
		return
	state = State.OVER
	_over_timer = 0.0
	_sfx("fall")
	_clear_powerups()
	run_finished.emit(summary())

func summary() -> Dictionary:
	return {"mode": mode, "daily_key": daily_key, "seed": seed_value, "meters": meters, "fish": fish,
		"time": run_time, "stomps": stomps, "springs": springs, "powerups": powerups_used, "cause": cause}

# --- Camera & feel ---------------------------------------------------------------

func _update_camera(delta: float) -> void:
	if state == State.PLAYING:
		var target := cat.position.y + view_size.y * GameConfig.CAMERA_LEAD
		if target < cam_y:
			var k := GameConfig.tuned("camera_follow", GameConfig.CAMERA_FOLLOW) * (1.6 if rocket_time > 0.0 else 1.0)
			cam_y = lerpf(cam_y, target, 1.0 - exp(-k * delta))
			# Never let the cat leave the top of the screen.
			cam_y = minf(cam_y, cat.position.y + view_size.y * 0.5 - 140.0)
	_shake = maxf(0.0, _shake - delta * 40.0)
	_apply_camera()

func _apply_camera() -> void:
	var settings := get_node_or_null("/root/GameSettings")
	var amount := _shake if settings == null or bool(settings.screen_shake) else 0.0
	camera.position = Vector2(GameConfig.COLUMN_WIDTH * 0.5, cam_y)
	camera.offset = Vector2(randf_range(-amount, amount), randf_range(-amount, amount)) if amount > 0.1 else Vector2.ZERO

func _shake_add(amount: float) -> void:
	_shake = maxf(_shake, amount)

func _sfx(cue: String, pitch: float = 1.0) -> void:
	var audio := get_node_or_null("/root/AudioDirector")
	if audio != null:
		audio.play(StringName(cue), pitch)

# --- Streaming -------------------------------------------------------------------

func view_top() -> float:
	return cam_y - view_size.y * 0.5

func view_bottom() -> float:
	return cam_y + view_size.y * 0.5

func _stream_world() -> void:
	if generator == null:
		return
	pending.append_array(generator.generate_until(view_top() - GENERATE_AHEAD))
	var spawn_line := view_top() - SPAWN_AHEAD
	var i := 0
	while i < pending.size():
		var spec: Dictionary = pending[i]
		if float(spec.y) > spawn_line:
			_spawn(spec)
			pending.remove_at(i)
		else:
			i += 1
	var cull := view_bottom() + DESPAWN_BELOW
	for list_index in 3:
		var list: Array = [platforms, items, enemies][list_index]
		var j := list.size() - 1
		while j >= 0:
			var node: Node2D = list[j]
			if not is_instance_valid(node) or node.position.y > cull:
				if is_instance_valid(node):
					node.queue_free()
				list.remove_at(j)
			j -= 1

func _spawn(spec: Dictionary) -> void:
	match String(spec.type):
		"platform":
			_spawn_platform(spec)
		"fish", "pickup":
			var it := TowerItem.new()
			_layer("Items").add_child(it)
			it.setup("fish" if spec.type == "fish" else String(spec.kind), Vector2(float(spec.x), float(spec.y)))
			items.append(it)
		"enemy":
			var e := Gloomling.new()
			_layer("Enemies").add_child(e)
			e.setup(spec, GameConfig.tuned("enemy_speed", 1.0))
			enemies.append(e)

func _spawn_platform(spec: Dictionary) -> void:
	var p := TowerPlatform.new()
	_layer("Platforms").add_child(p)
	p.setup(spec)
	platforms.append(p)

## Ask the shell to show a first-time hint when a new kind scrolls on screen.
func _check_hints() -> void:
	if state != State.PLAYING:
		return
	var visible_line := view_top() + 120.0
	for p: TowerPlatform in platforms:
		if p.position.y > visible_line and p.kind != "grass" and not _seen_kinds.has(p.kind):
			_seen_kinds[p.kind] = true
			hint_requested.emit(p.kind)
	for e: Gloomling in enemies:
		if e.position.y > visible_line and not _seen_kinds.has("enemy"):
			_seen_kinds["enemy"] = true
			hint_requested.emit("enemy")
	for it: TowerItem in items:
		if it.kind != "fish" and it.position.y > visible_line and not _seen_kinds.has(it.kind):
			_seen_kinds[it.kind] = true
			hint_requested.emit(it.kind)

# --- Helper nodes ------------------------------------------------------------------

## Clips the world to the column and paints its soft backdrop panel.
class ColumnClip extends Node2D:
	func _draw() -> void:
		var game := get_parent() as ClimbGame
		if game == null:
			return
		var top := game.view_top() - 40.0
		draw_rect(Rect2(0, top, GameConfig.COLUMN_WIDTH, game.view_size.y + 80.0), Color.WHITE)

## Best-height ribbon and milestone pennants painted inside the column.
class Markers extends Node2D:
	var game: ClimbGame
	func _draw() -> void:
		if game == null:
			return
		var font := ClimbGame.DISPLAY_FONT
		var top := game.view_top() - 60.0
		var bottom := game.view_bottom() + 60.0
		for ms: Dictionary in TowerData.MILESTONES:
			var y := GameConfig.world_y_for(float(ms.m))
			if y < top or y > bottom:
				continue
			var reached := game.meters >= int(ms.m)
			var c := Color(1, 1, 1, 0.5 if reached else 0.85)
			var x := 0.0
			while x < GameConfig.COLUMN_WIDTH:
				draw_line(Vector2(x, y), Vector2(x + 14, y), Color(1, 1, 1, 0.35), 3.0, true)
				x += 26.0
			draw_colored_polygon(PackedVector2Array([Vector2(8, y), Vector2(8, y - 34), Vector2(52, y - 26), Vector2(8, y - 18)]), Color("ff7a6b") if not reached else Color("7ed3a8"))
			draw_line(Vector2(8, y + 4), Vector2(8, y - 38), Color("6b4a33"), 3.0, true)
			draw_string_outline(font, Vector2(60, y - 12), "%d m" % int(ms.m), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 6, Color("5b3b2a"))
			draw_string(font, Vector2(60, y - 12), "%d m" % int(ms.m), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, c.lerp(Color.WHITE, 0.5))
		if game.local_best_m > 0:
			var by := GameConfig.world_y_for(float(game.local_best_m))
			if by > top and by < bottom:
				var beaten := game.meters > game.local_best_m
				var col := Color("ffd35c") if not beaten else Color(1, 1, 1, 0.4)
				var x2 := 0.0
				while x2 < GameConfig.COLUMN_WIDTH:
					draw_line(Vector2(x2, by), Vector2(x2 + 20, by), col, 4.0, true)
					x2 += 32.0
				var label := I18n.t("hud.best_line")
				var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
				draw_string_outline(font, Vector2(GameConfig.COLUMN_WIDTH - tw - 12, by - 10), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color("5b3b2a"))
				draw_string(font, Vector2(GameConfig.COLUMN_WIDTH - tw - 12, by - 10), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)

## Soft chalk borders showing the wrap edges of the column.
class ColumnFrame extends Node2D:
	var game: ClimbGame
	func _draw() -> void:
		if game == null:
			return
		var top := game.view_top() - 40.0
		var h := game.view_size.y + 80.0
		for x: float in [0.0, GameConfig.COLUMN_WIDTH]:
			draw_rect(Rect2(x - 3.0, top, 6.0, h), Color(1, 1, 1, 0.16))
			var y := top - fposmod(top, 36.0)
			while y < top + h:
				draw_line(Vector2(x, y), Vector2(x, y + 18.0), Color(1, 1, 1, 0.45), 2.0, true)
				y += 36.0
