class_name DayNight
extends Node3D
## Day and night for the 3D town: the sun crosses the sky (long golden shadows in the evening),
## a moonlit night with glowing windows, lamp light pools and fireflies, then dawn.
## One full day takes CYCLE seconds of play. Each visit starts in the morning.
## Settings > Day and night off keeps it a sunny afternoon.

const CYCLE := 20.0 * 60.0
const START := 0.1 # morning

# [phase, sun elevation°, sun direction°, sun colour, sun energy, sky colour, ambient colour, ambient energy, night]
const KEYS := [
	[0.00, 6.0, -105.0, "#ffb38a", 0.35, "#f2c6a6", "#a6b0dc", 0.30, 0.35],
	[0.07, 34.0, -80.0, "#fff0d4", 0.82, "#bfe3f2", "#c9dcff", 0.38, 0.0],
	[0.30, 58.0, -38.0, "#fff4de", 0.85, "#bfe3f2", "#c9dcff", 0.38, 0.0],
	[0.52, 46.0, 10.0, "#fff0d4", 0.82, "#c4e4f0", "#cfdcf8", 0.38, 0.0],
	[0.62, 28.0, 60.0, "#ffd7a0", 0.88, "#f3dcc0", "#e2d6ee", 0.42, 0.0],
	[0.68, 16.0, 85.0, "#ffa868", 0.8, "#f4b494", "#e2bcc4", 0.46, 0.2],
	[0.71, 8.0, 95.0, "#ff8c5a", 0.45, "#c98a8a", "#9c90c8", 0.38, 0.6],
	[0.75, 42.0, -30.0, "#a8bcff", 0.3, "#26315c", "#6070b8", 0.36, 1.0],
	[0.93, 42.0, -30.0, "#a8bcff", 0.3, "#26315c", "#6070b8", 0.36, 1.0],
	[1.00, 6.0, -105.0, "#ffb38a", 0.35, "#f2c6a6", "#a6b0dc", 0.30, 0.35],
]

var main = null
var phase := START
var night := 0.0
var fireflies: CPUParticles3D


func _ready() -> void:
	fireflies = CPUParticles3D.new()
	fireflies.amount = 46
	fireflies.lifetime = 5.0
	fireflies.preprocess = 5.0
	fireflies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fireflies.emission_box_extents = Vector3(13, 0.9, 10)
	fireflies.direction = Vector3.UP
	fireflies.spread = 180.0
	fireflies.initial_velocity_min = 0.05
	fireflies.initial_velocity_max = 0.3
	fireflies.gravity = Vector3(0, 0.02, 0)
	fireflies.scale_amount_min = 0.035
	fireflies.scale_amount_max = 0.06
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.2, 1))
	curve.add_point(Vector2(0.8, 1))
	curve.add_point(Vector2(1, 0))
	fireflies.scale_amount_curve = curve
	var m := SphereMesh.new()
	m.radius = 1.0
	m.height = 2.0
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("#f6ff9a")
	m.material = mat
	fireflies.mesh = m
	fireflies.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fireflies.emitting = false
	add_child(fireflies)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="):
			phase = float(arg.substr(8))


func _process(delta: float) -> void:
	if not bool(Game.settings.get("daynight", true)):
		phase = 0.45
	else:
		phase = fposmod(phase + delta / CYCLE, 1.0)
	apply()


## Jump to a time of day (0..1), for testing and screenshots.
func set_phase(p: float) -> void:
	phase = fposmod(p, 1.0)
	apply()


func apply() -> void:
	var a: Array = KEYS[0]
	var b: Array = KEYS[1]
	for i in KEYS.size() - 1:
		if phase >= float(KEYS[i][0]) and phase <= float(KEYS[i + 1][0]):
			a = KEYS[i]
			b = KEYS[i + 1]
			break
	var t := smoothstep(float(a[0]), float(b[0]), phase)
	var elev := lerpf(a[1], b[1], t)
	var dir := lerp_angle(deg_to_rad(a[2]), deg_to_rad(b[2]), t)
	var sun: DirectionalLight3D = main.sun
	var env: Environment = main.env
	sun.rotation = Vector3(-deg_to_rad(elev), dir, 0)
	sun.light_color = Color(a[3]).lerp(Color(b[3]), t)
	var shadows: bool = sun.shadow_enabled
	sun.light_energy = lerpf(a[4], b[4], t) * (main.shadow_sun_k if shadows else 1.0)
	var sky := Color(a[5]).lerp(Color(b[5]), t)
	env.background_color = sky
	env.fog_light_color = sky.lerp(Color("#cfe3ea"), 0.3 * (1.0 - night))
	RenderingServer.set_default_clear_color(sky)
	env.ambient_light_color = Color(a[6]).lerp(Color(b[6]), t)
	env.ambient_light_energy = lerpf(a[7], b[7], t)
	night = lerpf(a[8], b[8], t)
	MeshKit.set_night(night)
	fireflies.emitting = night > 0.6
	if main.cam3d:
		fireflies.global_position = main.cam_target + Vector3(0, 0.9, 0)
