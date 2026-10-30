class_name WorldOverlay
extends Node2D
## World-space UI drawn above everything: station names, chore progress ring,
## starmail arrow and floating reward text.

var main = null
var floaters: Array = []
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font


func float_text(text: String, pos: Vector2, col: Color, delay: float = 0.0) -> void:
	floaters.append({"text": text, "pos": pos, "col": col, "age": -delay})


func _process(delta: float) -> void:
	for f in floaters:
		f["age"] = float(f["age"]) + delta
	floaters = floaters.filter(func(f): return float(f["age"]) < 1.6)
	queue_redraw()


func _text(pos: Vector2, text: String, size: int, col: Color, outline: Color = Color("#3a2c28"), osize: int = 6) -> void:
	var w := 600.0
	var p := pos - Vector2(w / 2.0, 0)
	draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_CENTER, w, size, osize, outline)
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_CENTER, w, size, col)


func _draw() -> void:
	if main == null:
		return
	# station names
	for st in main.stations:
		if str(st["label"]) != "":
			_text(st["pos"] + Vector2(0, float(st["label_y"])), str(st["label"]), 22, Color.WHITE)

	var player: Node2D = main.player
	var head := player.position + Vector2(0, -122)

	# progress ring for the chore the player is standing in
	if int(main.active) >= 0:
		var st: Dictionary = main.stations[int(main.active)]
		var kind := str(st["kind"])
		if kind != "kiosk":
			var need: float = main.station_time(st)
			var ratio := clampf(float(main.progress) / need, 0.0, 1.0)
			draw_circle(head, 27.0, Color(1, 1, 1, 0.9))
			draw_arc(head, 22.0, 0.0, TAU, 40, Color("#eadccb"), 7.0, true)
			if ratio > 0.0:
				draw_arc(head, 22.0, -PI / 2.0, -PI / 2.0 + TAU * ratio, 40, Color("#ff8a65"), 7.0, true)
			_text(head + Vector2(0, -38), main.station_verb(st), 20, Color.WHITE)
			var job_id: String = main.station_job_for_wish(st)
			if job_id != "" and Game.companion_wish() == job_id:
				_text(head + Vector2(0, -62), "Wish bonus!", 18, Color("#ffd1e0"), Color("#c2416e"))

	# arrow toward the mailbox when carrying starmail
	if int(main.mail_target) >= 0:
		var target: Vector2 = main.mailbox_pos(int(main.mail_target))
		var to := target - player.position
		if to.length() > 160.0:
			var dir := to.normalized()
			var c := player.position + Vector2(0, -40) + dir * 80.0
			var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() / 150.0)
			var pts := PackedVector2Array([c + dir * 22.0 * pulse, c + dir.orthogonal() * 14.0 - dir * 8.0, c - dir.orthogonal() * 14.0 - dir * 8.0])
			draw_colored_polygon(pts, Color("#ffd23f"))
			draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color("#7a5a1c"), 3.0, true)

	# floating rewards
	for f in floaters:
		var age: float = f["age"]
		if age < 0.0:
			continue
		var a := clampf(1.6 - age, 0.0, 1.0)
		var col: Color = f["col"]
		_text(f["pos"] + Vector2(0, -60.0 * age), str(f["text"]), 24, Color(col, a), Color(0.2, 0.15, 0.12, a))
