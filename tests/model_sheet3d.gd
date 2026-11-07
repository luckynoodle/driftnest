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
		"petparts":
			for sp in Data.SPECIES_ORDER:
				items.append([null, sp])
		"keepers", "hair", "hats":
			var looks: Array = []
			if what == "keepers":
				looks = Models3D.KEEPER_PRESETS
			elif what == "hair":
				for h in Models3D.HAIR_STYLES:
					looks.append({"name": {"short": "Short", "bob": "Bob", "long": "Long", "bun": "Bun", "curly": "Curly", "pigtails": "Pigtails"}[h], "hair": h, "hat": "none", "hair_col": ["#6b4a32", "#c45a2c", "#2b2220", "#e2b45a", "#3a2a24", "#8a5a3c"][Models3D.HAIR_STYLES.find(h)]})
			else:
				for h in Models3D.HAT_STYLES:
					looks.append({"name": {"leaf_cap": "Leaf cap", "beret": "Beret", "bucket": "Bucket hat", "beanie": "Beanie", "straw": "Straw hat", "flowers": "Flower crown", "none": "No hat"}[h], "hat": h, "hat_col": ["#7b5cb4", "#8a3b5c", "#f2c84b", "#d0503f", "#ef6f5e", "#ffb3c7", "#7b5cb4"][Models3D.HAT_STYLES.find(h)]})
			for lk in looks:
				items.append([lk, lk["name"]])
		"nature":
			for n in ["tree", "tree_bloom", "pine", "stump", "stump_grow", "rock", "rubble", "rubble_grow", "bush", "bush_bare", "bush_grow", "crystal", "crystal_stub", "crystal_grow", "flower", "tuft"]:
				items.append([Models3D.nature(n), n])
			for k in Data.TOOL_ORDER:
				items.append([Models3D.tool(k, 2), k])
			for e in Data.EGGS:
				items.append([Models3D.egg(e), e])
	var cols := 5 if what != "nature" else 8
	if what in ["keepers", "hair", "hats"]:
		cols = 7
	var sp := 3.6 if what == "buildings" else (1.6 if what in ["pets", "petparts"] else 1.4)
	if what in ["keepers", "hair", "hats"]:
		sp = 1.9
	for i in items.size():
		var mi := MeshInstance3D.new()
		mi.mesh = items[i][0] if items[i][0] is Mesh else null
		mi.position = Vector3((i % cols) * sp, 0, (i / cols) * sp)
		add_child(mi)
		if what in ["keepers", "hair", "hats"]:
			var kp := Models3D.keeper_parts(items[i][0])
			mi.mesh = kp[0]
			for li in 2:
				var leg := MeshKit.instance(kp[1 + li], mi)
				leg.position = Vector3(-0.1 + 0.2 * li, 0.32, 0)
			mi.scale = Vector3.ONE * 1.6
		if what == "petparts":
			var parts := Models3D.pet_parts(items[i][1])
			mi.mesh = parts["body"]
			for pr in [["ears", "ear_pivot", Vector3(0.4, 0, 0)], ["tail", "tail_pivot", Vector3(0, 0.5, 0)], ["wing_l", "wing_pivot_l", Vector3(0, 0, -0.5)], ["wing_r", "wing_pivot_r", Vector3(0, 0, 0.5)]]:
				if parts[pr[0]] == null:
					continue
				var pv := Node3D.new()
				pv.position = parts[pr[1]]
				pv.rotation = pr[2]
				mi.add_child(pv)
				MeshKit.instance(parts[pr[0]], pv)
		var l := Label3D.new()
		l.text = items[i][1]
		l.font_size = 48 if what == "buildings" else 28
		l.pixel_size = 0.01
		l.position = mi.position + Vector3(0, -0.05, sp * 0.42)
		if what in ["keepers", "hair", "hats"]:
			l.position = mi.position + Vector3(0, -0.25, 0.6)
			l.rotation_degrees.x = -15
			l.font_size = 40
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
	if what in ["keepers", "hair", "hats"]:
		cam.size = 4.2
		c.y = 1.25
		cam.position = c + Vector3(0, 5, 18)
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
