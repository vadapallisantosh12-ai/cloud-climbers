class_name ClimbHud
extends Control
## In-run HUD painted on the side panels around the column, plus touch buttons.

signal pause_pressed

const FISH_TEX := preload("res://assets/game/items/fish.webp")
const PAUSE_TEX := preload("res://assets/game/ui/icon_pause.webp")
const ARROW_TEX := preload("res://assets/game/ui/icon_arrow.webp")
const CAT_TEX := preload("res://assets/game/cat/cat_idle.webp")
const POWER_TEX := {
	"rocket": preload("res://assets/game/items/rocket.webp"),
	"shield": preload("res://assets/game/items/shield.webp"),
	"magnet": preload("res://assets/game/items/magnet.webp"),
}

var game: ClimbGame
var touch_left := false
var touch_right := false
var touch_mode := false
var _height_label: Label
var _best_label: Label
var _mode_label: Label
var _fish_label: Label
var _pause_button: TextureButton
var _left_button: TextureButton
var _right_button: TextureButton
var _card: PanelContainer
var _fish_card: PanelContainer
var _shown_m := -1
var _pop := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card = UiKit.panel()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	var v := UiKit.vbox(0)
	_card.add_child(v)
	_mode_label = UiKit.label("", 20, UiKit.CORAL, true)
	v.add_child(_mode_label)
	_height_label = UiKit.label("0 m", 64, UiKit.INK, true)
	v.add_child(_height_label)
	_best_label = UiKit.label("", 20, UiKit.INK.lerp(Color.WHITE, 0.25))
	v.add_child(_best_label)
	_fish_card = UiKit.panel()
	_fish_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fish_card)
	var fh := UiKit.hbox(10)
	_fish_card.add_child(fh)
	fh.add_child(UiKit.icon(FISH_TEX, 44))
	_fish_label = UiKit.label("0", 34, UiKit.INK, true)
	fh.add_child(_fish_label)
	_pause_button = TextureButton.new()
	_pause_button.texture_normal = PAUSE_TEX
	_pause_button.ignore_texture_size = true
	_pause_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_pause_button.custom_minimum_size = Vector2(76, 76)
	_pause_button.size = Vector2(76, 76)
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.pressed.connect(func(): pause_pressed.emit())
	add_child(_pause_button)
	_left_button = _arrow(true)
	_right_button = _arrow(false)
	touch_mode = DisplayServer.is_touchscreen_available() and OS.has_feature("web") and _is_mobile_web()
	_layout()
	I18n.locale_changed.connect(func(_l: String): refresh_labels())
	get_viewport().size_changed.connect(_layout)

func _is_mobile_web() -> bool:
	return bool(JavaScriptBridge.eval("(() => { try { return matchMedia('(pointer: coarse)').matches; } catch (e) { return false; } })()", true))

func _arrow(left: bool) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = ARROW_TEX
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.flip_h = left
	b.custom_minimum_size = Vector2(170, 170)
	b.size = Vector2(170, 170)
	b.focus_mode = Control.FOCUS_NONE
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	b.modulate = Color(1, 1, 1, 0.85)
	b.button_down.connect(func():
		if left: touch_left = true
		else: touch_right = true
		b.scale = Vector2(0.92, 0.92)
	)
	b.button_up.connect(func():
		if left: touch_left = false
		else: touch_right = false
		b.scale = Vector2.ONE
	)
	b.pivot_offset = Vector2(85, 85)
	add_child(b)
	return b

func enable_touch() -> void:
	if not touch_mode:
		touch_mode = true
		_layout()

func touch_axis() -> float:
	return (1.0 if touch_right else 0.0) - (1.0 if touch_left else 0.0)

func _layout() -> void:
	var vs := get_viewport_rect().size
	var side := (vs.x - GameConfig.COLUMN_WIDTH) * 0.5
	var compact := side < 300.0
	var card_w := clampf(side - 36.0, 150.0, 300.0)
	_card.position = Vector2(maxf(12.0, side - card_w - 24.0), 18)
	_card.custom_minimum_size = Vector2(card_w, 0)
	_height_label.add_theme_font_size_override("font_size", 46 if compact else 64)
	_fish_card.position = Vector2(_card.position.x, 18 + 180)
	_fish_card.custom_minimum_size = Vector2(minf(card_w, 200.0), 0)
	_pause_button.position = Vector2(vs.x - 96, 18)
	_left_button.visible = touch_mode
	_right_button.visible = touch_mode
	_left_button.position = Vector2(maxf(12.0, side * 0.5 - 85.0), vs.y - 200)
	_right_button.position = Vector2(vs.x - maxf(12.0, side * 0.5 - 85.0) - 170.0, vs.y - 200)

func refresh_labels() -> void:
	if game == null:
		return
	_mode_label.text = I18n.t("mode.daily_short", {"date": Main.pretty_date(game.daily_key)}) if game.mode == "daily" else I18n.t("mode.endless_short")
	_best_label.text = I18n.t("hud.best", {"m": game.local_best_m})
	_shown_m = -1

func _process(delta: float) -> void:
	if game == null or not visible:
		return
	# Keep the fish card tucked under the height card whatever its final height.
	_fish_card.position.y = _card.position.y + _card.size.y + 12.0
	if game.meters != _shown_m:
		if _shown_m >= 0 and game.meters / 10 != _shown_m / 10:
			_pop = 1.0
		_shown_m = game.meters
		_height_label.text = I18n.t("hud.meters", {"m": game.meters})
		if game.meters > game.local_best_m and game.local_best_m > 0:
			_best_label.text = I18n.t("hud.new_best")
			_best_label.add_theme_color_override("font_color", UiKit.CORAL)
		else:
			_best_label.add_theme_color_override("font_color", UiKit.INK.lerp(Color.WHITE, 0.25))
	_fish_label.text = str(game.fish)
	_pop = maxf(0.0, _pop - delta * 4.0)
	_height_label.pivot_offset = _height_label.size * Vector2(0.0, 0.5)
	_height_label.scale = Vector2.ONE * (1.0 + _pop * 0.12)
	queue_redraw()

func _draw() -> void:
	if game == null:
		return
	var vs := get_viewport_rect().size
	var side := (vs.x - GameConfig.COLUMN_WIDTH) * 0.5
	var font := UiKit.DISPLAY_FONT
	# Fish → shield progress under the fish counter.
	var fr := Rect2(_fish_card.position + Vector2(20, _fish_card.size.y + 6), Vector2(_fish_card.size.x - 40, 12))
	draw_rect(fr, Color(1, 1, 1, 0.55))
	draw_rect(Rect2(fr.position, Vector2(fr.size.x * float(game.fish_toward_shield) / GameConfig.FISH_FOR_SHIELD, fr.size.y)), UiKit.GOLD)
	draw_rect(fr, UiKit.INK, false, 2.0)
	# Active power-ups with countdown rings (right side).
	var px := vs.x - side + 40.0
	var py := 130.0
	for entry: Array in [["rocket", game.rocket_time, GameConfig.ROCKET_SECONDS], ["shield", game.shield_time, GameConfig.SHIELD_SECONDS], ["magnet", game.magnet_time, GameConfig.MAGNET_SECONDS]]:
		var t: float = entry[1]
		if t <= 0.0:
			continue
		var c := Vector2(px + 34, py + 34)
		draw_circle(c, 38, Color(1, 0.97, 0.9, 0.9))
		draw_arc(c, 38, -PI * 0.5, -PI * 0.5 + TAU * clampf(t / float(entry[2]), 0.0, 1.0), 48, UiKit.CORAL, 6.0, true)
		draw_arc(c, 38, 0, TAU, 48, UiKit.INK, 2.0, true)
		var tex: Texture2D = POWER_TEX[entry[0]]
		var s := 44.0 / maxf(tex.get_width(), tex.get_height())
		draw_texture_rect(tex, Rect2(c - tex.get_size() * s * 0.5, tex.get_size() * s), false)
		var label := I18n.t("power." + String(entry[0]))
		draw_string_outline(font, Vector2(px + 84, py + 44), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 6, Color.WHITE)
		draw_string(font, Vector2(px + 84, py + 44), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UiKit.INK)
		py += 92.0
	# Altimeter towards the next milestone.
	var next := TowerData.next_milestone(game.meters)
	if not next.is_empty() and side > 200.0:
		var prev_m := 0
		for ms: Dictionary in TowerData.MILESTONES:
			if int(ms.m) <= game.meters:
				prev_m = int(ms.m)
		var bx := vs.x - side * 0.5
		var top := maxf(vs.y * 0.45, 480.0)
		var bottom := vs.y - (240.0 if touch_mode else 70.0)
		if bottom - top > 120.0:
			var frac := clampf(float(game.meters - prev_m) / float(int(next.m) - prev_m), 0.0, 1.0)
			draw_line(Vector2(bx, top), Vector2(bx, bottom), Color(1, 1, 1, 0.7), 10.0, true)
			draw_line(Vector2(bx, bottom), Vector2(bx, lerpf(bottom, top, frac)), UiKit.GOLD, 10.0, true)
			var name_text := I18n.t(String(next.name))
			var head := "%d m" % int(next.m)
			for pair: Array in [[head, top - 40.0, 30], [name_text, top - 12.0, 22]]:
				var w := font.get_string_size(pair[0], HORIZONTAL_ALIGNMENT_LEFT, -1, pair[2]).x
				draw_string_outline(font, Vector2(bx - w * 0.5, pair[1]), pair[0], HORIZONTAL_ALIGNMENT_LEFT, -1, pair[2], 7, Color.WHITE)
				draw_string(font, Vector2(bx - w * 0.5, pair[1]), pair[0], HORIZONTAL_ALIGNMENT_LEFT, -1, pair[2], UiKit.INK)
			var cs := 44.0 / CAT_TEX.get_height()
			var cy := lerpf(bottom, top, frac)
			draw_texture_rect(CAT_TEX, Rect2(Vector2(bx - CAT_TEX.get_width() * cs * 0.5, cy - CAT_TEX.get_height() * cs * 0.5), CAT_TEX.get_size() * cs), false)
