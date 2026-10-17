extends Node
## Generates role images sequentially, then returns one atomic artwork revision.
## Network calls happen here, never while a preview is being built.

signal progress(message: String, completed: int, total: int)

const Generator = preload("res://scripts/kit_generator.gd")
const Client = preload("res://scripts/comfy_client.gd")
const AIArt = preload("res://scripts/ai_art.gd")
const ROLES = ["panel", "banner", "button", "bar_frame", "fill_health", "fill_mana", "slot",
	"icon_sword", "icon_shield", "icon_potion", "icon_heart", "icon_mana", "icon_gear",
	"icon_bag", "icon_arrow", "icon_star", "icon_coin", "icon_scroll", "icon_close"]
const NEGATIVE_PROMPT = "text, letters, words, numbers, digits, watermark, logo, signature, labels, typography, screenshot, game scene, landscape, character portrait, hands, perspective, isometric view, multiple objects, contact sheet, checkerboard background, cropped edges, busy center"

class PendingFrame extends RefCounted:
	signal finished
	var done = false

	func resolve() -> void:
		if done:
			return
		done = true
		finished.emit()

# Public so a lightweight local client can be supplied by an integration test.
var client: Node
var busy = false
var _cancelled = false
var _completed = 0
var _total = 0
var _active_role = ""
var _job_folder = ""
var _job_files: Array[String] = []
var _pending_frame: PendingFrame

func probe(endpoint: String) -> Dictionary:
	if busy:
		return {"ok": false, "checkpoints": [], "error": "Artwork generation is already running. Cancel it or wait before connecting again."}
	if not is_inside_tree():
		return {"ok": false, "checkpoints": [], "error": "Add the artwork pipeline to the scene tree before connecting."}
	busy = true
	_cancelled = false
	_completed = 0
	_total = 0
	_active_role = ""
	_ensure_client()
	var result: Dictionary = await client.probe_server(endpoint)
	busy = false
	return result

func generate(config: Dictionary, endpoint: String, checkpoint: String, prompt: String, component: String = "", steps: int = 12) -> Dictionary:
	if busy:
		return {"ok": false, "error": "Another artwork job is already running. Wait for it to finish or cancel it."}
	if not is_inside_tree():
		return {"ok": false, "error": "Add the artwork pipeline to the scene tree before generating."}
	var brief = prompt.strip_edges()
	var model = checkpoint.strip_edges()
	if brief.is_empty() or brief.length() > 4000:
		return {"ok": false, "error": "Describe the artwork using between 1 and 4,000 characters."}
	if model.is_empty() or model.length() > 1024:
		return {"ok": false, "error": "Choose an installed checkpoint from the local ComfyUI connection."}
	if steps < 1 or steps > 50:
		return {"ok": false, "error": "Choose between 1 and 50 sampling steps. Start with 12 on an 8 GB GPU."}
	if config.get("mode", "") != "kit":
		return {"ok": false, "error": "Create a fantasy UI kit before generating its artwork."}
	# A snapshot keeps edits, preview rebuilds, failure, and cancellation isolated
	# from the currently applied config throughout the asynchronous operation.
	var snapshot: Dictionary = config.duplicate(true)
	var selected = component.strip_edges()
	busy = true
	_cancelled = false
	_completed = 0
	_total = 0
	_active_role = ""
	_job_folder = ""
	_job_files.clear()
	progress.emit("Finding the artwork roles used by this kit…", 0, 0)
	if not await _wait_frame():
		return _fail(_cancel_message(), true)
	var roles = collect_roles(snapshot, selected)
	if roles.is_empty():
		return _fail("Choose a kit component before generating selected artwork." if not selected.is_empty() else "This kit has no artwork roles to generate.")
	_total = roles.size()
	_ensure_client()
	var job_id = "%d_%d_%08x" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec(), randi()]
	_job_folder = ProjectSettings.globalize_path("user://ai_art/" + job_id)
	if DirAccess.dir_exists_absolute(_job_folder) or FileAccess.file_exists(_job_folder):
		_job_folder = ""
		return _fail("Could not create a unique artwork cache folder. Try generating again.")
	var error = DirAccess.make_dir_recursive_absolute(_job_folder)
	if error != OK:
		_job_folder = ""
		return _fail("Could not create the local artwork cache (error %d)." % error)
	var base_seed = randi_range(0, 2147483647)
	var assets: Dictionary = {}
	for index in range(roles.size()):
		if _cancelled:
			return _fail(_cancel_message(), true)
		var role: String = roles[index]
		_active_role = _role_name(role)
		var size = _image_size(role)
		var role_prompt = _make_prompt(snapshot, brief, role)
		var seed_value = posmod(base_seed + int(role.hash()), 2147483647)
		progress.emit("Generating %s (%d of %d)…" % [_active_role, index + 1, _total], _completed, _total)
		if _cancelled:
			return _fail(_cancel_message(), true)
		# One request, batch size one, at a time. Button hover/pressed/disabled
		# variants are derived locally from this role's single normal image.
		var result: Dictionary = await client.generate_image(endpoint, model, role_prompt, NEGATIVE_PROMPT, seed_value, size.x, size.y, steps)
		if _cancelled or bool(result.get("cancelled", false)):
			return _fail(_cancel_message(), true)
		if not result.get("ok", false):
			return _fail("Could not generate %s. %s" % [_active_role, str(result.get("error", "Check the local ComfyUI console."))])
		var image: Image = result.get("image")
		if image == null or image.is_empty():
			return _fail("ComfyUI returned no usable image for %s." % _active_role)
		progress.emit("Preparing the transparent %s artwork…" % _active_role, _completed, _total)
		if not await _wait_frame():
			return _fail(_cancel_message(), true)
		var prepared: Dictionary = AIArt.prepare_image(image, role)
		if not prepared.get("ok", false):
			return _fail("Could not prepare %s. %s" % [_active_role, str(prepared.get("error", "Try a simpler isolated UI piece on a pure magenta background."))])
		var processed: Image = prepared.get("image")
		if processed == null or processed.is_empty():
			return _fail("The prepared %s image is empty. Try generating again." % _active_role)
		var filename = _job_folder.path_join(role + ".png")
		_job_files.append(filename)
		error = processed.save_png(filename)
		if error != OK:
			return _fail("Could not save the generated %s image (error %d)." % [_active_role, error])
		var sha256 = FileAccess.get_sha256(filename)
		if sha256.is_empty():
			return _fail("Could not verify the cached %s image." % _active_role)
		assets[role] = {
			"path": filename, "sha256": sha256, "prompt": role_prompt,
			"brief": brief, "checkpoint": model, "seed": seed_value,
			"width": processed.get_width(), "height": processed.get_height(),
			"requested_width": size.x, "requested_height": size.y, "steps": steps,
			"background_removed": bool(prepared.get("background_removed", false)),
			"job_id": job_id, "prompt_id": str(result.get("prompt_id", "")),
		}
		# No image is needed beyond the save. Release both image references and
		# their response dictionaries before progress callbacks can close the app.
		image = null
		processed = null
		result = {}
		prepared = {}
		_completed += 1
		progress.emit("Prepared %s (%d of %d)." % [_active_role, _completed, _total], _completed, _total)
		if not await _wait_frame():
			return _fail(_cancel_message(), true)
	if _cancelled:
		return _fail(_cancel_message(), true)
	var previous: Dictionary = snapshot.get("ai", {})
	var ai: Dictionary = previous.duplicate(true) if not selected.is_empty() else {}
	ai.enabled = true
	ai.prompt = brief
	ai.checkpoint = model
	ai.seed = previous.get("seed", base_seed) if not selected.is_empty() else base_seed
	ai.revision = int(previous.get("revision", 0)) + 1
	if selected.is_empty():
		ai.assets = assets
		ai.component_assets = {}
	else:
		if not ai.get("assets") is Dictionary:
			ai.assets = {}
		if not ai.get("component_assets") is Dictionary:
			ai.component_assets = {}
		ai.component_assets[selected] = assets
	ai.last_job = {"id": job_id, "component": selected, "seed": base_seed,
		"prompt": brief, "checkpoint": model, "steps": steps,
		"roles": roles, "created_at_utc": Time.get_datetime_string_from_system(true),
		"reproducibility": "Seeds and prompts record provenance; model output can vary between hardware and server versions."}
	var manifest_path = _job_folder.path_join("generation_manifest.json")
	_job_files.append(manifest_path)
	var file = FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null:
		return _fail("Could not save the local generation manifest. The current kit artwork was kept.")
	file.store_string(JSON.stringify({"generator": "UI Forge local artwork", "job": ai.last_job, "assets": assets}, "\t"))
	file.flush()
	var manifest_error = file.get_error()
	file.close()
	if manifest_error != OK:
		return _fail("Could not finish saving the local generation manifest (error %d). The current kit artwork was kept." % manifest_error)
	# Successful files remain available for undo, later previews, and export.
	_job_folder = ""
	_job_files.clear()
	_active_role = ""
	busy = false
	progress.emit("Artwork is ready. All %d images were prepared locally." % _total, _completed, _total)
	return {"ok": true, "ai": ai, "error": ""}

func cancel() -> void:
	if not busy:
		return
	_cancelled = true
	# Resolve local waits during teardown instead of leaving a function state
	# connected to a later SceneTree frame after its owner has been freed.
	_remove_job_files()
	var pending = _pending_frame
	if is_instance_valid(client) and client.has_method("cancel"):
		client.cancel()
	if pending != null:
		pending.resolve()

func _wait_frame() -> bool:
	# A progress handler may already have cancelled or freed this node before
	# control returns here, so never create a new waiter after cancellation.
	if _cancelled or not is_inside_tree():
		return false
	var pending = PendingFrame.new()
	_pending_frame = pending
	var tree = get_tree()
	var advance: Callable = pending.resolve
	tree.process_frame.connect(advance, CONNECT_ONE_SHOT)
	if not pending.done:
		await pending.finished
	if tree.process_frame.is_connected(advance):
		tree.process_frame.disconnect(advance)
	if _pending_frame == pending:
		_pending_frame = null
	return not _cancelled and is_inside_tree()

static func collect_roles(config: Dictionary, component: String = "") -> Array[String]:
	var snapshot: Dictionary = config.duplicate(true)
	# Missing or disabled AI images must not hide roles used by a component.
	snapshot.ai = {"enabled": false}
	var found: Dictionary = {}
	var seen: Dictionary = {}
	for page in range(Generator.PAGES.size()):
		var root: Control = Generator.build(snapshot, page)
		for child in root.get_children():
			var canonical = str(child.get_meta("kit_component", str(child.name)))
			if component.is_empty() or canonical == component:
				_find_node_roles(child, found, seen)
		root.free()
	var roles: Array[String] = []
	for role in ROLES:
		if found.has(role):
			roles.append(role)
	return roles

static func _find_node_roles(node: Node, found: Dictionary, seen: Dictionary) -> void:
	for property in node.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_STORAGE:
			_find_value_roles(node.get(property.name), found, seen)
	for child in node.get_children():
		_find_node_roles(child, found, seen)

static func _find_value_roles(value: Variant, found: Dictionary, seen: Dictionary) -> void:
	if value is Resource:
		if value is Texture2D:
			var role = str(value.get_meta("kit_art_role", ""))
			if role in ROLES:
				found[role] = true
		var id = value.get_instance_id()
		if seen.has(id):
			return
		seen[id] = true
		for property in value.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_STORAGE:
				_find_value_roles(value.get(property.name), found, seen)
	elif value is Array:
		for entry in value:
			_find_value_roles(entry, found, seen)
	elif value is Dictionary:
		for entry in value.values():
			_find_value_roles(entry, found, seen)

func _ensure_client() -> void:
	if not is_instance_valid(client):
		client = Client.new()
	if client.get_parent() == null:
		add_child(client)
	if client.has_signal("progress") and not client.is_connected("progress", _client_progress):
		client.connect("progress", _client_progress)

func _client_progress(message: String) -> void:
	var detail = message if _active_role.is_empty() else "%s: %s" % [_active_role.capitalize(), message]
	progress.emit(detail, _completed, _total)

static func _image_size(role: String) -> Vector2i:
	if role == "panel":
		return Vector2i(768, 768)
	if role.begins_with("icon_") or role == "slot":
		return Vector2i(512, 512)
	return Vector2i(1024, 512)

static func _make_prompt(config: Dictionary, brief: String, role: String) -> String:
	var kit: Dictionary = config.get("kit", {})
	var style = "crisp medieval pixel art, limited color palette, deliberate pixel clusters" if config.get("style", "") == "Medieval pixel" else "rich hand-painted fantasy game artwork, carefully illustrated carved details"
	var shared = "%s. Coordinated game UI asset collection. %s. Material: %s. Accent color #%s. %s ornaments. Consistent lighting from upper left, front-on orthographic view, one isolated piece, complete silhouette inside the image with margin. No text, letters, words, numbers, logos, or watermark. Flat pure magenta #ff00ff background only, no scenery or checkerboard." % [brief, style, str(kit.get("material", "Wood")), str(config.get("accent", "ecc17b")).trim_prefix("#"), str(kit.get("ornaments", "Balanced")).to_lower()]
	var description: String
	match role:
		"panel": description = "One rectangular empty game UI panel. A decorated outer border and corner ornaments surround a large calm blank center reserved for editable game text. Keep decoration along the perimeter."
		"banner": description = "One wide horizontal fantasy title banner with a complete ornate outer border and a large quiet empty center for editable text. No writing."
		"button": description = "One wide horizontal blank game menu button in its normal unpressed state, with a crafted beveled border and quiet empty center. No symbol or writing."
		"bar_frame": description = "One long horizontal empty health-bar frame, decorated outside, with a wide plain dark center that can hold a separate progress fill. No gauge marks or numbers."
		"fill_health": description = "One long horizontal solid red ruby or red liquid health-bar fill, luminous top highlight, no frame, no icon, no lettering."
		"fill_mana": description = "One long horizontal solid blue crystal or blue liquid mana-bar fill, luminous top highlight, no frame, no icon, no lettering."
		"slot": description = "One square empty inventory slot frame with a dark quiet inset center, complete border, no object inside."
		"icon_sword": description = "One clear fantasy sword inventory icon, full blade and hilt visible, diagonal orientation."
		"icon_shield": description = "One clear heraldic shield inventory icon with an original decorative crest, no letters."
		"icon_potion": description = "One clear small glass bottle of red healing potion inventory icon, complete stopper and bottle visible."
		"icon_heart": description = "One clear red ruby heart health icon, recognizable heart silhouette."
		"icon_mana": description = "One clear blue magical crystal mana icon, faceted crystal silhouette."
		"icon_gear": description = "One clear mechanical cogwheel settings icon with a central opening."
		"icon_bag": description = "One clear tied leather adventurer's pouch inventory icon."
		"icon_arrow": description = "One clear right-pointing navigation arrow icon, simple readable silhouette."
		"icon_star": description = "One clear five-pointed golden star quest marker icon."
		"icon_coin": description = "One clear golden coin currency icon with a decorative symbol, no letters or numbers."
		"icon_scroll": description = "One clear rolled parchment scroll quest icon, blank parchment without writing."
		"icon_close": description = "One clear X-shaped close icon, thick diagonal crossed strokes made from the same decorative material."
		_: description = "One empty coordinated game UI piece with a quiet blank center."
	return shared + "\n" + description

static func _role_name(role: String) -> String:
	return role.trim_prefix("icon_").replace("_", " ") + (" icon" if role.begins_with("icon_") else "")

func _fail(message: String, cancelled: bool = false) -> Dictionary:
	_remove_job_files()
	_active_role = ""
	busy = false
	return {"ok": false, "error": message, "cancelled": cancelled}

func _remove_job_files() -> void:
	for filename in _job_files:
		if FileAccess.file_exists(filename):
			DirAccess.remove_absolute(filename)
	if not _job_folder.is_empty() and DirAccess.dir_exists_absolute(_job_folder):
		DirAccess.remove_absolute(_job_folder)
	_job_files.clear()
	_job_folder = ""

static func _cancel_message() -> String:
	return "Artwork generation was cancelled. The current kit was kept. A queued ComfyUI image may still finish; other server jobs were not interrupted."

func _exit_tree() -> void:
	cancel()
