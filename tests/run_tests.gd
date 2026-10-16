extends SceneTree
## Run with: godot --headless --path . --script tests/run_tests.gd

const Generator = preload("res://scripts/hud_generator.gd")
const Exporter = preload("res://scripts/hud_exporter.gd")
const Art = preload("res://scripts/hud_art.gd")
var failures: Array[String] = []
var checks = 0
var scratch: String

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: " + description)

func _run() -> void:
	scratch = OS.get_environment("TMPDIR")
	if scratch.is_empty():
		scratch = "/tmp" if OS.get_name() != "Windows" else OS.get_environment("TEMP")
	scratch = scratch.path_join("uiforge_test_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(scratch)
	_test_combinations()
	await _test_editor()
	await _test_dragging_and_art()
	await _test_export()
	_test_art_variations()
	await _test_art_export()
	if failures.is_empty():
		print("PASS: %d checks. Generated 108 genre/style/layout combinations; exercised editor and portable exports." % checks)
		quit(0)
	else:
		printerr("FAILED: %d of %d checks. Scratch files: %s" % [failures.size(), checks, scratch])
		quit(1)

func _test_combinations() -> void:
	for genre in Generator.GENRES:
		for style in Generator.STYLES:
			var config = Generator.make_config(genre, style)
			for variant in range(3):
				var hud = Generator.build(config, variant)
				check(hud.get_child_count() == config.components.size(), "%s / %s / %d has every selected component" % [genre, style, variant])
				check(hud.theme != null and hud.get_script() == null, "Generated HUD has a theme and no app script")
				hud.free()
	# Stress the largest component set and scaling limits, including layout overlaps.
	for variant in range(3):
		for scale in [0.85, 1.0, 1.1]:
			var config = Generator.make_config()
			config.components = Generator.COMPONENTS.keys()
			config.scale = scale
			var hud = Generator.build(config, variant)
			var occupied: Array[Rect2] = []
			for child in hud.get_children():
				var rect = Rect2(child.position, child.size * child.scale)
				check(Rect2(Vector2.ZERO, Generator.CANVAS).encloses(rect), "Layout %d scale %.2f keeps %s inside canvas" % [variant, scale, child.name])
				for prior in occupied:
					check(not prior.intersects(rect), "Layout %d scale %.2f has no overlap at %s" % [variant, scale, child.name])
				occupied.append(rect)
			hud.free()

func _test_editor() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	check(app.current_config.genre == "FPS", "Editor generates a default FPS HUD on startup")
	check(app.variant_previews.size() == 3, "Editor displays three preview variations")
	check(app.preview.hud.has_node("Weapon/Ammo"), "Main preview contains editable weapon controls")
	var margin: Control = app.get_child(1)
	check(margin.get_combined_minimum_size().x <= 1120, "Editor fits the minimum window width")
	check(margin.get_combined_minimum_size().y <= 940, "Editor fits the default window height")
	app.genre_picker.select(1)
	app.genre_picker.item_selected.emit(1)
	app._select_style("Fantasy")
	check(app.component_checks.mana.button_pressed, "RPG selects mana by default")
	check(app.current_config.genre == "FPS", "Pending brief changes do not silently change the visible HUD")
	app.generate()
	check(app.current_config.genre == "RPG" and app.current_config.style == "Fantasy", "Generate applies the genre and style")
	app.select_variant(2)
	check(app.selected_variant == 2 and app.preview.hud.get_meta("layout") == "Cinematic", "Selecting a variation changes the live preview")
	app.health_slider.value = 31
	check(app.preview.hud.get_node("Health/Value").value == 31, "Health slider updates the actual HUD control")
	app.size_slider.value = 110
	check(is_equal_approx(app.preview.hud.get_node("Health").scale.x, 1.1), "HUD size updates exported component geometry")
	app.accent_picker.color_changed.emit(Color("faac77"))
	check(app.current_config.accent == "faac77", "Accent picker updates the generated palette")
	for check_box in app.component_checks.values():
		check_box.set_pressed_no_signal(false)
	app.generate()
	check(app.current_config.components.size() > 0, "Empty selection leaves the last valid HUD intact")
	check(app.status_label.text.contains("at least one"), "Empty selection provides actionable feedback")
	app._new_ui()
	check(app.selected_style == "Military" and app.selected_variant == 0 and app.size_slider.value == 100, "New UI resets the design and customization")
	app.queue_free()
	await process_frame

func _test_export() -> void:
	var config = Generator.make_config("RPG", "Fantasy")
	config.components = Generator.COMPONENTS.keys()
	config.health = 37
	config.mana = 19
	config.scale = 1.1
	var result = Exporter.export_hud(config, 2, scratch)
	check(result.ok, "Export writes a complete portable package")
	if not result.ok:
		return
	var second = Exporter.export_hud(config, 2, scratch)
	check(second.ok and second.path != result.path, "Repeated exports never overwrite an existing package")
	var bad = Exporter.export_hud(config, 0, scratch.path_join("not_a_directory"))
	check(not bad.ok and bad.has("error"), "Invalid export destination returns an actionable error")
	for filename in ["hud.tscn", "hud_theme.tres", "preset.json", "README.md"]:
		check(FileAccess.file_exists(result.path.path_join(filename)), "Export contains " + filename)
	var scene_text = FileAccess.get_file_as_string(result.scene)
	check(not scene_text.contains("res://") and not scene_text.contains("/workspace/"), "Export scene has no dependency on the app project")
	check(scene_text.contains("path=\"hud_theme.tres\""), "Scene references the adjacent editable theme")
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(result.path.path_join("preset.json")))
	check(manifest.health == 37 and manifest.variant == "Cinematic", "Preset preserves the customized design")
	# Open the exported scene in an entirely separate Godot project.
	var game = scratch.path_join("independent_game")
	DirAccess.make_dir_recursive_absolute(game.path_join("hud"))
	for filename in ["hud.tscn", "hud_theme.tres"]:
		DirAccess.copy_absolute(result.path.path_join(filename), game.path_join("hud/" + filename))
	_write(game.path_join("project.godot"), "config_version=5\n[application]\nconfig/name=\"Export Test\"\n[rendering]\nrenderer/rendering_method=\"gl_compatibility\"\n")
	DirAccess.copy_absolute(ProjectSettings.globalize_path("res://docs/examples/health_demo.gd"), game.path_join("health_demo.gd"))
	_write(game.path_join("verify.gd"), """extends SceneTree
func _initialize():
    call_deferred("verify")
func verify():
    var packed = load("res://hud/hud.tscn")
    if packed == null:
        quit(1)
        return
    var hud = packed.instantiate()
    root.add_child(hud)
    await process_frame
    var elements = hud.get_node("Canvas/Viewport/Design/Elements")
    if elements.get_child_count() != 12 or elements.theme == null or elements.theme.resource_path != "res://hud/hud_theme.tres":
        quit(2)
        return
    if elements.get_node("Health/Value").value != 37 or elements.get_node("Mana/Value").value != 19:
        quit(3)
        return
    elements.get_node("Health/Value").value = 12
    if elements.get_node("Health/Value").value != 12:
        quit(4)
        return
    var demo = Node2D.new()
    demo.set_script(load("res://health_demo.gd"))
    var layer = CanvasLayer.new()
    layer.name = "CanvasLayer"
    demo.add_child(layer)
    layer.add_child(packed.instantiate())
    root.add_child(demo)
    await process_frame
    if demo.health_bar.value != 100 or demo.health_text.text != "100 / 100":
        quit(5)
        return
    var key = InputEventKey.new()
    key.pressed = true
    key.keycode = KEY_SPACE
    demo._unhandled_key_input(key)
    if demo.health_bar.value != 90 or demo.health_text.text != "90 / 100":
        quit(6)
        return
    for i in range(20):
        demo._unhandled_key_input(key)
    if demo.health_bar.value != 0 or demo.health_text.text != "0 / 100":
        quit(7)
        return
    key.keycode = KEY_R
    demo._unhandled_key_input(key)
    if demo.health_bar.value != 100 or demo.health_text.text != "100 / 100":
        quit(8)
        return
    print("HEALTH_DEMO_OK")
    print("INDEPENDENT_EXPORT_OK")
    quit(0)
""")
	var output: Array = []
	var exit_code = OS.execute(OS.get_executable_path(), ["--headless", "--path", game, "--script", "verify.gd"], output, true)
	check(exit_code == 0 and str(output).contains("INDEPENDENT_EXPORT_OK") and not str(output).contains("ERROR:"), "Export loads, retains values, and works in a separate Godot project: " + str(output))
	check(str(output).contains("HEALTH_DEMO_OK"), "Documented health demo initializes, takes damage, clamps to zero, and heals")

func _pointer(app: Control, at: Vector2, pressed: bool, motion: bool = false) -> void:
	var screen = app.preview.get_global_transform() * at
	if motion:
		var event = InputEventMouseMotion.new()
		event.position = screen
		event.global_position = screen
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(event, true)
	else:
		var event = InputEventMouseButton.new()
		event.position = screen
		event.global_position = screen
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		root.push_input(event, true)

func _drag(app: Control, element: String, delta: Vector2) -> void:
	var node = app.preview.hud.get_node(element)
	var from = app.preview.origin + (node.position + node.size * node.scale / 2) * app.preview.design_scale
	var to = from + delta * app.preview.design_scale
	_pointer(app, from, true)
	_pointer(app, to, true, true)
	_pointer(app, to, false)

func _key(code: Key, control: bool = false, shift: bool = false) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.ctrl_pressed = control
	event.shift_pressed = shift
	root.push_input(event, true)

func _test_dragging_and_art() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	var start: Vector2 = app.preview.hud.get_node("Health").position
	var change = Vector2(72, -64)
	_drag(app, "Health", change)
	check(app.preview.selected_element == "Health", "A real viewport click selects the health panel through its labels and bar")
	check(app.preview.hud.get_node("Health").position.is_equal_approx(start + change), "Dragging maps preview pixels to design coordinates")
	check(app.current_config.positions.get("0", {}).get("Health", Vector2.ZERO).is_equal_approx(start + change), "Drag release saves a per-layout position")
	app.select_variant(1)
	check(app.preview.hud.get_node("Health").position != start + change, "Moving a component leaves the other layout's preset intact")
	app.select_variant(0)
	check(app.preview.hud.get_node("Health").position.is_equal_approx(start + change), "Switching variants preserves moved positions")
	_key(KEY_RIGHT, false, true)
	check(app.preview.hud.get_node("Health").position.is_equal_approx(start + change + Vector2(10, 0)), "Shift+arrow nudges the selected element ten design pixels")
	_key(KEY_Z, true)
	check(app.preview.hud.get_node("Health").position.is_equal_approx(start + change), "Ctrl+Z undoes a nudge")
	_key(KEY_Z, true, true)
	check(app.preview.hud.get_node("Health").position.is_equal_approx(start + change + Vector2(10, 0)), "Ctrl+Shift+Z restores the nudge")
	app.preview.snap_to_grid = true
	_drag(app, "Health", Vector2(17, -5))
	var snapped: Vector2 = app.preview.hud.get_node("Health").position
	check(is_zero_approx(fmod(snapped.x, 8)) and is_zero_approx(fmod(snapped.y, 8)), "Optional snapping aligns drags to the eight-pixel grid")
	app.preview.snap_to_grid = false
	_drag(app, "Health", Vector2(-4000, -4000))
	check(app.preview.hud.get_node("Health").position == Vector2.ZERO, "Dragging outside the preview clamps the element to the canvas")
	app._reset_layout()
	check(app.preview.hud.get_node("Health").position == start, "Reset layout restores the selected preset")
	app.layout_history.undo()
	check(app.preview.hud.get_node("Health").position == Vector2.ZERO, "Reset layout is undoable")
	app.accent_picker.color_changed.emit(Color("f0b887"))
	app.size_slider.value = 110
	check(app.preview.hud.get_node("Health").position == Vector2.ZERO, "Color and scale changes keep custom positions")
	app.art_detail.select(1)
	app._generate_art()
	var artwork = app.preview.hud.get_node_or_null("Health/Art") as TextureRect
	check(artwork != null and artwork.texture != null, "Generate art creates a textured panel locally")
	if artwork != null:
		check(artwork.texture.get_width() == 560 and artwork.texture.get_height() == 128, "Frame art has a 2x resolution texture")
		check(artwork.texture.get_image().get_pixel(0, 0).a < 0.1, "Generated art keeps a transparent outer corner")
	check(app.preview.hud.get_node("Health").position == Vector2.ZERO, "Art generation preserves the custom layout")
	app.health_slider.value = 22
	check(app.preview.hud.get_node("Health/Value").value == 22, "Textured panels retain editable live progress bars")
	app._clear_art()
	check(not app.preview.hud.has_node("Health/Art") and app.preview.hud.get_node("Health").position == Vector2.ZERO, "Clearing art preserves the edited layout")
	app.generate()
	check(app.current_config.positions.is_empty() and not app.current_config.art.enabled, "Generate starts new presets with clean art and positions")
	check(not app.layout_history.has_undo(), "Generate clears actions belonging to the old design")
	app.queue_free()
	await process_frame

func _test_art_variations() -> void:
	for style in Generator.STYLES:
		for detail in Art.DETAILS:
			var config = Generator.make_config("FPS", style)
			config.art = {"enabled": true, "seed": 1234, "detail": detail}
			var hud = Generator.build(config, 0)
			var texture: Texture2D = hud.get_node("Health/Art").texture
			check(texture != null and texture.get_image().get_size() == Vector2i(560, 128), "%s / %s rasterizes valid frame artwork" % [style, detail])
			var again = Generator.build(config, 0)
			check(again.get_node("Health/Art").texture.get_image().get_data() == texture.get_image().get_data(), "Seeded artwork reproduces the same pixels across preview refreshes")
			hud.free()
			again.free()
	var config = Generator.make_config()
	config.art = {"enabled": true, "seed": 100, "detail": "Weathered"}
	var first = Generator.build(config, 0)
	config.art.seed = 200
	var second = Generator.build(config, 0)
	check(first.get_node("Health/Art").texture.get_image().get_data() != second.get_node("Health/Art").texture.get_image().get_data(), "Changing the art seed produces new image pixels")
	first.free()
	second.free()

func _test_art_export() -> void:
	var config = Generator.make_config("RPG", "Fantasy")
	config.positions = {"2": {"Health": Vector2(320, 430), "Minimap": Vector2(850, 90)}}
	config.art = {"enabled": true, "seed": 3210, "detail": "Ornate", "strength": 0.7}
	var result = Exporter.export_hud(config, 2, scratch)
	check(result.ok, "Custom-position HUD with generated art exports")
	if not result.ok:
		return
	var art_path: String = result.path.path_join("art")
	check(DirAccess.get_files_at(art_path).size() == config.components.size(), "Every selected panel exports its PNG artwork")
	var image = Image.load_from_file(art_path.path_join("health.png"))
	check(image != null and image.get_size() == Vector2i(560, 128), "Exported artwork is a usable PNG image")
	var scene_text = FileAccess.get_file_as_string(result.scene)
	check(scene_text.contains('path="art/health.png"') and not scene_text.contains("/tmp/"), "Artwork uses portable relative resource paths")
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(result.path.path_join("preset.json")))
	check(manifest.positions["2"].Health.x == 320 and manifest.positions["2"].Health.y == 430 and manifest.art.seed == 3210, "Preset records numeric custom positions and reproducible art settings")
	var game = scratch.path_join("art_game")
	DirAccess.make_dir_recursive_absolute(game.path_join("hud/art"))
	for filename in ["hud.tscn", "hud_theme.tres"]:
		DirAccess.copy_absolute(result.path.path_join(filename), game.path_join("hud/" + filename))
	for filename in DirAccess.get_files_at(art_path):
		DirAccess.copy_absolute(art_path.path_join(filename), game.path_join("hud/art/" + filename))
	_write(game.path_join("project.godot"), "config_version=5\n[application]\nconfig/name=\"Art Export Test\"\n[rendering]\nrenderer/rendering_method=\"gl_compatibility\"\n")
	_write(game.path_join("verify.gd"), """extends SceneTree
func _initialize():
    call_deferred("verify")
func verify():
    var hud = load("res://hud/hud.tscn").instantiate()
    root.add_child(hud)
    await process_frame
    var elements = hud.get_node("Canvas/Viewport/Design/Elements")
    var health = elements.get_node("Health")
    var artwork = health.get_node("Art")
    if health.position != Vector2(320, 430) or elements.get_node("Minimap").position != Vector2(850, 90):
        quit(1)
        return
    if artwork.texture == null or artwork.texture.get_width() != 560 or not is_equal_approx(artwork.modulate.a, 0.7):
        quit(2)
        return
    health.get_node("Value").value = 47
    if health.get_node("Value").value != 47:
        quit(3)
        return
    print("ART_EXPORT_OK")
    quit(0)
""")
	var output: Array = []
	var imported = OS.execute(OS.get_executable_path(), ["--headless", "--editor", "--path", game, "--import", "--quit"], output, true)
	check(imported == 0 and not str(output).contains("ERROR:"), "An independent Godot project imports the scene, theme, and generated PNGs: " + str(output))
	output.clear()
	var exit_code = OS.execute(OS.get_executable_path(), ["--headless", "--path", game, "--script", "verify.gd"], output, true)
	check(exit_code == 0 and str(output).contains("ART_EXPORT_OK") and not str(output).contains("ERROR:"), "Independent game loads custom positions and art while retaining live controls: " + str(output))

func _write(path: String, text: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
