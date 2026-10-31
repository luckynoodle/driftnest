class_name Keeper
extends Node2D
## The Keeper, the player character, drawn in the storybook-3D style. Origin is at the feet (for y-sorting).

var facing := 1.0
var moving := false
var egg_type := ""
var egg_warm := 0.0
var t := 0.0

const CLOAK := Color("#3f7a7d")
const CLOAK_DARK := Color("#2a5153")
const SKIN := Color("#ffdcbc")
const HAT := Color("#6b4f9e")
const SCARF := Color("#ffb347")
const STRAP := Color("#8b5e3c")
const OW := 3.0


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	PetArt.fast = true
	var f := facing
	var step := sin(t * 14.0) if moving else 0.0
	var bob := -absf(step) * 4.0 if moving else sin(t * 2.0) * 1.0
	PetArt.soft(self, Vector2(2, 0), Vector2(30, 9), 0.45)
	PetArt.cast(self, Vector2(4, -2), 34, 110, 0.18)
	var o := Vector2(0, bob)
	var id := Transform2D.IDENTITY
	var flip := Transform2D(0.0, Vector2(f, 1.0), 0.0, o)

	# legs
	PetArt.shape(self, id, [Vector2(-13 + step * 4.0, -20), Vector2(-3 + step * 4.0, -20), Vector2(-3 + step * 4.0, 1), Vector2(-13 + step * 4.0, 1)], CLOAK_DARK.darkened(0.15), OW)
	PetArt.shape(self, id, [Vector2(3 - step * 4.0, -20), Vector2(13 - step * 4.0, -20), Vector2(13 - step * 4.0, 1), Vector2(3 - step * 4.0, 1)], CLOAK_DARK, OW)

	# egg basket on the back (behind the body)
	if egg_type != "":
		PetArt.draw_egg(self, o + Vector2(-f * 26.0, -60), egg_type, 18.0, t, egg_warm, false)
		PetArt.shape(self, flip, [Vector2(-46, -46), Vector2(-8, -46), Vector2(-12, -26), Vector2(-42, -26)], Color("#c98b5a"), OW)
		PetArt.line(self, flip, Vector2(-44, -39), Vector2(-10, -39), Color("#9b6a3e"), 2.0)
		PetArt.line(self, flip, Vector2(-42, -32), Vector2(-12, -32), Color("#9b6a3e"), 2.0)

	# cloak
	var top := [Vector2(-21, -17), Vector2(-24, -44), Vector2(-15, -64), Vector2(0, -68), Vector2(15, -64), Vector2(24, -44), Vector2(21, -17)]
	var cl := PackedVector2Array()
	for p in top:
		cl.append(o + p)
	PetArt.outline(self, cl, OW)
	PetArt.shaded_fill(self, cl, CLOAK, o + Vector2(0, -36))
	PetArt.rim(self, Transform2D(0.0, Vector2(f, 1), 0.0, o), Vector2(0, -42), Vector2(22, 26), 2.5, 0.7)
	# strap + scarf
	if egg_type != "":
		PetArt.stroke(self, flip, Vector2(-14, -64), Vector2(12, -22), STRAP, 4.0, 1.5)
	PetArt.shape(self, id, [o + Vector2(-16, -62), o + Vector2(16, -62), o + Vector2(14, -70), o + Vector2(0, -66), o + Vector2(-14, -70)], SCARF, OW * 0.8)
	PetArt.stroke(self, flip, Vector2(9, -60), Vector2(13, -40), SCARF, 6.0, 1.5)
	# arms
	var swing := step * 6.0
	PetArt.stroke(self, id, o + Vector2(17, -54), o + Vector2(20 + swing, -32), CLOAK_DARK, 7.0, 1.5)
	PetArt.stroke(self, id, o + Vector2(-17, -54), o + Vector2(-20 - swing, -32), CLOAK_DARK, 7.0, 1.5)
	PetArt.blob(self, id, o + Vector2(20 + swing, -30), Vector2(4.5, 4.5), SKIN, 0.0, 1.5, false)
	PetArt.blob(self, id, o + Vector2(-20 - swing, -30), Vector2(4.5, 4.5), SKIN, 0.0, 1.5, false)

	# head
	PetArt.blob(self, id, o + Vector2(0, -86), Vector2(19, 19), SKIN, 0.0, OW, false)
	var ex := f * 5.0
	for dx: float in [-4.5, 4.5]:
		PetArt.ell(self, id, o + Vector2(ex + dx, -86), Vector2(2.8, 3.4), PetArt.INK, 0.0)
		draw_circle(o + Vector2(ex + dx - 0.8, -87.4), 1.1, Color.WHITE)
	PetArt.ell(self, id, o + Vector2(ex + f * 10.0, -79), Vector2(4.5, 2.6), Color(1, 0.5, 0.5, 0.45))
	draw_arc(o + Vector2(ex, -80), 3.5, 0.3, PI - 0.3, 8, PetArt.INK, 1.6, true)
	# acorn hat with a little sprout
	var hat := PackedVector2Array()
	for i in 13:
		var a2 := lerpf(PI, TAU, float(i) / 12.0)
		hat.append(o + Vector2(cos(a2) * 22.0, -92.0 + sin(a2) * 17.0))
	PetArt.outline(self, hat, OW)
	PetArt.shaded_fill(self, hat, HAT, o + Vector2(0, -96))
	PetArt.stroke(self, id, o + Vector2(-25, -92), o + Vector2(25, -92), HAT.darkened(0.25), 5.0, 1.5)
	PetArt.line(self, flip, Vector2(0, -109), Vector2(5, -119), Color("#3f8f3a"), 3.0)
	PetArt.blob(self, flip, Vector2(12, -121), Vector2(8, 4), Color("#7cc95a"), -0.4, 2.0, false)
