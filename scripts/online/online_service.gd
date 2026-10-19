class_name OnlineService
extends Node
## Thin game-facing wrapper around OnlineLeaderboard. The game never waits on it:
## every call is async and the UI shows friendly status text on failure.

signal status_changed

var client := OnlineLeaderboard.new()
var run_id := ""
var run_board := ""
var run_started_ms := 0
var last_error := ""
var _begin_pending := false

func _ready() -> void:
	client.rules_version = GameConfig.LEADERBOARD_RULES
	add_child(client)

static func board_for(mode: String, daily_key: String) -> String:
	return GameConfig.BOARD_DAILY_PREFIX + daily_key if mode == "daily" else GameConfig.BOARD_ENDLESS

func has_identity() -> bool:
	return not client._token.is_empty()

func register(display_name: String) -> Dictionary:
	var result: Dictionary = await client.ensure_guest(display_name)
	if not result.get("ok", false):
		last_error = String(result.get("error", "online_leaderboard_unavailable"))
	status_changed.emit()
	return result

func forget_identity() -> void:
	client.forget_guest()
	run_id = ""
	status_changed.emit()

## Called when a run starts; opens a ranked run ticket in the background.
func begin(mode: String, daily_key: String) -> void:
	run_id = ""
	run_board = board_for(mode, daily_key)
	run_started_ms = Time.get_ticks_msec()
	if not has_identity():
		return
	_begin_pending = true
	client.board_id = run_board
	var board := run_board
	var result: Dictionary = await client.begin_run()
	_begin_pending = false
	if board != run_board:
		return
	if result.get("ok", false):
		run_id = String(result.data.get("runId", ""))
	else:
		last_error = String(result.get("error", ""))

## Submit the finished run. Returns {ok, rank?, error?}.
func submit(meters: int) -> Dictionary:
	if not has_identity():
		return {"ok": false, "error": "no_identity"}
	var waited := 0
	while _begin_pending and waited < 60:
		await get_tree().create_timer(0.1).timeout
		waited += 1
	if run_id.is_empty():
		return {"ok": false, "error": last_error if not last_error.is_empty() else "no_run"}
	if meters < 1:
		return {"ok": false, "error": "score_too_low"}
	var duration := maxi(3000, Time.get_ticks_msec() - run_started_ms)
	var id := run_id
	run_id = ""
	var result: Dictionary = await client.submit_run(id, meters, duration)
	if not result.get("ok", false):
		return {"ok": false, "error": String(result.get("error", "online_leaderboard_unavailable"))}
	var board: Dictionary = await fetch(run_board, 5)
	var rank := 0
	if board.get("ok", false) and board.data.get("myRank") is Dictionary:
		rank = int(board.data.myRank.get("rank", 0))
	return {"ok": true, "rank": rank, "board": board.get("data", {})}

func fetch(board_id: String, limit: int = 10) -> Dictionary:
	client.board_id = board_id
	return await client.read_board(limit)

## Player-facing explanation for an error code.
static func error_text(code: String) -> String:
	match code:
		"online_preview_requires_checkpoint", "online_leaderboard_not_configured":
			return I18n.t("online.preview_only")
		"leaderboard_read_only":
			return I18n.t("online.read_only")
		"no_identity":
			return I18n.t("online.need_name")
		"score_too_low":
			return I18n.t("online.too_low")
		"daily_board_closed":
			return I18n.t("online.daily_closed")
		"rate_limited":
			return I18n.t("online.rate_limited")
	return I18n.t("online.unavailable")
