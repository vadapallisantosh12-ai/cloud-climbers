extends Node

func _ready() -> void:
    call_deferred("_run")

func _capture(name: String) -> void:
    await RenderingServer.frame_post_draw
    var dir := OS.get_environment("GAME_CAPTURE_DIR")
    if dir.is_empty(): dir = "res://test-output"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
    var image := get_viewport().get_texture().get_image()
    var path := dir.path_join(name + ".png")
    var err := image.save_png(path)
    if err != OK: push_error("capture failed: " + path)

func _run() -> void:
    var old_balance := SaveStore.star_balance
    var title: Node = (load("res://scenes/title_screen.tscn") as PackedScene).instantiate()
    add_child(title)
    await get_tree().process_frame
    title.queue_redraw()
    await _capture("title_shop")
    title.queue_free()
    await get_tree().process_frame

    var game: Node = (load("res://scenes/game.tscn") as PackedScene).instantiate()
    add_child(game)
    await get_tree().process_frame
    _position_stage(game, 1)
    game.pickups.append(game._pickup(game.player_pos.x, game.player_pos.y, game.PickupType.SHIELD))
    game.pickups.append(game._pickup(game.player_pos.x, game.player_pos.y, game.PickupType.JETPACK))
    game._collect_pickups()
    game.set("stars_collected", 4)
    game.set("score", 2380)
    game.queue_redraw()
    await get_tree().process_frame
    await _capture("monster_powerups")

    _position_stage(game, 3)
    game.set("shield_charges", 0)
    game.set("jetpack_time", 0.0)
    game.set("stars_collected", 9)
    game.set("score", 4780)
    game.queue_redraw()
    await get_tree().process_frame
    await _capture("high_stage")

    game._advance_level()
    _position_stage(game, 2)
    game.set("score", 8340)
    game.queue_redraw()
    await get_tree().process_frame
    await _capture("endless_region_two")

    game.set("state", game.RunState.GAME_OVER)
    game.set("fail_reason", I18n.t("failure.monster"))
    game.set("max_height", 3320)
    game.set("height_m", 3320)
    game.set("score", 10670)
    SaveStore.star_balance = old_balance + 9
    game.queue_redraw()
    await get_tree().process_frame
    await _capture("endless_run_end")
    SaveStore.star_balance = old_balance
    print("[DEBUG_CAPTURE_PASS] shop, powerups, high stage, endless region and run-end screenshots written")
    get_tree().quit(0)

func _position_stage(game: Node, stage_index: int) -> void:
    var target := clampi(stage_index, 0, 3) * 1250 + 160
    game.player_pos.y = game.start_world_y - target
    game.camera_top = game.player_pos.y - get_viewport_rect().size.y * 0.45
    game.player_velocity = Vector2(0, -300)
    game.bounce_timer = 0.0
    game.max_height = target
    game.height_m = target
    game.current_stage = clampi(stage_index, 0, 3)
    game.stage_banner_time = 1.8
