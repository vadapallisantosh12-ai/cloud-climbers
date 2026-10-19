extends SceneTree
var capture_dir := ""

func _init() -> void:
    call_deferred("_run")

func _capture(label: String) -> void:
    for index in range(5): await process_frame
    await RenderingServer.frame_post_draw
    assert(root.get_texture().get_image().save_png(capture_dir.path_join(label + ".png")) == OK)
    print("[TEMPLATE_CAPTURE] " + label)

func _run() -> void:
    capture_dir = OS.get_environment("GAME_CAPTURE_DIR")
    assert(not capture_dir.is_empty() and DisplayServer.get_name() != "headless")
    DirAccess.make_dir_recursive_absolute(capture_dir)
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    var standings := root.get_node("LeaderboardStore")
    standings.save_path = "user://capture-standings.json"
    standings.records.clear()
    standings.set_display_name("小明 Jun")
    standings.add_result({"token": "capture-first", "score": 7820, "stage": 4, "outcome": "defeat", "duration": 142.5, "config_marker": "baseline", "timestamp": 1790000000})
    var sample_records: Array = standings.records.duplicate(true)
    var save := root.get_node("SaveStore")
    save.save_path = "user://capture-profile.json"
    for locale: String in ["en", "zh-CN"]:
        root.get_node("I18n").set_locale(locale, false)
        for viewport: Vector2i in [Vector2i(1280,720), Vector2i(720,1280)]:
            root.size = viewport
            var suffix := locale + "-" + str(viewport.x)
            standings.records.assign(sample_records)
            var title: Node = load("res://scenes/title_screen.tscn").instantiate()
            root.add_child(title)
            await process_frame
            title.time = 0
            title.set_process(false)
            title.queue_redraw()
            await _capture("title-" + suffix)
            title.session_ui.show_leaderboard()
            await _capture("leaderboard-" + suffix)
            title.session_ui.leaderboard.close()
            title.queue_free()
            await process_frame
            var game: Node = load("res://scenes/game.tscn").instantiate()
            root.add_child(game)
            await process_frame
            game.set_physics_process(false)
            game.tutorial.save_path = "user://capture-tutorial.json"
            game.tutorial.begin_run(true)
            game.tutorial.notify_event("move_available")
            game.stage_banner_time = 0
            game.queue_redraw()
            await _capture("tutorial-" + suffix)
            game.tutorial.skip()
            game.session_ui.show_menu("pause")
            await _capture("pause-" + suffix)
            game.session_ui.show_menu("settings")
            await _capture("settings-" + suffix)
            while not game.session_ui.modal_kind.is_empty(): game.session_ui.close_menu()
            game._finish(false, root.get_node("I18n").t("failure.fall"))
            game.queue_redraw()
            await _capture("results-" + suffix)
            game.queue_free()
            await process_frame
    root.get_node("AudioDirector").free()
    for index in range(3): await process_frame
    await create_timer(0.15).timeout
    print("[TEMPLATE_CAPTURE_PASS]")
    quit()
