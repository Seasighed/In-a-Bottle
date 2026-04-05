extends SceneTree

const TEST_SCENE := preload("res://Scenes/Tests/CiTestRunner.tscn")

func _init() -> void:
	call_deferred("_start")

func _start() -> void:
	var test_node: Node = TEST_SCENE.instantiate()
	root.add_child(test_node)
	while is_instance_valid(test_node):
		await process_frame
