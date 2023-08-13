extends Node3D

@export var terrain_size : Vector3i = Vector3i(100, 1, 100)
@export var chunk_size : Vector3i = Vector3i(10, 10, 10)
@export var observed_radius : float = 10
@export var observer : Node3D
@export var chunk_scene : PackedScene

var _chunks : Dictionary = {}
var _noise : Noise = FastNoiseLite.new()

var _sector : Vector3i = Vector3i.ONE
var _observer_pos : Vector3 = Vector3.ZERO
var _prepared_queue : ConcurrentQueue = ConcurrentQueue.new()
var _generation_queue : ConcurrentQueue = ConcurrentQueue.new()

var _thread : Thread = Thread.new()

var task_ids = []

class GenerationChunkData:
	var _sector : Vector3i
	
	func _init(sector : Vector3i):
		_sector = sector
		
	func get_sector(): return _sector


class PreparedChunkData:
	var sector : Vector3i:
		get: return sector
	var mesh : Mesh:
		get: return mesh
	var shape : ConcavePolygonShape3D:
		get: return shape

	func _init(chunk_sector, chunk_mesh, chunk_shape):
		self.sector = chunk_sector
		self.mesh = chunk_mesh
		self.shape = chunk_shape


func _ready():
	_noise.seed = hash("some")
	
	
func _exit_tree():
	return
	_thread.wait_to_finish()
	

var b = false
func _create_all_chunks(count : int):
	if !b:
		for x in count:
			for z in count:
				var chunk_sector = Vector3i(x, 0, z)
				var chunk = chunk_scene.instantiate()
				chunk.size = chunk_size
				chunk.sector = chunk_sector
				chunk.offset = chunk_sector * chunk_size
				add_child(chunk)
				chunk.global_position = chunk_sector * chunk_size
				_chunks[chunk_sector] = chunk
				var distance = (chunk_sector).length()
				var level_del : int = round(distance * 10)
				chunk.start_generation(_noise, level_del)
		b = true
	
	
func _process(delta):
	_create_all_chunks(20)
	return
	_observer_pos = observer.global_position
	var sector = _get_sector_by_position(Vector3(_observer_pos.x, 0, _observer_pos.z))
	if sector != _sector:
		_sector = sector
#		for chunk_pos in _chunks.keys():
#			if !_in_observed_radius(chunk_pos, _observer_pos, observed_radius):
#				var chunk = _chunks[chunk_pos]
#				chunk.queue_free()
#				_chunks.erase(chunk_pos)
		_do_create_chunks()
#		var task_id = WorkerThreadPool.add_task(_do_create_chunks, true, "")
#		task_ids.append(task_id)
		
#	print(task_ids.size(), " chunks ", _chunks.keys().size())
	var i = 0
	while i < task_ids.size():
		var task = task_ids[i]
		if WorkerThreadPool.is_task_completed(task):
			task_ids.remove_at(i)
		else:
			i += 1
		
#		WorkerThreadPool.task
#	print(_generation_queue.count)
	
	var prepared_chunk_data = _prepared_queue.pop()
	if prepared_chunk_data != null:
		if _in_observed_radius(prepared_chunk_data.sector, _observer_pos, observed_radius):
			var chunk = chunk_scene.instantiate()
			_chunks[prepared_chunk_data.sector] = chunk
			chunk.update_mesh(prepared_chunk_data.mesh)
			chunk.update_shape(prepared_chunk_data.shape)
			
			add_child(chunk)
			chunk.global_position = prepared_chunk_data.sector * chunk_size
			

func _generating():
	print("END")
	while true:
		var data = _generation_queue.pop()
		if data != null:
			var prepared_chunk_data = _create_chunk_data(data.get_sector())
			_prepared_queue.push(prepared_chunk_data)
		else: break
	print("END")


func _do_create_chunks():
	var sector = _sector
	var observer_pos = _observer_pos
	var r = chunk_size * observed_radius
	for x in range(sector.x - r.x, sector.x + r.x):
		for z in range(sector.z - r.z, sector.z + r.z):
			if !_in_observed_radius(Vector3i(x, 0, z), observer_pos, observed_radius): continue
			var chunk_pos = Vector3i(x, 0, z)
			var chunk : TerrainChunk = _chunks[chunk_pos] if _chunks.has(chunk_pos) else null
			if chunk == null:
				continue
				chunk = chunk_scene.instantiate()
				chunk.size = chunk_size
				chunk.sector = chunk_pos
				chunk.offset = chunk_pos * chunk_size
				add_child(chunk)
				chunk.global_position = chunk_pos * chunk_size
				_chunks[chunk_pos] = chunk
			var distance = (chunk_pos - _sector).length()
			var level_del : int = round(distance * 10)
			chunk.start_generation(_noise, level_del)
#				var generation_data = GenerationChunkData.new(chunk_pos)
#				_generation_queue.push(generation_data)
#				if !_thread.is_alive():
#					_thread.wait_to_finish()
#					_thread.start(_generating)
#				else: print("already start")

				
				
func _create_chunk_data(sector : Vector3i) -> PreparedChunkData:
	var chunk_offset = sector * chunk_size
	var chunk_array_mesh = _generate_chunk_mesh_array(chunk_size, chunk_offset, _noise)
	var chunk_surface_tool = _create_surface_tool(chunk_array_mesh)
	var chunk_mesh = chunk_surface_tool.commit()
	var chunk_shape = chunk_array_mesh.create_trimesh_shape()
	var chunk_data = PreparedChunkData.new(sector, chunk_mesh, chunk_shape)
	return chunk_data
#	var chunk : TerrainChunk = chunk_scene.instantiate()
#	chunk.global_position = chunk_offset
#	chunk.update_mesh(chunk_surface_tool.commit())
#	chunk.update_shape(chunk_array_mesh.create_trimesh_shape())
#	add_child(chunk)
#	return chunk
	
	
func _create_surface_tool(array_mesh, is_generate_normals = true):
	var surface_tool = SurfaceTool.new()
	surface_tool.create_from(array_mesh, 0)
	if is_generate_normals: surface_tool.generate_normals()
	return surface_tool


func _create_array_mesh(vertices, indices, normals = []):
	var mesh_data = []
	mesh_data.resize(ArrayMesh.ARRAY_MAX)
	mesh_data[ArrayMesh.ARRAY_VERTEX] = PackedVector3Array(vertices)
	mesh_data[ArrayMesh.ARRAY_INDEX] = PackedInt32Array(indices)
	mesh_data[ArrayMesh.ARRAY_NORMAL] = PackedVector3Array(normals);
	var array_mesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_data)
	return array_mesh
	
	
func _generate_chunk_mesh_array(size : Vector3i, offset : Vector3i, noise : Noise):
	var smooth = 1
#	Vertices
	var vertex_count : Vector3i = size * smooth + Vector3i.ONE
	var vertex_step : Vector3 = Vector3(size) / (Vector3(vertex_count) - Vector3.ONE)
	var vertices = []
	vertices.resize(vertex_count.x * vertex_count.z)
	for x in vertex_count.x:
		for z in vertex_count.x:
			var w = vertex_step.x * x - size.x / 2.0
			var h : float = noise.get_noise_2d(x+ offset.x, z + offset.z) * 15
			var d = vertex_step.z * z - size.z / 2.0
			vertices[x * vertex_count.x + z] = Vector3(w, h, d)
#	Triangles
	var triangle_count : Vector3i = size * smooth
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
	var normals = []
	normals.resize(vertices.size())
	return _create_array_mesh(vertices, indices, normals)


func _in_observed_radius(sector : Vector3i, observed_position : Vector3, radius : float):
	var sec = _get_sector_by_position(observed_position)
	return (sector - sec).length() <= radius
	
	
func _in_boundary(point : Vector3i, size : Vector3i) -> bool:
	return point > Vector3i.ZERO && point < size
	
	
func _get_1d_from_3d(point : Vector3i, size : Vector3i) -> int:
	return (point.x * size.x + point.y) * size.y + point.z if _in_boundary(point, size) else -1
	
	
func _get_sector_by_position(position : Vector3) -> Vector3i:
	return round(position / Vector3(chunk_size))


func _get_chunk_by_sector(sector : Vector3i):
	var index = _get_1d_from_3d(sector, terrain_size)
	return _chunks[index] if index >= 0 else null
	

func _get_chunk_by_position(position : Vector3):
	var sector = _get_sector_by_position(position)
	return _get_chunk_by_sector(sector)
	



