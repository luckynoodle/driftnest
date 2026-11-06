class_name NatureProp
extends Node2D
## A natural feature on the map (tree, rock, berry bush, crystal) in the storybook-3D style.
## Origin is its base. Drawn once, and again when it's gathered empty or grows back.

const OW := 2.6

var kind := "tree"
var variant := 0.5
## 0 = full, 1 = gathered empty (stump / rubble / bare bush), 2 = growing back.
var stage := 0


func _draw() -> void:
	PetArt.fast = true
	if stage > 0:
		_depleted()
		return
	match kind:
		"tree":
			if variant > 0.55:
				_pine()
			else:
				_tree()
		"rock": _rock()
		"bush": _bush()
		"crystal": _crystal()


func _tree() -> void:
	var k := 0.72 + variant * 0.5
	var id := Transform2D(0.0, Vector2(k, k), 0.0, Vector2.ZERO)
	PetArt.cast(self, Vector2(6, -4) * k, 70 * k, 140 * k, 0.24)
	PetArt.soft(self, Vector2.ZERO, Vector2(26, 8) * k, 0.4)
	PetArt.shape(self, id, [Vector2(-8, 0), Vector2(-6, -48), Vector2(6, -48), Vector2(8, 0)], Color("#9a6440"), OW)
	draw_colored_polygon(PackedVector2Array([id * Vector2(1, -2), id * Vector2(2, -48), id * Vector2(6, -48), id * Vector2(8, 0)]), Color("#6e4126"))
	var leaf := Color("#5fb34f")
	for b in [[-25, -62, 27], [25, -62, 27], [0, -88, 35], [-8, -54, 23], [16, -52, 22]]:
		PetArt.blob(self, id, Vector2(b[0], b[1]), Vector2(b[2], b[2]), leaf, 0.0, OW, true, 1.3)
	# soft inner shade under the canopy
	PetArt.ell(self, id, Vector2(6, -44), Vector2(30, 7), Color("#2f6f3f", 0.45))
	if variant < 0.14:
		for p in [Vector2(-20, -70), Vector2(14, -84), Vector2(23, -58), Vector2(-4, -104)]:
			PetArt.blob(self, id, p, Vector2(4.2, 4.2), Color("#ff8fa3"), 0.0, 1.5, false)


func _pine() -> void:
	var k := 0.7 + (variant - 0.55) * 1.0
	var id := Transform2D(0.0, Vector2(k, k), 0.0, Vector2.ZERO)
	PetArt.cast(self, Vector2(6, -4) * k, 56 * k, 150 * k, 0.24)
	PetArt.soft(self, Vector2.ZERO, Vector2(22, 7) * k, 0.4)
	PetArt.shape(self, id, [Vector2(-6, 0), Vector2(-6, -24), Vector2(6, -24), Vector2(6, 0)], Color("#8b5e3c"), OW)
	for i in 3:
		var y := -20.0 - 27.0 * i
		var w := 40.0 - 9.0 * i
		var pts := PackedVector2Array()
		pts.append(id * Vector2(0, y - 48))
		pts.append(id * Vector2(-w, y))
		for q in 5:
			var xx := lerpf(-w, w, float(q + 1) / 6.0)
			pts.append(id * Vector2(xx, y + 6.0 * sin(PI * float(q + 1) / 6.0)))
		pts.append(id * Vector2(w, y))
		PetArt.outline(self, pts, OW)
		# split shading: lit left half, shaded right half
		var mid := id * Vector2(0, y + 6)
		var left := PackedVector2Array([pts[0], pts[1], pts[2], pts[3], mid])
		var right := PackedVector2Array([pts[0], mid, pts[4], pts[5], pts[6]])
		draw_colored_polygon(left, Color("#58ab62").lightened(0.04 * i))
		draw_colored_polygon(right, Color("#2f7a4c").lightened(0.04 * i))
		draw_line(id * Vector2(-w * 0.55, y - 4), id * Vector2(-w * 0.12, y - 40), Color("#a6e3a0", 0.6), 2.5 * k, true)


func _rock() -> void:
	var k := 0.8 + variant * 0.5
	var id := Transform2D(0.0, Vector2(k, k), 0.0, Vector2.ZERO)
	PetArt.cast(self, Vector2(4, -2) * k, 50 * k, 40 * k, 0.22)
	PetArt.soft(self, Vector2(2, 0), Vector2(30, 8) * k, 0.4)
	var pts := [Vector2(-26, 0), Vector2(-28, -14), Vector2(-16, -30), Vector2(4, -34), Vector2(22, -24), Vector2(28, -8), Vector2(24, 0)]
	PetArt.shape(self, id, pts, Color("#aab4be"), OW, 1.3)
	draw_colored_polygon(PackedVector2Array([id * Vector2(4, -34), id * Vector2(22, -24), id * Vector2(28, -8), id * Vector2(24, 0), id * Vector2(6, 0), id * Vector2(10, -18)]), Color("#7c8794", 0.55))
	draw_line(id * Vector2(-16, -24), id * Vector2(0, -29), Color(1, 1, 1, 0.85), 3.0 * k, true)


func _bush() -> void:
	var k := 0.75 + variant * 0.4
	var id := Transform2D(0.0, Vector2(k, k), 0.0, Vector2.ZERO)
	PetArt.cast(self, Vector2(4, -2) * k, 56 * k, 50 * k, 0.22)
	PetArt.soft(self, Vector2.ZERO, Vector2(30, 8) * k, 0.4)
	for b in [[-15, -17, 18], [15, -17, 18], [0, -29, 21]]:
		PetArt.blob(self, id, Vector2(b[0], b[1]), Vector2(b[2], b[2]), Color("#4f9e4a"), 0.0, OW, true, 1.2)
	for p in [Vector2(-16, -20), Vector2(-3, -34), Vector2(11, -24), Vector2(18, -12), Vector2(-7, -12)]:
		PetArt.blob(self, id, p, Vector2(4.6, 4.6), Color("#5b4cf0"), 0.0, 1.4, false)
		draw_circle(id * (p + Vector2(-1.4, -1.4)), 1.5 * k, Color(1, 1, 1, 0.9))


func _depleted() -> void:
	var k := 0.8 + variant * 0.4
	var id := Transform2D(0.0, Vector2(k, k), 0.0, Vector2.ZERO)
	var growing := stage == 2
	match kind:
		"tree":
			# a stump, with a sapling coming up once it's growing back
			PetArt.soft(self, Vector2(2, 0), Vector2(20, 6) * k, 0.35)
			PetArt.shape(self, id, [Vector2(-10, 0), Vector2(-9, -14), Vector2(9, -14), Vector2(10, 0)], Color("#9a6440"), OW)
			PetArt.blob(self, id, Vector2(0, -14), Vector2(9.5, 4.5), Color("#e8c99a"), 0.0, OW * 0.8, false)
			draw_arc(id * Vector2(0, -14), 4.0 * k, 0.0, TAU, 12, Color("#c09a6b"), 1.4, true)
			for c in [Vector2(-18, -2), Vector2(15, 1), Vector2(-9, 4)]:
				PetArt.ell(self, id, c, Vector2(3.5, 1.6), Color("#d9b27a"), 0.4)
			if growing:
				draw_line(id * Vector2(14, -2), id * Vector2(16, -24), PetArt.INK, 4.0, true)
				draw_line(id * Vector2(14, -2), id * Vector2(16, -24), Color("#6e4126"), 2.0, true)
				PetArt.blob(self, id, Vector2(16, -30), Vector2(10, 9), Color("#6cbd5a"), 0.0, 2.0, true, 1.2)
		"rock":
			PetArt.soft(self, Vector2(2, 0), Vector2(22, 6) * k, 0.3)
			var n := 5 if growing else 3
			for i in n:
				var p := Vector2(-14 + 7 * i, -4 - 3 * (i % 2))
				PetArt.blob(self, id, p, Vector2(5.5, 4.0) * (1.25 if growing else 1.0), Color("#aab4be"), 0.0, 1.8, false, 1.2)
		"bush":
			PetArt.soft(self, Vector2.ZERO, Vector2(26, 7) * k, 0.35)
			for b in [[-12, -13, 14], [12, -13, 14], [0, -22, 16]]:
				PetArt.blob(self, id, Vector2(b[0], b[1]), Vector2(b[2], b[2]), Color("#6a9e5a"), 0.0, OW, true, 1.1)
			if growing:
				for p in [Vector2(-10, -16), Vector2(6, -24), Vector2(12, -10)]:
					PetArt.blob(self, id, p, Vector2(3.4, 3.4), Color("#a5d36a"), 0.0, 1.2, false)
		"crystal":
			PetArt.soft(self, Vector2.ZERO, Vector2(24, 7) * k, 0.3)
			PetArt.shape(self, id, [Vector2(-24, 0), Vector2(-20, -10), Vector2(0, -14), Vector2(20, -10), Vector2(24, 0)], Color("#8a8f96"), OW)
			var h := 18.0 if growing else 7.0
			for x: float in [-8.0, 6.0]:
				var pts := PackedVector2Array([id * Vector2(x - 4, -10), id * Vector2(x, -10 - h), id * Vector2(x + 4, -10)])
				PetArt.outline(self, pts, 1.8)
				draw_colored_polygon(pts, Color("#b9a3d6") if growing else Color("#9c94a8"))


func _crystal() -> void:
	var k := 0.8 + variant * 0.5
	var id := Transform2D(0.0, Vector2(k, k), 0.0, Vector2.ZERO)
	var glow := Color(0.8, 0.6, 1.0, 0.35)
	draw_texture_rect(PetArt.soft_texture(), Rect2(Vector2(-50, -70) * k, Vector2(100, 90) * k), false, glow)
	PetArt.cast(self, Vector2(4, -2) * k, 50 * k, 60 * k, 0.2)
	PetArt.shape(self, id, [Vector2(-26, 0), Vector2(-22, -12), Vector2(0, -16), Vector2(22, -12), Vector2(26, 0)], Color("#8a8f96"), OW)
	var cols := [Color("#c58cff"), Color("#b48cff"), Color("#e0c2ff")]
	var spikes := [[Vector2(-10, -6), 32.0, -0.3], [Vector2(6, -6), 44.0, 0.15], [Vector2(16, -4), 24.0, 0.5]]
	for i in spikes.size():
		var b: Vector2 = spikes[i][0]
		var h: float = spikes[i][1]
		var dir := Vector2(0, -1).rotated(float(spikes[i][2]))
		var side := dir.orthogonal() * h * 0.22
		var col: Color = cols[i]
		PetArt.outline(self, PackedVector2Array([id * (b - side), id * (b + dir * h), id * (b + side)]), OW)
		draw_colored_polygon(PackedVector2Array([id * (b - side), id * (b + dir * h), id * b]), col.lightened(0.3))
		draw_colored_polygon(PackedVector2Array([id * b, id * (b + dir * h), id * (b + side)]), col.darkened(0.1))
	PetArt.sparkle(self, id * Vector2(4, -46), 6.0 * k, Color(1, 1, 1, 0.95))
