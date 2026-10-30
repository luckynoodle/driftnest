extends Node2D
## A y-sorted world object (trees, buildings, lanterns...). Origin is at its base.

var kind := "tree"
var main = null
var station := -1
var variant := 0.0
var t := 0.0
var animated := false


func _ready() -> void:
	animated = kind in ["mill", "lantern", "mailbox", "kiosk", "post", "berry_bush"]


func _process(delta: float) -> void:
	if animated:
		t += delta
		queue_redraw()


func _shadow(r: Vector2) -> void:
	PetArt.ell(self, Transform2D.IDENTITY, Vector2.ZERO, r, Color(0, 0, 0, 0.16))


func _is_active() -> bool:
	return main != null and station >= 0 and int(main.active) == station


func _draw() -> void:
	match kind:
		"tree": _tree()
		"pine": _pine()
		"bush": _bush(Color("#6cbd5a"), false)
		"berry_bush": _bush(Color("#4f9e4a"), true)
		"rock": _rock()
		"mill": _mill()
		"kiosk": _kiosk()
		"post": _post()
		"mailbox": _mailbox()
		"lantern": _lantern()
		"pool_rock": _pool_rock()


func _tree() -> void:
	var k := 0.85 + variant * 0.35
	_shadow(Vector2(46, 14) * k)
	draw_rect(Rect2(Vector2(-8, -52) * k, Vector2(16, 52) * k), Color("#8b5e3c"))
	draw_circle(Vector2(0, -84) * k, 40 * k, Color("#5fae4f"))
	draw_circle(Vector2(-28, -64) * k, 28 * k, Color("#6cbd5a"))
	draw_circle(Vector2(28, -64) * k, 28 * k, Color("#6cbd5a"))
	draw_circle(Vector2(-12, -96) * k, 16 * k, Color("#86d16f"))
	if variant > 0.7:
		for p in [Vector2(-20, -78), Vector2(14, -92), Vector2(24, -66)]:
			draw_circle(p * k, 5 * k, Color("#ff8fa3"))


func _pine() -> void:
	var k := 0.85 + variant * 0.4
	_shadow(Vector2(36, 11) * k)
	draw_rect(Rect2(Vector2(-6, -24) * k, Vector2(12, 24) * k), Color("#7a5235"))
	for i in 3:
		var y := -24.0 - 30.0 * i
		var w := 44.0 - 10.0 * i
		draw_colored_polygon(PackedVector2Array([Vector2(-w, y) * k, Vector2(w, y) * k, Vector2(0, y - 52) * k]),
			Color("#3f8f5a").lightened(0.06 * i))


func _bush(col: Color, berries: bool) -> void:
	var k := 0.8 + variant * 0.4
	_shadow(Vector2(34, 10) * k)
	draw_circle(Vector2(-16, -18) * k, 20 * k, col)
	draw_circle(Vector2(16, -18) * k, 20 * k, col)
	draw_circle(Vector2(0, -30) * k, 24 * k, col.lightened(0.08))
	if berries:
		var glow := 0.15 + (0.25 if _berry_active() else 0.0) * (0.5 + 0.5 * sin(t * 6.0))
		for p in [Vector2(-18, -22), Vector2(-4, -36), Vector2(12, -26), Vector2(20, -14), Vector2(-8, -14), Vector2(4, -46)]:
			draw_circle(p * k, 9 * k, Color(0.6, 0.55, 1.0, glow))
			draw_circle(p * k, 5.5 * k, Color("#6b5cff"))
			draw_circle(p * k + Vector2(-1.5, -1.5), 1.8 * k, Color(1, 1, 1, 0.8))


func _berry_active() -> bool:
	return main != null and int(main.active) >= 0 and str(main.stations[int(main.active)]["id"]) == "grove"


func _rock() -> void:
	var k := 0.7 + variant * 0.6
	_shadow(Vector2(28, 8) * k)
	PetArt.ell(self, Transform2D.IDENTITY, Vector2(0, -12) * k, Vector2(26, 16) * k, Color("#9aa3ad"))
	PetArt.ell(self, Transform2D.IDENTITY, Vector2(-6, -18) * k, Vector2(12, 7) * k, Color("#b8c0c8"))


func _pool_rock() -> void:
	var k := 0.6 + variant * 0.5
	PetArt.ell(self, Transform2D.IDENTITY, Vector2(0, -8) * k, Vector2(24, 14) * k, Color("#8a949e"))
	PetArt.ell(self, Transform2D.IDENTITY, Vector2(-5, -12) * k, Vector2(10, 5) * k, Color("#aab3bb"))
	if variant > 0.5:
		_star(Vector2(8, -14) * k, 8.0 * k, Color("#ff8a65"))


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + TAU * i / 10.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)


func _mill() -> void:
	_shadow(Vector2(60, 16))
	draw_colored_polygon(PackedVector2Array([Vector2(-42, 0), Vector2(42, 0), Vector2(26, -150), Vector2(-26, -150)]), Color("#f3e6d3"))
	draw_colored_polygon(PackedVector2Array([Vector2(-42, 0), Vector2(-30, 0), Vector2(-18, -150), Vector2(-26, -150)]), Color("#e2d2bb"))
	draw_rect(Rect2(Vector2(-12, -40), Vector2(24, 40)), Color("#8b5e3c"))
	draw_circle(Vector2(0, -95), 10, Color("#9fd8f0"))
	draw_colored_polygon(PackedVector2Array([Vector2(-36, -148), Vector2(36, -148), Vector2(0, -196)]), Color("#e46a5a"))
	var spin := 5.0 if _is_active() else 0.7
	var ang := t * spin
	var hub := Vector2(0, -158)
	for i in 4:
		var a := ang + TAU * i / 4.0
		var dir := Vector2(cos(a), sin(a))
		var n := dir.orthogonal()
		var pts := PackedVector2Array([hub + n * 4.0, hub + dir * 100.0 + n * 4.0,
			hub + dir * 100.0 + n * 20.0, hub + dir * 30.0 + n * 20.0])
		draw_colored_polygon(pts, Color("#fffaf0"))
		draw_line(hub, hub + dir * 100.0, Color("#b89f7e"), 4.0, true)
	draw_circle(hub, 9, Color("#8b5e3c"))


func _kiosk() -> void:
	_shadow(Vector2(110, 18))
	draw_line(Vector2(-92, 0), Vector2(-92, -150), Color("#8b5e3c"), 8.0)
	draw_line(Vector2(92, 0), Vector2(92, -150), Color("#8b5e3c"), 8.0)
	draw_rect(Rect2(Vector2(-100, -62), Vector2(200, 62)), Color("#c98b5a"))
	draw_rect(Rect2(Vector2(-100, -62), Vector2(200, 10)), Color("#e0a676"))
	var types := ["meadow", "tide", "ember", "aurora"]
	for i in 4:
		var bounce := sin(t * 3.0 + i) * 2.0
		PetArt.draw_egg(self, Vector2(-66 + 44 * i, -80 + bounce), types[i], 15.0, t, 0.0, false)
	for i in 6:
		var x0 := -110.0 + i * (220.0 / 6.0)
		var x1 := x0 + 220.0 / 6.0
		var col := Color("#ff8a65") if i % 2 == 0 else Color("#fff3e0")
		draw_colored_polygon(PackedVector2Array([Vector2(x0 + 6, -168), Vector2(x1 + 6, -168), Vector2(x1, -128), Vector2(x0, -128)]), col)
		draw_circle(Vector2((x0 + x1) / 2.0, -128), (x1 - x0) / 2.0, col)


func _post() -> void:
	_shadow(Vector2(36, 10))
	draw_rect(Rect2(Vector2(-26, -86), Vector2(52, 86)), Color("#5b6bd6"))
	draw_rect(Rect2(Vector2(-26, -86), Vector2(52, 12)), Color("#4655b8"))
	draw_rect(Rect2(Vector2(-16, -60), Vector2(32, 6)), Color("#2f3a8a"))
	var has_mail: bool = main != null and int(main.mail_target) == -1
	var pulse := 0.5 + 0.5 * sin(t * 4.0)
	_star(Vector2(0, -112), 22.0 + (3.0 * pulse if has_mail else 0.0), Color("#ffd23f") if has_mail else Color("#c9c3a0"))


func _mailbox() -> void:
	var target: bool = main != null and int(main.mail_target) == int(main.stations[station]["index"])
	if target:
		var pulse := 0.5 + 0.5 * sin(t * 4.0)
		draw_rect(Rect2(Vector2(-26, -420), Vector2(52, 420)), Color(1.0, 0.9, 0.4, 0.12 + 0.1 * pulse))
		draw_rect(Rect2(Vector2(-12, -420), Vector2(24, 420)), Color(1.0, 0.95, 0.6, 0.18 + 0.1 * pulse))
	_shadow(Vector2(22, 7))
	draw_rect(Rect2(Vector2(-4, -50), Vector2(8, 50)), Color("#8b5e3c"))
	draw_rect(Rect2(Vector2(-20, -74), Vector2(40, 26)), Color("#e46a5a"))
	draw_circle(Vector2(-20, -61), 13, Color("#e46a5a"))
	draw_line(Vector2(20, -72), Vector2(20, -92), Color("#3b3b3b"), 3.0)
	draw_rect(Rect2(Vector2(20, -92), Vector2(14, 9)), Color("#ffd23f") if target else Color("#9a9a9a"))


func _lantern() -> void:
	var idx := int(main.stations[station]["index"]) if main != null else 0
	var lit: bool = main != null and bool(main.lantern_lit[idx])
	if lit:
		var flick := 0.85 + 0.15 * sin(t * 11.0 + idx)
		draw_circle(Vector2(0, -128), 70 * flick, Color(1.0, 0.82, 0.4, 0.16))
		draw_circle(Vector2(0, -128), 40 * flick, Color(1.0, 0.85, 0.45, 0.25))
	_shadow(Vector2(18, 6))
	draw_rect(Rect2(Vector2(-4, -110), Vector2(8, 110)), Color("#4a4458"))
	draw_rect(Rect2(Vector2(-18, -146), Vector2(36, 36)), Color("#4a4458"))
	draw_rect(Rect2(Vector2(-13, -141), Vector2(26, 26)), Color("#ffd966") if lit else Color("#6d6a80"))
	draw_colored_polygon(PackedVector2Array([Vector2(-22, -146), Vector2(22, -146), Vector2(0, -164)]), Color("#4a4458"))
	if lit:
		draw_circle(Vector2(0, -126 + sin(t * 9.0) * 1.5), 6, Color("#ff9a3d"))
