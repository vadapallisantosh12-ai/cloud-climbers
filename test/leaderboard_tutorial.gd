extends SceneTree

const Store := preload("res://scripts/leaderboard_store.gd")
const LEADERBOARD_PATH := "user://leaderboard-test-isolated.json"
const TUTORIAL_PATH := "user://tutorial-test-isolated.json"
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error("[LEADERBOARD_TUTORIAL_FAIL] " + message)

func _result(token: String, score := 100, duration := 20.0) -> Dictionary:
	return {"token": token, "score": score, "stage": 1, "outcome": "victory", "duration": duration, "timestamp": 1000, "config_marker": "baseline"}

func _run() -> void:
	var Tutorial: GDScript = load("res://scripts/tutorial_director.gd")
	var StandingsPanel: GDScript = load("res://scripts/leaderboard_panel.gd")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LEADERBOARD_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TUTORIAL_PATH))
	var store := Store.new()
	store.save_path = LEADERBOARD_PATH
	root.add_child(store)
	_expect(store.records.is_empty(), "missing save starts with an empty board")
	_expect(store.validate_name("小明").is_empty(), "two-character Chinese name accepted")
	_expect(store.validate_name("Jun小明").is_empty(), "mixed-language name accepted")
	_expect(not store.validate_name("𠀀").is_empty(), "rare unsupported name is reported")
	_expect(not store.validate_name("A\nB").is_empty(), "control characters rejected")
	_expect(not store.validate_name("a".repeat(25)).is_empty(), "display-name length bounded")
	_expect(store.set_display_name("  Jun小明  ") and store.display_name == "Jun小明", "name normalized and saved")
	_expect(store.add_result(_result("first")), "valid terminal result is stored")
	_expect(not store.add_result(_result("first", 500)), "same terminal token cannot finalize again")
	var resumed := Store.new()
	resumed.save_path = LEADERBOARD_PATH
	root.add_child(resumed)
	_expect(resumed.records.size() == 1 and resumed.records[0].name == "Jun小明", "Chinese name and result persist")
	_expect(resumed.display_name == "Jun小明", "chosen display name persists")
	_expect(not resumed.add_result(_result("first")), "duplicate token rejected after reload")
	for i in range(15):
		resumed.add_result(_result("run-%02d" % i, 200 + i))
	_expect(resumed.records.size() == 10 and resumed.records[0].score == 214, "top ten bounded and sorted descending")
	_expect(not resumed.add_result(_result("first", 99999)), "pruned record token remains deduplicated")
	resumed.add_result(_result("tie-b", 1000, 10.0))
	resumed.add_result(_result("tie-a", 1000, 10.0))
	_expect(resumed.records[0].token == "tie-a" and resumed.records[1].token == "tie-b", "complete ties sorted by stable token")
	var negative := _result("negative", -99)
	resumed.add_result(negative)
	var invalid := _result("nonterminal")
	invalid.outcome = "running"
	_expect(not resumed.add_result(invalid), "nonterminal result rejected")
	invalid = _result("bad-number")
	invalid.duration = "twenty"
	_expect(not resumed.add_result(invalid), "malformed numeric fields rejected")
	var file := FileAccess.open(LEADERBOARD_PATH, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	resumed.load_data()
	_expect(resumed.records.is_empty(), "malformed JSON safely falls back")
	file = FileAccess.open(LEADERBOARD_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 1, "display_name": [], "records": [null, {}, {"token": "broken"}], "recent_tokens": {"bad": true}}))
	file.close()
	resumed.load_data()
	_expect(resumed.records.is_empty() and resumed.display_name.is_empty(), "malformed collection members safely fall back")
	resumed.set_display_name("小明")
	resumed.add_result(_result("ui-record"))
	var panel: CanvasLayer = StandingsPanel.new()
	root.add_child(panel)
	paused = true
	panel.open(resumed)
	_expect(panel.is_open and paused, "standings open preserves caller pause")
	panel.close()
	_expect(not panel.is_open and paused, "standings close leaves pause restoration to caller")
	paused = false
	panel.queue_free()
	var tutorial: CanvasLayer = Tutorial.new()
	tutorial.save_path = TUTORIAL_PATH
	root.add_child(tutorial)
	tutorial.begin_run()
	_expect(tutorial.active and tutorial.current_step == 0, "first run shows movement callout")
	tutorial.notify_event("moved", "touch")
	_expect(tutorial.current_step == 1 and tutorial.active and tutorial.input_method == "touch", "movement event advances; waiting keeps Skip active")
	tutorial.notify_event("pickup_visible")
	tutorial.notify_event("pickup_collected")
	_expect(tutorial.current_step == 2, "real pickup completes pickup callout")
	tutorial.notify_event("hazard_visible")
	tutorial.notify_event("hazard_avoided")
	tutorial.notify_event("pause_available")
	_expect(tutorial.current_step == 3, "hazard event leads to player pause callout")
	tutorial.notify_event("paused")
	_expect(tutorial.completed and not tutorial.active, "real pause completes tutorial")
	tutorial.begin_run()
	_expect(not tutorial.active, "completed tutorial does not reappear on retry")
	for step_index in range(Tutorial.STEPS.size()):
		tutorial.replay()
		for index in range(step_index):
			tutorial.notify_event(Tutorial.STEPS[index].complete[0])
		_expect(tutorial.current_step == step_index and tutorial.active, "Skip available at step %d including event waits" % step_index)
		paused = step_index % 2 == 0
		var prior_pause := paused
		tutorial.skip()
		_expect(not tutorial.active and tutorial.completed and paused == prior_pause, "Skip persists dismissal and preserves pause at step %d" % step_index)
		paused = false
	var tutorial_resumed: CanvasLayer = Tutorial.new()
	tutorial_resumed.save_path = TUTORIAL_PATH
	root.add_child(tutorial_resumed)
	_expect(tutorial_resumed.completed, "versioned completion reloads")
	tutorial_resumed.replay()
	_expect(tutorial_resumed.active and not tutorial_resumed.completed, "replay explicitly resets completion")
	tutorial_resumed._process(21.0)
	_expect(tutorial_resumed.current_step == 1, "visible step timeout safely progresses")
	tutorial_resumed._process(31.0)
	_expect(tutorial_resumed.current_step == 2, "unreachable event timeout safely progresses")
	var script_source := FileAccess.get_file_as_string("res://scripts/tutorial_director.gd").to_lower()
	_expect(not script_source.contains("tuning") and not script_source.contains("f10"), "player tutorial has no developer-control dependency")
	tutorial.end_run()
	tutorial_resumed.end_run()
	store.queue_free()
	resumed.queue_free()
	tutorial.queue_free()
	tutorial_resumed.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LEADERBOARD_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TUTORIAL_PATH))
	print("[LEADERBOARD_TUTORIAL_%s] offline top10, mixed names, duplicate tokens, event progression, replay and skip" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
