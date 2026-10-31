class_name NatureProp
extends Node2D
## A natural feature on the map (tree, rock, berry bush, crystal). Origin is its base. Drawn once.

var kind := "tree"
var variant := 0.5


func _shadow(r: Vector2) -> void:
	PetArt.ell(self, Transform2D.IDENTITY, Vector2.ZERO, r, Color(0, 0, 0, 0.15))


func _draw() -> void:
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
	var k := 0.75 + variant * 0.5
	_shadow(Vector2(40, 12) * k)
	draw_rect(Rect2(Vector2(-7, -46) * k, Vector2(14, 46) * k), Color("#8b5e3c"))
	draw_circle(Vector2(0, -76) * k, 36 * k, Color("#5fae4f"))
	draw_circle(Vector2(-25, -58) * k, 25 * k, Color("#6cbd5a"))
	draw_circle(Vector2(25, -58) * k, 25 * k, Color("#6cbd5a"))
	draw_circle(Vector2(-10, -88) * k, 14 * k, Color("#86d16f"))
	if variant < 0.12:
		for p in [Vector2(-18, -70), Vector2(12, -84), Vector2(22, -60)]:
			draw_circle(p * k, 5 * k, Color("#ff8fa3"))


func _pine() -> void:
	var k := 0.7 + (variant - 0.55) * 1.0
	_shadow(Vector2(32, 10) * k)
	draw_rect(Rect2(Vector2(-6, -22) * k, Vector2(12, 22) * k), Color("#7a5235"))
	for i in 3:
		var y := -22.0 - 28.0 * i
		var w := 40.0 - 9.0 * i
		draw_colored_polygon(PackedVector2Array([Vector2(-w, y) * k, Vector2(w, y) * k, Vector2(0, y - 48) * k]),
			Color("#3f8f5a").lightened(0.06 * i))


func _rock() -> void:
	var k := 0.8 + variant * 0.5
	_shadow(Vector2(28, 8) * k)
	PetArt.ell(self, Transform2D.IDENTITY, Vector2(0, -14) * k, Vector2(26, 18) * k, Color("#9aa3ad"))
	PetArt.ell(self, Transform2D.IDENTITY, Vector2(10, -8) * k, Vector2(14, 10) * k, Color("#8a949e"))
	PetArt.ell(self, Transform2D.IDENTITY, Vector2(-6, -22) * k, Vector2(11, 6) * k, Color("#c2c9d0"))


func _bush() -> void:
	var k := 0.75 + variant * 0.4
	_shadow(Vector2(30, 9) * k)
	draw_circle(Vector2(-14, -16) * k, 18 * k, Color("#4f9e4a"))
	draw_circle(Vector2(14, -16) * k, 18 * k, Color("#4f9e4a"))
	draw_circle(Vector2(0, -27) * k, 21 * k, Color("#5fae4f"))
	for p in [Vector2(-16, -20), Vector2(-3, -33), Vector2(11, -24), Vector2(18, -12), Vector2(-7, -12)]:
		draw_circle(p * k, 5 * k, Color("#6b5cff"))
		draw_circle(p * k + Vector2(-1.2, -1.2), 1.6 * k, Color(1, 1, 1, 0.8))


func _crystal() -> void:
	var k := 0.8 + variant * 0.5
	_shadow(Vector2(26, 8) * k)
	PetArt.ell(self, Transform2D.IDENTITY, Vector2(0, -8) * k, Vector2(24, 12) * k, Color("#8a8f96"))
	var cols := [Color("#c58cff"), Color("#b48cff"), Color("#e0c2ff")]
	var spikes := [[Vector2(-10, -6), 30.0, -0.3], [Vector2(6, -6), 42.0, 0.15], [Vector2(16, -4), 22.0, 0.5]]
	for i in spikes.size():
		var base: Vector2 = spikes[i][0] * k
		var h: float = spikes[i][1] * k
		var dir := Vector2(0, -1).rotated(float(spikes[i][2]))
		var side := dir.orthogonal() * h * 0.22
		var col: Color = cols[i]
		draw_colored_polygon(PackedVector2Array([base - side, base + dir * h, base + side]), col)
		draw_colored_polygon(PackedVector2Array([base + dir * h, base + side, base]), col.lightened(0.3))
