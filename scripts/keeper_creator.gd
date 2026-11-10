class_name KeeperCreator
extends HBoxContainer
## "Pick a Keeper, then make it yours": start from one of six ready-made Keepers, then change
## skin, hair, outfit and hat with a turning 3D preview. Shown on a new town and from Settings.
## Nothing is labelled for boys or girls; everything is open to everyone.

var hud = null
var first_time := false
var look := {}
var preview_root: Node3D
var preview_mesh: Array = [] # [body, leg, leg] MeshInstance3D
var options: VBoxContainer
var scroll: ScrollContainer
var yaw := 0.4
var dragging := false
var rng := RandomNumberGenerator.new()


func _init(h, first: bool) -> void:
	hud = h
	first_time = first
	rng.randomize()
	look = Models3D.KEEPER_DEFAULT.duplicate()
	look.erase("pants")
	look.merge(Game.keeper_look, true)
	add_theme_constant_override("separation", 14)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_preview()
	var right: VBoxContainer = hud._vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(right)
	scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	options = hud._vbox(8)
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(options)
	var bottom: HBoxContainer = hud._hbox(10)
	var surprise: Button = hud._small_button("Surprise me", _surprise, Color("#7a9cc6"))
	surprise.custom_minimum_size = Vector2(0, 48)
	bottom.add_child(surprise)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(sp)
	var done: Button = hud._button("That's me!", _done, 21)
	done.custom_minimum_size = Vector2(180, 48)
	bottom.add_child(done)
	right.add_child(bottom)
	_rebuild_options()
	_update_preview()


# ---------------------------------------------------------------- preview

func _build_preview() -> void:
	var card: PanelContainer = hud._card(Color("#eaf4f6"))
	card.custom_minimum_size = Vector2(250, 300)
	card.size_flags_horizontal = Control.SIZE_FILL
	add_child(card)
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vpc.gui_input.connect(_on_preview_input)
	card.add_child(vpc)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vpc.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#d8e4ff")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 0.85
	sun.light_color = Color("#fff4e0")
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.position = Vector3(0, 1.1, 4.3)
	vp.add_child(cam)
	cam.look_at(Vector3(0, 0.74, 0))
	preview_root = Node3D.new()
	vp.add_child(preview_root)
	var ground := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.55
	disc.bottom_radius = 0.58
	disc.height = 0.06
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#9fd27a")
	disc.material = gm
	ground.mesh = disc
	ground.position = Vector3(0, -0.03, 0)
	preview_root.add_child(ground)
	var body := MeshInstance3D.new()
	preview_root.add_child(body)
	preview_mesh.append(body)
	for i in 2:
		var leg := MeshInstance3D.new()
		leg.position = Vector3(-0.1 + 0.2 * i, 0.32, 0)
		preview_root.add_child(leg)
		preview_mesh.append(leg)


func _on_preview_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		dragging = e.pressed
	elif e is InputEventScreenTouch:
		dragging = e.pressed
	elif (e is InputEventMouseMotion and dragging) or e is InputEventScreenDrag:
		yaw += e.relative.x * 0.012


func _process(delta: float) -> void:
	if not dragging:
		yaw += delta * 0.5
	if preview_root:
		preview_root.rotation.y = yaw


func _update_preview() -> void:
	var parts := Models3D.keeper_parts(look)
	for i in 3:
		(preview_mesh[i] as MeshInstance3D).mesh = parts[i]


# ---------------------------------------------------------------- options

func _set_part(key: String, value) -> void:
	look[key] = value
	_changed()


func _changed() -> void:
	_update_preview()
	_rebuild_options.call_deferred()


func _rebuild_options() -> void:
	var keep := scroll.scroll_vertical
	for c in options.get_children():
		c.queue_free()
	options.add_child(_heading("Start from a Keeper"))
	var presets := HFlowContainer.new()
	presets.add_theme_constant_override("h_separation", 8)
	presets.add_theme_constant_override("v_separation", 8)
	for p in Models3D.KEEPER_PRESETS:
		var pd: Dictionary = p
		var same := true
		for k in look:
			if pd.has(k) and str(pd[k]) != str(look[k]):
				same = false
		var b: Button = hud._small_button(str(pd["name"]), func(): _use_preset(pd), Color(str(pd["outfit"])) if same else Color("#a39486"))
		b.custom_minimum_size = Vector2(0, 44)
		presets.add_child(b)
	options.add_child(presets)
	options.add_child(_heading("Skin"))
	options.add_child(_swatches(Models3D.SKIN_TONES, "skin"))
	options.add_child(_heading("Hair"))
	options.add_child(_choices(Models3D.HAIR_STYLES, Models3D.HAIR_NAMES, "hair"))
	options.add_child(_swatches(Models3D.HAIR_COLOURS, "hair_col"))
	options.add_child(_heading("Outfit"))
	options.add_child(_swatches(Models3D.OUTFIT_COLOURS, "outfit"))
	options.add_child(_heading("Hat"))
	options.add_child(_choices(Models3D.HAT_STYLES, Models3D.HAT_NAMES, "hat"))
	if str(look["hat"]) != "none":
		options.add_child(_swatches(Models3D.HAT_COLOURS, "hat_col"))
	options.add_child(hud._wrap("You can change this any time from Settings.", 15))
	_restore_scroll.call_deferred(keep)


func _restore_scroll(v: int) -> void:
	scroll.scroll_vertical = v


func _heading(text: String) -> Label:
	return hud._label(text, 19)


func _choices(keys: Array, names: Dictionary, key: String) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	for k in keys:
		var v: String = k
		var on := str(look[key]) == v
		var b: Button = hud._small_button(str(names.get(v, v)), func(): _set_part(key, v), Color("#5aa64a") if on else Color("#a39486"))
		b.custom_minimum_size = Vector2(0, 44)
		flow.add_child(b)
	return flow


func _swatches(cols: Array, key: String) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	for c in cols:
		var hex: String = c
		var on := Color(str(look[key])).is_equal_approx(Color(hex))
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(44, 44)
		b.tooltip_text = hex
		var s := StyleBoxFlat.new()
		s.bg_color = Color(hex)
		s.set_corner_radius_all(22)
		s.set_border_width_all(4 if on else 2)
		s.border_color = Color("#4a3a32") if on else Color(1, 1, 1, 0.9)
		b.add_theme_stylebox_override("normal", s)
		b.add_theme_stylebox_override("hover", s)
		b.add_theme_stylebox_override("pressed", s)
		b.pressed.connect(func(): _set_part(key, hex))
		flow.add_child(b)
	return flow


func _use_preset(p: Dictionary) -> void:
	for k in p:
		if k != "name":
			look[k] = p[k]
	_changed()


func _pick(a: Array) -> String:
	return str(a[rng.randi() % a.size()])


func _surprise() -> void:
	look["skin"] = _pick(Models3D.SKIN_TONES)
	look["hair"] = _pick(Models3D.HAIR_STYLES)
	look["hair_col"] = _pick(Models3D.HAIR_COLOURS)
	look["outfit"] = _pick(Models3D.OUTFIT_COLOURS)
	look["hat"] = _pick(Models3D.HAT_STYLES)
	look["hat_col"] = _pick(Models3D.HAT_COLOURS)
	_changed()


func _done() -> void:
	Game.set_keeper_look(look)
	hud.close_modal()
	if first_time:
		hud.open_help.call_deferred()
