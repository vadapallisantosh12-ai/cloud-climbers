extends SceneTree

const SAVE_PATH := "user://leaderboard-visual-isolated.json"
const TUTORIAL_PATH := "user://tutorial-visual-isolated.json"
var output_dir := ""

func _init() -> void:
	call_deferred("_run")

func _capture(filename: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output_dir.path_join(filename + ".png")) == OK)
	print("[LEADERBOARD_TUTORIAL_CAPTURE] " + filename)

func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Use a real renderer for visual evidence")
	output_dir = OS.get_environment("GAME_CAPTURE_DIR")
	assert(not output_dir.is_empty())
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TUTORIAL_PATH))
	var store: Node = load("res://scripts/leaderboard_store.gd").new()
	store.save_path = SAVE_PATH
	root.add_child(store)
	store.set_display_name("Jun小明")
	for index in range(10):
		store.add_result({"token": "visual-%d" % index, "score": 43210 - index * 812, "stage": 3, "outcome": "victory" if index < 3 else "defeat", "duration": 142.1 + index, "timestamp": 1000 + index, "config_marker": "baseline"})
	var panel: CanvasLayer = load("res://scripts/leaderboard_panel.gd").new()
	root.add_child(panel)
	var tutorial: CanvasLayer = load("res://scripts/tutorial_director.gd").new()
	tutorial.save_path = TUTORIAL_PATH
	root.add_child(tutorial)
	for locale: String in ["en", "zh-CN"]:
		root.get_node("I18n").set_locale(locale, false)
		for size: Vector2i in [Vector2i(1280, 720), Vector2i(720, 1280), Vector2i(390, 844)]:
			root.size = size
			await process_frame
			panel.open(store)
			await _capture("standings-%s-%d" % [locale, size.x])
			assert(panel._panel.position.y + panel._panel.size.y <= size.y, "Leaderboard fits the viewport")
			panel.close()
			tutorial.input_method = "touch" if size.x < size.y else "keyboard"
			tutorial.begin_run(true)
			await _capture("tutorial-%s-%d" % [locale, size.x])
			assert(tutorial._card.size.y < 260, "Tutorial remains a compact card on its first layout")
			tutorial.end_run()
	panel.queue_free()
	tutorial.queue_free()
	store.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TUTORIAL_PATH))
	print("[LEADERBOARD_TUTORIAL_CAPTURE_PASS]")
	quit(0)
