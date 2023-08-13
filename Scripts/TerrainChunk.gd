class_name TerrainChunk extends Node3D

var width : int = 10
var depth : int = 10

var mesh
var shape

var size : Vector3i = Vector3i.ONE:
	set(value): size = value
	get: return size

var sector : Vector3i = Vector3i.ZERO:
	set(value): sector = value
	get: return sector
	

var offset : Vector3i = Vector3i.ZERO:
	set(value): offset = value
	get: return offset
	

var _thread : Thread = Thread.new()


func update_mesh(mesh):
	$MeshInstance3D.mesh = mesh
	
	
func update_shape(shape):
	$CollisionShape3D.shape = shape


func start_generation(noise : Noise, detalization_level : int = 1):
	_generate_mesh(noise, detalization_level)
	return
	var gen_func = func():
		_generate_mesh(noise, detalization_level)
	_thread.start(gen_func)


func _generate_mesh(noise : Noise, detalization_level : int = 1):
	var smooth : Vector3i = size - Vector3i.ONE * detalization_level
#	Vertices
	if smooth.x < 2: smooth = Vector3i.ONE * 2
	var vertex_count : Vector3i = smooth + Vector3i.ONE
	var vertex_step : Vector3 = Vector3(size) / (Vector3(vertex_count) - Vector3.ONE)
	var vertices = []
	vertices.resize(vertex_count.x * vertex_count.z)
	for x in vertex_count.x:
		for z in vertex_count.x:
			var w = vertex_step.x * x - size.x / 2.0
			var d = vertex_step.z * z - size.z / 2.0
			var h : float = noise.get_noise_2d(w + offset.x, d + offset.z) * 15
			vertices[x * vertex_count.x + z] = Vector3(w, h, d)
#	Triangles
	var triangle_count : Vector3i = smooth
	var indices = []
	indices.resize(triangle_count.x * triangle_count.z * 6)
	var vert : int = 0
	var ind : int = 0
	for x in triangle_count.x:
		for z in triangle_count.z:
			indices[ind + 0] = vert + 0
			indices[ind + 1] = vert + triangle_count.z + 1
			indices[ind + 2] = vert + 1
			indices[ind + 3] = vert + triangle_count.z + 1
			indices[ind + 4] = vert + triangle_count.z + 2
			indices[ind + 5] = vert + 1
			vert += 1
			ind += 6
		vert += 1
#	Normals
	var normals = []
	normals.resize(vertices.size())
		
	_build_mesh(vertices, indices, normals)
		
		
func _build_mesh(vertices, indices, normals):
	var mesh_data = []
	mesh_data.resize(ArrayMesh.ARRAY_MAX)
	mesh_data[ArrayMesh.ARRAY_VERTEX] = PackedVector3Array(vertices)
	mesh_data[ArrayMesh.ARRAY_INDEX] = PackedInt32Array(indices)
	mesh_data[ArrayMesh.ARRAY_NORMAL] = PackedVector3Array(normals);
	
	var array_mesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_data)
	
	var surface_tool = SurfaceTool.new()
	surface_tool.create_from(array_mesh, 0)
	surface_tool.generate_normals()
	
	var mesh = surface_tool.commit()
	$MeshInstance3D.mesh = mesh
#	$CollisionShape3D.shape = array_mesh.create_trimesh_shape()
