extends Control
## Small animated picture used in HUD cards: a creature, an egg, a resource icon,
## a tool or a building preview.

var mode := "pet" # "pet", "egg", "res", "tool", "building"
var species := ""
var level := 1
var prism := false
var silhouette := false
var egg_type := ""
var warmth := 0.0
var res := "glimmer"
var tool_kind := "axe"
var tier := 0
var building := ""
var t := 0.0
var _bview: Node2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	t = randf() * 10.0
	if mode == "building" and building != "":
		_bview = BuildingView.new()
		_bview.setup(building, -1)
		add_child(_bview)
		resized.connect(_fit_building)
		_fit_building.call_deferred()


func _fit_building() -> void:
	if _bview == null:
		return
	var size_px := Vector2(Data.BUILDINGS[building]["size"]) * WorldMap.TILE
	var h := size_px.y + 170.0
	var k := minf(size.x / (size_px.x + 40.0), size.y / h)
	_bview.scale = Vector2(k, k)
	_bview.position = Vector2(size.x / 2.0, size.y - 6.0)


func _process(delta: float) -> void:
	if is_visible_in_tree() and mode != "building":
		t += delta
		queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var m := minf(size.x, size.y)
	match mode:
		"pet":
			if species == "":
				return
			var base := m * 0.3 / Data.stage_scale(Data.MAX_STAGE) * 1.05
			var s := base * Data.stage_scale(Data.stage_of(level))
			PetArt.draw_pet(self, c + Vector2(0, s * 0.35), species, level, prism, t, base, 1.0, silhouette)
		"egg":
			if egg_type == "":
				return
			PetArt.draw_egg(self, c + Vector2(0, -m * 0.02), egg_type, m * 0.36, t, warmth)
		"tool":
			PetArt.draw_tool(self, c, tool_kind, tier, m * 0.38, -0.3)
		"res":
			draw_res(self, c, res, m * 0.42, t)


static func draw_res(ci: CanvasItem, c: Vector2, r_name: String, r: float, t: float = 0.0) -> void:
	var id := Transform2D.IDENTITY
	match r_name:
		"glimmer":
			var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, -r * 0.2), c + Vector2(0, r), c + Vector2(-r * 0.8, -r * 0.2)])
			ci.draw_colored_polygon(pts, Color("#7fd6ff"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, -r * 0.2), c + Vector2(0, -r * 0.05)]), Color("#c8f0ff"))
			ci.draw_circle(c + Vector2(-r * 0.25, -r * 0.35), r * 0.12 * (1.0 + 0.5 * sin(t * 3.0)), Color(1, 1, 1, 0.9))
		"wood":
			ci.draw_rect(Rect2(c + Vector2(-r, -r * 0.45), Vector2(r * 1.6, r * 0.9)), Color("#a8794f"))
			ci.draw_circle(c + Vector2(r * 0.6, 0), r * 0.45, Color("#e8c99a"))
			ci.draw_arc(c + Vector2(r * 0.6, 0), r * 0.25, 0, TAU, 12, Color("#c09a6b"), 1.5, true)
		"stone":
			PetArt.ell(ci, id, c + Vector2(0, r * 0.1), Vector2(r * 0.95, r * 0.7), Color("#9aa3ad"))
			PetArt.ell(ci, id, c + Vector2(-r * 0.25, -r * 0.2), Vector2(r * 0.4, r * 0.22), Color("#c2c9d0"))
		"berries":
			for q in [Vector2(-0.4, 0.2), Vector2(0.35, 0.25), Vector2(0, -0.35)]:
				ci.draw_circle(c + q * r, r * 0.42, Color("#6b5cff"))
				ci.draw_circle(c + q * r + Vector2(-r * 0.12, -r * 0.12), r * 0.12, Color(1, 1, 1, 0.8))
			ci.draw_line(c + Vector2(0, -r * 0.7), c + Vector2(r * 0.3, -r * 1.0), Color("#5aa64a"), 2.0)
		"fish":
			PetArt.ell(ci, id, c + Vector2(-r * 0.1, 0), Vector2(r * 0.75, r * 0.45), Color("#4fb6dd"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.55, 0), c + Vector2(r, -r * 0.45), c + Vector2(r, r * 0.45)]), Color("#3f9fcb"))
			ci.draw_circle(c + Vector2(-r * 0.5, -r * 0.1), r * 0.1, Color("#2b2230"))
		"crystal":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.4, r * 0.8), c + Vector2(0, -r), c + Vector2(r * 0.4, r * 0.8)]), Color("#c58cff"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.4, r * 0.8), c + Vector2(r * 0.05, r * 0.8)]), Color("#e0c2ff"))
		"pets":
			ci.draw_circle(c + Vector2(0, r * 0.25), r * 0.45, Color("#ff8a65"))
			for q in [Vector2(-0.55, -0.25), Vector2(-0.2, -0.65), Vector2(0.2, -0.65), Vector2(0.55, -0.25)]:
				ci.draw_circle(c + q * r, r * 0.2, Color("#ff8a65"))
		"charm":
			var pts2 := PackedVector2Array()
			for i in 10:
				var a := -PI / 2.0 + TAU * i / 10.0
				var rr := r if i % 2 == 0 else r * 0.45
				pts2.append(c + Vector2(cos(a), sin(a)) * rr)
			ci.draw_colored_polygon(pts2, Color("#ffd23f"))
