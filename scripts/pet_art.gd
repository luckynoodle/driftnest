class_name PetArt
extends RefCounted
## Procedural drawing for creatures and eggs — no image assets needed.
## Shapes are defined in "unit space" (body radius ≈ 1) and mapped through a Transform2D,
## so the same art works in the world, in HUD cards and mirrored when facing left.

const SEG := 24
const INK := Color("#2b2230")


static func _ellipse_pts(xf: Transform2D, c: Vector2, r: Vector2, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in SEG:
		var a := TAU * float(i) / float(SEG)
		pts.append(xf * (Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot) + c))
	return pts


static func ell(ci: CanvasItem, xf: Transform2D, c: Vector2, r: Vector2, col: Color, rot: float = 0.0) -> void:
	ci.draw_colored_polygon(_ellipse_pts(xf, c, r, rot), col)


static func circ(ci: CanvasItem, xf: Transform2D, c: Vector2, r: float, col: Color) -> void:
	ell(ci, xf, c, Vector2(r, r), col)


static func tri(ci: CanvasItem, xf: Transform2D, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([xf * a, xf * b, xf * c]), col)


static func line(ci: CanvasItem, xf: Transform2D, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	ci.draw_line(xf * a, xf * b, col, maxf(1.0, w * absf(xf.get_scale().y)), true)


static func shift_hue(c: Color, amount: float, sat_boost: float = 0.2) -> Color:
	return Color.from_hsv(fposmod(c.h + amount, 1.0), clampf(c.s + sat_boost, 0.0, 1.0), clampf(c.v + 0.05, 0.0, 1.0), c.a)


## Draws a creature. `pos` is the body centre; `size` is the body radius at level 1.
static func draw_pet(ci: CanvasItem, pos: Vector2, species_id: String, level: int, prism: bool,
		t: float, size: float, facing: float = 1.0, silhouette: bool = false) -> void:
	if not Data.SPECIES.has(species_id):
		return
	var sp: Dictionary = Data.SPECIES[species_id]
	var body := Color(str(sp["body"]))
	var acc := Color(str(sp["accent"]))
	if prism:
		body = shift_hue(body, 0.5, 0.25)
		acc = shift_hue(acc, 0.5, 0.15)
	var dark := body.darkened(0.28)
	var ink := INK
	if silhouette:
		body = Color("#5a5170")
		acc = body
		dark = body
		ink = body
	var lvl := clampi(level, 1, Data.MAX_LEVEL)
	var s := size * Data.stage_scale(lvl)
	var phase := float(species_id.length()) * 0.7
	var bob := sin(t * 3.0 + phase) * 0.05
	var face := 1.0 if facing >= 0.0 else -1.0
	var base := Transform2D(0.0, Vector2(s * face, s), 0.0, pos)
	var xf := Transform2D(0.0, Vector2(s * face, s), 0.0, pos + Vector2(0.0, bob * s))
	var ears: String = sp["ears"]
	var tail: String = sp["tail"]
	var extra: String = sp["extra"]

	# shadow + radiant aura
	if not silhouette:
		ell(ci, base, Vector2(0, 0.95), Vector2(0.95, 0.22), Color(0, 0, 0, 0.16))
		if lvl >= Data.MAX_LEVEL or extra == "glow":
			var pulse := 0.5 + 0.5 * sin(t * 2.5)
			circ(ci, xf, Vector2(0, -0.05), 1.55 + 0.08 * pulse, Color(acc, 0.18 + 0.1 * pulse))
			circ(ci, xf, Vector2(0, -0.05), 1.3, Color(acc, 0.16))

	# --- behind the body: tail, wings, mane, spikes, ears, antlers
	match tail:
		"puff":
			circ(ci, xf, Vector2(-0.95, 0.25), 0.34, acc)
		"long":
			var wag := sin(t * 4.0 + phase) * 0.15
			line(ci, xf, Vector2(-0.7, 0.35), Vector2(-1.25, 0.15 + wag), body, 0.22)
			line(ci, xf, Vector2(-1.25, 0.15 + wag), Vector2(-1.6, -0.25 + wag), body, 0.18)
			circ(ci, xf, Vector2(-1.6, -0.25 + wag), 0.09, body)
		"striped":
			var wag2 := sin(t * 3.0 + phase) * 0.1
			ell(ci, xf, Vector2(-1.15, 0.05), Vector2(0.62, 0.32), body, -0.4 + wag2)
			for k in 3:
				var c := Vector2(-0.85 - 0.22 * k, 0.17 - 0.09 * k)
				ell(ci, xf, c, Vector2(0.06, 0.28), dark if not silhouette else body, -0.4 + wag2)
		"fin":
			var flick := sin(t * 5.0 + phase) * 0.12
			tri(ci, xf, Vector2(-0.75, 0.25), Vector2(-1.45, -0.25 + flick), Vector2(-1.35, 0.7 + flick), acc)
		"fan":
			var n := 3
			if species_id == "kitsune":
				n = 1 + (lvl - 1) * 2 # grows extra tails: 1,3,5,7,9
			var root := Vector2(-0.75, 0.2)
			for k in n:
				var ang := 0.0 if n == 1 else lerpf(-0.9, 0.9, float(k) / float(n - 1))
				ang += sin(t * 2.0 + k) * 0.06
				var dir := Vector2(-1, 0).rotated(ang)
				ell(ci, xf, root + dir * 0.55, Vector2(0.55, 0.2), body, ang)
				circ(ci, xf, root + dir * 1.0, 0.15, acc)

	if extra == "wings":
		var flap := sin(t * 7.0 + phase) * 0.25
		var wing_col := Color(acc, 0.9) if species_id != "thunderbird" else dark
		ell(ci, xf, Vector2(-0.45, -0.55), Vector2(0.75, 0.38), wing_col, -0.7 + flap)
		ell(ci, xf, Vector2(0.05, -0.75), Vector2(0.65, 0.32), Color(wing_col, wing_col.a * 0.85), -1.1 - flap)
		if species_id == "luna_moth" and not silhouette:
			circ(ci, xf, Vector2(-0.55, -0.62), 0.12, Color("#ffd27a"))
	if extra == "mane":
		for k in 5:
			circ(ci, xf, Vector2(-0.55 + 0.22 * k, -0.78 + 0.03 * k * k * 0.3), 0.24, acc)
	if extra == "spikes":
		for k in 7:
			var a := lerpf(PI * 0.95, PI * 1.7, float(k) / 6.0)
			var p := Vector2(cos(a), sin(a) * 0.85)
			tri(ci, xf, p * 0.8 + p.orthogonal() * 0.18, p * 1.35, p * 0.8 - p.orthogonal() * 0.18, dark)

	match ears:
		"round":
			circ(ci, xf, Vector2(-0.35, -0.78), 0.27, body)
			circ(ci, xf, Vector2(0.45, -0.78), 0.27, body)
			circ(ci, xf, Vector2(-0.35, -0.78), 0.14, acc)
			circ(ci, xf, Vector2(0.45, -0.78), 0.14, acc)
		"pointy":
			tri(ci, xf, Vector2(-0.6, -0.55), Vector2(-0.38, -1.38), Vector2(-0.05, -0.68), body)
			tri(ci, xf, Vector2(0.15, -0.68), Vector2(0.5, -1.38), Vector2(0.72, -0.55), body)
			tri(ci, xf, Vector2(-0.45, -0.68), Vector2(-0.36, -1.12), Vector2(-0.18, -0.72), acc)
			tri(ci, xf, Vector2(0.3, -0.72), Vector2(0.5, -1.12), Vector2(0.58, -0.68), acc)
		"big":
			tri(ci, xf, Vector2(-0.75, -0.45), Vector2(-0.7, -1.6), Vector2(0.0, -0.75), body)
			tri(ci, xf, Vector2(0.2, -0.75), Vector2(0.95, -1.6), Vector2(0.95, -0.45), body)
			tri(ci, xf, Vector2(-0.6, -0.6), Vector2(-0.62, -1.3), Vector2(-0.18, -0.78), acc)
			tri(ci, xf, Vector2(0.38, -0.78), Vector2(0.86, -1.3), Vector2(0.82, -0.6), acc)
		"long":
			var flop := sin(t * 2.0 + phase) * 0.08
			ell(ci, xf, Vector2(-0.28, -1.2), Vector2(0.2, 0.58), body, -0.18 + flop)
			ell(ci, xf, Vector2(0.38, -1.2), Vector2(0.2, 0.58), body, 0.18 - flop)
			ell(ci, xf, Vector2(-0.28, -1.15), Vector2(0.09, 0.42), acc, -0.18 + flop)
			ell(ci, xf, Vector2(0.38, -1.15), Vector2(0.09, 0.42), acc, 0.18 - flop)
		"gills":
			var gill := Color("#ff6f9a") if not silhouette else body
			if prism:
				gill = shift_hue(gill, 0.5)
			for side: float in [-1.0, 1.0]:
				var cx := 0.2 + 0.85 * side
				for k in 3:
					var a := -PI / 2.0 + side * (0.5 + 0.35 * k)
					var tip := Vector2(cx, -0.25) + Vector2(cos(a), sin(a)) * 0.45
					line(ci, xf, Vector2(cx * 0.8, -0.25), tip, gill, 0.12)
					circ(ci, xf, tip, 0.08, gill)
		"antenna":
			line(ci, xf, Vector2(-0.05, -0.8), Vector2(-0.35, -1.5), ink, 0.07)
			line(ci, xf, Vector2(0.45, -0.8), Vector2(0.65, -1.5), ink, 0.07)
			circ(ci, xf, Vector2(-0.35, -1.5), 0.11, acc)
			circ(ci, xf, Vector2(0.65, -1.5), 0.11, acc)
		"crest":
			for k in 3:
				var bx := -0.25 + 0.3 * k
				tri(ci, xf, Vector2(bx - 0.15, -0.75), Vector2(bx - 0.05, -1.45 + 0.1 * k), Vector2(bx + 0.15, -0.8), acc)

	if extra == "antlers" or extra == "antlers_big":
		var big := extra == "antlers_big"
		var ac := Color("#7a5a3c") if not big else acc
		if silhouette:
			ac = body
		var h := 1.5 if big else 1.0
		for side: float in [-1.0, 1.0]:
			var bx := 0.18 + 0.28 * side
			var top := Vector2(bx + 0.25 * side, -0.75 - 0.75 * h)
			line(ci, xf, Vector2(bx, -0.75), top, ac, 0.09)
			line(ci, xf, Vector2(bx + 0.12 * side, -0.75 - 0.35 * h), Vector2(bx + 0.45 * side, -0.85 - 0.45 * h), ac, 0.07)
			if big:
				line(ci, xf, Vector2(bx + 0.2 * side, -0.75 - 0.6 * h), Vector2(bx - 0.05 * side, -0.85 - 0.85 * h), ac, 0.06)
				if not silhouette:
					circ(ci, xf, top, 0.08, Color(1, 1, 1, 0.8))
	if extra == "horns":
		tri(ci, xf, Vector2(0.05, -0.8), Vector2(0.0, -1.3), Vector2(0.2, -0.82), acc)
		tri(ci, xf, Vector2(0.35, -0.82), Vector2(0.5, -1.3), Vector2(0.5, -0.78), acc)

	# --- body
	circ(ci, xf, Vector2(-0.35, 0.78), 0.2, dark)
	circ(ci, xf, Vector2(0.4, 0.8), 0.2, dark)
	ell(ci, xf, Vector2.ZERO, Vector2(1.0, 0.86), body)
	ell(ci, xf, Vector2(0.18, 0.28), Vector2(0.58, 0.48), acc)

	if not silhouette:
		match extra:
			"stripes":
				for k in 3:
					ell(ci, xf, Vector2(-0.75 + 0.18 * k, 0.15), Vector2(0.06, 0.32), acc, 0.15)
			"spots":
				for p in [Vector2(-0.5, -0.35), Vector2(-0.1, -0.55), Vector2(-0.7, 0.2), Vector2(0.5, -0.5)]:
					circ(ci, xf, p, 0.13, acc)
		# face
		var blink := fmod(t + phase, 4.2) < 0.13
		for ex: float in [0.22, 0.66]:
			var ep := Vector2(ex, -0.14)
			if blink:
				line(ci, xf, ep + Vector2(-0.1, 0), ep + Vector2(0.1, 0), ink, 0.05)
			else:
				circ(ci, xf, ep, 0.12, ink)
				circ(ci, xf, ep + Vector2(-0.035, -0.045), 0.045, Color.WHITE)
		circ(ci, xf, Vector2(0.08, 0.08), 0.1, Color(1.0, 0.45, 0.55, 0.35))
		circ(ci, xf, Vector2(0.84, 0.08), 0.1, Color(1.0, 0.45, 0.55, 0.35))
		tri(ci, xf, Vector2(0.39, 0.0), Vector2(0.49, 0.0), Vector2(0.44, 0.07), ink)
		if extra == "whiskers":
			for k in 2:
				line(ci, xf, Vector2(0.62, 0.06 + 0.07 * k), Vector2(1.05, 0.0 + 0.12 * k), Color(ink, 0.6), 0.025)
		if extra == "tusk":
			line(ci, xf, Vector2(0.85, -0.05), Vector2(1.9, -0.55), Color("#fff8e6"), 0.09)
			for k in 4:
				var p := Vector2(0.85, -0.05).lerp(Vector2(1.9, -0.55), 0.2 + 0.2 * k)
				circ(ci, xf, p, 0.035, Color("#d9cbb0"))
		# level ornaments
		if lvl >= 4:
			for k in 3:
				var a := t * 1.5 + TAU * k / 3.0
				circ(ci, xf, Vector2(cos(a) * 1.25, -0.2 + sin(a) * 0.4), 0.06, Color(1.0, 0.95, 0.6, 0.9))
		if lvl >= Data.MAX_LEVEL:
			var halo_y := -1.35 if ears in ["none", "round", "gills"] else -1.75
			ci.draw_arc(xf * Vector2(0.18, halo_y), 0.35 * s, 0.0, TAU, 32, Color("#ffe27a"), maxf(2.0, 0.08 * s), true)
		if prism:
			for k in 4:
				var a2 := t * 0.8 + k * 1.7
				var sp2 := Vector2(cos(a2 * 1.3) * 1.2, sin(a2) * 1.0 - 0.2)
				var tw := 0.5 + 0.5 * sin(t * 5.0 + k)
				_sparkle(ci, xf * sp2, 0.12 * s * (0.5 + tw), Color(1, 1, 1, 0.9))


static func _sparkle(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * i / 8.0
		var rr := r if i % 2 == 0 else r * 0.3
		pts.append(p + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, col)


## Draws an egg centred at `pos`; `warmth` 0..1 makes it glow, wobble and crack.
static func draw_egg(ci: CanvasItem, pos: Vector2, egg_type: String, size: float, t: float,
		warmth: float = 0.0, with_shadow: bool = true) -> void:
	var info: Dictionary = Data.EGGS.get(egg_type, Data.EGGS["dawn"])
	var shell := Color(str(info["shell"]))
	var spot := Color(str(info["spots"]))
	var wob := 0.0
	if warmth > 0.6:
		wob = sin(t * 18.0) * 0.14 * (warmth - 0.6) / 0.4
	var base := Transform2D(0.0, Vector2(size, size), 0.0, pos)
	var xf := Transform2D(wob, Vector2(size, size), 0.0, pos)
	if with_shadow:
		ell(ci, base, Vector2(0, 0.92), Vector2(0.7, 0.16), Color(0, 0, 0, 0.16))
	if warmth > 0.05:
		circ(ci, base, Vector2(0, 0), 1.25 + 0.05 * sin(t * 4.0), Color(1.0, 0.8, 0.4, 0.28 * warmth))
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * float(i) / 32.0
		pts.append(xf * Vector2(cos(a) * 0.72 * (1.0 + 0.16 * sin(a)), sin(a) * 0.95))
	ci.draw_colored_polygon(pts, shell)
	for sp in [[Vector2(-0.25, -0.3), 0.14], [Vector2(0.3, 0.05), 0.18], [Vector2(-0.12, 0.45), 0.12], [Vector2(0.18, -0.6), 0.09], [Vector2(0.38, 0.5), 0.08]]:
		circ(ci, xf, sp[0], sp[1], spot)
	ell(ci, xf, Vector2(-0.32, -0.42), Vector2(0.09, 0.2), Color(1, 1, 1, 0.65), 0.3)
	if warmth > 0.85:
		var cr := Color(0.25, 0.18, 0.15, 0.8)
		var zig := [Vector2(-0.6, -0.05), Vector2(-0.35, -0.2), Vector2(-0.15, 0.0), Vector2(0.1, -0.22), Vector2(0.3, 0.0), Vector2(0.55, -0.15)]
		for i in zig.size() - 1:
			line(ci, xf, zig[i], zig[i + 1], cr, 0.05)
