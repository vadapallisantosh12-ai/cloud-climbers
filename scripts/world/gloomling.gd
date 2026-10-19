class_name Gloomling
extends Node2D
## A grumpy storm-cloud critter that patrols across the column.
## Stomp it from above; touching it from the side or below hurts.

const TEX := preload("res://assets/game/enemies/gloomling.webp")
const DISPLAY_WIDTH := 84.0

var speed := 90.0
var alive := true
var sprite := Sprite2D.new()
var _dir := 1.0
var _t := 0.0
var _base_y := 0.0
var _scale := 1.0

func setup(spec: Dictionary, speed_multiplier: float) -> void:
	sprite.texture = TEX
	_scale = DISPLAY_WIDTH / TEX.get_width()
	sprite.scale = Vector2(_scale, _scale)
	add_child(sprite)
	position = Vector2(float(spec.x), float(spec.y))
	_base_y = position.y
	speed = float(spec.speed) * speed_multiplier
	_t = float(spec.phase)
	_dir = 1.0 if sin(_t) >= 0.0 else -1.0

func tick(delta: float) -> void:
	if not alive:
		return
	_t += delta
	position.x += _dir * speed * delta
	var margin := DISPLAY_WIDTH * 0.5
	if position.x > GameConfig.COLUMN_WIDTH - margin:
		position.x = GameConfig.COLUMN_WIDTH - margin
		_dir = -1.0
	elif position.x < margin:
		position.x = margin
		_dir = 1.0
	position.y = _base_y + sin(_t * 2.4) * 14.0
	sprite.flip_h = _dir < 0.0
	# Wing flap: quick vertical squash; mood wobble.
	sprite.scale = Vector2(_scale * (1.0 + sin(_t * 14.0) * 0.05), _scale * (1.0 - sin(_t * 14.0) * 0.07))
	sprite.rotation = sin(_t * 3.0) * 0.08

## Knocked out: spin and drop away.
func defeat(from_x: float) -> void:
	alive = false
	var away := 1.0 if position.x >= from_x else -1.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position", position + Vector2(away * 90.0, 420.0), 0.8).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tw.tween_property(sprite, "rotation", away * 6.0, 0.8)
	tw.tween_property(sprite, "scale", sprite.scale * Vector2(1.2, 0.5), 0.12)
	tw.tween_property(self, "modulate:a", 0.0, 0.5).set_delay(0.3)
	tw.chain().tween_callback(queue_free)
