extends SceneTree
## Run with: godot --headless --path . --script tests/run_kit_tests.gd

const Kit = preload("res://scripts/kit_generator.gd")
const Art = preload("res://scripts/kit_art.gd")
const Exporter = preload("res://scripts/kit_exporter.gd")
var failures: Array[String] = []
var checks := 0
var scratch: String

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: " + description)

func _run() -> void:
	var temporary := OS.get_environment("TMPDIR")
	if temporary.is_empty():
		temporary = "/tmp" if OS.get_name() != "Windows" else OS.get_environment("TEMP")
	scratch = temporary.path_join("uiforge_kit_test_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(scratch)
	_test_generated_kits()
	_test_artwork()
	_test_individual_regeneration()
	await _test_editor()
	_test_export()
	if failures.is_empty():
		print("KIT_PASS: %d checks. Both offline styles, complete kits, individual regeneration, and portable Godot exports." % checks)
		quit(0)
	else:
		printerr("KIT_FAILED: %d of %d checks. Scratch files: %s" % [failures.size(), checks, scratch])
		quit(1)

func _test_generated_kits() -> void:
	for style in Kit.STYLES:
		for material in Kit.MATERIALS:
			var config: Dictionary = Kit.make_config(style)
			config.kit.seed = 4287
			config.kit.material = material
			for page in range(Kit.PAGES.size()):
				var generated: Control = Kit.build(config, page)
				# Full-rect roots derive their size from the embedding design canvas.
				var canvas := Control.new()
				canvas.size = Vector2(1280, 720)
				root.add_child(canvas)
				canvas.add_child(generated)
				var brief := "%s / %s / %s" % [style, material, Kit.PAGES[page]]
				check(generated.size == Vector2(1280, 720), brief + " uses the editable design canvas")
				check(generated.get_child_count() >= 7, brief + " contains a complete collection")
				check(_owned_native(generated, generated), brief + " contains owned native controls without generator scripts")
				for component in generated.get_children():
					if component is Control:
						check(Rect2(Vector2.ZERO, generated.size).encloses(Rect2(component.position, component.size * component.scale)), brief + " keeps " + str(component.name) + " inside the canvas")
				if page == 0:
					check(_count_type(generated, "Button") >= 4, brief + " has usable menu buttons")
				if generated.has_node("Health/Value"):
					var health: ProgressBar = generated.get_node("Health/Value")
					health.value = 31
					check(health.value == 31 and health.get_script() == null, brief + " keeps health live and editable")
				if generated.has_node("Mana/Value"):
					var mana: ProgressBar = generated.get_node("Mana/Value")
					mana.value = 19
					check(mana.value == 19, brief + " keeps mana live and editable")
				check(_texture_snapshot(generated).size() >= 7, brief + " has illustrated components")
				canvas.free()

func _test_artwork() -> void:
	var config: Dictionary = Kit.make_config(Kit.STYLES[0])
	config.kit.seed = 12345
	var normal: Image = Art.texture(config, Vector2(260, 56), "ContinueButton", "button", "normal").get_image()
	check(normal.get_size() == Vector2i(520, 112), "Kit artwork exports at twice the logical size")
	var normal_pixels := normal.get_data()
	_clear_art_cache()
	check(normal_pixels == Art.texture(config, Vector2(260, 56), "ContinueButton", "button", "normal").get_image().get_data(), "Clearing the cache reproduces the same seeded illustration")
	for state in ["hover", "pressed", "disabled", "focus"]:
		var image: Image = Art.texture(config, Vector2(260, 56), "ContinueButton", "button", state).get_image()
		check(image.get_data() != normal_pixels, "Button " + state + " has distinct artwork")
	var material_images: Array[PackedByteArray] = []
	for material in Kit.MATERIALS:
		config.kit.material = material
		material_images.append(Art.texture(config, Vector2(260, 100), "Panel", "panel").get_image().get_data())
	for first in range(material_images.size()):
		for second in range(first + 1, material_images.size()):
			check(material_images[first] != material_images[second], "Different kit materials change surface pixels")
	config.kit.material = Kit.MATERIALS[0]
	var ornament_images: Array[PackedByteArray] = []
	for ornaments in Kit.ORNAMENTS:
		config.kit.ornaments = ornaments
		ornament_images.append(Art.texture(config, Vector2(280, 180), "Panel", "panel").get_image().get_data())
	check(ornament_images[0] != ornament_images[-1], "Ornament amount changes frame decoration")
	var reseeded: Dictionary = Kit.make_config(Kit.STYLES[0])
	reseeded.kit.seed = 54321
	check(Art.texture(reseeded, Vector2(260, 56), "ContinueButton", "button", "normal").get_image().get_data() != normal_pixels, "A different kit seed changes the illustration")
	var pixel_config: Dictionary = Kit.make_config(Kit.STYLES[1])
	pixel_config.kit.seed = 12345
	var pixel_image: Image = Art.texture(pixel_config, Vector2(260, 56), "ContinueButton", "button").get_image()
	check(pixel_image.get_data() != normal_pixels, "Medieval pixel art is a separate visual style")
	var alpha_crisp := true
	var transparent := false
	var opaque := false
	for y in range(pixel_image.get_height()):
		for x in range(pixel_image.get_width()):
			var alpha := pixel_image.get_pixel(x, y).a
			if alpha > 0.0 and alpha < 1.0:
				alpha_crisp = false
			transparent = transparent or alpha == 0.0
			opaque = opaque or alpha == 1.0
	check(alpha_crisp and transparent and opaque, "Pixel art has crisp transparent edges without blurred alpha")

func _test_individual_regeneration() -> void:
	var config: Dictionary = Kit.make_config(Kit.STYLES[0])
	config.kit.seed = 1482
	config.positions = {"0": {"ContinueButton": Vector2(140, 280)}}
	config.element_scales = {"0": {"ContinueButton": 1.15}}
	var first: Control = Kit.build(config, 0)
	var before := _texture_snapshot(first)
	check(first.get_node("ContinueButton").position == Vector2(140, 280), "Custom kit positions are applied")
	check(is_equal_approx(first.get_node("ContinueButton").scale.x, 1.15), "Individual kit scaling is applied")
	config.kit.component_seeds["ContinueButton"] = 96814
	var second: Control = Kit.build(config, 0)
	var after := _texture_snapshot(second)
	var changed := false
	var other_unchanged := true
	for path in before:
		if str(path).begins_with("ContinueButton/"):
			changed = changed or before[path] != after.get(path)
		else:
			other_unchanged = other_unchanged and before[path] == after.get(path)
	check(changed, "Regenerating one component changes its artwork")
	check(other_unchanged, "Individual regeneration preserves every other component image")
	check(second.get_node("ContinueButton").position == first.get_node("ContinueButton").position and second.get_node("ContinueButton").scale == first.get_node("ContinueButton").scale, "Individual regeneration preserves custom position and size")
	first.free()
	second.free()

func _test_editor() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	app.creation_picker.select(1)
	app._set_creation_mode(1)
	check(app.current_config.get("mode", "hud") == "hud", "Changing the pending brief keeps the current design until Generate")
	app.kit_style_picker.select(1)
	app.kit_material_picker.select(1)
	app.kit_ornament_picker.select(0)
	app.generate()
	await process_frame
	check(app.preview.hud.has_node("ContinueButton"), "The editor generates the complete kit menu")
	check(app.current_config.style == Kit.STYLES[1] and app.current_config.kit.material == Kit.MATERIALS[1], "The simple controls apply the selected kit style and material")
	app.select_variant(1)
	check(app.preview.hud.has_node("Health/Value"), "Kit page selection displays the editable HUD")
	app.health_slider.value = 27
	check(app.preview.hud.get_node("Health/Value").value == 27, "Kit preview health uses the live inspector control")
	app.select_variant(0)
	app._apply_transform(0, "ContinueButton", Vector2(140, 280), 1.15)
	var before: Dictionary = _texture_snapshot(app.preview.hud)
	app.preview.selected_element = "ContinueButton"
	app._regenerate_selected()
	var after: Dictionary = _texture_snapshot(app.preview.hud)
	var selected_changed := false
	var others_unchanged := true
	for path in before:
		if str(path).begins_with("ContinueButton/"):
			selected_changed = selected_changed or before[path] != after.get(path)
		else:
			others_unchanged = others_unchanged and before[path] == after.get(path)
	check(selected_changed and others_unchanged, "The editor regenerates only the selected component")
	check(app.preview.hud.get_node("ContinueButton").position == Vector2(140, 280) and is_equal_approx(app.preview.hud.get_node("ContinueButton").scale.x, 1.15), "Editor regeneration retains the arranged component transform")
	app.layout_history.undo()
	check(_texture_snapshot(app.preview.hud) == before, "Undo restores the previous component illustration")
	app.layout_history.redo()
	check(_texture_snapshot(app.preview.hud) == after, "Redo restores the regenerated component illustration")
	app.queue_free()
	await process_frame

func _test_export() -> void:
	var config: Dictionary = Kit.make_config(Kit.STYLES[1])
	config.kit.seed = 5693
	config.kit.material = Kit.MATERIALS[2]
	config.positions = {"0": {"ContinueButton": Vector2(140, 280)}, "1": {"Health": Vector2(60, 580)}}
	config.element_scales = {"0": {"ContinueButton": 1.15}, "1": {"Health": 1.25}}
	config.health = 43
	config.mana = 28
	var exported: Dictionary = Exporter.export_kit(config, 1, scratch)
	check(exported.ok, "A complete kit exports successfully")
	if not exported.ok:
		return
	check(str(exported.scene).ends_with("hud.tscn"), "Export selects the previewed kit page")
	for filename in ["menu.tscn", "hud.tscn", "components.tscn", "kit_theme.tres", "preset.json", "README.md"]:
		check(FileAccess.file_exists(exported.path.path_join(filename)), "Complete kit export includes " + filename)
	for filename in ["menu.tscn", "hud.tscn", "components.tscn", "kit_theme.tres"]:
		var text := FileAccess.get_file_as_string(exported.path.path_join(filename))
		check(not text.contains("/workspace/") and not text.contains("/tmp/") and not text.contains("res://scripts/") and not text.contains("ImageTexture"), "Exported " + filename + " references portable resource assets")
	var assets := DirAccess.get_files_at(exported.path.path_join("art"))
	check(assets.size() > 30, "The kit includes surface, icon, bar, and button-state artwork")
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(exported.path.path_join("preset.json")))
	check(manifest.kit.seed == 5693 and manifest.kit.material == Kit.MATERIALS[2], "The preset preserves reproducible kit settings")
	check(manifest.positions["0"].ContinueButton.x == 140 and is_equal_approx(manifest.element_scales["1"].Health, 1.25), "The preset preserves positions and individual scales")
	var duplicate: Dictionary = Exporter.export_kit(config, 1, scratch)
	check(duplicate.ok and duplicate.path != exported.path, "Repeated kit exports preserve previous exports")
	var invalid: Dictionary = Exporter.export_kit(config, 0, scratch.path_join("missing"))
	check(not invalid.ok and invalid.has("error"), "An invalid kit destination returns an actionable error")
	var game := scratch.path_join("independent_game")
	_copy_tree(exported.path, game.path_join("fantasy_kit"))
	_write(game.path_join("project.godot"), "config_version=5\n[application]\nconfig/name=\"Independent Kit Test\"\n[rendering]\nrenderer/rendering_method=\"gl_compatibility\"\n")
	_write(game.path_join("verify.gd"), _independent_verifier())
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--editor", "--path", game, "--import", "--quit"], output, true)
	check(code == 0 and not str(output).contains("ERROR:"), "A fresh Godot project imports every kit resource: " + str(output))
	output.clear()
	code = OS.execute(OS.get_executable_path(), ["--headless", "--path", game, "--script", "verify.gd"], output, true)
	check(code == 0 and str(output).contains("INDEPENDENT_KIT_OK") and not str(output).contains("ERROR:"), "Independent game loads real textures, button states, custom transforms, and live controls: " + str(output))

func _independent_verifier() -> String:
	return """extends SceneTree
func _initialize():
    call_deferred("verify")
func verify():
    root.size = Vector2i(1000, 800)
    for filename in ["menu", "hud", "components"]:
        var packed = load("res://fantasy_kit/" + filename + ".tscn")
        if packed == null:
            quit(1)
            return
        var scene = packed.instantiate()
        root.add_child(scene)
        await process_frame
        var elements = scene.get_node("Canvas/Viewport/Design/Elements")
        if elements.get_script() != null or not check_textures(elements):
            quit(2)
            return
        if filename == "menu":
            var button = elements.get_node("ContinueButton")
            if not button is Button or button.position != Vector2(140, 280) or not is_equal_approx(button.scale.x, 1.15):
                quit(3)
                return
            for state in ["normal", "hover", "pressed", "disabled", "focus"]:
                var style = button.get_theme_stylebox(state)
                if not style is StyleBoxTexture or style.texture == null or not style.texture.resource_path.begins_with("res://fantasy_kit/art/"):
                    quit(4)
                    return
            if not (await click_native_button(scene, button)):
                quit(7)
                return
        if filename == "hud":
            var health = elements.get_node("Health")
            if health.position != Vector2(60, 580) or not is_equal_approx(health.scale.x, 1.25) or health.get_node("Value").value != 43:
                quit(5)
                return
            health.get_node("Value").value = 17
            if health.get_node("Value").value != 17 or elements.get_node("Mana/Value").value != 28:
                quit(6)
                return
        scene.queue_free()
        await process_frame
    print("INDEPENDENT_KIT_OK")
    quit(0)
func click_native_button(scene, button):
    var counter = {"pressed": 0}
    button.pressed.connect(func(): counter.pressed += 1)
    var container = scene.get_node("Canvas/Viewport")
    var at = container.get_global_rect().position + button.get_global_rect().get_center() * container.size / Vector2(1280, 720)
    var move = InputEventMouseMotion.new()
    move.position = at
    move.global_position = at
    root.push_input(move)
    await process_frame
    var press = InputEventMouseButton.new()
    press.position = at
    press.global_position = at
    press.button_index = MOUSE_BUTTON_LEFT
    press.button_mask = MOUSE_BUTTON_MASK_LEFT
    press.pressed = true
    root.push_input(press)
    await process_frame
    var release = InputEventMouseButton.new()
    release.position = at
    release.global_position = at
    release.button_index = MOUSE_BUTTON_LEFT
    release.pressed = false
    root.push_input(release)
    await process_frame
    return counter.pressed == 1
func check_textures(node):
    if node.get_script() != null:
        return false
    if node is TextureRect and node.texture != null:
        if node.texture.get_image() == null or not node.texture.resource_path.begins_with("res://fantasy_kit/art/"):
            return false
    for child in node.get_children():
        if not check_textures(child):
            return false
    return true
"""

func _texture_snapshot(root_node: Node) -> Dictionary:
	var images := {}
	_collect_textures(root_node, root_node, images)
	return images

func _collect_textures(node: Node, root_node: Node, images: Dictionary) -> void:
	var path := str(root_node.get_path_to(node))
	if node is TextureRect and node.texture != null:
		images[path + "/texture"] = node.texture.get_image().get_data()
	if node is Control:
		var styles: Array[String] = []
		if node is Button:
			styles = ["normal", "hover", "pressed", "disabled", "focus"]
		elif node is ProgressBar:
			styles = ["background", "fill"]
		elif node is Panel:
			styles = ["panel"]
		for name in styles:
			var style: StyleBox = node.get_theme_stylebox(name)
			if style is StyleBoxTexture and style.texture != null:
				images[path + "/" + name] = style.texture.get_image().get_data()
	for child in node.get_children():
		_collect_textures(child, root_node, images)

func _owned_native(node: Node, generated: Node) -> bool:
	if node.get_script() != null or (node != generated and node.owner != generated):
		return false
	for child in node.get_children():
		if not _owned_native(child, generated):
			return false
	return true

func _count_type(node: Node, type_name: String) -> int:
	var count := 1 if node.is_class(type_name) else 0
	for child in node.get_children():
		count += _count_type(child, type_name)
	return count

func _clear_art_cache() -> void:
	# The public cache can be evicted without affecting generation output.
	Art.texture_cache.clear()

func _copy_tree(source: String, destination: String) -> void:
	DirAccess.make_dir_recursive_absolute(destination)
	for filename in DirAccess.get_files_at(source):
		if not filename.ends_with(".import"):
			DirAccess.copy_absolute(source.path_join(filename), destination.path_join(filename))
	for directory in DirAccess.get_directories_at(source):
		_copy_tree(source.path_join(directory), destination.path_join(directory))

func _write(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(contents)
