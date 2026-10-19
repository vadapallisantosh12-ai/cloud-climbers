class_name ShareCard
extends RefCounted
## Renders a 1200×630 score postcard offscreen and returns it as an Image.

const CAT := preload("res://assets/game/cat/cat_cheer.webp")
const MOON := preload("res://assets/game/sky/moon.webp")
const CLOUD := preload("res://assets/game/sky/cloud_puffy.webp")
const FISH := preload("res://assets/game/items/fish.webp")
const SIZE := Vector2i(1200, 630)

static func render(host: Node, summary: Dictionary, rank: int) -> Image:
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.gui_disable_input = true
	host.add_child(vp)
	var root := Control.new()
	root.size = Vector2(SIZE)
	vp.add_child(root)
	var sky := TowerData.sky_at(float(summary.meters))
	var grad := Gradient.new()
	grad.set_color(0, sky.top)
	grad.set_color(1, sky.bottom)
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 64
	gt.height = 64
	var bg := TextureRect.new()
	bg.texture = gt
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.size = Vector2(SIZE)
	root.add_child(bg)
	if float(sky.stars) > 0.3:
		var moon := _sprite(MOON, Vector2(980, 60), 0.55)
		moon.modulate.a = float(sky.stars)
		root.add_child(moon)
	for c: Array in [[Vector2(-80, 430), 0.9], [Vector2(760, 470), 0.8], [Vector2(420, -60), 0.5]]:
		var cloud := _sprite(CLOUD, c[0], c[1])
		cloud.modulate = Color(sky.cloud, 0.85)
		root.add_child(cloud)
	var card := UiKit.panel()
	card.position = Vector2(450, 70)
	card.custom_minimum_size = Vector2(700, 490)
	root.add_child(card)
	var v := UiKit.vbox(4)
	card.add_child(v)
	v.add_child(UiKit.label(I18n.t("app.title"), 60, UiKit.CORAL, true))
	var mode_text := I18n.t("share.daily", {"date": Main.pretty_date(String(summary.daily_key))}) if summary.mode == "daily" else I18n.t("share.endless")
	v.add_child(UiKit.label(mode_text, 32, UiKit.INK))
	v.add_child(UiKit.label(I18n.t("share.climbed"), 38, UiKit.INK, true))
	v.add_child(UiKit.label(I18n.t("hud.meters", {"m": int(summary.meters)}), 150, UiKit.INK, true, 12, Color.WHITE))
	var row := UiKit.hbox(14)
	row.add_child(UiKit.icon(FISH, 48))
	row.add_child(UiKit.label("× %d" % int(summary.fish), 36, UiKit.INK, true))
	row.add_child(UiKit.label("   " + I18n.t("share.time", {"t": Main.pretty_time(float(summary.time))}), 34, UiKit.INK, true))
	if rank > 0:
		row.add_child(UiKit.label("   " + I18n.t("share.rank", {"rank": rank}), 34, UiKit.CORAL, true))
	v.add_child(row)
	v.add_child(UiKit.label(I18n.t("share.tagline"), 34, UiKit.INK.lerp(Color.WHITE, 0.2), true))
	var cat := _sprite(CAT, Vector2(40, 150), 1.95)
	root.add_child(cat)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := vp.get_texture().get_image()
	vp.queue_free()
	return image

static func _sprite(tex: Texture2D, pos: Vector2, s: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.size = tex.get_size() * s
	t.position = pos
	return t

## Web: download the PNG; desktop: write to user storage. Returns a status key.
static func save(image: Image, meters: int) -> String:
	var buffer := image.save_png_to_buffer()
	var file_name := "cloud-climber-%dm.png" % meters
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(buffer, file_name, "image/png")
		return "share.downloaded"
	var path := "user://" + file_name
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "share.save_failed"
	f.store_buffer(buffer)
	return "share.saved"
