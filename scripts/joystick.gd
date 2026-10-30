extends Control
## On-screen thumbstick for touch (also works with a mouse drag thanks to
## "emulate touch from mouse" in Project Settings). `value` is a vector in -1..1.

const RADIUS := 80.0

var value := Vector2.ZERO
var enabled := true
var _touch := -1
var _knob := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and _touch == -1 and enabled and is_visible_in_tree() and _hit(st.position):
			_touch = st.index
			_update(st.position)
			get_viewport().set_input_as_handled()
		elif not st.pressed and st.index == _touch:
			release()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _touch:
			_update(sd.position)
			get_viewport().set_input_as_handled()


func _hit(p: Vector2) -> bool:
	return get_global_rect().grow(20.0).has_point(p)


func release() -> void:
	_touch = -1
	value = Vector2.ZERO
	_knob = Vector2.ZERO
	queue_redraw()


func _update(p: Vector2) -> void:
	var d := p - get_global_rect().get_center()
	d = d.limit_length(RADIUS)
	_knob = d
	value = d / RADIUS
	if value.length() < 0.12:
		value = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	draw_circle(c, RADIUS + 14.0, Color(1, 1, 1, 0.22))
	draw_arc(c, RADIUS + 14.0, 0.0, TAU, 48, Color(1, 1, 1, 0.55), 3.0, true)
	draw_circle(c + _knob, 36.0, Color(1, 1, 1, 0.8 if _touch != -1 else 0.55))
	draw_arc(c + _knob, 36.0, 0.0, TAU, 32, Color("#3c6e71", 0.5), 3.0, true)
