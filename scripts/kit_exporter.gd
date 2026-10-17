extends RefCounted

const Generator = preload("res://scripts/kit_generator.gd")
const SCENE_FILES = ["menu.tscn", "hud.tscn", "components.tscn"]

## Export every page as native controls with shared, portable image resources.
static func export_kit(config: Dictionary, selected_page: int, parent_directory: String) -> Dictionary:
	if not DirAccess.dir_exists_absolute(parent_directory):
		return {"ok": false, "error": "Choose an existing, writable export folder."}
	var slug = str(config.get("style", "fantasy")).to_lower().replace(" ", "_").replace("-", "_")
	var base = parent_directory.path_join("uiforge_kit_" + slug)
	var folder = base
	var suffix = 2
	while DirAccess.dir_exists_absolute(folder) or FileAccess.file_exists(folder):
		folder = base + "_%d" % suffix
		suffix += 1
	var error = DirAccess.make_dir_recursive_absolute(folder.path_join("art"))
	if error != OK:
		return {"ok": false, "error": "Could not create the kit export folder (error %d)." % error}
	# Virtual paths make Godot serialize textures as external resources, including
	# textures inside Theme and StyleBoxTexture resources. Only cloned resources
	# receive these paths; the preview and its cached artwork remain untouched.
	var state = {
		"folder": folder,
		"prefix": "res://__uiforge_kit_export_%d/" % Time.get_ticks_usec(),
		"resources": {},
		"images": {},
		"error": "",
	}
	var shared_theme: Theme = null
	var scenes: Dictionary = {}
	for page in range(Generator.PAGES.size()):
		var elements: Control = Generator.build(config, page)
		_copy_node_resources(elements, str(Generator.PAGES[page]).to_lower(), state)
		if not str(state.error).is_empty():
			elements.free()
			_remove_partial(folder)
			return {"ok": false, "error": state.error}
		if shared_theme == null:
			shared_theme = elements.theme
			if shared_theme == null:
				elements.free()
				_remove_partial(folder)
				return {"ok": false, "error": "The generated kit has no shared theme."}
			error = ResourceSaver.save(shared_theme, folder.path_join("kit_theme.tres"))
			if error == OK:
				error = _finalize_paths(folder.path_join("kit_theme.tres"), state.prefix)
			if error != OK:
				elements.free()
				_remove_partial(folder)
				return {"ok": false, "error": "Could not save the kit theme (error %d)." % error}
			shared_theme.take_over_path(state.prefix + "kit_theme.tres")
		elements.theme = shared_theme
		var scene_root = _wrap(elements, str(Generator.PAGES[page]), config)
		var packed = PackedScene.new()
		error = packed.pack(scene_root)
		var scene_path = folder.path_join(SCENE_FILES[page])
		if error == OK:
			error = ResourceSaver.save(packed, scene_path)
		scene_root.free()
		if error == OK:
			error = _finalize_paths(scene_path, state.prefix)
		if error != OK:
			_remove_partial(folder)
			return {"ok": false, "error": "Could not save the %s scene (error %d)." % [Generator.PAGES[page], error]}
		scenes[Generator.PAGES[page]] = scene_path
	var manifest: Dictionary = config.duplicate(true)
	var resolution: Vector2i = config.get("resolution", Vector2i(1920, 1080))
	manifest.resolution = {"width": resolution.x, "height": resolution.y}
	manifest.pages = Generator.PAGES.duplicate()
	manifest.selected_page = clampi(selected_page, 0, Generator.PAGES.size() - 1)
	manifest.generator = "UI Forge fantasy kit"
	if manifest.get("ai") is Dictionary:
		manifest.ai = _portable_ai_provenance(manifest.ai)
	manifest.positions = {}
	for page in config.get("positions", {}):
		manifest.positions[page] = {}
		for component in config.positions[page]:
			var at: Vector2 = config.positions[page][component]
			manifest.positions[page][component] = {"x": at.x, "y": at.y}
	var files = {
		"preset.json": JSON.stringify(manifest, "\t"),
		"README.md": _instructions(config),
	}
	for filename in files:
		var file = FileAccess.open(folder.path_join(filename), FileAccess.WRITE)
		if file == null:
			_remove_partial(folder)
			return {"ok": false, "error": "Could not write the kit export instructions."}
		file.store_string(files[filename])
		file.close()
	return {
		"ok": true,
		"path": folder,
		"scene": folder.path_join(SCENE_FILES[clampi(selected_page, 0, SCENE_FILES.size() - 1)]),
		"scenes": scenes,
	}

static func _wrap(elements: Control, page_name: String, config: Dictionary) -> Control:
	var scene_root = Control.new()
	scene_root.name = page_name
	scene_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pixel = config.get("style", "") == "Medieval pixel"
	if pixel:
		scene_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var scaler = AspectRatioContainer.new()
	scaler.name = "Canvas"
	scaler.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scaler.ratio = 16.0 / 9.0
	scaler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene_root.add_child(scaler)
	var viewport_container = SubViewportContainer.new()
	viewport_container.name = "Viewport"
	viewport_container.stretch = true
	# Menus retain normal button input through the scaling viewport.
	viewport_container.mouse_filter = Control.MOUSE_FILTER_PASS
	scaler.add_child(viewport_container)
	var viewport = SubViewport.new()
	viewport.name = "Design"
	viewport.size = Vector2i(1280, 720)
	viewport.size_2d_override = Vector2i(1280, 720)
	viewport.size_2d_override_stretch = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if pixel:
		viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport_container.add_child(viewport)
	elements.name = "Elements"
	viewport.add_child(elements)
	_assign_owners(scene_root, scene_root)
	return scene_root

static func _assign_owners(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_assign_owners(child, owner)

static func _copy_node_resources(node: Node, context: String, state: Dictionary) -> void:
	for property in node.get_property_list():
		if not int(property.usage) & PROPERTY_USAGE_STORAGE:
			continue
		var name: String = property.name
		var value: Variant = node.get(name)
		if value is Resource or value is Array or value is Dictionary:
			node.set(name, _copy_value(value, context + "_" + name, state))
	for child in node.get_children():
		_copy_node_resources(child, context + "_" + str(child.name), state)

static func _copy_value(value: Variant, context: String, state: Dictionary) -> Variant:
	if value is Resource:
		return _copy_resource(value, context, state)
	if value is Array:
		var array: Array = value.duplicate(false)
		for index in range(array.size()):
			array[index] = _copy_value(array[index], context + "_%d" % index, state)
		return array
	if value is Dictionary:
		var dictionary: Dictionary = value.duplicate(false)
		for key in dictionary:
			dictionary[key] = _copy_value(dictionary[key], context + "_" + str(key), state)
		return dictionary
	return value

static func _copy_resource(original: Resource, context: String, state: Dictionary) -> Resource:
	var id = original.get_instance_id()
	if state.resources.has(id):
		return state.resources[id]
	if original is Texture2D:
		var image: Image = original.get_image()
		if image == null or image.is_empty():
			state.error = "Could not read the generated texture for %s." % context
			return null
		var hash = HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(("%d/%d/%d/" % [image.get_width(), image.get_height(), image.get_format()]).to_utf8_buffer())
		hash.update(image.get_data())
		var digest = hash.finish().hex_encode()
		if state.images.has(digest):
			# Reuse the same resource as well as the same filename. Giving a second
			# texture an existing path would evict the first one from Godot's cache
			# and cause its image bytes to be embedded during serialization.
			state.resources[id] = state.images[digest]
			return state.images[digest]
		var safe_name = context.to_snake_case().replace("/", "_").replace(":", "_").replace(" ", "_")
		# Keep filenames short enough for normal Windows project paths.
		var relative = "art/%s_%s.png" % [safe_name.left(48), digest.left(12)]
		var error = image.save_png(str(state.folder).path_join(relative))
		if error != OK:
			state.error = "Could not save generated kit artwork (error %d)." % error
			return null
		var texture = ImageTexture.create_from_image(image)
		texture.take_over_path(state.prefix + relative)
		state.images[digest] = texture
		state.resources[id] = texture
		return texture
	var result = original.duplicate(false)
	if result == null:
		state.error = "Could not copy the kit resource for %s." % context
		return null
	state.resources[id] = result
	for property in original.get_property_list():
		if not int(property.usage) & PROPERTY_USAGE_STORAGE:
			continue
		var name: String = property.name
		var value: Variant = original.get(name)
		if value is Resource or value is Array or value is Dictionary:
			result.set(name, _copy_value(value, context + "_" + name, state))
	return result

static func _finalize_paths(filename: String, prefix: String) -> Error:
	var file = FileAccess.open(filename, FileAccess.READ)
	if file == null:
		return ERR_CANT_OPEN
	var content = file.get_as_text().replace(prefix, "")
	file.close()
	file = FileAccess.open(filename, FileAccess.WRITE)
	if file == null:
		return ERR_CANT_CREATE
	file.store_string(content)
	file.close()
	return OK

static func _remove_partial(folder: String) -> void:
	# This function is called only for a unique folder created by this export.
	var art_folder = folder.path_join("art")
	if DirAccess.dir_exists_absolute(art_folder):
		for filename in DirAccess.get_files_at(art_folder):
			DirAccess.remove_absolute(art_folder.path_join(filename))
		DirAccess.remove_absolute(art_folder)
	for filename in SCENE_FILES + ["kit_theme.tres", "preset.json", "README.md"]:
		if FileAccess.file_exists(folder.path_join(filename)):
			DirAccess.remove_absolute(folder.path_join(filename))
	DirAccess.remove_absolute(folder)

## Keep the source settings useful without exporting machine-specific cache or
## connection details. Asset hashes describe the original generated images;
## the exported artwork can also include resizing and procedural decoration.
static func _portable_ai_provenance(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in source:
		var field = str(key).to_lower()
		if _is_local_ai_field(field) or _is_local_ai_path(str(key)):
			continue
		var value: Variant = source[key]
		if value is String and _is_local_ai_path(value) and not field.ends_with("prompt"):
			# Model names are useful provenance even when a provider reports a
			# local model path instead of its usual checkpoint identifier.
			if field in ["checkpoint", "model", "checkpoint_name", "model_name"]:
				result[key] = str(value).replace("\\", "/").get_file()
			continue
		result[key] = _portable_ai_value(value)
	return result

static func _portable_ai_value(value: Variant) -> Variant:
	if value is Dictionary:
		return _portable_ai_provenance(value)
	if value is Array:
		var result: Array = []
		for item in value:
			if item is String and _is_local_ai_path(item):
				continue
			result.append(_portable_ai_value(item))
		return result
	return value

static func _is_local_ai_field(field: String) -> bool:
	return field in ["path", "paths", "file", "directory", "cache", "cache_dir", "cache_directory", "cache_key", "cache_root", "local_cache", "base_url", "server_url", "comfyui_url", "endpoint", "api_key", "token"] \
		or field.ends_with("_path") or field.ends_with("_paths")

static func _is_local_ai_path(value: String) -> bool:
	var normalized = value.replace("\\", "/")
	return normalized.is_absolute_path() or normalized.begins_with("user://") \
		or normalized.begins_with("res://") or normalized.begins_with("file://")

static func _instructions(config: Dictionary) -> String:
	var ai: Dictionary = config.get("ai", {})
	var source_note = "Procedural artwork settings and seeds are recorded in preset.json."
	var ai_instructions = ""
	if ai.get("enabled", false):
		source_note = "Artwork combines procedural frames with any locally generated ComfyUI source images."
		ai_instructions = """
## Optional ComfyUI artwork

ComfyUI was an optional source of locally generated artwork in UI Forge. These
exported scenes need no ComfyUI server, AI model, generator script, or network
connection. The art folder contains the PNG resources used by the native controls.

preset.json retains recorded prompts, checkpoint names, seeds, source image
hashes, dimensions, and component revisions when available. Machine-specific
cache paths and server connection settings are excluded. Source hashes describe
the original generated images; exported PNGs may include resizing or procedural
decoration. Recorded seeds help track generation settings but do not guarantee
bit-for-bit reproduction across model versions, hardware, or ComfyUI workflows.
"""
	return """# UI Forge fantasy UI kit

%s. %s

## Add this kit to your Godot game

Use Godot 4.6 or newer (tested with 4.6.3). These are exported native Control
scenes, not the UI Forge application. No generator script or plugin is needed.

1. Open your game's project in Godot.
2. In the FileSystem dock, right-click res:// and choose Open in File Manager.
3. Create a ui folder and copy this entire exported folder into it. Keep
   menu.tscn, hud.tscn, components.tscn, kit_theme.tres, and art together.
4. Return to Godot and wait for the PNGs to finish importing.
5. For a gameplay HUD, add a CanvasLayer to your game scene and drag hud.tscn
   onto that CanvasLayer. For a menu screen, open menu.tscn or instantiate it
   below a CanvasLayer. components.tscn is a matching palette of reusable parts.
6. Save your game scene and press F6 to run it.

All three scenes are included, regardless of which page was visible at export.
Each page retains its own custom component positions and sizes. Background
scenery from the UI Forge preview is not part of the exported kit.

## Edit the controls

Right-click an instance in the Scene dock and enable Editable Children. Native
buttons, labels, bars, and panels live under Canvas/Viewport/Design/Elements.
Edit labels with the Text property. Connect native Button pressed signals to
your game scripts; menu actions and sample values are not wired to gameplay.
Change ProgressBar values from gameplay code for health, mana, and other stats.

kit_theme.tres is shared by all three pages. Local Theme Overrides hold generated
button states, panel frames, and bar fills. Their StyleBoxTexture resources and
TextureRect icons refer to the PNGs in art. Replace those images or edit the
resources in Godot to customize the exported kit. Keep the whole art folder:
hover, pressed, disabled, and focus artwork may be used only during interaction.

The transparent design canvas is 1280 x 720 and scales uniformly with the game
window. Other aspect ratios add empty space to preserve the component shapes.
The Medieval pixel style keeps nearest-neighbor filtering for crisp artwork;
whole-number viewport scales give the sharpest pixel grid.

preset.json records the complete kit seed, material and ornament settings,
individual component seeds, page positions, and scales. Loading this file back
into UI Forge is not currently supported. The exported scenes remain editable
in Godot independently of the generator.
%s""" % [str(config.get("style", "Fantasy")), source_note, ai_instructions]
