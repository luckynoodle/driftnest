extends Node
## Starts the town in 3D or classic 2D (Settings > 3D town), and swaps between them live.
## Automated tests run in 2D unless they pass --3d.

const Main2D := preload("res://scripts/main.gd")
const Main3D := preload("res://scripts/world3d/main3d.gd")

var current: Node = null
var is3d := false


func _ready() -> void:
	Game.settings_changed.connect(_on_settings)
	_start(_want3d())


func _want3d() -> bool:
	var args := OS.get_cmdline_user_args()
	if "--3d" in args:
		return true
	if "--2d" in args:
		return false
	for test in ["--smoke", "--balance", "--showcase"]:
		if test in args:
			return false
	return bool(Game.settings.get("view3d", true))


func _start(three: bool) -> void:
	if current:
		current.queue_free()
		current = null
	is3d = three
	var m := Node2D.new()
	m.set_script(Main3D if three else Main2D)
	m.name = "Main"
	current = m
	var t0 := Time.get_ticks_msec()
	add_child(m)
	print("Town ready (%s) in %d ms" % ["3D" if three else "2D", Time.get_ticks_msec() - t0])


func _on_settings() -> void:
	var want := _want3d()
	if want != is3d:
		Game.save_game()
		_start.call_deferred(want)
