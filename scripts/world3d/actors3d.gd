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


## A pet. Follows its logic actor (which decides where it walks) and animates.
class Pet3D extends Node3D:
	const SCALE := 1.15
	var actor: PetActor
	var body: MeshInstance3D
	var tool_mi: MeshInstance3D
	var zz: Label3D
	var t := 0.0
	var yaw := 0.0
	var _species := ""
	var _tool_key := ""
	var _last := Vector2.INF

	func _ready() -> void:
		body = MeshInstance3D.new()
		add_child(body)
		tool_mi = MeshInstance3D.new()
		body.add_child(tool_mi)
		zz = Label3D.new()
		zz.text = "z"
		zz.font_size = 64
		zz.outline_size = 12
		zz.modulate = Color("#6a6aa0")
		zz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		zz.pixel_size = 0.006
		zz.visible = false
		add_child(zz)
		t = randf() * 10.0

	func _process(delta: float) -> void:
		if actor == null or not is_instance_valid(actor):
			return
		t += delta
		var p := Game.find_pet(actor.pid)
		if p.is_empty():
			return
		if str(p["species"]) + str(p["prism"]) != _species:
			_species = str(p["species"]) + str(p["prism"])
			body.mesh = Models3D.pet(str(p["species"]), bool(p["prism"]))
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
		rotation.y = yaw
		var hop := absf(sin(t * 10.0)) * 0.16 if actor.moving else 0.0
		var breathe := 1.0 + sin(t * 2.4) * 0.025
		body.position.y = hop
		body.scale = Vector3(1.0 / sqrt(breathe), breathe, 1.0 / sqrt(breathe))
		# tool in the right paw, swinging while working
		tool_mi.position = Vector3(-0.42, 0.28, 0.12)
		var swing := 0.0
		if actor.working and not actor.moving:
			swing = sin(t * 8.0) * 0.7 - 0.2
		tool_mi.rotation = Vector3(swing, 0, 0.25)
		var idle: bool = not actor.working and not actor.moving and int(p["work"]) == -1
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
		var parts := Models3D.keeper_parts()
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
