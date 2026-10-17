extends SceneTree
## Run with: godot --headless --path . --script tests/run_kit_tests.gd

const Kit = preload("res://scripts/kit_generator.gd")
const Art = preload("res://scripts/kit_art.gd")
const Exporter = preload("res://scripts/kit_exporter.gd")
const Design = preload("res://scripts/kit_design.gd")
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
	_test_structural_art()
	_test_seeded_layouts()
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
	var geometry_before := _layout_signature(first)
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
	check(_layout_signature(second) == geometry_before, "Individual regeneration preserves every component's layout geometry")
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
	app.kit_design_picker.select(Design.FAMILIES.find("Wildwood"))
	app.kit_seed_lock.button_pressed = false
	app.generate()
	var first_seed := int(app.current_config.kit.seed)
	var first_layout := _layout_signature(app.preview.hud)
	var first_art: PackedByteArray = app.preview.hud.get_node("ContinueButton").get_theme_stylebox("normal").texture.get_image().get_data()
	app.generate()
	check(int(app.current_config.kit.seed) != first_seed and _layout_signature(app.preview.hud) != first_layout, "Consecutive unlocked generations change the seed and composition")
	check(app.preview.hud.get_node("ContinueButton").get_theme_stylebox("normal").texture.get_image().get_data() != first_art, "Consecutive unlocked generations change the illustrated button")
	check(app.current_config.kit.design == "Wildwood" and app.preview.hud.get_meta("design_family", "") == "Wildwood", "The design picker applies a consistent family")
	app.kit_seed_lock.button_pressed = false
	var seed_entry: LineEdit = app.kit_seed.get_line_edit()
	seed_entry.grab_focus()
	seed_entry.text = "202703"
	seed_entry.text_changed.emit(seed_entry.text)
	await process_frame
	check(int(app.kit_seed.value) == 202703 and app.kit_seed_lock.button_pressed, "Typing a seed updates its value and enables Keep seed before Generate")
	app.generate()
	var locked_layout := _layout_signature(app.preview.hud)
	var locked_art := _texture_snapshot(app.preview.hud)
	app.generate()
	check(int(app.current_config.kit.seed) == 202703 and _layout_signature(app.preview.hud) == locked_layout, "Locked generation reproduces the requested seed and complete layout")
	check(_texture_snapshot(app.preview.hud) == locked_art, "Locked generation reproduces every rendered asset")
	app.kit_seed_lock.button_pressed = false
	seed_entry.text = "202704"
	seed_entry.text_changed.emit(seed_entry.text)
	app.generate()
	check(int(app.current_config.kit.seed) == 202704 and app.kit_seed_lock.button_pressed, "Generate commits a seed typed in the same frame before selecting a design")
	app.queue_free()
	await process_frame

func _test_structural_art() -> void:
	for style in Kit.STYLES:
		var config: Dictionary = Kit.make_config(style)
		config.kit.design = "Royal court"
		var silhouettes := {}
		var frame_edges := {}
		for seed in [0, 16, 32, 48, 64, 80]:
			config.kit.seed = seed
			var image: Image = Art.texture(config, Vector2(260, 64), "ContinueButton", "button").get_image()
			silhouettes[_alpha_signature(image)] = true
			frame_edges[_edge_signature(image)] = true
		check(silhouettes.size() >= 4, style + " seeds change the actual button silhouette")
		check(frame_edges.size() >= 4, style + " seeds change the rendered border edge pattern")
		config.kit.seed = 763
		var geometry: PackedByteArray
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var image: Image = Art.texture(config, Vector2(260, 64), "ContinueButton", "button", state).get_image()
			var cached: Image = Art.texture(config, Vector2(260, 64), "ContinueButton", "button", state).get_image()
			_clear_art_cache()
			var regenerated: Image = Art.texture(config, Vector2(260, 64), "ContinueButton", "button", state).get_image()
			check(image.get_data() == cached.get_data() and image.get_data() == regenerated.get_data(), style + " " + state + " reproduces the cached and uncached artwork")
			if state == "normal":
				geometry = _alpha_signature(image)
			elif state != "focus":
				check(_alpha_signature(image) == geometry, style + " " + state + " retains its normal button contour")
		var family_edges := {}
		for family in Design.FAMILIES.slice(1):
			config.kit.design = family
			var texture: ImageTexture = Art.texture(config, Vector2(280, 180), "SamplePanel", "panel")
			family_edges[_edge_signature(texture.get_image())] = true
			check(texture.get_meta("kit_art_family", "") == family, style + " renders the chosen " + family + " design language")
		check(family_edges.size() >= 3, style + " families change rendered border and ornament edge patterns")
		for role in ["icon_sword", "icon_gear", "icon_bag"]:
			var icon_shapes := {}
			for seed in [0, 16, 32, 48, 64, 80]:
				config.kit.seed = seed
				var image: Image = Art.texture(config, Vector2(64, 64), "Inventory", role).get_image()
				icon_shapes[_alpha_signature(image)] = true
			check(icon_shapes.size() >= 3, style + " " + role + " has multiple structural icon silhouettes")

func _test_seeded_layouts() -> void:
	for style in Kit.STYLES:
		var config: Dictionary = Kit.make_config(style)
		config.kit.design = "Surprise me"
		var recipes := {}
		for seed in range(64):
			config.kit.seed = seed
			var design: Dictionary = Design.recipe(config)
			if not recipes.has(design.layout):
				recipes[design.layout] = config.duplicate(true)
			if recipes.size() == 4:
				break
		check(recipes.size() == 4, style + " seeds expose four composition recipes")
		var rendered_layouts := [{}, {}, {}]
		for layout in recipes:
			var candidate: Dictionary = recipes[layout]
			var expected: Dictionary = Design.recipe(candidate)
			for page in range(Kit.PAGES.size()):
				var generated: Control = Kit.build(candidate, page)
				rendered_layouts[page][_layout_signature(generated)] = true
				check(generated.get_meta("layout_recipe", -1) == layout and generated.get_meta("design_family", "") == expected.family, style + " " + Kit.PAGES[page] + " records its actual design recipe")
				_check_composition(generated, style + " " + Kit.PAGES[page] + " recipe " + str(layout))
				var textures: Array[Texture2D] = []
				_collect_art_resources(generated, textures)
				var consistent := not textures.is_empty()
				for texture in textures:
					consistent = consistent and texture.get_meta("kit_art_family", "") == expected.family
				check(consistent, style + " " + Kit.PAGES[page] + " keeps all frames, states, fills, and icons in one family")
				generated.free()
		for page in [0, 1]:
			check(rendered_layouts[page].size() >= 4, style + " " + Kit.PAGES[page] + " has four different rendered position and size arrangements")
		var same_recipe_layouts := [{}, {}]
		for seed in [0, 64, 128, 192]:
			config.kit.seed = seed
			for page in [0, 1]:
				var generated: Control = Kit.build(config, page)
				same_recipe_layouts[page][_layout_signature(generated)] = true
				_check_composition(generated, style + " " + Kit.PAGES[page] + " same-recipe seed " + str(seed))
				generated.free()
		for page in [0, 1]:
			check(same_recipe_layouts[page].size() >= 3, style + " " + Kit.PAGES[page] + " seeds vary proportions and spacing within one composition recipe")

func _check_composition(generated: Control, description: String) -> void:
	var bounded := true
	var overlaps: Array[String] = []
	var children := generated.get_children()
	for index in range(children.size()):
		var node: Control = children[index]
		var rect := Rect2(node.position, node.size * node.scale)
		bounded = bounded and Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(rect)
		for other_index in range(index):
			var other: Control = children[other_index]
			var other_rect := Rect2(other.position, other.size * other.scale)
			if not rect.intersects(other_rect):
				continue
			var panel: Control = node if node.name == "MenuPanel" else other if other.name == "MenuPanel" else null
			var button: Control = other if panel == node else node
			var menu_inset := panel != null and button.name in ["ContinueButton", "NewJourneyButton", "SettingsButton", "ExitButton"] and Rect2(panel.position, panel.size * panel.scale).encloses(Rect2(button.position, button.size * button.scale))
			if not menu_inset:
				overlaps.append(str(node.name) + "/" + str(other.name))
	check(bounded, description + " keeps every component within the canvas")
	check(overlaps.is_empty(), description + " has no unintended component overlaps: " + ", ".join(overlaps))

func _layout_signature(generated: Control) -> String:
	var parts: Array[String] = []
	for node in generated.get_children():
		parts.append("%s:%.3f,%.3f,%.3f,%.3f,%.3f,%.3f" % [node.name, node.position.x, node.position.y, node.size.x, node.size.y, node.scale.x, node.scale.y])
	parts.sort()
	return "|".join(parts)

func _alpha_signature(image: Image) -> PackedByteArray:
	var signature := PackedByteArray()
	var bytes := image.get_data()
	signature.resize(image.get_width() * image.get_height())
	for index in range(signature.size()):
		signature[index] = 1 if bytes[index * 4 + 3] >= 128 else 0
	return signature

func _edge_signature(image: Image) -> PackedByteArray:
	var signature := PackedByteArray()
	var bytes := image.get_data()
	var width := image.get_width()
	var height := image.get_height()
	# This supplements the geometric alpha-mask test with a border appearance
	# check. Exclude the quiet center so surface grain cannot dominate it.
	var band := maxi(8, roundi(mini(width, height) * .2))
	signature.resize(width * height)
	for y in range(height - 1):
		for x in range(width - 1):
			if x >= band and x < width - band and y >= band and y < height - band:
				continue
			var index := (y * width + x) * 4
			if bytes[index + 3] < 128:
				continue
			var across := 0
			var below := 0
			for channel in range(3):
				across += absi(int(bytes[index + channel]) - int(bytes[index + 4 + channel]))
				below += absi(int(bytes[index + channel]) - int(bytes[index + width * 4 + channel]))
			signature[y * width + x] = 1 if across >= 96 or below >= 96 else 0
	return signature

func _collect_art_resources(node: Node, textures: Array[Texture2D]) -> void:
	if node is TextureRect and node.texture != null:
		textures.append(node.texture)
	if node is Control:
		var styles: Array[String] = []
		if node is Button:
			styles = ["normal", "hover", "pressed", "disabled", "focus"]
		elif node is ProgressBar:
			styles = ["background", "fill"]
		elif node is Panel:
			styles = ["panel"]
		for state in styles:
			var style: StyleBox = node.get_theme_stylebox(state)
			if style is StyleBoxTexture and style.texture != null:
				textures.append(style.texture)
	for child in node.get_children():
		_collect_art_resources(child, textures)

func _test_export() -> void:
	var config: Dictionary = Kit.make_config(Kit.STYLES[1])
	config.kit.seed = 5693
	config.kit.material = Kit.MATERIALS[2]
	config.kit.design = "Runic forge"
	# Keep this deliberately moved command clear of the preset command row so
	# the native input check targets the same component whose transform we verify.
	config.positions = {"0": {"ContinueButton": Vector2(140, 130)}, "1": {"Health": Vector2(60, 580)}}
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
	check(manifest.kit.design == "Runic forge", "The preset records the selected procedural design family")
	check(manifest.positions["0"].ContinueButton.x == 140 and manifest.positions["0"].ContinueButton.y == 130 and is_equal_approx(manifest.element_scales["1"].Health, 1.25), "The preset preserves positions and individual scales")
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
            if not button is Button or button.position != Vector2(140, 130) or not is_equal_approx(button.scale.x, 1.15):
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
