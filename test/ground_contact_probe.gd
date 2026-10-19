extends "res://scripts/game.gd"
var frame_index := 0
var mode := 0
var monster_stage := 0
func _ready() -> void:
    pass
func _physics_process(_delta: float) -> void:
    pass
func _current_frame() -> int:
    return frame_index
func _draw() -> void:
    if mode == 0:
        _draw_player()
    elif mode == 1:
        _draw_monster(Vector2(128, 160 - MONSTER_BOTTOM), monster_stage, 0.7)
    else:
        _draw_platform(Rect2(40, 160, 176, 18), PlatformType.NORMAL, -1)
