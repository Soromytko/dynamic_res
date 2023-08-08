extends Node3D

@export var terrain_size : Vector3i = Vector3i(100, 1, 100)
@export var chunk_size : Vector3i = Vector3i(10, 10, 10)
@export var observer : Node3D
@export var observed_radius : float = 10
@export var chunk_scene : PackedScene

var _chunks : Dictionary = {}
var _sector : Vector3i = Vector3i.ONE

var _noise : Noise = FastNoiseLite.new()


func _ready():
	var count : int = terrain_size.x * terrain_size.y * terrain_size.z
	_noise.seed = hash("some")
#	_chunks.resize(count)
	

func _process(delta):
#	if !_chunks.has(Vector3i.ZERO):
#		var chunk = _create_chunk(Vector3i.ZERO)
#		_chunks[Vector3i.ZERO] = chunk
#	return
	
	var position = observer.global_position
	var sector = _get_sector_by_position(Vector3(position.x, 0, position.z))
	if sector != _sector:
		var r = chunk_size * observed_radius
		for x in range(sector.x - r.x, sector.x + r.x):
			for z in range(sector.z - r.z, sector.z + r.z):
				if !_in_observed_radius(Vector3i(x, 0, z)): continue
				var chunk_pos = Vector3i(x, 0, z)
				if !_chunks.has(chunk_pos):
					var chunk = _create_chunk(chunk_pos)
					_chunks[chunk_pos] = chunk
		
		for chunk_pos in _chunks.keys():
			if !_in_observed_radius(chunk_pos):
				var chunk = _chunks[chunk_pos]
				chunk.queue_free()
				_chunks.erase(chunk_pos)
		
		_sector = sector
			
	
func _create_chunk(sector : Vector3i) -> TerrainChunk:
	var chunk = chunk_scene.instantiate()
	var chunk_offset = sector * chunk_size
	chunk.global_position = chunk_offset
	chunk.generate_mesh(chunk_size, chunk_offset, _noise)
	add_child(chunk)
	return chunk
	
	
func _in_observed_radius(sector : Vector3i):
	var sec = _get_sector_by_position(observer.global_position)
	return (sector - sec).length() <= observed_radius
	
	
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
	



