extends SceneTree
## Exercise the actual project canvas_items/expand configuration. Never disable
## scaling: that would conceal the portrait design-base regression.
var failures: Array[String] = []
var capture_dir := ""
var test_prefix := "user://production_scaling_%d_" % OS.get_process_id()

func _init() -> void:
    call_deferred("_run")

func check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error("[PRODUCTION_SCALING_FAIL] " + message)

func capture(name: String) -> void:
    if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
    await process_frame
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "Native screenshot saves")

func _run() -> void:
    capture_dir = OS.get_environment("GAME_CAPTURE_DIR")
    if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
    var i18n := root.get_node("I18n")
    var tuning := root.get_node("TuningStore")
    tuning.preview_enabled = false
    root.get_node("SaveStore").save_path = test_prefix + "profile.json"
    root.get_node("LeaderboardStore").save_path = test_prefix + "standings.json"
    var expected_widths := [390, 474, 1280]
    var physical_sizes := [Vector2i(390, 844), Vector2i(720, 1280), Vector2i(1280, 720)]
    check(root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, "Production canvas_items scaling is retained")
    check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "Production expand aspect is retained")
    for index in range(physical_sizes.size()):
        var physical: Vector2i = physical_sizes[index]
        root.size = physical
        await process_frame
        await process_frame
        var title: Node = load("res://scenes/title_screen.tscn").instantiate()
        root.add_child(title)
        await process_frame
        await process_frame
        var viewport: Vector2 = root.get_visible_rect().size
        check(int(viewport.x) == expected_widths[index], "Logical width matches the physical orientation at %s: %s" % [physical, viewport])
        check((viewport.x < 850) == (physical.y > physical.x), "Actual title chooses portrait only for portrait windows")
        for locale: String in ["en", "zh-CN"]:
            i18n.set_locale(locale, false)
            title.queue_redraw()
            await process_frame
            await process_frame
            check(title.start_rect.end.x <= viewport.x and title.start_rect.end.y <= viewport.y, "Start action remains within the production viewport")
            for rect: Rect2 in title.skin_rects:
                check(rect.position.x >= 0 and rect.end.x <= viewport.x and rect.end.y <= viewport.y, "Skin card remains within the production viewport")
            await capture("native-title-%dx%d-%s" % [physical.x, physical.y, locale])
        title.free()
        var game: Node = load("res://scenes/game.tscn").instantiate()
        root.add_child(game)
        game.set_physics_process(false)
        game.tutorial.save_path = test_prefix + "tutorial.json"
        game.tutorial.end_run()
        await process_frame
        await process_frame
        check(game.player_pos.x > 0 and game.player_pos.x < viewport.x and game.player_pos.y < viewport.y, "Initial player is visible at %s" % physical)
        for platform: Dictionary in game.platforms:
            var rect: Rect2 = game._platform_rect(platform)
            check(rect.end.x > 0 and rect.position.x < viewport.x, "Authored platform route intersects the narrow viewport")
        if index == 2:
            check(game.platforms[0].y == 630.0 and game.start_world_y == 575.0, "Landscape preserves the original gameplay baseline")
        for locale: String in ["en", "zh-CN"]:
            i18n.set_locale(locale, false)
            game.queue_redraw()
            await capture("native-game-%dx%d-%s" % [physical.x, physical.y, locale])
        if index < 2:
            _steer_first_platforms(game)
        # Resizing a running game must not reset or move its authored state.
        var before_position: Vector2 = game.player_pos
        var before_platforms: Array = game.platforms.duplicate(true)
        var run_design: Vector2i = root.content_scale_size
        root.size = Vector2i(1280, 720) if index < 2 else Vector2i(390, 844)
        await process_frame
        await process_frame
        check(game.player_pos == before_position and game.platforms == before_platforms, "Rotation preserves active player/platform state")
        check(root.content_scale_size == run_design, "Active run keeps its authored design coordinate space")
        game.free()
        await process_frame
        print("[PRODUCTION_SCALING] physical=", physical, " viewport=", viewport, " portrait=", viewport.x < 850)
    for suffix: String in ["profile.json", "standings.json", "tutorial.json"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(test_prefix + suffix))
    root.get_node("AudioDirector").queue_free()
    await process_frame
    await create_timer(0.2).timeout
    if failures.is_empty(): print("[PRODUCTION_SCALING_PASS] real canvas_items/expand portrait, landscape, native captures and unchanged active run verified")
    quit(0 if failures.is_empty() else 1)

func _steer_first_platforms(game: Node) -> void:
    # Ordinary analog input and the actual controller/collision method prove
    # that the visible narrow layout also supports consecutive real landings.
    var reached := false
    for tick in range(1500):
        if game.state != game.RunState.PLAYING: break
        if game.last_platform >= 6:
            reached = true
            break
        var target: Dictionary = game.platforms[game.last_platform + 1]
        var vertical_speed := float(game.player_velocity.y)
        var delay := 0.0
        if game.bounce_timer > 0:
            vertical_speed = -820.0
            delay = float(game.bounce_timer)
        var dy: float = float(target.y) - game.PLAYER_BOTTOM - game.player_pos.y
        var discriminant := vertical_speed * vertical_speed + 3560.0 * dy
        var landing_time := maxf(0.0, (-vertical_speed + sqrt(maxf(0.0, discriminant))) / 1780.0 + delay)
        var target_x: float = game._platform_rect(target, game.total_time + landing_time).get_center().x
        var speed := clampf((target_x - float(game.player_pos.x)) * 7.0, -500.0, 500.0)
        Input.action_release("ui_left")
        Input.action_release("ui_right")
        if speed > 0: Input.action_press("ui_right", speed / 500.0)
        elif speed < 0: Input.action_press("ui_left", -speed / 500.0)
        game._physics_process(1.0 / 60.0)
    Input.action_release("ui_left")
    Input.action_release("ui_right")
    if not reached: print("PORTRAIT_ROUTE_DETAIL viewport=", root.get_visible_rect().size, " last_platform=", game.last_platform, " pos=", game.player_pos, " velocity=", game.player_velocity, " state=", game.state, " fail=", game.fail_reason)
    check(reached, "Default gameplay input traverses six platforms in portrait without teleporting")
