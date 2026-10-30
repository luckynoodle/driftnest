extends Control
## Small animated picture of a creature, an egg or a glimmer gem, used in HUD cards.

var mode := "pet" # "pet", "egg", "gem"
var species := ""
var level := 1
var prism := false
var silhouette := false
var egg_type := ""
var warmth := 0.0
var t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	t = randf() * 10.0


func _process(delta: float) -> void:
	if is_visible_in_tree():
		t += delta
		queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var m := minf(size.x, size.y)
	match mode:
		"pet":
			if species == "":
				return
			# fit the biggest stage inside the box
			var base := m * 0.3 / Data.stage_scale(Data.MAX_LEVEL) * 1.05
			var s := base * Data.stage_scale(level)
			PetArt.draw_pet(self, c + Vector2(0, s * 0.35), species, level, prism, t, base, 1.0, silhouette)
		"egg":
			if egg_type == "":
				return
			PetArt.draw_egg(self, c + Vector2(0, -m * 0.02), egg_type, m * 0.36, t, warmth)
		"gem":
			var r := m * 0.42
			var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, -r * 0.2), c + Vector2(0, r), c + Vector2(-r * 0.8, -r * 0.2)])
			draw_colored_polygon(pts, Color("#7fd6ff"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, -r * 0.2), c + Vector2(0, -r * 0.05)]), Color("#c8f0ff"))
			var tw := 0.5 + 0.5 * sin(t * 3.0)
			draw_circle(c + Vector2(-r * 0.25, -r * 0.35), 2.0 + tw * 1.5, Color(1, 1, 1, 0.9))
