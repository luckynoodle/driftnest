extends Node
## Autoload "Game": player progress, rewards, hatching and saving.
## Saved to user:// — on the web this maps to the browser's IndexedDB,
## on iOS to the app's Documents sandbox.

signal changed
signal toast(text: String)
signal hatched(pet: Dictionary, is_new: bool)
signal leveled(pet: Dictionary)

const SAVE_PATH := "user://driftnest_save.json"
const SAVE_VERSION := 1

var glimmer: int = 0
var pets: Array = []
var eggs: Array = []
var carried_egg: int = -1
var companion: int = -1
var next_id: int = 1
var discovered: Dictionary = {}
var jobs_done: int = 0
var first_run := false

var rng := RandomNumberGenerator.new()
var _dirty := false
var _save_timer := 0.0


func _ready() -> void:
	rng.randomize()
	if not load_game():
		new_game()


func _process(delta: float) -> void:
	if _dirty:
		_save_timer += delta
		if _save_timer >= 2.0:
			save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _dirty:
			save_game()


# ---------------------------------------------------------------- state

func new_game() -> void:
	glimmer = 40
	pets = []
	eggs = []
	companion = -1
	next_id = 1
	discovered = {}
	jobs_done = 0
	first_run = true
	var e := add_egg("dawn")
	carried_egg = int(e["id"])
	save_game()
	changed.emit()


func mark_dirty() -> void:
	_dirty = true
	changed.emit()


func add_egg(egg_type: String) -> Dictionary:
	var e := {"id": next_id, "type": egg_type, "warmth": 0}
	next_id += 1
	eggs.append(e)
	return e


func find_egg(id: int) -> Dictionary:
	for e in eggs:
		if int(e["id"]) == id:
			return e
	return {}


func find_pet(id: int) -> Dictionary:
	for p in pets:
		if int(p["id"]) == id:
			return p
	return {}


func get_companion() -> Dictionary:
	return find_pet(companion)


func get_carried_egg() -> Dictionary:
	return find_egg(carried_egg)


func egg_ratio(e: Dictionary) -> float:
	if e.is_empty():
		return 0.0
	return clampf(float(e["warmth"]) / float(Data.EGGS[e["type"]]["warmth"]), 0.0, 1.0)


func pet_display_name(p: Dictionary) -> String:
	var n: String = Data.SPECIES[p["species"]]["name"]
	return ("Prismatic " + n) if bool(p.get("prism", false)) else n


# ---------------------------------------------------------------- actions

func buy_egg(egg_type: String) -> bool:
	var info: Dictionary = Data.EGGS[egg_type]
	var price := int(info["price"])
	if glimmer < price:
		toast.emit("You need %d more glimmer." % (price - glimmer))
		return false
	glimmer -= price
	var e := add_egg(egg_type)
	if carried_egg == -1:
		carried_egg = int(e["id"])
		toast.emit("Bought a %s — you're carrying it now!" % info["name"])
	else:
		toast.emit("Bought a %s! Swap eggs from the Eggs menu." % info["name"])
	mark_dirty()
	return true


func carry_egg(id: int) -> void:
	carried_egg = id
	mark_dirty()


func set_companion(id: int) -> void:
	companion = id
	var p := get_companion()
	if not p.is_empty() and str(p.get("wish", "")) == "":
		p["wish"] = _random_wish("")
	mark_dirty()


## Multiplier on chore speed from the current companion.
func job_speed(job_id: String) -> float:
	var mult := 1.0
	var p := get_companion()
	if not p.is_empty():
		mult += 0.08 * float(int(p["level"]) - 1)
		var hab: String = Data.JOBS[job_id]["habitat"]
		if hab != "" and Data.SPECIES[p["species"]]["habitat"] == hab:
			mult += 0.5
	return mult


func companion_wish() -> String:
	var p := get_companion()
	return "" if p.is_empty() else str(p.get("wish", ""))


func complete_job(job_id: String) -> Dictionary:
	var job: Dictionary = Data.JOBS[job_id]
	var result := {"glimmer": int(job["glimmer"]), "xp": 0, "warmth": 0, "wish": false,
		"level_up": false, "hatched": false}
	jobs_done += 1

	var p := get_companion()
	if not p.is_empty():
		var xp := int(job["xp"])
		if str(p.get("wish", "")) == job_id:
			result["wish"] = true
			xp *= 2
			result["glimmer"] = int(result["glimmer"]) + 10
			p["wish"] = _random_wish(job_id)
		result["xp"] = xp
		if int(p["level"]) < Data.MAX_LEVEL:
			p["xp"] = int(p["xp"]) + xp
			while int(p["level"]) < Data.MAX_LEVEL and int(p["xp"]) >= Data.xp_needed(int(p["level"])):
				p["xp"] = int(p["xp"]) - Data.xp_needed(int(p["level"]))
				p["level"] = int(p["level"]) + 1
				result["level_up"] = true
			if int(p["level"]) >= Data.MAX_LEVEL:
				p["xp"] = 0

	glimmer += int(result["glimmer"])

	var e := get_carried_egg()
	if not e.is_empty():
		result["warmth"] = int(job["warmth"])
		e["warmth"] = int(e["warmth"]) + int(job["warmth"])
		if int(e["warmth"]) >= int(Data.EGGS[e["type"]]["warmth"]):
			_hatch(e)
			result["hatched"] = true

	if result["level_up"]:
		leveled.emit(p)
	mark_dirty()
	return result


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


func _hatch(e: Dictionary) -> void:
	var egg_id := int(e["id"])
	for i in range(eggs.size() - 1, -1, -1):
		if int(eggs[i]["id"]) == egg_id:
			eggs.remove_at(i)
	var sid := roll_species(str(e["type"]))
	var pet := {"id": next_id, "species": sid, "level": 1, "xp": 0,
		"prism": rng.randf() < Data.PRISM_CHANCE, "wish": _random_wish("")}
	next_id += 1
	pets.append(pet)
	var is_new := not discovered.has(sid)
	discovered[sid] = true
	carried_egg = -1
	if not eggs.is_empty():
		carried_egg = int(eggs[0]["id"])
	if companion == -1:
		companion = int(pet["id"])
	hatched.emit(pet, is_new)


func _random_wish(exclude: String) -> String:
	var options: Array = []
	for j in Data.JOB_ORDER:
		if j != exclude:
			options.append(j)
	return str(options[rng.randi_range(0, options.size() - 1)])


# ---------------------------------------------------------------- saving

func save_game() -> void:
	_dirty = false
	_save_timer = 0.0
	var data := {
		"version": SAVE_VERSION,
		"glimmer": glimmer,
		"pets": pets,
		"eggs": eggs,
		"carried_egg": carried_egg,
		"companion": companion,
		"next_id": next_id,
		"discovered": discovered.keys(),
		"jobs_done": jobs_done,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not save: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data))
	f.close()


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = parsed
	glimmer = int(d.get("glimmer", 0))
	carried_egg = int(d.get("carried_egg", -1))
	companion = int(d.get("companion", -1))
	next_id = int(d.get("next_id", 1))
	jobs_done = int(d.get("jobs_done", 0))
	pets = []
	for p in d.get("pets", []):
		if typeof(p) == TYPE_DICTIONARY and Data.SPECIES.has(str(p.get("species", ""))):
			pets.append({"id": int(p["id"]), "species": str(p["species"]), "level": int(p.get("level", 1)),
				"xp": int(p.get("xp", 0)), "prism": bool(p.get("prism", false)), "wish": str(p.get("wish", ""))})
	eggs = []
	for e in d.get("eggs", []):
		if typeof(e) == TYPE_DICTIONARY and Data.EGGS.has(str(e.get("type", ""))):
			eggs.append({"id": int(e["id"]), "type": str(e["type"]), "warmth": int(e.get("warmth", 0))})
	discovered = {}
	for s in d.get("discovered", []):
		discovered[str(s)] = true
	if find_egg(carried_egg).is_empty():
		carried_egg = -1 if eggs.is_empty() else int(eggs[0]["id"])
	if find_pet(companion).is_empty():
		companion = -1 if pets.is_empty() else int(pets[0]["id"])
	first_run = false
	return true


func reset_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	new_game()
