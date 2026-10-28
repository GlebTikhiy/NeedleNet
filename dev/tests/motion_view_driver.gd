extends Node

var body: Node
var freeze_bones := false
var poses: Array[Transform3D] = []

func _ready() -> void:
	process_priority = 2000

func _process(_delta: float) -> void:
	if not is_instance_valid(body):
		return
	var skeleton: Skeleton3D = body._skel
	if not freeze_bones:
		poses.clear()
		return
	if poses.is_empty():
		for index in skeleton.get_bone_count():
			poses.append(skeleton.get_bone_pose(index))
	for index in poses.size():
		skeleton.set_bone_pose(index, poses[index])
