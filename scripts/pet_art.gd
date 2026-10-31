class_name PetArt
extends RefCounted
## Storybook-3D drawing toolkit + creatures, eggs and tool icons. No image assets.
##
## Every shape is lit from the top-left: vertex colours fade from a warm highlight on the
## lit side to a cool shade on the far side, then get a soft ink outline, a specular dot
## and (for characters) a rim light. Shadows are soft blobs from one shared gradient texture
## and are cast towards the bottom-right.
##
## Creature shapes live in "unit space" (body radius ~ 1) and are mapped through a
## Transform2D, so the same art works in the world, in HUD cards and mirrored when facing left.

const SEG := 28
const INK := Color("#3b2a2a")
const LIGHT := Vector2(-0.55, -0.83) # direction *towards* the sun
const HILITE := Color(1.0, 0.97, 0.86)
const COOL := Color(0.22, 0.28, 0.48)
const SHADOW := Color(0.11, 0.22, 0.32)
const CAST_DIR := Vector2(0.86, 0.5)

static var _soft_tex: Texture2D
static var _fan_idx: Dictionary = {}
## When true (animated characters), outlines use a fast centroid-scaling method instead of
## polygon offsetting. Static scenery keeps the exact version.
static var fast := false


# ================================================================ colour + light

static func lit(col: Color, k: float) -> Color:
	## k in [-1, 1]: how much this point faces the light.
	if k >= 0.0:
		return col.lerp(HILITE, 0.34 * k)
	var d := col.darkened(0.34 * -k)
	return d.lerp(COOL, 0.14 * -k)


static func shift_hue(c: Color, amount: float, sat_boost: float = 0.2) -> Color:
	return Color.from_hsv(fposmod(c.h + amount, 1.0), clampf(c.s + sat_boost, 0.0, 1.0), clampf(c.v + 0.05, 0.0, 1.0), c.a)


static func soft_texture() -> Texture2D:
	if _soft_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.75))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_soft_tex = t
	return _soft_tex


# ================================================================ flat primitives (kept for simple things)

static func _ellipse_pts(xf: Transform2D, c: Vector2, r: Vector2, rot: float = 0.0, seg: int = SEG) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in seg:
		var a := TAU * float(i) / float(seg)
		pts.append(xf * (Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot) + c))
	return pts


static func ell(ci: CanvasItem, xf: Transform2D, c: Vector2, r: Vector2, col: Color, rot: float = 0.0) -> void:
	var ring := _ellipse_pts(xf, c, r, rot)
	var cols := PackedColorArray()
	cols.resize(ring.size())
	cols.fill(col)
	fan(ci, xf * c, ring, col, cols)


static func circ(ci: CanvasItem, xf: Transform2D, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(xf * c, r * absf(xf.get_scale().y), col)


static func _indices(n: int) -> PackedInt32Array:
	if not _fan_idx.has(n):
		var idx := PackedInt32Array()
		for i in n:
			idx.append(0)
			idx.append(i + 1)
			idx.append((i + 1) % n + 1)
		_fan_idx[n] = idx
	return _fan_idx[n]


## Triangle fan around `center` - no triangulation needed (shapes here are star-shaped).
static func fan(ci: CanvasItem, center: Vector2, ring: PackedVector2Array, ccol: Color, ring_cols: PackedColorArray) -> void:
	var pts := PackedVector2Array([center])
	pts.append_array(ring)
	var cols := PackedColorArray([ccol])
	cols.append_array(ring_cols)
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), _indices(ring.size()), pts, cols)


static func tri(ci: CanvasItem, xf: Transform2D, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	ci.draw_primitive(PackedVector2Array([xf * a, xf * b, xf * c]), PackedColorArray([col, col, col]), PackedVector2Array())


static func line(ci: CanvasItem, xf: Transform2D, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	ci.draw_line(xf * a, xf * b, col, maxf(1.0, w * absf(xf.get_scale().y)), true)


# ================================================================ shaded primitives

static func _ccw(pts: PackedVector2Array) -> PackedVector2Array:
	if Geometry2D.is_polygon_clockwise(pts):
		var r := pts.duplicate()
		r.reverse()
		return r
	return pts


## Ink outline drawn *under* a shape: the shape grown by `w` pixels with round joins.
static func outline(ci: CanvasItem, pts: PackedVector2Array, w: float, col: Color = INK) -> void:
	if w <= 0.05 or pts.size() < 3:
		return
	if fast:
		var c := Vector2.ZERO
		for p in pts:
			c += p
		c /= float(pts.size())
		var ring := PackedVector2Array()
		ring.resize(pts.size())
		for i in pts.size():
			var v := pts[i] - c
			var l := v.length()
			ring[i] = c + (v * ((l + w) / l) if l > 0.001 else v)
		var cols := PackedColorArray()
		cols.resize(ring.size())
		cols.fill(col)
		fan(ci, c, ring, col, cols)
		return
	var grown := Geometry2D.offset_polygon(_ccw(pts), w, Geometry2D.JOIN_ROUND)
	if grown.is_empty():
		grown = Geometry2D.offset_polygon(pts, w, Geometry2D.JOIN_ROUND)
	var best := PackedVector2Array()
	for g in grown:
		if g.size() > best.size():
			best = g
	if best.size() >= 3:
		ci.draw_colored_polygon(best, col)


## Fill a screen-space polygon with light-direction shading. `center` is where normals point from.
static func shaded_fill(ci: CanvasItem, pts: PackedVector2Array, col: Color, center: Vector2, strength: float = 1.0) -> void:
	var cols := PackedColorArray()
	cols.resize(pts.size())
	for i in pts.size():
		var n := (pts[i] - center)
		var k := 0.0
		if n.length_squared() > 0.0001:
			k = n.normalized().dot(LIGHT)
		cols[i] = lit(col, k * strength)
	fan(ci, center, pts, lit(col, 0.12 * strength), cols)


## A lit, outlined ellipse. `ow` = outline width in pixels (0 = none).
static func blob(ci: CanvasItem, xf: Transform2D, c: Vector2, r: Vector2, col: Color, rot: float = 0.0,
		ow: float = 0.0, shine: bool = true, strength: float = 1.0) -> void:
	var pts := _ellipse_pts(xf, c, r, rot)
	if ow > 0.05:
		var sc := absf(xf.get_scale().y)
		var grow := ow / maxf(sc, 0.001)
		var ring := _ellipse_pts(xf, c, r + Vector2(grow, grow), rot)
		var ink := PackedColorArray()
		ink.resize(ring.size())
		ink.fill(INK)
		fan(ci, xf * c, ring, INK, ink)
	var center := xf * c
	shaded_fill(ci, pts, col, center, strength)
	if shine:
		var hp := center + LIGHT * absf(xf.get_scale().y) * minf(r.x, r.y) * 0.48
		var hr := absf(xf.get_scale().y) * minf(r.x, r.y) * 0.24
		var hl := _ellipse_pts(Transform2D.IDENTITY, hp, Vector2(hr * 1.25, hr * 0.8), -0.6, 12)
		var hc := PackedColorArray()
		hc.resize(hl.size())
		hc.fill(Color(HILITE, 0.0))
		fan(ci, hp, hl, Color(HILITE, 0.75), hc)


## A lit, outlined polygon given in unit space.
static func shape(ci: CanvasItem, xf: Transform2D, unit_pts: Array, col: Color, ow: float = 0.0, strength: float = 1.0) -> void:
	var pts := PackedVector2Array()
	var cen := Vector2.ZERO
	for p in unit_pts:
		var q: Vector2 = xf * p
		pts.append(q)
		cen += q
	cen /= float(pts.size())
	outline(ci, pts, ow)
	shaded_fill(ci, pts, col, cen, strength)


## A thick outlined stroke (tails, antlers, legs).
static func stroke(ci: CanvasItem, xf: Transform2D, a: Vector2, b: Vector2, col: Color, w: float, ow: float = 0.0) -> void:
	var s := absf(xf.get_scale().y)
	var pa := xf * a
	var pb := xf * b
	if ow > 0.0:
		ci.draw_line(pa, pb, INK, w * s + ow * 2.0, true)
		ci.draw_circle(pa, (w * s + ow * 2.0) * 0.5, INK)
		ci.draw_circle(pb, (w * s + ow * 2.0) * 0.5, INK)
	ci.draw_line(pa, pb, col, w * s, true)
	ci.draw_circle(pa, w * s * 0.5, col)
	ci.draw_circle(pb, w * s * 0.5, col)
	var off := LIGHT * w * s * 0.18
	ci.draw_line(pa + off, pb + off, lit(col, 0.7), maxf(1.0, w * s * 0.3), true)


## Soft ground shadow (contact / blob shadow).
static func soft(ci: CanvasItem, center: Vector2, radii: Vector2, alpha: float = 0.32) -> void:
	ci.draw_texture_rect(soft_texture(), Rect2(center - radii, radii * 2.0), false, Color(SHADOW, alpha))


## Shadow cast by an object of `height` and `width` standing at `base`, falling bottom-right.
static func cast(ci: CanvasItem, base: Vector2, width: float, height: float, alpha: float = 0.26) -> void:
	var length := height * 0.75
	var ang := CAST_DIR.angle()
	ci.draw_set_transform(base + CAST_DIR * length * 0.42, ang, Vector2.ONE)
	var radii := Vector2(length * 0.62 + width * 0.25, width * 0.42)
	ci.draw_texture_rect(soft_texture(), Rect2(-radii, radii * 2.0), false, Color(SHADOW, alpha))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Light-catching arc along the top-left edge of an ellipse (rim light).
static func rim(ci: CanvasItem, xf: Transform2D, c: Vector2, r: Vector2, w_px: float, alpha: float = 0.75) -> void:
	var pts := PackedVector2Array()
	var flip := xf.get_scale().x < 0.0
	for i in 9:
		var a := lerpf(PI * 1.05, PI * 1.55, float(i) / 8.0)
		var p := Vector2(cos(a) * r.x * 0.9, sin(a) * r.y * 0.9)
		if flip:
			p.x = -p.x
		pts.append(xf * (c + p))
	ci.draw_polyline(pts, Color(HILITE, alpha), w_px, true)


static func sparkle(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * i / 8.0
		var rr := r if i % 2 == 0 else r * 0.3
		pts.append(p + Vector2(cos(a), sin(a)) * rr)
	var cols := PackedColorArray()
	cols.resize(8)
	cols.fill(col)
	fan(ci, p, pts, col, cols)


# ================================================================ creatures

## Draws a creature. `pos` is the body centre; `size` is the body radius at stage 1. `level` is the pet level (1-10).
static func draw_pet(ci: CanvasItem, pos: Vector2, species_id: String, level: int, prism: bool,
		t: float, size: float, facing: float = 1.0, silhouette: bool = false, sil_col: Color = Color("#6a6080")) -> void:
	if not Data.SPECIES.has(species_id):
		return
	var sp: Dictionary = Data.SPECIES[species_id]
	var body := Color(str(sp["body"]))
	var acc := Color(str(sp["accent"]))
	if prism:
		body = shift_hue(body, 0.5, 0.25)
		acc = shift_hue(acc, 0.5, 0.15)
	var dark := body.darkened(0.25)
	var ink := INK
	var strength := 1.0
	if silhouette:
		body = sil_col
		acc = body
		dark = body
		strength = 0.35
	var lvl := Data.stage_of(level)
	var s := size * Data.stage_scale(lvl)
	var ow := clampf(s * 0.085, 1.2, 4.0)
	var phase := float(species_id.length()) * 0.7
	var bob := sin(t * 3.0 + phase) * 0.05
	var face := 1.0 if facing >= 0.0 else -1.0
	var base := Transform2D(0.0, Vector2(s * face, s), 0.0, pos)
	var xf := Transform2D(0.0, Vector2(s * face, s), 0.0, pos + Vector2(0.0, bob * s))
	var ears: String = sp["ears"]
	var tail: String = sp["tail"]
	var extra: String = sp["extra"]

	# ground shadows + radiant aura
	if not silhouette:
		soft(ci, base * Vector2(0.1, 0.95), Vector2(1.05, 0.28) * s, 0.42)
		cast(ci, base * Vector2(0.1, 0.92), s * 1.6, s * 1.4, 0.16)
		if lvl >= Data.MAX_STAGE or extra == "glow":
			var pulse := 0.5 + 0.5 * sin(t * 2.5)
			ci.draw_texture_rect(soft_texture(), Rect2(xf * Vector2(0, -0.1) - Vector2(2.1, 2.1) * s, Vector2(4.2, 4.2) * s), false, Color(acc.lightened(0.3), 0.35 + 0.15 * pulse))

	# --- behind the body: tail, wings, mane, spikes, ears, antlers
	match tail:
		"puff":
			blob(ci, xf, Vector2(-0.95, 0.25), Vector2(0.36, 0.34), acc, 0.0, ow, true, strength)
		"long":
			var wag := sin(t * 4.0 + phase) * 0.15
			stroke(ci, xf, Vector2(-0.7, 0.35), Vector2(-1.25, 0.15 + wag), body, 0.24, ow)
			stroke(ci, xf, Vector2(-1.25, 0.15 + wag), Vector2(-1.6, -0.25 + wag), body, 0.2, ow)
		"striped":
			var wag2 := sin(t * 3.0 + phase) * 0.1
			blob(ci, xf, Vector2(-1.15, 0.05), Vector2(0.64, 0.34), body, -0.4 + wag2, ow, false, strength)
			for k in 3:
				var c := Vector2(-0.85 - 0.22 * k, 0.17 - 0.09 * k)
				ell(ci, xf, c, Vector2(0.065, 0.3), dark if not silhouette else body, -0.4 + wag2)
		"fin":
			var flick := sin(t * 5.0 + phase) * 0.12
			shape(ci, xf, [Vector2(-0.75, 0.25), Vector2(-1.5, -0.3 + flick), Vector2(-1.3, 0.2), Vector2(-1.4, 0.75 + flick)], acc, ow, strength)
		"fan":
			var n := 3
			if species_id == "kitsune":
				n = 1 + (lvl - 1) * 2 # grows extra tails: 1,3,5,7,9
			var root := Vector2(-0.75, 0.2)
			for k in n:
				var ang := 0.0 if n == 1 else lerpf(-0.9, 0.9, float(k) / float(n - 1))
				ang += sin(t * 2.0 + k) * 0.06
				var dir := Vector2(-1, 0).rotated(ang)
				blob(ci, xf, root + dir * 0.6, Vector2(0.58, 0.22), body, ang, ow, false, strength)
				blob(ci, xf, root + dir * 1.05, Vector2(0.17, 0.15), acc, 0.0, 0.0, false, strength)

	if extra == "wings":
		var flap := sin(t * 7.0 + phase) * 0.25
		var wing_col := acc if species_id != "thunderbird" else dark
		blob(ci, xf, Vector2(-0.45, -0.55), Vector2(0.78, 0.4), wing_col, -0.7 + flap, ow, true, strength)
		blob(ci, xf, Vector2(0.05, -0.78), Vector2(0.66, 0.33), wing_col.darkened(0.08), -1.1 - flap, ow, false, strength)
		if species_id == "luna_moth" and not silhouette:
			blob(ci, xf, Vector2(-0.55, -0.62), Vector2(0.13, 0.13), Color("#ffd27a"), 0.0, ow * 0.6, false)
	if extra == "mane":
		for k in 5:
			blob(ci, xf, Vector2(-0.55 + 0.22 * k, -0.78 + 0.01 * k * k), Vector2(0.26, 0.26), acc, 0.0, ow, false, strength)
	if extra == "spikes":
		for k in 7:
			var a := lerpf(PI * 0.95, PI * 1.7, float(k) / 6.0)
			var p := Vector2(cos(a), sin(a) * 0.85)
			shape(ci, xf, [p * 0.75 + p.orthogonal() * 0.2, p * 1.38, p * 0.75 - p.orthogonal() * 0.2], dark, ow, strength)

	match ears:
		"round":
			for ex: float in [-0.35, 0.45]:
				blob(ci, xf, Vector2(ex, -0.78), Vector2(0.28, 0.28), body, 0.0, ow, false, strength)
				blob(ci, xf, Vector2(ex, -0.78), Vector2(0.14, 0.14), acc.lerp(Color("#ffb3c0"), 0.4), 0.0, 0.0, false, strength)
		"pointy":
			shape(ci, xf, [Vector2(-0.62, -0.5), Vector2(-0.4, -1.4), Vector2(-0.02, -0.66)], body, ow, strength)
			shape(ci, xf, [Vector2(0.12, -0.66), Vector2(0.52, -1.4), Vector2(0.75, -0.5)], body, ow, strength)
			tri(ci, xf, Vector2(-0.46, -0.66), Vector2(-0.38, -1.12), Vector2(-0.17, -0.7), acc.lerp(Color("#ffb3c0"), 0.35))
			tri(ci, xf, Vector2(0.3, -0.7), Vector2(0.51, -1.12), Vector2(0.6, -0.66), acc.lerp(Color("#ffb3c0"), 0.35))
		"big":
			shape(ci, xf, [Vector2(-0.78, -0.42), Vector2(-0.74, -1.65), Vector2(0.02, -0.74)], body, ow, strength)
			shape(ci, xf, [Vector2(0.18, -0.74), Vector2(0.98, -1.65), Vector2(0.98, -0.42)], body, ow, strength)
			tri(ci, xf, Vector2(-0.6, -0.6), Vector2(-0.63, -1.32), Vector2(-0.17, -0.78), Color("#ffc2c8") if not silhouette else body)
			tri(ci, xf, Vector2(0.38, -0.78), Vector2(0.87, -1.32), Vector2(0.82, -0.6), Color("#f0a8b2") if not silhouette else body)
		"long":
			var flop := sin(t * 2.0 + phase) * 0.08
			for side: float in [-1.0, 1.0]:
				var ex2 := 0.05 + 0.33 * side
				blob(ci, xf, Vector2(ex2, -1.2), Vector2(0.21, 0.6), body, 0.18 * side - flop * side, ow, false, strength)
				ell(ci, xf, Vector2(ex2, -1.15), Vector2(0.09, 0.42), acc.lerp(Color("#ffb3c0"), 0.4) if not silhouette else body, 0.18 * side - flop * side)
		"gills":
			var gill := Color("#ff6f9a") if not silhouette else body
			if prism:
				gill = shift_hue(gill, 0.5)
			for side: float in [-1.0, 1.0]:
				var cx := 0.2 + 0.85 * side
				for k in 3:
					var a2 := -PI / 2.0 + side * (0.5 + 0.35 * k)
					var tip := Vector2(cx, -0.25) + Vector2(cos(a2), sin(a2)) * 0.48
					stroke(ci, xf, Vector2(cx * 0.8, -0.25), tip, gill, 0.12, ow * 0.7)
					blob(ci, xf, tip, Vector2(0.1, 0.1), gill, 0.0, ow * 0.7, false, strength)
		"antenna":
			stroke(ci, xf, Vector2(-0.05, -0.8), Vector2(-0.35, -1.5), INK, 0.06)
			stroke(ci, xf, Vector2(0.45, -0.8), Vector2(0.65, -1.5), INK, 0.06)
			blob(ci, xf, Vector2(-0.35, -1.5), Vector2(0.13, 0.13), acc, 0.0, ow * 0.7, true, strength)
			blob(ci, xf, Vector2(0.65, -1.5), Vector2(0.13, 0.13), acc, 0.0, ow * 0.7, true, strength)
		"crest":
			for k in 3:
				var bx := -0.25 + 0.3 * k
				shape(ci, xf, [Vector2(bx - 0.16, -0.72), Vector2(bx - 0.05, -1.48 + 0.1 * k), Vector2(bx + 0.16, -0.78)], acc, ow, strength)

	if extra == "antlers" or extra == "antlers_big":
		var big := extra == "antlers_big"
		var ac := Color("#8a6844") if not big else acc
		if silhouette:
			ac = body
		var h := 1.5 if big else 1.0
		for side: float in [-1.0, 1.0]:
			var bx2 := 0.18 + 0.28 * side
			var top := Vector2(bx2 + 0.25 * side, -0.75 - 0.75 * h)
			stroke(ci, xf, Vector2(bx2, -0.75), top, ac, 0.1, ow * 0.8)
			stroke(ci, xf, Vector2(bx2 + 0.12 * side, -0.75 - 0.35 * h), Vector2(bx2 + 0.45 * side, -0.85 - 0.45 * h), ac, 0.08, ow * 0.8)
			if big:
				stroke(ci, xf, Vector2(bx2 + 0.2 * side, -0.75 - 0.6 * h), Vector2(bx2 - 0.05 * side, -0.85 - 0.85 * h), ac, 0.07, ow * 0.8)
				if not silhouette:
					sparkle(ci, xf * top, 0.16 * s, Color(1, 1, 1, 0.9))
	if extra == "horns":
		shape(ci, xf, [Vector2(0.03, -0.78), Vector2(0.0, -1.32), Vector2(0.21, -0.82)], acc, ow, strength)
		shape(ci, xf, [Vector2(0.34, -0.82), Vector2(0.5, -1.32), Vector2(0.52, -0.76)], acc, ow, strength)

	# --- feet + body
	blob(ci, xf, Vector2(-0.35, 0.78), Vector2(0.22, 0.17), dark, 0.0, ow, false, strength)
	blob(ci, xf, Vector2(0.42, 0.8), Vector2(0.22, 0.17), dark.darkened(0.08), 0.0, ow, false, strength)
	blob(ci, xf, Vector2.ZERO, Vector2(1.0, 0.86), body, 0.0, ow, false, strength)
	if not silhouette:
		blob(ci, xf, Vector2(0.2, 0.3), Vector2(0.58, 0.46), acc, 0.0, 0.0, false, 0.6)
		match extra:
			"stripes":
				for k in 3:
					ell(ci, xf, Vector2(-0.75 + 0.18 * k, 0.15), Vector2(0.065, 0.32), acc, 0.15)
			"spots":
				for p in [Vector2(-0.5, -0.35), Vector2(-0.1, -0.55), Vector2(-0.7, 0.2), Vector2(0.5, -0.5)]:
					blob(ci, xf, p, Vector2(0.14, 0.13), acc, 0.0, 0.0, false)
		rim(ci, xf, Vector2.ZERO, Vector2(1.0, 0.86), maxf(1.5, s * 0.09), 0.85)
		# face: big glossy eyes
		var blink := fmod(t + phase, 4.2) < 0.13
		for ex: float in [0.2, 0.68]:
			var ep := Vector2(ex, -0.14)
			if blink:
				stroke(ci, xf, ep + Vector2(-0.12, 0.02), ep + Vector2(0.12, 0.02), ink, 0.06)
			else:
				ell(ci, xf, ep, Vector2(0.14, 0.17), ink)
				circ(ci, xf, ep + Vector2(-0.045, -0.06), 0.058, Color.WHITE)
				circ(ci, xf, ep + Vector2(0.05, 0.06), 0.028, Color(1, 1, 1, 0.85))
		ell(ci, xf, Vector2(0.02, 0.1), Vector2(0.13, 0.07), Color(1.0, 0.45, 0.55, 0.45))
		ell(ci, xf, Vector2(0.88, 0.1), Vector2(0.13, 0.07), Color(1.0, 0.45, 0.55, 0.45))
		tri(ci, xf, Vector2(0.38, 0.03), Vector2(0.5, 0.03), Vector2(0.44, 0.1), ink)
		var mouth := PackedVector2Array()
		for i in 7:
			var a3 := lerpf(0.2, PI - 0.2, float(i) / 6.0)
			mouth.append(xf * (Vector2(0.44, 0.13) + Vector2(cos(a3) * 0.08, sin(a3) * 0.06)))
		ci.draw_polyline(mouth, ink, maxf(1.0, s * 0.045), true)
		if extra == "whiskers":
			for k in 2:
				line(ci, xf, Vector2(0.62, 0.08 + 0.07 * k), Vector2(1.08, 0.02 + 0.12 * k), Color(ink, 0.6), 0.025)
		if extra == "tusk":
			stroke(ci, xf, Vector2(0.85, -0.05), Vector2(1.9, -0.55), Color("#fff8e6"), 0.1, ow * 0.7)
			for k in 4:
				var p2 := Vector2(0.85, -0.05).lerp(Vector2(1.9, -0.55), 0.2 + 0.2 * k)
				circ(ci, xf, p2, 0.035, Color("#d9cbb0"))
		# growth-stage ornaments
		if lvl >= 4:
			for k in 3:
				var a4 := t * 1.5 + TAU * k / 3.0
				var op := xf * Vector2(cos(a4) * 1.3, -0.2 + sin(a4) * 0.42)
				sparkle(ci, op, s * 0.13, Color(1.0, 0.95, 0.6, 0.95))
		if lvl >= Data.MAX_STAGE:
			var halo_y := -1.4 if ears in ["none", "round", "gills"] else -1.8
			var hc := xf * Vector2(0.18, halo_y)
			ci.draw_arc(hc, 0.36 * s, 0.0, TAU, 32, INK, maxf(3.0, 0.14 * s), true)
			ci.draw_arc(hc, 0.36 * s, 0.0, TAU, 32, Color("#ffe27a"), maxf(2.0, 0.08 * s), true)
		if prism:
			for k in 4:
				var a5 := t * 0.8 + k * 1.7
				var sp2 := Vector2(cos(a5 * 1.3) * 1.2, sin(a5) * 1.0 - 0.2)
				var tw := 0.5 + 0.5 * sin(t * 5.0 + k)
				sparkle(ci, xf * sp2, 0.14 * s * (0.5 + tw), Color(1, 1, 1, 0.95))


# ================================================================ eggs

## Draws an egg centred at `pos`; `warmth` 0..1 makes it glow, wobble and crack.
static func draw_egg(ci: CanvasItem, pos: Vector2, egg_type: String, size: float, t: float,
		warmth: float = 0.0, with_shadow: bool = true) -> void:
	var info: Dictionary = Data.EGGS.get(egg_type, Data.EGGS["dawn"])
	var shell := Color(str(info["shell"]))
	var spot := Color(str(info["spots"]))
	var wob := 0.0
	if warmth > 0.6:
		wob = sin(t * 18.0) * 0.14 * (warmth - 0.6) / 0.4
	var xf := Transform2D(wob, Vector2(size, size), 0.0, pos)
	var ow := clampf(size * 0.08, 1.0, 3.0)
	if with_shadow:
		soft(ci, pos + Vector2(0, size * 0.9), Vector2(0.8, 0.22) * size, 0.4)
	if warmth > 0.05:
		var gr := size * (1.5 + 0.06 * sin(t * 4.0))
		ci.draw_texture_rect(soft_texture(), Rect2(pos - Vector2(gr, gr), Vector2(gr, gr) * 2.0), false, Color(1.0, 0.78, 0.35, 0.55 * warmth))
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * float(i) / 32.0
		pts.append(xf * Vector2(cos(a) * 0.72 * (1.0 + 0.16 * sin(a)), sin(a) * 0.95))
	outline(ci, pts, ow)
	shaded_fill(ci, pts, shell, xf * Vector2(0, 0.05))
	for sp in [[Vector2(-0.25, -0.3), 0.14], [Vector2(0.3, 0.05), 0.18], [Vector2(-0.12, 0.45), 0.12], [Vector2(0.18, -0.6), 0.09], [Vector2(0.38, 0.5), 0.08]]:
		var sc: Vector2 = sp[0]
		circ(ci, xf, sc, sp[1], lit(spot, -sc.normalized().dot(Vector2(0.55, 0.83))))
	ell(ci, xf, Vector2(-0.3, -0.45), Vector2(0.1, 0.22), Color(1, 1, 1, 0.8), 0.35)
	if warmth > 0.85:
		var zig := [Vector2(-0.6, -0.05), Vector2(-0.35, -0.2), Vector2(-0.15, 0.0), Vector2(0.1, -0.22), Vector2(0.3, 0.0), Vector2(0.55, -0.15)]
		for i in zig.size() - 1:
			line(ci, xf, zig[i], zig[i + 1], INK, 0.06)


# ================================================================ tool icons

## Small tool icon (axe, basket, pickaxe, rod, hammer, compass). `pos` is the icon centre.
static func draw_tool(ci: CanvasItem, pos: Vector2, kind: String, tier: int, size: float, angle: float = 0.0) -> void:
	var xf := Transform2D(angle, Vector2(size, size), 0.0, pos)
	var handle := Color("#a0703f")
	var head := Color(str(Data.TIERS[clampi(tier, 0, Data.TIERS.size() - 1)]["color"]))
	var ow := clampf(size * 0.13, 1.0, 3.0)
	match kind:
		"axe":
			stroke(ci, xf, Vector2(0, 0.9), Vector2(0, -0.8), handle, 0.18, ow)
			shape(ci, xf, [Vector2(0, -0.82), Vector2(0.68, -1.02), Vector2(0.78, -0.18), Vector2(0, -0.34)], head, ow)
		"pickaxe":
			stroke(ci, xf, Vector2(0, 0.9), Vector2(0, -0.7), handle, 0.18, ow)
			shape(ci, xf, [Vector2(-0.85, -0.3), Vector2(-0.4, -0.82), Vector2(0, -0.92), Vector2(0.4, -0.82), Vector2(0.85, -0.3), Vector2(0.4, -0.62), Vector2(0, -0.7), Vector2(-0.4, -0.62)], head, ow)
		"hammer":
			stroke(ci, xf, Vector2(0, 0.9), Vector2(0, -0.5), handle, 0.18, ow)
			shape(ci, xf, [Vector2(-0.6, -0.9), Vector2(0.6, -0.9), Vector2(0.6, -0.38), Vector2(-0.6, -0.38)], head, ow)
		"rod":
			stroke(ci, xf, Vector2(-0.6, 0.9), Vector2(0.6, -0.9), handle, 0.13, ow)
			line(ci, xf, Vector2(0.6, -0.9), Vector2(0.6, 0.3), Color(1, 1, 1, 0.9), 0.05)
			blob(ci, xf, Vector2(0.6, 0.38), Vector2(0.16, 0.16), Color("#e46a5a"), 0.0, ow * 0.7)
		"basket":
			ci.draw_arc(xf * Vector2(0, -0.1), 0.56 * size, PI, TAU, 16, INK, maxf(3.0, 0.2 * size), true)
			ci.draw_arc(xf * Vector2(0, -0.1), 0.56 * size, PI, TAU, 16, handle, maxf(2.0, 0.11 * size), true)
			shape(ci, xf, [Vector2(-0.78, -0.12), Vector2(0.78, -0.12), Vector2(0.52, 0.82), Vector2(-0.52, 0.82)], head, ow)
			for k in 3:
				line(ci, xf, Vector2(-0.55 + 0.55 * k, 0.05), Vector2(-0.4 + 0.4 * k, 0.7), head.darkened(0.3), 0.06)
		"compass":
			blob(ci, xf, Vector2.ZERO, Vector2(0.82, 0.82), head, 0.0, ow, false)
			circ(ci, xf, Vector2.ZERO, 0.6, Color("#fffaf0"))
			tri(ci, xf, Vector2(0, -0.52), Vector2(0.16, 0), Vector2(-0.16, 0), Color("#e46a5a"))
			tri(ci, xf, Vector2(0, 0.52), Vector2(0.16, 0), Vector2(-0.16, 0), Color("#5a6470"))
