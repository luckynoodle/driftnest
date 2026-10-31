class_name PortraitView
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
	PetArt.fast = true
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
	PetArt.fast = true
	var id := Transform2D.IDENTITY
	var ow := clampf(r * 0.16, 1.2, 2.6)
	match r_name:
		"glimmer":
			PetArt.shape(ci, id, [c + Vector2(0, -r), c + Vector2(r * 0.82, -r * 0.18), c + Vector2(0, r), c + Vector2(-r * 0.82, -r * 0.18)], Color("#6fcaf5"), ow)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.85), c + Vector2(r * 0.66, -r * 0.18), c + Vector2(0, -r * 0.1)]), Color("#d4f3ff"))
			PetArt.sparkle(ci, c + Vector2(-r * 0.3, -r * 0.35), r * 0.3 * (0.8 + 0.3 * sin(t * 3.0)), Color(1, 1, 1, 0.95))
		"wood":
			PetArt.shape(ci, id, [c + Vector2(-r, -r * 0.45), c + Vector2(r * 0.6, -r * 0.45), c + Vector2(r * 0.6, r * 0.45), c + Vector2(-r, r * 0.45)], Color("#b07a45"), ow)
			PetArt.blob(ci, id, c + Vector2(r * 0.6, 0), Vector2(r * 0.42, r * 0.5), Color("#f0d3a4"), 0.0, ow, false)
			ci.draw_arc(c + Vector2(r * 0.6, 0), r * 0.22, 0, TAU, 12, Color("#c09a6b"), 1.5, true)
		"stone":
			PetArt.blob(ci, id, c + Vector2(0, r * 0.1), Vector2(r * 0.95, r * 0.72), Color("#b4bdc6"), 0.0, ow, true, 1.3)
		"berries":
			ci.draw_line(c + Vector2(0, -r * 0.6), c + Vector2(r * 0.35, -r * 1.0), Color("#3f8f3a"), 2.5, true)
			for q in [Vector2(-0.42, 0.22), Vector2(0.38, 0.26), Vector2(0, -0.32)]:
				PetArt.blob(ci, id, c + q * r, Vector2(r * 0.42, r * 0.42), Color("#5b4cf0"), 0.0, ow * 0.8, true)
		"fish":
			PetArt.shape(ci, id, [c + Vector2(r * 0.5, 0), c + Vector2(r, -r * 0.48), c + Vector2(r, r * 0.48)], Color("#3f9fcb"), ow)
			PetArt.blob(ci, id, c + Vector2(-r * 0.12, 0), Vector2(r * 0.76, r * 0.46), Color("#4fb6dd"), 0.0, ow, true)
			ci.draw_circle(c + Vector2(-r * 0.5, -r * 0.1), r * 0.11, PetArt.INK)
		"crystal":
			PetArt.outline(ci, PackedVector2Array([c + Vector2(-r * 0.45, r * 0.8), c + Vector2(0, -r), c + Vector2(r * 0.45, r * 0.8)]), ow)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.45, r * 0.8), c + Vector2(0, -r), c + Vector2(r * 0.02, r * 0.8)]), Color("#e0c2ff"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.02, r * 0.8), c + Vector2(0, -r), c + Vector2(r * 0.45, r * 0.8)]), Color("#b07ef0"))
		"pets":
			PetArt.blob(ci, id, c + Vector2(0, r * 0.28), Vector2(r * 0.48, r * 0.42), Color("#ff8a65"), 0.0, ow, false)
			for q in [Vector2(-0.58, -0.22), Vector2(-0.2, -0.62), Vector2(0.2, -0.62), Vector2(0.58, -0.22)]:
				PetArt.blob(ci, id, c + q * r, Vector2(r * 0.21, r * 0.23), Color("#ff8a65"), 0.0, ow * 0.8, false)
		"charm":
			var pts2: Array = []
			for i in 10:
				var a := -PI / 2.0 + TAU * i / 10.0
				var rr := r if i % 2 == 0 else r * 0.48
				pts2.append(c + Vector2(cos(a), sin(a)) * rr)
			PetArt.shape(ci, id, pts2, Color("#ffd23f"), ow)
