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

## Add this HUD to your game

Use Godot 4.6 or newer (tested with 4.6.3). This folder is an exported HUD,
not the UI Forge desktop application. It contains native editable Control nodes.

1. Open your game's project in the Godot editor.
2. In its FileSystem dock, right-click res:// and choose Open in File Manager.
   This opens the game folder containing your game's project.godot.
3. Create a ui folder there, then copy this entire exported folder into it.
   Keep hud.tscn and hud_theme.tres beside each other.
4. Return to Godot and wait for the new files to appear.
5. Open your gameplay scene. Select its root and add a CanvasLayer child.
6. Drag this folder's hud.tscn from FileSystem onto CanvasLayer in the Scene dock.
7. Keep the new instance named HUD, save the game scene, and press F6 to run it.

Your scene should contain:

```text
Game
  CanvasLayer
    HUD
```

CanvasLayer keeps the interface in screen space. The HUD is transparent;
UI Forge's preview background is not exported. No generator plugins or scripts
are needed in your game to display this scene.

## Window size and editing

The HUD uses a transparent 1280 x 720 design canvas, scaled uniformly within
the game viewport. Non-16:9 viewports letterbox the HUD to avoid distortion.
Your chosen target resolution is %d x %d; set your game window size there.

Set the game window under Project > Project Settings > Display > Window.
The recorded target resolution does not change those settings automatically.

Right-click the HUD instance in the Scene dock and enable Editable Children.
Its controls are below Canvas > Viewport > Design > Elements. Edit their text,
position, or Theme Overrides in the Inspector. The Elements node uses the shared
hud_theme.tres resource; changing that theme affects controls that use it.

## Connect gameplay values

The map, ammo, health, timers, and ability slots contain example data. Your game
must update the controls; the export does not include gameplay logic.

If Health was selected, attach a GDScript to your Node2D Game root to initialize
its health display. For a Node3D root, change extends to Node3D. If your game
already has a script, integrate the relevant code instead of replacing it.

```gdscript
extends Node2D

@onready var health_bar: ProgressBar = $CanvasLayer/HUD/Canvas/Viewport/Design/Elements/Health/Value
@onready var health_text: Label = $CanvasLayer/HUD/Canvas/Viewport/Design/Elements/Health/Amount

func _ready() -> void:
    update_health(100.0, 100.0)

func update_health(current: float, maximum: float) -> void:
    health_bar.max_value = maximum
    health_bar.value = current
    health_text.text = "%%d / %%d" %% [current, maximum]
```

Run the game scene with F6: this example should show 100 / 100. Call update_health
after damage or healing in your real game. If you get Node not found, check that
Health was selected and that the node names and script placement match the tree.

Other elements live below the same Elements node: Mana/Value, Armor/Value,
Weapon/Ammo, Weapon/Reserve, Minimap/MapContent, Objective/Description,
Speed/Value, Lap/Time, Resources/Values, Squad and Abilities/Slot1..Slot4.
Only components you selected are present. Replace the minimap sample blocks
with a camera or real map, and connect the remaining controls as needed.

preset.json records the design choices; importing it back into UI Forge is not
implemented. You can keep editing the exported scene and theme in Godot.

Full illustrated guides, a Space-to-damage / R-to-heal example, and troubleshooting:
https://github.com/Ruslanf89/UI_Generator/blob/main/docs/godot-guide.md
https://github.com/Ruslanf89/UI_Generator/blob/main/docs/windows-guide.md
""" % [config.genre, config.style, Generator.LAYOUTS[variant], config.resolution.x, config.resolution.y]
