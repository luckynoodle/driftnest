class_name GameHud
extends CanvasLayer
## Screen UI, built entirely in code: resource bar, goal + egg cards, menu buttons, joystick,
## the Keeper's action button, placement bar, and all the windows (Build, building panels,
## Pets + Pet Log, pet details, Eggs, Help, hatch reveal, welcome back).

const PortraitScript := preload("res://scripts/portrait.gd")
const JoystickScript := preload("res://scripts/joystick.gd")

const TEXT := Color("#4a3a32")
const SUBTLE := Color("#8a7668")
const GOOD := Color("#3f8f4f")
const BAD := Color("#c2413e")

var main = null
var root: Control
var joystick
var theme_res: Theme

var res_labels: Dictionary = {}
var res_bars: Dictionary = {}
var goal_label: Label
var goal_reward: Label
var goal_panel: PanelContainer
var egg_portrait
var egg_name: Label
var egg_bar: ProgressBar
var egg_info: Label

var action_btn: Button
var _action_text := ""

var place_panel: PanelContainer
var place_title: Label
var place_reason: Label
var place_ok: Button

var toast_panel: PanelContainer
var toast_label: Label
var _toast_tween: Tween

var modal: Control = null
var _modal_kind := ""
var _modal_arg := -1
var _pets_tab := "mine"
var _hatch_queue: Array = []
var _confirm_demolish := -1
var _refresh_t := 0.0

## HUD layout: the root is scaled so buttons stay finger-sized on phones (about 44 points),
## and inset by the notch / home-bar safe area on native iOS.
var ui_scale := 1.0
var compact := false
var left_col: VBoxContainer
var chip_flow: HFlowContainer
var menu_box: VBoxContainer
var fps_label: Label


func _ready() -> void:
	layer = 5
	theme_res = _build_theme()
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme_res
	add_child(root)
	_layout()
	get_viewport().size_changed.connect(_layout)

	_build_topbar()
	_build_cards()
	_build_menu_buttons()
	_build_action()
	_build_joystick()
	_build_place_bar()
	_build_toast()

	Game.changed.connect(refresh)
	Game.toast.connect(toast)
	Game.hatched.connect(_on_hatched)
	Game.leveled.connect(func(p): toast("%s reached level %d!" % [Game.pet_name(p), int(p["level"])]))
	Game.skill_up.connect(func(p, job): toast("%s's %s skill is now %d." % [Game.pet_name(p), Data.JOBS[job]["name"], int(Game.skill(p, job)["lvl"])]))
	Game.goal_done.connect(_on_goal_done)
	Game.welcome_back.connect(_on_welcome_back)
	Game.settings_changed.connect(_layout)
	refresh()
	_layout()
	if Game.first_run:
		open_help.call_deferred()
	elif Game.migration_note != "":
		_show_migration.call_deferred()
	elif not Game.offline_report.is_empty():
		_show_welcome.call_deferred()
	for h in Game.take_pending_hatches():
		_hatch_queue.append(h)


func _process(delta: float) -> void:
	if fps_label and fps_label.visible:
		fps_label.text = "%d fps" % Engine.get_frames_per_second()
	# live-update open panels a few times a second (progress bars, worker output)
	_refresh_t += delta
	if _refresh_t > 0.5:
		_refresh_t = 0.0
		_refresh_egg()
		if modal and _modal_kind in ["building"]:
			_reopen()


func is_modal_open() -> bool:
	return modal != null


# ================================================================ theme & widgets

func _sb(bg: Color, radius: int = 16, border: int = 0, border_col: Color = Color.TRANSPARENT, pad: float = 12.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_col
	s.set_content_margin_all(pad)
	s.anti_aliasing = true
	return s


func _build_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 20
	th.set_stylebox("panel", "PanelContainer", _sb(Color("#fff7ec"), 22, 3, Color("#e8c9a0"), 18))
	var normal := _sb(Color("#ff8a65"), 14, 0, Color.TRANSPARENT, 8)
	normal.border_width_bottom = 4
	normal.border_color = Color("#d9603e")
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#ff9f7f")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#ec7350")
	pressed.border_width_bottom = 1
	pressed.content_margin_top = 11
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("#d9cfc4")
	disabled.border_color = Color("#bfb3a6")
	th.set_stylebox("normal", "Button", normal)
	th.set_stylebox("hover", "Button", hover)
	th.set_stylebox("pressed", "Button", pressed)
	th.set_stylebox("disabled", "Button", disabled)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		th.set_color(c, "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color("#8f8378"))
	th.set_color("font_color", "Label", TEXT)
	th.set_color("default_color", "RichTextLabel", TEXT)
	th.set_stylebox("background", "ProgressBar", _sb(Color("#eadccb"), 8, 0, Color.TRANSPARENT, 0))
	th.set_stylebox("fill", "ProgressBar", _sb(Color("#ffb347"), 8, 0, Color.TRANSPARENT, 0))
	return th


func _card_style() -> StyleBoxFlat:
	var s := _sb(Color(1.0, 0.98, 0.94, 0.94), 16, 3, Color("#e8c9a0"), 8)
	s.shadow_color = Color(0, 0, 0, 0.12)
	s.shadow_size = 5
	s.shadow_offset = Vector2(0, 3)
	return s


func _label(text: String, size: int = 20, col: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _wrap(text: String, size: int = 17, col: Color = SUBTLE) -> Label:
	var l := _label(text, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _bar(col: Color, w: float = 190.0, h: float = 14.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_stylebox_override("fill", _sb(col, 8, 0, Color.TRANSPARENT, 0))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _portrait(mode: String, sz: Vector2) -> Control:
	var p: Control = PortraitScript.new()
	p.mode = mode
	p.custom_minimum_size = sz
	return p


func _res_icon(r: String, sz: float = 24.0) -> Control:
	var p = _portrait("res", Vector2(sz, sz))
	p.res = r
	return p


func _tool_icon(kind: String, tier: int, sz: float = 36.0) -> Control:
	var p = _portrait("tool", Vector2(sz, sz))
	p.tool_kind = kind
	p.tier = tier
	return p


func _pet_pic(p: Dictionary, sz: Vector2) -> Control:
	var pic = _portrait("pet", sz)
	pic.species = str(p["species"])
	pic.level = int(p["level"])
	pic.prism = bool(p["prism"])
	return pic


func _button(text: String, cb: Callable, font_size: int = 19) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _small_button(text: String, cb: Callable, color: Color = Color("#ff8a65")) -> Button:
	var b := _button(text, cb, 16)
	var s := _sb(color, 12, 0, Color.TRANSPARENT, 6)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.border_width_bottom = 3
	s.border_color = color.darkened(0.2)
	b.add_theme_stylebox_override("normal", s)
	var hs := s.duplicate() as StyleBoxFlat
	hs.bg_color = color.lightened(0.12)
	b.add_theme_stylebox_override("hover", hs)
	return b


func _cost_row(cost: Dictionary, size: int = 16) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	if cost.is_empty():
		row.add_child(_label("Free", size, GOOD))
	for r in ["glimmer"] + Data.RES_ORDER:
		if not cost.has(r):
			continue
		row.add_child(_res_icon(r, size + 4))
		var have := int(Game.res.get(r, 0)) >= int(cost[r])
		row.add_child(_label(str(int(cost[r])) + "  ", size, TEXT if have else BAD))
	return row


func _hbox(sep: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


func _vbox(sep: int = 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


func _card(bg: Color = Color("#fffdf8")) -> PanelContainer:
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", _sb(bg, 16, 2, Color("#efd9bb"), 10))
	return c


func _section(text: String) -> Label:
	return _label(text, 22, TEXT)


# ================================================================ layout & scaling

## How many points (iOS logical pixels) one viewport pixel covers on this screen.
func _points_per_px() -> float:
	var vp := get_viewport().get_visible_rect().size
	var short_vp := minf(vp.x, vp.y)
	if short_vp <= 0.0:
		return 1.0
	var short_pts := 0.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pts="): # testing: pretend to be a device this many points tall
			return float(arg.substr(6)) / short_vp
	if OS.has_feature("web"):
		var v = JavaScriptBridge.eval("Math.min(window.innerWidth, window.innerHeight)")
		short_pts = float(v) if v != null else 0.0
	if short_pts <= 0.0:
		var win := DisplayServer.window_get_size()
		var sc := maxf(DisplayServer.screen_get_scale(), 1.0)
		short_pts = minf(win.x, win.y) / sc
	return short_pts / short_vp


func _safe_margins() -> Array:
	## [left, top, right, bottom] in viewport pixels (only on phones/tablets running natively).
	if not OS.has_feature("mobile"):
		return [0.0, 0.0, 0.0, 0.0]
	var win := Vector2(DisplayServer.window_get_size())
	var safe := DisplayServer.get_display_safe_area()
	var vp := get_viewport().get_visible_rect().size
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0:
		return [0.0, 0.0, 0.0, 0.0]
	var k := vp / win
	return [safe.position.x * k.x, safe.position.y * k.y,
		(win.x - safe.end.x) * k.x, (win.y - safe.end.y) * k.y]


func _layout() -> void:
	if root == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var ratio := _points_per_px()
	var mult: float = {"small": 0.85, "auto": 1.0, "large": 1.18}.get(Game.settings.get("ui_size", "auto"), 1.0)
	ui_scale = clampf(0.92 / maxf(ratio, 0.05), 1.0, 1.75) * mult
	ui_scale = maxf(ui_scale, 0.8)
	var m := _safe_margins()
	root.position = Vector2(m[0], m[1])
	root.scale = Vector2(ui_scale, ui_scale)
	root.size = (vp - Vector2(m[0] + m[2], m[1] + m[3])) / ui_scale
	compact = root.size.y < 560.0
	if left_col:
		var avail := root.size.x - 170.0
		left_col.custom_minimum_size = Vector2(avail, 0)
		left_col.size = Vector2(avail, 0)
		chip_flow.custom_minimum_size = Vector2(avail, 0)
	if joystick:
		var js := 180.0 if compact else 220.0
		joystick.offset_left = 20
		joystick.offset_right = 20 + js
		joystick.offset_top = -js - 20
		joystick.offset_bottom = -20
		joystick.queue_redraw()
	if fps_label:
		fps_label.visible = bool(Game.settings.get("show_fps", false))
	if modal and _modal_kind != "" and _modal_kind != "hatch" and _modal_kind != "welcome":
		_reopen.call_deferred()


# ================================================================ always-on HUD

func _build_topbar() -> void:
	left_col = _vbox(8)
	left_col.position = Vector2(12, 10)
	left_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(left_col)
	chip_flow = HFlowContainer.new()
	chip_flow.add_theme_constant_override("h_separation", 6)
	chip_flow.add_theme_constant_override("v_separation", 6)
	chip_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_col.add_child(chip_flow)
	for r in ["glimmer"] + Data.RES_ORDER + ["pets", "charm"]:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", _card_style())
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var h := _hbox(4)
		h.add_child(_res_icon(r, 22))
		var lv := _vbox(0)
		lv.alignment = BoxContainer.ALIGNMENT_CENTER
		var l := _label("0", 18)
		l.custom_minimum_size = Vector2(30, 0)
		lv.add_child(l)
		if Data.STORAGE_BASE.has(r):
			# how full the store is
			var sb := _bar(Color("#7ed492"), 34, 4)
			lv.add_child(sb)
			res_bars[r] = sb
		h.add_child(lv)
		chip.add_child(h)
		chip_flow.add_child(chip)
		res_labels[r] = l


func _build_cards() -> void:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_col.add_child(row)

	goal_panel = PanelContainer.new()
	goal_panel.add_theme_stylebox_override("panel", _card_style())
	goal_panel.custom_minimum_size = Vector2(300, 0)
	goal_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gv := _vbox(1)
	gv.add_child(_label("Goal", 14, Color("#c27c2c")))
	goal_label = _label("", 16)
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_label.custom_minimum_size = Vector2(280, 0)
	gv.add_child(goal_label)
	goal_reward = _label("", 13, SUBTLE)
	gv.add_child(goal_reward)
	goal_panel.add_child(gv)
	row.add_child(goal_panel)

	var ep := PanelContainer.new()
	ep.add_theme_stylebox_override("panel", _card_style())
	ep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ep.custom_minimum_size = Vector2(250, 0)
	ep.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var eh := _hbox(8)
	egg_portrait = _portrait("egg", Vector2(40, 46))
	eh.add_child(egg_portrait)
	var ev := _vbox(2)
	ev.alignment = BoxContainer.ALIGNMENT_CENTER
	egg_name = _label("", 16)
	egg_bar = _bar(Color("#ffb347"), 170, 11)
	egg_info = _label("", 13, SUBTLE)
	ev.add_child(egg_name)
	ev.add_child(egg_bar)
	ev.add_child(egg_info)
	eh.add_child(ev)
	ep.add_child(eh)
	row.add_child(ep)


func _build_menu_buttons() -> void:
	var box := _vbox(8)
	menu_box = box
	box.anchor_left = 1.0
	box.anchor_right = 1.0
	box.offset_left = -144
	box.offset_right = -12
	box.offset_top = 10
	box.offset_bottom = 300
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	for pair in [["Build", open_build], ["Pets", open_pets], ["Eggs", open_eggs], ["Settings", open_settings]]:
		var b := _button(pair[0], pair[1], 20)
		b.custom_minimum_size = Vector2(0, 46)
		box.add_child(b)
	var zoom := _hbox(8)
	var zin := _small_button("+", func(): main.zoom_by(1.15), Color("#7a9cc6"))
	var zout := _small_button("-", func(): main.zoom_by(1.0 / 1.15), Color("#7a9cc6"))
	zin.custom_minimum_size = Vector2(58, 44)
	zout.custom_minimum_size = Vector2(58, 44)
	zin.add_theme_font_size_override("font_size", 24)
	zout.add_theme_font_size_override("font_size", 24)
	zoom.add_child(zout)
	zoom.add_child(zin)
	box.add_child(zoom)
	fps_label = _label("", 15, Color.WHITE)
	fps_label.add_theme_color_override("font_outline_color", Color("#3b2a2a"))
	fps_label.add_theme_constant_override("outline_size", 6)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(fps_label)


func _build_action() -> void:
	action_btn = Button.new()
	action_btn.focus_mode = Control.FOCUS_NONE
	action_btn.add_theme_font_size_override("font_size", 24)
	action_btn.anchor_left = 1.0
	action_btn.anchor_right = 1.0
	action_btn.anchor_top = 1.0
	action_btn.anchor_bottom = 1.0
	action_btn.offset_left = -300
	action_btn.offset_right = -20
	action_btn.offset_top = -92
	action_btn.offset_bottom = -20
	action_btn.visible = false
	action_btn.button_down.connect(func(): main.action_down())
	action_btn.button_up.connect(func(): main.action_up())
	root.add_child(action_btn)


func _build_joystick() -> void:
	joystick = JoystickScript.new()
	joystick.anchor_top = 1.0
	joystick.anchor_bottom = 1.0
	joystick.offset_left = 28
	joystick.offset_right = 248
	joystick.offset_top = -248
	joystick.offset_bottom = -28
	root.add_child(joystick)


func _build_place_bar() -> void:
	place_panel = PanelContainer.new()
	place_panel.anchor_left = 0.5
	place_panel.anchor_right = 0.5
	place_panel.anchor_top = 1.0
	place_panel.anchor_bottom = 1.0
	place_panel.offset_left = -290
	place_panel.offset_right = 290
	place_panel.offset_top = -132
	place_panel.offset_bottom = -16
	place_panel.visible = false
	var v := _vbox(6)
	var top := _hbox(10)
	place_title = _label("", 22)
	place_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(place_title)
	top.add_child(_small_button("Cancel", func(): main.cancel_place(), Color("#a39486")))
	place_ok = _small_button("Place here", func(): main.confirm_place(), Color("#5aa64a"))
	top.add_child(place_ok)
	v.add_child(top)
	place_reason = _label("", 16, SUBTLE)
	v.add_child(place_reason)
	place_panel.add_child(v)
	root.add_child(place_panel)


func update_placement(type: String, reason: String) -> void:
	if type == "":
		place_panel.visible = false
		joystick.visible = true
		return
	place_panel.visible = true
	place_title.text = "Place: " + Data.BUILDINGS[type]["name"]
	place_ok.disabled = reason != ""
	if reason == "":
		place_reason.text = "Tap the ground to move it. Looks good here!"
		place_reason.add_theme_color_override("font_color", GOOD)
	else:
		place_reason.text = "Tap the ground to move it.  " + reason
		place_reason.add_theme_color_override("font_color", BAD)


func _build_toast() -> void:
	toast_panel = PanelContainer.new()
	toast_panel.anchor_left = 0.5
	toast_panel.anchor_right = 0.5
	toast_panel.offset_left = -320
	toast_panel.offset_right = 320
	toast_panel.offset_top = 64
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.add_theme_stylebox_override("panel", _sb(Color(0.23, 0.17, 0.15, 0.88), 18, 0, Color.TRANSPARENT, 12))
	toast_label = _label("", 19, Color.WHITE)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_panel.add_child(toast_label)
	toast_panel.modulate.a = 0.0
	root.add_child(toast_panel)


func toast(text: String) -> void:
	toast_label.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_panel, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(2.8)
	_toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.5)


func refresh() -> void:
	for r in ["glimmer"] + Data.RES_ORDER:
		res_labels[r].text = str(int(Game.res.get(r, 0)))
		if res_bars.has(r):
			var cap := Game.storage_cap(r)
			var have := int(Game.res.get(r, 0))
			var fill := float(have) / float(cap)
			var bar: ProgressBar = res_bars[r]
			bar.max_value = cap
			bar.value = have
			var col := Color("#7ed492") if fill < 0.85 else (Color("#ffb347") if fill < 1.0 else Color("#e05a4a"))
			bar.add_theme_stylebox_override("fill", _sb(col, 3, 0, Color.TRANSPARENT, 0))
			res_labels[r].add_theme_color_override("font_color", BAD if fill >= 1.0 else TEXT)
	res_labels["pets"].text = "%d/%d" % [Game.pets.size(), Game.capacity()]
	res_labels["charm"].text = str(Game.charm())
	var g := Game.current_goal()
	if g.is_empty():
		goal_label.text = "All goals done. Keep growing your town!"
		goal_reward.text = ""
	else:
		goal_label.text = str(g["text"])
		goal_reward.text = "Reward: " + Data.cost_text(g["reward"])
	_refresh_egg()


func _refresh_egg() -> void:
	var e := Game.carried_egg()
	if e.is_empty():
		egg_portrait.egg_type = ""
		egg_name.text = "No egg carried"
		egg_bar.visible = false
		egg_info.text = "Buy one at the Egg Kiosk" if Game.eggs.is_empty() else "Pick one in Eggs"
	else:
		var need := float(Data.EGGS[e["type"]]["warmth"])
		egg_portrait.egg_type = str(e["type"])
		egg_portrait.warmth = Game.egg_ratio(e)
		egg_name.text = str(Data.EGGS[e["type"]]["name"])
		egg_bar.visible = true
		egg_bar.max_value = need
		egg_bar.value = float(e["warmth"])
		if bool(e.get("waiting", false)):
			egg_info.text = "Ready! Build a House to make room"
		else:
			egg_info.text = "Hatches in %ds" % ceili(need - float(e["warmth"]))


func show_action(text: String) -> void:
	if _action_text != text or not action_btn.visible:
		_action_text = text
		action_btn.text = text
		action_btn.visible = true


func hide_action() -> void:
	if action_btn.visible:
		action_btn.visible = false
		_action_text = ""


# ================================================================ modal windows

func close_modal() -> void:
	if modal:
		modal.queue_free()
		modal = null
	_modal_kind = ""
	_confirm_demolish = -1
	joystick.enabled = true
	if not _hatch_queue.is_empty():
		var next: Array = _hatch_queue.pop_front()
		_show_hatch.call_deferred(next[0], next[1])


func _reopen() -> void:
	match _modal_kind:
		"building": open_building(_modal_arg)
		"pet": open_pet(_modal_arg)
		"pets": open_pets()
		"eggs": open_eggs()
		"build": open_build()


func _open_window(title: String, w: float, h: float, closable: bool = true, kind: String = "", arg: int = -1) -> VBoxContainer:
	var scroll_keep := 0
	if modal and _modal_kind == kind and _modal_arg == arg:
		var old_sc := modal.find_child("Scroll", true, false) as ScrollContainer
		if old_sc:
			scroll_keep = old_sc.scroll_vertical
	if modal:
		modal.queue_free()
		modal = null
	_modal_kind = kind
	_modal_arg = arg
	joystick.release()
	joystick.enabled = false
	main.action_up()
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.12, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	modal = dim
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(cc)
	var panel := PanelContainer.new()
	var vp := root.size
	panel.custom_minimum_size = Vector2(minf(w, vp.x - 16.0), minf(h, vp.y - 16.0))
	cc.add_child(panel)
	var vb := _vbox(10)
	panel.add_child(vb)
	var header := _hbox(10)
	var tl := _label(title, 24 if compact else 28)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(tl)
	if closable:
		header.add_child(_button("Close", close_modal))
	vb.add_child(header)
	if scroll_keep > 0:
		_restore_scroll.call_deferred(scroll_keep)
	return vb


func _restore_scroll(v: int) -> void:
	if modal:
		var sc := modal.find_child("Scroll", true, false) as ScrollContainer
		if sc:
			sc.scroll_vertical = v


func _scroll(parent: Control) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = "Scroll"
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(sc)
	var inner := _vbox(10)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(inner)
	return inner


# ---------------------------------------------------------------- Build menu

func open_build() -> void:
	if main.placing != "":
		main.cancel_place()
	var vb := _open_window("Build", 980, 640, true, "build")
	vb.add_child(_wrap("Pick a building, then tap the ground to place it inside the town border. Pets with a hammer at the Builder's Hut put it up. You can help by standing next to it.", 16))
	var list := _scroll(vb)
	var grid := GridContainer.new()
	grid.columns = clampi(int((minf(980.0, root.size.x - 16.0) - 40.0) / 290.0), 1, 3)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	list.add_child(grid)
	for type in Data.BUILD_ORDER:
		var info: Dictionary = Data.BUILDINGS[type]
		var locked := int(info.get("th", 1)) > Game.town_level
		var card := _card(Color("#f3ece2") if locked else Color("#fffdf8"))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h := _hbox(8)
		var pic = _portrait("building", Vector2(96, 96))
		pic.building = type
		h.add_child(pic)
		var v := _vbox(3)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(_label(str(info["name"]), 19))
		v.add_child(_cost_row(Game.build_cost(type), 14))
		var d := _wrap(str(info["desc"]), 13)
		d.custom_minimum_size = Vector2(160, 0)
		v.add_child(d)
		if locked:
			v.add_child(_label("Town Hall Lv %d" % int(info["th"]), 15, BAD))
		else:
			var b := _small_button("Place", func(): close_modal(); main.start_placing(type), Color("#5aa64a"))
			b.disabled = not Game.can_afford(Game.build_cost(type))
			b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			v.add_child(b)
		h.add_child(v)
		card.add_child(h)
		grid.add_child(card)


# ---------------------------------------------------------------- building panels

func open_building(bid: int) -> void:
	var b := Game.find_building(bid)
	if b.is_empty():
		close_modal()
		return
	var info: Dictionary = Data.BUILDINGS[b["type"]]
	var vb := _open_window(str(info["name"]), 900, 620, true, "building", bid)
	var body := _scroll(vb)
	body.add_child(_wrap(str(info["desc"]), 17))
	if not bool(b["built"]):
		_construction_panel(body, b)
	else:
		if info.has("job"):
			_work_panel(body, b)
		match str(b["type"]):
			"town_hall": _town_hall_panel(body)
			"nest": _nest_panel(body)
			"kiosk": _kiosk_panel(body)
			"workshop": _workshop_panel(body)
			"market": _market_panel(body)
			"house":
				body.add_child(_label("Town has room for %d pets (%d living here now)." % [Game.capacity(), Game.pets.size()], 18))
			"storehouse":
				_storage_rows(body)
		if bool(info.get("deco", false)) and int(info.get("charm", 0)) > 0:
			body.add_child(_label("Town charm: %d  (+%d%% to all production)" % [Game.charm(), int(round((Game.charm_mult() - 1.0) * 100.0))], 18, GOOD))
	if not bool(info.get("fixed", false)):
		var txt := "Tap again to confirm" if _confirm_demolish == bid else ("Cancel construction (full refund)" if not bool(b["built"]) else "Demolish (50% refund)")
		var db := _small_button(txt, func(): _demolish(bid), Color("#c96a5a"))
		db.size_flags_horizontal = Control.SIZE_SHRINK_END
		vb.add_child(db)


func _demolish(bid: int) -> void:
	if _confirm_demolish != bid:
		_confirm_demolish = bid
		open_building(bid)
		return
	Game.demolish(bid)
	close_modal()


func _construction_panel(body: VBoxContainer, b: Dictionary) -> void:
	var need := float(Data.BUILDINGS[b["type"]]["work"])
	body.add_child(_section("Under construction"))
	var bar := _bar(Color("#ffb347"), 400, 18)
	bar.max_value = need
	bar.value = float(b["progress"])
	body.add_child(bar)
	body.add_child(_label("%d / %d work done" % [int(b["progress"]), int(need)], 16, SUBTLE))
	var builders := 0
	for hut in Game.buildings_of("builder_hut"):
		builders += Game.workers_at(int(hut["id"])).size()
	var target := Game.construction_target()
	if builders == 0:
		body.add_child(_wrap("No builders yet! Give a pet a Hammer and send it to the Builder's Hut, or stand next to this and hold Help build.", 17, BAD))
	elif target != b:
		body.add_child(_wrap("Builders are busy with another project first. They work through jobs in order.", 17))
	else:
		body.add_child(_label("%d builder(s) working on this." % builders, 17, GOOD))


func _job_building_names(job: String) -> String:
	var names: Array = []
	for type in Data.BUILDINGS:
		if Data.BUILDINGS[type].get("job", "") == job:
			names.append(Data.BUILDINGS[type]["name"])
	return " or ".join(names)


func _rate_text(p: Dictionary, b: Dictionary) -> String:
	var info: Dictionary = Data.BUILDINGS[b["type"]]
	var job: String = info["job"]
	var iv := Game.work_interval(p, b)
	match job:
		"building": return "%.1f build/sec" % (1.0 / iv)
		"exploring": return "a trip every %ds" % int(round(iv))
	return "1 %s every %.1fs" % [Data.RESOURCES[info["res"]]["name"].to_lower(), iv]


func _work_panel(body: VBoxContainer, b: Dictionary) -> void:
	var info: Dictionary = Data.BUILDINGS[b["type"]]
	var job: String = info["job"]
	var tool_kind: String = Data.JOBS[job]["tool"]
	var bid := int(b["id"])
	var workers := Game.workers_at(bid)
	body.add_child(_section("Workers  %d / %d" % [workers.size(), int(info["slots"])]))
	if info.has("res") and Game.is_full(info["res"]):
		body.add_child(_wrap("The %s store is full, so work has paused. Build a Storehouse, spend some, or sell at the Market." % Data.RESOURCES[info["res"]]["name"].to_lower(), 16, BAD))
	var dec := Game.decor_bonus(b)
	if dec > 0.0:
		body.add_child(_label("Nearby decorations: +%d%% speed" % int(round(dec * 100.0)), 15, GOOD))
	if b["type"] == "builder_hut":
		var target := Game.construction_target()
		if target.is_empty():
			body.add_child(_label("Nothing to build right now. Place something from the Build menu!", 16, SUBTLE))
		else:
			body.add_child(_label("Building: %s" % Data.BUILDINGS[target["type"]]["name"], 16, GOOD))
	for p in workers:
		var card := _card()
		var h := _hbox(10)
		h.add_child(_pet_pic(p, Vector2(70, 60)))
		var v := _vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nm := Game.pet_name(p) + ("  (Talent!)" if Game.has_talent(p, job) else "")
		v.add_child(_label(nm, 18, GOOD if Game.has_talent(p, job) else TEXT))
		var sk := Game.skill(p, job)
		v.add_child(_label("%s skill %d  ·  %s" % [Data.JOBS[job]["name"], int(sk["lvl"]), Data.tool_name(Game.pet_tool(p))], 15, SUBTLE))
		v.add_child(_label(_rate_text(p, b), 15, TEXT))
		h.add_child(v)
		var pid := int(p["id"])
		h.add_child(_small_button("Details", func(): open_pet(pid), Color("#7a9cc6")))
		h.add_child(_small_button("Remove", func(): Game.unassign(pid); open_building(bid), Color("#a39486")))
		card.add_child(h)
		body.add_child(card)
	if workers.size() >= int(info["slots"]):
		return
	# candidates
	var ready: Array = []
	var could: Array = []
	for p in Game.pets:
		if int(p["work"]) == bid:
			continue
		if Game.pet_job(p) == job:
			ready.append(p)
		elif int(p["work"]) == -1:
			could.append(p)
	var spare := Game.free_tools().filter(func(t): return t["kind"] == tool_kind)
	spare.sort_custom(func(a, c): return int(a["tier"]) > int(c["tier"]))
	if ready.is_empty() and (could.is_empty() or spare.is_empty()):
		var tn: String = Data.TOOLS[tool_kind]["name"]
		body.add_child(_wrap("Pets need %s %s to work here. %s" % ["an" if tn[0] in "AEIOU" else "a", tn,
			"Craft one at the Workshop." if spare.is_empty() else "Hatch more pets to fill this spot."], 16, BAD))
		return
	body.add_child(_section("Add a worker"))
	for p in ready:
		body.add_child(_candidate_card(p, b, ""))
	if not spare.is_empty():
		for p in could:
			body.add_child(_candidate_card(p, b, "Give %s & assign" % Data.tool_name(spare[0])))


func _candidate_card(p: Dictionary, b: Dictionary, give_text: String) -> Control:
	var job: String = Data.BUILDINGS[b["type"]]["job"]
	var bid := int(b["id"])
	var pid := int(p["id"])
	var card := _card()
	var h := _hbox(10)
	h.add_child(_pet_pic(p, Vector2(64, 54)))
	var v := _vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_label(Game.pet_name(p) + ("  (Talent!)" if Game.has_talent(p, job) else ""), 17, GOOD if Game.has_talent(p, job) else TEXT))
	var where := "Idle"
	var cur := Game.find_building(int(p["work"]))
	if not cur.is_empty():
		where = "Working at " + Data.BUILDINGS[cur["type"]]["name"]
	v.add_child(_label("Lv %d  ·  %s skill %d  ·  %s" % [int(p["level"]), Data.JOBS[job]["name"], int(Game.skill(p, job)["lvl"]), where], 14, SUBTLE))
	h.add_child(v)
	var kind: String = Data.JOBS[job]["tool"]
	var cb := func() -> void:
		if give_text != "":
			var spare := Game.free_tools().filter(func(t): return t["kind"] == kind)
			spare.sort_custom(func(a, c): return int(a["tier"]) > int(c["tier"]))
			if spare.is_empty():
				return
			Game.give_tool(pid, int(spare[0]["id"]))
		var err := Game.assign(pid, bid)
		if err != "":
			toast(err)
		open_building(bid)
	h.add_child(_small_button("Assign" if give_text == "" else give_text, cb, Color("#5aa64a")))
	card.add_child(h)
	return card


func _storage_rows(body: VBoxContainer) -> void:
	body.add_child(_section("Storage"))
	for r in Data.RES_ORDER:
		var row := _hbox(8)
		row.add_child(_res_icon(r, 24))
		var cap := Game.storage_cap(r)
		var have := int(Game.res.get(r, 0))
		var nl := _label(Data.RESOURCES[r]["name"], 16)
		nl.custom_minimum_size = Vector2(90, 0)
		row.add_child(nl)
		var bar := _bar(Color("#7ed492") if have < cap else Color("#e05a4a"), 200, 12)
		bar.max_value = cap
		bar.value = have
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		row.add_child(_label("%d / %d" % [have, cap], 15, BAD if have >= cap else SUBTLE))
		body.add_child(row)
	body.add_child(_wrap("Each Storehouse adds room for more. Upgrading the Town Hall adds some too.", 14))


func _town_hall_panel(body: VBoxContainer) -> void:
	body.add_child(_section("Town Hall  ·  Level %d" % Game.town_level))
	body.add_child(_label("Border: %d tiles  ·  Pets: %d / %d  ·  Nest space: %d  ·  Charm: %d" % [
		int(Game.town_radius()), Game.pets.size(), Game.capacity(), Game.nest_slots(), Game.charm()], 17))
	_storage_rows(body)
	var hungry := Game.pets.filter(func(p): return Game.mood(p) == "hungry").size()
	var per_hour := 0.0
	for p in Game.pets:
		per_hour += 3600.0 * (Data.HUNGER_WORKING if Game.is_working(p) else Data.HUNGER_IDLE) / float(Data.FOOD_FILL["berries"])
	body.add_child(_label("Food: your pets eat about %d berries an hour (fish count for more)." % int(per_hour), 16))
	if hungry > 0:
		body.add_child(_label("%d pet(s) are hungry and working slowly." % hungry, 16, BAD))
	if Game.town_level >= Data.TOWN_LEVELS.size():
		body.add_child(_label("Your town is fully grown!", 18, GOOD))
		return
	var next: Dictionary = Data.TOWN_LEVELS[Game.town_level]
	body.add_child(_section("Upgrade to level %d" % (Game.town_level + 1)))
	var unlocks: Array = []
	for type in Data.BUILD_ORDER:
		if int(Data.BUILDINGS[type].get("th", 1)) == Game.town_level + 1:
			unlocks.append(Data.BUILDINGS[type]["name"])
	var txt := "Border grows to %d tiles, +1 nest space." % int(next["radius"])
	if not unlocks.is_empty():
		txt += " Unlocks: " + ", ".join(unlocks) + "."
	body.add_child(_wrap(txt, 17, TEXT))
	body.add_child(_cost_row(next["cost"], 18))
	var b := _button("Upgrade Town Hall", func(): Game.upgrade_town(); _reopen())
	b.disabled = not Game.can_afford(next["cost"])
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	body.add_child(b)


func _nest_panel(body: VBoxContainer) -> void:
	var here := Game.eggs_at("nest")
	body.add_child(_section("In the Nest  %d / %d" % [here.size(), Game.nest_slots()]))
	for e in here:
		body.add_child(_egg_card(e))
	var bag := Game.eggs_at("bag")
	if not bag.is_empty() and here.size() < Game.nest_slots():
		body.add_child(_section("In your bag"))
		for e in bag:
			body.add_child(_egg_card(e))


func _kiosk_panel(body: VBoxContainer) -> void:
	body.add_child(_label("You have %d glimmer." % int(Game.res["glimmer"]), 17, SUBTLE))
	for egg_type in Data.EGG_ORDER:
		var info: Dictionary = Data.EGGS[egg_type]
		var card := _card()
		var row := _hbox(12)
		var pic = _portrait("egg", Vector2(80, 92))
		pic.egg_type = egg_type
		row.add_child(pic)
		var box := _vbox(2)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(_label(str(info["name"]), 22))
		var hab: Dictionary = Data.HABITATS[info["habitat"]]
		box.add_child(_label("%s eggs  ·  hatches in %ds carried" % [hab["name"], int(info["warmth"])], 15, Color(hab["color"]).darkened(0.2)))
		box.add_child(_pool_text(info))
		row.add_child(box)
		var price := int(info["price"])
		var buy := _button("Buy  %d" % price, func(): if Game.buy_egg(egg_type): _reopen(), 20)
		buy.custom_minimum_size = Vector2(140, 56)
		buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		buy.disabled = int(Game.res["glimmer"]) < price
		row.add_child(buy)
		card.add_child(row)
		body.add_child(card)


func _pool_text(info: Dictionary) -> RichTextLabel:
	var total := 0
	for entry in info["pool"]:
		total += int(entry[1])
	var parts: Array = []
	for entry in info["pool"]:
		var sid := str(entry[0])
		var sp: Dictionary = Data.SPECIES[sid]
		var rcol: String = Data.RARITY[sp["rarity"]]["color"]
		var nm := str(sp["name"]) if Game.discovered.has(sid) else "???"
		parts.append("[color=%s]%s[/color] %d%%" % [rcol, nm, roundi(100.0 * float(entry[1]) / float(total))])
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.add_theme_font_size_override("normal_font_size", 15)
	r.text = "  ·  ".join(parts)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _workshop_panel(body: VBoxContainer) -> void:
	body.add_child(_section("Craft tools"))
	body.add_child(_wrap("A tool decides which job a pet can do. Wooden x1, Stone x1.5, Crystal x2.2 speed.", 16))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	grid.add_child(_label("", 16))
	for tier in Data.TIERS.size():
		grid.add_child(_label(Data.TIERS[tier]["name"], 17, SUBTLE))
	for kind in Data.TOOL_ORDER:
		var h := _hbox(6)
		h.add_child(_tool_icon(kind, 0, 34))
		var lbl := _label("%s\n%s" % [Data.TOOLS[kind]["name"], Data.JOBS[Data.TOOLS[kind]["job"]]["name"]], 15)
		h.add_child(lbl)
		grid.add_child(h)
		for tier in Data.TIERS.size():
			var cell := _vbox(2)
			cell.add_child(_cost_row(Data.TIERS[tier]["cost"], 13))
			var b := _small_button("Craft", func(): Game.craft(kind, tier); _reopen(), Color("#5aa64a"))
			b.disabled = not Game.can_afford(Data.TIERS[tier]["cost"])
			cell.add_child(b)
			grid.add_child(cell)
	body.add_child(grid)
	body.add_child(_section("Your tools"))
	if Game.tools.is_empty():
		body.add_child(_label("None yet.", 16, SUBTLE))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	for t in Game.tools:
		var chip := _card()
		var h2 := _hbox(4)
		h2.add_child(_tool_icon(t["kind"], int(t["tier"]), 28))
		var owner := Game.tool_owner(int(t["id"]))
		h2.add_child(_label(Data.tool_name(t) + ("  (%s)" % Data.SPECIES[owner["species"]]["name"] if not owner.is_empty() else "  (free)"), 14, TEXT if owner.is_empty() else SUBTLE))
		chip.add_child(h2)
		flow.add_child(chip)
	body.add_child(flow)


func _market_panel(body: VBoxContainer) -> void:
	body.add_child(_section("Sell resources"))
	body.add_child(_wrap("The Market buys in lots of 10.", 15))
	for r in Data.RES_ORDER:
		var row := _hbox(10)
		row.add_child(_res_icon(r, 30))
		var l := _label("%s  ·  you have %d  ·  %d glimmer per 10" % [Data.RESOURCES[r]["name"], int(Game.res[r]), int(Data.RESOURCES[r]["sell10"])], 17)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var s10 := _small_button("Sell 10", func(): Game.sell(r, 10); _reopen())
		s10.disabled = int(Game.res[r]) < 10
		row.add_child(s10)
		var sall := _small_button("Sell half", func(): Game.sell(r, int(Game.res[r]) / 2); _reopen())
		sall.disabled = int(Game.res[r]) < 20
		row.add_child(sall)
		body.add_child(row)


# ---------------------------------------------------------------- pets

func _pet_status(p: Dictionary) -> String:
	var job := Game.pet_job(p)
	var b := Game.find_building(int(p["work"]))
	if job == "":
		return "Idle. Needs a tool to work"
	if b.is_empty():
		return "Idle. Has a %s" % Data.TOOLS[Game.pet_tool(p)["kind"]]["name"]
	if b["type"] == "builder_hut" and Game.construction_target().is_empty():
		return "Builder. Waiting for something to build"
	if str(p.get("waiting", "")) == "full":
		return "Waiting: %s store is full" % Data.RESOURCES[Data.BUILDINGS[b["type"]]["res"]]["name"].to_lower()
	return "%s at %s" % [Data.JOBS[job]["verb"], Data.BUILDINGS[b["type"]]["name"]]


const MOOD_TEXT := {"happy": "Happy", "okay": "Peckish", "hungry": "Hungry"}
const MOOD_COL := {"happy": Color("#3f8f4f"), "okay": Color("#c27c2c"), "hungry": Color("#c2413e")}


func _mood_label(p: Dictionary, size: int = 14) -> Label:
	var m := Game.mood(p)
	var pct := int(round((float(Data.MOOD_SPEED[m]) - 1.0) * 100.0))
	var txt: String = MOOD_TEXT[m]
	if pct != 0:
		txt += "  (%s%d%% speed)" % ["+" if pct > 0 else "", pct]
	return _label(txt, size, MOOD_COL[m])


func open_pets() -> void:
	var vb := _open_window("Pets", 980, 640, true, "pets")
	var tabs := _hbox(8)
	var b1 := _button("My Pets (%d/%d)" % [Game.pets.size(), Game.capacity()], func(): _pets_tab = "mine"; open_pets(), 18)
	var b2 := _button("Pet Log %d / %d" % [Game.discovered.size(), Data.SPECIES_ORDER.size()], func(): _pets_tab = "log"; open_pets(), 18)
	for pair in [[b1, "mine"], [b2, "log"]]:
		var btn: Button = pair[0]
		if _pets_tab == pair[1]:
			btn.disabled = true
			var sel := _sb(Color("#4a3a32"), 14, 0, Color.TRANSPARENT, 8)
			sel.content_margin_left = 16
			sel.content_margin_right = 16
			btn.add_theme_stylebox_override("disabled", sel)
			btn.add_theme_color_override("font_disabled_color", Color.WHITE)
		tabs.add_child(btn)
	vb.add_child(tabs)
	var body := _scroll(vb)
	var grid := GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	body.add_child(grid)
	if _pets_tab == "mine":
		grid.columns = clampi(int((minf(980.0, root.size.x - 16.0) - 40.0) / 200.0), 2, 4)
		if Game.pets.is_empty():
			body.add_child(_label("No pets yet. Carry your egg until it hatches!", 18, SUBTLE))
		for p in Game.pets:
			grid.add_child(_pet_card(p))
	else:
		grid.columns = clampi(int((minf(980.0, root.size.x - 16.0) - 40.0) / 165.0), 3, 5)
		for sid in Data.SPECIES_ORDER:
			grid.add_child(_log_card(sid))


func _pet_card(p: Dictionary) -> Control:
	var card := _card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := _vbox(3)
	v.add_child(_pet_pic(p, Vector2(150, 100)))
	var nm := _label(Game.pet_name(p), 17)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nm)
	var st := _label("Lv %d  ·  %s  ·  %s" % [int(p["level"]), Data.stage_name(int(p["level"])), MOOD_TEXT[Game.mood(p)]], 14, MOOD_COL[Game.mood(p)] if Game.mood(p) != "happy" else SUBTLE)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(st)
	var job_row := _hbox(4)
	job_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var tool := Game.pet_tool(p)
	if not tool.is_empty():
		job_row.add_child(_tool_icon(tool["kind"], int(tool["tier"]), 22))
	var status := _label(_pet_status(p), 13, GOOD if int(p["work"]) != -1 else SUBTLE)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(150, 0)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	job_row.add_child(status)
	v.add_child(job_row)
	var pid := int(p["id"])
	v.add_child(_small_button("Details", func(): open_pet(pid), Color("#7a9cc6")))
	card.add_child(v)
	return card


func _log_card(sid: String) -> Control:
	var card := _card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := _vbox(2)
	var known := Game.discovered.has(sid)
	var pic = _portrait("pet", Vector2(120, 90))
	pic.species = sid
	pic.silhouette = not known
	v.add_child(pic)
	var sp: Dictionary = Data.SPECIES[sid]
	var nm := _label(str(sp["name"]) if known else "???", 16)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nm)
	var rar: Dictionary = Data.RARITY[sp["rarity"]]
	var egg_name := ""
	for et in Data.EGG_ORDER:
		for entry in Data.EGGS[et]["pool"]:
			if str(entry[0]) == sid and egg_name == "":
				egg_name = str(Data.EGGS[et]["name"])
	var rl := _label("%s · %s" % [rar["name"], egg_name], 13, Color(rar["color"]))
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(rl)
	if known:
		var tl: Array = []
		for j in sp["talents"]:
			tl.append(Data.JOBS[j]["name"])
		var tal := _label("Talent: " + ", ".join(tl), 12, GOOD)
		tal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(tal)
	card.add_child(v)
	return card


func open_pet(pid: int) -> void:
	var p := Game.find_pet(pid)
	if p.is_empty():
		close_modal()
		return
	var vb := _open_window(Game.pet_name(p), 940, 640, true, "pet", pid)
	var cols := _hbox(16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(cols)

	# left: portrait, level, feeding
	var left := _vbox(6)
	left.custom_minimum_size = Vector2(230 if compact else 260, 0)
	left.add_child(_pet_pic(p, Vector2(230, 110) if compact else Vector2(260, 190)))
	var sp: Dictionary = Data.SPECIES[p["species"]]
	var rar: Dictionary = Data.RARITY[sp["rarity"]]
	left.add_child(_label("%s  ·  %s" % [rar["name"], "Mythical" if bool(sp["mythic"]) else "Real animal"], 16, Color(rar["color"])))
	var lvl := int(p["level"])
	left.add_child(_label("Level %d  ·  %s" % [lvl, Data.stage_name(lvl)], 20))
	var xb := _bar(Color("#7ed492"), 250, 14)
	xb.max_value = 1 if lvl >= Data.MAX_LEVEL else Data.xp_needed(lvl)
	xb.value = 1 if lvl >= Data.MAX_LEVEL else int(p["xp"])
	left.add_child(xb)
	left.add_child(_label("Fully grown!" if lvl >= Data.MAX_LEVEL else "%d / %d xp" % [int(p["xp"]), Data.xp_needed(lvl)], 14, SUBTLE))
	var food_row := _hbox(8)
	food_row.add_child(_label("Food", 15))
	var food_bar := _bar(Color("#ffb347"), 150, 12)
	food_bar.max_value = 1.0
	food_bar.step = 0.01
	food_bar.value = float(p.get("food", 1.0))
	food_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	food_row.add_child(food_bar)
	left.add_child(food_row)
	left.add_child(_mood_label(p, 14))
	left.add_child(_label("Feed a treat", 17))
	var feed := _hbox(6)
	for food in ["berries", "fish"]:
		var fb := _small_button("%s (%d)  +%dxp" % [Data.RESOURCES[food]["name"], int(Game.res[food]), int(Data.FOOD_XP[food])],
			func(): Game.feed(pid, food); _reopen(), Color("#9a6bff") if food == "berries" else Color("#3fa9d6"))
		fb.disabled = int(Game.res[food]) <= 0 or lvl >= Data.MAX_LEVEL
		feed.add_child(fb)
	left.add_child(feed)
	cols.add_child(left)

	# right: job, tool, skills
	var right := _scroll(cols)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(_section("Job"))
	right.add_child(_label(_pet_status(p), 17, GOOD if int(p["work"]) != -1 else SUBTLE))
	var job := Game.pet_job(p)
	var job_row := _hbox(8)
	if job != "":
		if int(p["work"]) == -1:
			var best := Game.best_workplace(p)
			if best.is_empty():
				job_row.add_child(_wrap("No free %s. Build one!" % _job_building_names(job), 16, BAD))
			else:
				var bid := int(best["id"])
				var send := func() -> void:
					var err := Game.assign(pid, bid)
					if err != "":
						toast(err)
					_reopen()
				job_row.add_child(_small_button("Send to %s" % Data.BUILDINGS[best["type"]]["name"], send, Color("#5aa64a")))
		else:
			job_row.add_child(_small_button("Stop working", func(): Game.unassign(pid); _reopen(), Color("#a39486")))
			var wb := int(p["work"])
			job_row.add_child(_small_button("Go to workplace", func(): open_building(wb), Color("#7a9cc6")))
	right.add_child(job_row)

	right.add_child(_section("Tool"))
	var tool := Game.pet_tool(p)
	var trow := _hbox(8)
	if tool.is_empty():
		trow.add_child(_label("No tool", 17, SUBTLE))
	else:
		trow.add_child(_tool_icon(tool["kind"], int(tool["tier"]), 34))
		trow.add_child(_label("%s  (x%.1f speed)" % [Data.tool_name(tool), float(Data.TIERS[int(tool["tier"])]["mult"])], 17))
		trow.add_child(_small_button("Take back", func(): Game.take_tool(pid); _reopen(), Color("#a39486")))
	right.add_child(trow)
	var spare := Game.free_tools()
	if not spare.is_empty():
		right.add_child(_label("Give a different tool:", 15, SUBTLE))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		var seen := {}
		for t in spare:
			var key := "%s%d" % [t["kind"], int(t["tier"])]
			if seen.has(key):
				continue
			seen[key] = true
			var tid := int(t["id"])
			var tj: String = Data.TOOLS[t["kind"]]["job"]
			var label := Data.tool_name(t) + ("  *" if Game.has_talent(p, tj) else "")
			var tb := _small_button(label, func(): Game.give_tool(pid, tid); _reopen(), Color("#e0a676"))
			flow.add_child(tb)
		right.add_child(flow)
		right.add_child(_label("* = this pet has a talent for that job", 13, SUBTLE))
	elif tool.is_empty():
		right.add_child(_wrap("No spare tools. Craft one at the Workshop.", 15, SUBTLE))

	right.add_child(_section("Skills  (max = pet level %d)" % lvl))
	for j in Data.JOB_ORDER:
		var sk := Game.skill(p, j)
		var row := _hbox(8)
		var talent := Game.has_talent(p, j)
		var nl := _label(Data.JOBS[j]["name"] + ("  Talent" if talent else ""), 16, GOOD if talent else TEXT)
		nl.custom_minimum_size = Vector2(190, 0)
		row.add_child(nl)
		row.add_child(_label("Lv %d" % int(sk["lvl"]), 16))
		var sb := _bar(Color("#7a9cc6"), 160, 12)
		sb.max_value = Data.skill_xp_needed(int(sk["lvl"]))
		sb.value = float(sk["xp"])
		sb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sb)
		if int(sk["lvl"]) >= lvl and float(sk["xp"]) >= Data.skill_xp_needed(int(sk["lvl"])) - 0.01:
			row.add_child(_label("capped, level up!", 13, BAD))
		else:
			row.add_child(_label("x%.2f" % Data.skill_mult(int(sk["lvl"])), 13, SUBTLE))
		right.add_child(row)
	right.add_child(_wrap("Skills rise while a pet works that job, up to its level. Level up by working or by feeding treats.", 14))


# ---------------------------------------------------------------- eggs

func _egg_card(e: Dictionary) -> Control:
	var card := _card()
	var row := _hbox(12)
	var pic = _portrait("egg", Vector2(70, 80))
	pic.egg_type = str(e["type"])
	pic.warmth = Game.egg_ratio(e)
	row.add_child(pic)
	var info := _vbox(3)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	var need := float(Data.EGGS[e["type"]]["warmth"])
	var where := {"carry": "Carried (full speed)", "nest": "In the Nest (half speed)", "bag": "In your bag (not warming)"}
	info.add_child(_label("%s  ·  %s" % [Data.EGGS[e["type"]]["name"], where[e["loc"]]], 19))
	var bar := _bar(Color("#ffb347"), 240, 12)
	bar.max_value = need
	bar.value = float(e["warmth"])
	info.add_child(bar)
	info.add_child(_label("Ready! Needs room in town" if bool(e.get("waiting", false)) else "%d / %d warmth" % [int(e["warmth"]), int(need)], 14, SUBTLE))
	row.add_child(info)
	var eid := int(e["id"])
	if e["loc"] != "carry":
		row.add_child(_small_button("Carry", func(): Game.move_egg(eid, "carry"); _reopen(), Color("#5aa64a")))
	if e["loc"] != "nest":
		var nb := _small_button("To Nest", func(): Game.move_egg(eid, "nest"); _reopen(), Color("#e0a676"))
		nb.disabled = Game.eggs_at("nest").size() >= Game.nest_slots()
		row.add_child(nb)
	card.add_child(row)
	return card


func open_eggs() -> void:
	var vb := _open_window("Eggs", 820, 600, true, "eggs")
	vb.add_child(_wrap("Your carried egg warms fastest. The Nest warms %d egg(s) at half speed, even while you're away. Gathering by hand adds a little warmth too." % Game.nest_slots(), 16))
	var body := _scroll(vb)
	if Game.eggs.is_empty():
		body.add_child(_label("No eggs right now. Buy one at the Egg Kiosk, or send explorers out to find some!", 17))
	for loc in ["carry", "nest", "bag"]:
		for e in Game.eggs_at(loc):
			body.add_child(_egg_card(e))


# ---------------------------------------------------------------- settings

func _toggle_row(body: VBoxContainer, label: String, note: String, key: String) -> void:
	var row := _hbox(10)
	var v := _vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_label(label, 18))
	if note != "":
		v.add_child(_wrap(note, 14))
	row.add_child(v)
	var on := bool(Game.settings.get(key, false))
	var b := _small_button("On" if on else "Off", func(): Game.set_setting(key, not on); open_settings(), Color("#5aa64a") if on else Color("#a39486"))
	b.custom_minimum_size = Vector2(78, 44)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(b)
	body.add_child(row)


func open_settings() -> void:
	var vb := _open_window("Settings", 720, 600, true, "settings")
	var body := _scroll(vb)
	body.add_child(_section("Graphics"))
	_toggle_row(body, "Visual effects", "Edge blur, sunlight and vignette. Turn off if the game feels slow.", "effects")
	_toggle_row(body, "Butterflies and pollen", "", "ambient")
	_toggle_row(body, "Show frame rate", "A counter under the menu buttons, for testing.", "show_fps")
	var size_row := _hbox(8)
	var sl := _label("Button size", 18)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_row.add_child(sl)
	for pair in [["Smaller", "small"], ["Auto", "auto"], ["Larger", "large"]]:
		var key: String = pair[1]
		var cur: bool = Game.settings.get("ui_size", "auto") == key
		var b := _small_button(pair[0], func(): Game.set_setting("ui_size", key), Color("#5aa64a") if cur else Color("#a39486"))
		b.custom_minimum_size = Vector2(0, 44)
		size_row.add_child(b)
	body.add_child(size_row)
	body.add_child(_section("Help"))
	var hb := _hbox(8)
	var help := _small_button("How to play", open_help, Color("#7a9cc6"))
	help.custom_minimum_size = Vector2(0, 44)
	hb.add_child(help)
	if Data.FEEDBACK_URL != "":
		var fb := _small_button("Send feedback", func(): OS.shell_open(Data.FEEDBACK_URL), Color("#7a9cc6"))
		fb.custom_minimum_size = Vector2(0, 44)
		hb.add_child(fb)
	body.add_child(hb)
	body.add_child(_section("Your town"))
	var txt := "Tap again to delete your town" if _confirm_demolish == -99 else "Start a new town"
	var reset := _small_button(txt, _reset_town, Color("#c96a5a"))
	reset.custom_minimum_size = Vector2(0, 44)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	body.add_child(reset)
	body.add_child(_label(Game.version_text(), 13, SUBTLE))


func _reset_town() -> void:
	if _confirm_demolish != -99:
		_confirm_demolish = -99
		open_settings()
		return
	_confirm_demolish = -1
	close_modal()
	Game.reset_save()
	main.reset_view()
	open_help.call_deferred()


func _show_migration() -> void:
	if modal:
		return
	var vb := _open_window("Welcome to the new Driftnest", 600, 360, false, "welcome")
	vb.add_child(_wrap(Game.migration_note, 18, TEXT))
	var ok := _button("Let's see!", close_modal, 22)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(ok)
	Game.migration_note = ""


# ---------------------------------------------------------------- help

func open_help() -> void:
	var vb := _open_window("Welcome to Driftnest", 820, 620, true, "help")
	var body := _scroll(vb)
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_font_size_override("normal_font_size", 18)
	r.add_theme_font_size_override("bold_font_size", 18)
	r.text = """You're the new [b]Keeper[/b] of a little town in the meadows. There's an egg on your back, and another warming in the Nest.

[b]Hatch pets.[/b] Your carried egg warms up over time. When it hatches, the pet moves into town.

[b]Give them jobs.[/b] Tap a pet, give it a [b]tool[/b], and send it to work:
 •  [b]Axe[/b]: Lumber Camp (wood)
 •  [b]Basket[/b]: Berry Farm (berries)
 •  [b]Pickaxe[/b]: Quarry (stone) or Crystal Mine (crystal)
 •  [b]Fishing Rod[/b]: Fishing Dock (fish)
 •  [b]Hammer[/b]: Builder's Hut (builds everything you place)
 •  [b]Compass[/b]: Explorer's Lodge (glimmer, supplies and eggs)

[b]Talents.[/b] Every species is naturally good at one or two jobs (+50%). Check the Pet Log.

[b]Level up.[/b] Pets gain levels by working or by eating berries and fish. A pet's level is the cap for its job skills, and skills rise as it works. Higher skill means faster work, and better tools (Stone, Crystal) from the Workshop help too.

[b]Grow the town.[/b] Place buildings from the [b]Build[/b] menu. Houses make room for more pets. Upgrade the [b]Town Hall[/b] to push the border out towards the lake and the crystal hills. Decorations add [b]charm[/b], which boosts everything.

[b]You can help.[/b] Walk up to trees, rocks, bushes or water and hold the action button to gather by hand, or help build. Each one runs out after a few pickings and grows back after a few minutes, faster near a Planted Tree.

[b]Food and storage.[/b] Pets eat berries and fish from your stores by themselves. Well-fed pets work faster, hungry ones slow down. Decorations near a workplace cheer its workers up too. Each resource has a storage limit: when a store is full, its workers pause, so build a Storehouse or sell extras at the Market.

Pets keep working while the game is closed (up to 8 hours).

Move with [b]WASD / arrow keys[/b] or the stick. Tap pets and buildings to manage them. Zoom with +/-, the mouse wheel or a pinch."""
	body.add_child(r)
	var go := _button("Let's go!", close_modal, 22)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.custom_minimum_size = Vector2(220, 52)
	vb.add_child(go)


# ---------------------------------------------------------------- events

func _on_goal_done(index: int) -> void:
	var g: Dictionary = Data.GOALS[index]
	toast("Goal complete! +" + Data.cost_text(g["reward"]))


func _on_hatched(pet: Dictionary, is_new: bool) -> void:
	if modal:
		_hatch_queue.append([pet, is_new])
	else:
		_show_hatch.call_deferred(pet, is_new)


func _show_hatch(pet: Dictionary, is_new: bool) -> void:
	if modal:
		_hatch_queue.append([pet, is_new])
		return
	var vb := _open_window("It hatched!", 580, 560, false, "hatch")
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	var pic := _pet_pic(pet, Vector2(300, 220))
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(pic)
	var sp: Dictionary = Data.SPECIES[pet["species"]]
	var nm := _label(Game.pet_name(pet), 32)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(nm)
	var rar: Dictionary = Data.RARITY[sp["rarity"]]
	var kind := "Mythical creature" if bool(sp["mythic"]) else "Real-world animal"
	var rl := _label("%s  ·  %s" % [rar["name"], kind], 17, Color(rar["color"]))
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(rl)
	var tl: Array = []
	for j in sp["talents"]:
		tl.append(Data.JOBS[j]["name"])
	var tal := _label("Talent: " + ", ".join(tl), 19, GOOD)
	tal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tal)
	if is_new:
		var nl := _label("New Pet Log entry!", 18, Color("#c2416e"))
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(nl)
	var row := _hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var pid := int(pet["id"])
	row.add_child(_button("Wonderful!", close_modal, 22))
	row.add_child(_button("Give it a job", func(): close_modal(); open_pet(pid), 22))
	vb.add_child(row)


func _on_welcome_back(rep: Dictionary) -> void:
	Game.offline_report = rep
	for h in Game.take_pending_hatches():
		_hatch_queue.append(h)
	if not modal:
		_show_welcome()


func _show_welcome() -> void:
	var rep := Game.offline_report
	if rep.is_empty() or float(rep.get("seconds", 0)) < 60.0:
		return
	var vb := _open_window("Welcome back!", 560, 440, false, "welcome")
	var mins := int(float(rep["seconds"]) / 60.0)
	var away := "%dh %dm" % [mins / 60, mins % 60] if mins >= 60 else "%d minutes" % mins
	vb.add_child(_label("You were away for %s. Your pets kept busy:" % away, 18))
	var gains: Dictionary = rep["gains"]
	if gains.is_empty():
		vb.add_child(_label("Nothing gathered. Give your pets jobs before you go!", 17, SUBTLE))
	for r in ["glimmer"] + Data.RES_ORDER:
		if gains.has(r):
			var row := _hbox(8)
			row.add_child(_res_icon(r, 28))
			row.add_child(_label("+%d %s" % [int(gains[r]), Data.RESOURCES[r]["name"]], 20, GOOD))
			vb.add_child(row)
	if int(rep.get("built", 0)) > 0:
		vb.add_child(_label("%d building(s) finished." % int(rep["built"]), 18))
	if int(rep.get("hatched", 0)) > 0:
		vb.add_child(_label("%d egg(s) hatched!" % int(rep["hatched"]), 18, Color("#c2416e")))
	var ok := _button("Great!", close_modal, 22)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(ok)
	Game.offline_report = {}
