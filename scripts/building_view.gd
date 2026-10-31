class_name BuildingView
extends Node2D
## Draws one town building. Origin = bottom-centre of its footprint (for y-sorting).
## Also used as the translucent "ghost" while placing a new building.

const T := WorldMap.TILE
const OUTLINE := Color("#4a3a32")

var type := "house"
var bid := -1
var ghost := false
var ghost_ok := true
var t := 0.0
var _var := 0.0


func setup(b_type: String, b_id: int) -> void:
	type = b_type
	bid = b_id
	_var = WorldMap.hash01(Vector2i(b_id, 7))
	if type == "path":
		z_index = -1


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _b() -> Dictionary:
	return {} if bid < 0 else Game.find_building(bid)


func _size() -> Vector2i:
	return Data.BUILDINGS[type]["size"]


func _draw() -> void:
	var sz := Vector2(_size()) * T
	if ghost:
		var col := Color(0.4, 0.9, 0.4, 0.35) if ghost_ok else Color(1.0, 0.35, 0.3, 0.35)
		draw_rect(Rect2(Vector2(-sz.x / 2.0, -sz.y), sz), col)
		draw_rect(Rect2(Vector2(-sz.x / 2.0, -sz.y), sz), Color(col, 0.9), false, 3.0)
		modulate = Color(1, 1, 1, 0.7)
	var b := _b()
	if not ghost and not b.is_empty() and not bool(b["built"]):
		_construction(sz, b)
		return
	_draw_type(sz)


func _construction(sz: Vector2, b: Dictionary) -> void:
	var w := sz.x
	draw_rect(Rect2(Vector2(-w / 2.0 + 6, -sz.y + 6), sz - Vector2(12, 12)), Color("#c9a978"))
	draw_rect(Rect2(Vector2(-w / 2.0 + 6, -sz.y + 6), sz - Vector2(12, 12)), Color("#9b7a4f"), false, 3.0)
	var ratio := clampf(float(b["progress"]) / float(Data.BUILDINGS[type]["work"]), 0.0, 1.0)
	if sz.x >= T * 2.0:
		# scaffolding rising with progress
		var h := 30.0 + 90.0 * ratio
		var top := -sz.y * 0.35 - h
		for x in [-w / 2.0 + 18, w / 2.0 - 18, 0.0]:
			draw_line(Vector2(x, -12), Vector2(x, top), Color("#a87b4f"), 5.0)
		for k in int(2 + ratio * 3):
			var y := -12.0 - (h + sz.y * 0.35 - 12.0) * float(k + 1) / 5.0
			draw_line(Vector2(-w / 2.0 + 14, y), Vector2(w / 2.0 - 14, y), Color("#c08a55"), 6.0)
		# a crate and planks
		draw_rect(Rect2(Vector2(w / 2.0 - 40, -36), Vector2(26, 24)), Color("#b07a45"))
		draw_rect(Rect2(Vector2(w / 2.0 - 40, -36), Vector2(26, 24)), Color("#7a5235"), false, 2.0)
	# progress bar
	var bw := minf(w - 16.0, 110.0)
	var bp := Vector2(-bw / 2.0, -sz.y - 22.0)
	draw_rect(Rect2(bp, Vector2(bw, 12)), Color(1, 1, 1, 0.9))
	draw_rect(Rect2(bp + Vector2(2, 2), Vector2((bw - 4.0) * ratio, 8)), Color("#ffb347"))


# ---------------------------------------------------------------- helpers

func _shadow(w: float) -> void:
	PetArt.ell(self, Transform2D.IDENTITY, Vector2(0, -6), Vector2(w * 0.55, 14), Color(0, 0, 0, 0.14))


func _cottage(w: float, wall_h: float, base_y: float, wall: Color, roof: Color, door: Color = Color("#8b5e3c")) -> void:
	var x0 := -w / 2.0
	draw_rect(Rect2(Vector2(x0, base_y - wall_h), Vector2(w, wall_h)), wall)
	draw_rect(Rect2(Vector2(x0, base_y - wall_h), Vector2(w, wall_h)), wall.darkened(0.25), false, 2.0)
	var roof_pts := PackedVector2Array([Vector2(x0 - 12, base_y - wall_h + 4), Vector2(-x0 + 12, base_y - wall_h + 4),
		Vector2(0, base_y - wall_h - w * 0.5)])
	draw_colored_polygon(roof_pts, roof)
	draw_polyline(PackedVector2Array([roof_pts[0], roof_pts[2], roof_pts[1]]), roof.darkened(0.25), 3.0, true)
	draw_rect(Rect2(Vector2(-10, base_y - 34), Vector2(20, 34)), door)
	draw_circle(Vector2(5, base_y - 17), 2.0, Color("#ffd23f"))


func _window(c: Vector2, s: float = 16.0, lit: bool = false) -> void:
	draw_rect(Rect2(c - Vector2(s, s) / 2.0, Vector2(s, s)), Color("#ffe9a8") if lit else Color("#9fd8f0"))
	draw_rect(Rect2(c - Vector2(s, s) / 2.0, Vector2(s, s)), Color("#ffffff"), false, 2.0)
	draw_line(c - Vector2(0, s / 2.0), c + Vector2(0, s / 2.0), Color.WHITE, 2.0)


func _sign(c: Vector2, kind: String) -> void:
	draw_circle(c, 15.0, Color("#fff7ec"))
	draw_arc(c, 15.0, 0.0, TAU, 24, Color("#8b5e3c"), 3.0, true)
	PetArt.draw_tool(self, c, kind, 0, 9.0)


func _log(c: Vector2, length: float, r: float) -> void:
	draw_rect(Rect2(c - Vector2(length / 2.0, r), Vector2(length, r * 2.0)), Color("#a8794f"))
	draw_circle(c + Vector2(length / 2.0, 0), r, Color("#e8c99a"))
	draw_arc(c + Vector2(length / 2.0, 0), r * 0.55, 0.0, TAU, 16, Color("#c09a6b"), 1.5, true)


func _rockpile(c: Vector2, k: float, col: Color = Color("#9aa3ad")) -> void:
	PetArt.ell(self, Transform2D.IDENTITY, c, Vector2(22, 13) * k, col)
	PetArt.ell(self, Transform2D.IDENTITY, c + Vector2(-16, 6) * k, Vector2(14, 9) * k, col.darkened(0.1))
	PetArt.ell(self, Transform2D.IDENTITY, c + Vector2(-5, -6) * k, Vector2(9, 5) * k, col.lightened(0.2))


func _crystal(c: Vector2, h: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(-h * 0.25, 0), c + Vector2(0, -h), c + Vector2(h * 0.25, 0)]), col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h), c + Vector2(h * 0.25, 0), c + Vector2(0.05 * h, 0)]), col.lightened(0.3))


# ---------------------------------------------------------------- types

func _draw_type(sz: Vector2) -> void:
	var w := sz.x
	var h := sz.y
	match type:
		"town_hall":
			_shadow(w)
			draw_rect(Rect2(Vector2(-w / 2.0 + 8, -h + 30), Vector2(w - 16, h - 36)), Color("#d9cbb0"))
			_cottage(w - 40, 120, -14, Color("#f3e6d3"), Color("#4f7fc9"))
			_window(Vector2(-48, -80), 20, true)
			_window(Vector2(48, -80), 20, true)
			# clock tower
			draw_rect(Rect2(Vector2(-22, -250), Vector2(44, 90)), Color("#f3e6d3"))
			draw_rect(Rect2(Vector2(-22, -250), Vector2(44, 90)), Color("#c9b89a"), false, 2.0)
			draw_colored_polygon(PackedVector2Array([Vector2(-30, -248), Vector2(30, -248), Vector2(0, -290)]), Color("#3d63a3"))
			draw_circle(Vector2(0, -215), 14, Color.WHITE)
			draw_arc(Vector2(0, -215), 14, 0, TAU, 24, Color("#4a3a32"), 2.0, true)
			draw_line(Vector2(0, -215), Vector2(0, -225), OUTLINE, 2.0)
			draw_line(Vector2(0, -215), Vector2(7, -215), OUTLINE, 2.0)
			# one flag per town level
			for i in Game.town_level:
				var fx := -w / 2.0 + 20 + i * 18.0
				draw_line(Vector2(fx, -30), Vector2(fx, -64), Color("#6b4f3a"), 2.0)
				var wave := sin(t * 4.0 + i) * 2.0
				draw_colored_polygon(PackedVector2Array([Vector2(fx, -64), Vector2(fx + 14, -59 + wave), Vector2(fx, -54)]), Color("#ff8a65"))
		"nest":
			_shadow(w)
			var id := Transform2D.IDENTITY
			PetArt.ell(self, id, Vector2(0, -50), Vector2(58, 30), Color("#a87b4f"))
			PetArt.ell(self, id, Vector2(0, -54), Vector2(46, 20), Color("#7a5535"))
			PetArt.ell(self, id, Vector2(0, -50), Vector2(40, 15), Color("#f6e7c8"))
			var nest_eggs := Game.eggs_at("nest")
			for i in mini(nest_eggs.size(), 3):
				var e: Dictionary = nest_eggs[i]
				PetArt.draw_egg(self, Vector2(-22 + 22 * i, -60), e["type"], 11.0, t, Game.egg_ratio(e), false)
			for i in 14:
				var a := float(i) / 14.0 * TAU
				var q := Vector2(cos(a) * 54, -50 + sin(a) * 26)
				var d := Vector2(cos(a + 1.4), sin(a + 1.4) * 0.45) * 12.0
				draw_line(q - d, q + d, Color("#d9b27a"), 3.0, true)
		"kiosk":
			_shadow(w)
			draw_line(Vector2(-54, -8), Vector2(-54, -120), Color("#8b5e3c"), 6.0)
			draw_line(Vector2(54, -8), Vector2(54, -120), Color("#8b5e3c"), 6.0)
			draw_rect(Rect2(Vector2(-60, -52), Vector2(120, 44)), Color("#c98b5a"))
			draw_rect(Rect2(Vector2(-60, -52), Vector2(120, 8)), Color("#e0a676"))
			var types := ["meadow", "tide", "ember", "aurora"]
			for i in 4:
				PetArt.draw_egg(self, Vector2(-39 + 26 * i, -64 + sin(t * 3.0 + i) * 2.0), types[i], 10.0, t, 0.0, false)
			for i in 5:
				var x0 := -66.0 + i * 26.4
				var col := Color("#ff8a65") if i % 2 == 0 else Color("#fff3e0")
				draw_colored_polygon(PackedVector2Array([Vector2(x0 + 4, -136), Vector2(x0 + 30, -136), Vector2(x0 + 26.4, -108), Vector2(x0, -108)]), col)
				draw_circle(Vector2(x0 + 13.2, -108), 13.2, col)
		"builder_hut":
			_shadow(w)
			_cottage(84, 60, -16, Color("#e9cfa6"), Color("#c96a4a"))
			_sign(Vector2(30, -66), "hammer")
			for k in 3:
				draw_rect(Rect2(Vector2(-w / 2.0 + 4, -18 - k * 7), Vector2(34, 6)), Color("#d4a76a"))
		"house":
			_shadow(w)
			var roofs := [Color("#e46a5a"), Color("#4f7fc9"), Color("#5aa64a"), Color("#9a6bff"), Color("#e8960c")]
			var walls := [Color("#f7ead6"), Color("#fff3e0"), Color("#f0e0d0"), Color("#e9f1f7")]
			var roof: Color = roofs[int(_var * roofs.size()) % roofs.size()]
			var wall: Color = walls[int(_var * 17.0) % walls.size()]
			_cottage(96, 66, -16, wall, roof)
			_window(Vector2(-28, -50), 16, true)
			_window(Vector2(28, -50), 16, true)
			draw_rect(Rect2(Vector2(20, -136), Vector2(14, 30)), Color("#a65a4a"))
			if fmod(t, 3.0) < 2.2:
				var sp := fmod(t, 3.0)
				draw_circle(Vector2(27 + sp * 6.0, -146 - sp * 14.0), 5.0 + sp * 2.0, Color(1, 1, 1, 0.5 - sp * 0.2))
		"lumber_camp":
			_shadow(w)
			_cottage(70, 52, -50, Color("#c08a55"), Color("#6b8f4a"))
			_sign(Vector2(0, -126), "axe")
			for k in 3:
				_log(Vector2(-22 + k * 4.0, -16 - k * 12.0), 50, 6.5)
			_log(Vector2(26, -14), 40, 6.5)
			PetArt.ell(self, Transform2D.IDENTITY, Vector2(42, -30), Vector2(14, 6), Color("#c99a6d"))
		"berry_farm":
			_shadow(w)
			for row in 2:
				for k in 3:
					var c := Vector2(-38 + 38 * k, -82 + row * 46)
					draw_circle(c, 18, Color("#4f9e4a"))
					draw_circle(c + Vector2(0, -6), 14, Color("#5fae4f"))
					for q in [Vector2(-7, -4), Vector2(6, -9), Vector2(5, 4), Vector2(-4, 6)]:
						draw_circle(c + q, 4.0, Color("#6b5cff"))
			for x in [-60.0, -20.0, 20.0, 60.0]:
				draw_line(Vector2(x, -4), Vector2(x, -26), Color("#a87b4f"), 4.0)
			draw_line(Vector2(-62, -18), Vector2(62, -18), Color("#c08a55"), 4.0)
			_sign(Vector2(54, -112), "basket")
		"quarry":
			_shadow(w)
			PetArt.ell(self, Transform2D.IDENTITY, Vector2(0, -64), Vector2(58, 44), Color("#8a8f96"))
			PetArt.ell(self, Transform2D.IDENTITY, Vector2(0, -62), Vector2(44, 32), Color("#6d737a"))
			for k in 3:
				draw_rect(Rect2(Vector2(-40 + k * 26, -30), Vector2(22, 18)), Color("#b8c0c8"))
				draw_rect(Rect2(Vector2(-40 + k * 26, -30), Vector2(22, 18)), Color("#8a949e"), false, 2.0)
			draw_line(Vector2(40, -10), Vector2(40, -120), Color("#8b5e3c"), 5.0)
			draw_line(Vector2(40, -118), Vector2(-4, -100), Color("#8b5e3c"), 4.0)
			var sw := sin(t * 1.5) * 4.0
			draw_line(Vector2(-4, -100), Vector2(-4 + sw, -76), Color("#4a4458"), 2.0)
			draw_rect(Rect2(Vector2(-12 + sw, -76), Vector2(16, 12)), Color("#b8c0c8"))
			_sign(Vector2(-46, -116), "pickaxe")
		"workshop":
			_shadow(w)
			_cottage(104, 68, -16, Color("#d9c2a0"), Color("#7a6a8f"))
			_window(Vector2(-30, -52), 18, true)
			draw_rect(Rect2(Vector2(26, -150), Vector2(16, 40)), Color("#8a7f78"))
			var sp2 := fmod(t, 2.5)
			draw_circle(Vector2(34 + sp2 * 5.0, -158 - sp2 * 16.0), 6.0 + sp2 * 3.0, Color(0.85, 0.85, 0.85, 0.6 - sp2 * 0.22))
			# anvil
			draw_rect(Rect2(Vector2(46, -26), Vector2(20, 10)), Color("#4a4458"))
			draw_rect(Rect2(Vector2(50, -16), Vector2(12, 12)), Color("#4a4458"))
			_sign(Vector2(30, -54), "hammer")
		"market":
			_shadow(w)
			draw_rect(Rect2(Vector2(-56, -50), Vector2(112, 40)), Color("#c98b5a"))
			for k in 4:
				var r: String = Data.RES_ORDER[k]
				draw_circle(Vector2(-40 + k * 27, -56), 9, Color(Data.RESOURCES[r]["color"]))
			draw_line(Vector2(-56, -10), Vector2(-56, -112), Color("#8b5e3c"), 5.0)
			draw_line(Vector2(56, -10), Vector2(56, -112), Color("#8b5e3c"), 5.0)
			for i in 4:
				var x0 := -64.0 + i * 32.0
				var col := Color("#4fb6dd") if i % 2 == 0 else Color("#fff3e0")
				draw_colored_polygon(PackedVector2Array([Vector2(x0, -130), Vector2(x0 + 32, -130), Vector2(x0 + 32, -104), Vector2(x0, -104)]), col)
				draw_circle(Vector2(x0 + 16, -104), 16, col)
			draw_rect(Rect2(Vector2(-60, -24), Vector2(22, 18)), Color("#b07a45"))
			draw_rect(Rect2(Vector2(40, -22), Vector2(20, 16)), Color("#b07a45"))
		"fishing_dock":
			for k in 6:
				draw_rect(Rect2(Vector2(-w / 2.0 + 4, -h + 8 + k * 20), Vector2(w - 8, 17)), Color("#c08a55").lightened(0.05 * (k % 2)))
			for x in [-56.0, 56.0]:
				draw_line(Vector2(x, -h + 6), Vector2(x, -2), Color("#7a5235"), 6.0)
			_cottage(54, 40, -h + 70, Color("#e9f1f7"), Color("#3fa9d6"))
			draw_line(Vector2(30, -40), Vector2(60, -40), Color("#7a5235"), 3.0)
			for k in 2:
				var f := Vector2(38 + k * 14, -34 + sin(t * 2.0 + k) * 1.5)
				PetArt.ell(self, Transform2D.IDENTITY, f + Vector2(0, 6), Vector2(4, 8), Color("#4fb6dd"))
			_sign(Vector2(-40, -30), "rod")
		"explorer_lodge":
			_shadow(w)
			draw_colored_polygon(PackedVector2Array([Vector2(-58, -12), Vector2(58, -12), Vector2(0, -120)]), Color("#c9a978"))
			draw_colored_polygon(PackedVector2Array([Vector2(-14, -12), Vector2(14, -12), Vector2(0, -50)]), Color("#6b4f3a"))
			draw_line(Vector2(0, -120), Vector2(0, -160), Color("#6b4f3a"), 3.0)
			var wave := sin(t * 4.0) * 3.0
			draw_colored_polygon(PackedVector2Array([Vector2(0, -160), Vector2(28, -152 + wave), Vector2(0, -144)]), Color("#e46a5a"))
			_sign(Vector2(42, -40), "compass")
		"crystal_mine":
			_shadow(w)
			PetArt.ell(self, Transform2D.IDENTITY, Vector2(0, -50), Vector2(62, 54), Color("#7a7f86"))
			PetArt.ell(self, Transform2D.IDENTITY, Vector2(-8, -64), Vector2(40, 32), Color("#8f959c"))
			draw_rect(Rect2(Vector2(-22, -56), Vector2(44, 46)), Color("#2b2630"))
			draw_rect(Rect2(Vector2(-26, -60), Vector2(52, 8)), Color("#8b5e3c"))
			draw_line(Vector2(-24, -52), Vector2(-24, -10), Color("#8b5e3c"), 6.0)
			draw_line(Vector2(24, -52), Vector2(24, -10), Color("#8b5e3c"), 6.0)
			var glow := 0.6 + 0.4 * sin(t * 3.0)
			_crystal(Vector2(40, -40), 34, Color("#c58cff"))
			_crystal(Vector2(-44, -30), 26, Color("#b48cff"))
			_crystal(Vector2(10, -96), 22, Color("#e0c2ff"))
			draw_circle(Vector2(0, -30), 10, Color(0.8, 0.6, 1.0, 0.3 * glow))
		"path":
			draw_rect(Rect2(Vector2(-T / 2.0, -T), Vector2(T, T)), Color("#e2cf9a"))
			for k in 4:
				var c2 := Vector2(-16 + (k % 2) * 32, -48 + (k / 2) * 32) + Vector2(WorldMap.hash01(Vector2i(bid, k)) * 6.0, 0)
				PetArt.ell(self, Transform2D.IDENTITY, c2, Vector2(12, 9), Color("#d4c08a"))
		"flower_bed":
			PetArt.ell(self, Transform2D.IDENTITY, Vector2(0, -24), Vector2(28, 16), Color("#8b5e3c"))
			var cols := [Color("#ff8fa3"), Color("#ffd23f"), Color("#ffffff"), Color("#b48cff")]
			for k in 5:
				var c3 := Vector2(-18 + k * 9, -28 + (k % 2) * 8)
				draw_line(c3, c3 + Vector2(0, 8), Color("#5aa64a"), 2.0)
				for q in 5:
					var a2 := TAU * q / 5.0
					draw_circle(c3 + Vector2(cos(a2), sin(a2)) * 3.5, 3.0, cols[(k + bid) % cols.size()])
				draw_circle(c3, 2.0, Color("#ffb347"))
		"sapling":
			PetArt.ell(self, Transform2D.IDENTITY, Vector2(0, -8), Vector2(22, 7), Color(0, 0, 0, 0.15))
			draw_rect(Rect2(Vector2(-4, -40), Vector2(8, 32)), Color("#8b5e3c"))
			draw_circle(Vector2(0, -56), 22, Color("#6cbd5a"))
			draw_circle(Vector2(-10, -48), 14, Color("#7cc95a"))
			draw_circle(Vector2(10, -64), 10, Color("#86d16f"))
		"lamp":
			var flick := 0.85 + 0.15 * sin(t * 9.0 + bid)
			draw_circle(Vector2(0, -92), 44 * flick, Color(1.0, 0.85, 0.45, 0.16))
			PetArt.ell(self, Transform2D.IDENTITY, Vector2(0, -8), Vector2(14, 5), Color(0, 0, 0, 0.15))
			draw_rect(Rect2(Vector2(-3, -82), Vector2(6, 74)), Color("#4a4458"))
			draw_rect(Rect2(Vector2(-12, -104), Vector2(24, 24)), Color("#4a4458"))
			draw_rect(Rect2(Vector2(-8, -100), Vector2(16, 16)), Color("#ffd966"))
			draw_colored_polygon(PackedVector2Array([Vector2(-15, -104), Vector2(15, -104), Vector2(0, -116)]), Color("#4a4458"))
		"fountain":
			_shadow(w)
			PetArt.ell(self, Transform2D.IDENTITY, Vector2(0, -56), Vector2(58, 34), Color("#c9ced4"))
			PetArt.ell(self, Transform2D.IDENTITY, Vector2(0, -58), Vector2(48, 26), Color("#7fd0ee"))
			draw_rect(Rect2(Vector2(-8, -110), Vector2(16, 52)), Color("#c9ced4"))
			PetArt.ell(self, Transform2D.IDENTITY, Vector2(0, -110), Vector2(22, 8), Color("#c9ced4"))
			for k in 6:
				var a3 := TAU * k / 6.0 + t
				var ph := fmod(t * 1.5 + k * 0.17, 1.0)
				var p := Vector2(0, -116) + Vector2(cos(a3) * 30 * ph, -30 * sin(ph * PI) + 46 * ph * ph)
				draw_circle(p, 3.0, Color(0.7, 0.9, 1.0, 0.9))
		"statue":
			_shadow(w)
			draw_rect(Rect2(Vector2(-44, -40), Vector2(88, 32)), Color("#c9ced4"))
			draw_rect(Rect2(Vector2(-36, -52), Vector2(72, 14)), Color("#dfe3e8"))
			var best := ""
			var best_lvl := 0
			for p in Game.pets:
				if int(p["level"]) > best_lvl:
					best_lvl = int(p["level"])
					best = p["species"]
			if best != "":
				var sp_scale := 26.0
				PetArt.draw_pet(self, Vector2(0, -52 - sp_scale * 1.1), best, 1, false, 0.0, sp_scale, 1.0, true)
				modulate = Color(1.15, 1.15, 1.2)
