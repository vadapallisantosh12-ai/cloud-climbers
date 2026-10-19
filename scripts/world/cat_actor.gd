class_name CatActor
extends Node2D
## Visual side of the hero kitten. Physics lives in game.gd; this node only
## chooses poses and adds squash/stretch, tilt and power-up attachments.
## The node origin is the cat's feet.

const POSES := {
	"idle": preload("res://assets/game/cat/cat_idle.webp"),
	"jump": preload("res://assets/game/cat/cat_jump.webp"),
	"fall": preload("res://assets/game/cat/cat_fall.webp"),
	"crouch": preload("res://assets/game/cat/cat_crouch.webp"),
	"hurt": preload("res://assets/game/cat/cat_hurt.webp"),
	"cheer": preload("res://assets/game/cat/cat_cheer.webp"),
}
const ROCKET_TEX := preload("res://assets/game/items/rocket.webp")
const SHIELD_TEX := preload("res://assets/game/items/shield.webp")
const MAGNET_TEX := preload("res://assets/game/items/magnet.webp")
const DISPLAY_HEIGHT := 90.0

var velocity := Vector2.ZERO
var pose := "idle"
var facing := 1.0
var land_timer := 0.0
var hurt := false
var rocket := false
var shield := false
var magnet := false
var grace := 0.0

var body := Sprite2D.new()
var ghost := Sprite2D.new()
var rocket_sprite := Sprite2D.new()
var shield_sprite := Bubble.new()
var magnet_sprite := Sprite2D.new()
var _t := 0.0
var _base_scale := 1.0
var _spin := 0.0

func _ready() -> void:
	_base_scale = DISPLAY_HEIGHT / POSES.idle.get_height()
	rocket_sprite.texture = ROCKET_TEX
	rocket_sprite.scale = Vector2.ONE * (74.0 / ROCKET_TEX.get_height())
	rocket_sprite.position = Vector2(0, -26)
	rocket_sprite.visible = false
	add_child(rocket_sprite)
	for sprite: Sprite2D in [body, ghost]:
		sprite.centered = false
		add_child(sprite)
	shield_sprite.position = Vector2(0, -44)
	shield_sprite.visible = false
	add_child(shield_sprite)
	magnet_sprite.texture = MAGNET_TEX
	magnet_sprite.scale = Vector2.ONE * (30.0 / MAGNET_TEX.get_width())
	magnet_sprite.position = Vector2(0, -112)
	magnet_sprite.visible = false
	add_child(magnet_sprite)
	set_pose("idle")

func set_pose(value: String) -> void:
	pose = value
	body.texture = POSES[value]
	ghost.texture = body.texture

func reset_visual() -> void:
	velocity = Vector2.ZERO
	hurt = false
	rocket = false
	shield = false
	magnet = false
	grace = 0.0
	_spin = 0.0
	rotation = 0.0
	land_timer = 0.0
	modulate = Color.WHITE
	set_pose("idle")

func landed() -> void:
	land_timer = 0.11

func animate(delta: float, attract: bool) -> void:
	_t += delta
	land_timer = maxf(0.0, land_timer - delta)
	grace = maxf(0.0, grace - delta)
	if absf(velocity.x) > 40.0:
		facing = signf(velocity.x)
	var next := pose
	if attract:
		next = "idle"
	elif hurt:
		next = "hurt"
	elif rocket:
		next = "jump"
	elif land_timer > 0.0:
		next = "crouch"
	elif velocity.y < -120.0:
		next = "jump"
	else:
		next = "fall"
	if next != pose:
		set_pose(next)
	# Squash & stretch.
	var stretch := 1.0
	if attract:
		stretch = 1.0 + sin(_t * 2.2) * 0.02
	elif land_timer > 0.0:
		stretch = 0.84 + (0.11 - land_timer) * 0.9
	elif not hurt:
		stretch = clampf(1.0 + (-velocity.y / 1400.0) * 0.14, 0.92, 1.16)
	var sx := _base_scale / sqrt(stretch)
	var sy := _base_scale * stretch
	var tex_size := body.texture.get_size()
	body.flip_h = facing < 0.0
	body.scale = Vector2(sx, sy)
	body.position = Vector2(-tex_size.x * sx * 0.5, -tex_size.y * sy)
	if hurt:
		_spin += delta * 9.0
		rotation = sin(_spin) * 0.6
	else:
		rotation = lerpf(rotation, clampf(velocity.x / GameConfig.MOVE_SPEED, -1.0, 1.0) * 0.14, 1.0 - exp(-12.0 * delta))
	# Wrap ghost: draw the other half of the cat on the opposite column edge.
	var edge := tex_size.x * sx * 0.5
	ghost.visible = position.x < edge or position.x > GameConfig.COLUMN_WIDTH - edge
	ghost.flip_h = body.flip_h
	ghost.scale = body.scale
	ghost.position = body.position + Vector2(GameConfig.COLUMN_WIDTH if position.x < edge else -GameConfig.COLUMN_WIDTH, 0)
	# Attachments.
	rocket_sprite.visible = rocket
	if rocket:
		rocket_sprite.rotation = sin(_t * 30.0) * 0.04
	shield_sprite.visible = shield
	if shield:
		var wob := 1.0 + sin(_t * 6.0) * 0.04
		shield_sprite.scale = Vector2(wob, 2.0 - wob)
		shield_sprite.rotation = -rotation
	magnet_sprite.visible = magnet
	if magnet:
		magnet_sprite.position = Vector2(sin(_t * 3.0) * 6.0, -112 + cos(_t * 5.0) * 3.0)
	# Blink while invulnerable after a shield pop.
	body.modulate.a = 0.45 if grace > 0.0 and int(_t * 16.0) % 2 == 0 else 1.0


## Soap-bubble shield drawn procedurally so the cat stays readable inside it.
class Bubble extends Node2D:
	var _t := 0.0
	func _process(delta: float) -> void:
		if visible:
			_t += delta
			queue_redraw()
	func _draw() -> void:
		var r := 60.0
		draw_circle(Vector2.ZERO, r, Color(0.7, 0.92, 1.0, 0.16))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.55, 0.85, 1.0, 0.85), 4.0, true)
		draw_arc(Vector2.ZERO, r - 4.0, PI * 1.05 + sin(_t * 2.0) * 0.1, PI * 1.45, 16, Color(1, 1, 1, 0.9), 5.0, true)
		draw_arc(Vector2.ZERO, r - 3.0, _t * 1.3, _t * 1.3 + 0.5, 10, Color(1.0, 0.75, 0.95, 0.6), 3.0, true)
		draw_circle(Vector2(-r * 0.42, -r * 0.5), 6.0, Color(1, 1, 1, 0.85))
