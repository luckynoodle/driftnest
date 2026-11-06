extends Node
## Automated play-through of the town loop. Run with:
##   godot --path . -- --smoke            (add --headless to skip rendering)
## Exits 0 on success, 1 on failure. Saves screenshots to user://shots when rendering.

var main = null
var failures: Array = []
var shot_dir := ""


func _ready() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	print("  ok   " if cond else "  FAIL ", msg)
	if not cond:
		failures.append(msg)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(shot_dir.path_join(name + ".png"))


func _close_all() -> void:
	for i in 10:
		if not main.hud.is_modal_open():
			return
		main.hud.close_modal()
		await _wait(0.05)


func _find_spot(type: String) -> Vector2i:
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


func _place(type: String) -> Dictionary:
	var c := _find_spot(type)
	_check(c.x >= 0, "found a spot for %s" % type)
	if c.x < 0:
		return {}
	var b := Game.place_building(type, c)
	_check(not b.is_empty(), "placed %s" % type)
	return b


func _wait_built(b: Dictionary, timeout: float) -> void:
	var waited := 0.0
	while not bool(b["built"]) and waited < timeout:
		await _wait(0.25)
		waited += 0.25


func _goto_building(b: Dictionary, offset: Vector2 = Vector2(0, 90)) -> void:
	var size: Vector2i = Data.BUILDINGS[b["type"]]["size"]
	main.keeper.position = WorldMap.cell_to_world(b["cell"]) + Vector2(size.x * 32.0, size.y * 64.0) + offset


func _run() -> void:
	shot_dir = OS.get_user_data_dir().path_join("shots")
	DirAccess.make_dir_recursive_absolute(shot_dir)
	print("Smoke test starting")
	Game.reset_save()
	main._sync()
	await _wait(0.3)
	main.hud.open_help()
	await _wait(0.2)
	await _shot("01_help")
	_check(main.hud.is_modal_open(), "help opens")
	await _close_all()
	await _shot("02_start")

	# --- hatch the Dawn egg
	_check(not Game.carried_egg().is_empty(), "starts carrying an egg")
	_check(Game.eggs_at("nest").size() == 1, "second egg warming in the nest")
	Engine.time_scale = 8.0
	var waited := 0.0
	while Game.pets.is_empty() and waited < 10.0:
		await _wait(0.25)
		waited += 0.25
	Engine.time_scale = 1.0
	_check(Game.pets.size() == 1, "dawn egg hatched")
	await _wait(0.2)
	await _shot("03_hatch")
	_check(main.hud.is_modal_open(), "hatch reveal shown")
	await _close_all()
	var p1: Dictionary = Game.pets[0]

	# --- builder
	var hammer := -1
	var axe := -1
	for t in Game.tools:
		if t["kind"] == "hammer": hammer = int(t["id"])
		if t["kind"] == "axe": axe = int(t["id"])
	Game.give_tool(int(p1["id"]), hammer)
	var hut: Dictionary = Game.buildings_of("builder_hut")[0]
	_check(Game.assign(int(p1["id"]), int(hut["id"])) == "", "pet assigned as builder")
	_check(Game.goal_index >= 2, "first two goals complete")

	# --- lumber camp built by the builder
	var camp := _place("lumber_camp")
	main.keeper.position = WorldMap.cell_to_world(camp["cell"]) + Vector2(64, 200)
	main.snap_camera()
	await _wait(0.6)
	await _shot("04_construction")
	Engine.time_scale = 8.0
	await _wait_built(camp, 6.0)
	Engine.time_scale = 1.0
	_check(bool(camp["built"]), "lumber camp built by builder pet")

	# --- second pet from the nest becomes a woodcutter
	var nest_egg: Dictionary = Game.eggs_at("nest")[0]
	nest_egg["warmth"] = float(Data.EGGS[nest_egg["type"]]["warmth"]) - 0.2
	await _wait(0.6)
	await _close_all()
	_check(Game.pets.size() == 2, "nest egg hatched")
	var p2: Dictionary = Game.pets[1]
	Game.give_tool(int(p2["id"]), axe)
	_check(Game.assign(int(p2["id"]), int(camp["id"])) == "", "pet assigned to lumber camp")
	var wood := int(Game.res["wood"])
	Engine.time_scale = 8.0
	await _wait(2.0)
	Engine.time_scale = 1.0
	_check(int(Game.res["wood"]) > wood, "woodcutter produces wood")
	_check(int(p2["xp"]) > 0 or int(p2["level"]) > 1, "working gives pet xp")
	_goto_building(camp)
	main.snap_camera()
	await _wait(0.5)
	await _shot("05_lumber")

	# --- keeper gathers by hand
	var tree_cell := Vector2i(-1, -1)
	for c in Game.map.nodes:
		if Game.map.nodes[c] == "tree" and (Vector2(c) - WorldMap.CENTER).length() < 12.0:
			tree_cell = c
			break
	main.keeper.position = WorldMap.cell_center(tree_cell) + Vector2(0, 64)
	await _wait(0.2)
	var w2 := int(Game.res["wood"])
	main.action_cd = 0.0
	_check(not main.action.is_empty() and main.action["kind"] == "gather", "keeper sees a gather action")
	main.do_action()
	_check(int(Game.res["wood"]) == w2 + 1, "keeper chops wood by hand")

	# --- grow the town (grant resources so the test runs fast)
	for r in ["wood", "stone", "berries", "fish"]:
		Game.res[r] = 2000
	Game.res["glimmer"] = 5000
	Game.res["crystal"] = 500
	var house := _place("house")
	var quarry := _place("quarry")
	var shop := _place("workshop")
	var market := _place("market")
	var farm := _place("berry_farm")
	Game.add_build_progress(house, 999)
	Game.add_build_progress(quarry, 999)
	Game.add_build_progress(shop, 999)
	Game.add_build_progress(market, 999)
	_check(Game.capacity() == 4, "house adds room for pets")
	_check(Game.craft("pickaxe", 1), "craft a stone pickaxe")
	_check(Game.buy_egg("tide"), "buy a tide egg")
	_check(Game.feed(int(p2["id"]), "berries"), "feed a pet")
	for path_i in 4:
		Game.place_building("flower_bed", _find_spot("flower_bed"))
	_check(Game.upgrade_town(), "upgrade town hall to 2")
	_check(Game.town_radius() > 10.0, "border grows")
	var dock := _place("fishing_dock")
	var lodge := _place("explorer_lodge")
	_check(Game.upgrade_town(), "upgrade town hall to 3")
	var mine := _place("crystal_mine")
	for b in [farm, dock, lodge, mine]:
		if not b.is_empty():
			Game.add_build_progress(b, 999)
	main._sync()

	# --- hatch more pets and staff buildings
	for i in 3:
		var e := Game.carried_egg()
		if e.is_empty():
			Game.buy_egg("meadow")
			e = Game.carried_egg()
		e["warmth"] = float(Data.EGGS[e["type"]]["warmth"])
		Game.tick(0.1)
	await _wait(0.2)
	await _close_all()
	_check(Game.pets.size() == 4, "four pets (town capacity)")
	var p3: Dictionary = Game.pets[2]
	var pick := -1
	for t in Game.tools:
		if t["kind"] == "pickaxe": pick = int(t["id"])
	Game.give_tool(int(p3["id"]), pick)
	_check(Game.assign(int(p3["id"]), int(quarry["id"])) == "", "miner assigned to quarry")
	Game.craft("compass", 0)
	var p4: Dictionary = Game.pets[3]
	for t in Game.free_tools():
		if t["kind"] == "compass":
			Game.give_tool(int(p4["id"]), int(t["id"]))
	_check(Game.assign(int(p4["id"]), int(lodge["id"])) == "", "explorer assigned")
	_check(Game.assign(int(p3["id"]), int(camp["id"])) != "", "wrong tool is rejected")

	# --- levels and skill caps
	for i in 60:
		Game.feed(int(p2["id"]), "fish")
	_check(int(p2["level"]) == Data.MAX_LEVEL, "feeding fish reaches max level")
	var sk_before := int(Game.skill(p2, "woodcutting")["lvl"])
	Game.simulate(600)
	_check(int(Game.skill(p2, "woodcutting")["lvl"]) > sk_before, "woodcutting skill rises with work")
	_check(int(Game.skill(p1, "building")["lvl"]) <= int(p1["level"]), "skill capped by pet level")
	_check(Game.charm() >= 4, "decorations add charm")

	# --- storage limits
	var wcap := Game.storage_cap("wood")
	Game.res["wood"] = wcap - 3
	_check(Game.gain("wood", 50) == 3 and int(Game.res["wood"]) == wcap, "storage stops at its limit")
	var cap_before := Game.storage_cap("stone")
	var sh := _place("storehouse")
	if not sh.is_empty():
		Game.add_build_progress(sh, 999)
	_check(Game.storage_cap("stone") > cap_before, "storehouse raises the limit")
	Game.res["wood"] = Game.storage_cap("wood")
	Game.tick(1.0)
	var paused := false
	for p in Game.pets:
		if str(p.get("waiting", "")) == "full":
			paused = true
	_check(paused, "worker waits when its store is full")

	# --- natural resources run out and grow back
	var rock := Vector2i(-1, -1)
	for c in Game.map.nodes:
		if Game.map.nodes[c] == "rock":
			rock = c
			break
	Game.res["stone"] = 0
	var got := 0
	while Game.keeper_gather_at(rock) == "stone":
		got += 1
	_check(got == int(Data.NODES["rock"]["stock"]), "a rock gives a few stones")
	_check(Game.keeper_gather_at(rock) == "empty" and Game.node_left(rock) == 0, "an empty rock gives nothing")
	Game.simulate(float(Data.NODES["rock"]["regrow"]) + 5.0)
	_check(Game.node_left(rock) == int(Data.NODES["rock"]["stock"]), "the rock grows back")

	# --- food and mood
	var hp: Dictionary = Game.pets[0]
	hp["food"] = 0.05
	_check(Game.mood(hp) == "hungry", "an unfed pet is hungry")
	Game.res["berries"] = 20
	Game.tick(0.1)
	_check(float(hp["food"]) >= Data.EAT_UP_TO and Game.mood(hp) == "happy", "a hungry pet eats from the store")
	_check(int(Game.res["berries"]) < 20, "eating uses up berries")

	# --- offline progress
	Game.res["wood"] = 0
	Game.res["stone"] = 0
	Game.res["berries"] = 150
	var rep := Game.simulate(3600)
	_check(int(Game.res["wood"]) > 0 and int(Game.res["stone"]) > 0, "offline hour gathers wood and stone")
	_check(int(Game.res["wood"]) <= Game.storage_cap("wood"), "offline gathering respects storage")
	_check(int(Game.stats.get("trips", 0)) > 0, "explorers made trips")
	_check(rep.has("gains"), "offline report built")
	main._sync()

	# --- screens
	main.zoom_level = 0.6
	main._apply_zoom()
	main.keeper.position = WorldMap.CENTER * 64.0 + Vector2(-120, 220)
	main.snap_camera()
	await _wait(1.2)
	await _shot("06_town")
	main.zoom_level = 0.85
	main._apply_zoom()
	_goto_building(camp)
	await _wait(0.6)
	main.tap_world(WorldMap.cell_to_world(camp["cell"]) + Vector2(64, 64))
	await _wait(0.2)
	_check(main.hud.is_modal_open(), "tapping a building opens its panel")
	await _shot("07_lumber_panel")
	main.hud.open_pet(int(p2["id"]))
	await _wait(0.2)
	await _shot("08_pet")
	main.hud.open_building(int(shop["id"]))
	await _wait(0.2)
	await _shot("09_workshop")
	main.hud.open_building(int(Game.buildings_of("town_hall")[0]["id"]))
	await _wait(0.2)
	await _shot("10_townhall")
	main.hud.open_build()
	await _wait(0.3)
	await _shot("11_build")
	main.hud._pets_tab = "mine"
	main.hud.open_pets()
	await _wait(0.2)
	await _shot("12_pets")
	main.hud._pets_tab = "log"
	main.hud.open_pets()
	await _wait(0.2)
	await _shot("13_petlog")
	await _close_all()
	main.start_placing("house")
	main.tap_world(WorldMap.cell_to_world(Vector2i(46, 46)))
	await _wait(0.3)
	await _shot("14_placing")
	main.cancel_place()
	_goto_building(dock, Vector2(0, -40))
	main.keeper.position.x -= 200
	main.snap_camera()
	await _wait(0.8)
	await _shot("15_lake")
	_goto_building(mine)
	main.snap_camera()
	await _wait(0.8)
	await _shot("16_crystal")

	# --- save / load
	Game.save_game()
	var n_pets := Game.pets.size()
	var n_b := Game.buildings.size()
	_check(Game.load_game(), "save loads")
	_check(Game.pets.size() == n_pets and Game.buildings.size() == n_b, "save round-trips")

	await _save_tests()

	Game.reset_save()
	print("Screenshots: ", shot_dir)
	if failures.is_empty():
		print("SMOKE OK")
		get_tree().quit(0)
	else:
		print("SMOKE FAILED: ", failures)
		get_tree().quit(1)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _save_tests() -> void:
	# 1) a version-1 (sky island) save is upgraded, keeping pets, eggs and glimmer
	Game.reset_save()
	var v1 := {"glimmer": 321, "carried_egg": 9, "companion": 3, "next_id": 12, "jobs_done": 40,
		"discovered": ["fennec", "kitsune"],
		"pets": [{"id": 3, "species": "fennec", "level": 3, "xp": 5, "prism": true, "wish": "nap"},
			{"id": 5, "species": "kitsune", "level": 5, "xp": 0, "prism": false, "wish": "berries"}],
		"eggs": [{"id": 9, "type": "tide", "warmth": 30}, {"id": 10, "type": "ember", "warmth": 0}]}
	_write(Game.SAVE_PATH, JSON.stringify(v1))
	_check(Game.load_game(), "v1 save loads through migration")
	_check(Game.pets.size() == 2 and Game.find_pet(int(Game.pets[0]["id"]))["species"] == "fennec", "v1 pets kept")
	_check(int(Game.pets[0]["level"]) == 5 and int(Game.pets[1]["level"]) == 9, "v1 levels mapped to the 1-10 scale")
	_check(bool(Game.pets[0]["prism"]), "prismatic kept")
	_check(int(Game.res["glimmer"]) == 321, "v1 glimmer kept")
	_check(Game.eggs.size() == 2 and not Game.carried_egg().is_empty() and Game.carried_egg()["type"] == "tide", "v1 eggs kept, carried egg still carried")
	_check(not Game.buildings_of("town_hall").is_empty(), "migrated player gets a town")
	_check(Game.migration_note != "", "migration note for the player")
	Game.save_game()
	_check(int(Game._read_json(Game.SAVE_PATH)["version"]) == Game.SAVE_VERSION, "upgraded save written at the current version")
	# 1b) a version-2 save (before food and gathering limits) gets fed pets, full nodes and the right goal
	var v2 := Game._to_dict()
	v2["version"] = 2
	v2.erase("nodes")
	for p in v2["pets"]:
		p.erase("food")
	v2["goal_index"] = 11 # "dock" in the old 18-goal list
	_write(Game.SAVE_PATH, JSON.stringify(v2))
	_check(Game.load_game(), "v2 save loads through migration")
	_check(float(Game.pets[0].get("food", 0.0)) >= 1.0 and Game.node_regrow.is_empty(), "v2 pets fed, nodes full")
	_check(Data.GOALS[Game.goal_index]["id"] == "dock", "v2 goal progress kept")
	# 2) a save from a newer version is never overwritten
	var future := {"version": Game.SAVE_VERSION + 1, "secret": "keep me"}
	_write(Game.SAVE_PATH, JSON.stringify(future))
	_check(not Game.load_game() and Game.save_locked, "newer save is detected and locked")
	Game.save_game()
	_check(str(Game._read_json(Game.SAVE_PATH).get("secret", "")) == "keep me", "newer save left untouched")
	Game.save_locked = false
	# 3) a corrupt save falls back to the backup
	Game.reset_save()
	Game.res["glimmer"] = 777
	Game.save_game()
	Game.res["glimmer"] = 778
	Game.save_game() # 777 is now the .bak
	_write(Game.SAVE_PATH, "{ this is not json")
	_check(Game.load_game() and int(Game.res["glimmer"]) == 777, "corrupt save recovers from the backup")

