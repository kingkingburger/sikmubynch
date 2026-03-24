extends Node

var _pools: Dictionary = {}  # scene_path -> Array of inactive nodes
var _active: Dictionary = {}  # scene_path -> Array of active nodes

func preload_pool(scene_path: String, count: int) -> void:
	if not _pools.has(scene_path):
		_pools[scene_path] = []
		_active[scene_path] = []
	var scene := load(scene_path) as PackedScene
	for i in count:
		var node := scene.instantiate()
		node.set_process(false)
		node.set_physics_process(false)
		_pools[scene_path].append(node)

func get_node(scene_path: String) -> Node:
	if not _pools.has(scene_path):
		_pools[scene_path] = []
		_active[scene_path] = []

	if _pools[scene_path].size() > 0:
		var node: Node = _pools[scene_path].pop_back()
		node.set_process(true)
		node.set_physics_process(true)
		_active[scene_path].append(node)
		return node

	# Pool empty — instantiate new
	var scene := load(scene_path) as PackedScene
	var node := scene.instantiate()
	_active[scene_path].append(node)
	return node

func return_node(scene_path: String, node: Node) -> void:
	if not _active.has(scene_path):
		node.queue_free()
		return

	_active[scene_path].erase(node)
	node.set_process(false)
	node.set_physics_process(false)

	if node.get_parent():
		node.get_parent().remove_child(node)

	_pools[scene_path].append(node)

func get_active_count(scene_path: String) -> int:
	if _active.has(scene_path):
		return _active[scene_path].size()
	return 0

func get_pool_count(scene_path: String) -> int:
	if _pools.has(scene_path):
		return _pools[scene_path].size()
	return 0

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
