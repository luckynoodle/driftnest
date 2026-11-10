class_name Ambient3D
extends Node3D
## Little bits of life in the 3D town: butterflies fluttering near the Keeper by day,
## the odd flock of birds flying over, and cloud shadows drifting across the meadow.
## Everything fades out at night (fireflies take over) and Settings > Ambient turns it off.

const BUTTERFLIES := 8
const BUTTERFLY_RANGE := 7.0
const WING_COLS := [Color("#ffb347"), Color("#ff8fb1"), Color("#9ad0ff"), Color("#fff07a"), Color("#c6a0ff"), Color("#ffffff")]

var main = null
var rng := RandomNumberGenerator.new()
var butterflies: Array = [] # [{node, wl, wr, target, speed, phase}]
var flock: Node3D
var birds: Array = [] # [{node, wl, wr, phase}]
var flock_vel := Vector3.ZERO
var flock_wait := 6.0
var t := 0.0
var _clouds := 1.0
var hold_flock := false # screenshots: keep a flock overhead


func _ready() -> void:
	rng.seed = 7741
	for i in BUTTERFLIES:
		butterflies.append(_make_butterfly(WING_COLS[i % WING_COLS.size()]))
	flock = Node3D.new()
	flock.visible = false
	add_child(flock)
	for i in 5:
		var b := _make_bird()
		var row := (i + 1) / 2
		var side := -1.0 if i % 2 == 1 else 1.0
		b["node"].position = Vector3(side * row * 0.55, rng.randf_range(-0.1, 0.1), row * 0.6)
		birds.append(b)


func _wing_mesh(col: Color, x: float) -> ArrayMesh:
	var k := MeshKit.new()
	k.sphere(Vector3(x * 0.075, 0, -0.02), Vector3(0.075, 0.006, 0.06), col, 10)
	k.sphere(Vector3(x * 0.055, 0, 0.055), Vector3(0.05, 0.005, 0.04), col.darkened(0.1), 8)
	k.ball(Vector3(x * 0.09, 0.005, -0.03), 0.018, Color(1, 1, 1).lerp(col, 0.3), 6)
	return k.commit()


func _make_butterfly(col: Color) -> Dictionary:
	var n := Node3D.new()
	n.scale = Vector3.ONE * 1.5
	add_child(n)
	var k := MeshKit.new()
	k.capsule(Vector3.ZERO, 0.014, 0.1, Color("#3a2e2a"), Vector3(90, 0, 0), 6)
	k.cyl(Vector3(0.012, 0.02, -0.06), 0.003, 0.003, 0.05, Color("#3a2e2a"), 4, Vector3(-40, 0, -20))
	k.cyl(Vector3(-0.012, 0.02, -0.06), 0.003, 0.003, 0.05, Color("#3a2e2a"), 4, Vector3(-40, 0, 20))
	MeshKit.instance(k.commit(), n)
	var wl := MeshKit.instance(_wing_mesh(col, -1.0), n)
	var wr := MeshKit.instance(_wing_mesh(col, 1.0), n)
	for m in [n.get_child(0), wl, wr]:
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return {"node": n, "wl": wl, "wr": wr, "target": Vector3.ZERO, "speed": rng.randf_range(0.7, 1.1),
		"phase": rng.randf() * TAU, "placed": false, "rest": 0.0}


func _make_bird() -> Dictionary:
	var n := Node3D.new()
	flock.add_child(n)
	var k := MeshKit.new()
	k.sphere(Vector3.ZERO, Vector3(0.05, 0.045, 0.13), Color("#f4f1ea"), 8)
	k.ball(Vector3(0, 0.02, -0.12), 0.04, Color("#f4f1ea"), 8)
	k.cone(Vector3(0, 0.02, -0.17), 0.015, 0.05, Color("#f2a33a"), 6, Vector3(-90, 0, 0))
	k.cone(Vector3(0, 0.0, 0.14), 0.04, 0.08, Color("#d9d4c8"), 4, Vector3(90, 0, 0))
	MeshKit.instance(k.commit(), n)
	var wings: Array = []
	for x in [-1.0, 1.0]:
		var wk := MeshKit.new()
		wk.sphere(Vector3(x * 0.15, 0, 0), Vector3(0.15, 0.008, 0.055), Color("#ebe6dc"), 8)
		wk.sphere(Vector3(x * 0.27, 0, 0.02), Vector3(0.05, 0.007, 0.035), Color("#7d7f88"), 6)
		wings.append(MeshKit.instance(wk.commit(), n))
	return {"node": n, "wl": wings[0], "wr": wings[1], "phase": rng.randf() * TAU}


func _ground(p: Vector3) -> float:
	return maxf(Terrain3D.height(p.x, p.z), Terrain3D.WATER_Y)


func _new_target(b: Dictionary) -> void:
	var c: Vector3 = main.cam_target
	var a := rng.randf() * TAU
	var r := sqrt(rng.randf()) * BUTTERFLY_RANGE
	var p := c + Vector3(cos(a) * r, 0, sin(a) * r)
	p.y = _ground(p) + rng.randf_range(0.35, 1.3)
	b["target"] = p


func _process(delta: float) -> void:
	t += delta
	var night: float = main.daynight.night if main.daynight else 0.0
	var on := bool(Game.settings.get("ambient", true))
	var day := on and night < 0.45
	# cloud shadows fade with the light
	var want := (1.0 - clampf(night * 1.6, 0.0, 1.0)) if on else 0.0
	_clouds = move_toward(_clouds, want, delta * 0.5)
	Terrain3D.ground_material().set_shader_parameter("clouds", _clouds)
	_update_butterflies(delta, day)
	_update_birds(delta, day)


func _update_butterflies(delta: float, day: bool) -> void:
	var c: Vector3 = main.cam_target
	for b in butterflies:
		var n: Node3D = b["node"]
		if not day:
			n.visible = false
			b["placed"] = false
			continue
		if not b["placed"]:
			_new_target(b)
			n.position = b["target"]
			_new_target(b)
			b["placed"] = true
		n.visible = true
		var to: Vector3 = b["target"] - n.position
		# keep them near the action: if the camera moved far away, drift back
		if Vector2(n.position.x - c.x, n.position.z - c.z).length() > BUTTERFLY_RANGE * 1.6:
			_new_target(b)
			n.position = b["target"] + Vector3(0, 1.5, 0)
			continue
		if to.length() < 0.2:
			_new_target(b)
		var ph: float = b["phase"]
		var wobble := Vector3(sin(t * 2.3 + ph), sin(t * 3.7 + ph * 2.0) * 0.7, cos(t * 1.9 + ph)) * 0.6
		var v := to.normalized() * float(b["speed"]) + wobble
		n.position += v * delta
		var gy := _ground(n.position) + 0.2
		n.position.y = maxf(n.position.y, gy)
		if Vector2(v.x, v.z).length() > 0.05:
			n.rotation.y = lerp_angle(n.rotation.y, atan2(-v.x, -v.z), delta * 4.0)
		var flap := 0.25 + 1.05 * absf(sin(t * 15.0 + ph))
		(b["wl"] as Node3D).rotation.z = -flap
		(b["wr"] as Node3D).rotation.z = flap


func _update_birds(delta: float, day: bool) -> void:
	if not flock.visible:
		flock_wait -= delta
		if flock_wait <= 0.0 and day:
			_launch_flock()
		return
	flock.position += flock_vel * delta
	if hold_flock:
		flock.position = main.cam_target + Vector3(1.5, 5.5, 1.0)
	for b in birds:
		var ph: float = b["phase"]
		var flap := sin(t * 7.0 + ph) * 0.55
		# glide now and then
		if fmod(t + ph, 6.0) > 4.2:
			flap = 0.08
		(b["wl"] as Node3D).rotation.z = flap
		(b["wr"] as Node3D).rotation.z = -flap
	var c: Vector3 = main.cam_target
	if Vector2(flock.position.x - c.x, flock.position.z - c.z).length() > 30.0:
		flock.visible = false
		flock_wait = rng.randf_range(22.0, 45.0)


func _launch_flock() -> void:
	var c: Vector3 = main.cam_target
	var a := rng.randf() * TAU
	var dir := Vector3(cos(a), 0, sin(a))
	var side := Vector3(-dir.z, 0, dir.x) * rng.randf_range(-5.0, 5.0)
	flock.position = c - dir * 24.0 + side + Vector3(0, rng.randf_range(5.5, 7.0), 0)
	flock_vel = dir * rng.randf_range(3.2, 4.2)
	flock.rotation.y = atan2(-dir.x, -dir.z)
	flock.visible = true


## For tests and screenshots: bring a flock overhead right now.
func flock_now() -> void:
	_launch_flock()
	hold_flock = true
