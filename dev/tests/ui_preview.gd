extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var output := OS.get_environment("NEEDLENET_UI_OUT")
	if output.is_empty():
		output = OS.get_user_data_dir().path_join("ui-preview")
	DirAccess.make_dir_recursive_absolute(output)
	var mp := root.get_node("MPMod")
	change_scene_to_file(mp.MENU_SCENE)
	await create_timer(9).timeout
	for button in root.find_children("*", "Button", true, false):
		if button.is_visible_in_tree() and button.text.strip_edges().to_upper() in ["CONFIRM", "ПОДТВЕРДИТЬ"]:
			button.pressed.emit()
			break
	await create_timer(2).timeout
	var entry: Button = mp.ui._find_mp_button(current_scene)
	if entry == null:
		quit(1)
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("main-menu-steam.png"))
	entry.grab_focus()
	entry.pressed.emit()
	await create_timer(1).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("session-steam.png"))
	print("NN_STEAM_UI ready=", mp.steam_ready(), " create_enabled=", not mp.ui._steam_host_btn.disabled)
	quit(0 if mp.steam_ready() and not mp.ui._steam_host_btn.disabled else 1)
