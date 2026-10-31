extends Node2D
## Art gallery for checking the drawing code: every species at two growth stages, eggs and tools.
## Run:  godot --path . res://tests/gallery.tscn   (saves user://shots/gallery.png and quits)

var t := 0.0
var frames := 0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#92d06b"))


func _process(delta: float) -> void:
	t += delta
	frames += 1
	queue_redraw()
	if frames == 12:
		await RenderingServer.frame_post_draw
		var dir := OS.get_user_data_dir().path_join("shots")
		DirAccess.make_dir_recursive_absolute(dir)
		get_viewport().get_texture().get_image().save_png(dir.path_join("gallery.png"))
		get_tree().quit()


func _draw() -> void:
	var i := 0
	for sid in Data.SPECIES_ORDER:
		var col := i % 10
		var row := i / 10
		var p := Vector2(70 + col * 122, 120 + row * 210)
		PetArt.draw_pet(self, p, sid, 1, false, 0.3, 26.0, 1.0)
		PetArt.draw_pet(self, p + Vector2(0, 110), sid, 10 if i % 3 == 0 else 7, i == 5, 0.3, 26.0, -1.0 if i % 2 else 1.0)
		i += 1
	var x := 70.0
	for et in ["dawn", "meadow", "tide", "ember", "aurora"]:
		PetArt.draw_egg(self, Vector2(x, 560), et, 26.0, 0.0, 0.3 if et != "aurora" else 0.95)
		x += 80.0
	x = 520.0
	for k in Data.TOOL_ORDER:
		PetArt.draw_tool(self, Vector2(x, 560), k, int(x) % 3, 22.0, -0.2)
		x += 70.0
	PetArt.draw_pet(self, Vector2(1060, 560), "fennec", 1, false, 0.3, 26.0, 1.0, true)
