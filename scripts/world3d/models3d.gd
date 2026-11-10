class_name Models3D
extends RefCounted
## Every 3D model in the game, built from simple shapes with MeshKit. One tile = one unit.
## Models face +Z (towards the camera at the default angle) and stand on y = 0.

const EYE := Color("#2b1f22")
const WOOD := Color("#9a6440")
const WOOD_DARK := Color("#6e4126")
const WOOD_LIGHT := Color("#c49262")
const STONE := Color("#9ea8b4")
const STONE_DARK := Color("#7f8996")
const WALL := Color("#f6ead4")
const BEAM := Color("#8a5a3c")
const WINDOW := Color("#ffd98a")
const BLUSH := Color("#ff9aa8")
const LEAF := Color("#57a84a")
const PINE := Color("#3f8f55")

static var _cache := {}


static func _cached(key: String, make: Callable) -> ArrayMesh:
	if not _cache.has(key):
		_cache[key] = make.call()
	return _cache[key]


static func _q(dir: Vector3) -> Basis:
	return Basis(Quaternion(Vector3.UP, dir.normalized()))


## A cone/cylinder pointing along `dir` from `base`.
static func _spike(k: MeshKit, base: Vector3, dir: Vector3, r: float, h: float, col: Color, seg := 8, top := 0.0) -> void:
	var b := _q(dir)
	k.push(Transform3D(b, base + dir.normalized() * h * 0.5))
	k.cyl(Vector3.ZERO, top, r, h, col, seg)
	k.pop()


# ================================================================ pets

static func _pet_cols(species: String, prism: bool) -> Array:
	var sp: Dictionary = Data.SPECIES[species]
	var body := Color(str(sp["body"]))
	var acc := Color(str(sp["accent"]))
	if prism:
		body = PetArt.shift_hue(body, 0.5, 0.25)
		acc = PetArt.shift_hue(acc, 0.5, 0.15)
	return [body, acc]


## A pet, about 1 unit tall at full size, feet on y = 0, face towards +Z (one merged mesh).
static func pet(species: String, prism := false) -> ArrayMesh:
	return _cached("pet_%s_%s" % [species, prism], func(): return _build_pet(species, prism, false)["body"])


## The pet split into parts that animate: {body, lids, ears, tail, wing_l, wing_r} meshes plus
## {ear_pivot, tail_pivot, wing_pivot_l, wing_pivot_r}; each part's mesh is relative to its pivot.
static func pet_parts(species: String, prism := false) -> Dictionary:
	var key := "petparts_%s_%s" % [species, prism]
	if not _cache.has(key):
		_cache[key] = _build_pet(species, prism, true)
	return _cache[key]


static func _part(split: bool, main: MeshKit, pivot: Vector3) -> MeshKit:
	if not split:
		return main
	var k := MeshKit.new()
	k.push(Transform3D(Basis(), -pivot))
	return k


static func _build_pet(species: String, prism: bool, split: bool) -> Dictionary:
	var sp: Dictionary = Data.SPECIES[species]
	var cols := _pet_cols(species, prism)
	var body: Color = cols[0]
	var acc: Color = cols[1]
	var dark := body.darkened(0.28)
	var k := MeshKit.new()
	var r := 0.36
	var cy := r + 0.04
	var whale := species == "sky_whale" or species == "narwhal" or species == "seal"
	var bscale := Vector3(1.05, 0.95, 1.0) if not whale else Vector3(1.0, 0.9, 1.25)
	# feet
	if not whale:
		for fx in [-0.16, 0.16]:
			for fz in [-0.1, 0.14]:
				k.sphere(Vector3(fx, 0.06, fz), Vector3(0.085, 0.06, 0.1), dark, 10)
	else:
		for fx in [-1.0, 1.0]:
			k.sphere(Vector3(fx * 0.3, 0.12, 0.08), Vector3(0.16, 0.04, 0.09), dark, 10, Vector3(0, fx * 25, fx * -20))
	k.sphere(Vector3(0, cy, 0), Vector3(r, r, r) * bscale, body, 22)
	var fz := r * bscale.z # front of the body
	k.sphere(Vector3(0, cy - 0.08, fz * 0.45 + (fz - r) * 0.6), Vector3(0.7, 0.62, 0.55) * r, acc, 18)
	# face
	for sx in [-1.0, 1.0]:
		k.sphere(Vector3(sx * 0.13, cy + 0.07, fz * 0.9), Vector3(0.055, 0.064, 0.035), EYE, 12)
		k.ball(Vector3(sx * 0.13 - 0.018, cy + 0.095, fz * 0.9 + 0.028), 0.02, Color.WHITE, 8)
		k.sphere(Vector3(sx * 0.21, cy - 0.025, fz * 0.8), Vector3(0.05, 0.028, 0.02), BLUSH, 10)
	k.ball(Vector3(0, cy + 0.0, fz * 0.98), 0.03, EYE, 8)
	# eyelids (shown while blinking or asleep)
	var kl := MeshKit.new()
	for sx in [-1.0, 1.0]:
		kl.sphere(Vector3(sx * 0.13, cy + 0.075, fz * 0.9 + 0.006), Vector3(0.064, 0.072, 0.04), body, 12)
		kl.box(Vector3(sx * 0.13, cy + 0.045, fz * 0.9 + 0.045), Vector3(0.08, 0.012, 0.01), EYE)
	var top := cy + r * 0.95
	var ear_pivot := Vector3(0, top - 0.06, 0)
	var main := k
	k = _part(split, main, ear_pivot)
	var ke := k
	# ears
	match str(sp["ears"]):
		"round":
			for sx in [-1.0, 1.0]:
				k.sphere(Vector3(sx * 0.2, top - 0.03, -0.03), Vector3(0.085, 0.085, 0.05), dark, 12)
				k.sphere(Vector3(sx * 0.2, top - 0.03, -0.0), Vector3(0.05, 0.05, 0.03), acc, 10)
		"big":
			for sx in [-1.0, 1.0]:
				k.cone(Vector3(sx * 0.21, top + 0.13, -0.03), 0.15, 0.44, body, 14, Vector3(0, 0, -sx * 22))
				k.cone(Vector3(sx * 0.205, top + 0.1, 0.02), 0.08, 0.3, Color("#ffb3c2"), 10, Vector3(0, 0, -sx * 22))
		"pointy":
			for sx in [-1.0, 1.0]:
				k.cone(Vector3(sx * 0.2, top + 0.04, -0.02), 0.11, 0.24, body, 12, Vector3(0, 0, -sx * 24))
				k.cone(Vector3(sx * 0.195, top + 0.025, 0.02), 0.06, 0.16, acc, 8, Vector3(0, 0, -sx * 24))
		"long":
			for sx in [-1.0, 1.0]:
				k.sphere(Vector3(sx * 0.13, top + 0.2, -0.04), Vector3(0.07, 0.24, 0.05), body, 12, Vector3(-8, 0, -sx * 10))
				k.sphere(Vector3(sx * 0.13, top + 0.2, -0.01), Vector3(0.04, 0.18, 0.03), Color("#ffc4d0"), 10, Vector3(-8, 0, -sx * 10))
		"antenna":
			for sx in [-1.0, 1.0]:
				_spike(k, Vector3(sx * 0.08, top - 0.04, 0.05), Vector3(sx * 0.5, 1, 0.2), 0.015, 0.3, dark, 6, 0.012)
				k.ball(Vector3(sx * 0.08, top - 0.04, 0.05) + Vector3(sx * 0.5, 1, 0.2).normalized() * 0.31, 0.05, acc, 10)
		"gills":
			for sx in [-1.0, 1.0]:
				for i in 3:
					var a := deg_to_rad(-30.0 + i * 30.0)
					var d := Vector3(sx * cos(a), sin(a) + 0.4, -0.1)
					_spike(k, Vector3(sx * 0.26, cy + 0.12, 0.0), d, 0.045, 0.2, body.darkened(0.15), 8, 0.03)
		"crest":
			for i in 3:
				_spike(k, Vector3(0, top - 0.04, 0.05 - i * 0.08), Vector3(0, 1, -0.5 - i * 0.3), 0.05, 0.24 - i * 0.03, acc, 8)
	var tail_pivot := Vector3(0, 0.27, -0.3)
	k = _part(split, main, tail_pivot)
	var kt := k
	# tail (behind = -Z)
	match str(sp["tail"]):
		"puff":
			k.ball(Vector3(0.0, 0.28, -0.38), 0.14, acc.lightened(0.3), 12)
		"striped":
			for i in 4:
				k.cyl(Vector3(0.0, 0.24 + i * 0.03, -0.36 - i * 0.12), 0.1, 0.1, 0.13, body if i % 2 == 0 else body.darkened(0.45), 12, Vector3(80, 0, 0))
		"long":
			_spike(k, Vector3(0, 0.22, -0.3), Vector3(0, 0.35, -1), 0.08, 0.55, body, 10)
		"fin":
			k.sphere(Vector3(0, 0.24, -0.45), Vector3(0.05, 0.08, 0.12), body, 10)
			for sx in [-1.0, 1.0]:
				k.sphere(Vector3(sx * 0.1, 0.3, -0.55), Vector3(0.14, 0.035, 0.08), body.darkened(0.1), 10, Vector3(0, sx * 30, sx * 25))
		"fan":
			for i in 5:
				var a := deg_to_rad(-50.0 + i * 25.0)
				var d := Vector3(sin(a) * 0.8, cos(a), -0.6)
				k.push(Transform3D(_q(d), Vector3(0, 0.3, -0.3) + d.normalized() * 0.25))
				k.sphere(Vector3.ZERO, Vector3(0.09, 0.26, 0.06), body, 10)
				k.sphere(Vector3(0, 0.2, 0), Vector3(0.07, 0.09, 0.05), acc, 8)
				k.pop()
	k = main
	var wl: MeshKit = null
	var wr: MeshKit = null
	var wpl := Vector3(-0.22, cy + 0.1, -0.1)
	var wpr := Vector3(0.22, cy + 0.1, -0.1)
	# extras
	match str(sp["extra"]):
		"spikes":
			for i in 16:
				var a := -PI * 0.95 + i * (PI * 0.9 / 15.0)
				var d := Vector3(cos(a) * 0.9, 0.7 + 0.25 * sin(i * 1.7), sin(a) * 0.85).normalized()
				_spike(k, Vector3(0, cy, 0) + d * r * 0.88, d, 0.055, 0.22, body.darkened(0.35), 6)
		"whiskers":
			for sx in [-1.0, 1.0]:
				for i in 2:
					k.box(Vector3(sx * 0.23, cy - 0.01 + i * 0.035, r * 0.85), Vector3(0.18, 0.008, 0.008), EYE, Vector3(0, -sx * 15, sx * (8 - i * 16)))
		"wings":
			var wc := acc if species != "luna_moth" else acc.lerp(Color("#bfeeb0"), 0.4)
			for sx in [-1.0, 1.0]:
				var kw := _part(split, main, wpl if sx < 0 else wpr)
				kw.sphere(Vector3(sx * 0.36, cy + 0.12, -0.12), Vector3(0.26, 0.04, 0.17), wc, 12, Vector3(0, sx * 20, sx * 35))
				if sx < 0:
					wl = kw
				else:
					wr = kw
		"stripes":
			for sx in [-1.0, 1.0]:
				for i in 3:
					k.sphere(Vector3(sx * 0.31, cy - 0.04, -0.06 - i * 0.09), Vector3(0.06, 0.16, 0.035), Color("#f4eadc"), 8, Vector3(0, sx * 60, 0))
		"tusk":
			_spike(k, Vector3(0, top - 0.06, 0.18), Vector3(0, 1, 0.55), 0.04, 0.5, Color("#f4efe2"), 8)
		"mane":
			for i in 5:
				k.ball(Vector3(0, top - 0.02 - i * 0.05, 0.08 - i * 0.1), 0.07, acc, 10)
		"antlers", "antlers_big":
			var big: bool = sp["extra"] == "antlers_big"
			var ac := acc if big else Color("#d9b98a")
			var s := 1.4 if big else 1.0
			for sx in [-1.0, 1.0]:
				var base := Vector3(sx * 0.1, top - 0.03, -0.02)
				var d1 := Vector3(sx * 0.45, 1, -0.1)
				_spike(k, base, d1, 0.025 * s, 0.32 * s, ac, 6, 0.018 * s)
				var tip := base + d1.normalized() * 0.32 * s
				_spike(k, tip, Vector3(sx * 0.8, 0.8, 0), 0.02 * s, 0.14 * s, ac, 6, 0.01)
				_spike(k, tip, Vector3(-sx * 0.1, 1, 0.2), 0.02 * s, 0.16 * s, ac, 6, 0.01)
				_spike(k, base + d1.normalized() * 0.16 * s, Vector3(sx * 0.2, 0.6, 0.8), 0.018 * s, 0.12 * s, ac, 6, 0.01)
		"spots":
			for d in [Vector3(0.6, 0.6, -0.3), Vector3(-0.5, 0.7, -0.4), Vector3(0.2, 0.9, -0.2), Vector3(-0.75, 0.2, 0.1), Vector3(0.8, 0.1, -0.1), Vector3(0.0, 0.6, -0.8)]:
				var n: Vector3 = d.normalized()
				k.push(Transform3D(_q(n), Vector3(0, cy, 0) + n * r * 0.97))
				k.sphere(Vector3.ZERO, Vector3(0.07, 0.025, 0.07), acc, 10)
				k.pop()
		"horns":
			for sx in [-1.0, 1.0]:
				_spike(k, Vector3(sx * 0.1, top - 0.02, 0.06), Vector3(sx * 0.2, 1, -0.3), 0.04, 0.2, acc, 8)
		"glow":
			k.sphere(Vector3(0, cy + 0.22, r * 0.78), Vector3(0.06, 0.06, 0.02), Color("#ffe58a"), 10)
	var out := {"body": main.commit(), "lids": kl.commit(), "ear_pivot": ear_pivot, "tail_pivot": tail_pivot,
		"wing_pivot_l": wpl, "wing_pivot_r": wpr}
	if split:
		out["ears"] = null if ke.is_empty() else ke.commit()
		out["tail"] = null if kt.is_empty() else kt.commit()
		out["wing_l"] = null if wl == null else wl.commit()
		out["wing_r"] = null if wr == null else wr.commit()
	return out


# ================================================================ tools, eggs

## A tool held upright: handle from y = 0 up to about 0.45.
static func tool(kind: String, tier: int) -> ArrayMesh:
	return _cached("tool_%s_%d" % [kind, tier], func():
		var k := MeshKit.new()
		var tc := Color(str(Data.TIERS[clampi(tier, 0, 2)]["color"]))
		match kind:
			"axe":
				k.cyl(Vector3(0, 0.2, 0), 0.025, 0.025, 0.42, WOOD, 6)
				k.box(Vector3(0.06, 0.38, 0), Vector3(0.12, 0.1, 0.03), tc)
				k.box(Vector3(0.12, 0.38, 0), Vector3(0.03, 0.14, 0.035), tc.lightened(0.25))
			"pickaxe":
				k.cyl(Vector3(0, 0.2, 0), 0.025, 0.025, 0.42, WOOD, 6)
				k.box(Vector3(0, 0.4, 0), Vector3(0.34, 0.05, 0.04), tc, Vector3(0, 0, 0))
				k.cone(Vector3(0.19, 0.39, 0), 0.03, 0.08, tc, 6, Vector3(0, 0, -100))
				k.cone(Vector3(-0.19, 0.39, 0), 0.03, 0.08, tc, 6, Vector3(0, 0, 100))
			"basket":
				k.cyl(Vector3(0, 0.1, 0), 0.13, 0.1, 0.16, tc.lerp(WOOD_LIGHT, 0.5), 12)
				k.torus(Vector3(0, 0.18, 0), 0.1, 0.12, tc.lerp(WOOD, 0.4), Vector3(90, 0, 0), Vector3(1, 1, 1.2))
				for i in 3:
					k.ball(Vector3(-0.05 + i * 0.05, 0.19, 0.0), 0.035, Color("#5b4cf0"), 8)
			"rod":
				k.cyl(Vector3(0, 0.35, 0), 0.012, 0.025, 0.7, tc.lerp(WOOD, 0.5), 6)
				k.ball(Vector3(0.0, 0.7, 0), 0.03, Color("#ef5b5b"), 8)
			"hammer":
				k.cyl(Vector3(0, 0.18, 0), 0.025, 0.025, 0.36, WOOD, 6)
				k.box(Vector3(0, 0.36, 0), Vector3(0.18, 0.09, 0.09), tc)
			"compass":
				k.cyl(Vector3(0, 0.12, 0), 0.11, 0.11, 0.04, Color("#f2c14e"), 16, Vector3(90, 0, 0))
				k.cyl(Vector3(0, 0.12, 0.022), 0.085, 0.085, 0.01, Color("#fff8e6"), 16, Vector3(90, 0, 0))
				k.box(Vector3(0, 0.15, 0.03), Vector3(0.02, 0.07, 0.01), Color("#ef5b5b"))
				k.torus(Vector3(0, 0.12, 0), 0.1, 0.12, tc, Vector3(90, 0, 0))
		return k.commit())


static func egg(egg_type: String) -> ArrayMesh:
	return _cached("egg_" + egg_type, func():
		var info: Dictionary = Data.EGGS.get(egg_type, Data.EGGS["dawn"])
		var k := MeshKit.new()
		k.sphere(Vector3(0, 0.15, 0), Vector3(0.12, 0.155, 0.12), Color(str(info["shell"])), 16)
		var spot := Color(str(info["spots"]))
		for d in [Vector3(0.5, 0.3, 0.8), Vector3(-0.7, -0.1, 0.7), Vector3(0.2, -0.6, 0.8), Vector3(0.8, -0.2, -0.3), Vector3(-0.4, 0.6, -0.6), Vector3(-0.2, 0.2, 1.0)]:
			var n: Vector3 = d.normalized()
			k.push(Transform3D(_q(n), Vector3(0, 0.15, 0) + Vector3(n.x * 0.12, n.y * 0.155, n.z * 0.12)))
			k.sphere(Vector3.ZERO, Vector3(0.028, 0.01, 0.028), spot, 8)
			k.pop()
		return k.commit())


# ================================================================ the Keeper

## The Keeper's look. Every key is optional; missing ones use the default Keeper.
const KEEPER_DEFAULT := {"skin": "#f5d7b8", "hair": "short", "hair_col": "#6b4a32", "outfit": "#3f7f7a",
	"scarf": "#f2a53a", "hat": "leaf_cap", "hat_col": "#7b5cb4", "pants": "#2f4a52"}

const KEEPER_PRESETS := [
	{"name": "Meadow", "skin": "#f5d7b8", "hair": "short", "hair_col": "#6b4a32", "outfit": "#3f7f7a", "scarf": "#f2a53a", "hat": "leaf_cap", "hat_col": "#7b5cb4"},
	{"name": "Harbour", "skin": "#c68a5e", "hair": "curly", "hair_col": "#2b2220", "outfit": "#34508a", "scarf": "#f2d04a", "hat": "bucket", "hat_col": "#f2c84b"},
	{"name": "Ember", "skin": "#eac0a0", "hair": "bob", "hair_col": "#c45a2c", "outfit": "#e8735a", "scarf": "#fff1dc", "hat": "beret", "hat_col": "#8a3b5c"},
	{"name": "Aurora", "skin": "#8d5a3b", "hair": "long", "hair_col": "#3a2a24", "outfit": "#9a7fd0", "scarf": "#9fe3c8", "hat": "flowers", "hat_col": "#ffb3c7"},
	{"name": "Woodland", "skin": "#f0c9a8", "hair": "bun", "hair_col": "#e2b45a", "outfit": "#4f7a3a", "scarf": "#d0503f", "hat": "beanie", "hat_col": "#d0503f"},
	{"name": "Sunny", "skin": "#5e3a26", "hair": "pigtails", "hair_col": "#241a16", "outfit": "#e0a83a", "scarf": "#3f9a8a", "hat": "straw", "hat_col": "#ef6f5e"},
]

const HAIR_STYLES := ["short", "bob", "long", "bun", "curly", "pigtails"]
const HAT_STYLES := ["leaf_cap", "beret", "bucket", "beanie", "straw", "flowers", "none"]


## [body, left leg, right leg]; the body includes arms, scarf, head, hair and hat.
static func keeper_parts(look: Dictionary = {}) -> Array:
	var lk := KEEPER_DEFAULT.duplicate()
	lk.merge(look, true)
	var key := "keeper_" + str(lk)
	if _cache.has(key):
		return _cache[key]
	var cloak := Color(str(lk["outfit"]))
	var skin := Color(str(lk["skin"]))
	var hair := Color(str(lk["hair_col"]))
	var scarf := Color(str(lk["scarf"]))
	var hc := Color(str(lk["hat_col"]))
	var b := MeshKit.new()
	b.capsule(Vector3(0, 0.66, 0), 0.25, 0.78, cloak, Vector3.ZERO)
	b.sphere(Vector3(0, 0.36, 0), Vector3(0.27, 0.08, 0.22), cloak.darkened(0.12), 14)
	for sx in [-1.0, 1.0]:
		b.capsule(Vector3(sx * 0.29, 0.66, 0.02), 0.07, 0.42, cloak.darkened(0.08), Vector3(0, 0, sx * 12))
		b.ball(Vector3(sx * 0.32, 0.45, 0.05), 0.07, skin, 10)
	b.torus(Vector3(0, 1.0, 0), 0.13, 0.23, scarf, Vector3.ZERO, Vector3(1, 1.3, 1))
	b.box(Vector3(0.1, 0.83, 0.2), Vector3(0.1, 0.3, 0.04), scarf, Vector3(0, 0, -8))
	b.ball(Vector3(0, 1.27, 0), 0.24, skin, 20)
	for sx in [-1.0, 1.0]:
		b.sphere(Vector3(sx * 0.085, 1.29, 0.215), Vector3(0.033, 0.04, 0.02), EYE, 10)
		b.ball(Vector3(sx * 0.085 - 0.012, 1.305, 0.232), 0.012, Color.WHITE, 6)
		b.sphere(Vector3(sx * 0.14, 1.22, 0.19), Vector3(0.035, 0.02, 0.012), BLUSH, 8)
	b.sphere(Vector3(0, 1.21, 0.235), Vector3(0.035, 0.02, 0.012), skin.darkened(0.2), 8)
	# hair
	var hs := str(lk["hair"])
	if hs != "curly":
		b.sphere(Vector3(0, 1.33, -0.025), Vector3(0.258, 0.2, 0.255), hair, 18)
		for i in 5:
			b.sphere(Vector3(-0.15 + i * 0.075, 1.4 - absf(i - 2) * 0.012, 0.17), Vector3(0.06, 0.05, 0.045), hair, 8)
	match hs:
		"bob", "long":
			for sx in [-1.0, 1.0]:
				b.sphere(Vector3(sx * 0.21, 1.2, -0.01), Vector3(0.09, 0.16, 0.13), hair, 12)
			b.sphere(Vector3(0, 1.2, -0.12), Vector3(0.23, 0.17, 0.14), hair, 14)
			if hs == "long":
				b.sphere(Vector3(0, 0.98, -0.16), Vector3(0.22, 0.3, 0.1), hair, 14)
		"bun":
			b.ball(Vector3(0, 1.38, -0.24), 0.11, hair, 12)
		"curly":
			for d in [Vector3(0, 1, -0.2), Vector3(0.6, 0.7, -0.3), Vector3(-0.6, 0.7, -0.3), Vector3(0.85, 0.2, -0.2), Vector3(-0.85, 0.2, -0.2), Vector3(0.4, 0.5, -0.8), Vector3(-0.4, 0.5, -0.8), Vector3(0, 0.3, -1), Vector3(0.3, 0.95, 0.3), Vector3(-0.3, 0.95, 0.3), Vector3(0, 0.85, 0.55), Vector3(0.65, 0.65, 0.35), Vector3(-0.65, 0.65, 0.35)]:
				var n: Vector3 = d.normalized()
				b.ball(Vector3(0, 1.28, 0) + n * 0.235, 0.085, hair, 8)
		"pigtails":
			for sx in [-1.0, 1.0]:
				b.ball(Vector3(sx * 0.27, 1.17, -0.06), 0.085, hair, 10)
				b.ball(Vector3(sx * 0.25, 1.23, -0.05), 0.035, scarf, 6)
	# hat
	match str(lk["hat"]):
		"leaf_cap":
			b.cyl(Vector3(0, 1.43, 0), 0.36, 0.36, 0.045, hc.darkened(0.12), 24, Vector3(-6, 0, 0))
			b.sphere(Vector3(0, 1.47, 0), Vector3(0.23, 0.18, 0.23), hc, 18)
			b.cyl(Vector3(0.02, 1.68, 0), 0.015, 0.02, 0.18, Color("#4f8a3a"), 6)
			b.sphere(Vector3(0.1, 1.78, 0), Vector3(0.14, 0.05, 0.08), Color("#7cc85b"), 10, Vector3(0, 0, -30))
		"beret":
			b.sphere(Vector3(0.04, 1.49, -0.02), Vector3(0.28, 0.08, 0.27), hc, 18, Vector3(0, 0, -10))
			b.cyl(Vector3(0.05, 1.58, -0.02), 0.012, 0.02, 0.06, hc.darkened(0.2), 6)
		"bucket":
			b.cyl(Vector3(0, 1.43, 0), 0.27, 0.38, 0.1, hc.darkened(0.08), 24)
			b.cyl(Vector3(0, 1.52, 0), 0.2, 0.25, 0.16, hc, 20)
		"beanie":
			b.sphere(Vector3(0, 1.42, -0.01), Vector3(0.265, 0.24, 0.265), hc, 18)
			b.cyl(Vector3(0, 1.39, 0), 0.27, 0.27, 0.08, hc.darkened(0.15), 20)
			b.ball(Vector3(0, 1.68, -0.02), 0.07, Color("#fff6ea"), 10)
		"straw":
			b.cyl(Vector3(0, 1.44, 0), 0.46, 0.46, 0.035, Color("#e8c77a"), 28, Vector3(-5, 0, 0))
			b.cyl(Vector3(0, 1.53, 0), 0.19, 0.22, 0.16, Color("#e8c77a"), 20)
			b.cyl(Vector3(0, 1.49, 0), 0.225, 0.225, 0.05, hc, 20)
		"flowers":
			var fc := [hc, Color("#fff6ea"), Color("#ffd166"), hc.lightened(0.2), Color("#b48cff")]
			for i in 9:
				var a := TAU * i / 9.0
				b.ball(Vector3(cos(a) * 0.22, 1.47, sin(a) * 0.22), 0.055, fc[i % fc.size()], 8)
			for i in 9:
				var a := TAU * (i + 0.5) / 9.0
				b.sphere(Vector3(cos(a) * 0.23, 1.46, sin(a) * 0.23), Vector3(0.04, 0.015, 0.06), Color("#6cbd5a"), 6, Vector3(0, -rad_to_deg(a), 0))
	var legs := []
	for sx in [-1.0, 1.0]:
		var l := MeshKit.new()
		l.box(Vector3(0, -0.15, 0), Vector3(0.13, 0.3, 0.14), Color(str(lk["pants"])))
		l.sphere(Vector3(0, -0.3, 0.04), Vector3(0.08, 0.05, 0.11), Color("#5a3b2c"), 10)
		legs.append(l.commit())
	var out := [b.commit(), legs[0], legs[1]]
	_cache[key] = out
	return out


# ================================================================ nature

static func nature(name: String) -> ArrayMesh:
	return _cached("n_" + name, func(): return _build_nature(name))


static func _build_nature(name: String) -> ArrayMesh:
	var k := MeshKit.new()
	match name:
		"tree", "tree_bloom":
			k.cyl(Vector3(0, 0.5, 0), 0.12, 0.18, 1.0, Color("#8f5d3b"), 8)
			for b in [[0, 1.55, 0, 0.62], [-0.42, 1.25, 0.1, 0.48], [0.42, 1.3, -0.05, 0.5], [0.05, 1.25, 0.4, 0.45], [-0.05, 1.3, -0.38, 0.45]]:
				k.ball(Vector3(b[0], b[1], b[2]), b[3], LEAF, 12)
			if name == "tree_bloom":
				for d in [Vector3(0.5, 1.5, 0.3), Vector3(-0.45, 1.45, 0.35), Vector3(0.1, 1.95, 0.25), Vector3(-0.2, 1.2, 0.62), Vector3(0.55, 1.15, -0.3), Vector3(-0.6, 1.6, -0.2)]:
					k.ball(d, 0.07, Color("#ffb3c1"), 8)
		"pine":
			k.cyl(Vector3(0, 0.3, 0), 0.1, 0.14, 0.6, Color("#7d5234"), 8)
			for i in 3:
				k.cone(Vector3(0, 0.85 + i * 0.5, 0), 0.8 - i * 0.2, 0.9, PINE.lightened(i * 0.05), 12)
		"stump":
			k.cyl(Vector3(0, 0.14, 0), 0.17, 0.2, 0.28, Color("#9a6440"), 10)
			k.cyl(Vector3(0, 0.285, 0), 0.165, 0.165, 0.02, Color("#e8c99a"), 10)
			for d in [Vector3(0.35, 0.03, 0.1), Vector3(-0.3, 0.03, 0.2), Vector3(0.05, 0.03, -0.35)]:
				k.sphere(d, Vector3(0.06, 0.02, 0.04), Color("#d9b27a"), 6)
		"stump_grow":
			k.cyl(Vector3(0, 0.14, 0), 0.17, 0.2, 0.28, Color("#9a6440"), 10)
			k.cyl(Vector3(0, 0.285, 0), 0.165, 0.165, 0.02, Color("#e8c99a"), 10)
			k.cyl(Vector3(0.32, 0.2, 0.1), 0.02, 0.03, 0.4, Color("#6e4126"), 6)
			k.ball(Vector3(0.32, 0.48, 0.1), 0.17, Color("#6cbd5a"), 10)
		"rock":
			k.sphere(Vector3(0, 0.2, 0), Vector3(0.55, 0.38, 0.45), STONE, 7, Vector3(8, 20, 0))
			k.sphere(Vector3(0.38, 0.1, 0.22), Vector3(0.22, 0.16, 0.2), STONE_DARK, 6, Vector3(0, 40, 10))
		"rubble", "rubble_grow":
			var n := 5 if name == "rubble_grow" else 3
			for i in n:
				k.sphere(Vector3(-0.3 + 0.15 * i, 0.07, 0.1 * ((i % 3) - 1)), Vector3(0.12, 0.08, 0.1) * (1.3 if n == 5 else 1.0), STONE, 6, Vector3(0, i * 37, 0))
		"bush":
			for q in [[-0.25, 0.28, 0, 0.32], [0.25, 0.28, 0, 0.32], [0, 0.45, 0, 0.36], [0, 0.3, 0.2, 0.28]]:
				k.ball(Vector3(q[0], q[1], q[2]), q[3], Color("#4f9e4a"), 12)
			for d in [Vector3(0.3, 0.42, 0.25), Vector3(-0.28, 0.35, 0.28), Vector3(0.05, 0.62, 0.22), Vector3(-0.1, 0.25, 0.45), Vector3(0.42, 0.25, 0.1), Vector3(-0.42, 0.5, 0.0), Vector3(0.15, 0.4, 0.42)]:
				k.ball(d, 0.065, Color("#5b4cf0"), 8)
		"bush_bare", "bush_grow":
			for q in [[-0.2, 0.22, 0, 0.24], [0.2, 0.22, 0, 0.24], [0, 0.34, 0, 0.27]]:
				k.ball(Vector3(q[0], q[1], q[2]), q[3], Color("#7aa864"), 10)
			if name == "bush_grow":
				for d in [Vector3(0.25, 0.32, 0.18), Vector3(-0.2, 0.3, 0.2), Vector3(0.0, 0.52, 0.15)]:
					k.ball(d, 0.05, Color("#b6dd7a"), 8)
		"crystal", "crystal_stub", "crystal_grow":
			k.sphere(Vector3(0, 0.08, 0), Vector3(0.55, 0.2, 0.45), Color("#8a8f96"), 7)
			var hs: Array = {"crystal": [0.75, 1.0, 0.55], "crystal_stub": [0.15, 0.2, 0.12], "crystal_grow": [0.4, 0.5, 0.3]}[name]
			var col := Color("#b48cff") if name != "crystal_stub" else Color("#9c94a8")
			var bases := [Vector3(-0.18, 0.15, 0.05), Vector3(0.1, 0.15, -0.05), Vector3(0.28, 0.12, 0.15)]
			var dirs := [Vector3(-0.3, 1, 0.1), Vector3(0.05, 1, -0.05), Vector3(0.45, 1, 0.2)]
			for i in 3:
				var h: float = hs[i]
				_spike(k, bases[i], dirs[i], 0.12, h, col.lightened(i * 0.12), 6, 0.0)
		"flower":
			k.cyl(Vector3(0, 0.05, 0), 0.008, 0.008, 0.1, Color("#4f9e4a"), 4)
			for i in 5:
				var a := TAU * i / 5.0
				k.sphere(Vector3(cos(a) * 0.045, 0.11, sin(a) * 0.045), Vector3(0.035, 0.015, 0.035), Color.WHITE, 6)
			k.ball(Vector3(0, 0.115, 0), 0.025, Color("#fff2a0"), 6)
		"tuft":
			for i in 3:
				var a := TAU * i / 3.0
				_spike(k, Vector3(cos(a) * 0.04, 0, sin(a) * 0.04), Vector3(cos(a) * 0.3, 1, sin(a) * 0.3), 0.025, 0.2 + 0.04 * i, Color.WHITE, 4)
		"lily":
			k.ellipse(Vector3(0, 0.0, 0), 0.22, 0.22, 0.02, Color("#5fae4f"), 12)
		"reed":
			for i in 4:
				_spike(k, Vector3(0.05 * i - 0.08, 0, 0.03 * (i % 2)), Vector3(0.1 * (i - 1.5), 1, 0), 0.02, 0.6 + 0.1 * (i % 2), Color("#5c9a48"), 4)
			k.capsule(Vector3(-0.02, 0.55, 0.0), 0.03, 0.16, Color("#7a5232"))
	return k.commit()


# ================================================================ buildings

## A finished building, centred on its footprint.
static func building(type: String, variant := 0) -> ArrayMesh:
	return _cached("bld_%s_%d" % [type, variant], func(): return _build_building(type, variant))


static func _cottage(k: MeshKit, w: float, d: float, wall_h: float, roof_col: Color, door_col: Color, roof_h := 1.0) -> void:
	k.box(Vector3(0, 0.09, 0), Vector3(w + 0.15, 0.18, d + 0.15), Color("#a9a39a"))
	k.box(Vector3(0, 0.18 + wall_h / 2.0, 0), Vector3(w, wall_h, d), WALL)
	var fz := d / 2.0 + 0.01
	for x in [-w / 2.0 + 0.05, w / 2.0 - 0.05]:
		k.box(Vector3(x, 0.18 + wall_h / 2.0, fz), Vector3(0.1, wall_h, 0.06), BEAM)
	k.box(Vector3(0, 0.18 + wall_h - 0.04, fz), Vector3(w, 0.1, 0.06), BEAM)
	k.roof(Vector3(0, 0.18 + wall_h, 0), w, d, roof_h, roof_col)
	# door with frame and a step stone
	k.box(Vector3(-w * 0.17, 0.62, fz + 0.005), Vector3(0.58, 0.88, 0.05), BEAM)
	k.box(Vector3(-w * 0.17, 0.6, fz + 0.01), Vector3(0.48, 0.8, 0.06), door_col)
	k.box(Vector3(-w * 0.17, 0.6, fz + 0.045), Vector3(0.42, 0.04, 0.02), door_col.darkened(0.2))
	k.ball(Vector3(-w * 0.17 + 0.14, 0.6, fz + 0.06), 0.035, Color("#f2c14e"), 6)
	k.ellipse(Vector3(-w * 0.17, 0.05, fz + 0.18), 0.3, 0.14, 0.06, STONE, 10)
	# stones along the base
	for i in int(w / 0.3):
		k.box(Vector3(-w / 2.0 + 0.15 + i * 0.3, 0.24, fz + 0.005), Vector3(0.26, 0.1, 0.04), Color("#cfc6b6") if i % 2 == 0 else Color("#bfb6a6"))
	# side windows (seen when the camera turns)
	for sx in [-1.0, 1.0]:
		k.glowing = true
		k.box(Vector3(sx * (w / 2.0 + 0.005), 0.95, 0.0), Vector3(0.05, 0.36, 0.36), WINDOW)
		k.glowing = false
		k.box(Vector3(sx * (w / 2.0 + 0.03), 0.95, 0.0), Vector3(0.04, 0.36, 0.05), BEAM)
		k.box(Vector3(sx * (w / 2.0 + 0.03), 0.76, 0.0), Vector3(0.06, 0.05, 0.46), BEAM)
	# window with flower box
	var wx := w * 0.24
	k.glowing = true
	k.box(Vector3(wx, 0.95, fz + 0.01), Vector3(0.44, 0.4, 0.05), WINDOW)
	k.glowing = false
	k.box(Vector3(wx, 0.95, fz + 0.04), Vector3(0.05, 0.4, 0.05), BEAM)
	k.box(Vector3(wx, 0.95, fz + 0.04), Vector3(0.44, 0.04, 0.05), BEAM)
	for sx in [-1.0, 1.0]:
		k.box(Vector3(wx + sx * 0.29, 0.95, fz + 0.03), Vector3(0.12, 0.44, 0.03), door_col.lightened(0.15))
		for j in 3:
			k.box(Vector3(wx + sx * 0.29, 0.83 + j * 0.12, fz + 0.05), Vector3(0.1, 0.02, 0.01), door_col.darkened(0.1))
	k.box(Vector3(wx, 0.71, fz + 0.06), Vector3(0.54, 0.06, 0.1), BEAM)
	k.box(Vector3(wx, 0.63, fz + 0.1), Vector3(0.54, 0.12, 0.16), Color("#a0673f"))
	var fc := [Color("#ff7a90"), Color("#ffd166"), Color("#ff9ec4"), Color("#ffffff")]
	for i in 4:
		k.ball(Vector3(wx - 0.19 + i * 0.13, 0.72, fz + 0.12), 0.06, fc[i], 8)


static func _chimney(k: MeshKit, p: Vector3) -> void:
	k.box(p, Vector3(0.28, 0.6, 0.28), Color("#b06a4a"))
	k.box(p + Vector3(0, 0.32, 0), Vector3(0.36, 0.08, 0.36), Color("#8e5238"))


static func _sign(k: MeshKit, p: Vector3, icon: Color) -> void:
	k.box(p, Vector3(0.36, 0.36, 0.05), WOOD_LIGHT)
	k.ball(p + Vector3(0, 0, 0.04), 0.1, icon, 10)


static func _build_building(type: String, variant: int) -> ArrayMesh:
	var k := MeshKit.new()
	var roofs := [Color("#3d6cc4"), Color("#7556bf"), Color("#d0603f"), Color("#3f9a8a"), Color("#c9852f")]
	var doors := [Color("#7a5ca8"), Color("#5c7ea8"), Color("#8a5a3c"), Color("#4f8a6a")]
	match type:
		"town_hall":
			_cottage(k, 2.8, 2.2, 1.7, Color("#3d6cc4"), Color("#7a5ca8"), 1.2)
			# clock tower
			k.box(Vector3(0, 2.6, 0.1), Vector3(0.9, 1.6, 0.9), WALL)
			k.glowing = true
			k.cyl(Vector3(0, 3.0, 0.56), 0.28, 0.28, 0.04, Color("#fffaf0"), 20, Vector3(90, 0, 0))
			k.glowing = false
			k.box(Vector3(0, 3.06, 0.59), Vector3(0.03, 0.18, 0.02), EYE)
			k.box(Vector3(0.05, 3.0, 0.59), Vector3(0.12, 0.03, 0.02), EYE)
			k.cone(Vector3(0, 3.75, 0.1), 0.68, 0.75, Color("#2f57a8"), 4, Vector3(0, 45, 0))
			for i in 3:
				var x := -0.6 + i * 0.6
				k.cyl(Vector3(x, 2.3, 1.05), 0.015, 0.015, 0.5, BEAM, 4)
				k.box(Vector3(x + 0.1, 2.48, 1.05), Vector3(0.2, 0.12, 0.01), Color("#ff8a4c"))
			# steps
			k.box(Vector3(-0.48, 0.1, 1.3), Vector3(0.8, 0.12, 0.3), STONE)
		"house":
			_cottage(k, 1.7, 1.5, 1.2, roofs[variant % roofs.size()], doors[variant % doors.size()], 0.9)
			_chimney(k, Vector3(0.45, 2.0, -0.2))
		"nest":
			k.torus(Vector3(0, 0.16, 0), 0.5, 0.82, Color("#b08453"), Vector3.ZERO, Vector3(1, 0.9, 1))
			k.ellipse(Vector3(0, 0.08, 0), 0.62, 0.62, 0.08, Color("#d9b27a"), 24)
			for i in 10:
				var a := TAU * i / 10.0
				k.box(Vector3(cos(a) * 0.82, 0.25, sin(a) * 0.82), Vector3(0.3, 0.03, 0.04), Color("#e1c48d"), Vector3(0, -rad_to_deg(a) + 70, 15))
		"kiosk", "market":
			var striped := Color("#ef6f5e") if type == "kiosk" else Color("#4f9ee8")
			k.box(Vector3(0, 0.38, 0.1), Vector3(1.7, 0.75, 0.7), Color("#c48a5a"))
			k.box(Vector3(0, 0.78, 0.1), Vector3(1.8, 0.08, 0.8), Color("#a86f45"))
			for x in [-0.82, 0.82]:
				for z in [-0.3, 0.45]:
					k.cyl(Vector3(x, 0.85, z), 0.045, 0.045, 1.7, BEAM, 6)
			for i in 7:
				k.box(Vector3(-0.78 + i * 0.26, 1.78, 0.2), Vector3(0.26, 0.05, 1.2), striped if i % 2 == 0 else Color("#fff6ea"), Vector3(22, 0, 0))
			if type == "kiosk":
				var ec := [Color("#d9f5c0"), Color("#cdeefa"), Color("#ffd9c2"), Color("#e7dcff")]
				for i in 4:
					k.sphere(Vector3(-0.54 + i * 0.36, 0.95, 0.2), Vector3(0.1, 0.13, 0.1), ec[i], 12)
			else:
				var cc := [Color("#5b4cf0"), Color("#aab4be"), Color("#c08a55"), Color("#3fa9d6")]
				for i in 4:
					k.box(Vector3(-0.54 + i * 0.36, 0.9, 0.2), Vector3(0.3, 0.16, 0.3), Color("#b98552"))
					for j in 3:
						k.ball(Vector3(-0.6 + i * 0.36 + j * 0.06, 1.0, 0.18 + (j % 2) * 0.06), 0.06, cc[i], 8)
		"builder_hut":
			_cottage(k, 1.6, 1.3, 1.0, Color("#c9852f"), Color("#8a5a3c"), 0.8)
			_sign(k, Vector3(0.45, 1.05, 0.72), Color("#9aa3ad"))
			for i in 3:
				k.cyl(Vector3(0.95, 0.12 + i * 0.0, -0.4 + i * 0.25), 0.11, 0.11, 0.7, WOOD, 8, Vector3(90, 0, 0))
			k.cyl(Vector3(0.95, 0.32, -0.27), 0.11, 0.11, 0.7, WOOD_LIGHT, 8, Vector3(90, 0, 0))
		"storehouse":
			k.box(Vector3(0, 0.08, 0), Vector3(1.9, 0.16, 1.7), Color("#a9a39a"))
			k.box(Vector3(0, 0.75, 0), Vector3(1.75, 1.2, 1.55), Color("#c4553f"))
			k.roof(Vector3(0, 1.35, 0), 1.75, 1.55, 0.85, Color("#6b4a3a"))
			k.box(Vector3(0, 0.62, 0.79), Vector3(0.8, 0.95, 0.05), Color("#fff3e0"))
			k.box(Vector3(0, 0.62, 0.81), Vector3(0.7, 0.85, 0.04), Color("#a8432f"))
			k.box(Vector3(0, 0.62, 0.84), Vector3(0.9, 0.06, 0.03), Color("#fff3e0"), Vector3(0, 0, 50))
			k.box(Vector3(0, 0.62, 0.84), Vector3(0.9, 0.06, 0.03), Color("#fff3e0"), Vector3(0, 0, -50))
			k.glowing = true
			k.box(Vector3(0, 1.55, 0.79), Vector3(0.3, 0.3, 0.05), WINDOW)
			k.glowing = false
			k.box(Vector3(-0.7, 0.2, 0.95), Vector3(0.35, 0.35, 0.35), WOOD_LIGHT, Vector3(0, 15, 0))
		"lumber_camp":
			k.box(Vector3(0, 0.05, 0), Vector3(1.8, 0.1, 1.6), Color("#c6a77a"))
			for x in [-0.75, 0.75]:
				for z in [-0.6, 0.6]:
					k.cyl(Vector3(x, 0.65, z), 0.06, 0.06, 1.3, WOOD_DARK, 6)
			k.roof(Vector3(0, 1.3, 0), 1.6, 1.4, 0.45, Color("#5f8f4a"))
			for i in 3:
				for j in 3 - i:
					k.cyl(Vector3(-0.3 + j * 0.24 + i * 0.12, 0.22 + i * 0.2, -0.3), 0.11, 0.11, 0.9, WOOD if (i + j) % 2 == 0 else WOOD_LIGHT, 8, Vector3(90, 0, 0))
			k.cyl(Vector3(0.45, 0.2, 0.45), 0.22, 0.24, 0.3, WOOD, 10)
			k.cyl(Vector3(0.45, 0.355, 0.45), 0.215, 0.215, 0.02, Color("#e8c99a"), 10)
			k.cyl(Vector3(0.52, 0.5, 0.45), 0.02, 0.02, 0.35, WOOD_DARK, 4, Vector3(0, 0, -25))
			k.box(Vector3(0.6, 0.63, 0.45), Vector3(0.12, 0.08, 0.02), Color("#c0c6cc"), Vector3(0, 0, -25))
		"berry_farm":
			k.box(Vector3(0, 0.05, 0), Vector3(1.85, 0.1, 1.75), Color("#8a6a44"))
			for row in 2:
				var z := -0.4 + row * 0.8
				k.box(Vector3(0, 0.18, z), Vector3(1.6, 0.25, 0.55), Color("#a0673f"))
				k.box(Vector3(0, 0.3, z), Vector3(1.5, 0.04, 0.45), Color("#5a3e2b"))
				for i in 3:
					var x := -0.5 + i * 0.5
					k.ball(Vector3(x, 0.48, z), 0.25, Color("#4f9e4a"), 10)
					for j in 4:
						var a := TAU * j / 4.0 + i
						k.ball(Vector3(x + cos(a) * 0.18, 0.52 + 0.06 * (j % 2), z + sin(a) * 0.14 + 0.06), 0.055, Color("#5b4cf0"), 6)
		"quarry":
			k.ellipse(Vector3(0, 0.04, 0.1), 0.95, 0.85, 0.08, Color("#9a8f80"), 20)
			k.ellipse(Vector3(0, 0.06, 0.1), 0.62, 0.55, 0.06, Color("#5e5850"), 20)
			for d in [Vector3(-0.7, 0.18, -0.5), Vector3(0.75, 0.15, -0.35), Vector3(0.6, 0.12, 0.65), Vector3(-0.8, 0.12, 0.5)]:
				k.sphere(d, Vector3(0.25, 0.2, 0.22), STONE, 7, Vector3(0, d.x * 90, 10))
			# pulley frame
			k.cyl(Vector3(-0.55, 0.75, -0.2), 0.05, 0.05, 1.5, WOOD_DARK, 6, Vector3(0, 0, -12))
			k.cyl(Vector3(0.1, 1.45, -0.2), 0.04, 0.04, 1.3, WOOD_DARK, 6, Vector3(0, 0, 80))
			k.cyl(Vector3(0.45, 1.05, -0.2), 0.008, 0.008, 0.75, EYE, 4)
			k.box(Vector3(0.45, 0.62, -0.2), Vector3(0.22, 0.16, 0.22), STONE_DARK)
			k.box(Vector3(0.3, 0.12, 0.25), Vector3(0.3, 0.2, 0.3), STONE)
			k.box(Vector3(0.62, 0.12, 0.3), Vector3(0.25, 0.2, 0.25), STONE)
		"workshop":
			_cottage(k, 1.8, 1.5, 1.15, Color("#6b6f8a"), Color("#8a5a3c"), 0.85)
			_chimney(k, Vector3(-0.5, 1.95, -0.2))
			# gear sign
			k.cyl(Vector3(0.55, 1.62, 0.78), 0.22, 0.22, 0.06, Color("#c0c6cc"), 10, Vector3(90, 0, 0))
			k.cyl(Vector3(0.55, 1.62, 0.82), 0.08, 0.08, 0.04, Color("#6b6f8a"), 10, Vector3(90, 0, 0))
			k.box(Vector3(0.95, 0.35, 0.55), Vector3(0.35, 0.22, 0.2), Color("#4a4a55"))
			k.box(Vector3(0.95, 0.15, 0.55), Vector3(0.15, 0.2, 0.15), Color("#4a4a55"))
		"fishing_dock":
			for i in 6:
				k.box(Vector3(-0.75 + i * 0.3, 0.12, 0.2), Vector3(0.28, 0.06, 1.6), WOOD_LIGHT if i % 2 == 0 else WOOD)
			for x in [-0.8, 0.8]:
				for z in [-0.5, 0.9]:
					k.cyl(Vector3(x, 0.0, z), 0.06, 0.06, 0.5, WOOD_DARK, 6)
			k.box(Vector3(0, 0.6, -0.45), Vector3(1.0, 0.9, 0.6), Color("#cfe6f2"))
			k.roof(Vector3(0, 1.05, -0.45), 1.0, 0.6, 0.45, Color("#3f8ec4"))
			k.box(Vector3(0.6, 0.35, 0.6), Vector3(0.3, 0.3, 0.3), WOOD)
			k.box(Vector3(-0.55, 0.6, 0.45), Vector3(0.04, 0.9, 0.04), WOOD_DARK)
			k.box(Vector3(-0.55, 1.0, 0.45), Vector3(0.5, 0.03, 0.03), WOOD_DARK)
			for i in 3:
				k.sphere(Vector3(-0.72 + i * 0.17, 0.85, 0.45), Vector3(0.05, 0.12, 0.03), Color("#7fb7d6"), 8)
		"explorer_lodge":
			k.box(Vector3(0, 0.05, 0), Vector3(1.8, 0.1, 1.6), Color("#c6a77a"))
			k.cone(Vector3(0, 0.85, -0.05), 0.95, 1.6, Color("#d9b06a"), 6)
			k.cone(Vector3(0, 0.55, 0.62), 0.3, 0.9, Color("#5a3e2b"), 3, Vector3(0, 0, 0))
			k.cyl(Vector3(0, 1.85, -0.05), 0.02, 0.02, 0.5, WOOD_DARK, 4)
			k.box(Vector3(0.14, 2.0, -0.05), Vector3(0.28, 0.16, 0.01), Color("#ef5b5b"))
			# map board
			k.box(Vector3(0.75, 0.6, 0.55), Vector3(0.05, 0.9, 0.05), WOOD_DARK)
			k.box(Vector3(0.75, 0.95, 0.58), Vector3(0.5, 0.4, 0.03), Color("#f3e3bf"))
			k.box(Vector3(0.75, 0.95, 0.6), Vector3(0.2, 0.02, 0.01), Color("#ef5b5b"), Vector3(0, 0, 30))
			k.box(Vector3(-0.7, 0.2, 0.6), Vector3(0.35, 0.3, 0.25), Color("#8a6a44"))
		"crystal_mine":
			k.sphere(Vector3(0, 0.3, -0.2), Vector3(1.0, 0.8, 0.8), Color("#8a8f96"), 9)
			k.box(Vector3(0, 0.45, 0.5), Vector3(0.75, 0.9, 0.2), Color("#2a2730"))
			k.box(Vector3(-0.38, 0.45, 0.58), Vector3(0.1, 0.95, 0.12), WOOD)
			k.box(Vector3(0.38, 0.45, 0.58), Vector3(0.1, 0.95, 0.12), WOOD)
			k.box(Vector3(0, 0.93, 0.58), Vector3(0.9, 0.1, 0.14), WOOD)
			for i in 3:
				_spike(k, Vector3(-0.6 + i * 0.55, 0.65 + (i % 2) * 0.2, -0.3), Vector3(-0.3 + i * 0.3, 1, 0.1), 0.1, 0.45, Color("#b48cff").lightened(i * 0.1), 6)
			k.box(Vector3(0.75, 0.15, 0.7), Vector3(0.4, 0.2, 0.3), WOOD)
			k.ball(Vector3(0.7, 0.3, 0.7), 0.1, Color("#c58cff"), 8)
		"path":
			k.box(Vector3(0, 0.02, 0), Vector3(0.98, 0.04, 0.98), Color("#cdbb94"))
			for d in [Vector3(-0.22, 0.05, -0.2), Vector3(0.22, 0.05, -0.18), Vector3(-0.2, 0.05, 0.22), Vector3(0.2, 0.05, 0.2)]:
				k.ellipse(d, 0.18, 0.16, 0.04, Color("#e3d6b4"), 8)
		"flower_bed":
			k.box(Vector3(0, 0.1, 0), Vector3(0.85, 0.2, 0.85), Color("#a0673f"))
			k.box(Vector3(0, 0.2, 0), Vector3(0.75, 0.02, 0.75), Color("#5a3e2b"))
			var fc2 := [Color("#ff7a90"), Color("#ffd166"), Color("#ff9ec4"), Color("#b48cff"), Color("#ffffff")]
			for i in 9:
				var p := Vector3(-0.25 + (i % 3) * 0.25, 0.3, -0.25 + (i / 3) * 0.25)
				k.cyl(p - Vector3(0, 0.05, 0), 0.01, 0.01, 0.1, Color("#4f9e4a"), 4)
				k.ball(p + Vector3(0, 0.03, 0), 0.07, fc2[i % 5], 8)
		"sapling":
			k.cyl(Vector3(0, 0.3, 0), 0.05, 0.07, 0.6, Color("#8f5d3b"), 6)
			k.ball(Vector3(0, 0.75, 0), 0.32, Color("#6cbd5a"), 12)
			k.ball(Vector3(0.2, 0.6, 0.1), 0.2, Color("#79c962"), 10)
			k.ellipse(Vector3(0, 0.02, 0), 0.3, 0.3, 0.04, Color("#7a5a3c"), 12)
		"lamp":
			k.cyl(Vector3(0, 0.08, 0), 0.14, 0.16, 0.16, Color("#4a4a5a"), 8)
			k.cyl(Vector3(0, 0.9, 0), 0.04, 0.06, 1.6, Color("#4a4a5a"), 8)
			k.glowing = true
			k.box(Vector3(0, 1.78, 0), Vector3(0.24, 0.28, 0.24), Color("#ffe39a"))
			k.glowing = false
			k.cone(Vector3(0, 1.98, 0), 0.22, 0.14, Color("#4a4a5a"), 4, Vector3(0, 45, 0))
		"fountain":
			k.cyl(Vector3(0, 0.22, 0), 0.9, 0.98, 0.44, STONE, 28)
			k.cyl(Vector3(0, 0.42, 0), 0.78, 0.78, 0.04, Color("#6cc6ea"), 28)
			k.cyl(Vector3(0, 0.75, 0), 0.16, 0.22, 0.8, Color("#c4ccd5"), 12)
			k.cyl(Vector3(0, 1.15, 0), 0.4, 0.3, 0.12, STONE, 16)
			k.ball(Vector3(0, 1.3, 0), 0.14, Color("#8fd8f5"), 10)
		"statue":
			k.box(Vector3(0, 0.25, 0), Vector3(1.3, 0.5, 1.3), STONE_DARK)
			k.box(Vector3(0, 0.55, 0), Vector3(1.1, 0.1, 1.1), STONE)
			k.push(MeshKit.xform(Vector3(0, 0.6, 0), Vector3.ZERO, Vector3(1.6, 1.6, 1.6)))
			k.sphere(Vector3(0, 0.4, 0), Vector3(0.38, 0.36, 0.36), Color("#d5dbe2"), 18)
			for sx in [-1.0, 1.0]:
				k.cone(Vector3(sx * 0.2, 0.86, -0.02), 0.11, 0.24, Color("#d5dbe2"), 10, Vector3(0, 0, -sx * 24))
				k.ball(Vector3(sx * 0.13, 0.47, 0.33), 0.04, Color("#9aa3ad"), 8)
			k.ball(Vector3(0.0, 0.28, -0.38), 0.14, Color("#d5dbe2"), 10)
			k.pop()
			k.ball(Vector3(0.5, 0.7, 0.5), 0.08, Color("#c58cff"), 8)
		_:
			k.box(Vector3(0, 0.5, 0), Vector3(1.6, 1.0, 1.6), WALL)
	_details(k, type, variant)
	return k.commit()


# ---------------------------------------------------------------- small props

static func _barrel(k: MeshKit, p: Vector3, s := 1.0) -> void:
	k.cyl(p + Vector3(0, 0.18 * s, 0), 0.13 * s, 0.13 * s, 0.36 * s, WOOD, 12)
	k.cyl(p + Vector3(0, 0.18 * s, 0), 0.145 * s, 0.145 * s, 0.2 * s, WOOD_LIGHT, 12)
	for y in [0.06, 0.3]:
		k.cyl(p + Vector3(0, y * s, 0), 0.14 * s, 0.14 * s, 0.03 * s, Color("#5a4a40"), 12)


static func _crate(k: MeshKit, p: Vector3, s := 1.0, rot := 0.0) -> void:
	k.push(MeshKit.xform(p + Vector3(0, 0.15 * s, 0), Vector3(0, rot, 0)))
	k.box(Vector3.ZERO, Vector3(0.3, 0.3, 0.3) * s, WOOD_LIGHT)
	for sx in [-1.0, 1.0]:
		k.box(Vector3(0, 0, sx * 0.152 * s), Vector3(0.3 * s, 0.05 * s, 0.01), WOOD)
		k.box(Vector3(sx * 0.152 * s, 0, 0), Vector3(0.01, 0.05 * s, 0.3 * s), WOOD)
		k.box(Vector3(0, 0, sx * 0.152 * s), Vector3(0.05 * s, 0.3 * s, 0.01), WOOD)
	k.pop()


static func _sack(k: MeshKit, p: Vector3, col := Color("#e2cfa2")) -> void:
	k.sphere(p + Vector3(0, 0.13, 0), Vector3(0.13, 0.14, 0.11), col, 10)
	k.cyl(p + Vector3(0, 0.27, 0), 0.03, 0.05, 0.06, col.darkened(0.15), 8)


## A small lantern that glows at night.
static func _lantern(k: MeshKit, p: Vector3) -> void:
	k.box(p + Vector3(0, 0.1, 0), Vector3(0.12, 0.03, 0.12), Color("#4a4a5a"))
	k.cyl(p + Vector3(0, 0.15, 0), 0.008, 0.008, 0.08, Color("#4a4a5a"), 4)
	k.glowing = true
	k.box(p, Vector3(0.09, 0.15, 0.09), Color("#ffe39a"))
	k.glowing = false
	k.box(p - Vector3(0, 0.09, 0), Vector3(0.11, 0.03, 0.11), Color("#4a4a5a"))


static func _pot(k: MeshKit, p: Vector3, flower: Color) -> void:
	k.cyl(p + Vector3(0, 0.09, 0), 0.11, 0.08, 0.18, Color("#c0714a"), 10)
	k.ball(p + Vector3(0, 0.24, 0), 0.11, Color("#4f9e4a"), 10)
	for i in 3:
		var a := TAU * i / 3.0
		k.ball(p + Vector3(cos(a) * 0.06, 0.31, sin(a) * 0.06), 0.045, flower, 6)


static func _bench(k: MeshKit, p: Vector3, rot := 0.0) -> void:
	k.push(MeshKit.xform(p, Vector3(0, rot, 0)))
	k.box(Vector3(0, 0.2, 0), Vector3(0.6, 0.04, 0.2), WOOD_LIGHT)
	k.box(Vector3(0, 0.36, -0.09), Vector3(0.6, 0.12, 0.03), WOOD_LIGHT)
	for sx in [-1.0, 1.0]:
		k.box(Vector3(sx * 0.25, 0.1, 0), Vector3(0.04, 0.2, 0.18), WOOD_DARK)
	k.pop()


static func _fence(k: MeshKit, a: Vector3, b: Vector3) -> void:
	var n := maxi(1, int(a.distance_to(b) / 0.3))
	for i in n + 1:
		k.box(a.lerp(b, float(i) / n) + Vector3(0, 0.15, 0), Vector3(0.05, 0.3, 0.05), WOOD_LIGHT)
	var mid := (a + b) / 2.0
	var ang := rad_to_deg(atan2(b.x - a.x, b.z - a.z)) - 90.0
	for y in [0.12, 0.24]:
		k.box(mid + Vector3(0, y, 0), Vector3(a.distance_to(b), 0.03, 0.02), WOOD, Vector3(0, ang, 0))


static func _hay(k: MeshKit, p: Vector3) -> void:
	k.cyl(p + Vector3(0, 0.14, 0), 0.14, 0.14, 0.34, Color("#e6c46a"), 12, Vector3(0, 0, 90))
	k.cyl(p + Vector3(0, 0.14, 0), 0.145, 0.145, 0.03, Color("#c9a24a"), 12, Vector3(0, 0, 90))


## Extra props that make each building feel lived in (all inside the footprint).
static func _details(k: MeshKit, type: String, variant: int) -> void:
	var flowers := [Color("#ff7a90"), Color("#ffd166"), Color("#b48cff"), Color("#ffffff"), Color("#ff9e5e")]
	match type:
		"town_hall":
			_lantern(k, Vector3(-0.85, 1.05, 1.2))
			_lantern(k, Vector3(-0.1, 1.05, 1.2))
			_pot(k, Vector3(-1.25, 0.0, 1.3), flowers[0])
			_pot(k, Vector3(0.3, 0.0, 1.3), flowers[1])
			_bench(k, Vector3(0.95, 0.0, 1.32))
			for sx in [-1.0, 1.0]:
				k.glowing = true
				k.box(Vector3(sx * 0.456, 2.55, 0.1), Vector3(0.03, 0.4, 0.22), WINDOW)
				k.glowing = false
			k.box(Vector3(0, 3.4, 0.1), Vector3(0.98, 0.07, 0.98), BEAM)
			k.box(Vector3(0, 1.98, 0.1), Vector3(0.98, 0.07, 0.98), BEAM)
		"house":
			_pot(k, Vector3(-0.83, 0.0, 0.86), flowers[variant % flowers.size()])
			match variant % 3:
				0:
					_barrel(k, Vector3(0.8, 0.0, 0.85), 0.8)
				1:
					_bench(k, Vector3(0.55, 0.0, 0.9))
				2:
					k.cyl(Vector3(0.82, 0.35, 0.86), 0.025, 0.025, 0.7, WOOD_DARK, 6)
					k.box(Vector3(0.82, 0.72, 0.86), Vector3(0.16, 0.12, 0.22), Color("#4f7fd6"))
			_lantern(k, Vector3(0.0, 1.05, 0.82))
		"builder_hut":
			_crate(k, Vector3(-0.72, 0.0, 0.82), 0.9, 15)
			_crate(k, Vector3(-0.72, 0.27, 0.82), 0.7, 40)
			k.box(Vector3(0.3, 0.04, 0.86), Vector3(0.7, 0.05, 0.12), WOOD_LIGHT, Vector3(0, 8, 0))
			k.box(Vector3(0.3, 0.09, 0.86), Vector3(0.7, 0.05, 0.12), WOOD, Vector3(0, -4, 0))
		"storehouse":
			_hay(k, Vector3(0.68, 0.0, 0.92))
			_hay(k, Vector3(0.68, 0.27, 0.92))
			_sack(k, Vector3(-0.32, 0.0, 0.95))
			_sack(k, Vector3(0.36, 0.0, 0.95), Color("#d6c08e"))
			_lantern(k, Vector3(0.0, 1.25, 0.85))
		"lumber_camp":
			for sx in [-1.0, 1.0]:
				k.box(Vector3(-0.35 + sx * 0.25, 0.18, 0.55), Vector3(0.04, 0.36, 0.25), WOOD_DARK, Vector3(0, 0, sx * 12))
			k.cyl(Vector3(-0.35, 0.4, 0.55), 0.1, 0.1, 0.8, WOOD_LIGHT, 8, Vector3(0, 0, 90))
			k.box(Vector3(-0.2, 0.55, 0.55), Vector3(0.36, 0.08, 0.01), Color("#c0c6cc"), Vector3(0, 0, -20))
			_lantern(k, Vector3(0.75, 1.0, 0.68))
		"berry_farm":
			_fence(k, Vector3(-0.9, 0, 0.9), Vector3(-0.3, 0, 0.9))
			_fence(k, Vector3(0.3, 0, 0.9), Vector3(0.9, 0, 0.9))
			_fence(k, Vector3(-0.9, 0, -0.9), Vector3(0.9, 0, -0.9))
			# scarecrow between the rows
			k.cyl(Vector3(0.82, 0.45, 0.0), 0.025, 0.025, 0.9, WOOD_DARK, 6)
			k.box(Vector3(0.82, 0.7, 0.0), Vector3(0.03, 0.03, 0.5), WOOD_DARK)
			k.sphere(Vector3(0.82, 0.62, 0.0), Vector3(0.08, 0.16, 0.12), Color("#d0503f"), 10)
			k.ball(Vector3(0.82, 0.9, 0.0), 0.1, Color("#f2dfb0"), 10)
			k.cyl(Vector3(0.82, 0.98, 0.0), 0.16, 0.16, 0.02, Color("#e8c77a"), 12)
			k.cyl(Vector3(0.82, 1.03, 0.0), 0.08, 0.09, 0.08, Color("#e8c77a"), 10)
			# watering can
			k.cyl(Vector3(-0.8, 0.09, 0.0), 0.07, 0.07, 0.16, Color("#5ea0c8"), 10)
			k.cyl(Vector3(-0.7, 0.14, 0.0), 0.012, 0.02, 0.15, Color("#5ea0c8"), 6, Vector3(0, 0, -55))
		"quarry":
			# a cart of stone
			k.box(Vector3(-0.15, 0.24, 0.8), Vector3(0.45, 0.2, 0.28), WOOD)
			for sx in [-1.0, 1.0]:
				k.cyl(Vector3(-0.15 + sx * 0.15, 0.1, 0.8), 0.1, 0.1, 0.32, WOOD_DARK, 10, Vector3(90, 0, 0))
			for i in 3:
				k.sphere(Vector3(-0.26 + i * 0.11, 0.38, 0.8), Vector3(0.07, 0.06, 0.07), STONE, 6)
			k.box(Vector3(0.15, 0.12, -0.8), Vector3(0.25, 0.22, 0.25), STONE_DARK)
			k.box(Vector3(0.15, 0.32, -0.8), Vector3(0.22, 0.18, 0.22), STONE)
		"workshop":
			_crate(k, Vector3(-0.75, 0.0, 0.88), 0.8, 10)
			_barrel(k, Vector3(-0.92, 0.0, 0.45), 0.75)
			_lantern(k, Vector3(0.01, 1.05, 0.83))
		"kiosk", "market":
			_lantern(k, Vector3(-0.72, 1.45, 0.45))
			_lantern(k, Vector3(0.72, 1.45, 0.45))
			if type == "market":
				_sack(k, Vector3(-0.85, 0.0, 0.85))
				_barrel(k, Vector3(0.85, 0.0, 0.82), 0.75)
			else:
				_pot(k, Vector3(0.85, 0.0, 0.82), flowers[2])
				_pot(k, Vector3(-0.85, 0.0, 0.82), flowers[0])
		"fishing_dock":
			_barrel(k, Vector3(-0.75, 0.15, 0.85), 0.7)
			k.cyl(Vector3(0.82, 0.35, 0.95), 0.02, 0.02, 0.5, WOOD_DARK, 4)
			_lantern(k, Vector3(0.82, 0.68, 0.95))
			# a coiled net
			k.torus(Vector3(0.15, 0.18, 0.75), 0.06, 0.16, Color("#d8cfae"), Vector3.ZERO, Vector3(1, 0.5, 1))
			k.torus(Vector3(0.15, 0.21, 0.75), 0.04, 0.12, Color("#c9bf9a"), Vector3.ZERO, Vector3(1, 0.5, 1))
		"explorer_lodge":
			_lantern(k, Vector3(0.75, 1.27, 0.55))
			k.sphere(Vector3(0.32, 0.15, 0.82), Vector3(0.13, 0.16, 0.1), Color("#5f8f4a"), 10)
			k.box(Vector3(0.32, 0.12, 0.91), Vector3(0.14, 0.1, 0.03), Color("#4a7a3a"))
		"crystal_mine":
			for sx in [-1.0, 1.0]:
				k.box(Vector3(sx * 0.15, 0.04, 0.8), Vector3(0.03, 0.03, 0.42), Color("#7a7f88"))
			for i in 3:
				k.box(Vector3(0, 0.02, 0.66 + i * 0.13), Vector3(0.42, 0.02, 0.05), WOOD_DARK)
			_lantern(k, Vector3(0.5, 0.78, 0.66))
		"nest":
			for i in 6:
				var a := TAU * i / 6.0 + 0.3
				k.box(Vector3(cos(a) * 0.93, 0.02, sin(a) * 0.93), Vector3(0.18, 0.015, 0.03), Color("#e1c48d"), Vector3(0, rad_to_deg(a) * 1.7, 0))
		"fountain":
			for i in 8:
				var a := TAU * i / 8.0
				k.box(Vector3(cos(a) * 0.94, 0.45, sin(a) * 0.94), Vector3(0.22, 0.05, 0.14), STONE.lightened(0.1), Vector3(0, -rad_to_deg(a), 0))



## The wooden frame around a building that's still being put up.
static func scaffold(size: Vector2i) -> ArrayMesh:
	return _cached("scaf_%d_%d" % [size.x, size.y], func():
		var k := MeshKit.new()
		var w := size.x * 0.92
		var d := size.y * 0.92
		var h := 1.4 if size.x > 1 else 0.7
		k.box(Vector3(0, 0.05, 0), Vector3(w, 0.1, d), Color("#c6a77a"))
		for x in [-w / 2.0, w / 2.0]:
			for z in [-d / 2.0, d / 2.0]:
				k.cyl(Vector3(x, h / 2.0, z), 0.04, 0.04, h, WOOD_LIGHT, 6)
		for z in [-d / 2.0, d / 2.0]:
			k.box(Vector3(0, h * 0.6, z), Vector3(w, 0.06, 0.06), WOOD_LIGHT)
			k.box(Vector3(0, h * 0.6, z), Vector3(w * 1.15, 0.05, 0.05), WOOD, Vector3(0, 0, 25))
		for x in [-w / 2.0, w / 2.0]:
			k.box(Vector3(x, h * 0.6, 0), Vector3(0.06, 0.06, d), WOOD_LIGHT)
		if size.x > 1:
			k.box(Vector3(w * 0.3, 0.18, d * 0.55), Vector3(0.3, 0.3, 0.3), WOOD_LIGHT, Vector3(0, 20, 0))
			k.cyl(Vector3(-w * 0.3, 0.12, d * 0.6), 0.09, 0.09, 0.6, WOOD, 8, Vector3(90, 70, 0))
		return k.commit())
