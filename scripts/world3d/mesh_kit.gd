class_name MeshKit
extends RefCounted
## Builds one merged, vertex-coloured mesh out of many simple shapes (spheres, boxes, cones...),
## so each building, pet or tree is a single draw call. Shapes are cached per size + colour.

static var _cache := {}
static var _mat: StandardMaterial3D
static var _mat_glow: StandardMaterial3D

var st := SurfaceTool.new()
var xf := Transform3D.IDENTITY # applied to every shape added (use push/pop to nest)
var _stack: Array = []
var _any := false


func _init() -> void:
	st.begin(Mesh.PRIMITIVE_TRIANGLES)


## The shared matte material every kit mesh uses (colours come from the vertices).
static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.vertex_color_is_srgb = true
		_mat.roughness = 0.82
		_mat.metallic_specular = 0.35
	return _mat


static func glow_material() -> StandardMaterial3D:
	if _mat_glow == null:
		_mat_glow = StandardMaterial3D.new()
		_mat_glow.vertex_color_use_as_albedo = true
		_mat_glow.vertex_color_is_srgb = true
		_mat_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _mat_glow


func push(t: Transform3D) -> void:
	_stack.append(xf)
	xf = xf * t


func pop() -> void:
	xf = _stack.pop_back()


static func xform(pos: Vector3, rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
	var b := Basis.from_euler(rot_deg * (PI / 180.0)).scaled(scl)
	return Transform3D(b, pos)


static func _colored(key: String, make: Callable, col: Color) -> ArrayMesh:
	var k := key + col.to_html()
	if _cache.has(k):
		return _cache[k]
	var pm: Mesh = make.call()
	var arr := pm.surface_get_arrays(0)
	var n: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var cols := PackedColorArray()
	cols.resize(n)
	cols.fill(col)
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = null
	arr[Mesh.ARRAY_TANGENT] = null
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_cache[k] = am
	return am


func _add(m: ArrayMesh, t: Transform3D) -> void:
	st.append_from(m, 0, xf * t)
	_any = true


# ---------------------------------------------------------------- shapes

## Ellipsoid centred at `c` with radii `r`.
func sphere(c: Vector3, r: Vector3, col: Color, seg := 14, rot := Vector3.ZERO) -> void:
	var rings := maxi(4, seg / 2)
	var m := _colored("s%d" % seg, func():
		var s := SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = seg
		s.rings = rings
		return s, col)
	_add(m, xform(c, rot, r))


func ball(c: Vector3, r: float, col: Color, seg := 14) -> void:
	sphere(c, Vector3(r, r, r), col, seg)


## Box centred at `c`.
func box(c: Vector3, size: Vector3, col: Color, rot := Vector3.ZERO) -> void:
	var m := _colored("b", func():
		var b := BoxMesh.new()
		b.size = Vector3.ONE
		return b, col)
	_add(m, xform(c, rot, size))


## Cylinder / cone centred at `c` (height along local Y). top = 0 makes a cone.
func cyl(c: Vector3, top: float, bottom: float, h: float, col: Color, seg := 12, rot := Vector3.ZERO) -> void:
	var tk := snappedf(top / maxf(bottom, 0.0001), 0.01)
	var m := _colored("c%d_%.2f" % [seg, tk], func():
		var cm := CylinderMesh.new()
		cm.top_radius = tk
		cm.bottom_radius = 1.0
		cm.height = 1.0
		cm.radial_segments = seg
		cm.rings = 1
		return cm, col)
	_add(m, xform(c, rot, Vector3(bottom, h, bottom)))


func cone(c: Vector3, r: float, h: float, col: Color, seg := 12, rot := Vector3.ZERO) -> void:
	cyl(c, 0.0, r, h, col, seg, rot)


func torus(c: Vector3, inner: float, outer: float, col: Color, rot := Vector3.ZERO, scl := Vector3.ONE, seg := 20) -> void:
	var k := snappedf(inner / outer, 0.01)
	var m := _colored("t%d_%.2f" % [seg, k], func():
		var t := TorusMesh.new()
		t.inner_radius = k
		t.outer_radius = 1.0
		t.rings = seg
		t.ring_segments = 8
		return t, col)
	_add(m, xform(c, rot, scl * outer))


func capsule(c: Vector3, r: float, h: float, col: Color, rot := Vector3.ZERO, seg := 12) -> void:
	var k := snappedf(h / r, 0.05)
	var m := _colored("p%d_%.2f" % [seg, k], func():
		var cp := CapsuleMesh.new()
		cp.radius = 1.0
		cp.height = maxf(k, 2.0)
		cp.radial_segments = seg
		cp.rings = 4
		return cp, col)
	_add(m, xform(c, rot, Vector3(r, r, r)))


## Pitched roof: ridge along local X, eaves overhanging by `over`.
func roof(c: Vector3, w: float, d: float, h: float, col: Color, over := 0.12, rot := Vector3.ZERO) -> void:
	var m := _colored("roof%.2f" % over, func():
		var s := SurfaceTool.new()
		s.begin(Mesh.PRIMITIVE_TRIANGLES)
		var hw := 0.5 + over
		var hd := 0.5 + over
		var a := Vector3(-hw, 0, hd)
		var b := Vector3(hw, 0, hd)
		var cc := Vector3(hw, 1, 0)
		var e := Vector3(-hw, 1, 0)
		var f := Vector3(-hw, 0, -hd)
		var g := Vector3(hw, 0, -hd)
		for q in [[a, b, cc, e], [g, f, e, cc]]:
			s.add_vertex(q[0]); s.add_vertex(q[2]); s.add_vertex(q[1])
			s.add_vertex(q[0]); s.add_vertex(q[3]); s.add_vertex(q[2])
		s.add_vertex(a); s.add_vertex(f); s.add_vertex(e)
		s.add_vertex(b); s.add_vertex(cc); s.add_vertex(g)
		# underside so the eaves aren't see-through from below
		s.add_vertex(a); s.add_vertex(g); s.add_vertex(f)
		s.add_vertex(a); s.add_vertex(b); s.add_vertex(g)
		s.generate_normals()
		s.index()
		return s.commit(), col)
	_add(m, xform(c, rot, Vector3(w, h, d)))
	# shingle rows and a ridge cap so roofs read well from above
	var hd2 := d / 2.0 + over
	var ang := atan2(h, hd2)
	var row := col.darkened(0.14)
	push(xform(c, rot))
	for s in [1.0, -1.0]:
		for i in 3:
			var f := (i + 1) / 4.0
			var p := Vector3(0, h * f + 0.02, s * hd2 * (1.0 - f))
			box(p, Vector3(w + over * 2.0, 0.03, 0.05), row, Vector3(rad_to_deg(ang) * s, 0, 0))
	box(Vector3(0, h + 0.02, 0), Vector3(w + over * 2.0 + 0.04, 0.09, 0.14), col.darkened(0.25))
	pop()


func ellipse(c: Vector3, rx: float, rz: float, h: float, col: Color, seg := 28, rot := Vector3.ZERO) -> void:
	var m := _colored("c%d_1.00" % seg, func():
		var cm := CylinderMesh.new()
		cm.top_radius = 1.0
		cm.bottom_radius = 1.0
		cm.height = 1.0
		cm.radial_segments = seg
		cm.rings = 1
		return cm, col)
	_add(m, xform(c, rot, Vector3(rx, h, rz)))


# ---------------------------------------------------------------- output

func is_empty() -> bool:
	return not _any


func commit() -> ArrayMesh:
	if not _any:
		return ArrayMesh.new()
	var m := st.commit()
	if m.get_surface_count() > 0:
		m.surface_set_material(0, material())
	return m


static func instance(mesh: Mesh, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if parent:
		parent.add_child(mi)
	return mi
