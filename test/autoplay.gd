extends Node
## Autoplay harness: a simple bot climbs the tower so we can check reachability,
## run length and difficulty. Set CAPTURE=1 (with a display) to save screenshots.
## Usage: godot --headless --path . --fixed-fps 60 res://test/autoplay.tscn

var main: Main
var game: ClimbGame
var capture := OS.get_environment("CAPTURE") == "1"
var target: TowerPlatform
var runs := int(OS.get_environment("RUNS")) if OS.get_environment("RUNS") != "" else 3
var results: Array = []
var shots := {}
var _last_vy := 0.0
var _stuck_m := -1
var _stuck_count := 0

func _ready() -> void:
	print("BOT start")
	SaveStore.save_path = "user://autoplay_save.json"
	SaveStore.tutorial_done = true
	SaveStore.name_prompted = true
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	game = main.game
	game.run_finished.connect(func(s: Dictionary): results.append(s))
	if capture:
		await _shot("01_title")
	for i in runs:
		var m := "daily" if i == 0 else "endless"
		main._begin_run(m)
		await _play()
		print("PLAY END i=%d state=%d meters=%d time=%.1f platforms=%d" % [i, game.state, game.meters, game.run_time, game.platforms.size()])
		if capture and i == 0:
			await get_tree().create_timer(1.6).timeout
			await _shot("09_results")
	for s: Dictionary in results:
		print("RUN mode=%s meters=%d time=%.1f fish=%d stomps=%d springs=%d powerups=%d cause=%s" % [s.mode, s.meters, s.time, s.fish, s.stomps, s.springs, s.powerups, s.cause])
	get_tree().quit()

func _play() -> void:
	var t := 0.0
	while game.state != ClimbGame.State.OVER and t < 400.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		if int(t * 60.0) % 600 == 0:
			var m_now := game.meters
			if m_now == _stuck_m:
				_stuck_count += 1
				if _stuck_count == 2:
					var cat := game.cat
					print("STUCK m=%d cat=(%.0f,%.0f) vy=%.0f" % [m_now, cat.position.x, cat.position.y, cat.velocity.y])
					for p: TowerPlatform in game.platforms:
						if p.position.y < cat.position.y + 150 and p.position.y > cat.position.y - 600:
							print("   plat %s x=%.0f y=%.0f dy=%.0f hw=%.0f solid=%s spring=%.0f" % [p.kind, p.position.x, p.position.y, cat.position.y - p.position.y, p.half_width, p.solid, p.spring_x])
					break
			else:
				_stuck_m = m_now
				_stuck_count = 0
		_steer()
		if capture:
			for tm: Array in [[3.0, "t03"], [8.0, "t08"], [15.0, "t15"]]:
				if t >= tm[0] and not shots.has(tm[1]):
					shots[tm[1]] = true
					await _shot(tm[1])
			for mark: Array in [[30, "02_early"], [180, "03_sunset"], [420, "04_dusk"], [700, "05_night"], [1100, "06_space"]]:
				if game.meters >= mark[0] and not shots.has(mark[1]):
					shots[mark[1]] = true
					await _shot(mark[1])
	await get_tree().process_frame

func _steer() -> void:
	var cat := game.cat
	var g := GameConfig.GRAVITY
	var vy := cat.velocity.y
	if OS.get_environment("BOTLOG") == "1" and vy < -500.0 and _last_vy >= 0.0:
		var tp := target.position if target != null and is_instance_valid(target) else Vector2.ZERO
		print("BOUNCE t=%.2f cat=(%.0f,%.0f) vy=%.0f target=(%.0f,%.0f) m=%d" % [game.run_time, cat.position.x, cat.position.y, vy, tp.x, tp.y, game.meters])
	if vy < -500.0 and _last_vy >= 0.0:
		target = null
	_last_vy = vy
	var apex_rise := (vy * vy) / (2.0 * g) if vy < 0.0 else 0.0
	if target == null or not is_instance_valid(target) or not target.solid or (vy > 0.0 and target.position.y < cat.position.y - 4.0) or target.position.y > cat.position.y + 400.0 or (vy < 0.0 and target.position.y >= cat.position.y - 2.0):
		target = null
		var best_score := -INF
		for p: TowerPlatform in game.platforms:
			if not p.solid or p.kind == "biscuit":
				continue
			var dy := cat.position.y - p.position.y
			var reach := apex_rise if vy < 0.0 else 0.0
			if dy > reach - 20.0 or dy < -260.0:
				continue
			var dx := absf(_wrap_dx(p.position.x - cat.position.x))
			var score := dy - dx * 0.35
			if p.kind == "spring" or p.spring_x != 0.0:
				score += 80.0
			if score > best_score:
				best_score = score
				target = p
	var axis := 0.0
	if target != null:
		var aim := target.position.x + (target.spring_x if target.spring_x != 0.0 else 0.0)
		var dx := _wrap_dx(aim - cat.position.x)
		axis = clampf(dx / 40.0, -1.0, 1.0)
	Input.action_release("move_left")
	Input.action_release("move_right")
	if axis < -0.1:
		Input.action_press("move_left", absf(axis))
	elif axis > 0.1:
		Input.action_press("move_right", axis)

func _wrap_dx(dx: float) -> float:
	var w := GameConfig.COLUMN_WIDTH
	return fposmod(dx + w * 0.5, w) - w * 0.5

func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := "/tmp/cc_shots"
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join(shot_name + ".png"))
	print("SHOT ", shot_name, " m=", game.meters)
