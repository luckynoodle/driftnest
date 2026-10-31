extends Node2D
## Static ground for the open map: grass, meadows, the lake and pond, the town plaza and flowers.
## Drawn once.

const T := WorldMap.TILE

var map: WorldMap


func _draw() -> void:
	var full := WorldMap.SIZE * T
	draw_rect(Rect2(Vector2.ZERO, Vector2(full, full)), Color("#8fd16b"))
	var id := Transform2D.IDENTITY
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# soft meadow patches
	for i in 140:
		var p := Vector2(rng.randf_range(0, full), rng.randf_range(0, full))
		PetArt.ell(self, id, p, Vector2(rng.randf_range(90, 260), rng.randf_range(50, 130)),
			Color("#9edc7a") if i % 3 != 0 else Color("#84c862"))
	# forest floor
	PetArt.ell(self, id, WorldMap.FOREST * T, Vector2(12.5, 13.5) * T, Color("#7cbf5a"))
	# quarry gravel
	PetArt.ell(self, id, WorldMap.ROCKS * T, Vector2(6.5, 5.5) * T, Color("#b8c49a"))
	PetArt.ell(self, id, WorldMap.CRYSTALS * T, Vector2(4.0, 3.6) * T, Color("#b9b3c9"))
	# town plaza
	var c := WorldMap.CENTER * T
	PetArt.ell(self, id, c + Vector2(0, 0.6 * T), Vector2(5.2, 4.2) * T, Color("#e2cf9a"))
	PetArt.ell(self, id, c + Vector2(0, 0.6 * T), Vector2(4.8, 3.8) * T, Color("#ecdcae"))
	# water: sand rim, deep water, shallows
	for cell in map.water:
		draw_circle(WorldMap.cell_center(cell), T * 0.95, Color("#ecdcae"))
	for cell in map.water:
		draw_circle(WorldMap.cell_center(cell), T * 0.72, Color("#4fb6dd"))
	for cell in map.water:
		var inner := true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
			if not map.water.has(cell + d):
				inner = false
				break
		if inner:
			draw_circle(WorldMap.cell_center(cell), T * 0.95, Color("#3f9fcb"))
	for cell in map.water:
		if WorldMap.hash01(cell, 3) < 0.12:
			var p2 := WorldMap.cell_center(cell)
			PetArt.ell(self, id, p2, Vector2(14, 3), Color(1, 1, 1, 0.45))
	# flowers
	var colors := [Color("#ffffff"), Color("#ffd23f"), Color("#ff8fa3"), Color("#b48cff")]
	for i in 1400:
		var p3 := Vector2(rng.randf_range(0, full), rng.randf_range(0, full))
		var cell2 := WorldMap.world_to_cell(p3)
		if map.water.has(cell2) or map.nodes.has(cell2) or p3.distance_to(c) < 6.0 * T:
			continue
		var col: Color = colors[rng.randi_range(0, colors.size() - 1)]
		for k in 5:
			var a := TAU * k / 5.0
			draw_circle(p3 + Vector2(cos(a), sin(a)) * 3.5, 3.0, col)
		draw_circle(p3, 2.2, Color("#ffb347"))
