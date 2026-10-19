extends Node
## Local progress: personal bests per mode, today's best, tutorial/hint flags
## and the leaderboard nickname. Stored as JSON in user storage (IndexedDB on Web).

signal changed

const PATH := "user://cloud_climber_save.json"
const DAILY_KEEP := 14

var save_path := PATH
var best_endless := 0
var daily_bests: Dictionary = {}  # "YYYYMMDD" -> metres
var total_runs := 0
var total_fish := 0
var tutorial_done := false
var hints_seen: Array = []
var nickname := ""
var name_prompted := false

func _ready() -> void:
	load_data()

func load_data() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not parsed is Dictionary:
		return
	var d: Dictionary = parsed
	best_endless = int(d.get("best_endless", 0))
	daily_bests = d.get("daily_bests", {}) if d.get("daily_bests", {}) is Dictionary else {}
	total_runs = int(d.get("total_runs", 0))
	total_fish = int(d.get("total_fish", 0))
	tutorial_done = bool(d.get("tutorial_done", false))
	hints_seen = d.get("hints_seen", []) if d.get("hints_seen", []) is Array else []
	nickname = String(d.get("nickname", ""))
	name_prompted = bool(d.get("name_prompted", false))

func save() -> void:
	var keys := daily_bests.keys()
	keys.sort()
	while keys.size() > DAILY_KEEP:
		daily_bests.erase(keys.pop_front())
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveStore: could not write save file")
		return
	file.store_string(JSON.stringify({"best_endless": best_endless, "daily_bests": daily_bests, "total_runs": total_runs,
		"total_fish": total_fish, "tutorial_done": tutorial_done, "hints_seen": hints_seen, "nickname": nickname,
		"name_prompted": name_prompted}))
	changed.emit()

func best_for(mode: String, daily_key: String) -> int:
	return int(daily_bests.get(daily_key, 0)) if mode == "daily" else best_endless

## Record a finished run. Returns true when it is a new personal best for its mode.
func record_run(summary: Dictionary) -> bool:
	var m := int(summary.meters)
	total_runs += 1
	total_fish += int(summary.fish)
	var is_best := false
	if String(summary.mode) == "daily":
		var key := String(summary.daily_key)
		if m > int(daily_bests.get(key, 0)):
			daily_bests[key] = m
			is_best = true
	elif m > best_endless:
		best_endless = m
		is_best = true
	save()
	return is_best and m > 0

func mark_hint(kind: String) -> bool:
	if kind in hints_seen:
		return false
	hints_seen.append(kind)
	save()
	return true

func set_tutorial_done() -> void:
	tutorial_done = true
	save()

func set_nickname(value: String) -> void:
	nickname = value
	name_prompted = true
	save()
