extends Node
## Captures every shell screen (both languages) plus high-altitude skies.
## Usage (needs a display): godot --audio-driver Dummy --path . res://test/ui_capture.tscn

var main: Main
var dir := "/tmp/cc_ui"

func _ready() -> void:
	SaveStore.save_path = "user://ui_capture_save.json"
	SaveStore.tutorial_done = false
	SaveStore.name_prompted = false
	SaveStore.hints_seen = []
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	DirAccess.make_dir_recursive_absolute(dir)
	await _wait(1.0)
	var mobile := OS.get_environment("MOBILE") == "1"
	if mobile:
		dir = "/tmp/cc_mobile"
		DirAccess.make_dir_recursive_absolute(dir)
		main.hud.touch_mode = true
		main.hud._layout()
	for locale: String in (["zh-CN"] if mobile else ["en", "zh-CN"]):
		I18n.set_locale(locale)
		await _wait(0.8)
		await _shot(locale + "_title")
		main._request_start("daily")
		await _wait(0.6)
		await _shot(locale + "_name")
		main._close_top_modal()
		main._begin_run("daily")
		await _wait(1.2)
		await _shot(locale + "_tutorial")
		main._pause()
		await _wait(0.5)
		await _shot(locale + "_pause")
		main._open_settings()
		await _wait(0.5)
		await _shot(locale + "_settings")
		main._close_all_modals()
		main._resume()
		for m: int in [420, 800, 1300]:
			_teleport(m)
			await _wait(0.9)
			if m == 800:
				main.game._activate("rocket")
				await _wait(0.4)
			await _shot("%s_sky_%d" % [locale, m])
		main.game._activate("shield")
		main.game._activate("magnet")
		await _wait(0.4)
		await _shot(locale + "_powers")
		main.game._end_run()
		await _wait(2.2)
		await _shot(locale + "_results")
		main._open_leaderboard("daily")
		await _wait(1.0)
		await _shot(locale + "_leaderboard")
		main._close_top_modal()
		main._open_share()
		await _wait(1.2)
		await _shot(locale + "_share")
		main._close_top_modal()
		main._show_title()
	get_tree().quit()

func _teleport(m: int) -> void:
	var g := main.game
	var y := GameConfig.world_y_for(float(m))
	g.generator.generate_until(y - 2000.0)
	g.pending.clear()
	for p in g.platforms:
		p.queue_free()
	g.platforms.clear()
	var gen := TowerGenerator.new(g.seed_value)
	var specs := gen.generate_until(y - 2400.0)
	g.generator = gen
	for spec in specs:
		if float(spec.y) < y + 400.0 and float(spec.y) > y - 1200.0:
			g._spawn(spec)
	var below: TowerPlatform = null
	for p in g.platforms:
		if p.position.y > y and (below == null or p.position.y < below.position.y):
			below = p
	g.cat.position = Vector2(below.position.x if below else 270.0, below.position.y if below else y)
	g.cat.velocity = Vector2(0, -900)
	g.best_y = g.cat.position.y
	g.meters = int(GameConfig.meters(g.best_y))
	g.cam_y = g.cat.position.y - g.view_size.y * 0.3

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(shot_name + ".png"))
	print("SHOT ", shot_name)
