class_name UiKit
extends RefCounted
## Storybook UI building blocks shared by every screen. Panels and buttons are
## nine-sliced hand-painted textures; colours come from this palette.

const PANEL_TEX := preload("res://assets/game/ui/panel_9.webp")
const BUTTON_TEX := preload("res://assets/game/ui/button_9.webp")
const DISPLAY_FONT := preload("res://assets/template/fonts/display/display_doodle.tres")
const BODY_FONT := preload("res://assets/template/fonts/ui_bold.tres")

const INK := Color("5b3b2a")
const CREAM := Color("fff8e7")
const CORAL := Color("ff7a6b")
const GOLD := Color("ffd35c")
const SKY := Color("7cc8f2")
const MINT := Color("7ed3a8")

const BUTTON_TINTS := {
	"primary": Color(1, 1, 1),
	"secondary": Color(1.0, 0.8, 0.7),
	"quiet": Color(1.0, 0.95, 0.86),
	"danger": Color(1.0, 0.72, 0.66),
}

static func panel_style(tint: Color = Color.WHITE) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = PANEL_TEX
	sb.set_texture_margin_all(34)
	sb.set_content_margin_all(26)
	sb.modulate_color = tint
	return sb

static func panel(tint: Color = Color.WHITE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(tint))
	return p

static func _button_style(tint: Color) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = BUTTON_TEX
	sb.texture_margin_left = 36
	sb.texture_margin_right = 36
	sb.texture_margin_top = 30
	sb.texture_margin_bottom = 30
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 6
	sb.content_margin_bottom = 12
	sb.modulate_color = tint
	return sb

static func button(text: String, variant: String = "primary", font_size: int = 30, min_width: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	var tint: Color = BUTTON_TINTS.get(variant, Color.WHITE)
	b.set_meta("tint", tint)
	b.add_theme_stylebox_override("normal", _button_style(tint))
	b.add_theme_stylebox_override("hover", _button_style(tint.lightened(0.12)))
	b.add_theme_stylebox_override("pressed", _button_style(tint.darkened(0.12)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover_pressed", _button_style(tint.darkened(0.08)))
	b.add_theme_stylebox_override("disabled", _button_style(tint.darkened(0.35)))
	b.add_theme_font_override("font", DISPLAY_FONT)
	b.add_theme_font_size_override("font_size", font_size)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(key, INK)
	b.add_theme_color_override("font_disabled_color", INK.lerp(Color.WHITE, 0.4))
	b.custom_minimum_size = Vector2(min_width, 64)
	b.pivot_offset = Vector2.ZERO
	b.focus_entered.connect(func(): _pulse(b, true))
	b.focus_exited.connect(func(): _pulse(b, false))
	b.mouse_entered.connect(func(): if not b.disabled: b.grab_focus())
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	b.button_down.connect(func(): b.scale = Vector2(0.95, 0.95))
	b.button_up.connect(func(): b.scale = Vector2(1.04, 1.04) if b.has_focus() else Vector2.ONE)
	return b

static func _pulse(b: Button, on: bool) -> void:
	if not is_instance_valid(b):
		return
	var tint: Color = b.get_meta("tint", Color.WHITE)
	b.add_theme_stylebox_override("normal", _button_style(tint.lightened(0.18) if on else tint))
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2(1.05, 1.05) if on else Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

static func label(text: String, size: int = 24, color: Color = INK, display: bool = false, outline: int = 0, outline_color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", DISPLAY_FONT if display else BODY_FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", outline_color)
	return l

static func vbox(sep: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func slider(value: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(240, 36)
	s.focus_mode = Control.FOCUS_ALL
	var track := StyleBoxFlat.new()
	track.bg_color = Color("e8d6b8")
	track.border_color = INK
	track.set_border_width_all(3)
	track.set_corner_radius_all(10)
	track.content_margin_top = 7
	track.content_margin_bottom = 7
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = SKY
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := _knob_texture()
	s.add_theme_icon_override("grabber", knob)
	s.add_theme_icon_override("grabber_highlight", knob)
	s.add_theme_icon_override("grabber_disabled", knob)
	return s

static var _knob: Texture2D
static func _knob_texture() -> Texture2D:
	if _knob != null:
		return _knob
	var img := Image.create(30, 30, false, Image.FORMAT_RGBA8)
	for y in 30:
		for x in 30:
			var d := Vector2(x - 14.5, y - 14.5).length()
			if d <= 14.0:
				img.set_pixel(x, y, INK if d > 10.5 else GOLD)
	_knob = ImageTexture.create_from_image(img)
	return _knob

## Two-state pill toggle made of two buttons (keeps gamepad focus simple).
static func choice(options: Array, selected: int, on_pick: Callable, font_size: int = 24) -> HBoxContainer:
	var row := hbox(8)
	var buttons: Array[Button] = []
	for i in options.size():
		var b := button(String(options[i]), "primary" if i == selected else "quiet", font_size, 110)
		b.custom_minimum_size.y = 56
		b.set_meta("tint", BUTTON_TINTS.primary if i == selected else BUTTON_TINTS.quiet)
		buttons.append(b)
		row.add_child(b)
	for i in buttons.size():
		var index := i
		buttons[i].pressed.connect(func():
			for j in buttons.size():
				var t: Color = BUTTON_TINTS.primary if j == index else BUTTON_TINTS.quiet
				buttons[j].set_meta("tint", t)
				buttons[j].add_theme_stylebox_override("normal", _button_style(t))
			on_pick.call(index)
		)
	return row

static func dim() -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(0.12, 0.08, 0.2, 0.45)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	return c

static func icon(tex: Texture2D, size: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

static func pop_in(node: Control, delay: float = 0.0) -> void:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(0.85, 0.85)
	node.modulate.a = 0.0
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
	tw.tween_property(node, "modulate:a", 1.0, 0.18).set_delay(delay)
