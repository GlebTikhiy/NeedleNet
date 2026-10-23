extends SceneTree

var mp: Node
var role := OS.get_environment("NEEDLENET_ROLE")
var elapsed := 0.0
var report_tick := 0.0
var started := false
var world_started := false
var complete := false
var last_command := ""
var last_tool_id := 0
var connect_port := int(OS.get_environment("NEEDLENET_CONNECT_PORT")) if OS.get_environment("NEEDLENET_CONNECT_PORT") != "" else 27841

func _initialize() -> void:
	call_deferred("start")

func start() -> void:
	mp = root.get_node("MPMod")
	mp.my_name = role
	if role == "host":
		print("NN_HOST_RESULT ", mp.host(27841))
	else:
		print("NN_JOIN_RESULT ", mp.join("127.0.0.1", connect_port))
	started = true
	print("NN_STARTED ", role, " user=", OS.get_user_data_dir())

func _process(delta: float) -> bool:
	if not started:
		return false
	elapsed += delta
	report_tick += delta
	var command_path := "user://nn_command.json"
	if FileAccess.file_exists(command_path):
		var text := FileAccess.get_file_as_string(command_path)
		if text != last_command:
			last_command = text
			var command: Variant = JSON.parse_string(text)
			if command is Dictionary:
				if command.get("action") == "resync":
					if bool(command.get("corrupt", false)):
						var h: PackedFloat32Array = mp.world_sync.field.heights
						h[0] -= 0.5
						mp.world_sync.field.heights = h
					mp.request_resync()
				elif command.get("action") == "resync_timeout":
					mp._resync_pending = true
					mp._resync_seed = mp._outgoing_world_seed()
					mp._resync_deadline = Time.get_ticks_msec() - 1
					mp._check_resync_timeout()
				elif command.get("action") == "chat":
					mp.send_chat(str(command.get("text", "")))
				elif command.get("action") == "money" and mp.in_world():
					root.get_node("GameState").money += 17.0
					print("NN_MONEY_MUTATION")
				elif command.get("action") == "spawn_fixture" and mp.in_world():
					var kind := str(command.get("kind", "hay_wad"))
					var item: Node = mp.world_sync.props_sync.props.spawn(kind, Transform3D(Basis.IDENTITY, Vector3(13, 0.6, 6)), {"strands": 1000.0})
					var fixture := {"kind": kind, "id": int(item.get_meta("mp_id", 0)) if is_instance_valid(item) else 0}
					var out := FileAccess.open("user://nn_fixture.json", FileAccess.WRITE)
					out.store_string(JSON.stringify(fixture))
					out.close()
				elif command.get("action") == "carry_fixture" and mp.in_world():
					var item: Node = mp.world_sync.props_sync._by_id.get(int(command.get("prop", 0)))
					if is_instance_valid(item):
						mp.world_sync.player.global_position = item.global_position + Vector3(0.5, 0, 1)
						print("NN_CARRY_RESULT ", mp.world_sync.player.carry.take(item))
				elif command.get("action") == "drop_cargo" and mp.in_world():
					mp.world_sync.player.carry.drop_all()
				elif command.get("action") == "factory_line" and mp.in_world():
					for lane in 8:
						mp.world_sync.builds.add_conveyor(Vector3(-20 + lane * 1.4, 1, -10), Vector3(-20 + lane * 1.4, 1, 10), 500 + lane)
				elif command.get("action") == "factory_fill" and mp.in_world():
					for lane in 8:
						for index in 20:
							var at := Vector3(-20 + lane * 1.4, 1.5, -9 + index * 0.8)
							mp.world_sync.props_sync.props.spawn("hay_wad", Transform3D(Basis.IDENTITY, at), {"strands": 50})
				elif command.get("action") == "move" and mp.in_world():
					mp.world_sync.player.global_position.x += 2.0
					print("NN_MOVE_MUTATION")
				elif command.get("action") == "dig" and mp.in_world():
					var field: Node = mp.world_sync.field
					var h: PackedFloat32Array = field.heights
					var index := 0
					for i in h.size():
						if h[i] > h[index]:
							index = i
					h[index] -= 0.3
					field.heights = h
					var nv: int = field.get("_nv")
					field._touch_vertex(index % nv, index / nv)
					mp.world_sync._hay_cand[index] = true
					print("NN_DIG_MUTATION ", index)
				elif command.get("action") == "save" and mp.in_world():
					mp.world_sync.world.save_now()
					print("NN_SAVE_REQUESTED")
				elif command.get("action") == "drop_tool" and mp.in_world():
					var tools: Node = mp.world_sync.tools_sync
					print("NN_GRANT_TOOL ", tools.grant(1, "broom"))
					tools.request_drop("broom", false)
				elif command.get("action") == "pickup_tool" and mp.in_world():
					for item in mp.world_sync.props_sync._by_id.values():
						if is_instance_valid(item) and str(item.item_id) == "broom":
							last_tool_id = int(item.get_meta("mp_id", 0))
							mp.world_sync.player.global_position = item.global_position + Vector3(0, 0, 1)
							mp.world_sync.tools_sync.request_pickup(item)
							break
				elif command.get("action") == "repeat_pickup" and mp.in_world():
					var player: Node = mp.world_sync.player
					for attempt in 3:
						mp.world_sync.economy.request("tool_pickup", {"id": "broom", "item": last_tool_id, "body": player.global_transform, "camera": player.camera.global_transform})
				elif command.get("action") == "menu":
					change_scene_to_file(mp.MENU_SCENE)
				elif command.get("action") == "reload":
					root.get_node("SaveManager").begin_load(0)
					root.get_node("Loading").enter_scene(mp.GAME_SCENE)
				elif command.get("action") == "leave":
					mp.leave()
				elif command.get("action") == "rejoin":
					mp.join("127.0.0.1", connect_port)
	if role == "host" and not world_started and mp.players.size() == 4:
		world_started = true
		var saves = root.get_node("SaveManager")
		print("NN_NEW_WORLD ", saves.begin_new_game(0, true))
		change_scene_to_file(mp.GAME_SCENE)
	if report_tick > 3.0:
		report_tick = 0.0
		var state := {"role": role, "players": mp.players.size(), "phase": mp.phase, "world": mp.in_world()}
		if mp.in_world():
			state["avatars"] = mp.world_sync.avatars.size()
			state["seed"] = root.get_node("GameState").run_seed
			state["money"] = root.get_node("GameState").money
			state["heights"] = mp.world_sync.field.heights.size()
			var digest := HashingContext.new()
			digest.start(HashingContext.HASH_SHA256)
			digest.update(mp.world_sync.field.heights.to_byte_array())
			state["hay_hash"] = digest.finish().hex_encode()
			var heights_file := FileAccess.open("user://nn_heights.bin", FileAccess.WRITE)
			heights_file.store_buffer(mp.world_sync.field.heights.to_byte_array())
			heights_file.close()
			state["hay_sum"] = 0.0
			for height in mp.world_sync.field.heights:
				state["hay_sum"] += height
			state["saved"] = root.get_node("SaveManager").has_save(0)
			state["broom_owned"] = mp.world_sync.tools_sync._local().has("broom")
			var loose_brooms := 0
			for item in mp.world_sync.props_sync._by_id.values():
				if is_instance_valid(item) and str(item.item_id) == "broom":
					loose_brooms += 1
			state["loose_brooms"] = loose_brooms
			state["carrying"] = mp.world_sync.player.carry.is_carrying()
			var props_state := {}
			var props_sync: Node = mp.world_sync.props_sync
			for id in props_sync._by_id:
				var item: Node = props_sync._by_id[id]
				if is_instance_valid(item):
					var owner := int(props_sync._owner.get(id, 0))
					props_state[str(id)] = {"kind": str(item.item_id), "owner": mp.player_name(owner), "held": bool(props_sync._held.get(id, false)), "x": item.global_position.x, "y": item.global_position.y, "z": item.global_position.z, "epoch": int(props_sync._epoch.get(id, 0)), "strands": props_sync._state_of(item).get("strands", 0)}
			state["props"] = props_state
			var catalog := {}
			for kind in ["hay_wad", "hay_bale", "bale", "paper", "paper_roll", "paper_sheet", "briquette", "pellet"]:
				catalog[kind] = load("res://scripts/items/item_db.gd").has_item(kind)
			state["item_catalog"] = catalog
			state["conveyors"] = mp.world_sync.builds.conveyors.size()
			var records := []
			for path in mp.world_sync.world.find_children("*", "Node", true, false):
				if path.has_method("save_ends") and "records_props" in path and bool(path.records_props):
					for index in range(path.run.first(), path.run.first() + path.run.count()):
						var record: Dictionary = path.run.record(index)
						records.append({"seq": record.seq, "strands": record.strands, "s": record.s})
			state["belt_records"] = records
			state["position"] = var_to_str(mp.world_sync.player.global_position)
			state["position_x"] = mp.world_sync.player.global_position.x
			var poses := {}
			for id in mp.world_sync.avatars:
				poses[mp.player_name(id)] = var_to_str(mp.world_sync.avatars[id].global_position)
			state["poses"] = poses
			var pose_x := {}
			for id in mp.world_sync.avatars:
				pose_x[mp.player_name(id)] = mp.world_sync.avatars[id].global_position.x
			state["pose_x"] = pose_x
		state["resync_pending"] = mp._resync_pending
		state["status"] = mp.ui._status.text
		state["chat"] = mp.ui._chat_lines
		state["recent_chat"] = mp.ui._chat_recent.get_parsed_text()
		state["recent_visible"] = mp.ui._chat_recent.visible
		print("NN_STATE ", JSON.stringify(state))
		var f := FileAccess.open("user://nn_state.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(state))
		f.close()
	return false
