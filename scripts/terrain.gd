extends Node2D
## Static ground: the floating island, paths, plazas, the nest and flowers. Drawn once.

var main = null


func _draw() -> void:
	var center: Vector2 = main.world_center
	var radii: Vector2 = main.world_radii
	var island := PackedVector2Array()
	var n := 140
	for i in n:
		var a := TAU * float(i) / float(n)
		var r := 1.0 + 0.025 * sin(a * 5.0 + 1.0) + 0.018 * sin(a * 11.0 + 2.0) + 0.01 * sin(a * 23.0)
		island.append(center + Vector2(cos(a) * radii.x * r, sin(a) * radii.y * r))

	# underside cliffs (gives the "floating" look)
	var under2 := PackedVector2Array()
	var under1 := PackedVector2Array()
	for p in island:
		under1.append(p + Vector2(0, 70))
		under2.append(center + (p - center) * 0.86 + Vector2(0, 190))
	draw_colored_polygon(under2, Color("#7a5538"))
	draw_colored_polygon(under1, Color("#a57a52"))
	draw_colored_polygon(island, Color("#93d46d"))
	var rim := island.duplicate()
	rim.append(island[0])
	draw_polyline(rim, Color("#b9e893"), 10.0, true)

	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in 26:
		var p := _random_inside(rng, 0.85)
		PetArt.ell(self, Transform2D.IDENTITY, p, Vector2(rng.randf_range(80, 220), rng.randf_range(40, 110)), Color("#9edc7a"))

	# paths
	for seg in main.paths:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		draw_line(a, b, Color("#e2cf9a"), 58.0, true)
		draw_circle(a, 29.0, Color("#e2cf9a"))
		draw_circle(b, 29.0, Color("#e2cf9a"))
	for seg in main.paths:
		var a2: Vector2 = seg[0]
		var b2: Vector2 = seg[1]
		draw_line(a2, b2, Color("#f1e3b8"), 42.0, true)
		draw_circle(a2, 21.0, Color("#f1e3b8"))
		draw_circle(b2, 21.0, Color("#f1e3b8"))

	# station grounds
	for st in main.stations:
		var p: Vector2 = st["pos"]
		match str(st["kind"]):
			"timed":
				match str(st["id"]):
					"nest": _nest(p)
					"grove":
						draw_circle(p, 130.0, Color("#7cbf5a"))
						draw_circle(p, 110.0, Color("#86c962"))
					"tidepool":
						PetArt.ell(self, Transform2D.IDENTITY, p, Vector2(170, 110), Color("#ecdcae"))
						PetArt.ell(self, Transform2D.IDENTITY, p, Vector2(140, 85), Color("#4fb6dd"))
						PetArt.ell(self, Transform2D.IDENTITY, p + Vector2(-10, -6), Vector2(105, 58), Color("#7fd0ee"))
						for k in 5:
							PetArt.ell(self, Transform2D.IDENTITY, p + Vector2(-70 + 34 * k, -10 + 14 * sin(k * 2.0)), Vector2(14, 4), Color(1, 1, 1, 0.5))
					_:
						draw_circle(p, 105.0, Color("#e9dcbd"))
			"kiosk":
				draw_circle(p + Vector2(0, -30), 120.0, Color("#f0e2c4"))
			"post":
				draw_circle(p + Vector2(0, -20), 95.0, Color("#e9dcbd"))
			"mailbox":
				draw_circle(p, 48.0, Color("#e9dcbd"))
			"lantern":
				draw_circle(p, 66.0, Color("#c9b8e8"))
				draw_circle(p, 52.0, Color("#d6c8f0"))

	# flowers
	var colors := [Color("#ffffff"), Color("#ffd23f"), Color("#ff8fa3"), Color("#b48cff")]
	for i in 260:
		var p := _random_inside(rng, 0.9)
		if main.is_blocked(p, 40.0):
			continue
		var c: Color = colors[rng.randi_range(0, colors.size() - 1)]
		for k in 5:
			var a := TAU * k / 5.0
			draw_circle(p + Vector2(cos(a), sin(a)) * 3.5, 3.0, c)
		draw_circle(p, 2.2, Color("#ffb347"))


func _nest(p: Vector2) -> void:
	var id := Transform2D.IDENTITY
	PetArt.ell(self, id, p + Vector2(0, 8), Vector2(125, 58), Color(0, 0, 0, 0.12))
	PetArt.ell(self, id, p, Vector2(120, 54), Color("#a87b4f"))
	PetArt.ell(self, id, p + Vector2(0, -4), Vector2(96, 38), Color("#7a5535"))
	PetArt.ell(self, id, p + Vector2(0, 2), Vector2(84, 30), Color("#f6e7c8"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 40:
		var a := rng.randf() * TAU
		var q := p + Vector2(cos(a) * 108, sin(a) * 46)
		var d := Vector2(cos(a + 1.4), sin(a + 1.4) * 0.45) * rng.randf_range(14, 26)
		draw_line(q - d, q + d, Color("#d9b27a"), 3.0, true)
	# pillows
	PetArt.ell(self, id, p + Vector2(-34, -4), Vector2(28, 16), Color("#ffb3c7"))
	PetArt.ell(self, id, p + Vector2(30, 6), Vector2(26, 14), Color("#b5e2f5"))


func _random_inside(rng: RandomNumberGenerator, k: float) -> Vector2:
	var a := rng.randf() * TAU
	var r := sqrt(rng.randf()) * k
	var c: Vector2 = main.world_center
	var rr: Vector2 = main.world_radii
	return c + Vector2(cos(a) * rr.x, sin(a) * rr.y) * r
