class_name TowerPlatform
extends Node2D
## One platform. The node origin sits on the walkable top surface.

const SPRING_TEX := preload("res://assets/game/platforms/spring.webp")
const TEXTURES := {
	"grass": preload("res://assets/game/platforms/platform_grass.webp"),
	"moving": preload("res://assets/game/platforms/platform_winged.webp"),
	"cloud": preload("res://assets/game/platforms/platform_cloud.webp"),
	"spring": preload("res://assets/game/platforms/platform_grass.webp"),
	"biscuit": preload("res://assets/game/platforms/platform_biscuit.webp"),
}

var kind := "grass"
var half_width := 60.0
var solid := true
var move_speed := 0.0
var spring_x := 0.0
var sprite := Sprite2D.new()
var spring_sprite: Sprite2D
var _move_min := 0.0
var _move_max := 0.0
var _dir := 1.0
var _bob := 0.0
var _squash := 0.0
var _dying := false

func setup(spec: Dictionary) -> void:
	kind = String(spec.kind)
	var def: Dictionary = TowerData.PLATFORM_KINDS[kind]
	var tex: Texture2D = TEXTURES[kind]
	var width := float(def.width) * float(spec.scale)
	half_width = width * 0.5
	var s := width / tex.get_width()
	sprite.texture = tex
	sprite.scale = Vector2(s, s)
	sprite.centered = true
	# Place the walk surface (def.top px below the texture's top) on y = 0.
	sprite.position = Vector2(0, tex.get_height() * s * 0.5 - float(def.top) * s)
	add_child(sprite)
	position = Vector2(float(spec.x), float(spec.y))
	move_speed = float(spec.get("move_speed", 0.0))
	if kind == "moving":
		_move_min = half_width + 6.0
		_move_max = GameConfig.COLUMN_WIDTH - half_width - 6.0
		position.x = lerpf(_move_min, _move_max, float(spec.phase))
		_dir = 1.0 if int(spec.get("row", 0)) % 2 == 0 else -1.0
	if kind == "cloud":
		sprite.modulate = Color(1, 1, 1, 0.93)
	if kind == "spring":
		spring_x = float(spec.spring_x)
		spring_sprite = Sprite2D.new()
		spring_sprite.texture = SPRING_TEX
		spring_sprite.centered = false
		spring_sprite.scale = Vector2(0.46, 0.46)
		spring_sprite.offset = Vector2(-SPRING_TEX.get_width() * 0.5, -SPRING_TEX.get_height())
		spring_sprite.position = Vector2(spring_x, 4)
		spring_sprite.scale.y = 0.32 # resting (compressed)
		add_child(spring_sprite)
	_bob = randf() * TAU

func tick(delta: float) -> void:
	if kind == "moving" and not _dying:
		position.x += _dir * move_speed * delta
		if position.x > _move_max:
			position.x = _move_max
			_dir = -1.0
		elif position.x < _move_min:
			position.x = _move_min
			_dir = 1.0
		_bob += delta * 3.0
		sprite.rotation = sin(_bob) * 0.02
	if kind == "cloud" and not _dying:
		_bob += delta * 1.6
		sprite.position.x = sin(_bob) * 2.0
	if _squash > 0.0:
		_squash = maxf(0.0, _squash - delta * 5.0)
		var k := sin(_squash * PI) * 0.12
		sprite.scale.y = sprite.scale.x * (1.0 - k)
		sprite.position.y = sprite.texture.get_height() * sprite.scale.x * 0.5 - float(TowerData.PLATFORM_KINDS[kind].top) * sprite.scale.x + k * 30.0

func covers(x: float) -> bool:
	return solid and absf(x - position.x) <= half_width

func is_spring_hit(x: float) -> bool:
	return kind == "spring" and absf(x - (position.x + spring_x)) <= 26.0

## React to the cat landing. Returns the launch speed (0 = no bounce).
func land(x: float, fx: FxLayer) -> Dictionary:
	_squash = 1.0
	match kind:
		"biscuit":
			_break(fx)
			return {"speed": 0.0, "event": "crack"}
		"cloud":
			_poof(fx)
			return {"speed": GameConfig.tuned("jump_speed", GameConfig.JUMP_SPEED), "event": "poof"}
		"spring":
			if is_spring_hit(x):
				_spring_anim()
				return {"speed": GameConfig.tuned("spring_speed", GameConfig.SPRING_SPEED), "event": "spring"}
	return {"speed": GameConfig.tuned("jump_speed", GameConfig.JUMP_SPEED), "event": "bounce"}

func _spring_anim() -> void:
	var tw := create_tween()
	tw.tween_property(spring_sprite, "scale:y", 0.58, 0.06).set_trans(Tween.TRANS_BACK)
	tw.tween_property(spring_sprite, "scale:y", 0.40, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _break(fx: FxLayer) -> void:
	solid = false
	_dying = true
	fx.crumbs(global_position + Vector2(0, 6), half_width * 2.0, 16)
	# Split into two halves that tumble away.
	var tex := sprite.texture
	var s := sprite.scale.x
	for side in [-1, 1]:
		var half := Sprite2D.new()
		half.texture = tex
		half.region_enabled = true
		var w := tex.get_width() * 0.5
		half.region_rect = Rect2(0 if side < 0 else w, 0, w, tex.get_height())
		half.scale = Vector2(s, s)
		half.position = sprite.position + Vector2(side * w * s * 0.5, 0)
		add_child(half)
		var tw := half.create_tween().set_parallel(true)
		tw.tween_property(half, "position", half.position + Vector2(side * 40, 260), 0.7).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(half, "rotation", side * 0.9, 0.7)
		tw.tween_property(half, "modulate:a", 0.0, 0.7).set_delay(0.2)
	sprite.visible = false

func _poof(fx: FxLayer) -> void:
	solid = false
	_dying = true
	fx.puff(global_position + Vector2(0, 8), 9, Color(1, 1, 1, 0.95), 90.0, 0.11)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(sprite, "scale", sprite.scale * Vector2(1.25, 0.6), 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.35)
