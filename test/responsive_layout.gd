extends SceneTree

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    var sizes := [Vector2i(960, 720), Vector2i(1280, 720), Vector2i(1680, 720)]
    for size in sizes:
        root.size = size
        await process_frame
        var title: Node = (load("res://scenes/title_screen.tscn") as PackedScene).instantiate()
        root.add_child(title)
        await process_frame
        title.queue_redraw()
        await process_frame
        var start_rect: Rect2 = title.get("start_rect")
        if start_rect.size.x <= 0.0 or start_rect.end.x > size.x:
            push_error("[RESPONSIVE_FAIL] title action is outside viewport at %s" % size)
            quit(1)
            return
        var skin_rects: Array = title.get("skin_rects")
        var first_skin: Rect2 = skin_rects[0]
        var last_skin: Rect2 = skin_rects[-1]
        if skin_rects.size() != 4 or last_skin.end.x > size.x or first_skin.size.x < 90.0:
            push_error("[RESPONSIVE_FAIL] skin shop is clipped at %s: first=%s last=%s" % [size, first_skin, last_skin])
            quit(1)
            return
        title.queue_free()
        await process_frame
        var game: Node = (load("res://scenes/game.tscn") as PackedScene).instantiate()
        root.add_child(game)
        await process_frame
        var player_pos: Vector2 = game.get("player_pos")
        if player_pos.x < 0.0 or player_pos.x > size.x:
            push_error("[RESPONSIVE_FAIL] player spawn is outside viewport at %s" % size)
            quit(1)
            return
        game.queue_free()
        await process_frame
    print("[RESPONSIVE_PASS] 960x720, 1280x720, 1680x720")
    quit(0)
