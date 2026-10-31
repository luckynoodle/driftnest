class_name Ambient
extends Node2D
## Life around the camera: butterflies flitting about and drifting pollen motes.

var cam: Camera2D
var t := 0.0
var flies: Array = []
var motes: Array = []
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 5
	z_index = 30
	var cols := [Color("#ffb3c7"), Color("#ffd23f"), Color("#b5e2f5"), Color("#ffffff"), Color("#c5a3ff")]
	for i in 7:
		flies.append({"pos": Vector2(rng.randf_range(-700, 700), rng.randf_range(-400, 400)), "phase": rng.randf() * 10.0,
			"col": cols[i % cols.size()], "vel": Vector2.ZERO})
	for i in 40:
		motes.append({"pos": Vector2(rng.randf_range(-800, 800), rng.randf_range(-500, 500)), "phase": rng.randf() * 10.0,
			"size": rng.randf_range(1.5, 3.5)})


func _process(delta: float) -> void:
	t += delta
	if cam == null:
		return
	var c := cam.get_screen_center_position()
	var half := get_viewport_rect().size / cam.zoom / 2.0 + Vector2(120, 120)
	for f in flies:
		var ph: float = f["phase"]
		var wander := Vector2(cos(t * 0.7 + ph * 1.3), sin(t * 0.9 + ph)) * 60.0
		f["vel"] = f["vel"].lerp(wander, delta * 1.5)
		f["pos"] += f["vel"] * delta
		_wrap(f, c, half)
	for m in motes:
		m["pos"] += Vector2(14.0 + sin(t + float(m["phase"])) * 8.0, -6.0 + cos(t * 0.7 + float(m["phase"])) * 5.0) * delta
		_wrap(m, c, half)
	queue_redraw()


func _wrap(o: Dictionary, c: Vector2, half: Vector2) -> void:
	var p: Vector2 = o["pos"]
	if p.x < c.x - half.x: p.x += half.x * 2.0
	if p.x > c.x + half.x: p.x -= half.x * 2.0
	if p.y < c.y - half.y: p.y += half.y * 2.0
	if p.y > c.y + half.y: p.y -= half.y * 2.0
	o["pos"] = p


func _draw() -> void:
	PetArt.fast = true
	for m in motes:
		var tw := 0.5 + 0.5 * sin(t * 2.0 + float(m["phase"]) * 3.0)
		draw_circle(m["pos"], float(m["size"]), Color(1.0, 0.98, 0.8, 0.35 + 0.35 * tw))
	for f in flies:
		var p: Vector2 = f["pos"]
		var ph: float = f["phase"]
		var flap := absf(sin(t * 14.0 + ph))
		var col: Color = f["col"]
		var face := -1.0 if Vector2(f["vel"]).x < 0.0 else 1.0
		PetArt.soft(self, p + Vector2(10, 46), Vector2(9, 3), 0.25)
		for side: float in [-1.0, 1.0]:
			var w := Vector2(7.0 * side * (0.35 + 0.65 * flap), -3.0)
			PetArt.blob(self, Transform2D.IDENTITY, p + w, Vector2(6.5 * (0.35 + 0.65 * flap), 7.5), col, 0.3 * side * face, 1.6, false)
		draw_line(p + Vector2(0, -5), p + Vector2(0, 5), PetArt.INK, 2.5, true)
