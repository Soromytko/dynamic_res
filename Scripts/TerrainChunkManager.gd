extends Node3D

@export var terrain_size : Vector3i = Vector3i(100, 1, 100)
@export var chunk_size : Vector3i = Vector3i(10, 10, 10)
@export var observer : Node3D
@export var observed_radius : float = 10
@export var chunk_scene : PackedScene

var _chunks : Array[TerrainChunk] = []
var _sector : Vector3i = Vector3i.ZERO


func _ready():
	var count : int = terrain_size.x * terrain_size.y * terrain_size.z
#	_chunks.resize(count)
	

func _process(delta):
	var position = observer.global_position
	var sector = _get_sector_by_position(Vector3(position.x, 0, position.z))
	if sector != _sector:
#		for i in _chunks.size():
#			var chunk = _chunks[i]
#			var sec = _get_sector_by_position(chunk.global_position)
#			if !_in_observed_radius(sec):
#				_chunks.remove_at(i)
#				i -= 1
#			else:
#				_create_chunk(sec)

		
		_sector = sector
			
	
func _create_chunk(sector : Vector3i):
	var chunk = chunk_scene.instantiate()
	chunk.global_position = sector * chunk_size
	add_child(chunk)
	_chunks.append(chunk)
	return
	var index = _get_1d_from_3d(sector, terrain_size)
	_chunks[index] = chunk
	
	
func _in_observed_radius(sector : Vector3i):
	return sector.length() <= observed_radius
	
	
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
	



