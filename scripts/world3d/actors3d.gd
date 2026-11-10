class_name Actors3D
extends RefCounted
## The 3D stand-ins for buildings, pets and the Keeper. Positions and behaviour come from the
## game logic (the same code the 2D view uses); these only draw and animate.


## A building in the world. Shows a scaffold while it's being built.
class Building3D extends Node3D:
	var bid := -1
	var type := ""
	var model: MeshInstance3D
	var frame: MeshInstance3D
	var eggs: Array = [] # nest only
	var smoke: CPUParticles3D
	var t := 0.0
	var _built := true

	func setup(b: Dictionary) -> void:
		bid = int(b["id"])
		type = b["type"]
		var size: Vector2i = Data.BUILDINGS[type]["size"]
		model = MeshKit.instance(Models3D.building(type, bid % 5), self)
		frame = MeshKit.instance(Models3D.scaffold(size), self)
		if type == "lamp":
			var pool := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(3.4, 3.4)
			pool.mesh = pm
			pool.material_override = MeshKit.pool_material()
			pool.position = Vector3(0, 0.05, 0)
			pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(pool)
		if type in ["house", "workshop"]:
			smoke = CPUParticles3D.new()
			smoke.amount = 5
			smoke.lifetime = 3.0
			smoke.direction = Vector3(0.3, 1, 0)
			smoke.spread = 10.0
			smoke.initial_velocity_min = 0.25
			smoke.initial_velocity_max = 0.4
			smoke.gravity = Vector3(0.05, 0.02, 0)
			smoke.scale_amount_min = 0.07
			smoke.scale_amount_max = 0.11
			var curve := Curve.new()
			curve.add_point(Vector2(0, 0.6))
			curve.add_point(Vector2(1, 1.8))
			smoke.scale_amount_curve = curve
			var sm := SphereMesh.new()
			sm.radius = 1.0
			sm.height = 2.0
			sm.radial_segments = 8
			sm.rings = 4
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.96, 0.96, 0.98, 0.32)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			sm.material = mat
			smoke.mesh = sm
			smoke.position = Vector3(0.45 if type == "house" else -0.5, 2.4, -0.2)
			smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(smoke)
		if type == "fountain":
			# water spray arcing out of the top bowl (uses the smoke slot so it stops while building)
			smoke = CPUParticles3D.new()
			smoke.amount = 26
			smoke.lifetime = 0.9
			smoke.direction = Vector3.UP
			smoke.spread = 28.0
			smoke.initial_velocity_min = 1.3
			smoke.initial_velocity_max = 1.6
			smoke.gravity = Vector3(0, -4.2, 0)
			smoke.scale_amount_min = 0.035
			smoke.scale_amount_max = 0.055
			var dm := SphereMesh.new()
			dm.radius = 1.0
			dm.height = 2.0
			dm.radial_segments = 6
			dm.rings = 3
			var dmat := StandardMaterial3D.new()
			dmat.albedo_color = Color(0.82, 0.95, 1.0, 0.75)
			dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			dm.material = dmat
			smoke.mesh = dm
			smoke.position = Vector3(0, 1.38, 0)
			smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(smoke)

	func refresh(b: Dictionary) -> void:
		var size: Vector2i = Data.BUILDINGS[type]["size"]
		var c := Vector2(b["cell"]) + Vector2(size) / 2.0
		position = Vector3(c.x, Terrain3D.height(c.x, c.y), c.y)
		if type == "fishing_dock":
			position.y = maxf(position.y, -0.05)
		_built = bool(b["built"])
		frame.visible = not _built
		if smoke:
			smoke.emitting = _built
		if _built:
			model.scale = Vector3.ONE
		else:
			var work := maxf(1.0, float(Data.BUILDINGS[type]["work"]))
			var k := clampf(float(b["progress"]) / work, 0.0, 1.0)
			model.scale = Vector3(0.96, 0.08 + 0.92 * k, 0.96)

	func _process(delta: float) -> void:
		t += delta
		if type != "nest":
			return
		var nest := Game.eggs_at("nest")
		while eggs.size() < mini(nest.size(), 3):
			var mi := MeshInstance3D.new()
			add_child(mi)
			eggs.append(mi)
		for i in eggs.size():
			var mi: MeshInstance3D = eggs[i]
			if i >= nest.size():
				mi.visible = false
				continue
			var e: Dictionary = nest[i]
			mi.visible = true
			mi.mesh = Models3D.egg(str(e["type"]))
			var warm := Game.egg_ratio(e)
			var wob := sin(t * 18.0 + i) * 0.25 * clampf((warm - 0.6) / 0.4, 0.0, 1.0)
			mi.position = Vector3(-0.32 + 0.32 * i, 0.1, 0.05 * (i % 2))
			mi.rotation = Vector3(0, 0, wob)
			mi.scale = Vector3.ONE * 1.3


## A pet. Follows its logic actor (which decides where it walks) and animates: hops when
## walking, wags its tail, twitches its ears, blinks, sleeps when idle, droops when hungry
## and jumps for joy when it levels up.
class Pet3D extends Node3D:
	const SCALE := 1.15
	var actor: PetActor
	var root: Node3D
	var body: MeshInstance3D
	var lids: MeshInstance3D
	var ears: Node3D
	var tail: Node3D
	var wing_l: Node3D
	var wing_r: Node3D
	var tool_mi: MeshInstance3D
	var zz: Label3D
	var sparkles: CPUParticles3D
	var t := 0.0
	var yaw := 0.0
	var _species := ""
	var _tool_key := ""
	var _last := Vector2.INF
	var _blink := 0.0
	var _next_blink := 2.0
	var _twitch := 0.0
	var _next_twitch := 3.0
	var _joy := 0.0
	var _rng := RandomNumberGenerator.new()

	func _ready() -> void:
		_rng.randomize()
		root = Node3D.new()
		add_child(root)
		body = MeshInstance3D.new()
		root.add_child(body)
		lids = MeshInstance3D.new()
		lids.visible = false
		root.add_child(lids)
		ears = _pivot()
		tail = _pivot()
		wing_l = _pivot()
		wing_r = _pivot()
		tool_mi = MeshInstance3D.new()
		root.add_child(tool_mi)
		zz = Label3D.new()
		zz.text = "z"
		zz.font_size = 64
		zz.outline_size = 12
		zz.modulate = Color("#6a6aa0")
		zz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		zz.pixel_size = 0.006
		zz.visible = false
		add_child(zz)
		sparkles = CPUParticles3D.new()
		sparkles.emitting = false
		sparkles.one_shot = true
		sparkles.amount = 18
		sparkles.lifetime = 0.9
		sparkles.explosiveness = 0.9
		sparkles.direction = Vector3.UP
		sparkles.spread = 70.0
		sparkles.initial_velocity_min = 1.2
		sparkles.initial_velocity_max = 2.2
		sparkles.gravity = Vector3(0, -2.5, 0)
		sparkles.scale_amount_min = 0.04
		sparkles.scale_amount_max = 0.07
		var star := SphereMesh.new()
		star.radius = 1.0
		star.height = 2.0
		star.radial_segments = 6
		star.rings = 3
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.albedo_color = Color("#ffe27a")
		star.material = sm
		sparkles.mesh = star
		sparkles.position = Vector3(0, 0.6, 0)
		add_child(sparkles)
		t = _rng.randf() * 10.0
		_next_blink = _rng.randf_range(1.0, 4.0)
		Game.leveled.connect(_on_leveled)

	func _pivot() -> Node3D:
		var n := Node3D.new()
		root.add_child(n)
		var mi := MeshInstance3D.new()
		n.add_child(mi)
		return n

	func _set_part(n: Node3D, mesh: Mesh, pivot: Vector3) -> void:
		n.position = pivot
		(n.get_child(0) as MeshInstance3D).mesh = mesh
		n.visible = mesh != null

	func _on_leveled(p: Dictionary) -> void:
		if actor != null and is_instance_valid(actor) and int(p["id"]) == actor.pid:
			_joy = 1.0
			sparkles.restart()

	func _process(delta: float) -> void:
		if actor == null or not is_instance_valid(actor):
			return
		t += delta
		var p := Game.find_pet(actor.pid)
		if p.is_empty():
			return
		if str(p["species"]) + str(p["prism"]) != _species:
			_species = str(p["species"]) + str(p["prism"])
			var parts := Models3D.pet_parts(str(p["species"]), bool(p["prism"]))
			body.mesh = parts["body"]
			lids.mesh = parts["lids"]
			_set_part(ears, parts["ears"], parts["ear_pivot"])
			_set_part(tail, parts["tail"], parts["tail_pivot"])
			_set_part(wing_l, parts["wing_l"], parts["wing_pivot_l"])
			_set_part(wing_r, parts["wing_r"], parts["wing_pivot_r"])
		var tool := Game.pet_tool(p)
		var tk := "" if tool.is_empty() else "%s%d" % [tool["kind"], tool["tier"]]
		if tk != _tool_key:
			_tool_key = tk
			tool_mi.mesh = null if tool.is_empty() else Models3D.tool(str(tool["kind"]), int(tool["tier"]))
		var s := SCALE * Data.stage_scale(Data.stage_of(int(p["level"])))
		scale = Vector3(s, s, s)
		var pos := actor.position
		position = Terrain3D.to3(pos)
		if _last != Vector2.INF:
			var mv := pos - _last
			if mv.length() > 0.5:
				yaw = lerp_angle(yaw, atan2(mv.x, mv.y), minf(1.0, delta * 10.0))
		_last = pos
		var mood := Game.mood(p)
		var idle: bool = not actor.working and not actor.moving and int(p["work"]) == -1
		var hungry := mood == "hungry"

		# body: hop when walking, breathe, jump and spin for joy
		var hop := absf(sin(t * 10.0)) * 0.16 if actor.moving else 0.0
		var breathe := 1.0 + sin(t * (1.6 if idle else 2.4)) * 0.025
		var spin := 0.0
		if _joy > 0.0:
			_joy = maxf(0.0, _joy - delta * 1.4)
			var k := 1.0 - _joy
			hop = maxf(hop, sin(k * PI) * 0.7)
			spin = k * TAU
		rotation.y = yaw + spin
		root.position.y = hop
		root.scale = Vector3(1.0 / sqrt(breathe), breathe, 1.0 / sqrt(breathe))

		# blinking, or eyes shut while asleep
		_next_blink -= delta
		if _next_blink <= 0.0:
			_blink = 0.13
			_next_blink = _rng.randf_range(2.0, 5.0)
		_blink = maxf(0.0, _blink - delta)
		lids.visible = _blink > 0.0 or idle

		# ears: gentle sway, a quick twitch now and then, droopy when hungry
		_next_twitch -= delta
		if _next_twitch <= 0.0:
			_twitch = 1.0
			_next_twitch = _rng.randf_range(2.5, 7.0)
		_twitch = maxf(0.0, _twitch - delta * 4.0)
		var twitch := sin(_twitch * PI * 3.0) * 0.35 * _twitch
		ears.rotation = Vector3(sin(t * 1.7) * 0.05 + (0.55 if hungry else 0.0) + twitch, 0, sin(t * 1.3) * 0.04)

		# tail: wags faster when walking, working or happy, barely when hungry or asleep
		var wag_speed := 3.0 if idle else (12.0 if actor.moving or _joy > 0.0 else 7.0)
		var wag_amp := 0.12 if (idle or hungry) else (0.45 if mood == "happy" else 0.3)
		tail.rotation = Vector3(0, sin(t * wag_speed) * wag_amp, 0)

		# wings flap when moving, flutter gently otherwise
		var flap := sin(t * (16.0 if actor.moving or _joy > 0.0 else 3.0)) * (0.5 if actor.moving else 0.15)
		wing_l.rotation = Vector3(0, 0, -flap)
		wing_r.rotation = Vector3(0, 0, flap)

		# tool in the right paw, swinging while working
		tool_mi.position = Vector3(-0.42, 0.28, 0.12)
		var swing := 0.0
		if actor.working and not actor.moving:
			swing = sin(t * 8.0) * 0.7 - 0.2
		tool_mi.rotation = Vector3(swing, 0, 0.25)
		zz.visible = idle
		if idle:
			var z := fmod(t, 2.4) / 2.4
			zz.position = Vector3(0.25 + z * 0.15, 1.05 + z * 0.4, 0)
			zz.modulate.a = 1.0 - z


## The Keeper (the player character).
class Keeper3D extends Node3D:
	var keeper: Keeper
	var main_ref = null
	var body: MeshInstance3D
	var legs: Array = []
	var egg: MeshInstance3D
	var t := 0.0
	var yaw := 0.0
	var _egg_type := ""

	func _ready() -> void:
		var parts := Models3D.keeper_parts(Game.keeper_look)
		var root := Node3D.new()
		root.name = "Root"
		add_child(root)
		body = MeshKit.instance(parts[0], root)
		for i in 2:
			var pivot := Node3D.new()
			pivot.position = Vector3(-0.1 + 0.2 * i, 0.32, 0)
			root.add_child(pivot)
			MeshKit.instance(parts[1 + i], pivot)
			legs.append(pivot)
		egg = MeshInstance3D.new()
		egg.position = Vector3(0, 0.42, 0.3)
		root.add_child(egg)
		scale = Vector3.ONE * 0.9
		Game.keeper_changed.connect(_restyle)

	func _restyle() -> void:
		var parts := Models3D.keeper_parts(Game.keeper_look)
		body.mesh = parts[0]
		for i in 2:
			((legs[i] as Node3D).get_child(0) as MeshInstance3D).mesh = parts[1 + i]

	func _process(delta: float) -> void:
		if keeper == null:
			return
		t += delta
		position = Terrain3D.to3(keeper.position)
		var md: Vector2 = main_ref.move_dir if main_ref else Vector2.ZERO
		if md.length() > 0.1:
			yaw = lerp_angle(yaw, atan2(md.x, md.y), minf(1.0, delta * 12.0))
		rotation.y = yaw
		var root: Node3D = get_node("Root")
		var step := sin(t * 12.0) if keeper.moving else 0.0
		for i in 2:
			(legs[i] as Node3D).rotation.x = step * 0.6 * (1.0 if i == 0 else -1.0)
		root.position.y = absf(step) * 0.06 if keeper.moving else sin(t * 2.0) * 0.01
		if keeper.egg_type != _egg_type:
			_egg_type = keeper.egg_type
			egg.mesh = null if _egg_type == "" else Models3D.egg(_egg_type)
		if _egg_type != "":
			var w := keeper.egg_warm
			var wob := sin(t * 18.0) * 0.25 * clampf((w - 0.6) / 0.4, 0.0, 1.0)
			egg.rotation = Vector3(0, 0, wob)
			egg.scale = Vector3.ONE * (1.25 + 0.05 * sin(t * 4.0) * w)
