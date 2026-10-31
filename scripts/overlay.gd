class_name WorldOverlay
extends Node2D
## World-space UI drawn over everything: town border, placement grid, worker badges,
## the Keeper's action ring and floating reward text.

const T := WorldMap.TILE

var main = null
var floaters: Array = []
var font: Font
var t := 0.0


func _ready() -> void:
	font = ThemeDB.fallback_font


func float_text(text: String, pos: Vector2, col: Color, delay: float = 0.0) -> void:
	if floaters.size() > 40:
		return
	floaters.append({"text": text, "pos": pos, "col": col, "age": -delay})


func _process(delta: float) -> void:
	t += delta
	for f in floaters:
		f["age"] = float(f["age"]) + delta
	floaters = floaters.filter(func(f): return float(f["age"]) < 1.5)
	queue_redraw()


func _text(pos: Vector2, text: String, size: int, col: Color, outline: Color = Color("#3a2c28"), osize: int = 6) -> void:
	var w := 600.0
	var p := pos - Vector2(w / 2.0, 0)
	draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_CENTER, w, size, osize, outline)
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_CENTER, w, size, col)


func _draw() -> void:
	if main == null:
		return
	var placing: bool = main.placing != ""
	_draw_border(placing)
	if placing:
		_draw_grid()
	_draw_badges()

	# keeper action ring
	var act: Dictionary = main.action
	if not act.is_empty() and bool(main.action_hold) and str(act["kind"]) != "open":
		var head: Vector2 = main.keeper.position + Vector2(0, -96)
		var ratio := 1.0 - clampf(float(main.action_cd) / float(main.action_cd_max), 0.0, 1.0)
		draw_circle(head, 20.0, Color(1, 1, 1, 0.9))
		draw_arc(head, 16.0, -PI / 2.0, -PI / 2.0 + TAU * ratio, 32, Color("#ff8a65"), 6.0, true)

	for f in floaters:
		var age: float = f["age"]
		if age < 0.0:
			continue
		var a := clampf(1.5 - age, 0.0, 1.0)
		var col: Color = f["col"]
		_text(f["pos"] + Vector2(0, -50.0 * age), str(f["text"]), 22, Color(col, a), Color(0.2, 0.15, 0.12, a), 5)


func _draw_border(strong: bool) -> void:
	var c := WorldMap.CENTER * T
	var r := Game.town_radius() * T
	var n := 96
	var col := Color(1, 1, 1, 0.75 if strong else 0.4)
	for i in n:
		if i % 2 == 1:
			continue
		var a0 := TAU * i / n + t * 0.01
		var a1 := TAU * (i + 1) / n + t * 0.01
		draw_arc(c, r, a0, a1, 4, col, 5.0 if strong else 3.0, true)


func _draw_grid() -> void:
	var g: Vector2i = main.ghost_cell
	var col := Color(1, 1, 1, 0.22)
	for y in range(g.y - 8, g.y + 10):
		for x in range(g.x - 8, g.x + 10):
			var c := Vector2i(x, y)
			if (Vector2(c) + Vector2(0.5, 0.5)).distance_to(WorldMap.CENTER) > Game.town_radius():
				continue
			draw_rect(Rect2(Vector2(c) * T, Vector2(T, T)), col, false, 1.0)


func _draw_badges() -> void:
	for b in Game.buildings:
		var info: Dictionary = Data.BUILDINGS[b["type"]]
		if not bool(b["built"]) or not info.has("job"):
			continue
		var size: Vector2i = info["size"]
		var top := WorldMap.cell_to_world(b["cell"]) + Vector2(size.x * T / 2.0, -10.0)
		if b["type"] == "builder_hut":
			top.y -= 40.0
		var n := Game.workers_at(int(b["id"])).size()
		var slots := int(info["slots"])
		var w := 74.0
		var rect := Rect2(top - Vector2(w / 2.0, 16), Vector2(w, 30))
		var bg := Color(1, 1, 1, 0.9) if n > 0 else Color(1.0, 0.85, 0.8, 0.95)
		draw_rect(rect, bg)
		draw_rect(rect, Color("#4a3a32", 0.5), false, 2.0)
		PetArt.draw_tool(self, top + Vector2(-20, -1), Data.JOBS[info["job"]]["tool"], 0, 9.0)
		draw_string(font, top + Vector2(-6, 8), "%d/%d" % [n, slots], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#4a3a32"))
