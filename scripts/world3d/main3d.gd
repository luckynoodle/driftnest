extends "res://scripts/main.gd"
## The 3D town. All game logic (moving the Keeper, actions, placement, pets walking to work)
## is inherited from the 2D main script and runs on the same 2D world coordinates; this script
## swaps in a 3D view: terrain, models, a camera you can turn, and 3D tap picking.

const PITCH := deg_to_rad(52.0)
const FOV := 32.0
const ZOOM_DIST := 13.5
const ROT_SPEED := 2.0 # radians per second with Q/E
const SUN_ENERGY := 0.82
const SHADOW_SUN_K := 0.4

var world: Node3D
var terrain3d: Terrain3D
var cam3d: Camera3D
var sun: DirectionalLight3D
var env: Environment
var k3d: Actors3D.Keeper3D
var b3d: Dictionary = {} # same dict as building_nodes
var p3d: Dictionary = {} # pid -> Pet3D
var overlay3d: Overlay3D
var daynight: DayNight
var shadow_sun_k := SHADOW_SUN_K

var yaw := 0.0
var cam_target := Vector3(40.5, 0, 43.5)
var _pinch_angle := 0.0
var _pinch_yaw := 0.0

var ghost3d: MeshInstance3D
var ghost_foot: MeshInstance3D
var ghost_mat: StandardMaterial3D
var grid_mesh: MeshInstance3D
var border_mmi: MultiMeshInstance3D
var _border_key := ""


# ================================================================ building the view

func _build_world() -> void:
	RenderingServer.set_default_clear_color(Color("#bfe3f2"))
	# the logic layer (Keeper and pet walkers) still exists, it just isn't drawn
	ysort = Node2D.new()
	ysort.visible = false
	add_child(ysort)

	world = Node3D.new()
	world.name = "World3D"
	add_child(world)

	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#bfe3f2")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c9dcff")
	env.ambient_light_energy = 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("#cfe3ea")
	env.fog_density = 0.0045
	we.environment = env
	world.add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_color = Color("#fff0d4")
	sun.light_energy = 0.82
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 42.0
	world.add_child(sun)

	terrain3d = Terrain3D.new()
	terrain3d.map = Game.map
	world.add_child(terrain3d)

	daynight = DayNight.new()
	daynight.main = self
	world.add_child(daynight)


func _build_view_extras() -> void:
	cam3d = Camera3D.new()
	cam3d.fov = FOV
	cam3d.far = 160.0
	world.add_child(cam3d)
	cam3d.make_current()

	k3d = Actors3D.Keeper3D.new()
	k3d.keeper = keeper
	k3d.main_ref = self
	world.add_child(k3d)

	_build_placement_view()

	var ol := CanvasLayer.new()
	ol.layer = 3
	overlay3d = Overlay3D.new()
	overlay3d.main = self
	ol.add_child(overlay3d)
	add_child(ol)

	b3d = building_nodes
	cam_target = Terrain3D.to3(keeper.position)
	_apply_zoom()


func _apply_settings() -> void:
	# real depth replaces the 2D tilt-shift finish; effects = shadows + smooth edges
	var fx := bool(Game.settings.get("effects", true))
	sun.shadow_enabled = fx
	# the Compatibility renderer adds a shadowed sun in an extra pass, which brightens it;
	# halve it then so the town looks the same with effects on or off
	sun.light_energy = SUN_ENERGY * (SHADOW_SUN_K if fx else 1.0)
	get_viewport().msaa_3d = Viewport.MSAA_2X if fx else Viewport.MSAA_DISABLED


# ================================================================ syncing

func _view_building(b: Dictionary) -> void:
	var bid := int(b["id"])
	var node: Actors3D.Building3D = building_nodes.get(bid)
	if node == null:
		node = Actors3D.Building3D.new()
		node.setup(b)
		world.add_child(node)
		building_nodes[bid] = node
	node.refresh(b)


func _view_pet_added(pid: int, actor: PetActor) -> void:
	var p := Actors3D.Pet3D.new()
	p.actor = actor
	world.add_child(p)
	p3d[pid] = p


func _view_pet_removed(pid: int) -> void:
	if p3d.has(pid):
		p3d[pid].queue_free()
		p3d.erase(pid)


func _on_node_changed(cell: Vector2i) -> void:
	terrain3d.refresh_node(cell)


func refresh_props() -> void:
	terrain3d.refresh_all()


## 2D callers pass a point a little above the thing (in 2D "up" is north); put the text over it.
func float_text(text: String, pos: Vector2, col: Color) -> void:
	overlay3d.float_text(text, Terrain3D.to3(pos + Vector2(0, 80), 1.7), col)


# ================================================================ camera

func _apply_zoom() -> void:
	zoom_level = clampf(zoom_level, 0.4, 1.4)
	_place_camera()


func _place_camera() -> void:
	if cam3d == null:
		return
	var dist := ZOOM_DIST / zoom_level
	var flat := Vector3(sin(yaw), 0.0, cos(yaw)) * dist * cos(PITCH)
	cam3d.position = cam_target + flat + Vector3(0, dist * sin(PITCH), 0)
	cam3d.look_at(cam_target + Vector3(0, 0.5, 0), Vector3.UP)


func snap_camera() -> void:
	cam_target = Terrain3D.to3(keeper.position)
	_place_camera()


func _follow_camera(delta: float) -> void:
	if not cam_free:
		var want := Terrain3D.to3(keeper.position)
		cam_target = cam_target.lerp(want, 1.0 - exp(-delta * 8.0))
	if Input.is_physical_key_pressed(KEY_Q):
		rotate_view(-ROT_SPEED * delta)
	if Input.is_physical_key_pressed(KEY_E):
		rotate_view(ROT_SPEED * delta)
	_place_camera()


## Turn the camera around the Keeper (radians; positive = clockwise from above).
func rotate_view(amount: float) -> void:
	yaw = wrapf(yaw + amount, -PI, PI)
	_place_camera()


## Turn by a quarter, for the on-screen buttons.
func turn_view(dir: int) -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float): yaw = v; _place_camera(), yaw, yaw + dir * PI / 4.0, 0.25).set_trans(Tween.TRANS_SINE)


func pan_camera_screen(rel: Vector2) -> void:
	cam_free = true
	var dist := ZOOM_DIST / zoom_level
	var per_px := 2.0 * dist * tan(deg_to_rad(FOV) / 2.0) / maxf(1.0, get_viewport().get_visible_rect().size.y)
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	cam_target -= right * rel.x * per_px
	cam_target += fwd * rel.y * per_px / sin(PITCH)
	cam_target.x = clampf(cam_target.x, 0.0, WorldMap.SIZE)
	cam_target.z = clampf(cam_target.z, 0.0, WorldMap.SIZE)
	cam_target.y = Terrain3D.height(cam_target.x, cam_target.z)
	_place_camera()


## The joystick is in screen directions; turn it to match the camera.
func _screen_dir_to_world(dir: Vector2) -> Vector2:
	return dir.rotated(-yaw)


## Where a screen point lands on the ground, in 2D world coordinates.
func screen_to_world(p: Vector2) -> Vector2:
	var o := cam3d.project_ray_origin(p)
	var d := cam3d.project_ray_normal(p)
	if absf(d.y) < 0.0001:
		return Vector2(o.x, o.z) * T
	var t := (0.0 - o.y) / d.y
	var hit := o + d * t
	return Vector2(hit.x, hit.z) * T


# ================================================================ input

func _unhandled_input(event: InputEvent) -> void:
	if hud.is_modal_open():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(1.0 / 1.1)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
		rotate_view(event.relative.x * 0.008)
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
				_pinch_angle = ((v[1] as Vector2) - (v[0] as Vector2)).angle()
				_pinch_yaw = yaw
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
					_tap_screen(event.position)
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 2 and _pinch_start > 0.0:
			var v2: Array = _touches.values()
			zoom_level = _pinch_zoom * (v2[0] as Vector2).distance_to(v2[1]) / _pinch_start
			var ang := ((v2[1] as Vector2) - (v2[0] as Vector2)).angle()
			yaw = wrapf(_pinch_yaw - angle_difference(_pinch_angle, ang), -PI, PI)
			_apply_zoom()
		elif _touches.size() == 1:
			var start2: Vector2 = _tap_start.get(event.index, event.position)
			if _panning or start2.distance_to(event.position) >= PAN_THRESHOLD:
				_panning = true
				pan_camera_screen(event.relative)


## A tap: move the building being placed, or open whichever pet / building is under the finger.
func _tap_screen(sp: Vector2) -> void:
	if placing != "":
		tap_world(screen_to_world(sp))
		return
	var best := -1
	var best_d := 56.0
	for pid in p3d:
		var node: Node3D = p3d[pid]
		var head := node.global_position + Vector3(0, 0.45 * node.scale.y, 0)
		if cam3d.is_position_behind(head):
			continue
		var d := cam3d.unproject_position(head).distance_to(sp)
		if d < best_d:
			best_d = d
			best = pid
	if best != -1:
		hud.open_pet(best)
		return
	var hit_bid := -1
	var hit_depth := INF
	for bid in building_nodes:
		var node: Actors3D.Building3D = building_nodes[bid]
		var aabb: AABB = node.global_transform * node.model.get_aabb()
		if not node.model.mesh or aabb.size == Vector3.ZERO:
			continue
		var rect := Rect2()
		var first := true
		for i in 8:
			var c := aabb.get_endpoint(i)
			if cam3d.is_position_behind(c):
				continue
			var s := cam3d.unproject_position(c)
			if first:
				rect = Rect2(s, Vector2.ZERO)
				first = false
			else:
				rect = rect.expand(s)
		if not first and rect.grow(6).has_point(sp):
			var depth := cam3d.global_position.distance_to(aabb.get_center())
			if depth < hit_depth:
				hit_depth = depth
				hit_bid = int(bid)
	if hit_bid != -1:
		hud.open_building(hit_bid)


# ================================================================ placement

func _build_placement_view() -> void:
	ghost_mat = StandardMaterial3D.new()
	ghost_mat.vertex_color_use_as_albedo = true
	ghost_mat.vertex_color_is_srgb = true
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.albedo_color = Color(0.7, 1.0, 0.7, 0.6)
	ghost3d = MeshInstance3D.new()
	ghost3d.material_override = ghost_mat
	ghost3d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost3d.visible = false
	world.add_child(ghost3d)
	ghost_foot = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE
	ghost_foot.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_foot.material_override = fm
	ghost_foot.visible = false
	world.add_child(ghost_foot)
	grid_mesh = MeshInstance3D.new()
	grid_mesh.mesh = ImmediateMesh.new()
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(1, 1, 1, 0.35)
	grid_mesh.material_override = gm
	grid_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(grid_mesh)
	border_mmi = MultiMeshInstance3D.new()
	border_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(border_mmi)


func _ghost_show(type: String) -> void:
	ghost3d.mesh = Models3D.building(type, 0)
	ghost3d.visible = true
	ghost_foot.visible = true


func _ghost_move(cell: Vector2i, ok: bool) -> void:
	var size: Vector2i = Data.BUILDINGS[placing]["size"]
	var c := Vector2(cell) + Vector2(size) / 2.0
	var h := Terrain3D.height(c.x, c.y)
	ghost3d.position = Vector3(c.x, h + 0.02, c.y)
	ghost_mat.albedo_color = Color(0.75, 1.0, 0.75, 0.62) if ok else Color(1.0, 0.55, 0.5, 0.55)
	ghost_foot.position = Vector3(c.x, h + 0.07, c.y)
	ghost_foot.scale = Vector3(size.x, 1, size.y)
	(ghost_foot.material_override as StandardMaterial3D).albedo_color = Color(0.5, 1.0, 0.5, 0.35) if ok else Color(1.0, 0.35, 0.3, 0.4)
	_draw_grid(cell)


func _ghost_hide() -> void:
	if ghost3d:
		ghost3d.visible = false
		ghost_foot.visible = false
		(grid_mesh.mesh as ImmediateMesh).clear_surfaces()


func _draw_grid(g: Vector2i) -> void:
	var im: ImmediateMesh = grid_mesh.mesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var r := Game.town_radius()
	for y in range(g.y - 8, g.y + 10):
		for x in range(g.x - 8, g.x + 10):
			var c := Vector2i(x, y)
			if (Vector2(c) + Vector2(0.5, 0.5)).distance_to(WorldMap.CENTER) > r:
				continue
			var a := Vector3(x, 0.06, y)
			var b := Vector3(x + 1, 0.06, y)
			var d := Vector3(x, 0.06, y + 1)
			im.surface_add_vertex(a); im.surface_add_vertex(b)
			im.surface_add_vertex(a); im.surface_add_vertex(d)
	im.surface_end()


func _update_border() -> void:
	var strong := placing != ""
	var r := Game.town_radius()
	var key := "%.2f_%s" % [r, strong]
	if key == _border_key:
		return
	_border_key = key
	var n := int(TAU * r / 0.72)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var dot := MeshKit.new()
	dot.ellipse(Vector3.ZERO, 1.0, 1.0, 0.4, Color.WHITE, 12)
	mm.mesh = dot.commit()
	mm.instance_count = n
	var s := 0.13 if strong else 0.085
	for i in n:
		var a := TAU * i / n
		var p := WorldMap.CENTER + Vector2(cos(a), sin(a)) * r
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s, s)), Vector3(p.x, Terrain3D.height(p.x, p.y) + 0.07, p.y)))
		mm.set_instance_color(i, Color("#fff3c4") if strong else Color(1.0, 0.97, 0.85))
	border_mmi.multimesh = mm


func _process(delta: float) -> void:
	super(delta)
	_update_border()
