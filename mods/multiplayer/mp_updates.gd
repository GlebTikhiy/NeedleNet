extends Node

const API := "https://api.github.com/repos/GlebTikhiy/NeedleNet/releases?per_page=20"
const RELEASES := "https://github.com/GlebTikhiy/NeedleNet/releases"
const CACHE := "user://needlenet_updates.json"
var mp: Node
var available := ""
var release_url := RELEASES
var status := ""
var busy := false
var _http: HTTPRequest


static func _numeric(value: String) -> bool:
	return value.is_valid_int() and not value.begins_with("-")


static func parse_version(value: String) -> Array:
	var regex := RegEx.new()
	regex.compile("^v?([0-9]+)\\.([0-9]+)\\.([0-9]+)(?:-([0-9A-Za-z.-]+))?$")
	var match := regex.search(value)
	if match == null:
		return []
	var core := []
	for index in [1, 2, 3]:
		var part := match.get_string(index)
		if part.length() > 9 or (part.length() > 1 and part.begins_with("0")):
			return []
		core.append(int(part))
	var pre := match.get_string(4)
	var identifiers := pre.split(".") if not pre.is_empty() else PackedStringArray()
	for part in identifiers:
		if part.is_empty() or (_numeric(part) and part.length() > 1 and part.begins_with("0")):
			return []
	return [core, identifiers]


static func compare_versions(left: String, right: String) -> int:
	var a := parse_version(left)
	var b := parse_version(right)
	if a.is_empty() or b.is_empty():
		return 0
	for index in 3:
		if a[0][index] != b[0][index]:
			return 1 if a[0][index] > b[0][index] else -1
	if a[1].is_empty() != b[1].is_empty():
		return 1 if a[1].is_empty() else -1
	for index in mini(a[1].size(), b[1].size()):
		var x: String = a[1][index]
		var y: String = b[1][index]
		if x == y:
			continue
		if _numeric(x) and _numeric(y):
			if x.length() != y.length():
				return 1 if x.length() > y.length() else -1
		elif _numeric(x) != _numeric(y):
			return -1 if _numeric(x) else 1
		return 1 if x > y else -1
	return signi(a[1].size() - b[1].size())


func _text(en: String, ru: String) -> String:
	return ru if TranslationServer.get_locale().begins_with("ru") else en


func start() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 10.0
	_http.body_size_limit = 524288
	_http.max_redirects = 0
	add_child(_http)
	_http.request_completed.connect(_completed)
	if OS.get_environment("NEEDLENET_TEST") == "1":
		return
	if FileAccess.file_exists(CACHE):
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(CACHE))
		if saved is Dictionary:
			var age := Time.get_unix_time_from_system() - float(saved.get("checked_at", 0))
			if age >= 0.0 and age < 3600.0:
				_consider(saved.get("releases", []), false)
				return
	check(false)


func check(_manual := true) -> void:
	if busy or _http == null:
		return
	busy = true
	status = _text("Checking for updates…", "Проверяю обновления…")
	mp.ui.refresh_updates()
	var error := _http.request(API, PackedStringArray(["Accept: application/vnd.github+json", "User-Agent: NeedleNet/" + mp.VERSION]))
	if error != OK:
		_failed()


func _failed() -> void:
	busy = false
	status = _text("Update check unavailable. You can retry.", "Не удалось проверить обновления. Можно повторить.")
	mp.ui.refresh_updates()


func _completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	busy = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_failed()
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not data is Array:
		_failed()
		return
	var releases := []
	for entry in data:
		if entry is Dictionary and not bool(entry.get("draft", false)) and not parse_version(str(entry.get("tag_name", ""))).is_empty():
			releases.append({"tag_name": str(entry.tag_name)})
	var file := FileAccess.open(CACHE, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"checked_at": Time.get_unix_time_from_system(), "releases": releases}))
	_consider(releases, true)


func _consider(releases: Variant, announce: bool) -> void:
	available = ""
	release_url = RELEASES
	if releases is Array:
		for entry in releases:
			if not entry is Dictionary:
				continue
			var tag := str(entry.get("tag_name", ""))
			if parse_version(tag).is_empty() or compare_versions(tag, mp.VERSION) <= 0:
				continue
			if available.is_empty() or compare_versions(tag, available) > 0:
				available = tag.trim_prefix("v")
				release_url = RELEASES + "/tag/" + tag.uri_encode()
	status = (_text("Update available: %s", "Доступно обновление: %s") % available) if not available.is_empty() else (_text("Installed: %s", "Установлена версия: %s") % mp.VERSION)
	mp.ui.refresh_updates()
	if announce and not available.is_empty():
		mp.ui.notify(status)


func open_or_check() -> void:
	if available.is_empty():
		check(true)
	else:
		OS.shell_open(release_url)
