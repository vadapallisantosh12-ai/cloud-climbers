extends SceneTree


var failures := 0

func _init() -> void:
    call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error(message)

func _run() -> void:
    var probe: Node2D = load("res://test/ground_contact_probe.gd").new()
    var viewport := SubViewport.new()
    viewport.size = Vector2i(256, 256)
    viewport.transparent_bg = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    viewport.add_child(probe)
    probe.player_pos = Vector2(128, 120)
    probe.bounce_timer = 0
    # Geometry checks remain available in headless CI. The renderer path checks
    # the actual production draw calls, independently of the source alpha scan.
    for skin in probe.SKIN_FRAMES:
        probe.selected_frames = probe.SKIN_FRAMES[skin]
        for index in probe.selected_frames.size():
            probe.frame_index = index
            var frame: Texture2D = probe.selected_frames[index]
            var rect: Rect2 = probe._player_frame_rect(frame)
            var image := frame.get_image()
            var mask := BitMap.new()
            mask.create_from_image_alpha(image, 0.125)
            var last := -1
            for y in image.get_height():
                for x in image.get_width():
                    if mask.get_bit(x, y): last = maxi(last, y)
            var bottom := rect.position.y + float(last + 1) * rect.size.y / image.get_height()
            _expect(absf(bottom - 40.0) < 0.01, "%s frame %d is not anchored" % [skin, index])
            if DisplayServer.get_name() != "headless":
                for direction in [-1.0, 1.0]:
                    probe.facing = direction
                    probe.queue_redraw()
                    await process_frame
                    await RenderingServer.frame_post_draw
                    var used := _opaque_rect(viewport.get_texture().get_image())
                    _expect(absf(float(used.end.y) - 160.0) <= 1.0, "%s/%d facing %s rendered bottom %s" % [skin, index, direction, used.end.y])
    probe.platforms.append(probe._platform(40, 160, 176, probe.PlatformType.MOVING, 0, 0))
    var monster: Dictionary = probe._monster(128, 134, 68, 0, 0)
    for phase in range(24):
        probe.total_time = phase * 0.19
        var support: Rect2 = probe._platform_rect(probe.platforms[0])
        var position: Vector2 = probe._monster_pos(monster)
        _expect(is_equal_approx(position.y + 26.0, support.position.y), "monster lost platform contact")
        _expect(position.x - 27.0 >= support.position.x and position.x + 27.0 <= support.end.x, "monster walked beyond its moving support")
    if DisplayServer.get_name() != "headless":
        for stage in range(4):
            probe.mode = 1
            probe.monster_stage = stage
            probe.queue_redraw()
            await process_frame
            await RenderingServer.frame_post_draw
            var used := _opaque_rect(viewport.get_texture().get_image())
            _expect(absf(float(used.end.y) - 160.0) <= 1.0, "monster outline bottom %s" % used.end.y)
        probe.mode = 2
        probe.queue_redraw()
        await process_frame
        await RenderingServer.frame_post_draw
        _expect(_opaque_rect(viewport.get_texture().get_image()).position.y == 160, "platform visual top must match collision top")
    await _check_player_moving_support()
    viewport.queue_free()
    await process_frame
    root.get_node("AudioDirector").queue_free()
    await process_frame
    await create_timer(0.15).timeout
    print("[GROUND_CONTACT_PASS] 48 hero frames, both facings, moving support, monster outlines and platform surface" if failures == 0 else "[GROUND_CONTACT_FAIL] %d" % failures)
    quit(0 if failures == 0 else 1)

func _opaque_rect(image: Image) -> Rect2i:
    var minimum := Vector2i(image.get_width(), image.get_height())
    var maximum := Vector2i(-1, -1)
    for y in image.get_height():
        for x in image.get_width():
            if image.get_pixel(x, y).a >= 0.125:
                minimum = minimum.min(Vector2i(x, y))
                maximum = maximum.max(Vector2i(x, y))
    return Rect2i(minimum, maximum - minimum + Vector2i.ONE)

func _check_player_moving_support() -> void:
    var game: Node2D = load("res://scenes/game.tscn").instantiate()
    root.add_child(game)
    game.set_physics_process(false)
    game.monsters.clear()
    game.stars.clear()
    game.pickups.clear()
    game.platforms.clear()
    var support: Dictionary = game._platform(360, 350, 168, game.PlatformType.MOVING, 0, 0)
    game.platforms.append(support)
    for edge in [-1.0, 1.0]:
        for reversal in [-1.0, 1.0]:
            support.phase = PI * 0.5 * reversal - 0.04
            game.total_time = 0.0
            game.last_platform = 0
            game.bounce_timer = 0.105
            game.jetpack_time = 0.0
            game.state = game.RunState.PLAYING
            game.player_velocity = Vector2.ZERO
            var before: Rect2 = game._platform_rect(support)
            var foot_x: float = before.get_center().x + edge * (before.size.x * 0.5 - 0.1)
            game.player_pos = Vector2(foot_x, before.position.y - game.PLAYER_BOTTOM)
            var relative_x: float = foot_x - before.position.x
            var left_motion := false
            var right_motion := false
            for step in range(6):
                var old_x: float = game.player_pos.x
                game._physics_process(0.017)
                var current: Rect2 = game._platform_rect(support)
                left_motion = left_motion or game.player_pos.x < old_x
                right_motion = right_motion or game.player_pos.x > old_x
                _expect(absf(game.player_pos.x - current.position.x - relative_x) < 0.001, "planted player slipped at moving-platform edge")
                _expect(absf(game.player_pos.y + game.PLAYER_BOTTOM - current.position.y) < 0.001, "moving support lost hero feet")
            _expect(left_motion and right_motion, "fixture must cross a platform direction reversal")
            game._physics_process(0.017)
            _expect(game.player_velocity.y < 0 and game.bounce_timer <= 0, "carried hero still launches automatically")
    game.queue_free()
    await process_frame
