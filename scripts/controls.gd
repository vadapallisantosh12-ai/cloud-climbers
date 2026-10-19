class_name Controls
extends RefCounted
## Input actions are declared here so remixers can rebind everything in one place.
## Menus use Godot's built-in ui_* actions (arrows, Enter/Space, gamepad D-pad/A/B).

const STICK_DEADZONE := 0.22

static func setup() -> void:
	_action("move_left", [KEY_LEFT, KEY_A], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_action("move_right", [KEY_RIGHT, KEY_D], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START], [])
	_action("restart", [KEY_R], [JOY_BUTTON_Y], [])

static func _action(action: String, keys: Array, buttons: Array, axes: Array) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, STICK_DEADZONE)
	for key: int in keys:
		var e := InputEventKey.new()
		e.physical_keycode = key
		InputMap.action_add_event(action, e)
	for button: int in buttons:
		var b := InputEventJoypadButton.new()
		b.button_index = button
		b.device = -1
		InputMap.action_add_event(action, b)
	for axis: Array in axes:
		var m := InputEventJoypadMotion.new()
		m.axis = axis[0]
		m.axis_value = axis[1]
		m.device = -1
		InputMap.action_add_event(action, m)
