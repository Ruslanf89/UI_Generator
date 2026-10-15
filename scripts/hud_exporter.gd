extends RefCounted

const Generator = preload("res://scripts/hud_generator.gd")

static func export_hud(config: Dictionary, variant: int, parent_directory: String) -> Dictionary:
	if not DirAccess.dir_exists_absolute(parent_directory):
		return {"ok": false, "error": "Choose an existing, writable export folder."}
	var slug = "%s_%s_%s" % [config.genre.to_lower(), config.style.to_lower().replace("-", ""), Generator.LAYOUTS[variant].to_lower()]
	var base = parent_directory.path_join("uiforge_" + slug)
	var folder = base
	var suffix = 2
	while DirAccess.dir_exists_absolute(folder) or FileAccess.file_exists(folder):
		folder = base + "_%d" % suffix
		suffix += 1
	var error = DirAccess.make_dir_recursive_absolute(folder)
	if error != OK:
		return {"ok": false, "error": "Could not create export folder (error %d)." % error}
	var root = Generator.build(config, variant)
	# A 1280 x 720 design scales uniformly at any viewport size; containers stay editable.
	var scene_root = Control.new()
	scene_root.name = "HUD"
	scene_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scaler = AspectRatioContainer.new()
	scaler.name = "Canvas"
	scaler.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scaler.ratio = 16.0 / 9.0
	scaler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene_root.add_child(scaler)
	var viewport_container = SubViewportContainer.new()
	viewport_container.name = "Viewport"
	viewport_container.stretch = true
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scaler.add_child(viewport_container)
	var viewport = SubViewport.new()
	viewport.name = "Design"
	viewport.size = Vector2i(1280, 720)
	viewport.size_2d_override = Vector2i(1280, 720)
	viewport.size_2d_override_stretch = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)
	root.name = "Elements"
	viewport.add_child(root)
	Generator.assign_owners(scene_root, scene_root)
	var theme_path = folder.path_join("hud_theme.tres")
	var scene_path = folder.path_join("hud.tscn")
	error = ResourceSaver.save(root.theme, theme_path)
	if error == OK:
		# Godot embeds resources saved outside res://. Attach a portable external
		# theme reference below instead of shipping an unrelated duplicate theme.
		root.theme = null
		var packed = PackedScene.new()
		error = packed.pack(scene_root)
		if error == OK:
			error = ResourceSaver.save(packed, scene_path)
	scene_root.free()
	if error != OK:
		_remove_partial(folder)
		return {"ok": false, "error": "Could not save HUD resources (error %d)." % error}
	var file = FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		_remove_partial(folder)
		return {"ok": false, "error": "Could not read the saved HUD scene."}
	var scene_text = file.get_as_text()
	file.close()
	var header_end = scene_text.find("\n")
	scene_text = scene_text.insert(header_end + 1, "\n[ext_resource type=\"Theme\" path=\"hud_theme.tres\" id=\"1_theme\"]\n")
	var elements_header = scene_text.find("[node name=\"Elements\"")
	var elements_header_end = scene_text.find("\n", elements_header)
	scene_text = scene_text.insert(elements_header_end + 1, "theme = ExtResource(\"1_theme\")\n")
	file = FileAccess.open(scene_path, FileAccess.WRITE)
	if file == null:
		_remove_partial(folder)
		return {"ok": false, "error": "Could not finalize the portable HUD scene."}
	file.store_string(scene_text)
	file.close()
	var manifest = config.duplicate(true)
	manifest.resolution = {"width": config.resolution.x, "height": config.resolution.y}
	manifest.variant = Generator.LAYOUTS[variant]
	manifest.generator = "UI Forge 0.1"
	var files = {
		"preset.json": JSON.stringify(manifest, "\t"),
		"README.md": _instructions(config, variant),
	}
	for filename in files:
		file = FileAccess.open(folder.path_join(filename), FileAccess.WRITE)
		if file == null:
			_remove_partial(folder)
			return {"ok": false, "error": "Could not write export documentation."}
		file.store_string(files[filename])
		file.close()
	return {"ok": true, "path": folder, "scene": scene_path}

static func _remove_partial(folder: String) -> void:
	# Only files inside the new export folder are ever removed on failure.
	for filename in ["hud.tscn", "hud_theme.tres", "preset.json", "README.md"]:
		DirAccess.remove_absolute(folder.path_join(filename))
	DirAccess.remove_absolute(folder)

static func _instructions(config: Dictionary, variant: int) -> String:
	return """# UI Forge HUD

%s / %s / %s

Requires Godot 4.6 or newer. Copy this entire folder into your game's project,
then instance hud.tscn under a CanvasLayer in your game scene. Keep hud_theme.tres
beside hud.tscn. No generator scripts, plugins, external art, or network access
are required. These are native editable Godot Control nodes.

The HUD uses a transparent 1280 x 720 design canvas, scaled uniformly within
the game viewport. Non-16:9 viewports letterbox the HUD to avoid distortion.
Your chosen target resolution is %d x %d; set your game window size there.

In the editor, enable Editable Children to customize individual controls.
Gameplay values, the map, timers, and ability slots contain example data;
connect them to your game's state. This export contains no gameplay logic.

For a health component, a script on your game scene can use:

```gdscript
@onready var health_bar: ProgressBar = $CanvasLayer/HUD/Canvas/Viewport/Design/Elements/Health/Value
@onready var health_text: Label = $CanvasLayer/HUD/Canvas/Viewport/Design/Elements/Health/Amount

func update_health(current: float, maximum: float) -> void:
    health_bar.max_value = maximum
    health_bar.value = current
    health_text.text = "%%d / %%d" %% [current, maximum]
```

Other elements live below the same Elements node: Mana/Value, Armor/Value,
Weapon/Ammo, Weapon/Reserve, Minimap/MapContent, Objective/Description,
Speed/Value, Lap/Time, Resources/Values, Squad and Abilities/Slot1..Slot4.
Only components you selected are present. Replace the minimap sample blocks
with a camera or real map, and connect the remaining controls as needed.

preset.json records the design choices for reference.
""" % [config.genre, config.style, Generator.LAYOUTS[variant], config.resolution.x, config.resolution.y]
