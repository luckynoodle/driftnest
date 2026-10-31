class_name BuildingView
extends Node2D
## Draws one town building in the storybook-3D (3/4) view: a lit front wall, a shaded side wall
## receding up-right, roofs seen from above, soft cast shadows. Origin = bottom-centre of the
## footprint (for y-sorting). Also used as the translucent "ghost" while placing.
##
## The static body is drawn only when something changes; animated bits (smoke, flags, lamp
## glow, fountain spray, eggs in the nest) live on a small child node redrawn every frame.

const T := WorldMap.TILE
const INK := PetArt.INK
const OW := 2.6
const ANIMATED := ["house", "workshop", "town_hall", "lamp", "fountain", "nest", "crystal_mine", "kiosk", "explorer_lodge"]

var type := "house"
var bid := -1
var ghost := false
var ghost_ok := true
var t := 0.0
var _var := 0.0
var _fx: Node2D
var _last_sig := ""
var _smoke_at := Vector2.INF


func setup(b_type: String, b_id: int) -> void:
	type = b_type
	bid = b_id
	_var = WorldMap.hash01(Vector2i(b_id, 7))
	z_index = -1 if type == "path" else 0
	if _fx == null:
		_fx = Node2D.new()
		_fx.draw.connect(_draw_fx)
		add_child(_fx)
	queue_redraw()


func _ready() -> void:
	if not Game.changed.is_connected(_on_changed):
		Game.changed.connect(_on_changed)


func _on_changed() -> void:
	# only rebuild the static drawing when something it shows has changed
	var b := _b()
	var sig := ""
	if not b.is_empty():
		sig = "%s|%d" % [str(b["built"]), int(float(b["progress"]) * 4.0)]
	if type == "town_hall":
		sig += "|%d" % Game.town_level
	if type == "statue":
		sig += "|%d" % Game.pets.size()
	if sig != _last_sig:
		_last_sig = sig
		queue_redraw()


func _process(delta: float) -> void:
	t += delta
	if ghost:
		queue_redraw()
	if _fx and (type in ANIMATED):
		_fx.queue_redraw()


func _b() -> Dictionary:
	return {} if bid < 0 else Game.find_building(bid)


func _size() -> Vector2i:
	return Data.BUILDINGS[type]["size"]


func _built() -> bool:
	var b := _b()
	return ghost or b.is_empty() or bool(b["built"])


func _draw() -> void:
	PetArt.fast = true
	var sz := Vector2(_size()) * T
	if ghost:
		var col := Color(0.4, 0.95, 0.45, 0.32) if ghost_ok else Color(1.0, 0.35, 0.3, 0.32)
		draw_rect(Rect2(Vector2(-sz.x / 2.0, -sz.y), sz), col)
		draw_rect(Rect2(Vector2(-sz.x / 2.0, -sz.y), sz), Color(col, 0.95), false, 3.0)
		modulate = Color(1, 1, 1, 0.72)
	if not _built():
		_construction(sz, _b())
		return
	_draw_type(sz)


# ================================================================ 3/4 drawing helpers

## Vertical face lit from the top-left: lighter at the top, darker at the bottom.
func _front(pts: PackedVector2Array, col: Color, ow: float = OW) -> void:
	PetArt.outline(self, pts, ow)
	var top := INF
	var bot := -INF
	for p in pts:
		top = minf(top, p.y)
		bot = maxf(bot, p.y)
	var cols := PackedColorArray()
	for p in pts:
		var k := inverse_lerp(top, bot, p.y) if bot > top else 0.5
		cols.append(PetArt.lit(col, lerpf(0.3, -0.12, k)))
	draw_polygon(pts, cols)


func _side(pts: PackedVector2Array, col: Color, ow: float = OW) -> void:
	PetArt.outline(self, pts, ow)
	var cols := PackedColorArray()
	var top := INF
	var bot := -INF
	for p in pts:
		top = minf(top, p.y)
		bot = maxf(bot, p.y)
	for p in pts:
		var k := inverse_lerp(top, bot, p.y) if bot > top else 0.5
		cols.append(PetArt.lit(col, lerpf(-0.42, -0.62, k)))
	draw_polygon(pts, cols)


func _top(pts: PackedVector2Array, col: Color, ow: float = OW) -> void:
	PetArt.outline(self, pts, ow)
	var cols := PackedColorArray()
	var left := INF
	var right := -INF
	for p in pts:
		left = minf(left, p.x)
		right = maxf(right, p.x)
	for p in pts:
		var k := inverse_lerp(left, right, p.x) if right > left else 0.5
		cols.append(PetArt.lit(col, lerpf(0.5, 0.08, k)))
	draw_polygon(pts, cols)


static func _pv(arr: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in arr:
		out.append(p)
	return out


## Box: front face bottom-left at `bl`, size w x h, depth vector d (up-right). Returns the top-front-left corner.
func _box(bl: Vector2, w: float, h: float, d: Vector2, col: Color, top_col: Color = Color(0, 0, 0, 0), ow: float = OW) -> void:
	var br := bl + Vector2(w, 0)
	var tl := bl + Vector2(0, -h)
	var tr := br + Vector2(0, -h)
	_side(_pv([br, br + d, tr + d, tr]), col, ow)
	_top(_pv([tl, tr, tr + d, tl + d]), top_col if top_col.a > 0.0 else col.lightened(0.1), ow)
	_front(_pv([bl, br, tr, tl]), col, ow)


func _cast(base: Vector2, w: float, h: float) -> void:
	PetArt.cast(self, base, w, h * 1.1, 0.24)
	PetArt.soft(self, base + Vector2(6, -2), Vector2(w * 0.62, 12), 0.36)


func _window(c: Vector2, s: Vector2, glass: Color = Color("#ffd36b")) -> void:
	var r := Rect2(c - s / 2.0, s)
	PetArt.outline(self, _pv([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), OW)
	draw_rect(r, Color("#6e4126"))
	var g := r.grow(-3.0)
	draw_polygon(_pv([g.position, Vector2(g.end.x, g.position.y), g.end, Vector2(g.position.x, g.end.y)]),
		PackedColorArray([glass.lightened(0.35), glass, glass.darkened(0.12), glass]))
	draw_line(Vector2(c.x, g.position.y), Vector2(c.x, g.end.y), INK, 2.0)
	draw_line(Vector2(g.position.x, c.y), Vector2(g.end.x, c.y), INK, 2.0)
	draw_colored_polygon(_pv([g.position + Vector2(2, 2), g.position + Vector2(s.x * 0.3, 2), g.position + Vector2(2, s.y * 0.35)]), Color(1, 1, 1, 0.6))
	_box(Vector2(r.position.x - 3, r.end.y + 4), s.x + 6, 4, Vector2(3, -3), Color("#8b5e3c"), Color(0, 0, 0, 0), 1.6)


func _door(bx: float, by: float, w: float, h: float, col: Color = Color("#a46a44")) -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2(bx - w / 2.0, by))
	for i in 11:
		var a := lerpf(PI, TAU, float(i) / 10.0)
		pts.append(Vector2(bx + cos(a) * w / 2.0, by - h + w / 2.0 + sin(a) * w / 2.0))
	pts.append(Vector2(bx + w / 2.0, by))
	PetArt.outline(self, pts, OW)
	draw_colored_polygon(pts, Color("#6e4126"))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(Vector2(bx + (p.x - bx) * 0.82, by - (by - p.y) * 0.92))
	_front(inner, col, 0.0)
	draw_line(Vector2(bx - w * 0.15, by - 2), Vector2(bx - w * 0.15, by - h * 0.8), Color("#7a4a2e"), 2.0)
	draw_line(Vector2(bx + w * 0.15, by - 2), Vector2(bx + w * 0.15, by - h * 0.8), Color("#7a4a2e"), 2.0)
	draw_circle(Vector2(bx + w * 0.28, by - h * 0.45), 2.6, Color("#ffd23f"))
	_box(Vector2(bx - w / 2.0 - 4, by + 4), w + 8, 4, Vector2(3, -3), Color("#c9b18e"), Color(0, 0, 0, 0), 1.6)


## Gable-roofed house: front wall x in [x0, x0+w], from y=base up wall_h; depth vector d.
## Returns a dictionary of useful points.
func _house(x0: float, base: float, w: float, wall_h: float, d: Vector2, wall: Color, roof: Color, roof_h: float = -1.0) -> Dictionary:
	if roof_h < 0.0:
		roof_h = w * 0.36
	var bl := Vector2(x0, base)
	var br := Vector2(x0 + w, base)
	var tl := bl + Vector2(0, -wall_h)
	var tr := br + Vector2(0, -wall_h)
	# walls
	_side(_pv([br, br + d, tr + d, tr]), wall)
	_front(_pv([bl, br, tr, tl]), wall)
	# plank / brick lines
	for k in 2:
		var y := base - wall_h * (0.35 + 0.33 * k)
		draw_line(Vector2(x0 + 3, y), Vector2(x0 + w - 3, y), Color(wall.darkened(0.2), 0.45), 2.0)
	draw_rect(Rect2(Vector2(x0 + 2, base - 7), Vector2(w - 4, 6)), Color(0.35, 0.25, 0.15, 0.18))
	# roof
	var o := 8.0
	var e1 := tl + Vector2(-o, 4)
	var e2 := tr + Vector2(o * 0.4, 4)
	var r1 := e1 + d * 0.5 + Vector2(0, -roof_h)
	var r2 := e2 + d * 0.5 + Vector2(0, -roof_h)
	_side(_pv([e2 - Vector2(o * 0.4, 0), tr + d + Vector2(0, 4), r2]), wall)
	var slope := _pv([e1, e2, r2, r1])
	PetArt.outline(self, slope, OW + 0.6)
	draw_polygon(slope, PackedColorArray([PetArt.lit(roof, -0.1), PetArt.lit(roof, -0.25), PetArt.lit(roof, 0.25), PetArt.lit(roof, 0.55)]))
	# shingle rows
	for k in range(1, 5):
		var f := float(k) / 5.0
		var a := e1.lerp(r1, f)
		var b := e2.lerp(r2, f)
		var pts := PackedVector2Array()
		var n := int(w / 14.0) + 1
		for i in n + 1:
			var p := a.lerp(b, float(i) / float(n))
			pts.append(p)
			if i < n:
				pts.append(a.lerp(b, (float(i) + 0.5) / float(n)) + Vector2(0, 4.0))
		draw_polyline(pts, Color(roof.darkened(0.3), 0.75), 2.0, true)
	# sunlit edge + ridge cap
	draw_line(e1.lerp(r1, 0.08) + Vector2(4, 0), r1 + Vector2(6, 2), Color(PetArt.HILITE, 0.55), 4.0, true)
	draw_line(r1 + Vector2(-2, 0), r2 + Vector2(2, 0), INK, 6.0, true)
	draw_line(r1, r2, roof.darkened(0.15), 3.0, true)
	return {"bl": bl, "br": br, "tl": tl, "tr": tr, "r1": r1, "r2": r2, "e1": e1, "e2": e2, "d": d}


func _chimney(p: Vector2, h: float, col: Color = Color("#c98b6a")) -> void:
	_box(p, 16, h, Vector2(7, -6), col, col.darkened(0.3))


func _sign(c: Vector2, kind: String) -> void:
	PetArt.blob(self, Transform2D.IDENTITY, c, Vector2(15, 15), Color("#fff2dc"), 0.0, OW, false)
	PetArt.draw_tool(self, c, kind, 0, 9.0)


func _log(c: Vector2, length: float, r: float) -> void:
	_front(_pv([c + Vector2(-length / 2.0, -r), c + Vector2(length / 2.0, -r), c + Vector2(length / 2.0, r), c + Vector2(-length / 2.0, r)]), Color("#a8794f"), 2.0)
	PetArt.blob(self, Transform2D.IDENTITY, c + Vector2(length / 2.0, 0), Vector2(r * 0.8, r), Color("#ecd0a0"), 0.0, 2.0, false)
	draw_arc(c + Vector2(length / 2.0, 0), r * 0.45, 0, TAU, 12, Color("#c09a6b"), 1.5, true)


func _bush(c: Vector2, k: float, berries: bool) -> void:
	PetArt.soft(self, c + Vector2(4, 4), Vector2(24, 7) * k, 0.35)
	for b in [[-12, -12, 14], [12, -12, 14], [0, -22, 16]]:
		PetArt.blob(self, Transform2D(0.0, Vector2(k, k), 0.0, c), Vector2(b[0], b[1]), Vector2(b[2], b[2]), Color("#4f9e4a"), 0.0, 2.2, true, 1.2)
	if berries:
		for p in [Vector2(-12, -14), Vector2(-2, -26), Vector2(9, -18), Vector2(14, -8), Vector2(-6, -8)]:
			PetArt.blob(self, Transform2D.IDENTITY, c + p * k, Vector2(3.8, 3.8), Color("#5b4cf0"), 0.0, 1.3, false)
			draw_circle(c + p * k + Vector2(-1, -1), 1.2, Color.WHITE)


func _crystal(c: Vector2, h: float, col: Color, tilt: float = 0.0) -> void:
	var dir := Vector2(0, -1).rotated(tilt)
	var side := dir.orthogonal() * h * 0.24
	PetArt.outline(self, _pv([c - side, c + dir * h, c + side]), 2.2)
	draw_colored_polygon(_pv([c - side, c + dir * h, c]), col.lightened(0.3))
	draw_colored_polygon(_pv([c, c + dir * h, c + side]), col.darkened(0.12))


func _awning(x0: float, x1: float, y: float, d: Vector2, depth_h: float, c1: Color, c2: Color, n: int) -> void:
	## Striped fabric awning sloping down towards the viewer, with a scalloped front edge.
	var back0 := Vector2(x0, y) + d + Vector2(0, -depth_h)
	var back1 := Vector2(x1, y) + d + Vector2(0, -depth_h)
	for i in n:
		var a := float(i) / n
		var b := float(i + 1) / n
		var f0 := Vector2(lerpf(x0, x1, a), y)
		var f1 := Vector2(lerpf(x0, x1, b), y)
		var col := c1 if i % 2 == 0 else c2
		var pts := _pv([f0, f1, back0.lerp(back1, b), back0.lerp(back1, a)])
		PetArt.outline(self, pts, 2.0)
		draw_polygon(pts, PackedColorArray([PetArt.lit(col, 0.0), PetArt.lit(col, -0.1), PetArt.lit(col, 0.45), PetArt.lit(col, 0.5)]))
		var mid := (f0 + f1) / 2.0
		var r := (f1.x - f0.x) / 2.0
		var sc := PackedVector2Array()
		for q in 9:
			var ang := lerpf(0.0, PI, float(q) / 8.0)
			sc.append(mid + Vector2(cos(ang) * r, sin(ang) * r * 0.7))
		PetArt.outline(self, sc, 2.0)
		draw_colored_polygon(sc, PetArt.lit(col, -0.15))


# ================================================================ construction

func _construction(sz: Vector2, b: Dictionary) -> void:
	var w := sz.x
	var ratio := clampf(float(b["progress"]) / float(Data.BUILDINGS[type]["work"]), 0.0, 1.0)
	var d := Vector2(w * 0.18, -w * 0.2)
	PetArt.soft(self, Vector2(4, -4), Vector2(w * 0.55, 14), 0.3)
	_box(Vector2(-w / 2.0 + 8, -8), w - 16 - d.x, 8, d, Color("#c9b18e"), Color("#d9c49e"))
	if sz.x >= T * 2.0:
		var h := 18.0 + 80.0 * ratio
		# timber frame rising
		var x0 := -w / 2.0 + 14
		var x1 := w / 2.0 - 14 - d.x
		for x: float in [x0, x1, (x0 + x1) / 2.0]:
			PetArt.stroke(self, Transform2D.IDENTITY, Vector2(x, -16), Vector2(x, -16 - h), Color("#c08a55"), 6.0, 2.0)
			PetArt.stroke(self, Transform2D.IDENTITY, Vector2(x, -16) + d * 0.9, Vector2(x, -16 - h) + d * 0.9, Color("#a87b4f"), 5.0, 2.0)
		for k in int(1 + ratio * 3):
			var y := -16.0 - h * float(k + 1) / 4.0
			PetArt.stroke(self, Transform2D.IDENTITY, Vector2(x0 - 4, y), Vector2(x1 + 4, y), Color("#d4a06a"), 6.0, 2.0)
		_box(Vector2(w / 2.0 - 46, -12), 22, 20, Vector2(8, -8), Color("#b07a45"))
		for k in 3:
			_box(Vector2(-w / 2.0 + 10, -12 - k * 6), 34, 5, Vector2(6, -5), Color("#e0b47a"), Color(0, 0, 0, 0), 1.6)
	# progress bar
	var bw := minf(w - 16.0, 110.0)
	var bp := Vector2(-bw / 2.0, -sz.y - 26.0)
	PetArt.outline(self, _pv([bp, bp + Vector2(bw, 0), bp + Vector2(bw, 14), bp + Vector2(0, 14)]), 2.5)
	draw_rect(Rect2(bp, Vector2(bw, 14)), Color("#fff7ec"))
	draw_rect(Rect2(bp + Vector2(2, 2), Vector2((bw - 4.0) * ratio, 10)), Color("#ffb347"))
	draw_rect(Rect2(bp + Vector2(2, 2), Vector2((bw - 4.0) * ratio, 4)), Color("#ffd28f"))


# ================================================================ building types

func _draw_type(sz: Vector2) -> void:
	var w := sz.x
	var h := sz.y
	match type:
		"town_hall":
			var d := Vector2(34, -36)
			_cast(Vector2(0, -12), w, 220)
			_box(Vector2(-w / 2.0 + 6, -4), w - 12 - d.x * 0.6, 10, d * 0.6, Color("#d9cbb0"), Color("#ece2cc"))
			var hp := _house(-w / 2.0 + 16, -14, w - 32 - d.x, 92, d, Color("#fff3df"), Color("#4f7fc9"), 52)
			_door(-d.x / 2.0 + 2, -14, 32, 50, Color("#7a5a9e"))
			_window(Vector2(-58, -66), Vector2(24, 26))
			_window(Vector2(50, -66), Vector2(24, 26))
			# side window
			var br: Vector2 = hp["br"]
			var sw := _pv([br + Vector2(8, -40), br + Vector2(26, -59), br + Vector2(26, -82), br + Vector2(8, -63)])
			PetArt.outline(self, sw, 2.0)
			draw_colored_polygon(sw, Color("#e8b85a"))
			# clock tower on the ridge
			var r1: Vector2 = hp["r1"]
			var r2: Vector2 = hp["r2"]
			var mid := r1.lerp(r2, 0.5)
			_box(mid + Vector2(-20, 26), 40, 96, Vector2(14, -14), Color("#fff3df"))
			var cc := mid + Vector2(0, -36)
			PetArt.blob(self, Transform2D.IDENTITY, cc, Vector2(13, 13), Color.WHITE, 0.0, OW, false)
			draw_line(cc, cc + Vector2(0, -9), INK, 2.0)
			draw_line(cc, cc + Vector2(7, 0), INK, 2.0)
			var tw := _pv([mid + Vector2(-26, -66), mid + Vector2(24, -66), mid + Vector2(38, -80), mid + Vector2(7, -112)])
			PetArt.outline(self, tw, OW)
			draw_polygon(tw, PackedColorArray([PetArt.lit(Color("#3d63a3"), 0.2), PetArt.lit(Color("#3d63a3"), -0.3), PetArt.lit(Color("#3d63a3"), -0.4), PetArt.lit(Color("#3d63a3"), 0.6)]))
			# planters
			for x: float in [-w / 2.0 + 12, w / 2.0 - 48]:
				_box(Vector2(x, 2), 22, 12, Vector2(6, -5), Color("#8b5e3c"))
				for k in 3:
					PetArt.blob(self, Transform2D.IDENTITY, Vector2(x + 5 + k * 6, -12), Vector2(5, 5), [Color("#ff8fa3"), Color("#ffd23f"), Color("#b48cff")][k], 0.0, 1.5, false)
		"nest":
			var id := Transform2D.IDENTITY
			_cast(Vector2(0, -34), w * 0.9, 50)
			PetArt.blob(self, id, Vector2(0, -50), Vector2(60, 32), Color("#a87b4f"), 0.0, OW, false)
			PetArt.ell(self, id, Vector2(0, -56), Vector2(47, 21), Color("#6e4a2e"))
			PetArt.ell(self, id, Vector2(0, -52), Vector2(42, 15), Color("#f6e7c8"))
			for i in 18:
				var a := float(i) / 18.0 * TAU
				var q := Vector2(cos(a) * 54, -46 + sin(a) * 26)
				var dd := Vector2(cos(a + 1.4), sin(a + 1.4) * 0.45) * 12.0
				draw_line(q - dd, q + dd, Color("#e3c28a") if i % 2 else Color("#c49a62"), 3.0, true)
		"kiosk":
			var d2 := Vector2(18, -20)
			_cast(Vector2(0, -10), w, 130)
			for x: float in [-54.0, 40.0]:
				PetArt.stroke(self, Transform2D.IDENTITY, Vector2(x, -8), Vector2(x, -112), Color("#8b5e3c"), 6.0, 2.0)
			_box(Vector2(-60, -6), 112, 40, d2, Color("#c98b5a"), Color("#e0a676"))
			_awning(-68, 58, -104, d2, 34, Color("#ff8a65"), Color("#fff3e0"), 5)
		"builder_hut":
			var d3 := Vector2(22, -24)
			_cast(Vector2(0, -14), 100, 120)
			var hp2 := _house(-44, -16, 76, 58, d3, Color("#e9cfa6"), Color("#c96a4a"))
			_door(-12, -16, 22, 36)
			_sign(Vector2(16, -50), "hammer")
			for k in 3:
				_box(Vector2(-w / 2.0 + 2, -4 - k * 6), 30, 5, Vector2(6, -5), Color("#e0b47a"), Color(0, 0, 0, 0), 1.6)
			_box(Vector2(38, -6), 20, 18, Vector2(6, -6), Color("#b07a45"))
		"house":
			var roofs := [Color("#e46a5a"), Color("#4f7fc9"), Color("#5aa64a"), Color("#9a6bff"), Color("#e8960c")]
			var walls := [Color("#fff3df"), Color("#fdebd3"), Color("#f2e3d3"), Color("#eef3f7")]
			var roof: Color = roofs[int(_var * roofs.size()) % roofs.size()]
			var wall: Color = walls[int(_var * 17.0) % walls.size()]
			var d4 := Vector2(24, -26)
			_cast(Vector2(0, -16), 100, 150)
			var hp3 := _house(-52, -16, 88, 60, d4, wall, roof)
			_door(-8, -16, 22, 38)
			_window(Vector2(-34, -44), Vector2(18, 18))
			_window(Vector2(20, -44), Vector2(18, 18))
			var chp := Vector2(hp3["r2"].x - 26, hp3["r2"].y + 30)
			_chimney(chp, 46)
			_smoke_at = chp + Vector2(11, -52)
			# flower boxes
			for x: float in [-44.0, 10.0]:
				for k in 3:
					PetArt.blob(self, Transform2D.IDENTITY, Vector2(x + 2 + k * 6, -36), Vector2(4, 4), [Color("#ff8fa3"), Color("#ffd23f"), Color("#ffffff")][(k + bid) % 3], 0.0, 1.3, false)
		"lumber_camp":
			var d5 := Vector2(22, -22)
			_cast(Vector2(0, -16), 100, 110)
			# open shed: roof on posts
			for x: float in [-50.0, 6.0]:
				PetArt.stroke(self, Transform2D.IDENTITY, Vector2(x, -50), Vector2(x, -110), Color("#8b5e3c"), 6.0, 2.0)
			_box(Vector2(-54, -104), 64, 8, d5, Color("#6b8f4a"), Color("#86b05e"))
			for k in 3:
				_log(Vector2(-26 + k * 4.0, -58 - k * 11.0), 52, 6.0)
			for k in 2:
				_log(Vector2(-6 + k * 26.0, -20), 34, 7.0)
			_box(Vector2(30, -12), 22, 14, Vector2(6, -6), Color("#c99a6d"), Color("#ecd0a0"))
			PetArt.draw_tool(self, Vector2(44, -36), "axe", 0, 11.0, 0.5)
			_sign(Vector2(36, -88), "axe")
		"berry_farm":
			_cast(Vector2(0, -10), w, 50)
			for row in 2:
				var y := -66.0 + row * 44.0
				_box(Vector2(-58, y + 14), 104, 10, Vector2(10, -10), Color("#8b5e3c"), Color("#6e4a2e"))
				for k in 3:
					_bush(Vector2(-38 + 38 * k, y + 6), 0.85, true)
			for x: float in [-60.0, -20.0, 20.0, 60.0]:
				PetArt.stroke(self, Transform2D.IDENTITY, Vector2(x, 0), Vector2(x, -22), Color("#c08a55"), 4.0, 1.6)
			PetArt.stroke(self, Transform2D.IDENTITY, Vector2(-62, -14), Vector2(62, -14), Color("#d4a06a"), 4.0, 1.6)
			_sign(Vector2(52, -106), "basket")
		"quarry":
			var id2 := Transform2D.IDENTITY
			_cast(Vector2(0, -20), w, 60)
			PetArt.blob(self, id2, Vector2(0, -62), Vector2(60, 44), Color("#b8b0a0"), 0.0, OW, false)
			PetArt.ell(self, id2, Vector2(0, -66), Vector2(50, 34), Color("#7c7468"))
			PetArt.ell(self, id2, Vector2(0, -58), Vector2(42, 24), Color("#5f584e"))
			PetArt.ell(self, id2, Vector2(-4, -62), Vector2(40, 6), Color("#8a8276", 0.6))
			for k in 3:
				_box(Vector2(-44 + k * 28, -10), 22, 16, Vector2(7, -7), Color("#b8c0c8"), Color("#dfe4e8"))
			PetArt.stroke(self, id2, Vector2(46, -8), Vector2(46, -128), Color("#8b5e3c"), 6.0, 2.0)
			PetArt.stroke(self, id2, Vector2(46, -124), Vector2(0, -104), Color("#8b5e3c"), 5.0, 2.0)
			draw_line(Vector2(0, -104), Vector2(0, -82), INK, 2.0)
			_box(Vector2(-8, -70), 16, 12, Vector2(5, -5), Color("#b8c0c8"))
			_sign(Vector2(-48, -112), "pickaxe")
		"workshop":
			var d6 := Vector2(24, -26)
			_cast(Vector2(0, -16), 110, 150)
			var hp4 := _house(-54, -16, 92, 64, d6, Color("#e8d4b4"), Color("#7a6a8f"))
			_door(16, -16, 24, 40, Color("#8a6a9e"))
			_window(Vector2(-28, -44), Vector2(22, 20))
			var chp2 := Vector2(hp4["r1"].x + 14, hp4["r1"].y + 34)
			_chimney(chp2, 50, Color("#9a8f88"))
			_smoke_at = chp2 + Vector2(11, -56)
			_box(Vector2(-58, -2), 16, 10, Vector2(5, -5), Color("#5a5468"))
			_box(Vector2(-55, -12), 22, 6, Vector2(5, -5), Color("#5a5468"))
			PetArt.blob(self, Transform2D.IDENTITY, Vector2(30, -96), Vector2(14, 14), Color("#c9ced4"), 0.0, OW, false)
			for k in 8:
				var a := TAU * k / 8.0
				PetArt.blob(self, Transform2D.IDENTITY, Vector2(30, -96) + Vector2(cos(a), sin(a)) * 15.0, Vector2(4, 4), Color("#c9ced4"), 0.0, 1.5, false)
			PetArt.blob(self, Transform2D.IDENTITY, Vector2(30, -96), Vector2(5, 5), Color("#7a6a8f"), 0.0, 1.5, false)
		"market":
			var d7 := Vector2(18, -20)
			_cast(Vector2(0, -10), w, 120)
			for x: float in [-54.0, 40.0]:
				PetArt.stroke(self, Transform2D.IDENTITY, Vector2(x, -8), Vector2(x, -110), Color("#8b5e3c"), 6.0, 2.0)
			_box(Vector2(-58, -10), 108, 36, d7, Color("#c98b5a"), Color("#e0a676"))
			for k in 4:
				var r: String = Data.RES_ORDER[k]
				PortraitView.draw_res(self, Vector2(-38 + k * 26, -54), r, 10.0)
			_awning(-66, 56, -102, d7, 30, Color("#4fb6dd"), Color("#fff3e0"), 4)
			_box(Vector2(-62, 4), 20, 16, Vector2(6, -6), Color("#b07a45"))
			_box(Vector2(40, 4), 20, 14, Vector2(6, -6), Color("#b07a45"))
		"fishing_dock":
			for k in 6:
				_box(Vector2(-w / 2.0 + 4, -h + 26 + k * 19), w - 22, 4, Vector2(14, -14), Color("#c08a55").lightened(0.05 * (k % 2)), Color(0, 0, 0, 0), 1.6)
			for x: float in [-56.0, 42.0]:
				PetArt.stroke(self, Transform2D.IDENTITY, Vector2(x, -h + 18), Vector2(x, 8), Color("#6e4a2e"), 7.0, 2.0)
			var d8 := Vector2(16, -16)
			_house(-34, -h + 74, 50, 36, d8, Color("#eef3f7"), Color("#3fa9d6"))
			PetArt.stroke(self, Transform2D.IDENTITY, Vector2(26, -46), Vector2(56, -46), Color("#7a5235"), 3.0, 1.2)
			for k in 2:
				var f := Vector2(34 + k * 14, -38)
				PetArt.blob(self, Transform2D.IDENTITY, f, Vector2(4, 8), Color("#4fb6dd"), 0.0, 1.5, false)
			_sign(Vector2(-42, -32), "rod")
		"explorer_lodge":
			var d9 := Vector2(26, -26)
			_cast(Vector2(0, -12), 110, 130)
			var a1 := Vector2(-56, -12)
			var a2 := Vector2(30, -12)
			var apex := Vector2(-13, -118)
			_side(_pv([a2, a2 + d9, apex + d9, apex]), Color("#c9a978"))
			_front(_pv([a1, a2, apex]), Color("#e6cfa0"))
			_front(_pv([Vector2(-26, -12), Vector2(0, -12), Vector2(-13, -56)]), Color("#6b4f3a"), 2.0)
			for k in 3:
				var f2 := float(k + 1) / 4.0
				draw_line(a1.lerp(apex, f2), a2.lerp(apex, f2), Color("#b8996a"), 2.0)
			PetArt.stroke(self, Transform2D.IDENTITY, apex + d9, apex + d9 + Vector2(0, -44), Color("#6b4f3a"), 3.0, 1.2)
			_sign(Vector2(44, -30), "compass")
			_box(Vector2(-60, -2), 18, 14, Vector2(5, -5), Color("#8b5e3c"))
		"crystal_mine":
			var id3 := Transform2D.IDENTITY
			_cast(Vector2(0, -20), w, 90)
			PetArt.blob(self, id3, Vector2(0, -50), Vector2(64, 54), Color("#8a8f96"), 0.0, OW, true, 1.3)
			PetArt.blob(self, id3, Vector2(-14, -70), Vector2(36, 26), Color("#9aa0a6"), 0.0, 0.0, false, 1.3)
			_front(_pv([Vector2(-24, -8), Vector2(24, -8), Vector2(24, -58), Vector2(-24, -58)]), Color("#2b2630"))
			for x: float in [-26.0, 22.0]:
				_box(Vector2(x, -6), 6, 56, Vector2(4, -4), Color("#8b5e3c"))
			_box(Vector2(-30, -58), 62, 8, Vector2(4, -4), Color("#a0703f"))
			draw_line(Vector2(-18, -8), Vector2(18, -8), Color("#6e4a2e"), 3.0)
			_crystal(Vector2(44, -36), 34, Color("#c58cff"), 0.2)
			_crystal(Vector2(-46, -26), 26, Color("#b48cff"), -0.3)
			_crystal(Vector2(10, -96), 24, Color("#e0c2ff"), 0.1)
		"path":
			var r0 := Rect2(Vector2(-T / 2.0, -T), Vector2(T, T))
			draw_rect(r0.grow(-1), Color("#c9a86a"))
			draw_rect(r0.grow(-3), Color("#ecd9a8"))
			for k in 5:
				var c2 := Vector2(-18 + (k % 3) * 18, -46 + (k / 3) * 26) + Vector2(WorldMap.hash01(Vector2i(bid, k)) * 6.0, 0)
				PetArt.ell(self, Transform2D.IDENTITY, c2 + Vector2(1.5, 2.5), Vector2(10, 7), Color("#c9ad74"))
				PetArt.ell(self, Transform2D.IDENTITY, c2, Vector2(10, 7), Color("#f6e7bf"))
		"flower_bed":
			PetArt.soft(self, Vector2(4, -6), Vector2(30, 9), 0.3)
			_box(Vector2(-24, -8), 42, 12, Vector2(8, -8), Color("#8b5e3c"), Color("#5e3d24"))
			var cols := [Color("#ff8fa3"), Color("#ffd23f"), Color("#ffffff"), Color("#b48cff")]
			for k in 5:
				var c3 := Vector2(-18 + k * 9, -26 + (k % 2) * 4)
				draw_line(c3, c3 + Vector2(0, 8), Color("#3f8f3a"), 2.0)
				for q in 5:
					var a3 := TAU * q / 5.0
					draw_circle(c3 + Vector2(cos(a3), sin(a3)) * 3.6, 3.6, INK)
				for q in 5:
					var a4 := TAU * q / 5.0
					draw_circle(c3 + Vector2(cos(a4), sin(a4)) * 3.6, 2.7, cols[(k + bid) % cols.size()])
				draw_circle(c3, 2.0, Color("#ffb347"))
		"sapling":
			var id4 := Transform2D.IDENTITY
			PetArt.cast(self, Vector2(0, -8), 36, 70, 0.22)
			PetArt.soft(self, Vector2(0, -8), Vector2(16, 5), 0.4)
			PetArt.shape(self, id4, [Vector2(-4, -8), Vector2(-3, -40), Vector2(3, -40), Vector2(4, -8)], Color("#9a6440"), 2.0)
			for b in [[-10, -46, 14], [10, -46, 14], [0, -60, 18]]:
				PetArt.blob(self, id4, Vector2(b[0], b[1]), Vector2(b[2], b[2]), Color("#6cbd5a"), 0.0, 2.2, true, 1.3)
		"lamp":
			PetArt.cast(self, Vector2(0, -8), 20, 100, 0.2)
			PetArt.soft(self, Vector2(0, -8), Vector2(12, 4), 0.4)
			PetArt.stroke(self, Transform2D.IDENTITY, Vector2(0, -8), Vector2(0, -84), Color("#4a4458"), 6.0, 2.0)
			_box(Vector2(-10, -84), 20, 22, Vector2(5, -5), Color("#4a4458"))
			draw_rect(Rect2(Vector2(-6, -102), Vector2(12, 14)), Color("#ffd966"))
			var cap := _pv([Vector2(-14, -106), Vector2(16, -106), Vector2(3, -118)])
			PetArt.outline(self, cap, 2.0)
			draw_colored_polygon(cap, Color("#5a5468"))
		"fountain":
			var id5 := Transform2D.IDENTITY
			_cast(Vector2(0, -20), w * 0.9, 60)
			PetArt.blob(self, id5, Vector2(0, -50), Vector2(58, 32), Color("#c9ced4"), 0.0, OW, false)
			PetArt.ell(self, id5, Vector2(0, -54), Vector2(48, 23), Color("#9aa3ad"))
			PetArt.ell(self, id5, Vector2(0, -50), Vector2(46, 20), Color("#5fb8de"))
			PetArt.ell(self, id5, Vector2(-10, -54), Vector2(26, 8), Color("#a8e3f5"))
			_box(Vector2(-8, -54), 16, 44, Vector2(5, -5), Color("#c9ced4"))
			PetArt.blob(self, id5, Vector2(2, -100), Vector2(20, 8), Color("#c9ced4"), 0.0, OW, false)
		"statue":
			_cast(Vector2(0, -16), w * 0.8, 150)
			_box(Vector2(-44, -10), 82, 30, Vector2(12, -12), Color("#c9ced4"))
			_box(Vector2(-36, -40), 66, 12, Vector2(10, -10), Color("#dfe3e8"))
			var best := ""
			var best_lvl := 0
			for p in Game.pets:
				if int(p["level"]) > best_lvl:
					best_lvl = int(p["level"])
					best = p["species"]
			if best != "":
				PetArt.draw_pet(self, Vector2(2, -86), best, 1, false, 0.0, 26.0, 1.0, true, Color("#b9c0c8"))


# ================================================================ animated layer

func _draw_fx() -> void:
	if not _built():
		return
	PetArt.fast = true
	var f := _fx
	match type:
		"house", "workshop":
			if _smoke_at == Vector2.INF:
				return
			var base := _smoke_at
			for k in 3:
				var ph := fmod(t * 0.6 + k / 3.0, 1.0)
				var p := base + Vector2(ph * 22.0 + sin(t + k) * 3.0, -ph * 52.0)
				var r := 5.0 + ph * 9.0
				f.draw_circle(p, r + 2.0, Color(INK, 0.5 * (1.0 - ph)))
				f.draw_circle(p, r, Color(1, 1, 1, 0.85 * (1.0 - ph)))
		"town_hall":
			for i in Game.town_level:
				var fx := -70.0 + i * 20.0
				var top := Vector2(fx, -144)
				f.draw_line(top + Vector2(0, 34), top, INK, 3.0)
				var wave := sin(t * 4.0 + i) * 3.0
				var flag := _pv([top, top + Vector2(16, 5 + wave), top + Vector2(0, 11)])
				PetArt.outline(f, flag, 1.6)
				f.draw_colored_polygon(flag, Color("#ff8a65"))
		"lamp":
			var flick := 0.85 + 0.15 * sin(t * 9.0 + bid)
			var r2 := 60.0 * flick
			f.draw_texture_rect(PetArt.soft_texture(), Rect2(Vector2(0, -96) - Vector2(r2, r2), Vector2(r2, r2) * 2.0), false, Color(1.0, 0.85, 0.45, 0.35))
		"fountain":
			for k in 8:
				var a := TAU * k / 8.0 + t * 0.5
				var ph2 := fmod(t * 1.4 + k * 0.13, 1.0)
				var p2 := Vector2(2, -108) + Vector2(cos(a) * 34.0 * ph2, -26.0 * sin(ph2 * PI) + 52.0 * ph2 * ph2 * 0.6 + sin(a) * 10.0 * ph2)
				f.draw_circle(p2, 3.4, Color(0.75, 0.93, 1.0, 0.95))
			var ring := fmod(t * 0.8, 1.0)
			f.draw_arc(Vector2(0, -50), 20.0 + 24.0 * ring, 0, TAU, 32, Color(1, 1, 1, 0.5 * (1.0 - ring)), 2.0, true)
		"nest":
			var nest_eggs := Game.eggs_at("nest")
			for i in mini(nest_eggs.size(), 3):
				var e: Dictionary = nest_eggs[i]
				PetArt.draw_egg(f, Vector2(-22 + 22 * i, -62), e["type"], 12.0, t, Game.egg_ratio(e), false)
			# front lip of the nest over the eggs
			var lip := PackedVector2Array()
			for i in 17:
				var a2 := lerpf(0.0, PI, float(i) / 16.0)
				lip.append(Vector2(cos(a2) * 58.0, -50.0 + sin(a2) * 30.0))
			for i in 17:
				var a3 := lerpf(PI, 0.0, float(i) / 16.0)
				lip.append(Vector2(cos(a3) * 46.0, -50.0 + sin(a3) * 16.0))
			f.draw_colored_polygon(lip, Color("#b88a58"))
			for i in 9:
				var a4 := lerpf(0.2, PI - 0.2, float(i) / 8.0)
				var q := Vector2(cos(a4) * 52.0, -50.0 + sin(a4) * 23.0)
				f.draw_line(q - Vector2(6, 2), q + Vector2(6, -2), Color("#e3c28a"), 3.0, true)
		"crystal_mine":
			var g := 0.5 + 0.5 * sin(t * 2.5)
			f.draw_texture_rect(PetArt.soft_texture(), Rect2(Vector2(-30, -60), Vector2(60, 50)), false, Color(0.8, 0.6, 1.0, 0.25 + 0.2 * g))
			PetArt.sparkle(f, Vector2(44, -70) + Vector2(0, sin(t * 2.0) * 3.0), 6.0 * (0.6 + 0.4 * g), Color(1, 1, 1, 0.95))
		"kiosk":
			var types := ["meadow", "tide", "ember", "aurora"]
			for i in 4:
				PetArt.draw_egg(f, Vector2(-38 + 24 * i, -60 + sin(t * 3.0 + i) * 2.0), types[i], 10.0, t, 0.0, false)
		"explorer_lodge":
			var top2 := Vector2(13, -188)
			var wave2 := sin(t * 4.0) * 3.0
			var flag2 := _pv([top2, top2 + Vector2(26, 7 + wave2), top2 + Vector2(0, 16)])
			PetArt.outline(f, flag2, 1.6)
			f.draw_colored_polygon(flag2, Color("#e46a5a"))
