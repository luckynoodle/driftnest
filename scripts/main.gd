extends Node2D
## Builds the island world, moves the Keeper, runs chores and hands rewards to Game.

const SkyScript := preload("res://scripts/sky.gd")
const TerrainScript := preload("res://scripts/terrain.gd")
const PropScript := preload("res://scripts/prop.gd")

const CENTER := Vector2(1500, 1050)
const RADII := Vector2(1400, 900)
const WALK_LIMIT := 0.93
const SPEED := 320.0

var player: Keeper
var pet: PetFollower
var ysort: Node2D
var overlay: WorldOverlay
var terrain = null
var hud: GameHud
var world_center := CENTER
var world_radii := RADII
var cam: Camera2D

var stations: Array = []
var paths: Array = []
var active := -1
var progress := 0.0
var cooldown := 0.0
var mail_target := -1
var lantern_lit := [false, false, false]
var lantern_reset := 0.0

# test hook: scripted input used by the automated smoke test
var auto_dir := Vector2.ZERO


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#a8dcf2"))
	_define_stations()

	var sky: Node2D = SkyScript.new()
	sky.z_index = -20
	add_child(sky)

	terrain = TerrainScript.new()
	terrain.main = self
	terrain.z_index = -10
	add_child(terrain)

	ysort = Node2D.new()
	ysort.y_sort_enabled = true
	add_child(ysort)

	player = Keeper.new()
	player.position = CENTER + Vector2(0, 170)
	ysort.add_child(player)

	pet = PetFollower.new()
	pet.position = player.position + Vector2(-60, 0)
	ysort.add_child(pet)

	_spawn_props()

	overlay = WorldOverlay.new()
	overlay.main = self
	overlay.z_index = 50
	add_child(overlay)

	cam = Camera2D.new()
	cam.position = player.position
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	cam.limit_left = -300
	cam.limit_top = -300
	cam.limit_right = 3300
	cam.limit_bottom = 2450
	add_child(cam)
	cam.make_current()

	hud = GameHud.new()
	hud.main = self
	add_child(hud)

	Game.changed.connect(_refresh_pet)
	_refresh_pet()

	if "--smoke" in OS.get_cmdline_user_args():
		var smoke = load("res://tests/smoke.gd").new()
		smoke.main = self
		add_child(smoke)


# ================================================================ world layout

func _add_station(id: String, kind: String, job: String, pos: Vector2, radius: float, label: String, label_y: float, index: int = 0) -> void:
	stations.append({"id": id, "kind": kind, "job": job, "pos": pos, "radius": radius,
		"label": label, "label_y": label_y, "index": index})


func _define_stations() -> void:
	_add_station("nest", "timed", "nap", CENTER, 115, "The Nest", -80)
	_add_station("kiosk", "kiosk", "", Vector2(1900, 880), 95, "Egg Kiosk", -210)
	_add_station("grove", "timed", "berries", Vector2(880, 640), 115, "Moonberry Grove", -150)
	_add_station("windmill", "timed", "windmill", Vector2(2300, 600), 100, "Cloudmill", -290)
	_add_station("tidepool", "timed", "tidepool", Vector2(760, 1420), 125, "Tidepool", -130)
	_add_station("post", "post", "starmail", Vector2(1450, 640), 85, "Star Post", -200)
	var mailboxes := [Vector2(980, 1060), Vector2(2050, 1300), Vector2(1250, 1620), Vector2(2620, 980)]
	for i in mailboxes.size():
		_add_station("mail%d" % i, "mailbox", "starmail", mailboxes[i], 60, "", 0, i)
	var lanterns := [Vector2(2200, 1480), Vector2(2420, 1580), Vector2(2560, 1320)]
	for i in lanterns.size():
		_add_station("lantern%d" % i, "lantern", "lanterns", lanterns[i], 62, "Lantern Ridge" if i == 1 else "", 90 if i == 1 else 0, i)

	var hub := CENTER
	for id in ["kiosk", "grove", "windmill", "tidepool", "post"]:
		paths.append([hub, station_by_id(id)["pos"]])
	paths.append([hub, Vector2(2380, 1450)])
	paths.append([station_by_id("post")["pos"], station_by_id("grove")["pos"]])
	paths.append([station_by_id("post")["pos"], station_by_id("windmill")["pos"]])
	# each mailbox gets a short path to the closest main path
	for mb: Vector2 in mailboxes:
		var best := Vector2.ZERO
		var best_d := INF
		for seg in paths.duplicate():
			var q := Geometry2D.get_closest_point_to_segment(mb, seg[0], seg[1])
			if mb.distance_to(q) < best_d:
				best_d = mb.distance_to(q)
				best = q
		paths.append([best, mb])


func station_by_id(id: String) -> Dictionary:
	for st in stations:
		if st["id"] == id:
			return st
	return {}


func mailbox_pos(index: int) -> Vector2:
	return station_by_id("mail%d" % index)["pos"]


## Used for decoration placement: is `p` too close to a station or path?
func is_blocked(p: Vector2, margin: float) -> bool:
	for st in stations:
		if p.distance_to(st["pos"]) < float(st["radius"]) + margin + 30.0:
			return true
	for seg in paths:
		var q := Geometry2D.get_closest_point_to_segment(p, seg[0], seg[1])
		if p.distance_to(q) < 30.0 + margin:
			return true
	return false


func _spawn_prop(kind: String, pos: Vector2, station: int = -1, variant: float = 0.5) -> void:
	var pr = PropScript.new()
	pr.kind = kind
	pr.main = self
	pr.station = station
	pr.variant = variant
	pr.position = pos
	ysort.add_child(pr)


func _spawn_props() -> void:
	for i in stations.size():
		var st: Dictionary = stations[i]
		var p: Vector2 = st["pos"]
		match str(st["id"]):
			"kiosk": _spawn_prop("kiosk", p + Vector2(0, -55), i)
			"windmill": _spawn_prop("mill", p + Vector2(0, -70), i)
			"post": _spawn_prop("post", p + Vector2(0, -45), i)
			"grove":
				for k in 6:
					var a := TAU * k / 6.0 + 0.3
					_spawn_prop("berry_bush", p + Vector2(cos(a) * 128, sin(a) * 92), i, 0.3 + 0.12 * k)
			"tidepool":
				for k in 7:
					var a2 := TAU * k / 7.0
					_spawn_prop("pool_rock", p + Vector2(cos(a2) * 160, sin(a2) * 100), -1, fmod(k * 0.37, 1.0))
		match str(st["kind"]):
			"mailbox": _spawn_prop("mailbox", p + Vector2(0, -24), i)
			"lantern": _spawn_prop("lantern", p + Vector2(0, -18), i)

	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var placed := 0
	var tries := 0
	while placed < 60 and tries < 4000:
		tries += 1
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.9
		var p := CENTER + Vector2(cos(a) * RADII.x, sin(a) * RADII.y) * r
		if is_blocked(p, 40.0) or p.distance_to(player.position) < 120.0:
			continue
		var roll := rng.randf()
		var kind := "tree"
		if roll > 0.82:
			kind = "rock"
		elif roll > 0.62:
			kind = "bush"
		elif roll > 0.45:
			kind = "pine"
		_spawn_prop(kind, p, -1, rng.randf())
		placed += 1


# ================================================================ per-frame

func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	var modal: bool = hud.is_modal_open()
	if not modal:
		dir.x = Input.get_axis("ui_left", "ui_right")
		dir.y = Input.get_axis("ui_up", "ui_down")
		if Input.is_physical_key_pressed(KEY_A): dir.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D): dir.x += 1.0
		if Input.is_physical_key_pressed(KEY_W): dir.y -= 1.0
		if Input.is_physical_key_pressed(KEY_S): dir.y += 1.0
		dir += hud.joystick.value
		dir += auto_dir
	dir = dir.limit_length(1.0)

	player.position += dir * SPEED * delta
	var local := (player.position - CENTER) / RADII
	if local.length() > WALK_LIMIT:
		player.position = CENTER + local.normalized() * WALK_LIMIT * RADII
	player.moving = dir.length() > 0.1
	if absf(dir.x) > 0.1:
		player.facing = signf(dir.x)
	cam.position = player.position

	# companion follows a little behind
	var target := player.position + Vector2(-player.facing * 62.0, 6.0)
	var before := pet.position
	pet.position = pet.position.lerp(target, 1.0 - exp(-delta * 6.0))
	var moved := pet.position - before
	pet.moving = moved.length() > 40.0 * delta
	if absf(moved.x) > 0.5:
		pet.facing = signf(moved.x)
	elif not pet.moving:
		pet.facing = player.facing

	var e := Game.get_carried_egg()
	player.egg_type = "" if e.is_empty() else str(e["type"])
	player.egg_warm = Game.egg_ratio(e)
	var cp := Game.get_companion()
	pet.wish = "" if cp.is_empty() else str(cp["wish"])

	if lantern_reset > 0.0:
		lantern_reset -= delta
		if lantern_reset <= 0.0:
			lantern_lit = [false, false, false]
	cooldown = maxf(0.0, cooldown - delta)
	if modal:
		hud.hide_action()
		return
	_update_station(delta)


func _station_valid(st: Dictionary) -> bool:
	match str(st["kind"]):
		"mailbox":
			return int(st["index"]) == mail_target
		"lantern":
			return not bool(lantern_lit[int(st["index"])])
		"post":
			return mail_target == -1
	return true


func _update_station(delta: float) -> void:
	var found := -1
	var best := INF
	for i in stations.size():
		var st: Dictionary = stations[i]
		if not _station_valid(st):
			continue
		var d := player.position.distance_to(st["pos"])
		if d < float(st["radius"]) and d < best:
			best = d
			found = i
	if found != active:
		active = found
		progress = 0.0
	if active == -1:
		hud.hide_action()
		return
	var cur: Dictionary = stations[active]
	if str(cur["kind"]) == "kiosk":
		hud.show_action("Open Egg Kiosk", hud.open_shop)
		return
	hud.hide_action()
	if cooldown > 0.0:
		return
	progress += delta * Game.job_speed(str(cur["job"]))
	if progress >= station_time(cur):
		progress = 0.0
		cooldown = 0.5
		_complete(cur)


func station_time(st: Dictionary) -> float:
	match str(st["kind"]):
		"post":
			return 1.5
		"mailbox":
			return 0.8
		"lantern":
			return 1.0
	if str(st["job"]) == "":
		return 1.0
	return float(Data.JOBS[str(st["job"])]["time"])


func station_verb(st: Dictionary) -> String:
	match str(st["kind"]):
		"post":
			return "Grabbing starmail..."
		"mailbox":
			return "Delivering..."
		"lantern":
			return "Lighting lantern..."
	match str(st["job"]):
		"nap": return "Napping... zzz"
		"berries": return "Picking moonberries..."
		"windmill": return "Winding the mill..."
		"tidepool": return "Tidying the pool..."
	return ""


## Which job a station counts as for the companion's wish (the whole errand counts).
func station_job_for_wish(st: Dictionary) -> String:
	return str(st["job"])


func _complete(st: Dictionary) -> void:
	var p: Vector2 = st["pos"]
	match str(st["kind"]):
		"timed":
			_reward(str(st["job"]), p)
		"post":
			mail_target = randi() % 4
			overlay.float_text("Starmail!", p + Vector2(0, -120), Color("#ffd23f"))
			hud.toast("Deliver the starmail to the glowing mailbox — follow the arrow!")
		"mailbox":
			mail_target = -1
			_reward("starmail", p)
		"lantern":
			lantern_lit[int(st["index"])] = true
			var lit := 0
			for l in lantern_lit:
				if l:
					lit += 1
			if lit >= 3:
				lantern_reset = 4.0
				_reward("lanterns", p)
			else:
				overlay.float_text("Lantern lit  %d / 3" % lit, p + Vector2(0, -170), Color("#ffd966"))


func _reward(job_id: String, at: Vector2) -> void:
	var r := Game.complete_job(job_id)
	var y := at + Vector2(0, -110)
	overlay.float_text("+%d glimmer" % int(r["glimmer"]), y, Color("#9fe6ff"))
	var d := 0.25
	if int(r["xp"]) > 0:
		overlay.float_text("+%d xp" % int(r["xp"]), y + Vector2(0, -30), Color("#a6f0b4"), d)
		d += 0.25
	if int(r["warmth"]) > 0 and not bool(r["hatched"]):
		overlay.float_text("+%d warmth" % int(r["warmth"]), y + Vector2(0, -60), Color("#ffc27a"), d)
		d += 0.25
	if bool(r["wish"]):
		overlay.float_text("Wish granted!", y + Vector2(0, -90), Color("#ffb3cf"), d)


func _refresh_pet() -> void:
	var p := Game.get_companion()
	if p.is_empty():
		pet.species = ""
		pet.visible = false
		return
	if not pet.visible:
		pet.position = player.position + Vector2(-60, 0)
	pet.visible = true
	pet.species = str(p["species"])
	pet.level = int(p["level"])
	pet.prism = bool(p["prism"])
