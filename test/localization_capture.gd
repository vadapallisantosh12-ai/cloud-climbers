extends SceneTree

var capture_dir := ""

func _init() -> void:
    call_deferred("_run")

func _capture(name: String) -> void:
    await process_frame
    await RenderingServer.frame_post_draw
    var path := capture_dir.path_join(name + ".png")
    assert(root.get_texture().get_image().save_png(path) == OK)
    print("[LOCALIZATION_CAPTURE] " + path)

func _run() -> void:
    capture_dir = OS.get_environment("GAME_CAPTURE_DIR")
    assert(not capture_dir.is_empty(), "Set GAME_CAPTURE_DIR to an evidence directory")
    assert(DisplayServer.get_name() != "headless", "Visual evidence needs a real renderer")
    DirAccess.make_dir_recursive_absolute(capture_dir)
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    var i18n := root.get_node("I18n")
    for locale: String in ["en", "zh-CN"]:
        i18n.set_locale(locale, false)
        root.size = Vector2i(1280, 720)
        var title: Node = (load("res://scenes/title_screen.tscn") as PackedScene).instantiate()
        root.add_child(title)
        await process_frame
        title.time = 0.0
        title.set_process(false)
        title.queue_redraw()
        await _capture("title-" + locale)
        title.session_ui.show_menu("help")
        title.queue_redraw()
        await _capture("help-" + locale)
        title.session_ui.close_menu()
        root.size = Vector2i(960, 720)
        title.queue_redraw()
        await _capture("title-960-" + locale)
        title.queue_free()
        await process_frame
        root.size = Vector2i(1280, 720)
        var game: Node = (load("res://scenes/game.tscn") as PackedScene).instantiate()
        root.add_child(game)
        await process_frame
        game.set_physics_process(false)
        game.stage_banner_time = 1.0
        game.queue_redraw()
        await _capture("game-" + locale)
        game._finish(false, i18n.t("failure.monster"))
        game.queue_redraw()
        await _capture("result-" + locale)
        game.queue_free()
        await process_frame
    print("[LOCALIZATION_CAPTURE_PASS] EN/CN title, help, gameplay, tuning and results")
    quit(0)
