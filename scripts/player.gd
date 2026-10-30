class_name Keeper
extends Node2D
## The Keeper — the player character. Origin is at the feet (for y-sorting).

var facing := 1.0
var moving := false
var egg_type := ""
var egg_warm := 0.0
var t := 0.0

const CLOAK := Color("#3c6e71")
const CLOAK_DARK := Color("#2c5254")
const SKIN := Color("#ffd9b8")
const HAT := Color("#6b4f9e")
const SCARF := Color("#ffb347")
const STRAP := Color("#8b5e3c")


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var f := facing
	var step := sin(t * 14.0) if moving else 0.0
	var bob := absf(step) * -4.0 if moving else sin(t * 2.0) * 1.0
	PetArt.ell(self, Transform2D.IDENTITY, Vector2.ZERO, Vector2(26, 8), Color(0, 0, 0, 0.18))

	# legs
	draw_rect(Rect2(Vector2(-10 + step * 4.0, -16), Vector2(8, 16)), CLOAK_DARK)
	draw_rect(Rect2(Vector2(3 - step * 4.0, -16), Vector2(8, 16)), CLOAK_DARK)
	var o := Vector2(0, bob)

	# egg basket on the back (behind the body)
	if egg_type != "":
		PetArt.draw_egg(self, o + Vector2(-f * 20.0, -48), egg_type, 15.0, t, egg_warm, false)
		draw_line(o + Vector2(-f * 8.0, -60), o + Vector2(-f * 22.0, -38), STRAP, 3.0, true)
		PetArt.ell(self, Transform2D.IDENTITY, o + Vector2(-f * 20.0, -36), Vector2(16, 6), Color("#c98b5a"))

	# cloak body
	var body := PackedVector2Array([
		o + Vector2(-17, -14), o + Vector2(17, -14), o + Vector2(12, -52), o + Vector2(-12, -52)])
	draw_colored_polygon(body, CLOAK)
	draw_rect(Rect2(o + Vector2(-13, -52), Vector2(26, 7)), SCARF)
	draw_line(o + Vector2(f * 6.0, -48), o + Vector2(f * 10.0, -34), SCARF, 5.0, true)
	if egg_type != "":
		draw_line(o + Vector2(-f * 8.0, -50), o + Vector2(f * 9.0, -22), STRAP, 3.0, true)
	# arms
	var swing := step * 6.0
	draw_line(o + Vector2(14, -44), o + Vector2(18 + swing, -26), CLOAK_DARK, 6.0, true)
	draw_line(o + Vector2(-14, -44), o + Vector2(-18 - swing, -26), CLOAK_DARK, 6.0, true)

	# head
	draw_circle(o + Vector2(0, -66), 15.0, SKIN)
	var eye_x := f * 6.0
	draw_circle(o + Vector2(eye_x - 4.0, -66), 2.4, PetArt.INK)
	draw_circle(o + Vector2(eye_x + 4.0, -66), 2.4, PetArt.INK)
	draw_circle(o + Vector2(eye_x + f * 8.0, -61), 3.0, Color(1, 0.5, 0.5, 0.35))
	# acorn hat with a little sprout
	var hat := PackedVector2Array([
		o + Vector2(-17, -70), o + Vector2(17, -70), o + Vector2(12, -84), o + Vector2(0, -88), o + Vector2(-12, -84)])
	draw_colored_polygon(hat, HAT)
	draw_line(o + Vector2(0, -88), o + Vector2(f * 4.0, -97), Color("#5aa64a"), 3.0, true)
	PetArt.ell(self, Transform2D.IDENTITY, o + Vector2(f * 9.0, -98), Vector2(6, 3), Color("#7cc95a"), -0.4 * f)
