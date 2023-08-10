class_name ConcurrentQueue

class Segment:
	var next : Segment = null:
#		get:
#			if next == null: next = Segment.new(16)
#			return next
		set(value): next = value
		get: return next
		

	var data = []:
		get: return data
		
		
	func _init(data_size : int):
		data.resize(data_size)
	

var _segment_start : Segment
var _segment_end : Segment

var _start_segment_index : int = 0
var _end_segment_index : int = 0

var _push_mutex : Mutex = Mutex.new()
var _pop_mutex : Mutex = Mutex.new()

const SEGMENT_DATA_SIZE = 16


func _init():
	var segment = Segment.new(SEGMENT_DATA_SIZE)
	_segment_start = segment
	_segment_end = segment
	

func push(value):
	_push_mutex.lock()
	
	_segment_end.data[_end_segment_index] = value
	var next_index = _end_segment_index + 1
		
	if next_index == SEGMENT_DATA_SIZE:
		_segment_end.next = Segment.new(SEGMENT_DATA_SIZE)
		_segment_end = _segment_end.next
		_end_segment_index = 0
	else:
		_end_segment_index = next_index
	
	_push_mutex.unlock()
	
	
func pop():
	if _segment_start == _segment_end && _start_segment_index == _end_segment_index:
		return null
		
	_pop_mutex.lock()
	
	var value = _segment_start.data[_start_segment_index]
	var next_index : int = _start_segment_index + 1
	
	if next_index == SEGMENT_DATA_SIZE:
		_segment_start = _segment_start.next
		_start_segment_index = 0
	else:
		_start_segment_index = next_index
		
	_pop_mutex.unlock()
		
	return value
	
	
