class_name WorldMap
extends RefCounted
## The open landscape around the town, generated from a fixed seed so it is the same
## every time (only buildings are saved). Natural features live on a tile grid.

const SIZE := 80
const TILE := 64.0
const CENTER := Vector2(40.5, 40.5) # town centre, in tile units
const CLEAR_RADIUS := 7.5

const FOREST := Vector2(23.0, 42.0)
const ROCKS := Vector2(42.0, 27.0)
const LAKE := Vector2(54.0, 53.0)
const CRYSTALS := Vector2(58.5, 35.5)
const BERRIES := Vector2(50.0, 31.0)
const MEADOW_POND := Vector2(28.0, 58.0)

var nodes: Dictionary = {} # Vector2i -> "tree" | "rock" | "bush" | "crystal"
var water: Dictionary = {} # Vector2i -> true


func _init() -> void:
	_generate()


static func cell_to_world(c: Vector2i) -> Vector2:
	return Vector2(c) * TILE


static func cell_center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * TILE


static func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


static func town_center_world() -> Vector2:
	return CENTER * TILE


static func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < SIZE and c.y < SIZE


static func hash01(c: Vector2i, salt: int = 0) -> float:
	var h := (c.x * 73856093) ^ (c.y * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return float(absi(h) % 10000) / 10000.0


func _lake_radius(center: Vector2, base: float, p: Vector2) -> float:
	var a := (p - center).angle()
	return base + 0.9 * sin(a * 3.0 + 1.3) + 0.6 * sin(a * 5.0 + 0.4)


func _generate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261031
	# water first
	for y in SIZE:
		for x in SIZE:
			var c := Vector2i(x, y)
			var p := Vector2(x + 0.5, y + 0.5)
			if p.distance_to(LAKE) < _lake_radius(LAKE, 6.0, p) or p.distance_to(MEADOW_POND) < _lake_radius(MEADOW_POND, 3.2, p):
				water[c] = true
	for y in SIZE:
		for x in SIZE:
			var c := Vector2i(x, y)
			if water.has(c) or _near_water(c):
				continue
			var p := Vector2(x + 0.5, y + 0.5)
			var d := p.distance_to(CENTER)
			if d < CLEAR_RADIUS:
				continue
			var r := rng.randf()
			var edge := mini(mini(x, y), mini(SIZE - 1 - x, SIZE - 1 - y))
			if edge < 3:
				if r < 0.75:
					nodes[c] = "tree"
			elif p.distance_to(FOREST) < 11.0 + 1.5 * sin(p.y * 0.7):
				if r < 0.5:
					nodes[c] = "tree"
			elif p.distance_to(ROCKS) < 6.0:
				if r < 0.3:
					nodes[c] = "rock"
			elif p.distance_to(CRYSTALS) < 3.2:
				if r < 0.45:
					nodes[c] = "crystal"
				elif r < 0.6:
					nodes[c] = "rock"
			elif p.distance_to(BERRIES) < 3.5:
				if r < 0.3:
					nodes[c] = "bush"
			else:
				if r < 0.045:
					nodes[c] = "tree"
				elif r < 0.055:
					nodes[c] = "rock"
				elif r < 0.065:
					nodes[c] = "bush"


func _near_water(c: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if water.has(c + Vector2i(dx, dy)):
				return true
	return false


func count_near(rect: Rect2i, margin: int, kind: String) -> int:
	var n := 0
	for y in range(rect.position.y - margin, rect.end.y + margin):
		for x in range(rect.position.x - margin, rect.end.x + margin):
			var c := Vector2i(x, y)
			if kind == "water":
				if water.has(c):
					n += 1
			elif nodes.get(c, "") == kind:
				n += 1
	return n
