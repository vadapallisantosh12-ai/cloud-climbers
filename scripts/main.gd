class_name Main
extends Node
## Game shell: title, run flow, pause, settings, results, leaderboard, share card,
## first-run tutorial, hint toasts and milestone celebrations. Gameplay lives in
## ClimbGame; this script only orchestrates screens and input.

enum Screen { TITLE, PLAYING, PAUSED, RESULTS }

const TROPHY := preload("res://assets/game/ui/icon_trophy.webp")
const GEAR := preload("res://assets/game/ui/icon_gear.webp")
const SHARE := preload("res://assets/game/ui/icon_share.webp")
const BANNER := preload("res://assets/game/ui/banner.webp")
const FISH := preload("res://assets/game/items/fish.webp")
const HINT_ICONS := {
	"biscuit": preload("res://assets/game/platforms/platform_biscuit.webp"),
	"cloud": preload("res://assets/game/platforms/platform_cloud.webp"),
	"moving": preload("res://assets/game/platforms/platform_winged.webp"),
	"spring": preload("res://assets/game/platforms/spring.webp"),
	"enemy": preload("res://assets/game/enemies/gloomling.webp"),
	"rocket": preload("res://assets/game/items/rocket.webp"),
	"shield": preload("res://assets/game/items/shield.webp"),
	"magnet": preload("res://assets/game/items/magnet.webp"),
	"fish_shield": preload("res://assets/game/items/fish.webp"),
}

var screen := Screen.TITLE
var game: ClimbGame
var sky: SkyBackdrop
var hud: ClimbHud
var online: OnlineService
var ui_root: Control
var modal_root: Control
var toast_root: Control
var overlay_fx: FxLayer
var modal_stack: Array[Control] = []
var mode := "daily"
var daily_key := ""
var last_summary: Dictionary = {}
var last_rank := 0
var last_is_best := false
var endless_seed := 0
var _tutorial: Control
var _tutorial_time := 0.0
var _run_token := 0
var _tutorial_steer := 0.0
var _toast_queue: Array[String] = []
var _toast_busy := false
var _results_online_label: Label
var _results_name_row: Control
var _share_image: Image
var _settings_open := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Controls.setup()
	daily_key = TowerGenerator.daily_key()
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -10
	add_child(sky_layer)
	sky = SkyBackdrop.new()
	sky_layer.add_child(sky)
	game = ClimbGame.new()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	game.sky = sky
	add_child(game)
	game.run_finished.connect(_on_run_finished)
	game.milestone_reached.connect(_on_milestone)
	game.hint_requested.connect(_on_hint)
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 5
	add_child(hud_layer)
	hud = ClimbHud.new()
	hud.game = game
	hud_layer.add_child(hud)
	hud.pause_pressed.connect(_pause)
	hud.visible = false
	var fx_layer := CanvasLayer.new()
	fx_layer.layer = 8
	add_child(fx_layer)
	overlay_fx = FxLayer.new()
	fx_layer.add_child(overlay_fx)
	toast_root = _full_rect()
	toast_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(toast_root)
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	ui_root = _full_rect()
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(ui_root)
	modal_root = _full_rect()
	modal_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(modal_root)
	online = OnlineService.new()
	add_child(online)
	endless_seed = randi()
	I18n.locale_changed.connect(func(_l: String): _rebuild())
	AudioDirector.start_music()
	_show_title()

static func _full_rect() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c

static func pretty_date(key: String) -> String:
	if key.length() != 8:
		return key
	var month := int(key.substr(4, 2))
	var day := int(key.substr(6, 2))
	if I18n.get_locale() == "zh-CN":
		return "%d月%d日" % [month, day]
	var names := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%s %d" % [names[clampi(month - 1, 0, 11)], day]

static func pretty_time(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]

func _clear(node: Control) -> void:
	for child in node.get_children():
		child.queue_free()

func _focus(control: Control) -> void:
	if control != null:
		control.call_deferred("grab_focus")

# --- Title ---------------------------------------------------------------------

func _show_title() -> void:
	screen = Screen.TITLE
	get_tree().paused = false
	AudioDirector.set_paused(false)
	hud.visible = false
	_close_all_modals()
	_clear(ui_root)
	_clear(toast_root)
	_toast_queue.clear()
	_toast_busy = false
	_remove_tutorial()
	daily_key = TowerGenerator.daily_key()
	game.build(TowerGenerator.daily_seed(daily_key), "daily", daily_key, 0)
	var root := UiKit.vbox(0)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(root)
	var top_pad := Control.new()
	top_pad.custom_minimum_size = Vector2(0, 16)
	top_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_pad)
	# Logo.
	var logo := UiKit.vbox(-30)
	logo.alignment = BoxContainer.ALIGNMENT_CENTER
	logo.custom_minimum_size = Vector2(0, 200)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(logo)
	var title := UiKit.label(I18n.t("title.main"), 92, UiKit.CREAM, true, 22, UiKit.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_child(title)
	var ribbon := _ribbon(I18n.t("title.sub"), 32, 360)
	logo.add_child(ribbon)
	var tagline := UiKit.label(I18n.t("title.tagline"), 24, UiKit.CREAM, true, 8, UiKit.INK)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_child(tagline)
	# Middle row: daily card | column | endless card.
	var middle := UiKit.hbox(0)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(middle)
	var left := CenterContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(left)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(GameConfig.COLUMN_WIDTH, 0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(spacer)
	var right := CenterContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(right)
	var daily_button := _mode_card(left, I18n.t("mode.daily"), I18n.t("mode.daily_date", {"date": pretty_date(daily_key)}),
		I18n.t("mode.daily_desc"), I18n.t("mode.best_today", {"m": SaveStore.best_for("daily", daily_key)}), I18n.t("mode.daily_play"), "primary")
	daily_button.pressed.connect(func(): _request_start("daily"))
	var endless_button := _mode_card(right, I18n.t("mode.endless"), I18n.t("mode.endless_sub"),
		I18n.t("mode.endless_desc"), I18n.t("mode.best_all", {"m": SaveStore.best_endless}), I18n.t("mode.endless_play"), "secondary")
	endless_button.pressed.connect(func(): _request_start("endless"))
	# Bottom bar.
	var bar := UiKit.hbox(16)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.custom_minimum_size = Vector2(0, 84)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	var board := _icon_button(I18n.t("menu.leaderboard"), TROPHY, "quiet")
	board.pressed.connect(func(): _open_leaderboard("daily"))
	bar.add_child(board)
	var settings := _icon_button(I18n.t("menu.settings"), GEAR, "quiet")
	settings.pressed.connect(_open_settings)
	bar.add_child(settings)
	var lang := UiKit.button(I18n.t("menu.language_toggle"), "quiet", 26, 140)
	lang.pressed.connect(func(): I18n.toggle_locale())
	bar.add_child(lang)
	var foot := UiKit.label(I18n.t("tutorial.touch") if hud.touch_mode else I18n.t("title.controls"), 18, UiKit.CREAM, false, 6, UiKit.INK)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.custom_minimum_size = Vector2(0, 34)
	root.add_child(foot)
	UiKit.pop_in(title)
	_focus(daily_button)

func _ribbon(text: String, size: int, width: float) -> Control:
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := Control.new()
	box.custom_minimum_size = Vector2(width, width * BANNER.get_height() / BANNER.get_width())
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(box)
	var tex := UiKit.icon(BANNER, 0)
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	box.add_child(tex)
	var l := UiKit.label(text, size, UiKit.CREAM, true, 6, Color("b24a3c"))
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.offset_top = -10
	box.add_child(l)
	return holder

func _mode_card(parent: Control, heading: String, sub: String, desc: String, best: String, play: String, variant: String) -> Button:
	var vs := get_viewport().get_visible_rect().size
	var side := (vs.x - GameConfig.COLUMN_WIDTH) * 0.5
	var card := UiKit.panel()
	card.custom_minimum_size = Vector2(clampf(side - 40.0, 220.0, 330.0), 0)
	parent.add_child(card)
	var v := UiKit.vbox(6)
	card.add_child(v)
	var h := UiKit.label(heading, 40, UiKit.CORAL, true)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(h)
	var s := UiKit.label(sub, 22, UiKit.INK, true)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	var d := UiKit.label(desc, 18, UiKit.INK.lerp(Color.WHITE, 0.2))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(d)
	var b2 := UiKit.label(best, 24, UiKit.INK, true)
	b2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(b2)
	var b := UiKit.button(play, variant, 32)
	v.add_child(b)
	UiKit.pop_in(card, 0.08)
	return b

func _icon_button(text: String, tex: Texture2D, variant: String) -> Button:
	var b := UiKit.button(text, variant, 26, 180)
	b.icon = tex
	b.add_theme_constant_override("icon_max_width", 38)
	b.add_theme_constant_override("h_separation", 10)
	return b

# --- Run flow ----------------------------------------------------------------------

func _request_start(run_mode: String) -> void:
	if not SaveStore.name_prompted:
		_open_name(func(): _begin_run(run_mode))
	else:
		_begin_run(run_mode)

func _begin_run(run_mode: String) -> void:
	_run_token += 1
	mode = run_mode
	_close_all_modals()
	_clear(ui_root)
	_clear(toast_root)
	_toast_queue.clear()
	_toast_busy = false
	get_tree().paused = false
	AudioDirector.set_paused(false)
	daily_key = TowerGenerator.daily_key()
	var tower_seed := TowerGenerator.daily_seed(daily_key) if mode == "daily" else endless_seed
	game.build(tower_seed, mode, daily_key, SaveStore.best_for(mode, daily_key))
	game.start_run()
	hud.visible = true
	hud.refresh_labels()
	screen = Screen.PLAYING
	TuningStore.begin_run()
	online.begin(mode, daily_key)
	if not SaveStore.tutorial_done:
		_show_tutorial()

func _retry() -> void:
	if mode == "endless":
		endless_seed = randi()
	AudioDirector.play(&"ui_confirm")
	_begin_run(mode)

func _on_run_finished(summary: Dictionary) -> void:
	last_summary = summary
	last_rank = 0
	last_is_best = SaveStore.record_run(summary)
	TuningStore.end_run()
	_remove_tutorial()
	var token := _run_token
	await get_tree().create_timer(0.75).timeout
	# A quick retry during the fall delay starts a new run; never cover it.
	if screen != Screen.PLAYING or token != _run_token:
		return
	_show_results()
	_submit_online()

func _submit_online() -> void:
	var summary := last_summary
	if not online.has_identity():
		_set_online_status(I18n.t("online.need_name"))
		return
	_set_online_status(I18n.t("online.submitting"))
	var result: Dictionary = await online.submit(int(summary.meters))
	if summary != last_summary:
		return
	if result.get("ok", false):
		last_rank = int(result.get("rank", 0))
		_set_online_status(I18n.t("online.ranked", {"rank": last_rank}) if last_rank > 0 else I18n.t("online.submitted"))
	else:
		_set_online_status(OnlineService.error_text(String(result.get("error", ""))))

func _set_online_status(text: String) -> void:
	if is_instance_valid(_results_online_label):
		_results_online_label.text = text

# --- Results ---------------------------------------------------------------------

func _show_results() -> void:
	screen = Screen.RESULTS
	hud.visible = false
	_clear(ui_root)
	var s := last_summary
	var dimmer := UiKit.dim()
	dimmer.color.a = 0.3
	ui_root.add_child(dimmer)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(center)
	var card := UiKit.panel()
	card.custom_minimum_size = Vector2(700, 0)
	center.add_child(card)
	var v := UiKit.vbox(6)
	card.add_child(v)
	var heading := UiKit.label(I18n.t("results.enemy") if s.cause == "enemy" else I18n.t("results.fall"), 40, UiKit.CORAL, true)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(heading)
	var sub := UiKit.label(I18n.t("share.daily", {"date": pretty_date(String(s.daily_key))}) if s.mode == "daily" else I18n.t("share.endless"), 20, UiKit.INK)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var big := UiKit.label(I18n.t("hud.meters", {"m": 0}), 104, UiKit.INK, true, 12, Color.WHITE)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(big)
	var target_m := int(s.meters)
	var tw := big.create_tween()
	tw.tween_method(func(x: float): big.text = I18n.t("hud.meters", {"m": int(x)}), 0.0, float(target_m), clampf(target_m / 600.0, 0.4, 1.2)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if last_is_best:
		var best_ribbon := _ribbon(I18n.t("results.new_best"), 30, 320)
		v.add_child(best_ribbon)
		tw.tween_callback(func():
			AudioDirector.play(&"milestone")
			var vs := get_viewport().get_visible_rect().size
			overlay_fx.confetti(Vector2(vs.x * 0.5 - 300, vs.y), 50, 700.0)
			overlay_fx.confetti(Vector2(vs.x * 0.5 + 300, vs.y), 50, 700.0)
		)
	else:
		var best := UiKit.label(I18n.t("results.best", {"m": SaveStore.best_for(String(s.mode), String(s.daily_key))}), 24, UiKit.INK, true)
		best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(best)
	var stats := UiKit.hbox(26)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_child(UiKit.icon(FISH, 38))
	stats.add_child(UiKit.label("× %d" % int(s.fish), 26, UiKit.INK, true))
	stats.add_child(UiKit.label(I18n.t("results.time", {"t": pretty_time(float(s.time))}), 26, UiKit.INK, true))
	stats.add_child(UiKit.label(I18n.t("results.stomps", {"n": int(s.stomps)}), 26, UiKit.INK, true))
	v.add_child(stats)
	_results_online_label = UiKit.label("", 20, Color("3d6f8f"))
	_results_online_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results_online_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_results_online_label)
	_results_name_row = null
	if not online.has_identity():
		_results_name_row = _name_row(func(_n: String):
			if is_instance_valid(_results_name_row):
				_results_name_row.queue_free()
			_set_online_status(I18n.t("online.joined_next"))
		)
		v.add_child(_results_name_row)
	var row := UiKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var again := UiKit.button(I18n.t("results.again"), "primary", 30, 190)
	again.pressed.connect(_retry)
	row.add_child(again)
	var share := _icon_button(I18n.t("results.share"), SHARE, "secondary")
	share.pressed.connect(_open_share)
	row.add_child(share)
	var board := _icon_button(I18n.t("menu.leaderboard"), TROPHY, "quiet")
	board.pressed.connect(func(): _open_leaderboard(String(s.mode)))
	row.add_child(board)
	var menu := UiKit.button(I18n.t("results.menu"), "quiet", 26, 120)
	menu.pressed.connect(_show_title)
	row.add_child(menu)
	var hint := UiKit.label(I18n.t("results.hint"), 16, UiKit.INK.lerp(Color.WHITE, 0.3))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	UiKit.pop_in(card)
	_focus(again)

func _name_row(on_done: Callable) -> Control:
	var row := UiKit.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var edit := _line_edit()
	row.add_child(edit)
	var join := UiKit.button(I18n.t("online.join"), "secondary", 24, 150)
	row.add_child(join)
	var submit := func():
		var text := edit.text.strip_edges()
		if text.is_empty():
			AudioDirector.play(&"ui_invalid")
			return
		SaveStore.set_nickname(text)
		join.disabled = true
		var result: Dictionary = await online.register(text)
		if result.get("ok", false):
			on_done.call(text)
		else:
			join.disabled = false
			_set_online_status(OnlineService.error_text(String(result.get("error", ""))))
	join.pressed.connect(submit)
	edit.text_submitted.connect(func(_t: String): submit.call())
	return row

func _line_edit() -> LineEdit:
	var edit := LineEdit.new()
	edit.max_length = GameConfig.NAME_MAX_CHARS
	edit.placeholder_text = I18n.t("name.placeholder")
	edit.custom_minimum_size = Vector2(300, 60)
	edit.text = SaveStore.nickname
	edit.add_theme_font_override("font", UiKit.DISPLAY_FONT)
	edit.add_theme_font_size_override("font_size", 28)
	edit.add_theme_color_override("font_color", UiKit.INK)
	edit.add_theme_color_override("font_placeholder_color", UiKit.INK.lerp(Color.WHITE, 0.5))
	edit.add_theme_color_override("caret_color", UiKit.CORAL)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fffdf5")
	sb.border_color = UiKit.INK
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	edit.add_theme_stylebox_override("normal", sb)
	var focus := sb.duplicate() as StyleBoxFlat
	focus.border_color = UiKit.CORAL
	edit.add_theme_stylebox_override("focus", focus)
	return edit

# --- Pause -----------------------------------------------------------------------

func _pause() -> void:
	if screen != Screen.PLAYING or game.state == ClimbGame.State.OVER:
		return
	screen = Screen.PAUSED
	get_tree().paused = true
	AudioDirector.set_paused(true)
	game.pointer_active = false
	AudioDirector.play(&"ui_confirm")
	var v := _open_modal(I18n.t("pause.title"), 460)
	var resume := UiKit.button(I18n.t("pause.resume"), "primary", 30)
	resume.pressed.connect(_resume)
	v.add_child(resume)
	var restart := UiKit.button(I18n.t("pause.restart"), "secondary", 28)
	restart.pressed.connect(_retry)
	v.add_child(restart)
	var settings := UiKit.button(I18n.t("menu.settings"), "quiet", 28)
	settings.pressed.connect(_open_settings)
	v.add_child(settings)
	var quit := UiKit.button(I18n.t("pause.quit"), "quiet", 28)
	quit.pressed.connect(func():
		TuningStore.end_run()
		_show_title()
	)
	v.add_child(quit)
	var hint := UiKit.label(I18n.t("pause.hint"), 16, UiKit.INK.lerp(Color.WHITE, 0.3))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	_focus(resume)

func _resume() -> void:
	if screen != Screen.PAUSED:
		return
	_close_all_modals()
	screen = Screen.PLAYING
	get_tree().paused = false
	AudioDirector.set_paused(false)
	AudioDirector.play(&"ui_back")

# --- Modals ------------------------------------------------------------------------

func _open_modal(heading: String, width: float) -> VBoxContainer:
	var holder := _full_rect()
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_root.add_child(holder)
	holder.add_child(UiKit.dim())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(center)
	var card := UiKit.panel()
	card.custom_minimum_size = Vector2(width, 0)
	center.add_child(card)
	var v := UiKit.vbox(10)
	card.add_child(v)
	var h := UiKit.label(heading, 44, UiKit.CORAL, true)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(h)
	for child in modal_stack:
		child.visible = false
	modal_stack.append(holder)
	UiKit.pop_in(card)
	return v

func _close_top_modal() -> void:
	if modal_stack.is_empty():
		return
	var top: Control = modal_stack.pop_back()
	if top.has_meta("on_close"):
		(top.get_meta("on_close") as Callable).call()
	top.queue_free()
	AudioDirector.play(&"ui_back")
	if not modal_stack.is_empty():
		var below: Control = modal_stack.back()
		below.visible = true
		var first := _first_button(below)
		_focus(first)
	else:
		_settings_open = false
		_focus(_first_button(ui_root))

func _close_all_modals() -> void:
	for m in modal_stack:
		m.queue_free()
	modal_stack.clear()
	_settings_open = false

func _first_button(node: Node) -> Button:
	for child in node.get_children():
		if child is Button and (child as Button).visible and not (child as Button).disabled:
			return child
		var found := _first_button(child)
		if found != null:
			return found
	return null

func _open_settings() -> void:
	_settings_open = true
	var v := _open_modal(I18n.t("menu.settings"), 620)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	for channel: String in ["Master", "Music", "SFX"]:
		grid.add_child(UiKit.label(I18n.t("settings." + channel.to_lower()), 26, UiKit.INK, true))
		var s := UiKit.slider(AudioDirector.get_volume(channel))
		s.value_changed.connect(func(value: float):
			AudioDirector.set_volume(channel, value)
			AudioDirector.save_settings()
			AudioDirector.play(&"ui_adjust")
		)
		grid.add_child(s)
	grid.add_child(UiKit.label(I18n.t("settings.effects"), 26, UiKit.INK, true))
	grid.add_child(UiKit.choice([I18n.t("settings.high"), I18n.t("settings.low")], 0 if GameSettings.high_effects else 1,
		func(i: int): GameSettings.set_high_effects(i == 0)))
	grid.add_child(UiKit.label(I18n.t("settings.shake"), 26, UiKit.INK, true))
	grid.add_child(UiKit.choice([I18n.t("settings.on"), I18n.t("settings.off")], 0 if GameSettings.screen_shake else 1,
		func(i: int): GameSettings.set_screen_shake(i == 0)))
	grid.add_child(UiKit.label(I18n.t("settings.language"), 26, UiKit.INK, true))
	grid.add_child(UiKit.choice(["中文", "English"], 0 if I18n.get_locale() == "zh-CN" else 1,
		func(i: int): I18n.set_locale("zh-CN" if i == 0 else "en")))
	var controls := UiKit.label(I18n.t("settings.controls"), 17, UiKit.INK.lerp(Color.WHITE, 0.15))
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.custom_minimum_size = Vector2(560, 0)
	v.add_child(controls)
	var back := UiKit.button(I18n.t("menu.back"), "primary", 28)
	back.pressed.connect(_close_top_modal)
	v.add_child(back)
	_focus(back)

func _open_name(then: Callable) -> void:
	var v := _open_modal(I18n.t("name.title"), 560)
	var desc := UiKit.label(I18n.t("name.desc"), 20, UiKit.INK)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.custom_minimum_size = Vector2(500, 0)
	v.add_child(desc)
	var edit := _line_edit()
	if edit.text.is_empty():
		edit.text = I18n.t("name.default", {"n": randi_range(100, 999)})
	v.add_child(edit)
	var row := UiKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var ok := UiKit.button(I18n.t("name.confirm"), "primary", 30, 200)
	row.add_child(ok)
	var skip := UiKit.button(I18n.t("name.skip"), "quiet", 26, 160)
	row.add_child(skip)
	var confirm := func():
		var text := edit.text.strip_edges()
		if text.is_empty():
			AudioDirector.play(&"ui_invalid")
			return
		SaveStore.set_nickname(text)
		then.call()
		_register_then_begin(text)
	ok.pressed.connect(confirm)
	edit.text_submitted.connect(func(_t: String): confirm.call())
	skip.pressed.connect(func():
		SaveStore.name_prompted = true
		SaveStore.save()
		then.call()
	)
	edit.call_deferred("grab_focus")
	edit.call_deferred("select_all")

func _register_then_begin(display_name: String) -> void:
	var result: Dictionary = await online.register(display_name)
	if result.get("ok", false) and screen == Screen.PLAYING and online.run_id.is_empty():
		online.begin(mode, daily_key)

func _open_leaderboard(tab: String) -> void:
	var v := _open_modal(I18n.t("menu.leaderboard"), 640)
	var list := UiKit.vbox(4)
	var status := UiKit.label("", 20, Color("3d6f8f"))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var who := UiKit.label(I18n.t("board.playing_as", {"name": SaveStore.nickname}) if online.has_identity() else I18n.t("online.need_name"), 18, UiKit.INK)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var load_tab := func(which: String):
		_clear(list)
		status.text = I18n.t("board.loading")
		var board_id := OnlineService.board_for(which, daily_key)
		var result: Dictionary = await online.fetch(board_id, 10)
		if not is_instance_valid(list):
			return
		_clear(list)
		if not result.get("ok", false):
			status.text = OnlineService.error_text(String(result.get("error", "")))
			return
		var entries: Array = result.data.get("entries", [])
		status.text = I18n.t("board.empty") if entries.is_empty() else ""
		for e: Dictionary in entries:
			list.add_child(_board_row(int(e.rank), String(e.displayName), int(e.score), false))
		if result.data.get("myRank") is Dictionary:
			var mine: Dictionary = result.data.myRank
			if int(mine.rank) > entries.size():
				list.add_child(_board_row(int(mine.rank), SaveStore.nickname, int(mine.score), true))
	v.add_child(UiKit.choice([I18n.t("board.today", {"date": pretty_date(daily_key)}), I18n.t("board.endless")], 0 if tab == "daily" else 1,
		func(i: int): load_tab.call("daily" if i == 0 else "endless"), 24))
	var scroll_holder := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.45)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(10)
	scroll_holder.add_theme_stylebox_override("panel", sb)
	scroll_holder.custom_minimum_size = Vector2(560, 300)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_holder.add_child(scroll)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	v.add_child(scroll_holder)
	v.add_child(status)
	v.add_child(who)
	if not online.has_identity():
		v.add_child(_name_row(func(n: String):
			who.text = I18n.t("board.playing_as", {"name": n})
		))
	var back := UiKit.button(I18n.t("menu.back"), "primary", 28)
	back.pressed.connect(_close_top_modal)
	v.add_child(back)
	load_tab.call(tab)
	_focus(back)

func _board_row(rank: int, player: String, score: int, mine: bool) -> Control:
	var row := UiKit.hbox(12)
	var medal_colors := [Color("f2b233"), Color("b8c3cc"), Color("d08a4f")]
	var r := UiKit.label("#%d" % rank, 26, medal_colors[rank - 1] if rank <= 3 else UiKit.INK, true, 5 if rank <= 3 else 0, UiKit.INK)
	r.custom_minimum_size = Vector2(80, 0)
	row.add_child(r)
	var n := UiKit.label(player, 24, UiKit.CORAL if mine or player == SaveStore.nickname else UiKit.INK, true)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.clip_text = true
	row.add_child(n)
	row.add_child(UiKit.label(I18n.t("hud.meters", {"m": score}), 26, UiKit.INK, true))
	return row

func _open_share() -> void:
	var v := _open_modal(I18n.t("share.title"), 700)
	var status := UiKit.label(I18n.t("share.rendering"), 20, Color("3d6f8f"))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(600, 315)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v.add_child(preview)
	v.add_child(status)
	var row := UiKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var save := UiKit.button(I18n.t("share.save"), "primary", 28, 200)
	save.disabled = true
	row.add_child(save)
	var copy := UiKit.button(I18n.t("share.copy"), "secondary", 26, 180)
	row.add_child(copy)
	var back := UiKit.button(I18n.t("menu.back"), "quiet", 26, 140)
	back.pressed.connect(_close_top_modal)
	row.add_child(back)
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(_share_text())
		status.text = I18n.t("share.copied")
		AudioDirector.play(&"ui_confirm")
	)
	save.pressed.connect(func():
		if _share_image != null:
			status.text = I18n.t(ShareCard.save(_share_image, int(last_summary.meters)))
			AudioDirector.play(&"ui_confirm")
	)
	_focus(back)
	_share_image = await ShareCard.render(self, last_summary, last_rank)
	if is_instance_valid(preview):
		preview.texture = ImageTexture.create_from_image(_share_image)
		status.text = I18n.t("share.ready")
		save.disabled = false
		_focus(save)

func _share_text() -> String:
	var s := last_summary
	if s.mode == "daily":
		return I18n.t("share.text_daily", {"m": int(s.meters), "date": pretty_date(String(s.daily_key))})
	return I18n.t("share.text_endless", {"m": int(s.meters)})

# --- Tutorial, hints, milestones ------------------------------------------------------

func _show_tutorial() -> void:
	_remove_tutorial()
	_tutorial_time = 0.0
	_tutorial_steer = 0.0
	var vs := get_viewport().get_visible_rect().size
	var card := UiKit.panel()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = Vector2(GameConfig.COLUMN_WIDTH - 40.0, 0)
	card.position = Vector2((vs.x - GameConfig.COLUMN_WIDTH) * 0.5 + 20.0, 90)
	toast_root.add_child(card)
	var v := UiKit.vbox(6)
	card.add_child(v)
	var h := UiKit.label(I18n.t("tutorial.title"), 34, UiKit.CORAL, true)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(h)
	for key in ["tutorial.keys", "tutorial.mouse", "tutorial.pad"] + (["tutorial.touch"] if hud.touch_mode else []):
		var l := UiKit.label(I18n.t(key), 20, UiKit.INK, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	var goal := UiKit.label(I18n.t("tutorial.goal"), 20, Color("3d6f8f"))
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(goal)
	_tutorial = card
	UiKit.pop_in(card)

func _remove_tutorial() -> void:
	if is_instance_valid(_tutorial):
		var t := _tutorial
		_tutorial = null
		var tw := t.create_tween()
		tw.tween_property(t, "modulate:a", 0.0, 0.3)
		tw.tween_callback(t.queue_free)

func _on_hint(kind: String) -> void:
	if kind == "fish_shield":
		_queue_toast(kind)
		return
	if SaveStore.mark_hint(kind):
		_queue_toast(kind)

func _queue_toast(kind: String) -> void:
	_toast_queue.append(kind)
	if not _toast_busy:
		_next_toast()

func _next_toast() -> void:
	if _toast_queue.is_empty():
		_toast_busy = false
		return
	_toast_busy = true
	var kind: String = _toast_queue.pop_front()
	var vs := get_viewport().get_visible_rect().size
	var card := UiKit.panel(Color(1, 1, 1, 0.96))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UiKit.hbox(12)
	card.add_child(row)
	row.add_child(UiKit.icon(HINT_ICONS.get(kind, FISH), 54))
	var l := UiKit.label(I18n.t("hint." + kind), 22, UiKit.INK, true)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(360, 0)
	row.add_child(l)
	toast_root.add_child(card)
	# Hints live on the left side panel so they never cover the climbing column.
	var side := (vs.x - GameConfig.COLUMN_WIDTH) * 0.5
	var wide := side >= 300.0
	var w := side - 48.0 if wide else GameConfig.COLUMN_WIDTH - 60.0
	card.custom_minimum_size = Vector2(w, 0)
	l.custom_minimum_size = Vector2(w - 120.0, 0)
	var home := Vector2(24.0, 350.0) if wide else Vector2(side + 30.0, 96.0)
	var hidden := home - Vector2(w + 60.0, 0) if wide else home - Vector2(0, 260)
	card.position = hidden
	AudioDirector.play(&"ui_notify")
	var tw := card.create_tween()
	tw.tween_property(card, "position", home, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(GameConfig.TUTORIAL_HINT_SECONDS)
	tw.tween_property(card, "position", hidden, 0.25).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		card.queue_free()
		_next_toast()
	)

func _on_milestone(ms: Dictionary) -> void:
	var vs := get_viewport().get_visible_rect().size
	var left := (vs.x - GameConfig.COLUMN_WIDTH) * 0.5
	overlay_fx.confetti(Vector2(left + 20, vs.y + 10), 45, 820.0)
	overlay_fx.confetti(Vector2(vs.x - left - 20, vs.y + 10), 45, 820.0)
	var holder := _ribbon(I18n.t("milestone.banner", {"m": int(ms.m), "name": I18n.t(String(ms.name))}), 30, 620)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_root.add_child(holder)
	holder.size = Vector2(vs.x, 200)
	holder.position = Vector2(0, -220)
	var tw := holder.create_tween()
	tw.tween_property(holder, "position:y", 60.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(GameConfig.MILESTONE_BANNER_SECONDS)
	tw.tween_property(holder, "position:y", -220.0, 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(holder.queue_free)

# --- Frame & input --------------------------------------------------------------------

func _process(delta: float) -> void:
	if screen == Screen.PLAYING:
		game.input_axis = clampf(Input.get_axis("move_left", "move_right") + hud.touch_axis(), -1.0, 1.0)
		if is_instance_valid(_tutorial):
			_tutorial_time += delta
			if absf(game.input_axis) > 0.3:
				_tutorial_steer += delta
			# Stay until the player has read it and actually steered a little.
			if (_tutorial_time > 3.5 and _tutorial_steer > 0.6) or _tutorial_time > 11.0:
				SaveStore.set_tutorial_done()
				_remove_tutorial()
	else:
		game.input_axis = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		hud.enable_touch()
	if screen == Screen.PLAYING:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			game.pointer_active = event.pressed
			game.pointer_screen_x = event.position.x
		elif event is InputEventMouseMotion and game.pointer_active:
			game.pointer_screen_x = event.position.x
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if screen == Screen.PLAYING:
			_pause()
		elif modal_stack.size() > 1 or (modal_stack.size() == 1 and screen != Screen.PAUSED):
			_close_top_modal()
		elif screen == Screen.PAUSED:
			_resume()
		elif screen == Screen.RESULTS and event.is_action_pressed("ui_cancel"):
			_show_title()
		return
	if event.is_action_pressed("restart") and modal_stack.is_empty() and screen == Screen.RESULTS:
		get_viewport().set_input_as_handled()
		_retry()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if screen == Screen.PLAYING and game.state == ClimbGame.State.PLAYING:
			_pause()

## Re-render text after a language switch, keeping the current screen.
func _rebuild() -> void:
	var reopen_settings := _settings_open
	match screen:
		Screen.TITLE:
			_show_title()
		Screen.RESULTS:
			_close_all_modals()
			_show_results()
			_set_online_status(I18n.t("online.ranked", {"rank": last_rank}) if last_rank > 0 else "")
		Screen.PAUSED:
			_close_all_modals()
			screen = Screen.PLAYING
			_pause()
		Screen.PLAYING:
			hud.refresh_labels()
	hud.refresh_labels()
	if reopen_settings:
		_open_settings()
