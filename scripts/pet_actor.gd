class_name PetActor
extends Node2D
## A pet walking around town: to its workplace, to a construction site, or wandering when idle.
## Origin is at its feet.

const BASE_SIZE := 18.0
const SPEED := 150.0

var pid := -1
var t := 0.0
var facing := 1.0
var moving := false
var working := false
var _wander := Vector2.ZERO
var _wander_t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = pid * 7919
	t = _rng.randf() * 10.0
	_wander = position


func _target(p: Dictionary) -> Vector2:
	working = false
	var b := Game.find_building(int(p["work"]))
	if not b.is_empty() and bool(b["built"]) and Game.pet_job(p) == Data.BUILDINGS[b["type"]].get("job", ""):
		var mates := Game.workers_at(int(b["id"]))
		var idx := maxi(0, mates.find(p))
		if b["type"] == "builder_hut":
			var site := Game.construction_target()
			if not site.is_empty():
				working = true
				return _front(site) + Vector2(-34 + 34 * idx, 18)
		else:
			working = true
		return _front(b) + Vector2(-38 + 76 * (idx % 2), 22 + 14 * (idx / 2))
	# idle: wander around the plaza
	_wander_t -= get_process_delta_time()
	if _wander_t <= 0.0:
		_wander_t = _rng.randf_range(3.0, 7.0)
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(1.0, 4.2) * WorldMap.TILE
		_wander = WorldMap.town_center_world() + Vector2(cos(a) * r * 1.2, sin(a) * r * 0.8 + WorldMap.TILE * 2.6)
	return _wander


func _front(b: Dictionary) -> Vector2:
	var size: Vector2i = Data.BUILDINGS[b["type"]]["size"]
	return WorldMap.cell_to_world(b["cell"]) + Vector2(size.x * WorldMap.TILE / 2.0, size.y * WorldMap.TILE)


func _process(delta: float) -> void:
	t += delta
	var p := Game.find_pet(pid)
	if p.is_empty():
		return
	var target := _target(p)
	var to := target - position
	var step := SPEED * delta
	moving = to.length() > 4.0
	if moving:
		var mv := to.limit_length(step)
		position += mv
		if absf(mv.x) > 0.3:
			facing = signf(mv.x)
	queue_redraw()


func _draw() -> void:
	PetArt.fast = true
	var p := Game.find_pet(pid)
	if p.is_empty():
		return
	var lvl := int(p["level"])
	var s := BASE_SIZE * Data.stage_scale(Data.stage_of(lvl))
	var hop := -absf(sin(t * 10.0)) * 6.0 if moving else 0.0
	PetArt.draw_pet(self, Vector2(0, -0.95 * s + hop), p["species"], lvl, bool(p["prism"]), t, BASE_SIZE, facing)
	var tool := Game.pet_tool(p)
	if not tool.is_empty():
		var swing := 0.0
		if working and not moving:
			swing = sin(t * 8.0) * 0.7 - 0.3
		PetArt.draw_tool(self, Vector2(facing * s * 1.05, -0.9 * s + hop), tool["kind"], int(tool["tier"]), s * 0.42, swing * facing)
	if not working and not moving and int(p["work"]) == -1:
		var z := fmod(t, 2.4) / 2.4
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(s * 0.6 + z * 8.0, -2.0 * s - z * 18.0), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.3, 0.3, 0.5, 1.0 - z))
