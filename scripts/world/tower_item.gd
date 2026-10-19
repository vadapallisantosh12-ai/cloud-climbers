class_name TowerItem
extends Node2D
## A floating collectible: fish treat or one of the power-ups.

const TEXTURES := {
	"fish": preload("res://assets/game/items/fish.webp"),
	"rocket": preload("res://assets/game/items/rocket.webp"),
	"shield": preload("res://assets/game/items/shield.webp"),
	"magnet": preload("res://assets/game/items/magnet.webp"),
}
const DISPLAY_HEIGHT := {"fish": 26.0, "rocket": 60.0, "shield": 52.0, "magnet": 50.0}

var kind := "fish"
var radius := 22.0
var collected := false
var homing := false
var sprite := Sprite2D.new()
var _t := 0.0
var _base := Vector2.ZERO

func setup(item_kind: String, pos: Vector2) -> void:
	kind = item_kind
	var tex: Texture2D = TEXTURES[kind]
	sprite.texture = tex
	var s := float(DISPLAY_HEIGHT[kind]) / tex.get_height()
	sprite.scale = Vector2(s, s)
	add_child(sprite)
	position = pos
	_base = pos
	radius = 20.0 if kind == "fish" else 34.0
	_t = randf() * TAU
	if kind != "fish":
		queue_redraw()

func tick(delta: float) -> void:
	_t += delta
	if not homing:
		position.y = _base.y + sin(_t * 3.0) * (3.0 if kind == "fish" else 6.0)
	if kind == "fish":
		sprite.scale.x = absf(sprite.scale.y) * (0.75 + 0.25 * cos(_t * 4.0))
	else:
		sprite.rotation = sin(_t * 2.2) * 0.08
		queue_redraw()

func _draw() -> void:
	if kind == "fish":
		return
	# Soft halo ring so power-ups read clearly against any sky colour.
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	draw_circle(Vector2.ZERO, 40.0 + pulse * 4.0, Color(1, 0.97, 0.8, 0.22 + pulse * 0.1))
	draw_arc(Vector2.ZERO, 42.0 + pulse * 4.0, 0, TAU, 40, Color(1, 1, 1, 0.55), 2.5, true)
