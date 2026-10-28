extends SceneTree

var mp: Node
var output := OS.get_environment("NEEDLENET_UI_OUT")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	mp = root.get_node("MPMod")
	mp.my_name = "Motion test"
	mp.host(27845)
	root.get_node("SaveManager").begin_new_game(0, true)
	change_scene_to_file(mp.GAME_SCENE)
	while not mp.in_world():
		await create_timer(0.2).timeout
	await create_timer(8).timeout
	var player: Node = mp.world_sync.player
	var camera: Camera3D = player.camera
	var intro: Node = mp.world_sync.world.get("intro")
	if is_instance_valid(intro) and intro.has_method("_finish"):
		intro.call("_finish")
	await create_timer(1).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	player.scripted = false
	player.global_position = Vector3(25, 0.1, 3)
	player.rotation = Vector3.ZERO
	player.set("_pitch", -1.4)
	camera.rotation = Vector3.ZERO
	camera.get_parent().rotation.x = -1.4
	player.reset_physics_interpolation()
	player.capture_mouse(true)
	camera.make_current()
	for property in player.get_property_list():
		if str(property.name).contains("bob") or str(property.name).contains("sway") or str(property.name).contains("head") or str(property.name).contains("shake"):
			print("NN_PROBE_PLAYER_FIELD ", property.name, "=", player.get(property.name))
	var view = load(OS.get_environment("NEEDLENET_VIEW_DRIVER")).new()
	root.add_child(view)
	view.body = mp.world_sync._me
	Engine.max_fps = 144
	print("NN_PROBE_INTERPOLATION_ENABLED ", ProjectSettings.get_setting("physics/common/physics_interpolation"))
	print("NN_PROBE_CONTROL ", player.scripted, " accepts=", player.call("_accepts_move"))
	var samples := []
	var images: Array[Image] = []
	var start: Vector3 = player.global_position
	Input.action_press("move_forward")
	for frame in 480:
		if frame == 120:
			Input.action_press("sprint")
		elif frame == 240:
			Input.action_release("sprint")
			view.freeze_bones = true
		elif frame == 360:
			view.freeze_bones = false
			Input.action_release("move_forward")
		await RenderingServer.frame_post_draw
		var body: Node3D = mp.world_sync._me
		var relative := camera.get_camera_transform().affine_inverse() * body.global_position
		var root_error: Vector3 = body.global_position - player.global_position
		var view_error: Vector3 = root_error - camera.get_parent().global_basis * camera.position
		var hips: Vector3 = body._skel.global_transform * body._skel.get_bone_global_pose(body._b_hips).origin
		var screen: Vector2 = camera.unproject_position(hips)
		var head: Node3D = camera.get_parent()
		var bone: Vector3 = body._skel.get_bone_global_pose(body._b_hips).origin
		samples.append({"frame": frame, "fraction": Engine.get_physics_interpolation_fraction(), "relative": [relative.x, relative.y, relative.z], "head": [head.position.x, head.position.y, head.position.z], "head_rotation": [head.rotation.x, head.rotation.y, head.rotation.z], "hips_local": [bone.x, bone.y, bone.z], "anim_time": body._anim.current_animation_position, "view_error": [view_error.x, view_error.y, view_error.z], "root_error": [root_error.x, root_error.y, root_error.z], "hips_pixel": [screen.x, screen.y], "speed": player.velocity.length(), "player_z": player.global_position.z})
		if frame % 6 == 0:
			images.append(root.get_texture().get_image())
	print("NN_PROBE_TRAVEL ", player.global_position.distance_to(start))
	var out := FileAccess.open(output.path_join("samples.json"), FileAccess.WRITE)
	out.store_string(JSON.stringify(samples))
	out.close()
	for index in images.size():
		images[index].save_png(output.path_join("frame-%03d.png" % index))
	print("NN_PROBE_RESULT PASS")
	quit()
