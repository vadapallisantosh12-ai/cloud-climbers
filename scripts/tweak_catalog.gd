extends RefCounted

# One source for validation, presentation, persistence, timing and run integrity.
const CATEGORIES := ["AUDIO", "PLAYER", "ENEMIES", "ENVIRONMENT"]
const SCHEMA_VERSION := 2

static func descriptors() -> Array[Dictionary]:
    return [
        _spec("music_volume", "AUDIO", 1.0, 0.0, 1.0, 0.05, "LIVE", "COSMETIC", "ratio"),
        _spec("sfx_volume", "AUDIO", 1.0, 0.0, 1.0, 0.05, "LIVE", "COSMETIC", "ratio"),
        _spec("ui_volume", "AUDIO", 1.0, 0.0, 1.0, 0.05, "LIVE", "COSMETIC", "ratio"),
        _spec("move_speed", "PLAYER", 470.0, 300.0, 700.0, 10.0, "LIVE", "GAMEPLAY", "speed"),
        _spec("move_accel", "PLAYER", 4200.0, 1500.0, 7000.0, 100.0, "LIVE", "GAMEPLAY", "acceleration"),
        _spec("gravity", "PLAYER", 2000.0, 1400.0, 2800.0, 50.0, "LIVE", "GAMEPLAY", "acceleration"),
        _spec("jump_speed", "PLAYER", 1010.0, 850.0, 1150.0, 10.0, "NEXT_ACTION", "GAMEPLAY", "speed"),
        _spec("spring_speed", "PLAYER", 1700.0, 1300.0, 2200.0, 25.0, "NEXT_ACTION", "GAMEPLAY", "speed"),
        _spec("enemy_speed", "ENEMIES", 1.0, 0.5, 1.6, 0.1, "NEXT_SPAWN", "GAMEPLAY", "ratio"),
        _spec("camera_follow", "ENVIRONMENT", 9.0, 3.0, 16.0, 0.5, "LIVE", "COSMETIC", "ratio"),
    ]

static func _spec(id: String, category: String, baseline: float, minimum: float, maximum: float, step: float, mode: String, integrity: String, unit: String, type := "float") -> Dictionary:
    return {"id": id, "category": category, "type": type, "default": baseline,
        "min": minimum, "max": maximum, "step": step, "options": [], "unit": unit,
        "apply_mode": mode, "integrity": integrity, "label_key": "tweak." + id + ".label",
        "description_key": "tweak." + id + ".description", "tags": [category.to_lower(), id]}
