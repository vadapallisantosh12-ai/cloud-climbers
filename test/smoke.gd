extends SceneTree
## Finite smoke check for Cloud Climber: boots the shell, verifies deterministic
## daily towers and reachable route gaps, runs a short climb, exercises power-ups,
## pause, results, both languages and one-key retry.
## Enum values are compared as ints so this script does not compile game scripts
## before autoloads exist (SceneTree scripts load first).

const SCREEN_TITLE := 0
const SCREEN_PAUSED := 2
const SCREEN_RESULTS := 3
const STATE_PLAYING := 1

var failures: Array[String] = []

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("SMOKE: " + message)

func _initialize() -> void:
	call_deferred("_run")

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	var save := root.get_node("SaveStore")
	save.save_path = "user://smoke_save.json"
	save.name_prompted = true
	save.tutorial_done = true
	var gen_script: GDScript = load("res://scripts/world/tower_generator.gd")
	var cfg: GDScript = load("res://scripts/config/game_config.gd")
	var a: Array = gen_script.new(gen_script.daily_seed("20260927")).generate_until(-20000.0)
	var b: Array = gen_script.new(gen_script.daily_seed("20260927")).generate_until(-20000.0)
	var c: Array = gen_script.new(gen_script.daily_seed("20260928")).generate_until(-20000.0)
	_check(a.size() > 100 and JSON.stringify(a) == JSON.stringify(b), "daily tower is not deterministic")
	_check(JSON.stringify(a) != JSON.stringify(c), "different days produced the same tower")
	var jump: float = cfg.JUMP_SPEED * cfg.JUMP_SPEED / (2.0 * cfg.GRAVITY)
	for tower_seed in [1, 777, 424242]:
		var prev_y: float = cfg.START_Y
		var last_row := -1
		var worst := 0.0
		for spec: Dictionary in gen_script.new(tower_seed).generate_until(cfg.world_y_for(3000.0)):
			if spec.type == "platform" and int(spec.row) != last_row:
				last_row = int(spec.row)
				_check(spec.kind != "biscuit", "seed %d: fragile route platform on row %d" % [tower_seed, last_row])
				worst = maxf(worst, prev_y - float(spec.y))
				prev_y = float(spec.y)
		_check(worst < jump * 0.9, "seed %d: route gap %.0f exceeds safe jump height %.0f" % [tower_seed, worst, jump])
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _frames(5)
	_check(int(main.screen) == SCREEN_TITLE, "title screen did not open")
	main._begin_run("daily")
	await _frames(240)
	var game = main.game
	_check(int(game.state) == STATE_PLAYING, "run did not start")
	_check(game.platforms.size() > 8, "tower did not stream platforms")
	for kind in ["rocket", "shield", "magnet"]:
		game._activate(kind)
	await _frames(30)
	_check(game.rocket_time > 0.0 and game.cat.rocket, "rocket did not activate")
	_check(game.shield_time > 0.0 and game.magnet_time > 0.0, "shield or magnet did not activate")
	_check(game.meters > 0, "the cat did not climb")
	main._pause()
	_check(paused and int(main.screen) == SCREEN_PAUSED, "pause failed")
	main._resume()
	_check(not paused, "resume failed")
	game._end_run()
	await create_timer(1.6).timeout
	_check(int(main.screen) == SCREEN_RESULTS, "results screen did not open")
	_check(int(main.last_summary.meters) == int(game.meters), "summary meters mismatch")
	for locale in ["en", "zh-CN"]:
		root.get_node("I18n").set_locale(locale)
		await _frames(3)
		_check(root.get_node("I18n").t("title.main") != "title.main", "missing localization for " + locale)
	main._retry()
	await _frames(10)
	_check(int(game.state) == STATE_PLAYING, "retry did not restart")
	main.queue_free()
	await _frames(3)
	if failures.is_empty():
		print("[SMOKE_PASS] deterministic daily tower, reachable gaps, power-ups, pause, results, locales and retry verified")
		quit(0)
	else:
		print("[SMOKE_FAIL] ", failures)
		quit(1)
