class_name GameHud
extends CanvasLayer
## Screen UI: status cards, buttons, joystick, toasts and the modal windows
## (Egg Kiosk, Pets/Bestiary, Eggs, Help, hatch reveal). Built entirely in code.

const PortraitScript := preload("res://scripts/portrait.gd")
const JoystickScript := preload("res://scripts/joystick.gd")

const TEXT := Color("#4a3a32")
const SUBTLE := Color("#8a7668")

var main = null
var root: Control
var joystick
var theme_res: Theme

var glimmer_label: Label
var comp_portrait
var comp_name: Label
var comp_bar: ProgressBar
var comp_info: Label
var egg_portrait
var egg_name: Label
var egg_bar: ProgressBar
var egg_info: Label
var egg_panel: PanelContainer

var action_btn: Button
var _action_cb: Callable
var _action_text := ""

var toast_panel: PanelContainer
var toast_label: Label
var _toast_tween: Tween

var modal: Control = null
var _pets_tab := "mine"
var _hatch_queue: Array = []


func _ready() -> void:
	layer = 5
	theme_res = _build_theme()
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme_res
	add_child(root)

	_build_status()
	_build_menu_buttons()
	_build_action()
	_build_joystick()
	_build_toast()

	Game.changed.connect(refresh)
	Game.toast.connect(toast)
	Game.hatched.connect(_on_hatched)
	Game.leveled.connect(_on_leveled)
	refresh()
	if Game.first_run:
		open_help.call_deferred()


func is_modal_open() -> bool:
	return modal != null


# ================================================================ theme

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

	var normal := _sb(Color("#ff8a65"), 14, 0, Color.TRANSPARENT, 10)
	normal.border_width_bottom = 4
	normal.border_color = Color("#d9603e")
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#ff9f7f")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#ec7350")
	pressed.border_width_bottom = 1
	pressed.content_margin_top = 13
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
	var s := _sb(Color(1.0, 0.98, 0.94, 0.94), 18, 3, Color("#e8c9a0"), 10)
	s.shadow_color = Color(0, 0, 0, 0.12)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	return s


func _label(text: String, size: int = 20, col: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
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


func _button(text: String, cb: Callable, font_size: int = 20) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_NONE
	return b


# ================================================================ status cards

func _build_status() -> void:
	var col := VBoxContainer.new()
	col.position = Vector2(16, 16)
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(col)

	# glimmer
	var gp := PanelContainer.new()
	gp.add_theme_stylebox_override("panel", _card_style())
	gp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gh := HBoxContainer.new()
	gh.add_theme_constant_override("separation", 8)
	gh.add_child(_portrait("gem", Vector2(30, 30)))
	glimmer_label = _label("0", 24)
	gh.add_child(glimmer_label)
	gh.add_child(_label("glimmer", 16, SUBTLE))
	gp.add_child(gh)
	gp.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(gp)

	# companion
	var cp := PanelContainer.new()
	cp.add_theme_stylebox_override("panel", _card_style())
	cp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 10)
	comp_portrait = _portrait("pet", Vector2(76, 76))
	ch.add_child(comp_portrait)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 4)
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.custom_minimum_size = Vector2(210, 0)
	comp_name = _label("", 19)
	comp_bar = _bar(Color("#7ed492"))
	comp_info = _label("", 15, SUBTLE)
	cv.add_child(comp_name)
	cv.add_child(comp_bar)
	cv.add_child(comp_info)
	ch.add_child(cv)
	cp.add_child(ch)
	col.add_child(cp)

	# carried egg
	egg_panel = PanelContainer.new()
	egg_panel.add_theme_stylebox_override("panel", _card_style())
	egg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var eh := HBoxContainer.new()
	eh.add_theme_constant_override("separation", 10)
	egg_portrait = _portrait("egg", Vector2(60, 66))
	eh.add_child(egg_portrait)
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 4)
	ev.alignment = BoxContainer.ALIGNMENT_CENTER
	ev.custom_minimum_size = Vector2(210, 0)
	egg_name = _label("", 19)
	egg_bar = _bar(Color("#ffb347"))
	egg_info = _label("", 15, SUBTLE)
	ev.add_child(egg_name)
	ev.add_child(egg_bar)
	ev.add_child(egg_info)
	eh.add_child(ev)
	egg_panel.add_child(eh)
	col.add_child(egg_panel)


func _build_menu_buttons() -> void:
	var box := VBoxContainer.new()
	box.anchor_left = 1.0
	box.anchor_right = 1.0
	box.offset_left = -150
	box.offset_right = -16
	box.offset_top = 16
	box.offset_bottom = 260
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	box.add_child(_button("Pets", open_pets, 22))
	box.add_child(_button("Eggs", open_eggs, 22))
	box.add_child(_button("Help", open_help, 22))


func _build_action() -> void:
	action_btn = _button("", _on_action, 26)
	action_btn.anchor_left = 1.0
	action_btn.anchor_right = 1.0
	action_btn.anchor_top = 1.0
	action_btn.anchor_bottom = 1.0
	action_btn.offset_left = -320
	action_btn.offset_right = -24
	action_btn.offset_top = -104
	action_btn.offset_bottom = -28
	action_btn.visible = false
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


func _build_toast() -> void:
	toast_panel = PanelContainer.new()
	toast_panel.anchor_left = 0.5
	toast_panel.anchor_right = 0.5
	toast_panel.offset_left = -300
	toast_panel.offset_right = 300
	toast_panel.offset_top = 16
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := _sb(Color(0.23, 0.17, 0.15, 0.88), 18, 0, Color.TRANSPARENT, 12)
	toast_panel.add_theme_stylebox_override("panel", s)
	toast_label = _label("", 20, Color.WHITE)
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
	_toast_tween.tween_interval(2.6)
	_toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.5)


func refresh() -> void:
	glimmer_label.text = str(Game.glimmer)
	var p := Game.get_companion()
	if p.is_empty():
		comp_portrait.species = ""
		comp_name.text = "No companion yet"
		comp_bar.visible = false
		comp_info.text = "Warm your egg to hatch one!"
	else:
		var lvl := int(p["level"])
		comp_portrait.species = str(p["species"])
		comp_portrait.level = lvl
		comp_portrait.prism = bool(p["prism"])
		comp_name.text = "%s  ·  %s" % [Game.pet_display_name(p), Data.stage_name(lvl)]
		comp_bar.visible = true
		if lvl >= Data.MAX_LEVEL:
			comp_bar.max_value = 1
			comp_bar.value = 1
			comp_info.text = "Fully grown!  Wishes: %s" % Data.JOBS[str(p["wish"])]["short"]
		else:
			comp_bar.max_value = Data.xp_needed(lvl)
			comp_bar.value = int(p["xp"])
			comp_info.text = "Lv %d  ·  Wishes for: %s" % [lvl, Data.JOBS[str(p["wish"])]["short"]]
	var e := Game.get_carried_egg()
	if e.is_empty():
		egg_portrait.egg_type = ""
		egg_name.text = "No egg carried"
		egg_bar.visible = false
		egg_info.text = "Buy one at the Egg Kiosk" if Game.eggs.is_empty() else "Pick one in Eggs"
	else:
		var need := int(Data.EGGS[str(e["type"])]["warmth"])
		egg_portrait.egg_type = str(e["type"])
		egg_portrait.warmth = Game.egg_ratio(e)
		egg_name.text = str(Data.EGGS[str(e["type"])]["name"])
		egg_bar.visible = true
		egg_bar.max_value = need
		egg_bar.value = int(e["warmth"])
		egg_info.text = "Warmth %d / %d" % [int(e["warmth"]), need]


# ================================================================ context action

func show_action(text: String, cb: Callable) -> void:
	_action_cb = cb
	if _action_text != text or not action_btn.visible:
		_action_text = text
		action_btn.text = text
		action_btn.visible = true


func hide_action() -> void:
	if action_btn.visible:
		action_btn.visible = false
		_action_text = ""


func _on_action() -> void:
	if _action_cb.is_valid():
		_action_cb.call()


# ================================================================ modal windows

func close_modal() -> void:
	if modal:
		modal.queue_free()
		modal = null
	joystick.enabled = true
	if not _hatch_queue.is_empty():
		var next: Array = _hatch_queue.pop_front()
		_show_hatch.call_deferred(next[0], next[1])


func _open_window(title: String, w: float, h: float, closable: bool = true) -> VBoxContainer:
	if modal:
		modal.queue_free()
		modal = null
	joystick.release()
	joystick.enabled = false
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
	var vp := root.get_viewport_rect().size
	panel.custom_minimum_size = Vector2(minf(w, vp.x - 32.0), minf(h, vp.y - 32.0))
	cc.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	var header := HBoxContainer.new()
	var tl := _label(title, 30)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(tl)
	if closable:
		header.add_child(_button("Close", close_modal))
	vb.add_child(header)
	return vb


func _scroll(parent: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(sc)
	return sc


func _card() -> PanelContainer:
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", _sb(Color("#fffdf8"), 16, 2, Color("#efd9bb"), 10))
	return c


# ---------------------------------------------------------------- Egg Kiosk

func open_shop() -> void:
	var vb := _open_window("Egg Kiosk", 860, 600)
	vb.add_child(_label("You have %d glimmer. Each egg hatches a random creature from its pool." % Game.glimmer, 17, SUBTLE))
	var sc := _scroll(vb)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	sc.add_child(list)
	for egg_type in Data.EGG_ORDER:
		var info: Dictionary = Data.EGGS[egg_type]
		var card := _card()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var pic = _portrait("egg", Vector2(96, 110))
		pic.egg_type = egg_type
		row.add_child(pic)
		var info_box := VBoxContainer.new()
		info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_box.add_theme_constant_override("separation", 2)
		info_box.add_child(_label(str(info["name"]), 24))
		var hab: Dictionary = Data.HABITATS[str(info["habitat"])]
		info_box.add_child(_label("%s habitat  ·  needs %d warmth" % [hab["name"], int(info["warmth"])], 16, Color(str(hab["color"])).darkened(0.2)))
		info_box.add_child(_pool_text(info))
		row.add_child(info_box)
		var price := int(info["price"])
		var buy := _button("Buy  %d" % price, func(): _buy(egg_type), 22)
		buy.custom_minimum_size = Vector2(150, 60)
		buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		buy.disabled = Game.glimmer < price
		row.add_child(buy)
		card.add_child(row)
		list.add_child(card)


func _pool_text(info: Dictionary) -> RichTextLabel:
	var total := 0
	for entry in info["pool"]:
		total += int(entry[1])
	var parts: Array = []
	for entry in info["pool"]:
		var sid := str(entry[0])
		var sp: Dictionary = Data.SPECIES[sid]
		var rcol: String = Data.RARITY[str(sp["rarity"])]["color"]
		var nm := str(sp["name"]) if Game.discovered.has(sid) else "???"
		parts.append("[color=%s]%s[/color] %d%%" % [rcol, nm, roundi(100.0 * float(entry[1]) / float(total))])
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.add_theme_font_size_override("normal_font_size", 16)
	r.text = "  ·  ".join(parts)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _buy(egg_type: String) -> void:
	if Game.buy_egg(egg_type):
		open_shop()


# ---------------------------------------------------------------- Pets & Bestiary

func open_pets() -> void:
	var vb := _open_window("Pets", 900, 620)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	var b1 := _button("My Pets (%d)" % Game.pets.size(), func(): _pets_tab = "mine"; open_pets(), 18)
	var b2 := _button("Bestiary %d / %d" % [Game.discovered.size(), Data.SPECIES_ORDER.size()], func(): _pets_tab = "dex"; open_pets(), 18)
	b1.disabled = _pets_tab == "mine"
	b2.disabled = _pets_tab == "dex"
	for b in [b1, b2]:
		var sel := _sb(Color("#4a3a32"), 14, 0, Color.TRANSPARENT, 10)
		sel.content_margin_left = 18
		sel.content_margin_right = 18
		b.add_theme_stylebox_override("disabled", sel)
		b.add_theme_color_override("font_disabled_color", Color.WHITE)
	tabs.add_child(b1)
	tabs.add_child(b2)
	vb.add_child(tabs)
	var sc := _scroll(vb)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	sc.add_child(grid)
	if _pets_tab == "mine":
		if Game.pets.is_empty():
			vb.add_child(_label("No pets yet — keep doing chores to hatch your egg!", 18, SUBTLE))
		for p in Game.pets:
			grid.add_child(_pet_card(p))
	else:
		grid.columns = 5
		for sid in Data.SPECIES_ORDER:
			grid.add_child(_dex_card(sid))


func _pet_card(p: Dictionary) -> Control:
	var card := _card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	var pic = _portrait("pet", Vector2(160, 120))
	pic.species = str(p["species"])
	pic.level = int(p["level"])
	pic.prism = bool(p["prism"])
	v.add_child(pic)
	var sp: Dictionary = Data.SPECIES[str(p["species"])]
	var nm := _label(Game.pet_display_name(p), 18)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nm)
	var rar: Dictionary = Data.RARITY[str(sp["rarity"])]
	var rl := _label("%s%s" % [rar["name"], "  ·  Mythical" if bool(sp["mythic"]) else ""], 14, Color(str(rar["color"])))
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(rl)
	var lvl := int(p["level"])
	var st := _label("Lv %d  ·  %s" % [lvl, Data.stage_name(lvl)], 15, SUBTLE)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(st)
	var bar := _bar(Color("#7ed492"), 140, 10)
	bar.max_value = 1 if lvl >= Data.MAX_LEVEL else Data.xp_needed(lvl)
	bar.value = 1 if lvl >= Data.MAX_LEVEL else int(p["xp"])
	v.add_child(bar)
	var pid := int(p["id"])
	var following := pid == Game.companion
	var b := _button("Following" if following else "Follow me", func(): Game.set_companion(pid); open_pets(), 17)
	b.disabled = following
	v.add_child(b)
	card.add_child(v)
	return card


func _dex_card(sid: String) -> Control:
	var card := _card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	var known := Game.discovered.has(sid)
	var pic = _portrait("pet", Vector2(120, 96))
	pic.species = sid
	pic.silhouette = not known
	v.add_child(pic)
	var sp: Dictionary = Data.SPECIES[sid]
	var nm := _label(str(sp["name"]) if known else "???", 16)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nm)
	var rar: Dictionary = Data.RARITY[str(sp["rarity"])]
	var egg_name := ""
	for et in Data.EGG_ORDER:
		for entry in Data.EGGS[et]["pool"]:
			if str(entry[0]) == sid and egg_name == "":
				egg_name = str(Data.EGGS[et]["name"])
	var rl := _label("%s · %s" % [rar["name"], egg_name], 13, Color(str(rar["color"])))
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(rl)
	card.add_child(v)
	return card


# ---------------------------------------------------------------- Eggs

func open_eggs() -> void:
	var vb := _open_window("Eggs", 760, 560)
	vb.add_child(_label("The egg you carry gets warmer with every chore you finish.", 17, SUBTLE))
	var sc := _scroll(vb)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	sc.add_child(list)
	if Game.eggs.is_empty():
		list.add_child(_label("No eggs right now. Visit the Egg Kiosk to buy one!", 18))
	for e in Game.eggs:
		var card := _card()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var pic = _portrait("egg", Vector2(80, 90))
		pic.egg_type = str(e["type"])
		pic.warmth = Game.egg_ratio(e)
		row.add_child(pic)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		var need := int(Data.EGGS[str(e["type"])]["warmth"])
		info.add_child(_label(str(Data.EGGS[str(e["type"])]["name"]), 22))
		var bar := _bar(Color("#ffb347"), 260, 14)
		bar.max_value = need
		bar.value = int(e["warmth"])
		info.add_child(bar)
		info.add_child(_label("Warmth %d / %d" % [int(e["warmth"]), need], 15, SUBTLE))
		row.add_child(info)
		var eid := int(e["id"])
		var carrying := eid == Game.carried_egg
		var b := _button("Carrying" if carrying else "Carry", func(): Game.carry_egg(eid); open_eggs(), 20)
		b.disabled = carrying
		b.custom_minimum_size = Vector2(140, 56)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
		card.add_child(row)
		list.add_child(card)


# ---------------------------------------------------------------- Help

func open_help() -> void:
	var vb := _open_window("Welcome to Driftnest", 760, 580)
	var sc := _scroll(vb)
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_font_size_override("normal_font_size", 19)
	r.add_theme_font_size_override("bold_font_size", 19)
	r.text = """You're the new [b]Keeper[/b] of a floating island, and there's an egg on your back.

[b]Warm your egg.[/b] Every chore you finish adds warmth. When it's full, the egg hatches into a creature — real or mythical — that follows you around.

[b]Chores[/b] — walk into a spot and stay there:
 •  [color=#3fae5a]Moonberry Grove[/color] — pick berries
 •  [color=#3fa9d6]Tidepool[/color] — tidy the pool
 •  [color=#9a6bff]Cloudmill[/color] — wind the mill
 •  [color=#c27c2c]Star Post[/color] — grab starmail, then follow the arrow to the glowing mailbox
 •  [color=#ff6a3d]Lantern Ridge[/color] — light all three lanterns
 •  [b]The Nest[/b] — take a nap (slow, but very warm)

[b]Wishes.[/b] Your companion's thought bubble shows the chore it wishes for. Grant it for double XP and bonus glimmer.

[b]Habitats.[/b] Creatures do chores from their own habitat 50% faster, and they get quicker as they grow: Sprout, Fledgling, Bloom, Elder and finally Radiant.

[b]Collect them all.[/b] Spend glimmer on new eggs at the Egg Kiosk. Some hatch rare or legendary creatures, and once in a while a [color=#e8960c]Prismatic[/color] one appears.

Move with [b]WASD / arrow keys[/b] or the on-screen stick."""
	sc.add_child(r)
	var go := _button("Let's go!", close_modal, 24)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.custom_minimum_size = Vector2(220, 56)
	vb.add_child(go)


# ---------------------------------------------------------------- hatching

func _on_hatched(pet: Dictionary, is_new: bool) -> void:
	if modal:
		_hatch_queue.append([pet, is_new])
	else:
		_show_hatch.call_deferred(pet, is_new)


func _show_hatch(pet: Dictionary, is_new: bool) -> void:
	var vb := _open_window("It hatched!", 560, 540, false)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	var pic = _portrait("pet", Vector2(320, 240))
	pic.species = str(pet["species"])
	pic.level = 1
	pic.prism = bool(pet["prism"])
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(pic)
	var sp: Dictionary = Data.SPECIES[str(pet["species"])]
	var nm := _label(Game.pet_display_name(pet), 32)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(nm)
	var rar: Dictionary = Data.RARITY[str(sp["rarity"])]
	var kind := "Mythical creature" if bool(sp["mythic"]) else "Real-world animal"
	var rl := _label("%s  ·  %s  ·  %s habitat" % [rar["name"], kind, Data.HABITATS[str(sp["habitat"])]["name"]], 17, Color(str(rar["color"])))
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(rl)
	if is_new:
		var nl := _label("New Bestiary entry!", 18, Color("#c2416e"))
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(nl)
	var ok := _button("Wonderful!", close_modal, 24)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.custom_minimum_size = Vector2(220, 56)
	vb.add_child(ok)


func _on_leveled(pet: Dictionary) -> void:
	toast("%s grew into a %s!" % [Game.pet_display_name(pet), Data.stage_name(int(pet["level"]))])
