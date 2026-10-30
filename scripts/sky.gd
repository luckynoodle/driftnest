extends Node2D
## Drifting clouds and tiny far-off islets behind the main island.

var clouds: Array = []
var islets: Array = []
var t := 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 18:
		clouds.append({"pos": Vector2(rng.randf_range(-600, 3600), rng.randf_range(-500, 2700)),
			"scale": rng.randf_range(0.7, 1.8), "speed": rng.randf_range(8, 22)})
	for p in [Vector2(-180, 300), Vector2(3200, 420), Vector2(-120, 1900), Vector2(3150, 2050), Vector2(1500, -260)]:
		islets.append({"pos": p, "size": rng.randf_range(60, 120)})


func _process(delta: float) -> void:
	t += delta
	for c in clouds:
		var p: Vector2 = c["pos"]
		p.x += float(c["speed"]) * delta
		if p.x > 3800:
			p.x = -800
		c["pos"] = p
	queue_redraw()


func _draw() -> void:
	var id := Transform2D.IDENTITY
	for isl in islets:
		var p: Vector2 = isl["pos"] + Vector2(0, sin(t * 0.6 + p_hash(isl["pos"])) * 8.0)
		var s: float = isl["size"]
		draw_colored_polygon(PackedVector2Array([p + Vector2(-s, 0), p + Vector2(s, 0), p + Vector2(s * 0.2, s * 0.9)]), Color("#a57a52"))
		PetArt.ell(self, id, p, Vector2(s, s * 0.3), Color("#93d46d"))
		draw_circle(p + Vector2(-s * 0.3, -s * 0.35), s * 0.25, Color("#5fae4f"))
	for c in clouds:
		var p2: Vector2 = c["pos"]
		var k: float = c["scale"]
		var col := Color(1, 1, 1, 0.85)
		draw_circle(p2, 50 * k, col)
		draw_circle(p2 + Vector2(-55, 15) * k, 38 * k, col)
		draw_circle(p2 + Vector2(55, 12) * k, 42 * k, col)
		draw_circle(p2 + Vector2(10, 25) * k, 40 * k, col)


func p_hash(v: Vector2) -> float:
	return fmod(absf(v.x * 0.013 + v.y * 0.007), TAU)
