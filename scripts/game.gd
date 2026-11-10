extends Node
## Autoload "Game": all town state and the simulation (pets working, building, eggs warming),
## plus saving and offline progress. Visual nodes only *read* from here and listen to signals.
## Saved to user:// — browser IndexedDB on the web, the app's sandbox on iOS.

signal changed
signal toast(text: String)
signal hatched(pet: Dictionary, is_new: bool)
signal leveled(pet: Dictionary)
signal skill_up(pet: Dictionary, job: String)
signal produced(pet_id: int, building_id: int, res: String, amount: int)
signal building_done(building: Dictionary)
signal goal_done(index: int)
signal egg_found(egg: Dictionary)
signal welcome_back(report: Dictionary)
signal settings_changed
signal keeper_changed
signal node_changed(cell: Vector2i)

const SAVE_PATH := "user://driftnest_save.json"
const SAVE_VERSION := 3

var res: Dictionary = {}
var pets: Array = []
var eggs: Array = [] # {id, type, warmth, loc: "carry"|"nest"|"bag", waiting}
var tools: Array = [] # {id, kind, tier}
var buildings: Array = [] # {id, type, cell: Vector2i, built, progress}
var town_level := 1
var discovered: Dictionary = {}
var goal_index := 0
var stats: Dictionary = {}
var next_id := 1
var first_run := false
## How the Keeper looks (see Models3D.KEEPER_DEFAULT). Empty = the default Meadow Keeper.
var keeper_look := {}
var offline_report: Dictionary = {}

var map := WorldMap.new()
var rng := RandomNumberGenerator.new()
var running := true
var simulating := false

var _house_t := 0.0
## Natural resources that have been gathered from: cell -> units left, and cell -> seconds until regrown.
var node_stock: Dictionary = {}
var node_regrow: Dictionary = {}
var _decor_cache: Dictionary = {}
var _hunger_toast_t := 0.0
var _dirty := false
var _save_timer := 0.0
var _goal_timer := 0.0
var _pending_hatches: Array = []
var _last_wall := 0.0


## Per-device preferences (not part of the town save).
const SETTINGS_PATH := "user://settings.cfg"
var settings := {"effects": true, "ambient": true, "show_fps": false, "ui_size": "auto", "view3d": true, "daynight": true}
var build_info := {}


func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		for k in settings.keys():
			settings[k] = cf.get_value("settings", k, settings[k])
	if FileAccess.file_exists("res://build_info.json"):
		var f := FileAccess.open("res://build_info.json", FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			build_info = parsed


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	var cf := ConfigFile.new()
	for k in settings.keys():
		cf.set_value("settings", k, settings[k])
	cf.save(SETTINGS_PATH)
	settings_changed.emit()


func version_text() -> String:
	var v := "Driftnest %s" % ProjectSettings.get_setting("application/config/version", "dev")
	if build_info.has("commit"):
		v += "  ·  build %s, %s" % [str(build_info["commit"]).substr(0, 7), str(build_info.get("date", ""))]
	return v


func _ready() -> void:
	_load_settings()
	var font: Font = load("res://fonts/Nunito-ExtraBold.woff2")
	if font:
		ThemeDB.fallback_font = font
	rng.randomize()
	if not load_game():
		new_game()


func _process(delta: float) -> void:
	# If the app was suspended (iOS background, hidden browser tab), catch up on the missed time.
	var now := Time.get_unix_time_from_system()
	if _last_wall > 0.0 and now - _last_wall > 10.0 and running:
		var rep := simulate(minf(now - _last_wall, Data.OFFLINE_CAP))
		welcome_back.emit(rep)
	_last_wall = now
	if running:
		tick(delta)
	_save_timer += delta
	if _dirty and _save_timer >= 3.0:
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_game()


# ================================================================ new game

func new_game() -> void:
	_fresh_state()
	keeper_look = {}
	keeper_changed.emit()
	first_run = true
	save_game()
	changed.emit()


## A brand-new town in memory (no saving, no signals).
func _fresh_state() -> void:
	node_stock = {}
	node_regrow = {}
	res = {"glimmer": 50, "wood": 25, "stone": 10, "berries": 6, "fish": 0, "crystal": 0}
	pets = []
	eggs = []
	tools = []
	buildings = []
	town_level = 1
	discovered = {}
	goal_index = 0
	stats = {"crafted": 0, "fed": 0, "bought": 0, "trips": 0, "hatched": 0}
	next_id = 1
	offline_report = {}
	_add_building("town_hall", Vector2i(39, 39), true)
	_add_building("nest", Vector2i(35, 41), true)
	_add_building("kiosk", Vector2i(44, 41), true)
	_add_building("builder_hut", Vector2i(36, 36), true)
	var dawn := _add_egg("dawn", "carry")
	dawn["warmth"] = 0.0
	_add_egg("meadow", "nest")
	for k in ["hammer", "axe", "basket"]:
		_add_tool(k, 0)


func _new_id() -> int:
	next_id += 1
	return next_id - 1


func _add_building(type: String, cell: Vector2i, built: bool) -> Dictionary:
	var b := {"id": _new_id(), "type": type, "cell": cell, "built": built, "progress": 0.0}
	buildings.append(b)
	return b


func _add_egg(type: String, loc: String) -> Dictionary:
	var e := {"id": _new_id(), "type": type, "warmth": 0.0, "loc": loc, "waiting": false}
	eggs.append(e)
	return e


func _add_tool(kind: String, tier: int) -> Dictionary:
	var t := {"id": _new_id(), "kind": kind, "tier": tier}
	tools.append(t)
	return t


func mark_dirty() -> void:
	_dirty = true
	_check_goals()
	changed.emit()


# ================================================================ lookups

func find_pet(id: int) -> Dictionary:
	for p in pets:
		if int(p["id"]) == id:
			return p
	return {}


func find_building(id: int) -> Dictionary:
	for b in buildings:
		if int(b["id"]) == id:
			return b
	return {}


func find_egg(id: int) -> Dictionary:
	for e in eggs:
		if int(e["id"]) == id:
			return e
	return {}


func find_tool(id: int) -> Dictionary:
	for t in tools:
		if int(t["id"]) == id:
			return t
	return {}


func carried_egg() -> Dictionary:
	for e in eggs:
		if e["loc"] == "carry":
			return e
	return {}


func eggs_at(loc: String) -> Array:
	return eggs.filter(func(e): return e["loc"] == loc)


func buildings_of(type: String, only_built: bool = true) -> Array:
	return buildings.filter(func(b): return b["type"] == type and (bool(b["built"]) or not only_built))


func has_built(type: String) -> bool:
	return not buildings_of(type).is_empty()


func workers_at(bid: int) -> Array:
	return pets.filter(func(p): return int(p["work"]) == bid)


func tool_owner(tool_id: int) -> Dictionary:
	for p in pets:
		if int(p["tool"]) == tool_id:
			return p
	return {}


func free_tools() -> Array:
	return tools.filter(func(t): return tool_owner(int(t["id"])).is_empty())


func pet_tool(p: Dictionary) -> Dictionary:
	return find_tool(int(p["tool"]))


func pet_job(p: Dictionary) -> String:
	var t := pet_tool(p)
	return "" if t.is_empty() else str(Data.TOOLS[str(t["kind"])]["job"])


func pet_name(p: Dictionary) -> String:
	var n: String = Data.SPECIES[p["species"]]["name"]
	return ("Prismatic " + n) if bool(p.get("prism", false)) else n


func skill(p: Dictionary, job: String) -> Dictionary:
	var sk: Dictionary = p["skills"]
	if not sk.has(job):
		sk[job] = {"lvl": 1, "xp": 0.0}
	return sk[job]


func has_talent(p: Dictionary, job: String) -> bool:
	return job in Data.SPECIES[p["species"]]["talents"]


func capacity() -> int:
	return Data.BASE_CAPACITY + Data.HOUSE_CAPACITY * buildings_of("house").size()


func nest_slots() -> int:
	return town_level


func town_radius() -> float:
	return float(Data.TOWN_LEVELS[town_level - 1]["radius"])


func charm() -> int:
	var c := 0
	for b in buildings:
		if bool(b["built"]):
			c += int(Data.BUILDINGS[b["type"]].get("charm", 0))
	return c


func charm_mult() -> float:
	return 1.0 + minf(float(charm()), 50.0) / 100.0


func can_afford(cost: Dictionary) -> bool:
	for r in cost:
		if int(res.get(r, 0)) < int(cost[r]):
			return false
	return true


func spend(cost: Dictionary) -> void:
	for r in cost:
		res[r] = int(res.get(r, 0)) - int(cost[r])


## Add a resource, up to the storage limit (never removes anything already over it).
## Returns how much actually went in.
func gain(r: String, n: int) -> int:
	var have := int(res.get(r, 0))
	var cap := storage_cap(r)
	var room := maxi(0, cap - have)
	var added := mini(n, room) if n > 0 else n
	res[r] = have + added
	return added


func storage_cap(r: String) -> int:
	if not Data.STORAGE_BASE.has(r):
		return 1 << 30
	return int(Data.STORAGE_BASE[r]) + int(Data.STORAGE_PER_TOWN_LEVEL[r]) * (town_level - 1) \
		+ int(Data.STORAGE_PER_STOREHOUSE[r]) * buildings_of("storehouse").size()


func is_full(r: String) -> bool:
	return int(res.get(r, 0)) >= storage_cap(r)


# ---------------------------------------------------------------- natural resources

func node_kind(cell: Vector2i) -> String:
	if map.nodes.has(cell):
		return str(map.nodes[cell])
	if map.water.has(cell):
		return "water"
	return ""


func node_left(cell: Vector2i) -> int:
	if node_regrow.has(cell):
		return 0
	var kind := node_kind(cell)
	if kind == "":
		return 0
	return int(node_stock.get(cell, Data.NODES[kind]["stock"]))


## 0 = full, 1 = just emptied, 2 = growing back (past halfway).
func node_stage(cell: Vector2i) -> int:
	if not node_regrow.has(cell):
		return 0
	var kind := node_kind(cell)
	var total := float(Data.NODES[kind]["regrow"])
	return 2 if float(node_regrow[cell]) < total * 0.5 else 1


func _regrow_mult(cell: Vector2i) -> float:
	for b in buildings:
		if b["type"] == "sapling" and bool(b["built"]):
			var d: Vector2i = b["cell"] - cell
			if absi(d.x) <= Data.SAPLING_RADIUS and absi(d.y) <= Data.SAPLING_RADIUS:
				return Data.SAPLING_REGROW_MULT
	return 1.0


func _tick_nodes(dt: float) -> void:
	if node_regrow.is_empty():
		return
	for cell in node_regrow.keys():
		var before := node_stage(cell)
		node_regrow[cell] = float(node_regrow[cell]) - dt * _regrow_mult(cell)
		if float(node_regrow[cell]) <= 0.0:
			node_regrow.erase(cell)
			node_stock.erase(cell)
			if not simulating:
				node_changed.emit(cell)
		elif node_stage(cell) != before and not simulating:
			node_changed.emit(cell)


## The Keeper gathering by hand. Returns the resource gained, or "empty" / "full" / "".
func keeper_gather_at(cell: Vector2i) -> String:
	var kind := node_kind(cell)
	if kind == "":
		return ""
	var left := node_left(cell)
	if left <= 0:
		return "empty"
	var r: String = Data.NODES[kind]["res"]
	if is_full(r):
		return "full"
	gain(r, 1)
	left -= 1
	if left <= 0:
		node_stock.erase(cell)
		node_regrow[cell] = float(Data.NODES[kind]["regrow"])
	else:
		node_stock[cell] = left
	node_changed.emit(cell)
	var e := carried_egg()
	if not e.is_empty():
		e["warmth"] = minf(float(Data.EGGS[e["type"]]["warmth"]), float(e["warmth"]) + 1.0)
	mark_dirty()
	return r


# ---------------------------------------------------------------- food and mood

func mood(p: Dictionary) -> String:
	var f := float(p.get("food", 1.0))
	if f >= Data.EAT_BELOW:
		return "happy"
	if f >= 0.2:
		return "okay"
	return "hungry"


## Extra speed from decorations placed near a workplace.
func decor_bonus(b: Dictionary) -> float:
	var bid := int(b["id"])
	if _decor_cache.has(bid):
		return float(_decor_cache[bid])
	var size: Vector2i = Data.BUILDINGS[b["type"]]["size"]
	var area := Rect2i(b["cell"] - Vector2i(Data.DECOR_RADIUS, Data.DECOR_RADIUS), size + Vector2i(Data.DECOR_RADIUS * 2, Data.DECOR_RADIUS * 2))
	var charm_near := 0
	for o in buildings:
		if bool(o["built"]) and area.has_point(o["cell"]):
			charm_near += int(Data.BUILDINGS[o["type"]].get("charm", 0))
	var bonus := minf(float(charm_near) * Data.DECOR_BONUS_PER_CHARM, Data.DECOR_BONUS_MAX)
	_decor_cache[bid] = bonus
	return bonus


func _eat(p: Dictionary) -> void:
	while float(p["food"]) < Data.EAT_UP_TO:
		var food := ""
		if int(res.get("berries", 0)) > 0:
			food = "berries"
		elif int(res.get("fish", 0)) > 0:
			food = "fish"
		if food == "":
			return
		res[food] = int(res[food]) - 1
		p["food"] = minf(1.0, float(p["food"]) + float(Data.FOOD_FILL[food]))


## Is this pet actually producing right now (not idle, not paused)?
func is_working(p: Dictionary) -> bool:
	var b := find_building(int(p["work"]))
	if b.is_empty() or not bool(b["built"]):
		return false
	var job: String = Data.BUILDINGS[b["type"]].get("job", "")
	if job == "" or pet_job(p) != job:
		return false
	if job == "building":
		return not construction_target().is_empty()
	return str(p.get("waiting", "")) == ""


func egg_ratio(e: Dictionary) -> float:
	if e.is_empty():
		return 0.0
	return clampf(float(e["warmth"]) / float(Data.EGGS[e["type"]]["warmth"]), 0.0, 1.0)


## How many units per second... expressed as seconds per unit for this pet at this building.
func work_interval(p: Dictionary, b: Dictionary) -> float:
	var info: Dictionary = Data.BUILDINGS[b["type"]]
	var job: String = info.get("job", "")
	if job == "":
		return INF
	var t := pet_tool(p)
	var mult := Data.skill_mult(int(skill(p, job)["lvl"])) * charm_mult()
	if not t.is_empty():
		mult *= float(Data.TIERS[int(t["tier"])]["mult"])
	if has_talent(p, job):
		mult *= Data.TALENT_MULT
	mult *= float(Data.MOOD_SPEED[mood(p)]) * (1.0 + decor_bonus(b))
	if job == "exploring":
		mult = minf(mult, Data.EXPLORE_MAX_SPEED) # trips can't get shorter than this
	return float(Data.JOBS[job]["time"]) * float(info.get("time_mult", 1.0)) / mult


func construction_target() -> Dictionary:
	for b in buildings:
		if not bool(b["built"]):
			return b
	return {}


# ================================================================ simulation

func tick(dt: float) -> void:
	_warm_eggs(dt)
	_tick_nodes(dt)
	_decor_cache.clear()
	var someone_hungry := false
	for p in pets:
		# hunger first: working pets get hungry faster, and eat from storage on their own
		p["food"] = maxf(0.0, float(p.get("food", 1.0)) - dt * (Data.HUNGER_WORKING if is_working(p) else Data.HUNGER_IDLE))
		if float(p["food"]) < Data.EAT_BELOW:
			_eat(p)
		if mood(p) == "hungry":
			someone_hungry = true
		var bid := int(p["work"])
		if bid == -1:
			continue
		var b := find_building(bid)
		if b.is_empty() or not bool(b["built"]):
			continue
		var job: String = Data.BUILDINGS[b["type"]].get("job", "")
		if job == "" or pet_job(p) != job:
			continue
		if job == "building" and construction_target().is_empty():
			p["t"] = 0.0
			continue
		# a full store pauses the workers who fill it
		var out: String = Data.BUILDINGS[b["type"]].get("res", "")
		if out != "" and is_full(out):
			p["waiting"] = "full"
			p["t"] = 0.0
			continue
		p["waiting"] = ""
		var interval := work_interval(p, b)
		p["t"] = float(p.get("t", 0.0)) + dt
		var guard := 0
		while float(p["t"]) >= interval and guard < 200:
			p["t"] = float(p["t"]) - interval
			guard += 1
			_work_unit(p, b, job)
			if job == "building" and construction_target().is_empty():
				p["t"] = 0.0
				break
	var houses := buildings_of("house").size()
	if houses > 0:
		_house_t += dt * float(houses) * charm_mult()
		while _house_t >= Data.HOUSE_GLIMMER_TIME:
			_house_t -= Data.HOUSE_GLIMMER_TIME
			gain("glimmer", 1)
	_hunger_toast_t = maxf(0.0, _hunger_toast_t - dt)
	if someone_hungry and _hunger_toast_t <= 0.0 and not simulating and int(res.get("berries", 0)) == 0 and int(res.get("fish", 0)) == 0:
		_hunger_toast_t = 300.0
		toast.emit("Your pets are hungry and working slowly! Pick berries or build a Berry Farm.")
	_goal_timer += dt
	if _goal_timer > 0.5:
		_goal_timer = 0.0
		_check_goals()
	_dirty = true


func _work_unit(p: Dictionary, b: Dictionary, job: String) -> void:
	var info: Dictionary = Data.BUILDINGS[b["type"]]
	match job:
		"building":
			var target := construction_target()
			if target.is_empty():
				return
			add_build_progress(target, 1.0)
		"exploring":
			_explore_trip(p, b)
		_:
			var r: String = info["res"]
			if gain(r, 1) <= 0:
				return
			if not simulating:
				produced.emit(int(p["id"]), int(b["id"]), r, 1)
	_give_xp(p, int(Data.JOBS[job]["xp"]))
	_give_skill_xp(p, job, float(Data.JOBS[job]["sxp"]))
	if not simulating:
		changed.emit()


func _explore_trip(p: Dictionary, b: Dictionary) -> void:
	stats["trips"] = int(stats.get("trips", 0)) + 1
	var g := rng.randi_range(5, 12) + int(skill(p, "exploring")["lvl"])
	gain("glimmer", g)
	var r: String = ["wood", "stone", "berries", "fish"][rng.randi_range(0, 3)]
	var n := rng.randi_range(3, 8)
	gain(r, n)
	if not simulating:
		produced.emit(int(p["id"]), int(b["id"]), "glimmer", g)
		produced.emit(int(p["id"]), int(b["id"]), r, n)
	var egg_chance := 0.12 + 0.01 * float(int(skill(p, "exploring")["lvl"]) - 1)
	if rng.randf() < egg_chance:
		var roll := rng.randf()
		var type := "meadow"
		if roll > 0.95:
			type = "aurora"
		elif roll > 0.8:
			type = "ember"
		elif roll > 0.5:
			type = "tide"
		var e := _add_egg(type, "bag")
		if carried_egg().is_empty():
			e["loc"] = "carry"
		if not simulating:
			egg_found.emit(e)
			toast.emit("%s found a %s while exploring!" % [pet_name(p), Data.EGGS[type]["name"]])


func _give_xp(p: Dictionary, xp: int) -> void:
	if int(p["level"]) >= Data.MAX_LEVEL:
		return
	p["xp"] = int(p["xp"]) + xp
	var up := false
	while int(p["level"]) < Data.MAX_LEVEL and int(p["xp"]) >= Data.xp_needed(int(p["level"])):
		p["xp"] = int(p["xp"]) - Data.xp_needed(int(p["level"]))
		p["level"] = int(p["level"]) + 1
		up = true
	if int(p["level"]) >= Data.MAX_LEVEL:
		p["xp"] = 0
	if up:
		# skills that were waiting at the cap can now catch up
		for job in p["skills"].keys():
			_give_skill_xp(p, job, 0.0)
		if not simulating:
			leveled.emit(p)


func _give_skill_xp(p: Dictionary, job: String, amount: float) -> void:
	var s := skill(p, job)
	var cap := int(p["level"])
	s["xp"] = float(s["xp"]) + amount
	while int(s["lvl"]) < cap and float(s["xp"]) >= Data.skill_xp_needed(int(s["lvl"])):
		s["xp"] = float(s["xp"]) - Data.skill_xp_needed(int(s["lvl"]))
		s["lvl"] = int(s["lvl"]) + 1
		if not simulating:
			skill_up.emit(p, job)
	if int(s["lvl"]) >= cap:
		s["xp"] = minf(float(s["xp"]), float(Data.skill_xp_needed(int(s["lvl"]))))


func add_build_progress(b: Dictionary, amount: float) -> void:
	if bool(b["built"]):
		return
	b["progress"] = float(b["progress"]) + amount
	if float(b["progress"]) >= float(Data.BUILDINGS[b["type"]]["work"]):
		b["built"] = true
		b["progress"] = 0.0
		if not simulating:
			building_done.emit(b)
			toast.emit("%s is finished!" % Data.BUILDINGS[b["type"]]["name"])
		mark_dirty()


func _warm_eggs(dt: float) -> void:
	var nest_used := 0
	for e in eggs.duplicate():
		var rate := 0.0
		if e["loc"] == "carry":
			rate = 1.0
		elif e["loc"] == "nest" and nest_used < nest_slots():
			nest_used += 1
			rate = 0.5
		if rate <= 0.0:
			continue
		var need := float(Data.EGGS[e["type"]]["warmth"])
		e["warmth"] = minf(need, float(e["warmth"]) + dt * rate)
		if float(e["warmth"]) >= need:
			if pets.size() < capacity():
				_hatch(e)
			elif not bool(e.get("waiting", false)):
				e["waiting"] = true
				if not simulating:
					toast.emit("Your %s is ready to hatch, but town is full. Build a House!" % Data.EGGS[e["type"]]["name"])
				changed.emit()


func _hatch(e: Dictionary) -> void:
	eggs.erase(e)
	var sid := roll_species(str(e["type"]))
	var pet := {"id": _new_id(), "species": sid, "level": 1, "xp": 0, "prism": rng.randf() < Data.PRISM_CHANCE,
		"tool": -1, "work": -1, "skills": {}, "t": 0.0, "food": 1.0}
	pets.append(pet)
	var is_new := not discovered.has(sid)
	discovered[sid] = true
	stats["hatched"] = int(stats.get("hatched", 0)) + 1
	if e["loc"] == "carry":
		# pick up the next waiting egg from the bag automatically
		for other in eggs:
			if other["loc"] == "bag":
				other["loc"] = "carry"
				break
	if simulating:
		_pending_hatches.append([pet, is_new])
	else:
		hatched.emit(pet, is_new)
	mark_dirty()


func roll_species(egg_type: String) -> String:
	var pool: Array = Data.EGGS[egg_type]["pool"]
	var total := 0
	for entry in pool:
		total += int(entry[1])
	var r := rng.randi_range(1, total)
	for entry in pool:
		r -= int(entry[1])
		if r <= 0:
			return str(entry[0])
	return str(pool[0][0])


## Fast-forward the simulation (used for offline progress).
func simulate(seconds: float) -> Dictionary:
	var before := res.duplicate()
	var hatched_before := int(stats.get("hatched", 0))
	var built_before := buildings.filter(func(b): return bool(b["built"])).size()
	simulating = true
	var step := 5.0
	var left := seconds
	while left > 0.0:
		var d := minf(step, left)
		tick(d)
		left -= d
	simulating = false
	var gains := {}
	for r in res:
		var diff := int(res[r]) - int(before.get(r, 0))
		if diff > 0:
			gains[r] = diff
	var report := {"seconds": seconds, "gains": gains,
		"hatched": int(stats.get("hatched", 0)) - hatched_before,
		"built": buildings.filter(func(b): return bool(b["built"])).size() - built_before}
	return report


## Hatches that happened during offline simulation, shown once the HUD is ready.
func take_pending_hatches() -> Array:
	var out := _pending_hatches
	_pending_hatches = []
	return out


# ================================================================ player actions

func can_place(type: String, cell: Vector2i, check_cost: bool = true) -> String:
	var info: Dictionary = Data.BUILDINGS[type]
	if int(info.get("th", 1)) > town_level:
		return "Needs Town Hall level %d" % int(info["th"])
	var size: Vector2i = info["size"]
	var rect := Rect2i(cell, size)
	var radius := town_radius()
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := Vector2i(x, y)
			if not WorldMap.in_bounds(c):
				return "Off the map"
			if (Vector2(c) + Vector2(0.5, 0.5)).distance_to(WorldMap.CENTER) > radius:
				return "Outside the town border"
			if map.water.has(c):
				return "Can't build on water"
			if map.nodes.has(c):
				return "Something is in the way"
	for b in buildings:
		var br := Rect2i(b["cell"], Data.BUILDINGS[b["type"]]["size"])
		if br.intersects(rect):
			return "Something is in the way"
	var need: String = info.get("need", "")
	if need != "":
		var n := 0
		var margin := 1 if need == "water" else 3
		n = map.count_near(rect, margin, need)
		if need == "tree":
			for b in buildings:
				if Data.BUILDINGS[b["type"]].get("counts_as", "") == "tree" and Rect2i(rect.position - Vector2i(3, 3), rect.size + Vector2i(6, 6)).has_point(b["cell"]):
					n += 1
		if n < int(info["need_n"]):
			match need:
				"tree": return "Needs %d trees nearby (%d)" % [int(info["need_n"]), n]
				"rock": return "Needs %d rocks nearby (%d)" % [int(info["need_n"]), n]
				"crystal": return "Needs a crystal outcrop nearby"
				"water": return "Must touch the water"
	if check_cost and not can_afford(build_cost(type)):
		return "Not enough resources"
	return ""


func place_building(type: String, cell: Vector2i) -> Dictionary:
	if can_place(type, cell) != "":
		return {}
	var info: Dictionary = Data.BUILDINGS[type]
	var cost := build_cost(type)
	spend(cost)
	var b := _add_building(type, cell, int(info["work"]) <= 0)
	b["paid"] = cost
	if bool(b["built"]):
		building_done.emit(b)
	elif _builders_count() == 0:
		toast.emit("Construction started! Send a pet with a hammer to the Builder's Hut, or help build it yourself.")
	mark_dirty()
	return b


## What the next copy of a building costs. Each extra house or workplace costs more than
## the last (Data.COST_GROWTH), so the town grows steadily instead of snowballing.
func build_cost(type: String) -> Dictionary:
	var info: Dictionary = Data.BUILDINGS[type]
	var base: Dictionary = info["cost"]
	if bool(info.get("deco", false)) or bool(info.get("fixed", false)):
		return base
	var n := buildings_of(type, false).size()
	if n == 0:
		return base
	var mult := pow(float(Data.COST_GROWTH.get(type, Data.COST_GROWTH["default"])), n)
	var out := {}
	for r in base:
		out[r] = int(ceilf(float(base[r]) * mult / 5.0) * 5.0)
	return out


func _builders_count() -> int:
	var n := 0
	for hut in buildings_of("builder_hut"):
		n += workers_at(int(hut["id"])).size()
	return n


func demolish(bid: int) -> void:
	var b := find_building(bid)
	if b.is_empty() or bool(Data.BUILDINGS[b["type"]].get("fixed", false)):
		return
	for p in workers_at(bid):
		p["work"] = -1
	var cost: Dictionary = b.get("paid", Data.BUILDINGS[b["type"]]["cost"])
	for r in cost:
		gain(r, int(cost[r]) / 2 if bool(b["built"]) else int(cost[r]))
	buildings.erase(b)
	mark_dirty()


func give_tool(pid: int, tool_id: int) -> void:
	var p := find_pet(pid)
	if p.is_empty():
		return
	var other := tool_owner(tool_id)
	if not other.is_empty() and other != p:
		other["tool"] = -1
		other["work"] = -1
	p["tool"] = tool_id
	# leave a workplace that no longer matches the tool
	var b := find_building(int(p["work"]))
	if not b.is_empty() and Data.BUILDINGS[b["type"]].get("job", "") != pet_job(p):
		p["work"] = -1
	mark_dirty()


func take_tool(pid: int) -> void:
	var p := find_pet(pid)
	if p.is_empty():
		return
	p["tool"] = -1
	p["work"] = -1
	mark_dirty()


func assign(pid: int, bid: int) -> String:
	var p := find_pet(pid)
	var b := find_building(bid)
	if p.is_empty() or b.is_empty():
		return "Missing pet or building"
	var job: String = Data.BUILDINGS[b["type"]].get("job", "")
	if job == "":
		return "Nobody works here"
	if not bool(b["built"]):
		return "Still under construction"
	if pet_job(p) != job:
		return "Needs a %s" % Data.TOOLS[Data.JOBS[job]["tool"]]["name"]
	if int(p["work"]) != bid and workers_at(bid).size() >= int(Data.BUILDINGS[b["type"]]["slots"]):
		return "No free spots"
	p["work"] = bid
	p["t"] = 0.0
	mark_dirty()
	return ""


func unassign(pid: int) -> void:
	var p := find_pet(pid)
	if not p.is_empty():
		p["work"] = -1
		mark_dirty()


## Best building of the right job with a free slot, for one-tap "Send to work".
func best_workplace(p: Dictionary) -> Dictionary:
	var job := pet_job(p)
	if job == "":
		return {}
	for b in buildings:
		if bool(b["built"]) and Data.BUILDINGS[b["type"]].get("job", "") == job \
				and workers_at(int(b["id"])).size() < int(Data.BUILDINGS[b["type"]]["slots"]):
			return b
	return {}


func craft(kind: String, tier: int) -> bool:
	if not has_built("workshop"):
		toast.emit("Build a Workshop first.")
		return false
	var cost: Dictionary = Data.TIERS[tier]["cost"]
	if not can_afford(cost):
		toast.emit("Not enough resources for that.")
		return false
	spend(cost)
	var t := _add_tool(kind, tier)
	stats["crafted"] = int(stats.get("crafted", 0)) + 1
	toast.emit("Crafted a %s!" % Data.tool_name(t))
	mark_dirty()
	return true


func feed(pid: int, food: String) -> bool:
	var p := find_pet(pid)
	if p.is_empty() or int(res.get(food, 0)) <= 0:
		return false
	if int(p["level"]) >= Data.MAX_LEVEL:
		toast.emit("%s is already fully grown!" % pet_name(p))
		return false
	res[food] = int(res[food]) - 1
	p["food"] = minf(1.0, float(p.get("food", 1.0)) + float(Data.FOOD_FILL[food]))
	_give_xp(p, int(Data.FOOD_XP[food]))
	stats["fed"] = int(stats.get("fed", 0)) + 1
	mark_dirty()
	return true


## Sell in lots of 10 at the Market. Returns the glimmer earned.
func sell(r: String, n: int) -> int:
	n = mini(n, int(res.get(r, 0)))
	n -= n % 10
	if n <= 0:
		return 0
	res[r] = int(res[r]) - n
	var earned := n / 10 * int(Data.RESOURCES[r]["sell10"])
	gain("glimmer", earned)
	mark_dirty()
	return earned


func buy_egg(type: String) -> bool:
	var price := int(Data.EGGS[type]["price"])
	if int(res["glimmer"]) < price:
		toast.emit("You need %d more glimmer." % (price - int(res["glimmer"])))
		return false
	res["glimmer"] = int(res["glimmer"]) - price
	var loc := "bag"
	if carried_egg().is_empty():
		loc = "carry"
	elif eggs_at("nest").size() < nest_slots():
		loc = "nest"
	_add_egg(type, loc)
	stats["bought"] = int(stats.get("bought", 0)) + 1
	var where := {"carry": "You're carrying it now.", "nest": "It's warming in the Nest.", "bag": "It's in your egg bag."}
	toast.emit("Bought a %s! %s" % [Data.EGGS[type]["name"], where[loc]])
	mark_dirty()
	return true


func move_egg(eid: int, loc: String) -> void:
	var e := find_egg(eid)
	if e.is_empty():
		return
	if loc == "carry":
		var c := carried_egg()
		if not c.is_empty():
			c["loc"] = "bag"
	elif loc == "nest" and eggs_at("nest").size() >= nest_slots():
		toast.emit("The Nest is full. Upgrade the Town Hall for more nest space.")
		return
	e["loc"] = loc
	mark_dirty()


func upgrade_town() -> bool:
	if town_level >= Data.TOWN_LEVELS.size():
		return false
	var cost: Dictionary = Data.TOWN_LEVELS[town_level]["cost"]
	if not can_afford(cost):
		toast.emit("Not enough resources to upgrade.")
		return false
	spend(cost)
	town_level += 1
	toast.emit("Town Hall is now level %d! The town border has grown." % town_level)
	mark_dirty()
	return true


# ================================================================ goals

func current_goal() -> Dictionary:
	if goal_index >= Data.GOALS.size():
		return {}
	return Data.GOALS[goal_index]


func _goal_met(id: String) -> bool:
	match id:
		"hatch": return pets.size() >= 1
		"builder":
			for hut in buildings_of("builder_hut"):
				if not workers_at(int(hut["id"])).is_empty():
					return true
			return false
		"lumber": return has_built("lumber_camp")
		"woodcutter": return _anyone_works_at("lumber_camp")
		"house": return has_built("house")
		"farm": return _anyone_works_at("berry_farm")
		"storehouse": return has_built("storehouse")
		"quarry": return has_built("quarry")
		"workshop": return has_built("workshop")
		"craft": return int(stats.get("crafted", 0)) >= 1
		"feed": return int(stats.get("fed", 0)) >= 1
		"egg": return int(stats.get("bought", 0)) >= 1
		"town2": return town_level >= 2
		"dock": return has_built("fishing_dock")
		"charm": return charm() >= 10
		"level5":
			for p in pets:
				if int(p["level"]) >= 5:
					return true
			return false
		"explore": return _anyone_works_at("explorer_lodge")
		"dex8": return discovered.size() >= 8
		"town3": return town_level >= 3
		"crystal": return has_built("crystal_mine")
	return false


func _anyone_works_at(type: String) -> bool:
	for b in buildings_of(type):
		if not workers_at(int(b["id"])).is_empty():
			return true
	return false


func _check_goals() -> void:
	var guard := 0
	while goal_index < Data.GOALS.size() and _goal_met(Data.GOALS[goal_index]["id"]) and guard < 30:
		guard += 1
		var g: Dictionary = Data.GOALS[goal_index]
		for r in g["reward"]:
			if r == "egg":
				var loc := "carry" if carried_egg().is_empty() else ("nest" if eggs_at("nest").size() < nest_slots() else "bag")
				_add_egg(str(g["reward"][r]), loc)
			else:
				gain(r, int(g["reward"][r]))
		goal_index += 1
		if not simulating:
			goal_done.emit(goal_index - 1)
		changed.emit()


# ================================================================ saving
#
# Saves are versioned. When the format changes, bump SAVE_VERSION and add a
# `_migrate_<n>` step that upgrades a version-n dictionary to version n+1, so players
# never lose their town. Writes go to a temp file first, then replace the save, and the
# previous save is kept as a .bak in case anything goes wrong.

const SAVE_TMP := "user://driftnest_save.tmp"
const SAVE_BAK := "user://driftnest_save.bak"

## Set when a save from a NEWER game version is found (e.g. an old cached web build):
## we play on a fresh town in memory but never overwrite that newer save.
var save_locked := false
## Shown once by the HUD after an old save is upgraded.
var migration_note := ""


func _to_dict() -> Dictionary:
	var bl: Array = []
	for b in buildings:
		bl.append({"id": b["id"], "type": b["type"], "x": b["cell"].x, "y": b["cell"].y,
			"built": b["built"], "progress": b["progress"], "paid": b.get("paid", {})})
	return {
		"version": SAVE_VERSION,
		"time": Time.get_unix_time_from_system(),
		"res": res, "pets": pets, "eggs": eggs, "tools": tools, "buildings": bl,
		"town_level": town_level, "discovered": discovered.keys(), "goal_index": goal_index,
		"stats": stats, "next_id": next_id, "house_t": _house_t,
		"nodes": _nodes_to_list(),
		"keeper": keeper_look,
	}


func save_game() -> void:
	_dirty = false
	_save_timer = 0.0
	if save_locked:
		return
	var f := FileAccess.open(SAVE_TMP, FileAccess.WRITE)
	if f == null:
		push_warning("Could not save: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(_to_dict()))
	f.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists(SAVE_PATH.get_file()):
		if dir.file_exists(SAVE_BAK.get_file()):
			dir.remove(SAVE_BAK.get_file())
		dir.rename(SAVE_PATH.get_file(), SAVE_BAK.get_file())
	dir.rename(SAVE_TMP.get_file(), SAVE_PATH.get_file())


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else null


func load_game() -> bool:
	var parsed = _read_json(SAVE_PATH)
	if parsed == null:
		parsed = _read_json(SAVE_BAK) # main save missing or corrupt: fall back to the backup
	if parsed == null:
		return false
	var d: Dictionary = parsed
	var version := int(d.get("version", 1))
	if version > SAVE_VERSION:
		save_locked = true
		push_warning("Save is from a newer version (%d); not touching it." % version)
		return false
	while version < SAVE_VERSION:
		d = call("_migrate_%d" % version, d)
		version += 1
		d["version"] = version
	_from_dict(d)
	first_run = false
	# offline progress
	var away := Time.get_unix_time_from_system() - float(d.get("time", Time.get_unix_time_from_system()))
	away = clampf(away, 0.0, Data.OFFLINE_CAP)
	offline_report = {}
	if away > 30.0:
		offline_report = simulate(away)
	return true


func _nodes_to_list() -> Array:
	var out: Array = []
	for cell in node_stock:
		out.append([cell.x, cell.y, int(node_stock[cell]), 0.0])
	for cell in node_regrow:
		out.append([cell.x, cell.y, 0, float(node_regrow[cell])])
	return out


func _from_dict(d: Dictionary) -> void:
	keeper_look = {}
	var kl = d.get("keeper", {})
	if typeof(kl) == TYPE_DICTIONARY:
		for k in kl:
			if Models3D.KEEPER_DEFAULT.has(str(k)):
				keeper_look[str(k)] = str(kl[k])
	keeper_changed.emit()
	res = {}
	for r in Data.RESOURCES:
		res[r] = int(d.get("res", {}).get(r, 0))
	pets = []
	for p in d.get("pets", []):
		if not Data.SPECIES.has(str(p.get("species", ""))):
			continue
		var skills := {}
		for job in p.get("skills", {}):
			if Data.JOBS.has(job):
				skills[job] = {"lvl": int(p["skills"][job]["lvl"]), "xp": float(p["skills"][job]["xp"])}
		pets.append({"id": int(p["id"]), "species": str(p["species"]), "level": clampi(int(p.get("level", 1)), 1, Data.MAX_LEVEL),
			"xp": int(p.get("xp", 0)), "prism": bool(p.get("prism", false)), "tool": int(p.get("tool", -1)),
			"work": int(p.get("work", -1)), "skills": skills, "t": float(p.get("t", 0.0)),
			"food": clampf(float(p.get("food", 1.0)), 0.0, 1.0)})
	eggs = []
	for e in d.get("eggs", []):
		if Data.EGGS.has(str(e.get("type", ""))):
			eggs.append({"id": int(e["id"]), "type": str(e["type"]), "warmth": float(e.get("warmth", 0)),
				"loc": str(e.get("loc", "bag")), "waiting": bool(e.get("waiting", false))})
	tools = []
	for t in d.get("tools", []):
		if Data.TOOLS.has(str(t.get("kind", ""))):
			tools.append({"id": int(t["id"]), "kind": str(t["kind"]), "tier": clampi(int(t.get("tier", 0)), 0, Data.TIERS.size() - 1)})
	buildings = []
	for b in d.get("buildings", []):
		if Data.BUILDINGS.has(str(b.get("type", ""))):
			var nb := {"id": int(b["id"]), "type": str(b["type"]), "cell": Vector2i(int(b["x"]), int(b["y"])),
				"built": bool(b.get("built", true)), "progress": float(b.get("progress", 0.0))}
			if typeof(b.get("paid")) == TYPE_DICTIONARY and not b["paid"].is_empty():
				nb["paid"] = b["paid"]
			buildings.append(nb)
	town_level = clampi(int(d.get("town_level", 1)), 1, Data.TOWN_LEVELS.size())
	discovered = {}
	for s in d.get("discovered", []):
		discovered[str(s)] = true
	goal_index = int(d.get("goal_index", 0))
	stats = d.get("stats", {})
	next_id = int(d.get("next_id", 1))
	_house_t = float(d.get("house_t", 0.0))
	node_stock = {}
	node_regrow = {}
	for n in d.get("nodes", []):
		var cell := Vector2i(int(n[0]), int(n[1]))
		if node_kind(cell) == "":
			continue
		if float(n[3]) > 0.0:
			node_regrow[cell] = float(n[3])
		elif int(n[2]) > 0:
			node_stock[cell] = int(n[2])


## Version 1 was the sky-island prototype: one companion, chores, no town.
## Keep the player's creatures, eggs, glimmer and Pet Log; give them a fresh town.
func _migrate_1(old: Dictionary) -> Dictionary:
	_fresh_state()
	var d := _to_dict()
	d["res"]["glimmer"] = maxi(int(d["res"]["glimmer"]), int(old.get("glimmer", 0)))
	var top_id := int(d["next_id"])
	var new_pets: Array = []
	for p in old.get("pets", []):
		if typeof(p) != TYPE_DICTIONARY or not Data.SPECIES.has(str(p.get("species", ""))):
			continue
		new_pets.append({"id": top_id, "species": str(p["species"]),
			"level": clampi(int(p.get("level", 1)) * 2 - 1, 1, Data.MAX_LEVEL), "xp": 0,
			"prism": bool(p.get("prism", false)), "tool": -1, "work": -1, "skills": {}, "t": 0.0})
		top_id += 1
	var new_eggs: Array = []
	var carried := int(old.get("carried_egg", -1))
	for e in old.get("eggs", []):
		if typeof(e) != TYPE_DICTIONARY or not Data.EGGS.has(str(e.get("type", ""))):
			continue
		var need := float(Data.EGGS[str(e["type"])]["warmth"])
		new_eggs.append({"id": top_id, "type": str(e["type"]), "warmth": minf(float(e.get("warmth", 0)), need * 0.9),
			"loc": "carry" if int(e.get("id", -2)) == carried else "bag", "waiting": false})
		top_id += 1
	if not new_pets.is_empty():
		d["pets"] = new_pets
		d["eggs"] = new_eggs # their old eggs replace the starter eggs
	var dex: Array = d["discovered"]
	for s in old.get("discovered", []):
		if not dex.has(str(s)):
			dex.append(str(s))
	for p in new_pets:
		if not dex.has(p["species"]):
			dex.append(p["species"])
	d["next_id"] = top_id
	d["time"] = Time.get_unix_time_from_system()
	migration_note = "Driftnest has grown into a town! Your %d pet(s) and their eggs moved in with you. Tap a pet to give it a job." % new_pets.size()
	return d


## Version 2 -> 3: pets now get hungry (start them full), resources deplete (start everything
## full), and two goals were added, so keep each player on the goal they had reached.
func _migrate_2(d: Dictionary) -> Dictionary:
	for p in d.get("pets", []):
		p["food"] = 1.0
	d["nodes"] = []
	var old_ids := ["hatch", "builder", "lumber", "woodcutter", "house", "quarry", "workshop", "craft", "feed", "egg",
		"town2", "dock", "charm", "level5", "explore", "dex8", "town3", "crystal"]
	var gi := int(d.get("goal_index", 0))
	if gi >= old_ids.size():
		d["goal_index"] = Data.GOALS.size()
	else:
		for i in Data.GOALS.size():
			if Data.GOALS[i]["id"] == old_ids[gi]:
				d["goal_index"] = i
				break
	return d


## Change how the Keeper looks (only the keys the creator offers are kept).
func set_keeper_look(look: Dictionary) -> void:
	keeper_look = {}
	for k in ["skin", "hair", "hair_col", "outfit", "hat", "hat_col"]:
		if look.has(k):
			keeper_look[k] = str(look[k])
	keeper_changed.emit()
	save_game()


func reset_save() -> void:
	var dir := DirAccess.open("user://")
	if dir:
		for p in [SAVE_PATH, SAVE_TMP, SAVE_BAK]:
			if dir.file_exists(p.get_file()):
				dir.remove(p.get_file())
	save_locked = false
	migration_note = ""
	_pending_hatches = []
	new_game()
