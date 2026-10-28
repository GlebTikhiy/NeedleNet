extends SceneTree

var failed := false
var mp: Node
var output := OS.get_environment("NEEDLENET_UI_OUT")

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
	print("NN_UI_", "PASS " if condition else "FAIL ", label)

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, name + " screenshot")

func panel_fits() -> bool:
	var panel: Control = mp.ui._panel
	return Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(panel.get_global_rect())

func run() -> void:
	mp = root.get_node("MPMod")
	change_scene_to_file(mp.MENU_SCENE)
	await create_timer(9).timeout
	for button in root.find_children("*", "Button", true, false):
		if button.is_visible_in_tree() and button.text.strip_edges().to_upper() in ["CONFIRM", "ПОДТВЕРДИТЬ"]:
			button.pressed.emit()
			break
	await create_timer(3).timeout
	var menu := current_scene
	var button: Button = mp.ui._find_mp_button(menu)
	check(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled, "native main menu entry")
	check(button.pressed.get_connections().size() == 1, "one entry callback")
	check(not mp.ui._version_label.is_visible_in_tree(), "no watermark outside session panel")
	await shot("main-menu")
	button.grab_focus()
	button.pressed.emit()
	await create_timer(1).timeout
	check(mp.ui._root.visible and panel_fits(), "menu button opens fitting session panel")
	check(root.gui_get_focus_owner() == mp.ui._ip_toggle, "offline panel focuses available action")
	await shot("lobby-offline")
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	Input.parse_input_event(tab)
	await process_frame
	var focused := root.gui_get_focus_owner()
	check(is_instance_valid(focused) and mp.ui._panel.is_ancestor_of(focused), "Tab stays inside session panel")
	var old_size := root.size
	var old_scale := root.content_scale_size
	var old_mode := root.mode
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	mp.ui._ip_box.show()
	mp.ui._queue_lobby_layout()
	await create_timer(1).timeout
	check(panel_fits(), "expanded IP panel fits 720p")
	check(mp.ui._close_btn.is_visible_in_tree(), "close action remains visible at 720p")
	await shot("lobby-720p")
	mp.ui._ip_box.hide()
	root.content_scale_size = old_scale
	root.size = old_size
	root.mode = old_mode
	await create_timer(0.5).timeout
	mp.ui.close_panel()
	await process_frame
	check(root.gui_get_focus_owner() == button, "close returns focus to menu entry")
	# Simulate a game update without its native multiplayer placeholder.
	button.queue_free()
	await create_timer(1).timeout
	button = mp.ui._find_mp_button(menu)
	check(is_instance_valid(button) and not button.disabled, "fallback entry after native placeholder removed")
	var count := 0
	for candidate in menu.find_children("*", "Button", true, false):
		if candidate.has_meta("mp_menu_entry"):
			count += 1
	check(count == 1, "fallback entry has no duplicates")
	TranslationServer.set_locale("en")
	await create_timer(0.4).timeout
	check(button.text == "MULTIPLAYER", "menu entry changes language")
	TranslationServer.set_locale("ru")
	await create_timer(0.4).timeout
	check(mp.host(27843), "local session creation")
	mp.ui.open_panel()
	await create_timer(1).timeout
	var open_slots := 0
	for child in mp.ui._players_list.get_children():
		if str(child.name).begins_with("OpenSlot"):
			open_slots += 1
			check(child.size.y <= 48, "open slot row stays compact")
	check(open_slots == 3, "three open slots for host")
	check(panel_fits(), "host session panel fits viewport")
	await shot("lobby-host")
	check(mp.ui._lobby_play.text == tr("NEW GAME"), "fresh profile offers new game")
	check(mp.ui._lobby_load.visible and mp.ui._lobby_load.disabled, "load disabled without saves")
	mp.ui._open_chat()
	await process_frame
	check(mp.ui.chat_is_open(), "chat opens in lobby")
	mp.ui._on_chat_submit("Привет, команда! [b]текст[/b]")
	check(mp.ui._chat_lines.size() == 1, "chat retains Cyrillic and literal markup")
	mp.ui._open_chat()
	check(mp.ui._chat_box.get_global_rect().position.x < 40 and mp.ui._chat_box.get_global_rect().position.y < 120, "chat is in upper-left corner")
	var chat_style: StyleBoxFlat = mp.ui._chat_box.get_theme_stylebox("panel")
	check(chat_style.bg_color.a > 0.3 and chat_style.bg_color.a < 0.7, "chat background translucent")
	await shot("chat-lobby")
	var chat_size := root.size
	var chat_scale := root.content_scale_size
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	await create_timer(0.3).timeout
	check(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(mp.ui._chat_box.get_global_rect()), "corner chat fits 720p")
	await shot("chat-720p")
	root.size = chat_size
	root.content_scale_size = chat_scale
	mp.ui._close_chat()
	mp.ui._lobby_play.pressed.emit()
	await create_timer(0.8).timeout
	check(not mp.ui._root.visible and mp.active(), "host action opens native new-game flow")
	for native_button in current_scene.find_children("*", "Button", true, false):
		if native_button.is_visible_in_tree():
			print("NN_SAVE_FLOW_BUTTON ", native_button.text)
	await shot("new-game-picker")
	change_scene_to_file(mp.MENU_SCENE)
	await create_timer(0.8).timeout
	root.get_node("SaveManager").begin_new_game(1, true)
	change_scene_to_file(mp.GAME_SCENE)
	var deadline := Time.get_ticks_msec() + 90000
	while not mp.in_world() and Time.get_ticks_msec() < deadline:
		await create_timer(0.3).timeout
	check(mp.in_world(), "test world loaded")
	if mp.in_world():
		mp.ui._open_chat()
		await process_frame
		check(mp.world_sync.player.menu_is_up(), "typing blocks player controls")
		check(mp.world_sync._me.get_parent() == mp.world_sync.player, "local body shares player transform with camera")
		mp.ui._close_chat()
		var pause: Node = mp.ui._pause_menu.get_ref() if mp.ui._pause_menu != null else null
		check(is_instance_valid(pause), "pause menu registered")
		if is_instance_valid(pause):
			for control in pause.find_children("*", "Button", true, false):
				for connection in control.pressed.get_connections():
					print("NN_PAUSE_CALLBACK ", control.text, " -> ", connection.callable.get_method())
			pause.set("visible", true)
			await create_timer(1).timeout
			var entry: Button = mp.ui._find_mp_button(pause)
			check(is_instance_valid(entry) and entry.is_visible_in_tree(), "native pause session entry")
			await shot("pause-menu")
			if is_instance_valid(entry):
				entry.grab_focus()
				entry.pressed.emit()
				await create_timer(0.5).timeout
				check(mp.ui._root.visible and panel_fits(), "pause entry opens session panel")
				var escape := InputEventKey.new()
				escape.keycode = KEY_ESCAPE
				escape.pressed = true
				Input.parse_input_event(escape)
				await process_frame
				check(not mp.ui._root.visible and bool(pause.get("visible")), "Escape returns to pause menu")
				check(root.gui_get_focus_owner() == entry, "close returns focus to pause entry")
	if mp.in_world():
		paused = false
		await create_timer(3).timeout
		mp.world_sync.world.save_now()
		await create_timer(1).timeout
		var fixture := OS.get_environment("NEEDLENET_UI_SAVE")
		if not fixture.is_empty():
			var destination: String = root.get_node("SaveManager").slot_path(1)
			DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
			check(DirAccess.copy_absolute(fixture, destination) == OK, "existing save fixture copied to private test profile")
		change_scene_to_file(mp.MENU_SCENE)
		await create_timer(2).timeout
		mp.ui.open_panel()
		await process_frame
		check(root.get_node("SaveManager").any_save() and not mp.ui._lobby_load.disabled, "load enabled with existing save")
		check(mp.ui._lobby_play.visible and mp.ui._lobby_play.text == tr("NEW GAME"), "new game remains available with saves")
		mp.ui._lobby_play.pressed.emit()
		await create_timer(0.4).timeout
		check(mp.active() and not mp.ui._root.visible, "new-game picker with existing save retains session")
		change_scene_to_file(mp.MENU_SCENE)
		await create_timer(1).timeout
		mp.ui.open_panel()
		mp.ui._lobby_load.pressed.emit()
		await create_timer(0.5).timeout
		check(mp.active() and not mp.ui._root.visible, "load picker retains session")
		await shot("load-game-picker")
	var avatar = load("res://mods/multiplayer/mp_avatar.gd").new()
	root.add_child(avatar)
	avatar.set_process(false)
	avatar.set_target(Vector3.ZERO, deg_to_rad(179), 0, 0, 0, 4.2)
	var now := Time.get_ticks_msec() / 1000.0
	avatar._pose_samples.clear()
	avatar._pose_samples.append({"time": now - 0.2, "pos": Vector3.ZERO, "yaw": deg_to_rad(179), "pitch": 0.0})
	avatar._pose_samples.append({"time": now, "pos": Vector3(0.84, 0, 0), "yaw": deg_to_rad(-179), "pitch": 0.0})
	avatar._process(0.016)
	check(absf(avatar.position.x - 0.42) < 0.025, "pose buffer samples between network updates")
	check(absf(avatar.rotation.y) > 3.0, "yaw interpolates across angle wrap")
	avatar.set_target(Vector3(20, 0, 0), 0, 0, 0, 0, 0)
	avatar._process(0.016)
	check(avatar.position.distance_to(Vector3(20, 0, 0)) < 0.01, "teleport clears old pose samples")
	check(not avatar._label.fixed_size, "nametags use perspective size")
	var checker = load("res://mods/multiplayer/mp_updates.gd")
	check(checker.compare_versions("0.1.0-preview.10", "0.1.0-preview.2") > 0, "preview version numbers compare numerically")
	check(checker.compare_versions("0.1.0", "0.1.0-preview.99") > 0, "stable version sorts after preview")
	check(checker.parse_version("0.01.0").is_empty(), "invalid version rejected")
	mp.updater._consider([{"tag_name": "v0.1.0-preview.99"}, {"tag_name": "v0.1.0-preview.9"}, {"tag_name": "garbage"}], false)
	check(mp.updater.available == "0.1.0-preview.99" and mp.ui._update_btn.text in ["Скачать обновление", "Download update"], "update notification selects newest release")
	check(mp.updater.release_url.begins_with("https://github.com/GlebTikhiy/NeedleNet/releases/tag/"), "download target stays official repository")
	mp.updater._failed()
	check(not mp.updater.busy and not mp.ui._update_btn.disabled, "offline update failure permits retry")
	avatar.queue_free()
	print("NN_UI_RESULT ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

