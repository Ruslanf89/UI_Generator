extends SceneTree
## Mock HTTP integration only: no AI model, inference service, or GPU is used.
## Run: godot --headless --path . --script tests/run_ai_tests.gd

const Client = preload("res://scripts/comfy_client.gd")
const Pipeline = preload("res://scripts/ai_pipeline.gd")
const AIArt = preload("res://scripts/ai_art.gd")
const Kit = preload("res://scripts/kit_generator.gd")
const Art = preload("res://scripts/kit_art.gd")
const Exporter = preload("res://scripts/kit_exporter.gd")
var failures: Array[String] = []
var checks := 0
var scratch := ""
var endpoint := ""
var server_pid := -1
var generated_config: Dictionary = {}

func _initialize() -> void:
	root.tree_exiting.connect(_stop_server)
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
	scratch = temporary.path_join("uiforge_ai_test_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(scratch)
	if await _start_server():
		_test_workflow()
		_test_preparation()
		await _test_client()
		await _test_lifecycle()
		await _test_pipeline()
		if not generated_config.is_empty():
			_test_art_mapping()
			await _test_editor()
			_test_export()
		_test_request_log()
	_stop_server()
	if failures.is_empty():
		print("AI_PASS: %d checks. Mock ComfyUI HTTP, atomic artwork revisions, cancellation, native previews, and portable exports; no model or GPU used." % checks)
		quit(0)
	else:
		printerr("AI_FAILED: %d of %d checks. Fixture files: %s" % [failures.size(), checks, scratch])
		quit(1)

func _stop_server() -> void:
	if server_pid > 0 and OS.is_process_running(server_pid):
		OS.kill(server_pid)
	server_pid = -1

func _start_server() -> bool:
	var python := "python3" if OS.get_name() != "Windows" else "python"
	var port_file := scratch.path_join("server.port")
	server_pid = OS.create_process(python, [ProjectSettings.globalize_path("res://tests/fixtures/comfy_server.py"), "--port-file", port_file, "--log-file", scratch.path_join("requests.jsonl")], false)
	check(server_pid > 0, "Start the test-owned loopback HTTP fixture")
	var deadline := Time.get_ticks_msec() + 5000
	while not FileAccess.file_exists(port_file) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(FileAccess.file_exists(port_file), "The fixture chooses an available local port")
	if not FileAccess.file_exists(port_file):
		return false
	endpoint = "http://127.0.0.1:" + FileAccess.get_file_as_string(port_file).strip_edges()
	return true

func _control(options: Dictionary) -> void:
	var request := HTTPRequest.new()
	root.add_child(request)
	var error := request.request(endpoint + "/__control", ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(options))
	check(error == OK, "Configure the independent HTTP fixture")
	if error == OK:
		var response: Array = await request.request_completed
		check(response[0] == HTTPRequest.RESULT_SUCCESS and response[1] == 200, "The fixture accepted its test mode")
	request.queue_free()

func _test_workflow() -> void:
	var workflow: Dictionary = Client.build_workflow("fixture.safetensors", "Golden oak interface", "text, words", 426, 1024, 512, 12)
	check(workflow["4"].class_type == "CheckpointLoaderSimple" and workflow["4"].inputs.ckpt_name == "fixture.safetensors", "Workflow uses the selected installed checkpoint")
	check(workflow["6"].inputs.text == "Golden oak interface" and workflow["7"].inputs.text == "text, words", "Positive and negative prompts remain separate")
	check(workflow["5"].inputs.batch_size == 1 and workflow["5"].inputs.width == 1024 and workflow["5"].inputs.height == 512, "Workflow generates one bounded image per request")
	check(workflow["3"].inputs.seed == 426 and workflow["3"].inputs.steps == 12, "Workflow records reproducible sampling settings")
	check(workflow["3"].inputs.positive == ["6", 0] and workflow["3"].inputs.negative == ["7", 0], "Sampler receives both encoded prompts")
	check(workflow["9"].class_type == "SaveImage" and workflow["9"].inputs.images == ["8", 0], "Standard ComfyUI nodes decode and save the requested image")

func _test_preparation() -> void:
	var image := Image.create(40, 40, false, Image.FORMAT_RGBA8)
	image.fill(Color.MAGENTA)
	image.fill_rect(Rect2i(7, 7, 26, 26), Color("a46936"))
	var prepared: Dictionary = AIArt.prepare_image(image, "panel")
	check(prepared.ok and prepared.background_removed, "Connected magenta background becomes transparent")
	if prepared.ok:
		check(_alpha_count(prepared.image, false) > 0 and _alpha_count(prepared.image, true) > 0, "Prepared artwork retains its opaque subject and transparent margin")
	image.fill(Color.WHITE)
	image.fill_rect(Rect2i(7, 7, 26, 26), Color("bf8c3d"))
	image.fill_rect(Rect2i(13, 13, 14, 14), Color.WHITE)
	prepared = AIArt.prepare_image(image, "icon_shield")
	var enclosed_white := false
	if prepared.ok:
		for y in range(prepared.image.get_height()):
			for x in range(prepared.image.get_width()):
				var color: Color = prepared.image.get_pixel(x, y)
				enclosed_white = enclosed_white or (color.a > .99 and color.r > .99 and color.g > .99 and color.b > .99)
	check(prepared.ok and enclosed_white, "Removing white background preserves enclosed white details")
	for color in [Color.WHITE, Color.MAGENTA, Color.BLACK]:
		image.fill(color)
		check(not AIArt.prepare_image(image, "panel").ok, "A uniform blank image is rejected")
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(8, 8, 24, 24), Color("8f5028"))
	check(AIArt.prepare_image(image, "button").ok, "An already transparent source remains usable")

func _test_client() -> void:
	var client := Client.new()
	root.add_child(client)
	var progress_messages: Array[String] = []
	client.progress.connect(func(message): progress_messages.append(message))
	await _control({"reset_jobs": true})
	var connected: Dictionary = await client.probe_server(endpoint)
	check(connected.ok and connected.checkpoints == ["fixture.safetensors"], "Checkpoint discovery uses the real asynchronous HTTP client")
	for bad_endpoint in ["https://example.com", "http://127.0.0.1.evil.invalid:8188", "http://user@localhost:8188", endpoint + "/custom", "http://localhost:70000"]:
		var rejected: Dictionary = await client.probe_server(bad_endpoint)
		check(not rejected.ok and not str(rejected.error).is_empty(), "Reject an unsupported server address before any network call")
	var produced: Dictionary = await client.generate_image(endpoint, "fixture.safetensors", "Golden oak test fixture", "text", 482, 512, 512, 12)
	check(produced.ok and produced.image is Image and produced.image.get_size() == Vector2i(512, 512), "The client queues, polls, and decodes a fixture PNG")
	check(not str(produced.get("prompt_id", "")).is_empty() and progress_messages.size() >= 4, "The client supplies its job ID and progress messages")
	for invalid in [["", "prompt", 42, 512, 512, 12], ["fixture.safetensors", "", 42, 512, 512, 12], ["fixture.safetensors", "prompt", -1, 512, 512, 12], ["fixture.safetensors", "prompt", 42, 128, 512, 12], ["fixture.safetensors", "prompt", 42, 512, 512, 0]]:
		var rejected: Dictionary = await client.generate_image(endpoint, invalid[0], invalid[1], "", invalid[2], invalid[3], invalid[4], invalid[5])
		check(not rejected.ok, "Invalid generation settings return a useful failure")
	for options in [{"empty_models": true}, {"probe_error": true}, {"probe_bad_json": true}, {"probe_redirect": true}]:
		await _control(options)
		var unavailable: Dictionary = await client.probe_server(endpoint)
		check(not unavailable.ok and not str(unavailable.error).is_empty(), "Missing models and malformed discovery fail explicitly")
	for options in [{"history_error": true}, {"history_bad_json": true}, {"bad_image": true}, {"empty_output": true}, {"prompt_error": true}]:
		await _control(options)
		var failed: Dictionary = await client.generate_image(endpoint, "fixture.safetensors", "fixture", "", 43, 512, 512, 12)
		check(not failed.ok and not str(failed.error).is_empty(), "Server generation and invalid image failures resolve explicitly")
	await _control({"delay_path": "/object_info/CheckpointLoaderSimple", "delay_seconds": 1.5})
	var pending := {}
	call_deferred("_capture_probe", client, pending)
	var frames := Engine.get_process_frames()
	await create_timer(.08).timeout
	check(Engine.get_process_frames() > frames + 2, "Waiting for a slow HTTP response leaves the scene loop responsive")
	var busy: Dictionary = await client.probe_server(endpoint)
	check(not busy.ok, "Concurrent requests cannot overwrite an active client job")
	var cancelled_at := Time.get_ticks_msec()
	client.cancel()
	await _wait_result(pending, 2000)
	check(pending.has("result") and pending.result.get("cancelled", false) and Time.get_ticks_msec() - cancelled_at < 1000, "Cancel resolves an in-flight HTTP await promptly (%d ms, %s)" % [Time.get_ticks_msec() - cancelled_at, str(pending)])
	await _control({"history_wait": true})
	pending = {}
	call_deferred("_capture_client_generation", client, pending)
	await create_timer(.1).timeout
	client.cancel()
	await _wait_result(pending, 2000)
	check(pending.has("result") and pending.result.get("cancelled", false), "Cancel also resolves the wait between history polls")
	await _control({})
	var offline: Dictionary = await client.probe_server("http://127.0.0.1:1")
	check(not offline.ok and not str(offline.error).is_empty(), "An offline localhost service returns connection guidance")
	client.queue_free()
	await process_frame

func _test_pipeline() -> void:
	var pipeline := Pipeline.new()
	root.add_child(pipeline)
	var config: Dictionary = Kit.make_config(Kit.STYLES[0])
	config.kit.seed = 4829
	config.positions = {"0": {"ContinueButton": Vector2(140, 280)}}
	config.element_scales = {"0": {"ContinueButton": 1.15}}
	var roles: Array[String] = Pipeline.collect_roles(config)
	check(roles.size() == 19 and "button" in roles and "icon_sword" in roles and "fill_mana" in roles, "A complete kit discovers all nineteen artwork roles")
	check(Pipeline.collect_roles(config, "ContinueButton") == ["button"], "Selected regeneration requests only the component's needed role")
	var before := config.duplicate(true)
	var notices: Array = []
	pipeline.progress.connect(func(message, completed, total): notices.append([message, completed, total]))
	await _control({"reset_jobs": true})
	var result: Dictionary = await pipeline.generate(config, endpoint, "fixture.safetensors", "Carved golden oak, geometric test fixture", "", 12)
	check(result.ok, "The full pipeline prepares a coordinated image family")
	check(config == before, "Full generation returns an atomic revision without mutating the current design")
	if not result.ok:
		pipeline.queue_free()
		return
	check(result.ai.enabled and result.ai.assets.size() == roles.size() and result.ai.component_assets.is_empty(), "The completed revision supplies every requested role")
	for role in roles:
		var asset: Dictionary = result.ai.assets[role]
		check(FileAccess.file_exists(asset.path) and FileAccess.get_sha256(asset.path) == asset.sha256, role + " is a real hash-verified cached PNG")
		check(asset.background_removed and str(asset.prompt).contains("Carved golden oak") and asset.checkpoint == "fixture.safetensors", role + " records its prompt, checkpoint, and transparency preparation")
	check(notices.size() > roles.size() and notices[-1][1] == roles.size() and notices[-1][2] == roles.size(), "Progress reaches the completed role count")
	config.ai = result.ai
	var family_before: Dictionary = config.ai.assets.duplicate(true)
	await _control({})
	var selected: Dictionary = await pipeline.generate(config, endpoint, "fixture.safetensors", "Silvered oak, selected fixture", "ContinueButton", 12)
	check(selected.ok and selected.ai.assets == family_before, "Selected generation keeps every shared family asset unchanged")
	if selected.ok:
		check(selected.ai.component_assets.ContinueButton.keys() == ["button"], "Selected generation adds only the requested component override")
		check(selected.ai.component_assets.ContinueButton.button.sha256 != config.ai.assets.button.sha256, "Selected regeneration can create a different artwork image")
		config.ai = selected.ai
	generated_config = config.duplicate(true)
	before = config.duplicate(true)
	for options in [{"reset_jobs": true, "corrupt_on_job": 3}, {"blank_image": true}]:
		await _control(options)
		var failed: Dictionary = await pipeline.generate(config, endpoint, "fixture.safetensors", "Failing fixture", "", 12)
		check(not failed.ok and config == before and not pipeline.busy, "A partial or unusable image failure preserves all previous artwork and clears busy state")
	await _control({"history_wait": true})
	var pending := {}
	call_deferred("_capture_pipeline", pipeline, config, pending)
	await create_timer(.1).timeout
	check(pipeline.busy and config == before, "Pending generation keeps the last complete artwork visible")
	pipeline.cancel()
	await _wait_result(pending, 2000)
	check(pending.has("result") and not pending.result.ok and pending.result.get("cancelled", false) and config == before and not pipeline.busy, "Pipeline cancellation returns promptly and preserves the previous revision")
	await _control({})
	pipeline.queue_free()
	await process_frame

func _test_lifecycle() -> void:
	await _control({"delay_path": "/view", "delay_seconds": 1.5})
	var script := scratch.path_join("lifecycle.gd")
	_write(script, _lifecycle_verifier())
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", script], output, true)
	check(code == 0 and str(output).contains("AI_LIFECYCLE_OK") and not str(output).contains("ERROR:") and not str(output).contains("WARNING:"), "Closing the app and freeing a partially completed pipeline cancel their awaits and remove only owned cache files: " + str(output))
	for chunk in output:
		for line in str(chunk).split("\n"):
			if line.begins_with("AI_DIALOG_CONTENT_MIN:"):
				print(line)
	await _control({})

func _lifecycle_verifier() -> String:
	return """extends SceneTree
const Pipeline = preload("res://scripts/ai_pipeline.gd")
const Kit = preload("res://scripts/kit_generator.gd")
const ENDPOINT = %s
var state = {"receiving": false, "http_folder": "", "saved": false, "local_folder": ""}
func _initialize():
    create_timer(15).timeout.connect(func(): quit(99))
    call_deferred("verify")
func verify():
    var pref_path = ProjectSettings.globalize_path("user://local_ai.cfg")
    var had_prefs = FileAccess.file_exists(pref_path)
    var prefs = FileAccess.get_file_as_bytes(pref_path) if had_prefs else PackedByteArray()
    var sentinel = ProjectSettings.globalize_path("user://ai_art/lifecycle_sentinel_" + str(OS.get_process_id()))
    DirAccess.make_dir_recursive_absolute(sentinel)
    var sentinel_file = FileAccess.open(sentinel.path_join("keep.txt"), FileAccess.WRITE)
    sentinel_file.store_string("another job's cache")
    sentinel_file.close()
    var app = load("res://scenes/main.tscn").instantiate()
    root.add_child(app)
    await process_frame
    await process_frame
    print("AI_DIALOG_CONTENT_MIN: ", app.ai_dialog.get_contents_minimum_size())
    app._set_creation_mode(1)
    app.generate()
    app.ai_endpoint.text = ENDPOINT
    app.ai_prompt.text = "Lifecycle geometric fixture"
    app.ai_model_picker.clear()
    app.ai_model_picker.add_item("fixture.safetensors")
    app.ai_model_picker.set_item_metadata(0, "fixture.safetensors")
    app.ai_model_picker.select(0)
    app.ai_pipeline.progress.connect(func(message, _completed, _total):
        if message.contains("Receiving generated artwork"):
            state.receiving = true
            state.http_folder = app.ai_pipeline._job_folder
    )
    app.call_deferred("_generate_ai_art", "ContinueButton")
    var deadline = Time.get_ticks_msec() + 5000
    while not state.receiving and Time.get_ticks_msec() < deadline:
        await process_frame
    if not state.receiving:
        quit(1)
        return
    await create_timer(.08).timeout
    app.queue_free()
    await process_frame
    await process_frame
    if is_instance_valid(app) or state.http_folder.is_empty() or DirAccess.dir_exists_absolute(state.http_folder):
        quit(2)
        return
    var pipeline = Pipeline.new()
    root.add_child(pipeline)
    pipeline.progress.connect(func(message, completed, _total):
        if completed == 1 and message.begins_with("Prepared "):
            state.saved = true
            state.local_folder = pipeline._job_folder
            pipeline.queue_free()
    )
    pipeline.call_deferred("generate", Kit.make_config(), ENDPOINT, "fixture.safetensors", "Lifecycle partial fixture", "", 12)
    deadline = Time.get_ticks_msec() + 8000
    while not state.saved and Time.get_ticks_msec() < deadline:
        await process_frame
    await process_frame
    await process_frame
    await process_frame
    if not state.saved or is_instance_valid(pipeline) or state.local_folder.is_empty() or DirAccess.dir_exists_absolute(state.local_folder) or not FileAccess.file_exists(sentinel.path_join("keep.txt")):
        quit(3)
        return
    DirAccess.remove_absolute(sentinel.path_join("keep.txt"))
    DirAccess.remove_absolute(sentinel)
    if had_prefs:
        var pref_file = FileAccess.open(pref_path, FileAccess.WRITE)
        pref_file.store_buffer(prefs)
    else:
        DirAccess.remove_absolute(pref_path)
    print("AI_LIFECYCLE_OK")
    quit(0)
""" % JSON.stringify(endpoint)

func _test_art_mapping() -> void:
	var config := generated_config.duplicate(true)
	var normal: ImageTexture = Art.texture(config, Vector2(312, 62), "ContinueButton", "button")
	check(normal.get_meta("kit_art_source", "") == "ai" and normal.get_size() == Vector2(624, 124), "Kit controls use their generated component image at twice logical resolution")
	var global_button: ImageTexture = Art.texture(config, Vector2(312, 62), "NewJourneyButton", "button")
	check(normal.get_image().get_data() != global_button.get_image().get_data(), "The selected image overrides its component while other buttons keep the shared family")
	for state in ["hover", "pressed", "disabled", "focus"]:
		var image: ImageTexture = Art.texture(config, Vector2(312, 62), "ContinueButton", "button", state)
		check(image.get_meta("kit_art_source", "") == "ai" and image.get_image().get_data() != normal.get_image().get_data(), "Native button " + state + " is derived from the generated image")
	config.ai.component_assets.ContinueButton.button.path = scratch.path_join("missing.png")
	var fallback: ImageTexture = Art.texture(config, Vector2(312, 62), "ContinueButton", "button")
	check(fallback.get_image().get_data() == global_button.get_image().get_data(), "A missing component override falls back to valid family artwork")
	config.ai.assets.button.sha256 = "invalid"
	check(Art.texture(config, Vector2(312, 62), "ContinueButton", "button").get_meta("kit_art_source", "") == "procedural", "Invalid cached-image hashes safely use procedural artwork")
	config = generated_config.duplicate(true)
	config.style = Kit.STYLES[1]
	var pixel: Image = Art.texture(config, Vector2(60, 60), "Icon1", "icon_sword").get_image()
	check(_alpha_count(pixel, false) + _alpha_count(pixel, true) == pixel.get_width() * pixel.get_height(), "Generated pixel-style images keep hard alpha edges")
	var hud: Control = Kit.build(generated_config, 1)
	hud.get_node("Health/Value").value = 23
	check(hud.get_node("Health/Value").value == 23 and hud.get_node("Health/Value").get_script() == null, "Generated artwork preserves editable native progress bars")
	hud.free()

func _test_editor() -> void:
	var preference_path := ProjectSettings.globalize_path("user://local_ai.cfg")
	var had_preferences := FileAccess.file_exists(preference_path)
	var previous_preferences := FileAccess.get_file_as_bytes(preference_path) if had_preferences else PackedByteArray()
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	app._set_creation_mode(1)
	app.generate()
	app._apply_transform(0, "ContinueButton", Vector2(140, 280), 1.15)
	app.ai_endpoint.text = endpoint
	app.ai_prompt.text = "App integration geometric fixture"
	app.ai_quality_picker.select(0)
	await _control({})
	await app._connect_ai()
	check(app.ai_model_picker.item_count > 0 and not app.ai_busy, "The app can discover a local model through its connection UI")
	app.preview.selected_element = "ContinueButton"
	var first_piece: Dictionary = await app._generate_selected_ai()
	check(first_piece.ok and app.current_config.ai.assets.is_empty() and app.current_config.ai.component_assets.ContinueButton.size() == 1, "Generate selected piece can start from an entirely procedural kit")
	check(app.preview.hud.get_node("ContinueButton").get_theme_stylebox("normal").texture.get_meta("kit_art_source", "") == "ai" and app.preview.hud.get_node("NewJourneyButton").get_theme_stylebox("normal").texture.get_meta("kit_art_source", "") == "procedural", "A first generated piece coexists with the other procedural controls")
	app.layout_history.undo()
	check(not app.current_config.get("ai", {}).get("enabled", false), "The first selected-piece generation can be undone")
	app._apply_ai_result(generated_config.ai)
	var prior: Dictionary = app.current_config.ai.duplicate(true)
	app.preview.selected_element = "ContinueButton"
	app._regenerate_selected()
	check(app.ai_busy and app.generate_button.disabled and app.creation_picker.disabled and not app.ai_cancel_button.disabled, "The selected-regeneration action starts AI work and exposes its cancel control")
	app._apply_transform(0, "ContinueButton", Vector2(180, 300), 1.2)
	var deadline := Time.get_ticks_msec() + 15000
	while app.ai_busy and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not app.ai_busy and app.current_config.ai.revision > prior.revision and app.current_config.ai.assets == prior.assets, "App selected generation completes a new revision while preserving the image family")
	check(app.preview.hud.get_node("ContinueButton").position == Vector2(180, 300) and is_equal_approx(app.preview.hud.get_node("ContinueButton").scale.x, 1.2), "Successful asynchronous artwork generation preserves moves made during its job")
	var replacement: Dictionary = app.current_config.ai.duplicate(true)
	check(replacement.component_assets.ContinueButton.button.steps == 12, "The app's Fast quality option reaches the actual sampling workflow")
	app.layout_history.undo()
	check(app.current_config.ai == prior, "App artwork undo restores the entire prior revision")
	app.layout_history.redo()
	check(app.current_config.ai == replacement, "App artwork redo restores the generated revision")
	await _control({"history_wait": true})
	var pending := {}
	call_deferred("_capture_app", app, pending)
	await create_timer(.1).timeout
	check(app.ai_busy and app.current_config.ai == replacement, "The app displays existing artwork while generation is pending")
	app.ai_pipeline.cancel()
	await _wait_result(pending, 2000)
	check(pending.has("result") and not app.ai_busy and app.current_config.ai == replacement, "Cancel restores app controls and keeps the previous image revision")
	await _control({})
	app._restore_procedural_art()
	check(not app.current_config.get("ai", {}).get("enabled", false) and app.preview.hud.get_node("ContinueButton").position == Vector2(180, 300), "Restoring procedural art keeps the arrangement")
	app.layout_history.undo()
	check(app.current_config.ai == replacement, "The procedural-art restore action is undoable")
	app.queue_free()
	await process_frame
	if had_preferences:
		var preference_file := FileAccess.open(preference_path, FileAccess.WRITE)
		preference_file.store_buffer(previous_preferences)
	else:
		DirAccess.remove_absolute(preference_path)

func _test_export() -> void:
	var config := generated_config.duplicate(true)
	config.health = 43
	config.mana = 28
	config.positions["1"] = {"Health": Vector2(60, 300)}
	config.element_scales["1"] = {"Health": 1.25}
	var exported: Dictionary = Exporter.export_kit(config, 1, scratch)
	check(exported.ok, "A kit containing generated artwork exports successfully")
	if not exported.ok:
		return
	var preset := FileAccess.get_file_as_string(exported.path.path_join("preset.json"))
	check(not preset.contains("user://") and not preset.contains("/tmp/") and not preset.contains("/workspace/") and not preset.contains("/home/"), "The export manifest discloses no local artwork cache paths")
	var manifest = JSON.parse_string(preset)
	check(manifest.ai.enabled and manifest.ai.assets.button.sha256 == config.ai.assets.button.sha256 and manifest.ai.component_assets.ContinueButton.button.sha256 == config.ai.component_assets.ContinueButton.button.sha256, "Export preserves shared and selected-image provenance hashes")
	check(not manifest.ai.assets.button.has("path"), "The portable manifest omits machine-specific source paths")
	for name in ["menu.tscn", "hud.tscn", "components.tscn", "kit_theme.tres"]:
		var text := FileAccess.get_file_as_string(exported.path.path_join(name))
		check(not text.contains("user://") and not text.contains("res://scripts/") and not text.contains("/tmp/") and not text.contains("ImageTexture"), name + " uses portable PNG resources without generator dependencies")
	var game := scratch.path_join("independent_game")
	_copy_tree(exported.path, game.path_join("generated_kit"))
	_write(game.path_join("project.godot"), "config_version=5\n[application]\nconfig/name=\"Generated Artwork Export Fixture\"\n[rendering]\nrenderer/rendering_method=\"gl_compatibility\"\n")
	_write(game.path_join("verify.gd"), _independent_verifier())
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--editor", "--path", game, "--import", "--quit"], output, true)
	check(code == 0 and not str(output).contains("ERROR:"), "An independent project imports every generated PNG and scene: " + str(output))
	output.clear()
	code = OS.execute(OS.get_executable_path(), ["--headless", "--path", game, "--script", "verify.gd"], output, true)
	check(code == 0 and str(output).contains("GENERATED_ART_EXPORT_OK") and not str(output).contains("ERROR:"), "Independent scenes retain real textures, native states, and live bars: " + str(output))

func _independent_verifier() -> String:
	return """extends SceneTree
func _initialize():
    call_deferred("verify")
func verify():
    for filename in ["menu", "hud", "components"]:
        var packed = load("res://generated_kit/" + filename + ".tscn")
        if packed == null:
            quit(1)
            return
        var scene = packed.instantiate()
        root.add_child(scene)
        await process_frame
        var elements = scene.get_node("Canvas/Viewport/Design/Elements")
        if not script_free(elements):
            quit(2)
            return
        if filename == "menu":
            var button = elements.get_node("ContinueButton")
            if button.position != Vector2(140, 280) or not is_equal_approx(button.scale.x, 1.15):
                quit(3)
                return
            for state in ["normal", "hover", "pressed", "disabled", "focus"]:
                var style = button.get_theme_stylebox(state)
                if not style is StyleBoxTexture or style.texture == null or style.texture.get_image() == null or not style.texture.resource_path.begins_with("res://generated_kit/art/"):
                    quit(4)
                    return
        if filename == "hud":
            var health = elements.get_node("Health")
            if health.position != Vector2(60, 300) or not is_equal_approx(health.scale.x, 1.25) or health.get_node("Value").value != 43:
                quit(5)
                return
            health.get_node("Value").value = 17
            if health.get_node("Value").value != 17 or elements.get_node("Mana/Value").value != 28:
                quit(6)
                return
        scene.queue_free()
        await process_frame
    print("GENERATED_ART_EXPORT_OK")
    quit(0)
func script_free(node):
    if node.get_script() != null:
        return false
    if node is TextureProgressBar:
        for texture in [node.texture_under, node.texture_progress, node.texture_over]:
            if texture != null and (texture.get_image() == null or not texture.resource_path.begins_with("res://generated_kit/art/")):
                return false
    for child in node.get_children():
        if not script_free(child):
            return false
    return true
"""

func _test_request_log() -> void:
	var lines := FileAccess.get_file_as_string(scratch.path_join("requests.jsonl")).split("\n", false)
	var prompt_count := 0
	var safe := true
	var dimensions_safe := true
	for line in lines:
		var record = JSON.parse_string(line)
		if record.method == "POST" and record.path != "/__control":
			safe = safe and record.path == "/prompt"
		if record.path == "/prompt":
			prompt_count += 1
			var latent: Dictionary = record.body.prompt["5"].inputs
			dimensions_safe = dimensions_safe and latent.batch_size == 1 and latent.width <= 1024 and latent.height <= 1024
	check(safe, "Cancellation never interrupts or deletes other ComfyUI server jobs")
	check(prompt_count >= 23 and dimensions_safe, "Every actual prompt uses a single bounded image batch")

func _capture_probe(client: Node, sink: Dictionary) -> void:
	sink.result = await client.probe_server(endpoint)

func _capture_client_generation(client: Node, sink: Dictionary) -> void:
	sink.result = await client.generate_image(endpoint, "fixture.safetensors", "Waiting fixture", "", 43, 512, 512, 12)

func _capture_pipeline(pipeline: Node, config: Dictionary, sink: Dictionary) -> void:
	sink.result = await pipeline.generate(config, endpoint, "fixture.safetensors", "Waiting fixture", "ContinueButton", 12)

func _capture_app(app: Node, sink: Dictionary) -> void:
	await app._generate_ai_art("ContinueButton")
	sink.result = true

func _wait_result(sink: Dictionary, milliseconds: int) -> void:
	var deadline := Time.get_ticks_msec() + milliseconds
	while not sink.has("result") and Time.get_ticks_msec() < deadline:
		await process_frame

func _alpha_count(image: Image, opaque: bool) -> int:
	var result := 0
	var bytes := image.get_data()
	for index in range(3, bytes.size(), 4):
		if bytes[index] == (255 if opaque else 0):
			result += 1
	return result

func _copy_tree(source: String, destination: String) -> void:
	DirAccess.make_dir_recursive_absolute(destination)
	for filename in DirAccess.get_files_at(source):
		if not filename.ends_with(".import"):
			DirAccess.copy_absolute(source.path_join(filename), destination.path_join(filename))
	for directory in DirAccess.get_directories_at(source):
		_copy_tree(source.path_join(directory), destination.path_join(directory))

func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
