extends Node

signal patch_status(message: String)
signal patch_finished(updated_files: int)
signal patch_failed(message: String)

const PATCH_DIR := "user://patches"
const PATCH_DATA_DIR := "user://patches/data"
const LOCAL_MANIFEST_PATH := "user://patches/manifest.json"

var http_base_url := "https://paradise-rpg-server.onrender.com"
var patch_manifest_url := "https://paradise-rpg-server.onrender.com/patch/manifest"
var patch_enabled := true

var _http: HTTPRequest
var _manifest: Dictionary = {}
var _local_manifest: Dictionary = {}
var _queue: Array = []
var _updated_files := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_config()
	if not patch_enabled:
		return
	_http = HTTPRequest.new()
	add_child(_http)
	call_deferred("check_for_patches")

func check_for_patches() -> void:
	_ensure_dir(PATCH_DATA_DIR)
	_local_manifest = _read_json(LOCAL_MANIFEST_PATH)
	patch_status.emit("Verificando atualizacoes de dados...")
	_request(patch_manifest_url, Callable(self, "_on_manifest_loaded"))

func _load_config() -> void:
	var file := FileAccess.open("res://client/config/mmo_client_config.json", FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	http_base_url = str(parsed.get("http_base_url", http_base_url))
	patch_manifest_url = str(parsed.get("patch_manifest_url", http_base_url + "/patch/manifest"))
	patch_enabled = bool(parsed.get("patch_enabled", true))

func _on_manifest_loaded(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		patch_failed.emit("Nao foi possivel verificar atualizacoes.")
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY or not bool(parsed.get("ok", false)):
		patch_failed.emit("Manifesto de atualizacao invalido.")
		return
	_manifest = parsed
	_queue = _files_to_update(parsed.get("files", []))
	_updated_files = 0
	if _queue.is_empty():
		patch_status.emit("Dados do jogo atualizados.")
		patch_finished.emit(0)
		return
	patch_status.emit("Baixando dados do jogo...")
	_download_next_file()

func _files_to_update(files: Array) -> Array:
	var local_by_path := {}
	for entry in _local_manifest.get("files", []):
		if typeof(entry) == TYPE_DICTIONARY:
			local_by_path[str(entry.get("path", ""))] = str(entry.get("sha256", ""))
	var pending := []
	for entry in files:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var file_path := str(entry.get("path", ""))
		var remote_sha := str(entry.get("sha256", ""))
		if file_path.is_empty() or remote_sha.is_empty():
			continue
		var local_path := PATCH_DIR + "/" + file_path
		if local_by_path.get(file_path, "") == remote_sha and FileAccess.file_exists(local_path):
			continue
		pending.append(entry)
	return pending

func _download_next_file() -> void:
	if _queue.is_empty():
		_save_manifest()
		patch_status.emit("Atualizacao de dados concluida.")
		patch_finished.emit(_updated_files)
		return
	var entry: Dictionary = _queue.pop_front()
	var url := str(entry.get("url", ""))
	if url.begins_with("/"):
		url = http_base_url + url
	entry["_download_url"] = url
	_request(url, Callable(self, "_on_file_loaded").bind(entry))

func _on_file_loaded(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, entry: Dictionary) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		patch_failed.emit("Falha ao baixar " + str(entry.get("path", "")))
		_download_next_file()
		return
	var local_path := PATCH_DIR + "/" + str(entry.get("path", ""))
	_ensure_dir(local_path.get_base_dir())
	var file := FileAccess.open(local_path, FileAccess.WRITE)
	if file == null:
		patch_failed.emit("Falha ao salvar " + local_path)
		_download_next_file()
		return
	file.store_buffer(body)
	_updated_files += 1
	_download_next_file()

func _request(url: String, callback: Callable) -> void:
	if _http.request_completed.is_connected(callback):
		_http.request_completed.disconnect(callback)
	_http.request_completed.connect(callback, CONNECT_ONE_SHOT)
	var err := _http.request(url, ["Cache-Control: no-cache"], HTTPClient.METHOD_GET)
	if err != OK:
		patch_failed.emit("Falha HTTP: " + str(err))

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _save_manifest() -> void:
	_ensure_dir(PATCH_DIR)
	var file := FileAccess.open(LOCAL_MANIFEST_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_manifest, "\t"))

func _ensure_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
