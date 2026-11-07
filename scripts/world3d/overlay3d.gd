class_name Overlay3D
extends Node2D
## Screen-space labels over the 3D world: worker badges above workplaces, the Keeper's
## action ring and floating reward text. Positions are projected from 3D every frame.

var main = null
var floaters: Array = []
var font: Font
var t := 0.0


func _ready() -> void:
	font = ThemeDB.fallback_font


func float_text(text: String, pos3: Vector3, col: Color) -> void:
	if floaters.size() > 40:
		return
	floaters.append({"text": text, "pos": pos3, "col": col, "age": 0.0})


func _process(delta: float) -> void:
	t += delta
	for f in floaters:
		f["age"] = float(f["age"]) + delta
	floaters = floaters.filter(func(f): return float(f["age"]) < 1.5)
	queue_redraw()


func _proj(p: Vector3) -> Vector2:
	var cam: Camera3D = main.cam3d
	if cam.is_position_behind(p):
		return Vector2(-9999, -9999)
	return cam.unproject_position(p)


func _text(pos: Vector2, text: String, size: int, col: Color, outline: Color = Color("#3a2c28"), osize: int = 6) -> void:
	var w := 600.0
	var p := pos - Vector2(w / 2.0, 0)
	draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_CENTER, w, size, osize, outline)
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_CENTER, w, size, col)


func _draw() -> void:
	if main == null or main.cam3d == null:
		return
	var k: float = clampf(main.zoom_level, 0.6, 1.2)
	# worker badges
	for b in Game.buildings:
		var info: Dictionary = Data.BUILDINGS[b["type"]]
		if not bool(b["built"]) or not info.has("job"):
			continue
		var node: Node3D = main.b3d.get(int(b["id"]))
		if node == null:
			continue
		var top := _proj(node.global_position + Vector3(0, 2.6 if b["type"] != "builder_hut" else 2.4, 0))
		if top.x < -100:
			continue
		var n := Game.workers_at(int(b["id"])).size()
		var slots := int(info["slots"])
		var w := 74.0 * k
		var h := 30.0 * k
		var rect := Rect2(top - Vector2(w / 2.0, h / 2.0), Vector2(w, h))
		var bg := Color(1, 1, 1, 0.92) if n > 0 else Color(1.0, 0.85, 0.8, 0.95)
		draw_rect(rect, bg)
		draw_rect(rect, Color("#4a3a32", 0.5), false, 2.0)
		PetArt.draw_tool(self, top + Vector2(-20, 0) * k, Data.JOBS[info["job"]]["tool"], 0, 9.0 * k)
		draw_string(font, top + Vector2(-6, 7) * k, "%d/%d" % [n, slots], HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * k), Color("#4a3a32"))

	# keeper action ring
	var act: Dictionary = main.action
	if not act.is_empty() and bool(main.action_hold) and str(act["kind"]) != "open":
		var head := _proj(main.k3d.global_position + Vector3(0, 2.1, 0))
		var ratio := 1.0 - clampf(float(main.action_cd) / float(main.action_cd_max), 0.0, 1.0)
		draw_circle(head, 20.0, Color(1, 1, 1, 0.9))
		draw_arc(head, 16.0, -PI / 2.0, -PI / 2.0 + TAU * ratio, 32, Color("#ff8a65"), 6.0, true)

	for f in floaters:
		var age: float = f["age"]
		var a := clampf(1.5 - age, 0.0, 1.0)
		var col: Color = f["col"]
		var p := _proj(f["pos"] + Vector3(0, age * 0.8, 0))
		_text(p, str(f["text"]), 22, Color(col, a), Color(0.2, 0.15, 0.12, a), 5)
