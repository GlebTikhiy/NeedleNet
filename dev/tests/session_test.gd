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
var frame_samples: Array[float] = []
var factory_job := "idle"
var previous_frame_usec := 0
var last_command_id := 0
var production_nodes: Array[Node] = []
var production_events := {}
var connect_port := int(OS.get_environment("NEEDLENET_CONNECT_PORT")) if OS.get_environment("NEEDLENET_CONNECT_PORT") != "" else 27841

func _initialize() -> void:
	call_deferred("start")

func start() -> void:
	AudioServer.set_bus_mute(0, true)
	Engine.max_fps = 60
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
	var now_usec := Time.get_ticks_usec()
	if previous_frame_usec > 0:
		frame_samples.append((now_usec - previous_frame_usec) / 1000.0)
	previous_frame_usec = now_usec
	report_tick += delta
	var command_path := "user://nn_command.json"
	if FileAccess.file_exists(command_path):
		var text := FileAccess.get_file_as_string(command_path)
		if text != last_command:
			last_command = text
			var command: Variant = JSON.parse_string(text)
			if command is Dictionary:
				last_command_id = int(command.get("id", 0))
				if command.get("action") == "quit_test":
					quit(0)
				elif command.get("action") == "production_setup" and mp.in_world():
					production_setup()
				elif command.get("action") == "production_feed" and mp.in_world():
					production_feed(command)
				elif command.get("action") == "production_supply" and mp.in_world():
					production_supply()
				elif command.get("action") == "partial_belt_probe" and mp.in_world():
					partial_belt_probe()
				elif command.get("action") == "queued_belt_probe" and mp.in_world():
					partial_belt_probe(true)
				elif command.get("action") == "stress_view" and mp.in_world():
					if "intro" in mp.world_sync.world and is_instance_valid(mp.world_sync.world.intro):
						mp.world_sync.world.intro._finish()
					var camera := Camera3D.new()
					mp.world_sync.world.add_child(camera)
					camera.global_position = Vector3(-28, 70, 35)
					camera.look_at(Vector3(-28, 6, -28))
					camera.make_current()
					Engine.max_fps = 60
				elif command.get("action") == "capture_factory" and mp.in_world():
					capture_factory()
				elif command.get("action") == "stress_factory" and mp.in_world():
					stress_factory(int(command.get("belts", 128)), int(command.get("cargo", 1024)), bool(command.get("loops", false)))
				elif command.get("action") == "fund" and mp.in_world():
					root.get_node("GameState").money = 100000.0
				elif command.get("action") == "buy_tech" and mp.in_world():
					var tech: Node = root.get_node("Tech")
					for entry in ProjectSettings.get_global_class_list():
						if entry.class == "TechTree":
							var tree: Script = load(entry.path)
							print("NN_BELT_CARD ", tree.nodes().get("belt_speed"), " reason=", tech.can_buy("belt_speed"))
							for id in tree.ids():
								if tech.can_buy(id).get("ok", false):
									print("NN_TECH_BUY ", id, " ", tech.buy(id))
									break
				elif command.get("action") == "grant_guest" and mp.in_world():
					for pid in mp.players:
						if mp.player_name(pid) == "guest1":
							print("NN_GUEST_GRANT ", mp.world_sync.tools_sync.grant(pid, "broom"))
				elif command.get("action") == "inspect_native" and mp.in_world():
					var dump := {}
					for label in ["builds", "props", "tech"]:
						var target: Node = mp.world_sync.builds if label == "builds" else (mp.world_sync.props_sync.props if label == "props" else root.get_node("Tech"))
						var scripts := []
						var current: Script = target.get_script()
						while current != null:
							scripts.append({"path": current.resource_path, "source_length": current.get_source_code().length(), "methods": current.get_script_method_list()})
							current = current.get_base_script()
						dump[label] = scripts
					var file := FileAccess.open("user://native-api.json", FileAccess.WRITE)
					file.store_string(JSON.stringify(dump))
					file.close()
				elif command.get("action") == "resync":
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
					if bool(command.get("disable_autosave", false)) and "autosave_enabled" in mp.world_sync.world:
						mp.world_sync.world.autosave_enabled = false
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
		if OS.get_environment("NEEDLENET_RESTORE") == "1":
			print("NN_LOAD_WORLD ", saves.begin_load(0))
			root.get_node("Loading").enter_scene(mp.GAME_SCENE)
		else:
			print("NN_NEW_WORLD ", saves.begin_new_game(0, true))
			change_scene_to_file(mp.GAME_SCENE)
	if report_tick > 3.0:
		report_tick = 0.0
		var state := {"role": role, "players": mp.players.size(), "phase": mp.phase, "world": mp.in_world()}
		state["elapsed"] = elapsed
		state["last_command_id"] = last_command_id
		state["factory_job"] = factory_job
		frame_samples.sort()
		state["frame_p95_ms"] = frame_samples[int((frame_samples.size() - 1) * 0.95)] if not frame_samples.is_empty() else 0
		state["frame_max_ms"] = frame_samples.back() if not frame_samples.is_empty() else 0
		state["static_memory"] = OS.get_static_memory_usage()
		state["nodes"] = get_node_count()
		state["drawn_frames"] = Engine.get_frames_drawn()
		state["fps"] = Engine.get_frames_per_second()
		state["draw_calls"] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		state["audio_muted"] = AudioServer.is_bus_mute(0)
		frame_samples.clear()
		if mp.in_world():
			state["tech"] = root.get_node("Tech").ranks.duplicate()
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
			var machine_rows := {}
			var machine_runtime := {}
			for group in ["compressors", "pulpers", "papers", "briquette_presses", "wrappers", "pelletizers"]:
				if group in mp.world_sync.builds:
					var rows := []
					for machine in mp.world_sync.builds.get(group):
						if is_instance_valid(machine):
							rows.append(machine.to_dict())
						var runtime := {}
						for key in ["power", "power_blocked", "water", "water_blocked", "switched_off", "stored", "stored_strands", "_batch", "_press", "_wrap"]:
							if key in machine:
								runtime[key] = machine.get(key)
						machine_runtime[str(machine.get_instance_id())] = {"group": group, "values": runtime}
					machine_rows[group] = rows
			state["machines"] = machine_rows
			state["machine_runtime"] = machine_runtime
			state["production_events"] = production_events.duplicate()
			var records := []
			for path in mp.world_sync.world.find_children("*", "Node", true, false):
				if path.has_method("save_ends") and "records_props" in path and bool(path.records_props):
					var path_label := str(path.get_path())
					for index in range(path.run.first(), path.run.first() + path.run.count()):
						var record: Dictionary = path.run.record(index)
						records.append({"seq": record.seq, "strands": record.strands, "s": record.s, "path": path_label})
			state["belt_records"] = records
			state["cargo_strands"] = 0.0
			state["cargo_count"] = records.size() + props_state.size()
			var sequences := {}
			state["duplicate_belt_ids"] = 0
			state["duplicate_examples"] = []
			state["belt_position_sum"] = 0.0
			for record in records:
				state["cargo_strands"] += float(record.strands)
				state["belt_position_sum"] += float(record.s)
				if sequences.has(record.seq):
					state["duplicate_belt_ids"] += 1
					if state["duplicate_examples"].size() < 8:
						state["duplicate_examples"].append({"seq": record.seq, "paths": [sequences[record.seq].path, record.path]})
				sequences[record.seq] = record
			state["belt_strands"] = state["cargo_strands"]
			for item_state in props_state.values():
				state["cargo_strands"] += float(item_state.strands)
			state["belt_cargo_count"] = records.size()
			if "merged_record_moves" in mp.world_sync.belts_sync:
				state["merged_record_moves"] = mp.world_sync.belts_sync.merged_record_moves
			if OS.get_environment("NEEDLENET_COMPACT") == "1":
				state.erase("props")
				state.erase("belt_records")
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

func stress_point(index: int, end: bool, loops: bool) -> Vector3:
	if loops:
		var loop_id := index / 4
		var corner := (index + (1 if end else 0)) % 4
		var offsets := [Vector3(0, 0, 0), Vector3(0, 0, 4), Vector3(4, 0, 4), Vector3(4, 0, 0)]
		return Vector3(-55 + (loop_id % 8) * 7, 6, -55 + (loop_id / 8) * 7) + offsets[corner]
	var col := index % 16
	var row := index / 16
	return Vector3(-55 + col * 2.5, 1, -50 + row * 4 + (3 if end else 0))

func production_setup() -> void:
	var methods := ["add_compressor", "add_pulper", "add_paper", "add_briquette", "add_wrapper", "add_pelletizer"]
	var dump := {}
	for index in methods.size():
		var machine: Node = mp.world_sync.builds.call(methods[index], Vector3(-45 + (index % 3) * 12, 0, 22 + (index / 3) * 15), 0.0)
		production_nodes.append(machine)
		var entry := {"methods": [], "properties": {}, "constants": {}, "state": machine.to_dict(), "signals": machine.get_signal_list()}
		for signal_info in machine.get_signal_list():
			if signal_info.args.size() == 1 and signal_info.name in ["baled", "baled_record", "wrapped", "wrapped_record", "pressed", "pressed_record", "rolled", "rolled_record", "slabbed", "slabbed_record", "bricked"]:
				machine.connect(signal_info.name, _production_event.bind(methods[index], str(signal_info.name)))
		var script: Script = machine.get_script()
		while script != null:
			entry.methods.append_array(script.get_script_method_list())
			for key in script.get_script_constant_map():
				var value: Variant = script.get_script_constant_map()[key]
				if value is int or value is float:
					entry.constants[key] = value
			script = script.get_base_script()
		for property in machine.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				var value: Variant = machine.get(property.name)
				if value is int or value is float or value is Vector3 or value is bool:
					entry.properties[property.name] = value
		dump[methods[index]] = entry
	for entry in ProjectSettings.get_global_class_list():
		if entry.class == "BeltRun":
			dump["item_ids"] = load(entry.path).get_script_constant_map().get("ITEM_IDS", [])
	var file := FileAccess.open("user://production-api.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(dump))
	file.close()

func _production_event(_value: Variant, machine: String, event: String) -> void:
	var key := machine + ":" + event
	production_events[key] = int(production_events.get(key, 0)) + 1

func production_feed(command: Dictionary) -> void:
	var index := int(command.get("machine", 0))
	if index < 0 or index >= production_nodes.size():
		return
	var machine: Node = production_nodes[index]
	var at: Vector3 = machine.global_position + Vector3(0, 1.5, 0)
	var method := str(command.get("port", ""))
	if method != "" and machine.has_method(method):
		var point: Variant = machine.call(method)
		if point is Vector3:
			at = point + Vector3(0, 0.4, 0)
	var kind := str(command.get("kind", "hay_wad"))
	var count := int(command.get("count", 4))
	var amount := int(command.get("strands", 1000))
	if index == 3 and bool(command.get("native_batch", false)):
		var tech: Node = root.get_node("Tech")
		if kind == "eco_brick":
			count = maxi(2, 2 * int(tech.briquette_batch_bricks()))
			amount = int(tech.pellet_brick_strands())
		else:
			amount = maxi(120, int(tech.briquette_batch_strands()))
	for n in count:
		var state := {"strands": amount}
		if kind == "eco_brick":
			state["worth"] = 10.0
		mp.world_sync.props_sync.props.spawn(kind, Transform3D(Basis.IDENTITY, at + Vector3(0, n * 0.05, 0)), state)

func production_supply() -> void:
	var builds: Node = mp.world_sync.builds
	var poles: Array[Node] = []
	for row in 6:
		for col in 5:
			poles.append(builds.add_power_pole(Vector3(-45 + col * 6, 0, 8 + row * 6), 0.0))
	await process_frame
	for row in 6:
		for col in 5:
			var index := row * 5 + col
			var neighbors := []
			if col < 4:
				neighbors.append(index + 1)
			if row < 5:
				neighbors.append(index + 5)
			for next in neighbors:
				var joined: int = builds.join_poles(poles[index], poles[next])
				if joined < 0:
					print("NN_SUPPLY_WIRE_BLOCKED ", builds.wire_answer(poles[index], poles[next]))
	var machines: Array[Node] = []
	for col in 3:
		var generator: Node = builds.add_generator(Vector3(-45 + col * 12, 0, 12), 0.0)
		machines.append(generator)
		var at: Vector3 = generator.global_position + Vector3(0, 1, 0)
		for method in ["feed_point", "port_in", "_mouth"]:
			if generator.has_method(method):
				var point: Variant = generator.call(method)
				if point is Vector3:
					at = point + Vector3(0, 0.4, 0)
					break
		for n in 4:
			mp.world_sync.props_sync.props.spawn("eco_brick", Transform3D(Basis.IDENTITY, at + Vector3(0, n * 0.1, 0)), {"strands": 5000, "worth": 1000.0})
	var pump: Node = builds.add_borehole(Vector3(-33, 0, 10), 0.0)
	machines.append(pump)
	var pulper: Node = production_nodes[1]
	if pump.has_method("water_port") and pulper.has_method("water_port"):
		var start: Variant = pump.call("water_port")
		var end: Variant = pulper.call("water_port")
		if start is Vector3 and end is Vector3:
			builds.add_water_main(start, end, 9000)
	var dump := {}
	for machine in machines:
		var data := {"state": machine.to_dict(), "methods": [], "ports": {}}
		var script: Script = machine.get_script()
		while script != null:
			data.methods.append_array(script.get_script_method_list())
			script = script.get_base_script()
		for method in ["port_in", "feed_point", "_mouth", "power_ports", "water_ports", "water_port"]:
			if machine.has_method(method):
				data.ports[method] = machine.call(method)
		dump[str(machine.name)] = data
	var file := FileAccess.open("user://production-supply.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(dump))
	file.close()

func capture_factory() -> void:
	await RenderingServer.frame_post_draw
	print("NN_FACTORY_SCREENSHOT ", root.get_texture().get_image().save_png("user://stress-factory.png"))

func partial_belt_probe(queued: bool = false) -> void:
	var paths := []
	var source: Node = null
	for path in mp.world_sync.world.find_children("*", "Node", true, false):
		if path.has_method("save_ends") and "records_props" in path and path.records_props:
			paths.append(path)
			if source == null and path.run.count() > 0:
				source = path
	if source == null or paths.size() < 2:
		return
	var target: Node = paths[0] if paths[0] != source else paths[1]
	var rows := []
	for index in range(source.run.first(), source.run.first() + source.run.count()):
		var row: Dictionary = source.run.record(index)
		row["gap"] = source.run.gap_of(index)
		rows.append(row)
	var routes: Script = load("res://mods/multiplayer/mp_belt_routes.gd")
	var ends: PackedVector3Array = source.save_ends()
	var entry := {"a": ends[0], "b": ends[1], "line": source._line, "owner": routes.owner_key(mp.world_sync, source), "records": rows}
	var seq: int = rows[0].seq
	# Reproduce a predicted seam transfer before the older source update arrives.
	for path in paths:
		for index in range(path.run.first() + path.run.count() - 1, path.run.first() - 1, -1):
			if path.run.seq_of(index) == seq:
				path.run.remove_at(index)
	var prediction: Dictionary = rows[0].duplicate(true)
	prediction["s"] = 0.0
	routes.restore(target, [prediction])
	var accepted := false
	var invalid_rejected := false
	if queued:
		var target_ends: PackedVector3Array = target.save_ends()
		var next_entry := {"a": target_ends[0], "b": target_ends[1], "line": target._line, "owner": routes.owner_key(mp.world_sync, target), "records": [prediction]}
		var service: Node = mp.world_sync.belts_sync
		invalid_rejected = not service._apply_belts([entry, next_entry], true)
		service._pending_snapshot = null
		service._queue_belts([entry], [], true)
		service._queue_belts([next_entry], [], false)
		var payload: Dictionary = service._pending_snapshot
		accepted = service._apply_belts(payload.paths, payload.full)
		service._pending_snapshot = null
	else:
		accepted = mp.world_sync.belts_sync._apply_belts([entry], false)
	var copies := 0
	for path in paths:
		for index in range(path.run.first(), path.run.first() + path.run.count()):
			if path.run.seq_of(index) == seq:
				copies += 1
	var file := FileAccess.open("user://queued-belt-probe.json" if queued else "user://partial-belt-probe.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"accepted": accepted, "copies": copies, "seq": seq, "invalid_rejected": invalid_rejected}))
	file.close()

func stress_factory(belts: int, cargo: int, loops: bool = false) -> void:
	factory_job = "building"
	var world: Node = mp.world_sync
	# Independent native belts with unique line identities, inside the field.
	for index in belts:
		if not is_instance_valid(world):
			factory_job = "aborted"
			return
		world.builds.add_conveyor(stress_point(index, false, loops), stress_point(index, true, loops), 1000 + (index / 4 if loops else index))
		if index % 16 == 15:
			await process_frame
	factory_job = "spawning"
	for index in cargo:
		if not is_instance_valid(world):
			factory_job = "aborted"
			return
		var belt := index % belts
		var at := stress_point(belt, false, loops).lerp(stress_point(belt, true, loops), 0.15 + (index / belts) * 0.04) + Vector3(0, 0.5, 0)
		world.props_sync.props.spawn("hay_wad", Transform3D(Basis.IDENTITY, at), {"strands": 50})
		if index % 16 == 15:
			await process_frame
	factory_job = "done"
