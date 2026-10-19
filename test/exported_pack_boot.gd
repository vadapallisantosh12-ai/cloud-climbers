extends SceneTree
func _init() -> void:
	call_deferred("_run")
func _fail(message: String) -> void:
	push_error("[PCK_BOOT_FAIL] " + message)
	quit(1)
func _run() -> void:
	var main_path := String(ProjectSettings.get_setting("application/run/main_scene", ""))
	if main_path != "res://scenes/main.tscn":
		_fail("unexpected main scene: " + main_path)
		return
	var i18n := root.get_node_or_null("I18n")
	if i18n == null or not FileAccess.file_exists("res://localization/en.json") or not FileAccess.file_exists("res://localization/zh-CN.json"):
		_fail("localization service or catalogs missing")
		return
	i18n.set_locale("zh-CN", false)
	if i18n.t("title.main") != "云端攀登":
		_fail("packed Chinese copy missing")
		return
	i18n.set_locale("en", false)
	if i18n.t("title.main") != "Cloud Climber":
		_fail("packed English copy missing")
		return
	var scene: PackedScene = load(main_path)
	if scene == null:
		_fail("main scene missing")
		return
	var node := scene.instantiate()
	root.add_child(node)
	await process_frame
	print("[PCK_BOOT_PASS] configured main scene loaded from exported resources")
	quit(0)
