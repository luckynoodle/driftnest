class_name Terrain3D
extends Node3D
## The 3D landscape: rolling meadow, the town plaza, lakes with water, and all of nature
## (trees, rocks, bushes, crystals, flowers, grass) drawn in chunks of MultiMeshes so only
## what's near the camera costs anything. Trees and rocks that run out switch to stumps /
## rubble and back as they regrow.

const CHUNK := 16
const MARGIN := 14 # tiles of scenery beyond the playable map
const WATER_Y := -0.12
const PLAZA_C := Vector2(40.5, 41.1)
const PLAZA_R := Vector2(5.6, 4.6)

var map: WorldMap
var _noise := FastNoiseLite.new()
## cell -> [chunk key, kind-mesh name, index in that chunk's full multimesh]
var _node_slot: Dictionary = {}
## chunk key -> {mesh name -> MultiMeshInstance3D}
var _chunks: Dictionary = {}
## chunk key -> {depleted mesh name -> [cells]}
var _depleted: Dictionary = {}

static var _hnoise: FastNoiseLite


# ================================================================ heights

static func _lake_s(center: Vector2, base: float, p: Vector2) -> float:
	var a := (p - center).angle()
	var r := base + 0.9 * sin(a * 3.0 + 1.3) + 0.6 * sin(a * 5.0 + 0.4)
	return p.distance_to(center) - r


## Signed distance (tiles) to the nearest lake shore; negative inside the water.
static func lake_s(p: Vector2) -> float:
	return minf(_lake_s(WorldMap.LAKE, 6.0, p), _lake_s(WorldMap.MEADOW_POND, 3.2, p))


## Ground height at a point given in tiles.
static func height(x: float, z: float) -> float:
	if _hnoise == null:
		_hnoise = FastNoiseLite.new()
		_hnoise.seed = 11
		_hnoise.frequency = 0.07
	var p := Vector2(x, z)
	var h := 0.0
	var s := lake_s(p)
	if s < 0.9:
		h -= smoothstep(0.9, -1.6, s) * 0.6
	var edge := maxf(maxf(3.0 - x, x - 77.0), maxf(3.0 - z, z - 77.0))
	if edge > 0.0:
		h += pow(edge, 1.25) * 0.28 + (_hnoise.get_noise_2d(x, z) + 0.6) * edge * 0.14
	return h


## World 2D (pixels) -> 3D position on the ground.
static func to3(p: Vector2, lift := 0.0) -> Vector3:
	var x := p.x / WorldMap.TILE
	var z := p.y / WorldMap.TILE
	return Vector3(x, height(x, z) + lift, z)


static func in_plaza(p: Vector2) -> bool:
	var d := (p - PLAZA_C) / PLAZA_R
	return d.length() < 1.0


# ================================================================ build

func _ready() -> void:
	_noise.seed = 5
	_noise.frequency = 0.05
	_build_ground()
	_build_plaza()
	_build_water()
	_build_nature()
	Game.node_changed.connect(refresh_node)


func _build_ground() -> void:
	var lo := -MARGIN
	var hi := WorldMap.SIZE + MARGIN
	var n := hi - lo
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	verts.resize((n + 1) * (n + 1))
	norms.resize(verts.size())
	cols.resize(verts.size())
	var g1 := Color("#73b552")
	var g2 := Color("#549b43")
	var dry := Color("#a9c46a")
	var sand := Color("#e3cf9c")
	var bed := Color("#6f8f6a")
	var i := 0
	for zi in n + 1:
		for xi in n + 1:
			var x := float(lo + xi)
			var z := float(lo + zi)
			var h := height(x, z)
			verts[i] = Vector3(x, h, z)
			var nx := height(x - 0.5, z) - height(x + 0.5, z)
			var nz := height(x, z - 0.5) - height(x, z + 0.5)
			norms[i] = Vector3(nx, 1.0, nz).normalized()
			var t := clampf(0.5 + _noise.get_noise_2d(x * 2.0, z * 2.0) * 0.9, 0.0, 1.0)
			var c := g1.lerp(g2, t)
			var edge := maxf(maxf(-x, x - 80.0), maxf(-z, z - 80.0))
			if edge > 0.0:
				c = c.lerp(dry, clampf(edge / 12.0, 0.0, 0.5))
			# forest floor is a little darker
			var fd := Vector2(x, z).distance_to(WorldMap.FOREST)
			if fd < 12.0:
				c = c.lerp(Color("#4f9440"), (1.0 - fd / 12.0) * 0.5)
			var s := lake_s(Vector2(x, z))
			if s < 1.1:
				c = c.lerp(sand, clampf((1.1 - s) / 0.9, 0.0, 1.0))
			if s < -0.4:
				c = sand.lerp(bed, clampf((-0.4 - s) / 1.2, 0.0, 1.0))
			cols[i] = c
			i += 1
	var idx := PackedInt32Array()
	idx.resize(n * n * 6)
	var k := 0
	for zi in n:
		for xi in n:
			var a := zi * (n + 1) + xi
			var b := a + 1
			var c2 := a + (n + 1)
			var d := c2 + 1
			idx[k] = a; idx[k + 1] = b; idx[k + 2] = c2
			idx[k + 3] = b; idx[k + 4] = d; idx[k + 5] = c2
			k += 6
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 1.0
	m.metallic_specular = 0.1
	am.surface_set_material(0, m)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.name = "Ground"
	add_child(mi)


func _build_plaza() -> void:
	var k := MeshKit.new()
	var c := Vector3(PLAZA_C.x, 0.0, PLAZA_C.y)
	k.ellipse(c + Vector3(0, -0.01, 0), PLAZA_R.x + 0.25, PLAZA_R.y + 0.25, 0.05, Color("#b9a073"), 48)
	k.ellipse(c + Vector3(0, 0.0, 0), PLAZA_R.x, PLAZA_R.y, 0.06, Color("#d8bf8c"), 48)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in 230:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.94
		var p := c + Vector3(cos(a) * r * PLAZA_R.x, 0.03, sin(a) * r * PLAZA_R.y)
		k.ellipse(p, 0.16, 0.13, 0.03, Color("#c9ae7c").lerp(Color("#e6d3a6"), rng.randf()), 7, Vector3(0, rng.randf() * 180.0, 0))
	var mi := MeshKit.instance(k.commit(), self)
	mi.name = "Plaza"
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_water() -> void:
	var sh := Shader.new()
	sh.code = WATER_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	for lake in [[WorldMap.LAKE, 6.0], [WorldMap.MEADOW_POND, 3.2]]:
		var c: Vector2 = lake[0]
		var r: float = lake[1] + 2.5
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var step := 0.5
		var cells := int(ceil(r * 2.0 / step))
		for zi in cells:
			for xi in cells:
				var x0 := c.x - r + xi * step
				var z0 := c.y - r + zi * step
				var quad := [Vector2(x0, z0), Vector2(x0 + step, z0), Vector2(x0 + step, z0 + step), Vector2(x0, z0 + step)]
				var inside := false
				for q in quad:
					if lake_s(q) < 0.6:
						inside = true
				if not inside:
					continue
				for vi in [0, 1, 2, 0, 2, 3]:
					var q2: Vector2 = quad[vi]
					var depth := clampf(-lake_s(q2) / 2.5, 0.0, 1.0)
					st.set_color(Color(depth, 0, 0))
					st.set_normal(Vector3.UP)
					st.add_vertex(Vector3(q2.x, WATER_Y, q2.y))
		var wm := st.commit()
		wm.surface_set_material(0, mat)
		var mi := MeshInstance3D.new()
		mi.mesh = wm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	# lilies and reeds
	var k := MeshKit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for cell in map.water:
		var p := Vector2(cell) + Vector2(0.5, 0.5)
		var s := lake_s(p)
		if s < -1.0 and rng.randf() < 0.1:
			k.ellipse(Vector3(p.x + rng.randf_range(-0.3, 0.3), WATER_Y + 0.02, p.y + rng.randf_range(-0.3, 0.3)), 0.24, 0.22, 0.02, Color("#5fae4f"), 12)
			if rng.randf() < 0.4:
				k.ball(Vector3(p.x + 0.08, WATER_Y + 0.07, p.y), 0.06, Color("#ffb3c1"), 8)
	for i in 70:
		var lake: Vector2 = WorldMap.LAKE if i < 50 else WorldMap.MEADOW_POND
		var base := 6.0 if i < 50 else 3.2
		var a := rng.randf() * TAU
		if absf(sin(a)) > 0.8 and rng.randf() < 0.5:
			continue
		var r2 := base + 0.9 * sin(a * 3.0 + 1.3) + 0.6 * sin(a * 5.0 + 0.4) + 0.15
		var p2 := lake + Vector2(cos(a), sin(a)) * r2
		if rng.randf() < 0.35:
			k.push(MeshKit.xform(Vector3(p2.x, height(p2.x, p2.y), p2.y), Vector3(0, rng.randf() * 360.0, 0)))
			for j in 4:
				var dir := Vector3(0.1 * (j - 1.5), 1, 0.05 * j)
				Models3D._spike(k, Vector3(0.05 * j - 0.08, 0, 0.03 * (j % 2)), dir, 0.02, 0.55 + 0.1 * (j % 2), Color("#5c9a48"), 4)
			k.capsule(Vector3(-0.02, 0.5, 0.0), 0.03, 0.16, Color("#7a5232"))
			k.pop()
	var decor := MeshKit.instance(k.commit(), self)
	decor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ================================================================ nature

func _chunk_key(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / CHUNK), floori(float(cell.y) / CHUNK))


func _mesh_for(kind: String, cell: Vector2i) -> String:
	var v := WorldMap.hash01(cell, 1)
	match kind:
		"tree":
			if v > 0.55:
				return "pine"
			return "tree_bloom" if v < 0.14 else "tree"
	return kind


func _xf_for(cell: Vector2i, kind: String, extra_scale := 1.0) -> Transform3D:
	var v := WorldMap.hash01(cell, 1)
	var jx := (WorldMap.hash01(cell, 2) - 0.5) * 0.35
	var jz := (WorldMap.hash01(cell, 3) - 0.5) * 0.35
	var x := cell.x + 0.5 + jx
	var z := cell.y + 0.5 + jz
	var s := 1.0
	match kind:
		"tree": s = 0.85 + v * 0.4
		"rock": s = 0.8 + v * 0.5
		"bush": s = 0.85 + v * 0.3
		"crystal": s = 0.9 + v * 0.3
	s *= extra_scale
	var rot := WorldMap.hash01(cell, 4) * TAU
	var b := Basis(Vector3.UP, rot).scaled(Vector3(s, s, s))
	return Transform3D(b, Vector3(x, height(x, z), z))


func _tint_for(cell: Vector2i) -> Color:
	var t := WorldMap.hash01(cell, 5)
	return Color(0.92 + t * 0.16, 0.95 + t * 0.1, 0.9 + t * 0.12)


func _mmi(mesh: Mesh, xfs: Array, tints: Array, shadow := true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		mm.set_instance_color(i, tints[i] if i < tints.size() else Color.WHITE)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if not shadow:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


func _build_nature() -> void:
	# gather per chunk
	var groups := {} # chunk -> {mesh -> [[cell, xf, tint]]}
	for cell in map.nodes:
		var kind: String = map.nodes[cell]
		var mname := _mesh_for(kind, cell)
		var ck := _chunk_key(cell)
		if not groups.has(ck):
			groups[ck] = {}
		if not groups[ck].has(mname):
			groups[ck][mname] = []
		groups[ck][mname].append([cell, _xf_for(cell, kind), _tint_for(cell)])
	# scenery trees on the hills beyond the map
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for z in range(-MARGIN + 1, WorldMap.SIZE + MARGIN - 1):
		for x in range(-MARGIN + 1, WorldMap.SIZE + MARGIN - 1):
			if x >= 0 and z >= 0 and x < WorldMap.SIZE and z < WorldMap.SIZE:
				continue
			if rng.randf() > 0.42:
				continue
			var cell := Vector2i(x, z)
			var mname := "pine" if rng.randf() < 0.55 else "tree"
			var ck := _chunk_key(cell)
			if not groups.has(ck):
				groups[ck] = {}
			if not groups[ck].has(mname):
				groups[ck][mname] = []
			groups[ck][mname].append([Vector2i(-99999, -99999), _xf_for(cell, "tree", 1.1), _tint_for(cell)])
	for ck in groups:
		_chunks[ck] = {}
		_depleted[ck] = {}
		for mname in groups[ck]:
			var list: Array = groups[ck][mname]
			var xfs := []
			var tints := []
			for i in list.size():
				var it: Array = list[i]
				xfs.append(it[1])
				tints.append(it[2])
				var cell: Vector2i = it[0]
				if cell.x > -99999:
					_node_slot[cell] = [ck, mname, i, it[1]]
			_chunks[ck][mname] = _mmi(Models3D.nature(mname), xfs, tints)
	_build_ground_decor()
	for cell in map.nodes:
		if Game.node_stage(cell) != 0:
			refresh_node(cell)


func _build_ground_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 123
	var groups := {}
	var flower_cols := [Color("#ffd166"), Color("#ff8fa3"), Color("#ffffff"), Color("#b48cff"), Color("#ff9e5e")]
	var grass_cols := [Color("#4f9a40"), Color("#62ad4c"), Color("#3f8a3a")]
	for z in WorldMap.SIZE:
		for x in WorldMap.SIZE:
			var cell := Vector2i(x, z)
			if map.nodes.has(cell) or map.water.has(cell):
				continue
			var p := Vector2(x + 0.5, z + 0.5)
			if in_plaza(p) or lake_s(p) < 0.8:
				continue
			var ck := _chunk_key(cell)
			if not groups.has(ck):
				groups[ck] = {"flower": [[], []], "tuft": [[], []]}
			for j in 2:
				var r := rng.randf()
				var what := ""
				if r < 0.16:
					what = "flower"
				elif r < 0.62:
					what = "tuft"
				if what == "":
					continue
				var px := x + rng.randf()
				var pz := z + rng.randf()
				var s := rng.randf_range(0.8, 1.3)
				var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(px, height(px, pz), pz))
				groups[ck][what][0].append(xf)
				groups[ck][what][1].append(flower_cols[rng.randi() % flower_cols.size()] if what == "flower" else grass_cols[rng.randi() % grass_cols.size()])
	for ck in groups:
		for what in ["flower", "tuft"]:
			if groups[ck][what][0].size() > 0:
				_mmi(Models3D.nature(what), groups[ck][what][0], groups[ck][what][1], false)


const DEPLETED := {
	"tree": ["stump", "stump_grow"], "tree_bloom": ["stump", "stump_grow"], "pine": ["stump", "stump_grow"],
	"rock": ["rubble", "rubble_grow"], "bush": ["bush_bare", "bush_grow"], "crystal": ["crystal_stub", "crystal_grow"]}


## A natural resource was gathered empty or grew back: swap it for the right model.
func refresh_node(cell: Vector2i) -> void:
	if not _node_slot.has(cell):
		return
	var slot: Array = _node_slot[cell]
	var ck: Vector2i = slot[0]
	var mname: String = slot[1]
	var idx: int = slot[2]
	var full_xf: Transform3D = slot[3]
	var stage := Game.node_stage(cell)
	var mmi: MultiMeshInstance3D = _chunks[ck][mname]
	mmi.multimesh.set_instance_transform(idx, full_xf if stage == 0 else Transform3D(Basis().scaled(Vector3.ZERO), full_xf.origin))
	# depleted models for this chunk: rebuild their small lists
	var dep: Dictionary = _depleted[ck]
	for dn in DEPLETED.get(mname, []):
		if dep.has(dn):
			(dep[dn] as Array).erase(cell)
	if stage > 0 and DEPLETED.has(mname):
		var dn2: String = DEPLETED[mname][stage - 1]
		if not dep.has(dn2):
			dep[dn2] = []
		dep[dn2].append(cell)
	for dn3 in dep.keys():
		var key: String = "dep_" + dn3
		var cells: Array = dep[dn3]
		var mmi2: MultiMeshInstance3D = _chunks[ck].get(key)
		if mmi2 == null:
			mmi2 = _mmi(Models3D.nature(dn3), [], [])
			_chunks[ck][key] = mmi2
		var mm := mmi2.multimesh
		mm.instance_count = cells.size()
		for i in cells.size():
			var s2: Array = _node_slot[cells[i]]
			mm.set_instance_transform(i, s2[3])
			mm.set_instance_color(i, Color.WHITE)


func refresh_all() -> void:
	for cell in _node_slot:
		refresh_node(cell)


const WATER_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_back, specular_schlick_ggx;
uniform vec3 shallow : source_color = vec3(0.42, 0.80, 0.92);
uniform vec3 deep : source_color = vec3(0.16, 0.52, 0.78);
varying float depth;
varying vec3 wpos;
void vertex() {
	depth = COLOR.r;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(wpos.x * 1.3 + TIME * 1.1) * 0.012 + cos(wpos.z * 1.7 + TIME * 0.9) * 0.012;
}
void fragment() {
	float d = smoothstep(0.0, 1.0, depth);
	vec3 col = mix(shallow, deep, d);
	float w = sin(wpos.x * 2.1 + TIME * 1.4 + sin(wpos.z * 1.3) * 2.0) * sin(wpos.z * 2.6 - TIME * 1.1);
	float glint = smoothstep(0.82, 0.98, w);
	col += vec3(glint) * 0.35;
	float edge = 1.0 - smoothstep(0.0, 0.1, depth);
	col = mix(col, vec3(0.92, 0.97, 1.0), edge * 0.55);
	ALBEDO = col;
	ROUGHNESS = 0.08;
	SPECULAR = 0.6;
	NORMAL = normalize(NORMAL + vec3(cos(wpos.x * 3.0 + TIME) * 0.05, 0.0, sin(wpos.z * 3.0 + TIME * 1.2) * 0.05));
	ALPHA = mix(0.7, 0.92, d);
}
"""
