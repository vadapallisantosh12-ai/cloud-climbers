class_name GameConfig
extends RefCounted
## Every gameplay number lives here. Tower layout, difficulty bands, sky colours
## and milestones are data in `tower_data.gd`. Values marked (tunable) can also be
## adjusted live from the Preview tuning panel through `TuningStore`.

# --- Playfield -------------------------------------------------------------
const COLUMN_WIDTH := 540.0          ## Width of the climbable column in px (wraps at the edges).
const PX_PER_METER := 40.0           ## Converts world px into the metres shown to players.
const START_Y := 0.0                 ## World y of the starting rooftop (upwards is negative y).

# --- Cat movement ------------------------------------------------------------
const GRAVITY := 2000.0              ## (tunable) px/s² pulling the cat down.
const JUMP_SPEED := 1010.0           ## (tunable) Launch speed from a normal platform (apex ≈ 255 px).
const SPRING_SPEED := 1700.0         ## (tunable) Launch speed from a spring.
const STOMP_SPEED := 1080.0          ## Bounce speed after stomping a gloomling.
const MOVE_SPEED := 470.0            ## (tunable) Max horizontal speed.
const MOVE_ACCEL := 4200.0           ## (tunable) Horizontal acceleration while steering.
const MOVE_DECEL := 3200.0           ## Horizontal braking when no input is held.
const MAX_FALL_SPEED := 1400.0       ## Terminal velocity.
const CAT_HALF_WIDTH := 22.0         ## Collision half-width of the feet box.
const CAT_HEIGHT := 64.0             ## Collision height (feet to head).
const COYOTE_PX := 10.0              ## Extra landing tolerance below a platform top.
const MOUSE_DEADZONE := 14.0         ## Mouse steering stops within this many px of the cursor.

# --- Camera ----------------------------------------------------------------
const CAMERA_LEAD := 0.12            ## Cat sits this fraction of screen height below centre.
const CAMERA_FOLLOW := 9.0           ## (tunable) Upward follow sharpness.
const DEATH_MARGIN := 60.0           ## px below the screen bottom before the run ends.

# --- Power-ups -------------------------------------------------------------
const ROCKET_SECONDS := 2.7          ## Rocket flight time.
const ROCKET_SPEED := 1500.0         ## Rocket climb speed px/s.
const ROCKET_EXIT_SPEED := 1250.0    ## Upward speed kept when the rocket burns out.
const SHIELD_SECONDS := 14.0         ## Shield lasts until hit or this timeout.
const MAGNET_SECONDS := 10.0         ## Magnet duration.
const MAGNET_RADIUS := 280.0         ## Fish inside this radius fly to the cat.
const MAGNET_PULL := 1600.0          ## Fish homing speed px/s.
const HIT_GRACE_SECONDS := 1.1       ## Invulnerability after a shield absorbs a hit.
const FISH_FOR_SHIELD := 25          ## Collecting this many fish grants a free shield.

# --- Scoring & pacing ---------------------------------------------------------
const MILESTONE_BANNER_SECONDS := 2.4
const TUTORIAL_HINT_SECONDS := 3.6

# --- Enemies -----------------------------------------------------------------
const ENEMY_RADIUS := 30.0           ## Hit radius of a gloomling.
const ENEMY_STOMP_WINDOW := 26.0     ## Feet must be this close above the enemy centre to stomp.

# --- Feel ------------------------------------------------------------------
const HITSTOP_STOMP := 0.06
const SHAKE_STOMP := 7.0
const SHAKE_HURT := 16.0
const SHAKE_SPRING := 4.0
const SHAKE_ROCKET := 3.0
const SHAKE_MILESTONE := 6.0

# --- Online ------------------------------------------------------------------
const NAME_MAX_CHARS := 16
const LEADERBOARD_RULES := "v1"
const BOARD_ENDLESS := "endless-v1"
const BOARD_DAILY_PREFIX := "daily-v1_"

static func tuned(key: String, fallback: float) -> float:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null:
		return fallback
	var store := loop.root.get_node_or_null("TuningStore")
	if store == null or not store.has_method("has_key") or not store.has_key(key):
		return fallback
	return float(store.get_value(key))

static func meters(world_y: float) -> float:
	return (START_Y - world_y) / PX_PER_METER

static func world_y_for(meters_value: float) -> float:
	return START_Y - meters_value * PX_PER_METER
