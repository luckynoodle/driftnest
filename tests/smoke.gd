extends Node
## Automated play-through. Run with:
##   godot --path . -- --smoke            (add --headless to skip rendering)
## Exits with code 0 on success, 1 on failure. Saves screenshots to user://shots when rendering.

var main = null
var failures: Array = []
var shot_dir := ""


func _ready() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		print("  FAIL ", msg)
		failures.append(msg)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(shot_dir.path_join(name + ".png"))


func _goto(id: String) -> void:
	main.player.position = main.station_by_id(id)["pos"]
	main.pet.position = main.player.position + Vector2(-60, 0)


func _run() -> void:
	shot_dir = OS.get_user_data_dir().path_join("shots")
	DirAccess.make_dir_recursive_absolute(shot_dir)
	print("Smoke test starting")
	Game.reset_save()
	await _wait(0.3)
	main.hud.open_help()
	await _wait(0.3)
	await _shot("01_help")
	_check(main.hud.is_modal_open(), "help window opens")
	main.hud.close_modal()
	await _wait(0.2)
	await _shot("02_start")

	# --- hatch the Dawn egg by napping in the nest
	_check(not Game.get_carried_egg().is_empty(), "starts carrying an egg")
	Engine.time_scale = 6.0
	_goto("nest")
	var waited := 0.0
	while Game.pets.is_empty() and waited < 40.0:
		await _wait(0.5)
		waited += 0.5
	Engine.time_scale = 1.0
	_check(Game.pets.size() == 1, "dawn egg hatched after naps")
	_check(Game.companion != -1, "hatchling became companion")
	await _wait(0.4)
	await _shot("03_hatch")
	_check(main.hud.is_modal_open(), "hatch reveal shown")
	main.hud.close_modal()

	# --- timed chores
	for id in ["grove", "tidepool", "windmill"]:
		var g := Game.glimmer
		_goto(id)
		Engine.time_scale = 4.0
		await _wait(5.0)
		Engine.time_scale = 1.0
		_check(Game.glimmer > g, "chore at %s pays glimmer" % id)
	await _shot("04_chore")

	# --- starmail errand
	_goto("post")
	Engine.time_scale = 4.0
	await _wait(1.5)
	_check(main.mail_target >= 0, "starmail picked up")
	await _shot("05_mail")
	var g2 := Game.glimmer
	_goto("mail%d" % main.mail_target)
	await _wait(1.5)
	Engine.time_scale = 1.0
	_check(main.mail_target == -1 and Game.glimmer > g2, "starmail delivered")

	# --- lanterns
	var g3 := Game.glimmer
	Engine.time_scale = 4.0
	for i in 3:
		_goto("lantern%d" % i)
		await _wait(1.2)
	Engine.time_scale = 1.0
	_check(Game.glimmer > g3, "lantern ridge pays out")
	_goto("lantern1")
	main.player.position += Vector2(-120, -40)
	await _wait(0.3)
	await _shot("06_lanterns")

	# --- shop & collection
	_goto("kiosk")
	await _wait(0.3)
	_check(main.hud.action_btn.visible, "kiosk shows action button")
	await _shot("07_kiosk")
	Game.glimmer = 5000
	main.hud.open_shop()
	await _wait(0.3)
	await _shot("08_shop")
	for et in Data.EGG_ORDER:
		_check(Game.buy_egg(et), "buy %s egg" % et)
	_check(Game.eggs.size() == 4, "own four eggs")
	main.hud.open_eggs()
	await _wait(0.3)
	await _shot("09_eggs")
	# force-hatch every egg to fill the collection
	for i in 4:
		var e: Dictionary = Game.get_carried_egg()
		e["warmth"] = int(Data.EGGS[e["type"]]["warmth"]) - 1
		Game.complete_job("nap")
		await _wait(0.1)
	main.hud.close_modal()
	while main.hud.is_modal_open():
		main.hud.close_modal()
		await _wait(0.1)
	_check(Game.pets.size() == 5, "five pets after hatching bought eggs")
	# level one pet to Radiant
	var p: Dictionary = Game.pets[Game.pets.size() - 1]
	Game.set_companion(int(p["id"]))
	for i in 40:
		Game.complete_job("lanterns")
	_check(int(p["level"]) == Data.MAX_LEVEL, "companion reaches Radiant")
	p["prism"] = true
	Game.changed.emit()
	main.player.position = main.world_center + Vector2(200, 260)
	await _wait(1.0)
	await _shot("10_radiant")
	main.hud._pets_tab = "mine"
	main.hud.open_pets()
	await _wait(0.3)
	await _shot("11_pets")
	main.hud._pets_tab = "dex"
	main.hud.open_pets()
	await _wait(0.3)
	await _shot("12_bestiary")
	main.hud.close_modal()

	# --- save / load
	Game.save_game()
	var before_pets := Game.pets.size()
	var before_glim := Game.glimmer
	_check(Game.load_game(), "save loads")
	_check(Game.pets.size() == before_pets and Game.glimmer == before_glim, "save round-trips")

	Game.reset_save()
	print("Screenshots: ", shot_dir)
	if failures.is_empty():
		print("SMOKE OK")
		get_tree().quit(0)
	else:
		print("SMOKE FAILED: ", failures)
		get_tree().quit(1)
