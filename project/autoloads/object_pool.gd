extends Node

var _pools: Dictionary = {}
var _active: Dictionary = {}

func reset() -> void:
	for path in _active:
		for node in _active[path]:
			if is_instance_valid(node):
				node.queue_free()
	for path in _pools:
		for node in _pools[path]:
			if is_instance_valid(node):
				node.queue_free()
	_pools.clear()
	_active.clear()
