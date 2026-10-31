extends Node
## Builds a busy town instantly and saves screenshots (for reviewing the art), then quits.
##   godot --path . -- --showcase

var main = null


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var dir := OS.get_user_data_dir().path_join("shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	print("shot ", name)


func _spot(type: String) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	var r := int(Game.town_radius()) + 1
	for y in range(40 - r, 41 + r):
		for x in range(40 - r, 41 + r):
			var c := Vector2i(x, y)
			if Game.can_place(type, c, false) == "":
				var d := (Vector2(c) - WorldMap.CENTER).length()
				if d < best_d:
					best_d = d
					best = c
	return best


func _place(type: String, built: bool = true) -> Dictionary:
	var c := _spot(type)
	if c.x < 0:
		return {}
	var b := Game.place_building(type, c)
	if built and not b.is_empty():
		Game.add_build_progress(b, 999)
	return b


func _measure(label: String) -> void:
	await _frames(3)
	var t0 := Time.get_ticks_usec()
	await _frames(10)
	print("%-60s frame %.1f ms  process %.2f ms" % [label, float(Time.get_ticks_usec() - t0) / 10000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])


func _run() -> void:
	Game.reset_save()
	Game.running = false
	for r in ["wood", "stone", "berries", "fish"]:
		Game.res[r] = 5000
	Game.res["glimmer"] = 20000
	Game.res["crystal"] = 2000
	Game.upgrade_town()
	Game.upgrade_town()
	var camp := _place("lumber_camp")
	var quarry := _place("quarry")
	_place("house")
	_place("house")
	_place("workshop")
	_place("market")
	_place("berry_farm")
	_place("fishing_dock")
	_place("explorer_lodge")
	_place("crystal_mine")
	_place("fountain")
	for i in 6:
		_place("lamp")
		_place("flower_bed")
		_place("sapling")
	_place("house", false)
	# hatch a few pets and put them to work
	for et in ["dawn", "meadow", "tide", "ember", "aurora", "meadow"]:
		var e := Game.carried_egg()
		if e.is_empty():
			Game.buy_egg(et)
			e = Game.carried_egg()
		e["warmth"] = float(Data.EGGS[e["type"]]["warmth"])
		Game.tick(0.01)
	for p in Game.pets:
		p["level"] = [3, 6, 10, 2, 8, 5][Game.pets.find(p) % 6]
	var hut: Dictionary = Game.buildings_of("builder_hut")[0]
	var kinds := ["hammer", "axe", "pickaxe", "basket", "rod", "compass"]
	for i in Game.pets.size():
		Game.craft(kinds[i % kinds.size()], i % 3)
		var t: Dictionary = Game.tools[Game.tools.size() - 1]
		Game.give_tool(int(Game.pets[i]["id"]), int(t["id"]))
		var wp := Game.best_workplace(Game.pets[i])
		if not wp.is_empty():
			Game.assign(int(Game.pets[i]["id"]), int(wp["id"]))
	main._sync()
	main.hud.close_modal()
	main.zoom_level = 0.7
	main._apply_zoom()
	main.keeper.position = WorldMap.CENTER * 64.0 + Vector2(-60, 200)
	main.snap_camera()
	await _frames(40)
	while main.hud.is_modal_open():
		main.hud.close_modal()
		await _frames(2)
	await _frames(20)
	await _measure("all")
	var props: Array = main.ysort.get_children().filter(func(c): return c is NatureProp)
	var t1 := Time.get_ticks_usec()
	for c in props:
		c.queue_redraw()
	await _frames(1)
	print("redraw all %d nature props: %.0f ms" % [props.size(), float(Time.get_ticks_usec() - t1) / 1000.0])
	if DisplayServer.get_name() == "headless":
		get_tree().quit()
		return
	await _shot("s1_town")
	main.zoom_level = 1.1
	main._apply_zoom()
	main.keeper.position = WorldMap.CENTER * 64.0 + Vector2(40, 260)
	main.snap_camera()
	await _frames(20)
	await _shot("s2_close")
	var dock := Game.buildings_of("fishing_dock")
	if not dock.is_empty():
		main.zoom_level = 0.8
		main._apply_zoom()
		main.keeper.position = WorldMap.cell_to_world(dock[0]["cell"]) + Vector2(-60, 200)
		main.snap_camera()
		await _frames(20)
		await _shot("s3_lake")
	main.keeper.position = WorldMap.FOREST * 64.0 + Vector2(500, 0)
	main.snap_camera()
	await _frames(20)
	await _shot("s4_forest")
	main.zoom_level = 0.85
	main._apply_zoom()
	main.keeper.position = WorldMap.CENTER * 64.0 + Vector2(-60, 200)
	main.snap_camera()
	await _frames(5)
	main.hud.open_pet(int(Game.pets[2]["id"]))
	await _frames(5)
	await _shot("s5_pet_panel")
	main.hud.open_build()
	await _frames(5)
	await _shot("s6_build")
	main.hud.close_modal()
	await _frames(3)
	await _shot("s7_hud")
	Game.reset_save()
	get_tree().quit()
