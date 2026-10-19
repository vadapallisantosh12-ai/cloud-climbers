class_name TowerData
extends RefCounted
## Data that describes the tower. Edit these tables to remix the climb:
## no generator code has to change to add a band, re-weight platforms,
## recolour the sky or add a milestone.

## Platform kinds. `path_safe` kinds may form the guaranteed route upward;
## others are only placed as decoys next to it.
const PLATFORM_KINDS := {
	"grass":   {"texture": "res://assets/game/platforms/platform_grass.webp",   "width": 132.0, "top": 12.0, "path_safe": true},
	"moving":  {"texture": "res://assets/game/platforms/platform_winged.webp",  "width": 126.0, "top": 8.0,  "path_safe": true},
	"cloud":   {"texture": "res://assets/game/platforms/platform_cloud.webp",   "width": 128.0, "top": 12.0, "path_safe": true},
	"spring":  {"texture": "res://assets/game/platforms/platform_grass.webp",   "width": 132.0, "top": 12.0, "path_safe": true},
	"biscuit": {"texture": "res://assets/game/platforms/platform_biscuit.webp", "width": 128.0, "top": 8.0,  "path_safe": false},
}

## Difficulty bands, chosen by the metres at which a row is generated.
## gap: vertical px between route platforms (must stay below the ≈255 px jump apex).
## reach: max horizontal px between consecutive route platforms.
## route: weights for the route platform kind. decoy: chance of an extra
## platform per row and the weights of its kind. width: platform scale range.
## move_speed: winged platform speed px/s. enemy: chance per row of a gloomling.
## pickup: chance per row of a power-up. fish: chance per row of a fish trail.
const BANDS := [
	{"from": 0,    "gap": [74, 112],  "reach": 200, "width": [1.05, 1.2],
	 "route": {"grass": 86, "moving": 6, "spring": 8},
	 "decoy": 0.28, "decoy_kinds": {"grass": 70, "biscuit": 30},
	 "move_speed": [60, 90], "enemy": 0.0, "pickup": 0.05, "fish": 0.34},
	{"from": 120,  "gap": [92, 140],  "reach": 220, "width": [0.95, 1.1],
	 "route": {"grass": 64, "moving": 16, "cloud": 10, "spring": 10},
	 "decoy": 0.36, "decoy_kinds": {"grass": 40, "biscuit": 60},
	 "move_speed": [70, 110], "enemy": 0.035, "pickup": 0.055, "fish": 0.32},
	{"from": 350,  "gap": [110, 165], "reach": 235, "width": [0.9, 1.02],
	 "route": {"grass": 48, "moving": 24, "cloud": 18, "spring": 10},
	 "decoy": 0.42, "decoy_kinds": {"grass": 30, "biscuit": 70},
	 "move_speed": [90, 140], "enemy": 0.06, "pickup": 0.06, "fish": 0.3},
	{"from": 650,  "gap": [128, 188], "reach": 245, "width": [0.84, 0.96],
	 "route": {"grass": 38, "moving": 30, "cloud": 22, "spring": 10},
	 "decoy": 0.46, "decoy_kinds": {"grass": 25, "biscuit": 75},
	 "move_speed": [110, 170], "enemy": 0.085, "pickup": 0.06, "fish": 0.28},
	{"from": 1000, "gap": [145, 205], "reach": 250, "width": [0.78, 0.9],
	 "route": {"grass": 30, "moving": 34, "cloud": 26, "spring": 10},
	 "decoy": 0.5, "decoy_kinds": {"grass": 20, "biscuit": 80},
	 "move_speed": [130, 200], "enemy": 0.11, "pickup": 0.065, "fish": 0.26},
	{"from": 1500, "gap": [160, 218], "reach": 255, "width": [0.72, 0.84],
	 "route": {"grass": 24, "moving": 38, "cloud": 30, "spring": 8},
	 "decoy": 0.5, "decoy_kinds": {"grass": 15, "biscuit": 85},
	 "move_speed": [150, 230], "enemy": 0.13, "pickup": 0.07, "fish": 0.24},
]

## Power-up weights (rolled when a row gets a pickup).
const PICKUP_WEIGHTS := {"rocket": 26, "shield": 38, "magnet": 36}
## No pickup or enemy is generated below this height so the opening stays calm.
const SAFE_START_METERS := 25.0
## Minimum metres between two gloomlings.
const ENEMY_SPACING_METERS := 22.0

## Sky gradient keyframes by metres: top colour, horizon colour, star alpha,
## world tint (applied to platforms and actors so they sit in the light).
const SKY := [
	{"m": 0,    "top": Color("7cc8f2"), "bottom": Color("dff4ff"), "stars": 0.0,  "tint": Color("ffffff"), "cloud": Color("ffffff")},
	{"m": 250,  "top": Color("5fb2ec"), "bottom": Color("fdf3d8"), "stars": 0.0,  "tint": Color("fffaf0"), "cloud": Color("fffdf6")},
	{"m": 520,  "top": Color("f09a7c"), "bottom": Color("ffd58f"), "stars": 0.0,  "tint": Color("ffe7cf"), "cloud": Color("ffd7c4")},
	{"m": 780,  "top": Color("6a4f9c"), "bottom": Color("f39a9a"), "stars": 0.35, "tint": Color("e6d4f0"), "cloud": Color("d6b3d8")},
	{"m": 1050, "top": Color("1a2150"), "bottom": Color("4a4b8f"), "stars": 0.85, "tint": Color("c9d0f2"), "cloud": Color("7f86c0")},
	{"m": 1500, "top": Color("0a0c24"), "bottom": Color("2a1d5a"), "stars": 1.0,  "tint": Color("c4c8f0"), "cloud": Color("4b4a86")},
]

## Milestones: celebrated once per run. `name` is a localization key.
const MILESTONES := [
	{"m": 100,  "name": "milestone.chimneys"},
	{"m": 250,  "name": "milestone.kites"},
	{"m": 500,  "name": "milestone.sunset"},
	{"m": 750,  "name": "milestone.twilight"},
	{"m": 1000, "name": "milestone.stars"},
	{"m": 1500, "name": "milestone.moon"},
	{"m": 2000, "name": "milestone.comets"},
	{"m": 3000, "name": "milestone.legend"},
]

static func band_for(meters: float) -> Dictionary:
	var chosen: Dictionary = BANDS[0]
	for band: Dictionary in BANDS:
		if meters >= float(band.from):
			chosen = band
	return chosen

static func sky_at(meters: float) -> Dictionary:
	if meters <= float(SKY[0].m):
		return SKY[0]
	for index in range(1, SKY.size()):
		var next: Dictionary = SKY[index]
		if meters < float(next.m):
			var prev: Dictionary = SKY[index - 1]
			var t := smoothstep(float(prev.m), float(next.m), meters)
			return {
				"top": (prev.top as Color).lerp(next.top, t),
				"bottom": (prev.bottom as Color).lerp(next.bottom, t),
				"stars": lerpf(prev.stars, next.stars, t),
				"tint": (prev.tint as Color).lerp(next.tint, t),
				"cloud": (prev.cloud as Color).lerp(next.cloud, t),
			}
	return SKY[SKY.size() - 1]

static func next_milestone(meters: float) -> Dictionary:
	for milestone: Dictionary in MILESTONES:
		if float(milestone.m) > meters:
			return milestone
	return {}

static func weighted_pick(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total := 0.0
	for key: String in weights:
		total += float(weights[key])
	var roll := rng.randf() * total
	for key: String in weights:
		roll -= float(weights[key])
		if roll <= 0.0:
			return key
	return String(weights.keys()[0])
