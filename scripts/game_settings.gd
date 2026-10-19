extends Node
## Player-facing presentation settings (audio volumes live in AudioDirector,
## language in I18n). Persisted to user storage.

signal changed

const PATH := "user://cloud_climber_settings.json"
var high_effects := true
var screen_shake := true

func _ready() -> void:
	if FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			high_effects = bool(parsed.get("high_effects", true))
			screen_shake = bool(parsed.get("screen_shake", true))

func set_high_effects(value: bool) -> void:
	high_effects = value
	_save()

func set_screen_shake(value: bool) -> void:
	screen_shake = value
	_save()

## Multiplier for particle counts.
func particle_scale() -> float:
	return 1.0 if high_effects else 0.35

func _save() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"high_effects": high_effects, "screen_shake": screen_shake}))
	changed.emit()
