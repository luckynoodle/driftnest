extends Control
## On-screen thumbstick for touch (also works with a mouse drag thanks to
## "emulate touch from mouse" in Project Settings). `value` is a vector in -1..1.
## Works in local coordinates, so it behaves the same however the HUD is scaled.

var value := Vector2.ZERO
var enabled := true
var _touch := -1
var _knob := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _radius() -> float:
	return minf(size.x, size.y) / 2.0 - 30.0


func _local(p: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * p


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and _touch == -1 and enabled and is_visible_in_tree() and _hit(_local(st.position)):
			_touch = st.index
			_update(_local(st.position))
			get_viewport().set_input_as_handled()
		elif not st.pressed and st.index == _touch:
			release()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _touch:
			_update(_local(sd.position))
			get_viewport().set_input_as_handled()


func _hit(local: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).grow(20.0).has_point(local)


func release() -> void:
	_touch = -1
	value = Vector2.ZERO
	_knob = Vector2.ZERO
	queue_redraw()


func _update(local: Vector2) -> void:
	var r := _radius()
	var d := (local - size / 2.0).limit_length(r)
	_knob = d
	value = d / r
	if value.length() < 0.12:
		value = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var r := _radius()
	var knob := clampf(r * 0.45, 24.0, 36.0)
	draw_circle(c, r + 14.0, Color(1, 1, 1, 0.22))
	draw_arc(c, r + 14.0, 0.0, TAU, 48, Color(1, 1, 1, 0.55), 3.0, true)
	draw_circle(c + _knob, knob, Color(1, 1, 1, 0.8 if _touch != -1 else 0.55))
	draw_arc(c + _knob, knob, 0.0, TAU, 32, Color("#3c6e71", 0.5), 3.0, true)
