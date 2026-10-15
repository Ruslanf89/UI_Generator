extends SceneTree
## Run with: godot --headless --path . --script tests/run_tests.gd

const Generator = preload("res://scripts/hud_generator.gd")
const Exporter = preload("res://scripts/hud_exporter.gd")
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
	await _test_export()
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
    print("INDEPENDENT_EXPORT_OK")
    quit(0)
""")
	var output: Array = []
	var exit_code = OS.execute(OS.get_executable_path(), ["--headless", "--path", game, "--script", "verify.gd"], output, true)
	check(exit_code == 0 and str(output).contains("INDEPENDENT_EXPORT_OK") and not str(output).contains("ERROR:"), "Export loads, retains values, and works in a separate Godot project: " + str(output))

func _write(path: String, text: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
