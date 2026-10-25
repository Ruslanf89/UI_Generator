extends SceneTree
## Native shape and reservoir regressions. No model or network is used.
## Headless: godot --headless --path . --script tests/run_kit_shape_tests.gd
## Render: DISPLAY=:99 godot --display-driver x11 --rendering-driver opengl3
##   --audio-driver Dummy --path . --script tests/run_kit_shape_tests.gd -- --render

const Kit = preload("res://scripts/kit_generator.gd")
const Shapes = preload("res://scripts/kit_shapes.gd")
const Design = preload("res://scripts/kit_design.gd")
const Exporter = preload("res://scripts/kit_exporter.gd")
const Pipeline = preload("res://scripts/ai_pipeline.gd")
var checks := 0
var failures: Array[String] = []
var scratch := ""

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
	scratch = temporary.path_join("uiforge_shape_test_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(scratch)
	var render_mode := "--render" in OS.get_cmdline_user_args()
	if render_mode:
		check(DisplayServer.get_name().to_lower() != "headless", "Rendering checks use an actual graphics backend")
		if failures.is_empty():
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
			await _test_rendered_masks()
			await _test_rendered_reservoirs()
	else:
		_test_mask_pixels()
		_test_native_values()
		_test_role_aliases()
		_test_portable_shapes()
	if failures.is_empty():
		print("SHAPE_PASS: %d %s checks. Artifacts: %s" % [checks, "rendering" if render_mode else "native shape/export", scratch])
		quit(0)
	else:
		printerr("SHAPE_FAILED: %d of %d checks. Artifacts: %s" % [failures.size(), checks, scratch])
		quit(1)

func _test_mask_pixels() -> void:
	var sample_points := {
		"circle": {"inside": Vector2(.5, .1), "outside": Vector2(.1, .1)},
		"hexagon": {"inside": Vector2(.5, .1), "outside": Vector2(.1, .1)},
		"shield": {"inside": Vector2(.5, .85), "outside": Vector2(.1, .9)},
		"octagon": {"inside": Vector2(.5, .1), "outside": Vector2(.1, .1)},
		"diamond": {"inside": Vector2(.5, .15), "outside": Vector2(.2, .2)},
		"square": {"inside": Vector2(.1, .1), "outside": Vector2(.005, .005)},
	}
	for pixel in [false, true]:
		var contours := {}
		for shape in Design.MAP_SHAPES:
			var texture: ImageTexture = Shapes.mask_texture(Vector2(128, 128), shape, pixel)
			check(texture != null, shape + " generates a usable native mask")
			if texture == null:
				continue
			var image := texture.get_image()
			check(image.get_size() == Vector2i(256, 256), shape + " mask has two-times resolution")
			check(_at(image, Vector2(.5, .5)).a > .99 and _at(image, sample_points[shape].inside).a > .99 and _at(image, sample_points[shape].outside).a < .01, shape + " has the intended geometric inside and outside")
			var bytes := image.get_data()
			contours[_alpha_bytes(image)] = true
			Shapes.mask_cache.clear()
			check(Shapes.mask_texture(Vector2(128, 128), shape, pixel).get_image().get_data() == bytes, shape + " mask reproduces after cache eviction")
			if pixel:
				var hard_alpha := true
				for index in range(3, bytes.size(), 4):
					hard_alpha = hard_alpha and bytes[index] in [0, 255]
				check(hard_alpha, shape + " pixel mask has crisp alpha edges")
		check(contours.size() == Design.MAP_SHAPES.size(), "All six map contours are geometrically distinct")

func _test_native_values() -> void:
	for style in Kit.STYLES:
		for form in Design.RESOURCE_FORMS:
			var config := Kit.make_config(style)
			config.kit.seed = 1733
			config.kit.stat_presentation = form
			config.kit.map_shape = "shield"
			for page in [1, 2]:
				var generated: Control = Kit.build(config, page)
				for component in ["Health", "Mana"]:
					var node: Control = generated.get_node(component)
					var value: Range = node.get_node("Value")
					var label := "%s/%s/%s/%s" % [style, Kit.PAGES[page], component, form]
					check(node.get_meta("stat_presentation", "") == form, label + " keeps its semantic presentation")
					check(value.visible and value.get_script() == null, label + " exposes a visible script-free native Range")
					value.max_value = 200
					value.value = 150
					check(value.value == 150 and value.max_value == 200, label + " retains the full native value and maximum API")
					if form in ["orb", "vial"]:
						check(value is TextureProgressBar, label + " uses a true TextureProgressBar")
						if value is TextureProgressBar:
							check(value.texture_under != null and value.texture_progress != null, label + " contains the empty vessel and liquid textures")
							if value.texture_progress != null:
								var image: Image = value.texture_progress.get_image()
								check(_at(image, Vector2(.5, .5)).a > .9 and _at(image, Vector2(.01, .01)).a < .05, label + " liquid has a shaped transparent contour")
							check(value.texture_progress.get_meta("kit_art_role", "") == ("fill_health" if component == "Health" else "fill_mana"), label + " preserves its existing AI fill-role alias")
					else:
						check(value is ProgressBar, label + " keeps the standard editable progress control")
				if page == 1:
					var mask: TextureRect = generated.get_node("Minimap/MapContent")
					check(mask.clip_children == CanvasItem.CLIP_CHILDREN_ONLY and mask.texture != null and mask.has_node("World"), style + "/" + form + " clips real map content through the mask")
				generated.free()

func _test_role_aliases() -> void:
	for style in Kit.STYLES:
		for form in ["orb", "vial"]:
			var config := Kit.make_config(style)
			config.kit.stat_presentation = form
			config.kit.map_shape = "hexagon"
			var roles: Array[String] = Pipeline.collect_roles(config)
			check(roles.size() == 19 and roles == Pipeline.ROLES, style + "/" + form + " preserves exactly the nineteen existing AI artwork roles")

func _test_portable_shapes() -> void:
	for form in ["orb", "vial"]:
		var config := Kit.make_config(Kit.STYLES[2])
		config.kit.seed = 1733
		config.kit.design = "Dragon covenant" if form == "orb" else "Bone crypt"
		config.kit.stat_presentation = form
		config.kit.map_shape = "hexagon" if form == "orb" else "shield"
		config.health = 37
		config.mana = 25
		var exported: Dictionary = Exporter.export_kit(config, 1, scratch)
		check(exported.ok, form + " kit exports all native scenes and textures")
		if not exported.ok:
			continue
		var scene := FileAccess.get_file_as_string(exported.path.path_join("hud.tscn"))
		check(scene.contains('type="TextureProgressBar"') and scene.contains("clip_children = %d" % CanvasItem.CLIP_CHILDREN_ONLY) and not scene.contains("ImageTexture") and not scene.contains("res://scripts/"), form + " export contains native liquid controls and alpha clipping with portable images")
		var game := scratch.path_join("game_" + form)
		_copy_tree(exported.path, game.path_join("kit"))
		_write(game.path_join("project.godot"), "config_version=5\n[application]\nconfig/name=\"Native Shape Export Test\"\n[rendering]\nrenderer/rendering_method=\"gl_compatibility\"\n")
		_write(game.path_join("verify.gd"), _export_verifier(form, config.kit.map_shape))
		var output: Array = []
		var code := OS.execute(OS.get_executable_path(), ["--headless", "--editor", "--path", game, "--import", "--quit"], output, true)
		check(code == 0 and not str(output).contains("ERROR:"), form + " PNG resources import in a fresh game: " + str(output))
		output.clear()
		code = OS.execute(OS.get_executable_path(), ["--headless", "--path", game, "--script", "verify.gd"], output, true)
		check(code == 0 and str(output).contains("NATIVE_SHAPE_EXPORT_OK") and not str(output).contains("ERROR:"), form + " native masks, textures, and Range APIs work independently: " + str(output))

func _export_verifier(form: String, map_shape: String) -> String:
	return """extends SceneTree
const FORM = %s
const MAP_SHAPE = %s
func _initialize():
    call_deferred("verify")
func verify():
    for page in ["menu", "hud", "components"]:
        var scene = load("res://kit/" + page + ".tscn").instantiate()
        root.add_child(scene)
        await process_frame
        var elements = scene.get_node("Canvas/Viewport/Design/Elements")
        if not native_only(elements):
            quit(1)
            return
        if page == "hud":
            var mask = elements.get_node("Minimap/MapContent")
            if not mask is TextureRect or mask.clip_children != CanvasItem.CLIP_CHILDREN_ONLY or mask.get_meta("map_shape", "") != MAP_SHAPE or not png_texture(mask.texture):
                quit(2)
                return
        if page != "menu":
            for component in ["Health", "Mana"]:
                var stat = elements.get_node(component)
                var value = stat.get_node("Value")
                if stat.get_meta("stat_presentation", "") != FORM or not value is TextureProgressBar or not value.visible or value.max_value != 100 or value.value != (37 if component == "Health" else 25):
                    quit(3)
                    return
                if not png_texture(value.texture_under) or not png_texture(value.texture_progress) or (value.texture_over != null and not png_texture(value.texture_over)):
                    quit(4)
                    return
                value.max_value = 200
                value.value = 150
                if value.max_value != 200 or value.value != 150:
                    quit(5)
                    return
        scene.queue_free()
        await process_frame
    print("NATIVE_SHAPE_EXPORT_OK")
    quit(0)
func png_texture(texture):
    return texture != null and texture.get_image() != null and texture.resource_path.begins_with("res://kit/art/") and texture.resource_path.ends_with(".png")
func native_only(node):
    if node.get_script() != null:
        return false
    for child in node.get_children():
        if not native_only(child):
            return false
    return true
""" % [JSON.stringify(form), JSON.stringify(map_shape)]

func _test_rendered_masks() -> void:
	for style in Kit.STYLES:
		for shape in Design.MAP_SHAPES:
			var config := Kit.make_config(style)
			config.kit.seed = 1733
			config.kit.map_shape = shape
			config.kit.stat_presentation = "bar"
			var generated: Control = Kit.build(config, 1)
			var source: TextureRect = generated.get_node("Minimap/MapContent")
			var mask: TextureRect = source.duplicate(0)
			for child in mask.get_children():
				child.free()
			mask.position = Vector2(24, 24)
			var fill := ColorRect.new()
			fill.position = Vector2(-16, -16)
			fill.size = mask.size + Vector2(32, 32)
			fill.color = Color(1, .1, .4, 1)
			mask.add_child(fill)
			var viewport := _viewport(Vector2i(mask.size) + Vector2i(48, 48))
			viewport.add_child(mask)
			var image: Image = await _capture(viewport)
			var mismatches := 0
			var inside := 0
			var outside := 0
			var source_image := mask.texture.get_image()
			if image != null:
				image.save_png(scratch.path_join("clip_%s_%s.png" % [style.replace(" ", "_"), shape]))
				for y in range(2, int(mask.size.y) - 2, 4):
					for x in range(2, int(mask.size.x) - 2, 4):
						var expected := _stable_mask_alpha(source_image, Vector2((x + .5) / mask.size.x, (y + .5) / mask.size.y))
						var actual := image.get_pixel(x + 24, y + 24).a
						if expected > .99:
							inside += 1
							mismatches += 1 if actual < .95 else 0
						elif expected < .01:
							outside += 1
							mismatches += 1 if actual > .05 else 0
				for point in [Vector2i(12, 24 + int(mask.size.y) / 2), Vector2i(24 + int(mask.size.x) / 2, 12), Vector2i(24 + int(mask.size.x) + 8, 24 + int(mask.size.y) / 2)]:
					mismatches += 1 if image.get_pixelv(point).a > .01 else 0
			check(image != null and inside > 10 and outside > 0 and mismatches == 0, style + "/" + shape + " really clips children outside its rendered alpha contour (%d mismatches)" % mismatches)
			viewport.free()
			generated.free()
			await process_frame

func _test_rendered_reservoirs() -> void:
	for style in Kit.STYLES:
		for form in ["orb", "vial"]:
			var config := Kit.make_config(style)
			config.kit.seed = 1733
			config.kit.stat_presentation = form
			var generated: Control = Kit.build(config, 1)
			for component in ["Health", "Mana"]:
				var source: Range = generated.get_node(component + "/Value")
				if not source is TextureProgressBar:
					check(false, style + "/" + form + " renders with a native liquid control")
					continue
				var value: TextureProgressBar = source.duplicate(0)
				value.position = Vector2(24, 24)
				value.min_value = 0
				value.max_value = 100
				value.value = 0
				var viewport := _viewport(Vector2i(value.size) + Vector2i(48, 48))
				viewport.add_child(value)
				var empty: Image = await _capture(viewport)
				value.value = 100
				var full: Image = await _capture(viewport)
				var changed := 0
				if empty != null and full != null:
					full.save_png(scratch.path_join("%s_%s_%s.png" % [style.replace(" ", "_"), form, component]))
					var first := empty.get_data()
					var second := full.get_data()
					for index in range(0, first.size(), 4):
						var distance := 0
						for channel in range(3):
							distance += absi(int(first[index + channel]) - int(second[index + channel]))
						changed += 1 if distance > 40 else 0
				check(empty != null and full != null and changed > value.size.x * value.size.y * .08, style + "/" + form + "/" + component + " visibly fills when native .value changes (%d pixels)" % changed)
				value.texture_under = null
				value.texture_over = null
				value.value = 50
				var half: Image = await _capture(viewport)
				if half != null:
					var top := half.get_pixel(24 + int(value.size.x * .5), 24 + int(value.size.y * .25)).a
					var bottom := half.get_pixel(24 + int(value.size.x * .5), 24 + int(value.size.y * .75)).a
					check(top < .01 and bottom > .9, style + "/" + form + "/" + component + " renders the native half-full level")
					if form == "orb":
						var edge := half.get_pixel(24 + int(value.size.x * .08), 24 + int(value.size.y * .6)).a
						check(edge > .9, style + "/" + component + " crops the original orb hemisphere without squeezing it")
				viewport.free()
				await process_frame
			generated.free()

func _viewport(size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport

func _capture(viewport: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	check(image != null and not image.is_empty(), "The graphics backend produced an actual viewport image")
	return image

func _at(image: Image, point: Vector2) -> Color:
	return image.get_pixel(clampi(int(point.x * image.get_width()), 0, image.get_width() - 1), clampi(int(point.y * image.get_height()), 0, image.get_height() - 1))

func _stable_mask_alpha(image: Image, point: Vector2) -> float:
	# The mask is at 2x resolution while the viewport samples it through the GPU
	# filter. Ignore a one-logical-pixel transition band around antialiased edges.
	var x := int(point.x * image.get_width())
	var y := int(point.y * image.get_height())
	var lowest := 1.0
	var highest := 0.0
	for offset_y in [-2, 0, 2]:
		for offset_x in [-2, 0, 2]:
			var alpha := image.get_pixel(clampi(x + offset_x, 0, image.get_width() - 1), clampi(y + offset_y, 0, image.get_height() - 1)).a
			lowest = minf(lowest, alpha)
			highest = maxf(highest, alpha)
	return 1.0 if lowest > .99 else (0.0 if highest < .01 else .5)

func _alpha_bytes(image: Image) -> PackedByteArray:
	var bytes := image.get_data()
	var mask := PackedByteArray()
	mask.resize(image.get_width() * image.get_height())
	for index in range(mask.size()):
		mask[index] = 1 if bytes[index * 4 + 3] >= 128 else 0
	return mask

func _copy_tree(source: String, destination: String) -> void:
	DirAccess.make_dir_recursive_absolute(destination)
	for filename in DirAccess.get_files_at(source):
		if not filename.ends_with(".import"):
			DirAccess.copy_absolute(source.path_join(filename), destination.path_join(filename))
	for directory in DirAccess.get_directories_at(source):
		_copy_tree(source.path_join(directory), destination.path_join(directory))

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
