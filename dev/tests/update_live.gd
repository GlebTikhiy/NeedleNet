extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var mp: Node = root.get_node("MPMod")
	await process_frame
	mp.updater.check(true)
	while mp.updater.busy:
		await process_frame
	print("NN_UPDATES_LIVE ", mp.updater.status)
	var ok: bool = mp.updater.status.begins_with("Installed:") or mp.updater.status.begins_with("Установлена") or not mp.updater.available.is_empty()
	print("NN_UPDATES_RESULT ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
