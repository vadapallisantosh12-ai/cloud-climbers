extends SceneTree
## Deterministic native integration tests. Route proof drives ordinary input and
## the actual fixed-step gameplay method; it never teleports the hero or edits
## stage content, actor state, pickup state or tuning to reach the goal.

var failures: Array[String] = []
var game: Node
var tuning: Node
var save: Node
var leaderboard: Node
var original_paths: Dictionary = {}
const STEP := 1.0 / 60.0
var test_prefix := "user://template_contract_%d_" % OS.get_process_id()

func _init() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)

func _run() -> void:
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    root.size = Vector2i(1280, 720)
    tuning = root.get_node("TuningStore")
    save = root.get_node("SaveStore")
    leaderboard = root.get_node("LeaderboardStore")
    original_paths = {"tuning": tuning.save_path, "leaderboard": leaderboard.save_path, "preview_enabled": tuning.preview_enabled}
    tuning.preview_enabled = false
    tuning.save_path = test_prefix + "tuning.json"
    leaderboard.save_path = test_prefix + "leaderboard.json"
    leaderboard.load_data()
    if "save_path" in save:
        original_paths.profile = save.save_path
        save.save_path = test_prefix + "profile.json"
    else:
        _check(false, "SaveStore needs an injectable save_path before integration settlement tests")
        _finish()
        return
    game = _new_game()
    await process_frame
    game.set_physics_process(false)
    _check(game.platforms[0].y == 630.0 and game.start_world_y == 575.0, "1280×720 preserves the authored start-floor geometry")
    _pause_contract()
    await _menu_input_contract()
    _vfx_contract()
    await _tutorial_contract()
    _terminal_contract()
    _result_locale_contract()
    game.free()
    game = _new_game()
    await process_frame
    game.set_physics_process(false)
    game.tutorial.end_run()
    _route_contract()
    if game.level_number > 1:
        _check(game.max_height < 300 and game.current_stage == 0, "Goal starts the next authored zone with reset height and stage")
        _check(game.player_velocity == Vector2.ZERO, "Goal rebuild resets player velocity")
        _check(game.score >= 5000, "Milestone preserves cumulative score")
        _check(game.stars_collected >= 0 and game.monster_bonus >= 0, "Endless progression retains valid cumulative rewards")
    game.free()
    root.get_node("AudioDirector").queue_free()
    await process_frame
    await create_timer(0.15).timeout
    _finish()

func _new_game() -> Node:
    var instance: Node = load("res://scenes/game.tscn").instantiate()
    root.add_child(instance)
    instance.set_physics_process(false)
    instance.tutorial.save_path = test_prefix + "tutorial.json"
    instance.tutorial.begin_run(true)
    return instance

func _pause_contract() -> void:
    game.touch_dirs[3] = 1.0
    var position: Vector2 = game.player_pos
    var elapsed := float(game.total_time)
    var bounce := float(game.bounce_timer)
    game.open_overlay("pause")
    _check(paused and game.touch_dirs.is_empty(), "Opening pause clears held touch movement")
    game.open_overlay("settings")
    for i in range(12): game._physics_process(STEP)
    _check(game.player_pos == position and game.total_time == elapsed and game.bounce_timer == bounce, "Paused physics and run timers remain stable")
    game.close_overlay("settings")
    _check(paused, "Closing a nested overlay preserves its enclosing pause")
    game.close_overlay("pause")
    _check(not paused, "Closing the last overlay resumes an originally running game")
    paused = true
    game.open_overlay("external_pause")
    game.close_overlay("external_pause")
    _check(paused, "Overlay close preserves an already paused tree")
    paused = false

func _menu_input_contract() -> void:
    game.tutorial.begin_run(true)
    var ui: Node = game.session_ui
    ui.show_menu("pause")
    ui.show_menu("settings")
    ui.close_menu()
    _check(ui.modal_kind == "pause" and paused, "Back from settings restores the pause menu")
    ui.show_menu("confirm_restart")
    ui.close_menu()
    _check(ui.modal_kind == "pause" and paused, "Cancelling restart restores pause without resuming gameplay")
    ui.show_menu("confirm_title")
    ui.close_menu()
    _check(ui.modal_kind == "pause" and paused, "Cancelling return-to-title restores pause")
    var pause_focus := root.gui_get_focus_owner()
    var tutorial_step := int(game.tutorial.current_step)
    ui.show_leaderboard()
    await process_frame
    await process_frame
    _check(not game.tutorial._card.visible, "Paused tutorial card cannot cover a modal")
    ui.leaderboard._entry.grab_focus()
    ui.leaderboard._entry.text = "Sky"
    ui.leaderboard._entry.caret_column = 3
    var backspace := InputEventKey.new()
    backspace.keycode = KEY_BACKSPACE
    backspace.pressed = true
    root.push_input(backspace)
    _check(ui.leaderboard._entry.text == "Sk", "Backspace edits the leaderboard name while a tutorial is pending")
    _check(game.tutorial.active and game.tutorial.current_step == tutorial_step, "Paused text editing cannot skip or advance the tutorial")
    ui.leaderboard.close()
    _check(paused and root.gui_get_focus_owner() == pause_focus, "Closing nested leaderboard restores pause focus")
    ui.close_menu()
    await process_frame
    await process_frame
    _check(not paused and game.tutorial._card.visible, "Resume restores the pending tutorial card")
    var toolbar_target: Vector2 = ui.toolbar.get_child(0).get_global_rect().get_center()
    var touch := InputEventScreenTouch.new()
    touch.index = 7
    touch.position = Vector2(64, root.size.y - 90)
    touch.pressed = true
    root.push_input(touch)
    _check(game.touch_dirs.has(7), "A gameplay touch begins steering")
    touch.position = toolbar_target
    touch.pressed = false
    root.push_input(touch)
    _check(not game.touch_dirs.has(7), "Release over a GUI control clears held touch movement")
    var mouse := InputEventMouseButton.new()
    mouse.button_index = MOUSE_BUTTON_LEFT
    mouse.position = Vector2(64, root.size.y - 90)
    mouse.pressed = true
    root.push_input(mouse)
    _check(game.touch_dirs.has(-1), "A gameplay mouse press begins steering")
    mouse.position = toolbar_target
    mouse.pressed = false
    root.push_input(mouse)
    _check(not game.touch_dirs.has(-1), "Release over a GUI control clears held mouse movement")

func _result_locale_contract() -> void:
    var localization := root.get_node("I18n")
    var previous_locale: String = localization.get_locale()
    var other_locale := "zh-CN" if previous_locale == "en" else "en"
    localization.set_locale(other_locale, false)
    _check(game.session_ui.end_actions.get_child(0).text == localization.t("leaderboard.open"), "Debrief standings action updates with the locale")
    _check(game.session_ui.end_actions.get_child(1).text == localization.t("menu.title"), "Debrief title action updates with the locale")
    _check(game.fail_reason_key == "failure.monster" and game.fail_reason == localization.t("failure.monster"), "Terminal failure explanation updates with the locale")
    localization.set_locale(previous_locale, false)
    _check(game.fail_reason == localization.t("failure.monster"), "Returning to the previous locale restores its terminal explanation")

func _vfx_contract() -> void:
    for i in range(40): game._burst(game.player_pos, Color.WHITE, 100, 300.0)
    _check(game.particles.size() <= game.MAX_PARTICLES, "Burst effects remain bounded")
    for i in range(100): game._jetpack_particles()
    _check(game.particles.size() <= game.MAX_PARTICLES, "Jetpack effects share the particle budget")
    var original_velocity: Vector2 = game.player_velocity
    game.player_velocity = Vector2(600, -900)
    for i in range(1000):
        game._update_effects(STEP)
        _check(game.trails.size() <= game.MAX_TRAILS, "Sustained movement trails remain bounded")
    game.player_velocity = original_velocity
    game.particles.clear()
    game.trails.clear()

func _tutorial_contract() -> void:
    game.tutorial.begin_run(true)
    var skip := InputEventKey.new()
    skip.keycode = KEY_BACKSPACE
    skip.pressed = true
    root.push_input(skip)
    _check(not game.tutorial.active, "First-run tutorial has a working keyboard skip")
    _check(root.is_input_handled(), "Tutorial skip consumes its input event")
    _check(game.state == game.RunState.PLAYING and game.overlays.is_empty(), "Skipping tutorial leaves gameplay active without a modal")
    game.tutorial.begin_run()
    _check(not game.tutorial.active, "Completed tutorial does not repeat on retry")
    game.tutorial.begin_run(true)
    await process_frame
    await process_frame
    var touch := InputEventScreenTouch.new()
    touch.index = 6
    touch.position = game.tutorial._skip_button.get_global_rect().get_center()
    touch.pressed = true
    root.push_input(touch)
    touch.pressed = false
    root.push_input(touch)
    _check(not game.tutorial.active, "Tutorial Skip button accepts touch")
    _check(not game.touch_dirs.has(6), "Tutorial Skip touch cannot leak into held movement")
    game.tutorial.begin_run(true)
    for event: String in ["moved", "pickup_collected", "hazard_avoided", "pause_available"]:
        game.tutorial.notify_event(event)
    _check(game.tutorial.current_step == 3 and game.tutorial.active, "Pause tutorial waits for a real player pause action")
    touch.index = 8
    touch.position = game.session_ui.toolbar.get_child(0).get_global_rect().get_center()
    touch.pressed = true
    root.push_input(touch)
    touch.pressed = false
    root.push_input(touch)
    _check(paused and game.session_ui.modal_kind == "pause", "Touch Pause control opens the real pause menu")
    _check(game.tutorial.completed and not game.tutorial.active, "Touch Pause action completes the event-driven tutorial")
    game.session_ui.close_menu()

func _terminal_contract() -> void:
    # Synthesize one terminal frame at the score-service boundary. This is not
    # the route proof below; only this test sets state for a same-frame pickup.
    game.max_height = 100
    game.player_pos.y = game.start_world_y - 123.0
    game.stars_collected = 3
    game.monster_bonus = 350
    var prior_balance := int(save.star_balance)
    game._finish(false, "failure.monster")
    _check(game.score == 1223, "Terminal frame refreshes score before settlement")
    _check(save.star_balance == prior_balance + 3, "Terminal settlement awards collected stars once")
    _check(leaderboard.records.size() == 1 and int(leaderboard.records[0].score) == 1223, "Leaderboard receives the finalized same-frame score")
    game._finish(false, "test")
    game._finish(false, "test")
    _check(save.star_balance == prior_balance + 3 and leaderboard.records.size() == 1, "Repeated terminal signals cannot duplicate rewards or standings")

func _landing_time(platform: Dictionary) -> float:
    var destination: float = float(platform.y) - game.PLAYER_BOTTOM
    var dy: float = destination - float(game.player_pos.y)
    var velocity := float(game.player_velocity.y)
    var delay := 0.0
    if game.bounce_timer > 0.0:
        velocity = -820.0
        delay = float(game.bounce_timer)
    var discriminant: float = velocity * velocity + 2.0 * 1780.0 * dy
    if discriminant < 0.0: return -1.0
    var duration := (-velocity + sqrt(discriminant)) / 1780.0
    return duration + delay if duration > 0.0 else -1.0

func _safe_target(platform: Dictionary, landing_time: float) -> float:
    var rect: Rect2 = game._platform_rect(platform, game.total_time + landing_time)
    var target := rect.get_center().x
    for monster: Dictionary in game.monsters:
        if monster.alive and monster.platform_index == platform.index:
            var patrol := minf(float(monster.range), maxf(0.0, rect.size.x * 0.5 - game.MONSTER_HALF_WIDTH))
            var enemy_x := rect.get_center().x + sin((game.total_time + landing_time) * float(monster.speed) + float(monster.phase)) * patrol
            var left := rect.position.x - 8.0
            var right := rect.end.x + 8.0
            target = left if absf(enemy_x - left) > absf(enemy_x - right) else right
            break
    return target

func _route_contract() -> void:
    var goal_reached := false
    var target_index := 1
    var reached: Dictionary = {0: true}
    var last_landed := 0
    for tick in range(60 * 240):
        if game.state != game.RunState.PLAYING:
            print("ROUTE_FAILURE tick=", tick, " height=", game.max_height, " landed=", game.last_platform, " target=", target_index, " pos=", game.player_pos, " velocity=", game.player_velocity, " reason=", game.fail_reason)
            break
        if game.level_number > 1:
            goal_reached = true
            print("ROUTE_COMPLETE ticks=", tick, " seconds=", tick * STEP, " score=", game.score, " platforms=", reached.size())
            break
        if game.last_platform != last_landed:
            last_landed = game.last_platform
            reached[last_landed] = true
        var best_index := -1
        var best_time := -1.0
        var best_x := 0.0
        for index in range(game.last_platform + 1, game.platforms.size()):
            var platform: Dictionary = game.platforms[index]
            if not platform.active: continue
            var duration := _landing_time(platform)
            if duration <= 0.0: continue
            var desired_x := _safe_target(platform, duration)
            var distance := absf(desired_x - float(game.player_pos.x))
            # Conservative horizontal reach: acceleration and braking need room.
            if distance > 500.0 * duration - 22.0: continue
            best_index = index
            best_time = duration
            best_x = desired_x
            break
        if best_index >= 0:
            target_index = best_index
        else:
            var fallback: Dictionary = game.platforms[mini(target_index, game.platforms.size() - 1)]
            best_time = maxf(0.08, _landing_time(fallback))
            best_x = _safe_target(fallback, best_time)
        var distance := best_x - float(game.player_pos.x)
        var wanted_speed := clampf(distance * 7.0, -500.0, 500.0)
        if absf(distance) < 2.0 and absf(game.player_velocity.x) < 25.0:
            wanted_speed = 0.0
        Input.action_release("ui_left")
        Input.action_release("ui_right")
        if wanted_speed > 0.0: Input.action_press("ui_right", wanted_speed / 500.0)
        elif wanted_speed < 0.0: Input.action_press("ui_left", -wanted_speed / 500.0)
        game._physics_process(STEP)
        game.tutorial._process(STEP)
    Input.action_release("ui_left")
    Input.action_release("ui_right")
    _check(goal_reached, "Ordinary default-tuning controller reaches the authored 5000m goal")
    _check(reached.size() > 20, "Route proof traverses the authored platform sequence")

func _finish() -> void:
    paused = false
    if tuning != null:
        tuning.preview_enabled = original_paths.get("preview_enabled", true)
        tuning.save_path = original_paths.get("tuning", tuning.save_path)
    if leaderboard != null:
        leaderboard.save_path = original_paths.get("leaderboard", leaderboard.save_path)
    if save != null and original_paths.has("profile"):
        save.save_path = original_paths.profile
    for suffix: String in ["tuning.json", "leaderboard.json", "profile.json", "tutorial.json"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(test_prefix + suffix))
    if failures.is_empty(): print("TEMPLATE_CONTRACT_OK")
    quit(0 if failures.is_empty() else 1)
