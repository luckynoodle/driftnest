extends Node2D
## The ground. One shader-painted meadow quad, a shader-animated lake, and the map split into
## chunks of static decoration (tufts, flowers, pebbles, the plaza, lake banks) so only
## what's on screen gets drawn.

const T := WorldMap.TILE
const CHUNK := 10 # tiles per chunk side

var map: WorldMap


func _ready() -> void:
	var full := WorldMap.SIZE * T
	var ground := Node2D.new()
	ground.z_index = -12
	var gm := ShaderMaterial.new()
	gm.shader = load("res://shaders/ground.gdshader")
	ground.material = gm
	ground.draw.connect(func(): ground.draw_rect(Rect2(Vector2.ZERO, Vector2(full, full)), Color.WHITE))
	add_child(ground)

	# lake banks (under the water)
	var banks := Node2D.new()
	banks.z_index = -11
	banks.draw.connect(_draw_banks.bind(banks))
	add_child(banks)

	var water := Node2D.new()
	water.z_index = -10
	var wm := ShaderMaterial.new()
	wm.shader = load("res://shaders/water.gdshader")
	water.material = wm
	water.draw.connect(_draw_water.bind(water))
	add_child(water)

	var lilies := Node2D.new()
	lilies.z_index = -9
	lilies.draw.connect(_draw_lilies.bind(lilies))
	add_child(lilies)

	var n := WorldMap.SIZE / CHUNK
	for cy in n:
		for cx in n:
			var ch := Node2D.new()
			ch.z_index = -9
			ch.draw.connect(_draw_chunk.bind(ch, Vector2i(cx, cy)))
			add_child(ch)


func _draw_banks(ci: Node2D) -> void:
	PetArt.fast = true
	for cell in map.water:
		ci.draw_circle(WorldMap.cell_center(cell) + Vector2(0, 4), T * 1.0, Color("#3b2a2a"))
	for cell in map.water:
		ci.draw_circle(WorldMap.cell_center(cell) + Vector2(0, 2), T * 0.96, Color("#e9d7a8"))
	for cell in map.water:
		ci.draw_circle(WorldMap.cell_center(cell), T * 0.8, Color("#8a6a44"))


func _depth(cell: Vector2i) -> int:
	var dmin := 4
	for r in range(1, 4):
		for d in [Vector2i(r, 0), Vector2i(-r, 0), Vector2i(0, r), Vector2i(0, -r), Vector2i(r, r), Vector2i(-r, -r), Vector2i(r, -r), Vector2i(-r, r)]:
			if not map.water.has(cell + d):
				return r - 1
	return dmin - 1


func _draw_water(ci: Node2D) -> void:
	var tex := PetArt.soft_texture()
	var off := Vector2(0, 9) # water sits lower than the bank: the far bank wall shows
	var deps := {}
	for cell in map.water:
		deps[cell] = _depth(cell)
	for cell in map.water:
		ci.draw_circle(WorldMap.cell_center(cell) + off, T * 0.78, Color(0.0, 0, 0, 1))
	for cell in map.water:
		if int(deps[cell]) >= 1:
			ci.draw_circle(WorldMap.cell_center(cell) + off, T * 0.9, Color(0.3, 0, 0, 1))
	for cell in map.water:
		if int(deps[cell]) >= 1:
			var r := T * 1.4
			ci.draw_texture_rect(tex, Rect2(WorldMap.cell_center(cell) + off - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(0.62, 0, 0, 0.7))
	for cell in map.water:
		if int(deps[cell]) >= 2:
			var r2 := T * 1.6
			ci.draw_texture_rect(tex, Rect2(WorldMap.cell_center(cell) + off - Vector2(r2, r2), Vector2(r2, r2) * 2.0), false, Color(1.0, 0, 0, 0.75))


func _draw_lilies(ci: Node2D) -> void:
	PetArt.fast = true
	for cell in map.water:
		var h := WorldMap.hash01(cell, 5)
		if h < 0.1 and _depth(cell) >= 1:
			var p := WorldMap.cell_center(cell) + Vector2(10, 20)
			PetArt.soft(ci, p + Vector2(6, 8), Vector2(28, 10), 0.35)
			var xf := Transform2D(0.0, Vector2(1, 1), 0.0, p)
			var pad := PackedVector2Array()
			for i in 20:
				var a := lerpf(0.35, TAU - 0.05, float(i) / 19.0)
				pad.append(p + Vector2(cos(a) * 24.0, sin(a) * 11.0))
			pad.append(p)
			PetArt.outline(ci, pad, 2.0, Color("#2f5a32"))
			PetArt.shaded_fill(ci, pad, Color("#5fb34f"), p)
			if h < 0.05:
				PetArt.blob(ci, xf, Vector2(-6, -8), Vector2(8, 7), Color("#ffb3c7"), 0.0, 2.0, true)
				ci.draw_circle(p + Vector2(-6, -8), 3.0, Color("#ffe14d"))
		elif h > 0.93 and _depth(cell) == 0:
			# reeds at the shore
			var q := WorldMap.cell_center(cell) + Vector2(0, -6)
			for k in 4:
				var x := -12.0 + k * 8.0
				var top := q + Vector2(x + 3.0, -30.0 - 6.0 * sin(k * 1.7))
				ci.draw_line(q + Vector2(x, 0), top, Color("#3b2a2a"), 4.5, true)
				ci.draw_line(q + Vector2(x, 0), top, Color("#6fae4f"), 2.5, true)
				if k % 2 == 0:
					PetArt.blob(ci, Transform2D.IDENTITY, top + Vector2(0, 6), Vector2(3.2, 7.0), Color("#8b5e3c"), 0.0, 1.5, false)


func _draw_chunk(ci: Node2D, chunk: Vector2i) -> void:
	PetArt.fast = true
	var rng := RandomNumberGenerator.new()
	rng.seed = chunk.x * 1009 + chunk.y * 9176 + 1
	var origin := Vector2(chunk) * CHUNK * T
	var size := CHUNK * T
	var c := WorldMap.CENTER * T
	var id := Transform2D.IDENTITY

	# town plaza (only the chunks that touch it)
	var plaza := Rect2(c - Vector2(5.6, 4.6) * T + Vector2(0, 0.6 * T), Vector2(11.2, 9.2) * T)
	if plaza.intersects(Rect2(origin, Vector2(size, size))):
		_plaza(ci, c + Vector2(0, 0.6 * T))

	# forest floor / quarry gravel / crystal dust tints
	for zone in [[WorldMap.FOREST, Vector2(12.0, 13.0), Color(0.18, 0.4, 0.2, 0.28)],
			[WorldMap.ROCKS, Vector2(6.5, 5.5), Color(0.9, 0.85, 0.65, 0.35)],
			[WorldMap.CRYSTALS, Vector2(4.2, 3.8), Color(0.75, 0.65, 0.95, 0.35)]]:
		var zc: Vector2 = zone[0] * T
		var zr: Vector2 = zone[1] * T
		if Rect2(zc - zr, zr * 2.0).intersects(Rect2(origin, Vector2(size, size))):
			ci.draw_texture_rect(PetArt.soft_texture(), Rect2(zc - zr, zr * 2.0), false, zone[2])

	# tufts
	for i in 70:
		var p := origin + Vector2(rng.randf() * size, rng.randf() * size)
		if _skip(p, c):
			continue
		var k := rng.randf_range(0.7, 1.2)
		var dark := Color("#4a9446", 0.65)
		for b in [[-7.0, -14.0, 3.0], [0.0, -18.0, 0.0], [7.0, -14.0, -3.0]]:
			ci.draw_line(p + Vector2(b[0], 0) * k, p + Vector2(b[0] + b[2], b[1]) * k, dark, 2.6 * k, true)
		ci.draw_line(p + Vector2(-1, -2) * k, p + Vector2(0, -14) * k, Color("#c4ef9a", 0.6), 1.4 * k, true)
	# flowers with ink outlines and little shadows
	var cols := [Color("#ffffff"), Color("#ffd23f"), Color("#ff8fa3"), Color("#b48cff")]
	for i in 26:
		var p2 := origin + Vector2(rng.randf() * size, rng.randf() * size)
		if _skip(p2, c):
			continue
		var col: Color = cols[rng.randi_range(0, cols.size() - 1)]
		ci.draw_line(p2, p2 + Vector2(0, 8), Color("#3f8f3a"), 2.0, true)
		PetArt.soft(ci, p2 + Vector2(4, 8), Vector2(8, 3), 0.3)
		for q in 5:
			var a := TAU * q / 5.0
			ci.draw_circle(p2 + Vector2(cos(a) * 5.0, sin(a) * 3.8), 4.6, PetArt.INK)
		for q in 5:
			var a2 := TAU * q / 5.0
			ci.draw_circle(p2 + Vector2(cos(a2) * 5.0, sin(a2) * 3.8), 3.6, col)
		ci.draw_circle(p2, 2.6, Color("#ffb347"))
	# pebbles
	for i in 10:
		var p3 := origin + Vector2(rng.randf() * size, rng.randf() * size)
		if _skip(p3, c):
			continue
		var r := rng.randf_range(3.0, 6.0)
		PetArt.ell(ci, id, p3 + Vector2(1.5, 1.5), Vector2(r, r * 0.6), Color("#5b7a4a", 0.6))
		PetArt.ell(ci, id, p3, Vector2(r, r * 0.6), Color("#d9d2bf"))


func _skip(p: Vector2, town: Vector2) -> bool:
	var cell := WorldMap.world_to_cell(p)
	if map.water.has(cell) or map.nodes.has(cell):
		return true
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if map.water.has(cell + d):
			return true
	var rel := (p - town - Vector2(0, 0.6 * T)) / Vector2(5.4, 4.4) / T
	return rel.length() < 1.0


func _plaza(ci: Node2D, c: Vector2) -> void:
	var id := Transform2D.IDENTITY
	PetArt.ell(ci, id, c + Vector2(0, 8), Vector2(5.35, 4.35) * T, Color("#a8844c"))
	PetArt.ell(ci, id, c, Vector2(5.3, 4.3) * T, Color("#c9a86a"))
	PetArt.ell(ci, id, c, Vector2(5.1, 4.1) * T, Color("#ecd9a8"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 340:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.96
		var p := c + Vector2(cos(a) * 5.1 * T, sin(a) * 4.1 * T) * r
		var sz := rng.randf_range(10.0, 17.0)
		PetArt.ell(ci, id, p + Vector2(1.5, 2.5), Vector2(sz, sz * 0.62), Color("#c9ad74", 0.8))
		PetArt.ell(ci, id, p, Vector2(sz, sz * 0.62), Color("#f6e7bf") if i % 3 else Color("#efdcae"))
