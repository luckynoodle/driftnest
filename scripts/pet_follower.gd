class_name PetFollower
extends Node2D
## The companion creature that follows the Keeper. Origin is at its feet.

const BASE_SIZE := 22.0

var species := ""
var level := 1
var prism := false
var wish := ""
var facing := 1.0
var moving := false
var t := 0.0
var _bubble := StyleBoxFlat.new()


func _ready() -> void:
	_bubble.bg_color = Color(1, 1, 1, 0.94)
	_bubble.set_corner_radius_all(14)
	_bubble.border_color = Color("#ff8fb1")
	_bubble.set_border_width_all(2)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	if species == "":
		return
	var s := BASE_SIZE * Data.stage_scale(level)
	var hop := -absf(sin(t * 10.0)) * 8.0 if moving else 0.0
	PetArt.draw_pet(self, Vector2(0, -0.95 * s + hop), species, level, prism, t, BASE_SIZE, facing)

	# thought bubble with the creature's current wish
	if wish != "" and Data.JOBS.has(wish):
		var font := ThemeDB.fallback_font
		var label: String = Data.JOBS[wish]["short"]
		var fs := 16
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 22.0
		var top := -2.4 * s - 34.0 + sin(t * 2.0) * 3.0
		var rect := Rect2(Vector2(-w / 2.0, top), Vector2(w, 28))
		draw_circle(Vector2(-4, top + 34), 4.0, Color(1, 1, 1, 0.9))
		draw_circle(Vector2(-9, top + 41), 2.5, Color(1, 1, 1, 0.9))
		draw_style_box(_bubble, rect)
		draw_string(font, Vector2(-w / 2.0, top + 20), label, HORIZONTAL_ALIGNMENT_CENTER, w, fs, Color("#c2416e"))
