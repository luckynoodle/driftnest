extends Node
## Balance check: a bot plays the opening of the game at simulated speed, the way a sensible
## new player would (follows the goals, hires pets, builds, crafts, feeds, sells extras), and
## prints when each milestone lands. It gathers by hand on real trees, rocks and bushes:
## walking between them, waiting for them to regrow, and stopping when a store is full.
##   godot --headless --path . -- --balance [--minutes=120]
## Two players are simulated:
##   typical  - hands-on at first, then lets the pets work. Must hit the plan's targets:
##              first hatch < 1 min, first new building < 5 min, Town Hall 2 in 30-45 min.
##   grinder  - holds the gather button non-stop for the first 30 minutes. Hand-gathering must
##              not skip the game: Town Hall 2 no sooner than 20 min.

const STEP := 0.5
const WALK_SPEED := 330.0 # px per second, same as the Keeper

var main = null
var t := 0.0
var log_rows: Array = []
var _milestones := {}
var _off := 0
var _profile := "typical"
# hand-gathering state
var _pos := WorldMap.CENTER
var _cell := Vector2i(-1, -1)
var _walk_left := 0.0
var _hand_t := 0.0
var _hand_count := 0
var _hungry_secs := 0.0


func _ready() -> void:
	_run.call_deferred()


func _mark(key: String, text: String) -> void:
	if _milestones.has(key):
		return
	_milestones[key] = t
	log_rows.append([t, text])


func _fmt(sec: float) -> String:
	return "%2d:%02d" % [int(sec) / 60, int(sec) % 60]


func _run() -> void:
	var minutes := 120
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--minutes="):
			minutes = int(arg.substr(10))
	Game.running = false
	Game.goal_done.connect(func(i): _mark("goal_" + str(Data.GOALS[i]["id"]), "Goal %d done: %s" % [i + 1, Data.GOALS[i]["text"]]))
	Game.hatched.connect(func(p, _new): _mark("hatch%d" % Game.pets.size(), "Pet #%d hatched (%s)" % [Game.pets.size(), Data.SPECIES[p["species"]]["name"]]))
	Game.building_done.connect(func(b): _mark("built_" + str(b["type"]), "First %s finished" % Data.BUILDINGS[b["type"]]["name"]))
	for profile in ["typical", "grinder"]:
		_play(profile, minutes)
	Game.reset_save()
	print("BALANCE OK" if _off == 0 else "BALANCE OFF (%d target(s) missed)" % _off)
	get_tree().quit(0 if _off == 0 else 1)


func _play(profile: String, minutes: int) -> void:
	Game.reset_save()
	Game.running = false
	# fixed luck (eggs, explorer finds) so every machine sees the same run; --seed=N to try others
	var seed := 20261107
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seed = int(arg.substr(7))
	Game.rng.seed = seed
	_profile = profile
	t = 0.0
	log_rows = []
	_milestones = {}
	_pos = WorldMap.CENTER
	_cell = Vector2i(-1, -1)
	_walk_left = 0.0
	_hand_count = 0
	_hungry_secs = 0.0
	var end := minutes * 60.0
	var snapshots := {}
	while t < end:
		_think()
		Game.tick(STEP)
		t += STEP
		for p in Game.pets:
			if Game.mood(p) == "hungry":
				_hungry_secs += STEP
		for m in [10, 20, 30, 45, 60, 90, 120]:
			if not snapshots.has(m) and t >= m * 60.0:
				snapshots[m] = "pets %d/%d, town %d, built %d, glimmer %d, wood %d/%d, stone %d/%d, berries %d/%d, fish %d, crystal %d, goal %d/%d, by hand %d" % [
					Game.pets.size(), Game.capacity(), Game.town_level, Game.buildings.filter(func(b): return bool(b["built"])).size(),
					Game.res["glimmer"], Game.res["wood"], Game.storage_cap("wood"), Game.res["stone"], Game.storage_cap("stone"),
					Game.res["berries"], Game.storage_cap("berries"), Game.res["fish"], Game.res["crystal"],
					Game.goal_index, Data.GOALS.size(), _hand_count]
	print("\n=== %s player: %d simulated minutes ===" % [profile.capitalize(), minutes])
	for r in log_rows:
		if not str(r[1]).begins_with("Pet #") or str(r[1]).begins_with("Pet #1 ") or str(r[1]).begins_with("Pet #2 "):
			print("  %s  %s" % [_fmt(r[0]), r[1]])
	print("--- Snapshots ---")
	for m in [10, 20, 30, 45, 60, 90, 120]:
		if snapshots.has(m):
			print("  %3d min: %s" % [m, snapshots[m]])
	var pet_secs := 0.0
	print("  Hungry pet-minutes over the run: %d" % int(_hungry_secs / 60.0))
	print("--- Targets ---")
	var th2: float = _milestones.get("goal_town2", INF)
	if profile == "typical":
		_target("First hatch", _milestones.get("hatch1", INF), 0, 60)
		var first_build := INF
		for k in _milestones:
			if str(k).begins_with("built_"):
				first_build = minf(first_build, _milestones[k])
		_target("First new building finished", first_build, 0, 300)
		_target("Town Hall level 2", th2, 1800, 2700)
	else:
		_target("Town Hall 2 (grinding by hand)", th2, 1200, 2700)


func _target(name: String, at: float, lo: float, hi: float) -> void:
	var ok := at >= lo and at <= hi
	if not ok:
		_off += 1
	print("  %-32s %s   target %s to %s   %s" % [name, "never" if at == INF else _fmt(at), _fmt(lo), _fmt(hi), "OK" if ok else "OFF"])


# ================================================================ the bot

func _duty() -> float:
	## Share of each minute the player spends gathering by hand.
	if _profile == "grinder":
		return 1.0 if t < 1800.0 else 0.15
	if t < 600.0:
		return 0.5
	return 0.15 if t < 1800.0 else 0.05


func _think() -> void:
	if fmod(t, 60.0) < _duty() * 60.0:
		_hand_gather()
	_staff()
	_follow_goal()
	_housekeeping()


func _hand_gather() -> void:
	if _walk_left > 0.0:
		_walk_left -= STEP
		return
	var kind := _wanted_node()
	if _cell.x < 0 or Game.node_kind(_cell) != kind or Game.node_left(_cell) <= 0:
		_cell = _nearest(kind)
		if _cell.x < 0:
			return
		_walk_left = (Vector2(_cell) - _pos).length() * WorldMap.TILE / WALK_SPEED + 0.3
		_pos = Vector2(_cell)
		return
	var cadence := 1.5 if kind == "crystal" else (1.0 if kind == "water" else 0.5)
	_hand_t += STEP
	if _hand_t < cadence:
		return
	_hand_t = 0.0
	var r := Game.keeper_gather_at(_cell)
	if r != "" and r != "empty" and r != "full":
		_hand_count += 1


func _nearest(kind: String) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for cell in Game.map.nodes:
		if Game.map.nodes[cell] != kind or Game.node_left(cell) <= 0:
			continue
		var d := (Vector2(cell) - _pos).length()
		if d < best_d and (Vector2(cell) - WorldMap.CENTER).length() < 22.0:
			best_d = d
			best = cell
	return best


func _wanted_node() -> String:
	if not Game.pets.is_empty() and int(Game.res["berries"]) < 15 and not Game.is_full("berries"):
		return "bush"
	var g := Game.current_goal()
	var cost := _goal_cost(g)
	var pick := "tree"
	if int(cost.get("stone", 0)) > int(Game.res["stone"]) and int(Game.res["wood"]) >= int(cost.get("wood", 0)):
		pick = "rock"
	elif int(cost.get("berries", 0)) > int(Game.res["berries"]):
		pick = "bush"
	elif Game.res["wood"] > Game.res["stone"] + 20:
		pick = "rock"
	if Game.is_full(Data.NODES[pick]["res"]):
		pick = "rock" if pick == "tree" else "tree"
	return pick


func _goal_cost(g: Dictionary) -> Dictionary:
	if g.is_empty():
		return {}
	var map := {"lumber": "lumber_camp", "house": "house", "farm": "berry_farm", "storehouse": "storehouse", "quarry": "quarry", "workshop": "workshop",
		"dock": "fishing_dock", "explore": "explorer_lodge", "crystal": "crystal_mine"}
	if map.has(g["id"]):
		return Game.build_cost(map[g["id"]])
	if g["id"] in ["town2", "town3"] and Game.town_level < Data.TOWN_LEVELS.size():
		return Data.TOWN_LEVELS[Game.town_level]["cost"]
	return {}


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


func _place(type: String) -> bool:
	if not Game.can_afford(Game.build_cost(type)):
		_sell_for(Game.build_cost(type))
		return false
	var c := _spot(type)
	if c.x < 0:
		return false
	return not Game.place_building(type, c).is_empty()


func _has_any(type: String) -> bool:
	return not Game.buildings_of(type, false).is_empty()


func _sell_for(cost: Dictionary) -> void:
	## Short on glimmer only: sell spare goods at the Market (keep a working reserve).
	var need := int(cost.get("glimmer", 0)) - int(Game.res["glimmer"])
	if need <= 0 or not Game.has_built("market"):
		return
	for r in ["fish", "berries", "stone", "wood", "crystal"]:
		var keep := int(cost.get(r, 0)) + 60
		var spare := int(Game.res[r]) - keep
		if spare >= 10 and need > 0:
			var lots := mini(spare / 10, ceili(float(need) / float(Data.RESOURCES[r]["sell10"])))
			need -= Game.sell(r, lots * 10)


func _staff() -> void:
	# keep one builder, then fill workplaces in this order
	var order := ["building", "woodcutting", "mining", "foraging", "fishing", "exploring"]
	if int(Game.res["berries"]) < 40 and not Game.pets.is_empty():
		order = ["building", "foraging", "woodcutting", "mining", "fishing", "exploring"]
	for p in Game.pets:
		if int(p["work"]) != -1:
			continue
		for job in order:
			var wp := _free_workplace(job)
			if wp.is_empty():
				continue
			if job == "building" and Game.construction_target().is_empty() and _builders() >= 1:
				continue
			var kind: String = Data.JOBS[job]["tool"]
			if Game.pet_job(p) != job:
				var spare := Game.free_tools().filter(func(t): return t["kind"] == kind)
				if spare.is_empty():
					if Game.has_built("workshop") and Game.can_afford(Data.TIERS[0]["cost"]):
						Game.craft(kind, 0)
						spare = Game.free_tools().filter(func(t): return t["kind"] == kind)
				if spare.is_empty():
					continue
				Game.give_tool(int(p["id"]), int(spare[0]["id"]))
			if Game.assign(int(p["id"]), int(wp["id"])) == "":
				break


func _builders() -> int:
	var n := 0
	for hut in Game.buildings_of("builder_hut"):
		n += Game.workers_at(int(hut["id"])).size()
	return n


func _free_workplace(job: String) -> Dictionary:
	for b in Game.buildings:
		if bool(b["built"]) and Data.BUILDINGS[b["type"]].get("job", "") == job \
				and Game.workers_at(int(b["id"])).size() < int(Data.BUILDINGS[b["type"]]["slots"]):
			return b
	return {}


func _follow_goal() -> void:
	var g := Game.current_goal()
	if g.is_empty():
		return
	match str(g["id"]):
		"lumber":
			if not _has_any("lumber_camp"): _place("lumber_camp")
		"house":
			if not _has_any("house"): _place("house")
		"farm":
			if not _has_any("berry_farm"): _place("berry_farm")
		"storehouse":
			if not _has_any("storehouse"): _place("storehouse")
		"quarry":
			if not _has_any("quarry"): _place("quarry")
		"workshop":
			if not _has_any("workshop"): _place("workshop")
		"craft":
			if Game.can_afford(Data.TIERS[0]["cost"]): Game.craft("pickaxe", 0)
		"feed":
			if not Game.pets.is_empty() and int(Game.res["berries"]) > 0: Game.feed(int(Game.pets[0]["id"]), "berries")
		"egg":
			if not _has_any("market"): _place("market")
			if int(Game.res["glimmer"]) >= 90: Game.buy_egg("meadow")
			else: _sell_for({"glimmer": 90})
		"town2", "town3":
			var cost: Dictionary = Data.TOWN_LEVELS[Game.town_level]["cost"]
			if Game.can_afford(cost): Game.upgrade_town()
			else: _sell_for(cost)
		"dock":
			if not _has_any("fishing_dock"): _place("fishing_dock")
		"charm":
			if Game.construction_target().is_empty():
				for deco in ["lamp", "flower_bed", "sapling"]:
					if Game.can_afford(Game.build_cost(deco)):
						_place(deco)
						break
		"level5":
			var best: Dictionary = Game.pets[0]
			for p in Game.pets:
				if int(p["level"]) > int(best["level"]): best = p
			if int(Game.res["fish"]) > 5: Game.feed(int(best["id"]), "fish")
			elif int(Game.res["berries"]) > 20: Game.feed(int(best["id"]), "berries")
		"explore":
			if not _has_any("explorer_lodge"): _place("explorer_lodge")
		"dex8":
			if int(Game.res["glimmer"]) >= 250 and Game.eggs.size() < 2: Game.buy_egg("tide")
			elif int(Game.res["glimmer"]) >= 90 and Game.eggs.size() < 2: Game.buy_egg("meadow")
		"crystal":
			if not _has_any("crystal_mine"): _place("crystal_mine")


func _housekeeping() -> void:
	# room for waiting eggs
	var waiting := Game.eggs.filter(func(e): return bool(e.get("waiting", false)))
	if not waiting.is_empty() and Game.construction_target().is_empty() and Game.goal_index > 3:
		_place("house")
	# a new egg whenever there's room and nothing is warming (after the egg tutorial goal)
	if Game.goal_index > 10 and Game.eggs.is_empty() and Game.pets.size() < Game.capacity():
		if int(Game.res["glimmer"]) >= 90 + 40:
			Game.buy_egg("meadow")
	# keep the carried egg slot full
	if Game.carried_egg().is_empty():
		var bag := Game.eggs_at("bag")
		if not bag.is_empty():
			Game.move_egg(int(bag[0]["id"]), "carry")
	# a Market once there's a Workshop (players see it in the Build menu)
	if Game.has_built("workshop") and not _has_any("market") and Game.construction_target().is_empty():
		_place("market")
	# more room once the town is full and there's glimmer for another egg
	if Game.pets.size() >= Game.capacity() and Game.goal_index > 11 and Game.construction_target().is_empty() \
			and int(Game.res["glimmer"]) >= 150:
		_place("house")
	# a Storehouse when the next Town Hall upgrade won't fit in storage
	if Game.town_level < Data.TOWN_LEVELS.size() and Game.construction_target().is_empty() and Game.goal_index > 11:
		var nxt: Dictionary = Data.TOWN_LEVELS[Game.town_level]["cost"]
		for r in nxt:
			if r != "glimmer" and int(nxt[r]) > Game.storage_cap(r):
				_place("storehouse")
				break
	# second workplaces once the first is full
	if Game.goal_index > 7 and Game.construction_target().is_empty():
		for pair in [["berry_farm", 9], ["lumber_camp", 10]]:
			if Game.buildings_of(pair[0], false).size() < 2 and Game.goal_index >= pair[1] and Game.pets.size() >= 4:
				_place(pair[0])
