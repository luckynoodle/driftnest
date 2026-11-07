extends Node3D
## Dev tool: renders every 3D model in a grid and saves a picture.
## godot --path . res://tests/model_sheet3d.tscn -- --what=buildings|pets|nature

func _ready() -> void:
	var what := "buildings"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--what="):
			what = a.substr(7)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#9fd27e")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c9dcff")
	env.ambient_light_energy = 0.38
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = 0.82
	sun.light_color = Color("#fff0d4")
	sun.shadow_enabled = true
	add_child(sun)
	var items: Array = []
	match what:
		"buildings":
			for t in ["town_hall", "nest", "kiosk", "builder_hut"] + Data.BUILD_ORDER:
				items.append([Models3D.building(t, 0), t])
		"pets":
			for s in Data.SPECIES_ORDER:
				items.append([Models3D.pet(s), s])
		"nature":
			for n in ["tree", "tree_bloom", "pine", "stump", "stump_grow", "rock", "rubble", "rubble_grow", "bush", "bush_bare", "bush_grow", "crystal", "crystal_stub", "crystal_grow", "flower", "tuft"]:
				items.append([Models3D.nature(n), n])
			for k in Data.TOOL_ORDER:
				items.append([Models3D.tool(k, 2), k])
			for e in Data.EGGS:
				items.append([Models3D.egg(e), e])
	var cols := 5 if what != "nature" else 8
	var sp := 3.6 if what == "buildings" else (1.6 if what == "pets" else 1.4)
	for i in items.size():
		var mi := MeshInstance3D.new()
		mi.mesh = items[i][0]
		mi.position = Vector3((i % cols) * sp, 0, (i / cols) * sp)
		add_child(mi)
		var l := Label3D.new()
		l.text = items[i][1]
		l.font_size = 48 if what == "buildings" else 28
		l.pixel_size = 0.01
		l.position = mi.position + Vector3(0, -0.05, sp * 0.42)
		l.rotation_degrees.x = -50
		l.modulate = Color.BLACK
		add_child(l)
		if what == "buildings":
			var k3 := MeshKit.new()
			var sz: Vector2i = Data.BUILDINGS[items[i][1]]["size"] if Data.BUILDINGS.has(items[i][1]) else Vector2i(2, 2)
			k3.box(Vector3(0, -0.02, 0), Vector3(sz.x, 0.02, sz.y), Color("#7cc05a"))
			MeshKit.instance(k3.commit(), mi)
	var rows := ceili(float(items.size()) / cols)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = rows * sp * 1.25 + 1.0
	var c := Vector3((cols - 1) * sp / 2.0, 0, (rows - 1) * sp / 2.0)
	cam.position = c + Vector3(0, 20, 16)
	add_child(cam)
	cam.look_at(c, Vector3.UP)
	cam.current = true
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "user://model_sheet_%s.png" % what
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
	get_tree().quit()
