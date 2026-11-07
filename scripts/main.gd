extends Node2D
## Builds the open-world town scene, moves the Keeper, handles taps, building placement
## and the Keeper's hands-on actions. Game state and the simulation live in the Game autoload.

const T := WorldMap.TILE
const SPEED := 330.0
const TerrainScript := preload("res://scripts/terrain.gd")

var keeper: Keeper
var ysort: Node2D
var overlay: WorldOverlay
var hud: GameHud
var cam: Camera2D

var building_nodes: Dictionary = {} # bid -> BuildingView
var pet_nodes: Dictionary = {} # pid -> PetActor
var occupied: Dictionary = {} # Vector2i -> bid (solid buildings only)
var props: Dictionary = {} # Vector2i -> NatureProp

var placing := ""
var ghost: BuildingView
var ghost_cell := Vector2i.ZERO
var ghost_reason := ""

var action: Dictionary = {}
var action_hold := false
var action_cd := 0.0
var action_cd_max := 0.45

var zoom_level := 0.85
var ambient: Ambient
var post_layer: CanvasLayer
var _touches: Dictionary = {}
var _pinch_start := 0.0
var _pinch_zoom := 1.0
var _tap_start: Dictionary = {}
var _panning := false

## Tap-to-walk target (INF = none) and whether the camera has been dragged away from the Keeper.
var cam_free := false
const PAN_THRESHOLD := 24.0

# test hook: scripted input used by the automated smoke test
var auto_dir := Vector2.ZERO


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#6aa84f"))

	var terrain: Node2D = TerrainScript.new()
	terrain.map = Game.map
	add_child(terrain)

	ysort = Node2D.new()
	ysort.y_sort_enabled = true
	add_child(ysort)

	for cell in Game.map.nodes:
		var pr := NatureProp.new()
		pr.kind = Game.map.nodes[cell]
		pr.variant = WorldMap.hash01(cell, 1)
		pr.stage = Game.node_stage(cell)
		pr.position = WorldMap.cell_center(cell) + Vector2((WorldMap.hash01(cell, 2) - 0.5) * 16.0, T * 0.35)
		ysort.add_child(pr)
		props[cell] = pr
	Game.node_changed.connect(_on_node_changed)

	keeper = Keeper.new()
	keeper.scale = Vector2(0.8, 0.8)
	keeper.position = WorldMap.cell_center(Vector2i(40, 43))
	ysort.add_child(keeper)

	overlay = WorldOverlay.new()
	overlay.main = self
	overlay.z_index = 50
	add_child(overlay)

	cam = Camera2D.new()
	cam.position = keeper.position
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(WorldMap.SIZE * T)
	cam.limit_bottom = int(WorldMap.SIZE * T)
	add_child(cam)
	cam.make_current()
	_apply_zoom()

	ambient = Ambient.new()
	ambient.cam = cam
	add_child(ambient)

	# storybook miniature finish (tilt-shift, sun wash, vignette, grain); HUD sits above it
	post_layer = CanvasLayer.new()
	post_layer.layer = 2
	var post := ColorRect.new()
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pm := ShaderMaterial.new()
	pm.shader = load("res://shaders/post.gdshader")
	post.material = pm
	post_layer.add_child(post)
	add_child(post_layer)

	hud = GameHud.new()
	hud.main = self
	add_child(hud)

	Game.changed.connect(_sync)
	Game.settings_changed.connect(_apply_settings)
	_apply_settings()
	Game.building_done.connect(func(_b): _sync())
	Game.produced.connect(_on_produced)
	_sync()

	if "--balance" in OS.get_cmdline_user_args():
		var bal = load("res://tests/balance.gd").new()
		bal.main = self
		add_child(bal)
	if "--showcase" in OS.get_cmdline_user_args():
		var show = load("res://tests/showcase.gd").new()
		show.main = self
		add_child(show)
	if "--smoke" in OS.get_cmdline_user_args():
		var smoke = load("res://tests/smoke.gd").new()
		smoke.main = self
		add_child(smoke)


# ================================================================ syncing nodes with state

func _sync() -> void:
	var seen := {}
	occupied.clear()
	for b in Game.buildings:
		var bid := int(b["id"])
		seen[bid] = true
		var node: BuildingView = building_nodes.get(bid)
		if node == null:
			node = BuildingView.new()
			node.setup(b["type"], bid)
			ysort.add_child(node)
			building_nodes[bid] = node
		var size: Vector2i = Data.BUILDINGS[b["type"]]["size"]
		node.position = WorldMap.cell_to_world(b["cell"]) + Vector2(size.x * T / 2.0, size.y * T)
		if not bool(Data.BUILDINGS[b["type"]].get("deco", false)) or size.x > 1 or b["type"] == "lamp":
			for y in size.y:
				for x in size.x:
					occupied[b["cell"] + Vector2i(x, y)] = bid
	for bid in building_nodes.keys():
		if not seen.has(bid):
			building_nodes[bid].queue_free()
			building_nodes.erase(bid)

	var pseen := {}
	for p in Game.pets:
		var pid := int(p["id"])
		pseen[pid] = true
		if not pet_nodes.has(pid):
			var a := PetActor.new()
			a.pid = pid
			a.position = keeper.position
			if _nest_id() != -1:
				a.position = WorldMap.cell_to_world(Game.find_building(_nest_id())["cell"]) + Vector2(64, 150)
			ysort.add_child(a)
			pet_nodes[pid] = a
	for pid in pet_nodes.keys():
		if not pseen.has(pid):
			pet_nodes[pid].queue_free()
			pet_nodes.erase(pid)


func _on_node_changed(cell: Vector2i) -> void:
	var pr: NatureProp = props.get(cell)
	if pr and pr.stage != Game.node_stage(cell):
		pr.stage = Game.node_stage(cell)
		pr.queue_redraw()


## After a reset or load, bring every prop in line with the saved state.
func refresh_props() -> void:
	for cell in props:
		_on_node_changed(cell)


func _apply_settings() -> void:
	post_layer.visible = bool(Game.settings.get("effects", true))
	ambient.visible = bool(Game.settings.get("ambient", true))
	ambient.set_process(ambient.visible)


## Back to the start after a reset: Keeper at the plaza, camera on them.
func reset_view() -> void:
	cam_free = false
	keeper.position = WorldMap.cell_center(Vector2i(40, 43))
	_sync()
	refresh_props()
	snap_camera()


func _nest_id() -> int:
	var n := Game.buildings_of("nest")
	return -1 if n.is_empty() else int(n[0]["id"])


func _on_produced(pid: int, _bid: int, r: String, amount: int) -> void:
	var node: Node2D = pet_nodes.get(pid)
	if node == null:
		return
	overlay.float_text("+%d %s" % [amount, Data.RESOURCES[r]["name"].to_lower()], node.position + Vector2(0, -50),
		Color(Data.RESOURCES[r]["color"]).lightened(0.35))


# ================================================================ camera & input

func _apply_zoom() -> void:
	zoom_level = clampf(zoom_level, 0.4, 1.4)
	cam.zoom = Vector2(zoom_level, zoom_level)


func snap_camera() -> void:
	cam.position = keeper.position
	cam.reset_smoothing()


func zoom_by(f: float) -> void:
	zoom_level *= f
	_apply_zoom()


func screen_to_world(p: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * p


func _unhandled_input(event: InputEvent) -> void:
	if hud.is_modal_open():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(1.0 / 1.1)
	elif event is InputEventMagnifyGesture:
		zoom_by(event.factor)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			_tap_start[event.index] = event.position
			if _touches.size() == 2:
				var v: Array = _touches.values()
				_pinch_start = (v[0] as Vector2).distance_to(v[1])
				_pinch_zoom = zoom_level
				_panning = false
		else:
			var start: Vector2 = _tap_start.get(event.index, event.position)
			var was_pinch := _touches.size() >= 2
			_touches.erase(event.index)
			_tap_start.erase(event.index)
			if _touches.is_empty():
				var was_pan := _panning
				_panning = false
				if not was_pinch and not was_pan and start.distance_to(event.position) < PAN_THRESHOLD:
					tap_world(screen_to_world(event.position))
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 2 and _pinch_start > 0.0:
			var v2: Array = _touches.values()
			zoom_level = _pinch_zoom * (v2[0] as Vector2).distance_to(v2[1]) / _pinch_start
			_apply_zoom()
		elif _touches.size() == 1:
			# one finger dragging on the ground pans the camera
			var start2: Vector2 = _tap_start.get(event.index, event.position)
			if _panning or start2.distance_to(event.position) >= PAN_THRESHOLD:
				_panning = true
				pan_camera(-event.relative / zoom_level)


## Move the camera without moving the Keeper (drag to look around).
func pan_camera(world_delta: Vector2) -> void:
	if not cam_free:
		cam_free = true
		cam.position = keeper.position
	var full := WorldMap.SIZE * T
	cam.position = (cam.position + world_delta).clamp(Vector2.ZERO, Vector2(full, full))


func tap_world(p: Vector2) -> void:
	if placing != "":
		var size: Vector2i = Data.BUILDINGS[placing]["size"]
		ghost_cell = WorldMap.world_to_cell(p) - Vector2i(size.x / 2, size.y / 2)
		if size.x > 1:
			ghost_cell = WorldMap.world_to_cell(p + Vector2(T / 2.0, T / 2.0)) - Vector2i(size.x / 2, size.y / 2)
		_update_ghost()
		return
	# pets first (they stand in front of buildings)
	var best := -1
	var best_d := 40.0
	for pid in pet_nodes:
		var d: float = (pet_nodes[pid].position + Vector2(0, -20)).distance_to(p)
		if d < best_d:
			best_d = d
			best = pid
	if best != -1:
		hud.open_pet(best)
		return
	for b in Game.buildings:
		var size2: Vector2i = Data.BUILDINGS[b["type"]]["size"]
		var r := Rect2(WorldMap.cell_to_world(b["cell"]) - Vector2(0, 60), Vector2(size2) * T + Vector2(0, 60))
		if r.has_point(p):
			hud.open_building(int(b["id"]))
			return
	# tapping open ground does nothing: the Keeper moves with the joystick


# ================================================================ placement

func start_placing(type: String) -> void:
	placing = type
	if ghost == null:
		ghost = BuildingView.new()
		ghost.ghost = true
		ghost.z_index = 40
		add_child(ghost)
	ghost.setup(type, -1)
	ghost.z_index = 40
	ghost.visible = true
	var size: Vector2i = Data.BUILDINGS[type]["size"]
	var kc := WorldMap.world_to_cell(keeper.position)
	ghost_cell = kc + Vector2i(1, -size.y)
	_update_ghost()


func _update_ghost() -> void:
	if ghost == null or placing == "":
		return
	var size: Vector2i = Data.BUILDINGS[placing]["size"]
	ghost.position = WorldMap.cell_to_world(ghost_cell) + Vector2(size.x * T / 2.0, size.y * T)
	ghost_reason = Game.can_place(placing, ghost_cell)
	ghost.ghost_ok = ghost_reason == ""
	hud.update_placement(placing, ghost_reason)


func move_ghost(d: Vector2i) -> void:
	ghost_cell += d
	_update_ghost()


func confirm_place() -> void:
	if placing == "":
		return
	var b := Game.place_building(placing, ghost_cell)
	if b.is_empty():
		_update_ghost()
		return
	_sync()
	unstick_keeper()
	if bool(Data.BUILDINGS[placing].get("deco", false)) and Game.can_afford(Game.build_cost(placing)):
		# keep placing decorations; nudge the ghost along
		ghost_cell += Vector2i(Data.BUILDINGS[placing]["size"].x, 0)
		_update_ghost()
	else:
		cancel_place()


func cancel_place() -> void:
	placing = ""
	if ghost:
		ghost.visible = false
	hud.update_placement("", "")


# ================================================================ per-frame

## If the Keeper is standing inside something solid (a building just placed on top of them),
## step them out to the nearest free spot.
func unstick_keeper() -> void:
	if not _blocked(keeper.position):
		return
	var kc := WorldMap.world_to_cell(keeper.position)
	var best := Vector2.INF
	for r in range(1, 8):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var p := WorldMap.cell_center(kc + Vector2i(dx, dy))
				if not _blocked(p) and p.distance_to(keeper.position) < best.distance_to(keeper.position):
					best = p
		if best != Vector2.INF:
			keeper.position = best
			if not cam_free:
				cam.position = keeper.position
			return


func _blocked(p: Vector2) -> bool:
	var c := WorldMap.world_to_cell(p)
	if not WorldMap.in_bounds(c) or c.x < 1 or c.y < 1 or c.x >= WorldMap.SIZE - 1 or c.y >= WorldMap.SIZE - 1:
		return true
	return Game.map.water.has(c) or occupied.has(c)


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
	if dir.length() > 0.1:
		cam_free = false # moving brings the camera back to the Keeper
	dir = dir.limit_length(1.0)
	var mv := dir * SPEED * delta
	var before := keeper.position
	# never trap the Keeper: if they're already inside something solid, let them walk out
	var inside := _blocked(keeper.position)
	if inside or not _blocked(keeper.position + Vector2(mv.x, 0)):
		keeper.position.x += mv.x
	if inside or not _blocked(keeper.position + Vector2(0, mv.y)):
		keeper.position.y += mv.y
	var full := WorldMap.SIZE * T
	keeper.position = keeper.position.clamp(Vector2(T, T), Vector2(full - T, full - T))
	keeper.moving = keeper.position.distance_to(before) > 0.01
	if absf(dir.x) > 0.1:
		keeper.facing = signf(dir.x)
	if not cam_free:
		cam.position = keeper.position

	var e := Game.carried_egg()
	keeper.egg_type = "" if e.is_empty() else str(e["type"])
	keeper.egg_warm = Game.egg_ratio(e)

	if modal:
		hud.hide_action()
		action_hold = false
		return
	_update_action(delta)


func _update_action(delta: float) -> void:
	action = _find_action()
	if action.is_empty():
		hud.hide_action()
		action_hold = false
		return
	hud.show_action(str(action["label"]))
	action_cd = maxf(0.0, action_cd - delta)
	if action_hold and action_cd <= 0.0 and str(action["kind"]) != "open":
		do_action()


func _find_action() -> Dictionary:
	var kc := WorldMap.world_to_cell(keeper.position)
	for b in Game.buildings:
		var size: Vector2i = Data.BUILDINGS[b["type"]]["size"]
		var r := Rect2i(b["cell"] - Vector2i(1, 1), size + Vector2i(2, 2))
		if r.has_point(kc):
			if not bool(b["built"]):
				return {"kind": "build", "bid": b["id"], "label": "Help build"}
	for b in Game.buildings:
		var size2: Vector2i = Data.BUILDINGS[b["type"]]["size"]
		if bool(Data.BUILDINGS[b["type"]].get("deco", false)):
			continue
		var r2 := Rect2i(b["cell"] - Vector2i(1, 1), size2 + Vector2i(2, 2))
		if r2.has_point(kc):
			return {"kind": "open", "bid": b["id"], "label": "Open " + Data.BUILDINGS[b["type"]]["name"]}
	var best := {}
	var best_d := 92.0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c := kc + Vector2i(dx, dy)
			var kind := Game.node_kind(c)
			if kind == "" or Game.node_left(c) <= 0:
				continue
			var d := keeper.position.distance_to(WorldMap.cell_center(c) + Vector2(0, T * 0.35))
			if kind == "water":
				d = keeper.position.distance_to(WorldMap.cell_center(c)) - 20.0
			if d < best_d:
				best_d = d
				best = {"kind": "gather", "node": kind, "cell": c,
					"label": "%s (%d left)" % [Data.NODES[kind]["verb"], Game.node_left(c)]}
	return best


func action_down() -> void:
	action_hold = true
	if not action.is_empty() and (action_cd <= 0.0 or str(action["kind"]) == "open"):
		do_action()


func action_up() -> void:
	action_hold = false


func do_action() -> void:
	if action.is_empty():
		return
	match str(action["kind"]):
		"open":
			action_hold = false
			hud.open_building(int(action["bid"]))
		"build":
			action_cd_max = 0.35
			action_cd = action_cd_max
			var b := Game.find_building(int(action["bid"]))
			if not b.is_empty():
				Game.add_build_progress(b, 1.0)
				overlay.float_text("+1 build", keeper.position + Vector2(0, -110), Color("#ffc27a"))
				Game.changed.emit()
		"gather":
			var node: String = action["node"]
			action_cd_max = 1.5 if node == "crystal" else (1.0 if node == "water" else 0.5)
			action_cd = action_cd_max
			var r := Game.keeper_gather_at(action["cell"])
			if r == "full":
				action_hold = false
				var rn: String = Data.NODES[node]["res"]
				hud.toast("Your %s store is full! Build a Storehouse, or sell some at the Market." % Data.RESOURCES[rn]["name"].to_lower())
			elif r != "" and r != "empty":
				overlay.float_text("+1 %s" % Data.RESOURCES[r]["name"].to_lower(), keeper.position + Vector2(0, -110),
					Color(Data.RESOURCES[r]["color"]).lightened(0.35))
