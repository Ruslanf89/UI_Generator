extends Control

const Generator = preload("res://scripts/hud_generator.gd")
const Exporter = preload("res://scripts/hud_exporter.gd")
const Preview = preload("res://scripts/hud_preview.gd")
const Art = preload("res://scripts/hud_art.gd")
const Kit = preload("res://scripts/kit_generator.gd")
const KitDesign = preload("res://scripts/kit_design.gd")
const AIPipeline = preload("res://scripts/ai_pipeline.gd")
const INK = Color("edf1f3")
const MUTED = Color("87959f")
const GREEN = Color("b9ef77")
const SURFACE = Color("111a22")
const BORDER = Color("25323c")

var genre_picker: OptionButton
var resolution_picker: OptionButton
var component_checks: Dictionary = {}
var style_buttons: Dictionary = {}
var selected_style = "Military"
var selected_variant = 0
var current_config: Dictionary = {}
var preview: Control
var variant_previews: Array = []
var variant_buttons: Array = []
var variant_labels: Array = []
var accent_picker: ColorPickerButton
var size_slider: HSlider
var health_slider: HSlider
var mana_slider: HSlider
var health_value: Label
var mana_value: Label
var scale_value: Label
var title_label: Label
var detail_label: Label
var selected_label: Label
var status_label: Label
var dirty_label: Label
var component_count: Label
var export_button: Button
var export_dialog: FileDialog
var export_result: AcceptDialog
var updating_controls = false
var position_label: Label
var layout_history = UndoRedo.new()
var art_detail: OptionButton
var art_material: OptionButton
var art_scale: HSlider
var art_wear: HSlider
var art_strength: HSlider
var art_seed: SpinBox
var art_update_timer: Timer
var creation_picker: OptionButton
var hud_brief: VBoxContainer
var kit_brief: VBoxContainer
var kit_brief_scroll: ScrollContainer
var kit_style_picker: OptionButton
var kit_design_picker: OptionButton
var kit_material_picker: OptionButton
var kit_ornament_picker: OptionButton
var kit_seed: SpinBox
var kit_seed_lock: CheckBox
var generate_button: Button
var art_controls: VBoxContainer
var kit_controls: VBoxContainer
var regenerate_button: Button
var new_ui_button: Button
var ai_pipeline: Node
var ai_dialog: AcceptDialog
var ai_endpoint: LineEdit
var ai_model_picker: OptionButton
var ai_quality_picker: OptionButton
var ai_prompt: TextEdit
var ai_status: Label
var ai_progress: ProgressBar
var ai_connect_button: Button
var ai_generate_button: Button
var ai_selected_button: Button
var ai_cancel_button: Button
var ai_restore_button: Button
var ai_hint: Label
var ai_busy = false
var ai_preferred_checkpoint = ""

func _ready() -> void:
	DisplayServer.window_set_min_size(Vector2i(1120, 900))
	_build_theme()
	_build_ui()
	_apply_genre_defaults()
	generate()

func _exit_tree() -> void:
	if is_instance_valid(ai_pipeline):
		ai_pipeline.cancel()
	layout_history.free()

func _build_theme() -> void:
	var app_theme = Theme.new()
	app_theme.default_font_size = 14
	app_theme.set_color("font_color", "Label", INK)
	app_theme.set_color("font_color", "Button", INK)
	app_theme.set_color("font_hover_color", "Button", Color.WHITE)
	app_theme.set_color("font_pressed_color", "Button", GREEN)
	app_theme.set_color("font_color", "CheckBox", Color("bac4cc"))
	app_theme.set_color("font_color", "OptionButton", INK)
	for type in ["Button", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var bg = Color("1a2631") if state in ["hover", "pressed"] else Color("141f28")
			var stroke = GREEN.darkened(0.4) if state == "focus" else BORDER
			var style = Generator.panel_style(bg, stroke, 7)
			style.content_margin_left = 12
			style.content_margin_right = 12
			style.content_margin_top = 8
			style.content_margin_bottom = 8
			app_theme.set_stylebox(state, type, style)
	app_theme.set_stylebox("panel", "PopupMenu", Generator.panel_style(SURFACE, BORDER, 6))
	var dialog_panel = Generator.panel_style(SURFACE, BORDER, 10)
	for side in ["left", "right", "top", "bottom"]:
		dialog_panel.set("content_margin_" + side, 14)
	app_theme.set_stylebox("panel", "AcceptDialog", dialog_panel)
	var dialog_border = get_theme_stylebox("embedded_border", "Window").duplicate()
	if dialog_border is StyleBoxFlat:
		dialog_border.bg_color = SURFACE
		dialog_border.border_color = BORDER
		app_theme.set_stylebox("embedded_border", "Window", dialog_border)
	for type in ["LineEdit", "TextEdit"]:
		app_theme.set_stylebox("normal", type, Generator.panel_style(Color("0b141d"), BORDER, 5))
		app_theme.set_stylebox("read_only", type, Generator.panel_style(SURFACE, BORDER, 5))
	app_theme.set_color("font_color", "PopupMenu", INK)
	app_theme.set_stylebox("panel", "PanelContainer", Generator.panel_style(SURFACE, BORDER, 12))
	for state in ["slider", "grabber_area", "grabber_area_highlight"]:
		var track = Generator.panel_style(Color("2a3843") if state == "slider" else GREEN.darkened(0.2), Color.TRANSPARENT, 2, 0)
		track.content_margin_top = 2
		track.content_margin_bottom = 2
		app_theme.set_stylebox(state, "HSlider", track)
	theme = app_theme

func _build_ui() -> void:
	var backdrop = ColorRect.new()
	backdrop.color = Color("0b1219")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 18)
	margin.add_child(page)
	_header(page)
	var workspace = HBoxContainer.new()
	workspace.add_theme_constant_override("separation", 18)
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(workspace)
	_sidebar(workspace)
	_center(workspace)
	_inspector(workspace)
	var footer = HBoxContainer.new()
	page.add_child(footer)
	status_label = _label("Ready to create. Everything stays on your device.", 12, MUTED)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.clip_text = true
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	footer.add_child(status_label)
	footer.add_child(_label("CTRL + G  Generate     /     CTRL + E  Export", 11, MUTED))
	export_dialog = FileDialog.new()
	export_dialog.title = "Choose a folder for your Godot HUD"
	export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	export_dialog.size = Vector2i(900, 600)
	export_dialog.dir_selected.connect(_export_to)
	add_child(export_dialog)
	export_result = AcceptDialog.new()
	export_result.title = "Your HUD is ready"
	export_result.min_size = Vector2i(580, 180)
	add_child(export_result)
	_build_ai_studio()

func _build_ai_studio() -> void:
	ai_pipeline = AIPipeline.new()
	add_child(ai_pipeline)
	ai_pipeline.progress.connect(_ai_progress_changed)
	ai_dialog = AcceptDialog.new()
	ai_dialog.theme = theme
	ai_dialog.title = "Local AI prompt studio"
	ai_dialog.min_size = Vector2i(720, 650)
	ai_dialog.get_ok_button().text = "Close"
	add_child(ai_dialog)
	var body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	ai_dialog.add_child(body)
	body.add_child(_wrapped("Generate new artwork with your local ComfyUI model. Text, buttons, and bars stay editable.", 13, INK))
	body.add_child(_label("LOCAL COMFYUI ADDRESS", 11, MUTED))
	var connection = HBoxContainer.new()
	body.add_child(connection)
	ai_endpoint = LineEdit.new()
	ai_endpoint.text = "http://127.0.0.1:8188"
	ai_endpoint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	connection.add_child(ai_endpoint)
	ai_connect_button = _button("Connect & load models")
	ai_connect_button.add_theme_font_size_override("font_size", 12)
	ai_connect_button.pressed.connect(_connect_ai)
	connection.add_child(ai_connect_button)
	body.add_child(_label("SDXL CHECKPOINT", 11, MUTED))
	ai_model_picker = OptionButton.new()
	ai_model_picker.fit_to_longest_item = false
	ai_model_picker.add_item("Connect to load installed checkpoints")
	ai_model_picker.disabled = true
	body.add_child(ai_model_picker)
	ai_quality_picker = OptionButton.new()
	ai_quality_picker.add_item("Fast preview · 12 sampling steps")
	ai_quality_picker.add_item("Detailed artwork · 20 sampling steps")
	ai_quality_picker.select(1)
	body.add_child(ai_quality_picker)
	body.add_child(_label("DESCRIBE YOUR ARTWORK", 11, MUTED))
	ai_prompt = TextEdit.new()
	ai_prompt.custom_minimum_size = Vector2(0, 145)
	ai_prompt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ai_prompt.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	ai_prompt.placeholder_text = "Describe materials, ornaments, colors, and the mood of your game…"
	ai_prompt.text = "Hand-painted high fantasy interface with intricate carved frames, aged bronze trim, dragon ornaments, and glowing blue magical crystals."
	body.add_child(ai_prompt)
	body.add_child(_wrapped("A full kit generates 19 images, one at a time. On an 8 GB GPU this can take several minutes. Buttons share artwork across their interactive states.", 11, MUTED))
	var actions = HBoxContainer.new()
	body.add_child(actions)
	ai_generate_button = _button("Generate AI artwork", true)
	ai_generate_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ai_generate_button.pressed.connect(_generate_ai_art)
	actions.add_child(ai_generate_button)
	ai_selected_button = _button("Generate selected piece")
	ai_selected_button.add_theme_font_size_override("font_size", 12)
	ai_selected_button.disabled = true
	ai_selected_button.pressed.connect(_generate_selected_ai)
	actions.add_child(ai_selected_button)
	ai_cancel_button = _button("Cancel")
	ai_cancel_button.disabled = true
	ai_cancel_button.tooltip_text = "Stop this UI Forge job. The current image may still finish in ComfyUI."
	ai_cancel_button.pressed.connect(_cancel_ai)
	actions.add_child(ai_cancel_button)
	ai_progress = ProgressBar.new()
	ai_progress.custom_minimum_size.y = 18
	ai_progress.max_value = 19
	ai_progress.value = 0
	body.add_child(ai_progress)
	ai_status = _wrapped("Start ComfyUI, then connect. Choose the SDXL base checkpoint you installed. Your current design stays visible until generation completes.", 12, MUTED)
	ai_status.custom_minimum_size.y = 52
	body.add_child(ai_status)
	var help = LinkButton.new()
	help.text = "Windows / RTX 50-series setup guide ↗"
	help.uri = "https://github.com/Ruslanf89/UI_Generator/blob/main/docs/local-ai-guide.md"
	body.add_child(help)
	var preferences = ConfigFile.new()
	if preferences.load("user://local_ai.cfg") == OK:
		ai_endpoint.text = str(preferences.get_value("studio", "endpoint", ai_endpoint.text))
		ai_prompt.text = str(preferences.get_value("studio", "prompt", ai_prompt.text))
		ai_preferred_checkpoint = str(preferences.get_value("studio", "checkpoint", ""))
		ai_quality_picker.select(clampi(int(preferences.get_value("studio", "quality", 1)), 0, 1))

func _connect_ai() -> Dictionary:
	if ai_busy:
		return {"ok": false, "error": "Another AI request is already running."}
	_set_ai_busy(true)
	_ai_progress_changed("Connecting to local ComfyUI…", 0, 19)
	var result: Dictionary = await ai_pipeline.probe(ai_endpoint.text.strip_edges())
	if result.get("ok", false):
		ai_model_picker.clear()
		for checkpoint in result.get("checkpoints", []):
			ai_model_picker.add_item(str(checkpoint))
			var index = ai_model_picker.item_count - 1
			ai_model_picker.set_item_metadata(index, str(checkpoint))
			if str(checkpoint) == ai_preferred_checkpoint or (ai_preferred_checkpoint.is_empty() and "sd_xl_base" in str(checkpoint).to_lower()):
				ai_model_picker.select(index)
		ai_status.text = "Connected. Choose an SDXL-compatible checkpoint, describe the artwork, and generate. The app creates each asset with a batch size of one."
		_save_ai_preferences()
	else:
		ai_model_picker.clear()
		ai_model_picker.add_item("Connect to load installed checkpoints")
		ai_status.text = str(result.get("error", "Could not connect to ComfyUI.")).left(600)
	_set_ai_busy(false)
	return result

func _generate_ai_art(component: String = "") -> Dictionary:
	if ai_busy:
		return {"ok": false, "error": "Another AI request is already running."}
	if current_config.get("mode", "hud") != "kit":
		ai_status.text = "Choose Fantasy UI kit and Generate complete kit first."
		return {"ok": false, "error": ai_status.text}
	var checkpoint = ""
	if ai_model_picker.selected >= 0:
		var selected: Variant = ai_model_picker.get_item_metadata(ai_model_picker.selected)
		if selected is String:
			checkpoint = selected
	if checkpoint.is_empty():
		ai_status.text = "Click Connect & load models, then choose your installed SDXL checkpoint."
		ai_dialog.popup_centered(Vector2i(760, 690))
		return {"ok": false, "error": ai_status.text}
	if ai_prompt.text.strip_edges().is_empty() or ai_prompt.text.length() > 4000:
		ai_status.text = "Enter a prompt between 1 and 4,000 characters."
		return {"ok": false, "error": ai_status.text}
	preview._finish_drag()
	if not component.is_empty():
		ai_dialog.popup_centered(Vector2i(780, 760))
	_save_ai_preferences()
	_set_ai_busy(true)
	_ai_progress_changed("Preparing " + ("the complete kit" if component.is_empty() else component) + "…", 0, 19)
	var steps = 12 if ai_quality_picker.selected == 0 else 20
	var result: Dictionary = await ai_pipeline.generate(current_config.duplicate(true), ai_endpoint.text.strip_edges(), checkpoint, ai_prompt.text.strip_edges(), component, steps)
	if result.get("ok", false):
		var previous: Dictionary = current_config.get("ai", {}).duplicate(true)
		layout_history.create_action("Generate AI kit" if component.is_empty() else "Generate AI " + component)
		layout_history.add_do_method(_apply_ai_result.bind(result.ai.duplicate(true)))
		layout_history.add_undo_method(_apply_ai_result.bind(previous))
		layout_history.commit_action()
		ai_status.text = "AI artwork applied. Review the edges and readability in the preview. You can regenerate one piece or undo this generation with Ctrl+Z."
	else:
		ai_status.text = str(result.get("error", "AI generation did not complete.")).left(600) + " Your previous artwork is kept."
		status_label.text = ai_status.text
	_set_ai_busy(false)
	return result

func _apply_ai_result(artwork: Dictionary) -> void:
	if artwork.is_empty():
		current_config.erase("ai")
	else:
		current_config.ai = artwork.duplicate(true)
	_sync_ai_controls()
	_refresh_previews()
	status_label.text = "AI artwork applied · export includes the accepted PNGs. Ctrl+Z to undo." if current_config.get("ai", {}).get("enabled", false) else "Procedural artwork restored. Positions and sizes are kept."

func _generate_selected_ai() -> Dictionary:
	var node = preview.hud.get_node_or_null(NodePath(preview.selected_element)) if not preview.selected_element.is_empty() else null
	if node == null or current_config.get("mode", "hud") != "kit":
		ai_status.text = "Close AI studio, select a piece in the large preview, then reopen the studio."
		return {"ok": false, "error": ai_status.text}
	return await _generate_ai_art(str(node.get_meta("kit_component", node.name)))

func _restore_procedural_art() -> void:
	if ai_busy or not current_config.get("ai", {}).get("enabled", false):
		return
	var previous: Dictionary = current_config.ai.duplicate(true)
	layout_history.create_action("Restore procedural art")
	layout_history.add_do_method(_apply_ai_result.bind({}))
	layout_history.add_undo_method(_apply_ai_result.bind(previous))
	layout_history.commit_action()

func _set_ai_busy(busy: bool) -> void:
	ai_busy = busy
	ai_connect_button.disabled = busy
	ai_generate_button.disabled = busy
	ai_cancel_button.disabled = not busy
	ai_endpoint.editable = not busy
	ai_prompt.editable = not busy
	ai_model_picker.disabled = busy or ai_model_picker.item_count == 0 or not ai_model_picker.get_item_metadata(0) is String
	ai_quality_picker.disabled = busy
	generate_button.disabled = busy
	creation_picker.disabled = busy
	new_ui_button.disabled = busy
	_sync_ai_controls()

func _sync_ai_controls() -> void:
	var active = current_config.get("ai", {}).get("enabled", false)
	accent_picker.disabled = active
	ai_restore_button.disabled = ai_busy or not active
	ai_hint.text = "AI artwork keeps its generated colors. Edit the prompt in AI studio to change them. Export includes the PNGs; your game does not need ComfyUI." if active else "Create new artwork from a prompt using ComfyUI on this PC. No API key or per-image fee."
	if is_instance_valid(preview.hud):
		_selection_changed(preview.selected_element)

func _ai_progress_changed(message: String, completed: int, total: int) -> void:
	ai_status.text = message.left(600)
	ai_progress.max_value = maxi(1, total)
	ai_progress.value = completed
	status_label.text = message

func _cancel_ai() -> void:
	if ai_busy:
		ai_pipeline.cancel()
		ai_status.text = "Cancelling this UI Forge job. The current ComfyUI image may still finish."

func _save_ai_preferences() -> void:
	var preferences = ConfigFile.new()
	preferences.set_value("studio", "endpoint", ai_endpoint.text)
	preferences.set_value("studio", "prompt", ai_prompt.text)
	preferences.set_value("studio", "quality", ai_quality_picker.selected)
	if ai_model_picker.selected >= 0 and ai_model_picker.get_item_metadata(ai_model_picker.selected) is String:
		ai_preferred_checkpoint = ai_model_picker.get_item_metadata(ai_model_picker.selected)
	preferences.set_value("studio", "checkpoint", ai_preferred_checkpoint)
	preferences.save("user://local_ai.cfg")

func _header(parent: Node) -> void:
	var row = HBoxContainer.new()
	row.custom_minimum_size.y = 48
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	var icon = TextureRect.new()
	icon.texture = preload("res://assets/icon.svg")
	icon.custom_minimum_size = Vector2(42, 42)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	row.add_child(_label("UI FORGE", 23, INK))
	row.add_child(_label("/   UI STUDIO", 11, MUTED))
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(_label("LOCAL GENERATION   ·   GODOT 4", 11, MUTED))
	var fresh = _button("+  New UI")
	new_ui_button = fresh
	fresh.pressed.connect(_new_ui)
	row.add_child(fresh)
	export_button = _button("Export to Godot  ↗", true)
	export_button.custom_minimum_size.x = 170
	export_button.pressed.connect(_open_export)
	row.add_child(export_button)

func _sidebar(parent: Node) -> void:
	var outer = _panel(parent, 268)
	var body = outer
	body.add_child(_label("DESIGN BRIEF", 11, GREEN))
	creation_picker = OptionButton.new()
	creation_picker.custom_minimum_size.y = 40
	creation_picker.add_item("HUD layouts")
	creation_picker.add_item("Fantasy UI kit")
	creation_picker.item_selected.connect(_set_creation_mode)
	body.add_child(creation_picker)
	hud_brief = VBoxContainer.new()
	hud_brief.add_theme_constant_override("separation", 10)
	hud_brief.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(hud_brief)
	body = hud_brief
	_space(body, 7)
	body.add_child(_label("01   GAME TYPE", 11, MUTED))
	genre_picker = OptionButton.new()
	genre_picker.custom_minimum_size.y = 40
	for genre in Generator.GENRES:
		genre_picker.add_item(genre)
	genre_picker.item_selected.connect(func(_index):
		_apply_genre_defaults()
		_mark_dirty())
	body.add_child(genre_picker)
	_space(body, 5)
	body.add_child(_label("02   VISUAL STYLE", 11, MUTED))
	var styles_grid = GridContainer.new()
	styles_grid.columns = 2
	styles_grid.add_theme_constant_override("h_separation", 7)
	styles_grid.add_theme_constant_override("v_separation", 7)
	body.add_child(styles_grid)
	for style_name in Generator.STYLES:
		var button = _button("●  " + style_name)
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_color_override("font_color", Color(Generator.PALETTES[style_name].accent))
		button.add_theme_color_override("font_pressed_color", Color(Generator.PALETTES[style_name].accent))
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(_select_style.bind(style_name))
		styles_grid.add_child(button)
		style_buttons[style_name] = button
	_select_style("Military")
	_space(body, 5)
	var component_header = HBoxContainer.new()
	body.add_child(component_header)
	var caption = _label("03   COMPONENTS", 11, MUTED)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	component_header.add_child(caption)
	component_count = _label("", 11, GREEN)
	component_header.add_child(component_count)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 145
	body.add_child(scroll)
	var components = VBoxContainer.new()
	components.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	components.add_theme_constant_override("separation", 0)
	scroll.add_child(components)
	for key in Generator.COMPONENTS:
		var check = CheckBox.new()
		check.text = Generator.COMPONENTS[key]
		check.custom_minimum_size.y = 30
		check.add_theme_font_size_override("font_size", 13)
		check.toggled.connect(func(_pressed):
			_update_count()
			_mark_dirty())
		component_checks[key] = check
		components.add_child(check)
	kit_brief_scroll = ScrollContainer.new()
	kit_brief_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	kit_brief_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	kit_brief_scroll.hide()
	outer.add_child(kit_brief_scroll)
	kit_brief = VBoxContainer.new()
	kit_brief.add_theme_constant_override("separation", 10)
	kit_brief.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kit_brief.hide()
	kit_brief_scroll.add_child(kit_brief)
	kit_brief.add_child(_label("A whole world of UI.", 21, INK))
	kit_brief.add_child(_wrapped("Generate a matching menu, gameplay HUD, and library of reusable controls.", 12, MUTED))
	kit_brief.add_child(_label("01   ART STYLE", 11, MUTED))
	kit_style_picker = OptionButton.new()
	for style in Kit.STYLES:
		kit_style_picker.add_item(style)
	kit_style_picker.item_selected.connect(func(_index): _mark_dirty())
	kit_brief.add_child(kit_style_picker)
	kit_brief.add_child(_label("02   DESIGN LANGUAGE", 11, MUTED))
	kit_design_picker = OptionButton.new()
	for design in KitDesign.FAMILIES:
		kit_design_picker.add_item(design)
	kit_design_picker.item_selected.connect(func(_index): _mark_dirty())
	kit_brief.add_child(kit_design_picker)
	kit_brief.add_child(_label("03   MATERIAL", 11, MUTED))
	kit_material_picker = OptionButton.new()
	for material in Kit.MATERIALS:
		kit_material_picker.add_item(material)
	kit_material_picker.item_selected.connect(func(_index): _mark_dirty())
	kit_brief.add_child(kit_material_picker)
	kit_brief.add_child(_label("04   DECORATION", 11, MUTED))
	kit_ornament_picker = OptionButton.new()
	for amount in Kit.ORNAMENTS:
		kit_ornament_picker.add_item(amount)
	kit_ornament_picker.select(2)
	kit_ornament_picker.item_selected.connect(func(_index): _mark_dirty())
	kit_brief.add_child(kit_ornament_picker)
	kit_brief.add_child(_label("DESIGN SEED", 11, MUTED))
	kit_seed = SpinBox.new()
	kit_seed.min_value = 0
	kit_seed.max_value = 2147483646
	kit_seed.step = 1
	kit_seed.update_on_text_changed = true
	kit_seed.value = randi_range(0, 2147483646)
	kit_seed.tooltip_text = "The same brief and seed reproduce the generated shapes, artwork, and composition."
	kit_seed.value_changed.connect(func(_value):
		if not updating_controls:
			kit_seed_lock.button_pressed = true
			_mark_dirty())
	kit_brief.add_child(kit_seed)
	kit_seed_lock = CheckBox.new()
	kit_seed_lock.text = "Keep seed"
	kit_seed_lock.add_theme_font_size_override("font_size", 12)
	kit_seed_lock.toggled.connect(func(_pressed): _mark_dirty())
	kit_brief.add_child(kit_seed_lock)
	kit_brief.add_child(_wrapped("Generate explores new shapes and compositions. Keep the seed to repeat a design.", 11, MUTED))
	kit_brief.add_child(_wrapped("Layered frames · carved ornaments\nHealth & mana bars · inventory · icons\nDrawn offline on your PC.", 11, MUTED))
	body = outer
	body.add_child(_label("TARGET RESOLUTION", 11, MUTED))
	resolution_picker = OptionButton.new()
	for resolution in ["1920 × 1080  /  Full HD", "2560 × 1440  /  QHD", "1280 × 720  /  HD"]:
		resolution_picker.add_item(resolution)
	resolution_picker.item_selected.connect(func(_index): _mark_dirty())
	body.add_child(resolution_picker)
	generate_button = _button("Generate 3 variations   →", true)
	generate_button.custom_minimum_size.y = 45
	generate_button.pressed.connect(generate)
	body.add_child(generate_button)
	body.add_child(_label("Generated locally · no account or API key", 11, MUTED))

func _center(parent: Node) -> void:
	var center = VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 10)
	parent.add_child(center)
	center.add_child(_label("YOUR INTERFACE, REIMAGINED", 10, GREEN))
	center.add_child(_label("A new look for your next world.", 26, INK))
	center.add_child(_label("Explore a direction. Refine the details. Make it playable.", 13, MUTED))
	_space(center, 3)
	var toolbar = HBoxContainer.new()
	center.add_child(toolbar)
	title_label = _label("", 16, INK)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(title_label)
	detail_label = _label("", 11, MUTED)
	toolbar.add_child(detail_label)
	var frame = PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.custom_minimum_size.y = 280
	frame.add_theme_stylebox_override("panel", Generator.panel_style(Color("090f13"), BORDER, 1))
	center.add_child(frame)
	preview = Preview.new()
	preview.editable = true
	preview.element_selected.connect(_selection_changed)
	preview.element_moving.connect(_position_changed)
	preview.element_moved.connect(_commit_move)
	preview.element_resized.connect(_commit_resize)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(preview)
	var preview_caption = HBoxContainer.new()
	center.add_child(preview_caption)
	var caption = _label("DRAG TO ARRANGE", 10, GREEN)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_caption.add_child(caption)
	preview_caption.add_child(_label("Illustrative environment · excluded from export", 10, MUTED))
	_space(center, 4)
	var variant_header = HBoxContainer.new()
	center.add_child(variant_header)
	var label = _label("CHOOSE YOUR DIRECTION", 11, MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	variant_header.add_child(label)
	dirty_label = _label("3 coordinated variations", 11, MUTED)
	variant_header.add_child(dirty_label)
	var variations = HBoxContainer.new()
	variations.add_theme_constant_override("separation", 10)
	center.add_child(variations)
	for i in range(3):
		var card = VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_stretch_ratio = 1
		variations.add_child(card)
		var image_frame = PanelContainer.new()
		image_frame.custom_minimum_size.y = 112
		card.add_child(image_frame)
		var small_preview = Preview.new()
		image_frame.add_child(small_preview)
		variant_previews.append(small_preview)
		var hit = Button.new()
		hit.flat = true
		hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hit.tooltip_text = "Preview " + Generator.LAYOUTS[i] + " layout"
		hit.pressed.connect(select_variant.bind(i))
		image_frame.add_child(hit)
		var button = _button("")
		button.toggle_mode = true
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(select_variant.bind(i))
		card.add_child(button)
		variant_buttons.append(button)
		var caption_label = _label(Generator.LAYOUTS[i], 11, MUTED)
		card.add_child(caption_label)
		variant_labels.append(caption_label)
	center.add_child(_label("Native controls. Shared theme. Ready for your game logic.", 12, MUTED))

func _inspector(parent: Node) -> void:
	var body = _panel(parent, 246, true)
	body.add_theme_constant_override("separation", 7)
	body.add_child(_label("THE FINISHING TOUCHES", 11, GREEN))
	body.add_child(_label("Make it yours.", 21, INK))
	body.add_child(_wrapped("Color and artwork apply to all variations.", 12, MUTED))
	_space(body, 9)
	selected_label = _label("", 16, INK)
	body.add_child(selected_label)
	body.add_child(_label("ARRANGE ELEMENTS", 11, GREEN))
	position_label = _label("Click an element in the preview", 11, MUTED)
	body.add_child(position_label)
	body.add_child(_wrapped("Drag to move · corners to resize\nArrows: nudge · Ctrl+Z: undo\nEsc: cancel an active drag", 11, MUTED))
	var snap = CheckBox.new()
	snap.text = "Snap to 8 px grid"
	snap.add_theme_font_size_override("font_size", 12)
	snap.toggled.connect(func(enabled): preview.snap_to_grid = enabled)
	body.add_child(snap)
	var reset = _button("Reset this layout")
	reset.pressed.connect(_reset_layout)
	body.add_child(reset)
	kit_controls = VBoxContainer.new()
	kit_controls.add_theme_constant_override("separation", 7)
	kit_controls.hide()
	body.add_child(kit_controls)
	kit_controls.add_child(_label("REFINE ONE PIECE", 11, GREEN))
	regenerate_button = _button("Regenerate selected")
	regenerate_button.add_theme_font_size_override("font_size", 12)
	regenerate_button.disabled = true
	regenerate_button.pressed.connect(_regenerate_selected)
	kit_controls.add_child(regenerate_button)
	kit_controls.add_child(_wrapped("Select a piece to explore a new silhouette, frame, and ornaments. Your arrangement and other pieces stay in place. Ctrl+Z undoes it.", 11, MUTED))
	kit_controls.add_child(_wrapped("Menu · HUD · Components\nExport saves all three pages and their shared artwork.", 11, MUTED))
	kit_controls.add_child(HSeparator.new())
	kit_controls.add_child(_label("LOCAL AI ART", 11, GREEN))
	var open_ai = _button("Open AI studio")
	open_ai.pressed.connect(func(): ai_dialog.popup_centered(Vector2i(780, 760)))
	kit_controls.add_child(open_ai)
	ai_hint = _wrapped("Create new artwork from a prompt using ComfyUI on this PC. No API key or per-image fee.", 11, MUTED)
	kit_controls.add_child(ai_hint)
	ai_restore_button = _button("Use procedural art")
	ai_restore_button.add_theme_font_size_override("font_size", 12)
	ai_restore_button.disabled = true
	ai_restore_button.pressed.connect(_restore_procedural_art)
	kit_controls.add_child(ai_restore_button)
	body.add_child(HSeparator.new())
	var inspector_body = body
	art_controls = VBoxContainer.new()
	art_controls.add_theme_constant_override("separation", 7)
	body.add_child(art_controls)
	body = art_controls
	body.add_child(_label("OFFLINE MATERIAL ART", 11, GREEN))
	body.add_child(_wrapped("Layer textured surfaces and frames behind editable text and bars.", 11, MUTED))
	body.add_child(_label("Material", 11, MUTED))
	art_material = OptionButton.new()
	for material in Art.MATERIALS:
		art_material.add_item(material)
	body.add_child(art_material)
	art_material.item_selected.connect(func(_index): _queue_art_update())
	body.add_child(_label("Frame detail", 11, MUTED))
	art_detail = OptionButton.new()
	for detail in Art.DETAILS:
		art_detail.add_item(detail)
	body.add_child(art_detail)
	art_detail.item_selected.connect(func(_index): _queue_art_update())
	var art_buttons = HBoxContainer.new()
	art_buttons.add_theme_constant_override("separation", 6)
	body.add_child(art_buttons)
	var make_art = _button("Generate art")
	make_art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	make_art.pressed.connect(_generate_art)
	art_buttons.add_child(make_art)
	var clear_art = _button("Clear")
	clear_art.pressed.connect(_clear_art)
	art_buttons.add_child(clear_art)
	art_scale = _art_slider(body, "Texture size", 50, 200, 100)
	art_scale.step = 5
	art_wear = _art_slider(body, "Wear", 0, 100, 30)
	art_strength = _art_slider(body, "Art opacity", 10, 100, 85)
	body.add_child(_label("Seed · reuse to reproduce a surface", 11, MUTED))
	var seed_row = HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 6)
	body.add_child(seed_row)
	art_seed = SpinBox.new()
	art_seed.min_value = 0
	art_seed.max_value = 2147483647
	art_seed.step = 1
	art_seed.value = randi_range(0, 2147483647)
	art_seed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art_seed.value_changed.connect(func(_value): _queue_art_update())
	seed_row.add_child(art_seed)
	var reroll = _button("New")
	reroll.tooltip_text = "Choose a new seed and generate a fresh surface"
	reroll.pressed.connect(func():
		art_seed.set_value_no_signal(randi_range(0, 2147483647))
		_generate_art())
	seed_row.add_child(reroll)
	body.add_child(_wrapped("New rolls a fresh seed. Material controls update existing artwork automatically.", 11, MUTED))
	art_update_timer = Timer.new()
	art_update_timer.one_shot = true
	art_update_timer.wait_time = .18
	art_update_timer.timeout.connect(_apply_art_settings)
	add_child(art_update_timer)
	body = inspector_body
	_space(body, 9)
	body.add_child(_label("ACCENT COLOR", 11, MUTED))
	accent_picker = ColorPickerButton.new()
	accent_picker.custom_minimum_size = Vector2(0, 40)
	accent_picker.edit_alpha = false
	accent_picker.color_changed.connect(func(color):
		if updating_controls or current_config.is_empty():
			return
		current_config.accent = color.to_html(false)
		_refresh_previews())
	body.add_child(accent_picker)
	_space(body, 9)
	var scale_header = HBoxContainer.new()
	body.add_child(scale_header)
	var scale_label = _label("HUD SIZE", 11, MUTED)
	scale_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_header.add_child(scale_label)
	scale_value = _label("100%", 12, INK)
	scale_header.add_child(scale_value)
	size_slider = _slider(body, 85, 110, 100)
	size_slider.value_changed.connect(func(value):
		scale_value.text = "%d%%" % value
		if not updating_controls and not current_config.is_empty():
			current_config.scale = value / 100.0
			_refresh_previews())
	_space(body, 12)
	body.add_child(HSeparator.new())
	_space(body, 5)
	body.add_child(_label("TEST YOUR HUD", 11, GREEN))
	body.add_child(_wrapped("Move the values to see your bars respond. These values also carry into the export.", 12, MUTED))
	_space(body, 8)
	health_value = _label("Health  /  78", 13, INK)
	body.add_child(health_value)
	health_slider = _slider(body, 0, 100, 78)
	health_slider.value_changed.connect(func(value): _change_value("health", value))
	mana_value = _label("Mana  /  62", 13, INK)
	body.add_child(mana_value)
	mana_slider = _slider(body, 0, 100, 62)
	mana_slider.value_changed.connect(func(value): _change_value("mana", value))
	var stretch = Control.new()
	stretch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(stretch)
	body.add_child(HSeparator.new())
	body.add_child(_label("BUILT FOR GODOT", 11, GREEN))
	body.add_child(_wrapped("Export a .tscn scene and a shared .tres theme. Edit every element and connect it to your game.", 12, MUTED))
	body.add_child(_wrapped("Map, ammo, and timers use sample data. Your game supplies the behavior.", 11, MUTED))

func generate() -> void:
	if ai_busy:
		status_label.text = "AI artwork is still generating. Cancel it in AI studio before creating a new design."
		return
	if creation_picker.selected == 1:
		_generate_kit()
		return
	var selected: Array = []
	for key in component_checks:
		if component_checks[key].button_pressed:
			selected.append(key)
	if selected.is_empty():
		status_label.text = "Choose at least one component before generating."
		return
	art_update_timer.stop()
	var genre = Generator.GENRES[genre_picker.selected]
	current_config = Generator.make_config(genre, selected_style)
	current_config.components = selected
	current_config.resolution = [Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(1280, 720)][resolution_picker.selected]
	layout_history.clear_history()
	preview.selected_element = ""
	updating_controls = true
	accent_picker.color = Color(current_config.accent)
	size_slider.value = 100
	health_slider.value = current_config.health
	mana_slider.value = current_config.mana
	updating_controls = false
	art_controls.show()
	kit_controls.hide()
	_sync_ai_controls()
	select_variant(0)
	_refresh_previews()
	health_slider.editable = "health" in selected
	mana_slider.editable = "mana" in selected
	health_value.modulate.a = 1.0 if health_slider.editable else 0.35
	mana_value.modulate.a = 1.0 if mana_slider.editable else 0.35
	dirty_label.text = "3 coordinated variations"
	dirty_label.modulate = Color.WHITE
	status_label.text = "%s / %s · %d components · 3 variations generated locally." % [genre, selected_style, selected.size()]

func _set_creation_mode(index: int) -> void:
	creation_picker.select(index)
	hud_brief.visible = index == 0
	kit_brief.visible = index == 1
	kit_brief_scroll.visible = index == 1
	generate_button.text = "Generate complete kit   →" if index == 1 else "Generate 3 variations   →"
	_mark_dirty()

func _generate_kit() -> void:
	art_update_timer.stop()
	kit_seed.apply()
	var previous_layout: int = int(KitDesign.recipe(current_config).layout) if current_config.get("mode", "hud") == "kit" else -1
	current_config = Kit.make_config(Kit.STYLES[kit_style_picker.selected])
	current_config.kit.design = KitDesign.FAMILIES[kit_design_picker.selected]
	var next_seed: int = int(kit_seed.value)
	if not kit_seed_lock.button_pressed:
		next_seed = randi_range(0, 2147483646)
		while next_seed == int(kit_seed.value) or posmod(next_seed, KitDesign.COMPOSITIONS.size()) == previous_layout:
			next_seed = randi_range(0, 2147483646)
	kit_seed.set_value_no_signal(next_seed)
	current_config.kit.seed = next_seed
	current_config.kit.material = Kit.MATERIALS[kit_material_picker.selected]
	current_config.kit.ornaments = Kit.ORNAMENTS[kit_ornament_picker.selected]
	current_config.accent = KitDesign.suggested_accent(current_config)
	current_config.resolution = [Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(1280, 720)][resolution_picker.selected]
	layout_history.clear_history()
	preview.selected_element = ""
	updating_controls = true
	accent_picker.color = Color(current_config.accent)
	size_slider.value = 100
	health_slider.value = current_config.health
	mana_slider.value = current_config.mana
	health_slider.editable = true
	mana_slider.editable = true
	health_value.modulate.a = 1.0
	mana_value.modulate.a = 1.0
	updating_controls = false
	art_controls.hide()
	kit_controls.show()
	_sync_ai_controls()
	select_variant(0)
	_refresh_previews()
	dirty_label.text = "%s · seed %d" % [KitDesign.recipe(current_config).family, next_seed]
	dirty_label.modulate = Color.WHITE
	status_label.text = "%s · %s · seed %d · Export saves all three kit pages." % [current_config.style, KitDesign.description(current_config), next_seed]

func _regenerate_selected() -> void:
	if ai_busy or current_config.get("mode", "hud") != "kit":
		return
	preview._finish_drag()
	var node = preview.hud.get_node_or_null(NodePath(preview.selected_element)) if not preview.selected_element.is_empty() else null
	if node == null:
		status_label.text = "Select a kit component in the large preview first."
		return
	var component = str(node.get_meta("kit_component", node.name))
	if current_config.get("ai", {}).get("enabled", false):
		_generate_ai_art(component)
		return
	var overrides: Dictionary = current_config.kit.component_seeds
	var had_override = overrides.has(component)
	var previous = int(overrides.get(component, 0))
	var next = randi_range(1, 2147483647)
	var old_silhouette: int = int(KitDesign.recipe(current_config, component).silhouette_index)
	var candidate: Dictionary = current_config.duplicate(true)
	candidate.kit.component_seeds[component] = next
	while next == previous or int(KitDesign.recipe(candidate, component).silhouette_index) == old_silhouette:
		next = (next % 2147483646) + 1
		candidate.kit.component_seeds[component] = next
	layout_history.create_action("Regenerate " + component)
	layout_history.add_do_method(_apply_component_seed.bind(component, next, true))
	layout_history.add_undo_method(_apply_component_seed.bind(component, previous, had_override))
	layout_history.commit_action()

func _apply_component_seed(component: String, seed_value: int, enabled: bool) -> void:
	if enabled:
		current_config.kit.component_seeds[component] = seed_value
	else:
		current_config.kit.component_seeds.erase(component)
	_refresh_previews()
	status_label.text = "%s artwork updated · arrangement is kept. Ctrl+Z to undo." % component

func select_variant(index: int) -> void:
	selected_variant = index
	if current_config.is_empty():
		return
	var is_kit = current_config.get("mode", "hud") == "kit"
	var names: Array = Kit.PAGES if is_kit else Generator.PALETTES[current_config.style].names
	for i in range(3):
		variant_buttons[i].set_pressed_no_signal(i == index)
		variant_buttons[i].text = "%02d  %s%s" % [i + 1, names[i], "  ✓" if i == index else ""]
		variant_labels[i].modulate = GREEN if i == index else Color.WHITE
		variant_labels[i].text = ["Menu & panels", "Gameplay elements", "Reusable controls"][i] if is_kit else Generator.LAYOUTS[i]
	title_label.text = "%02d  /  %s" % [index + 1, names[index]]
	selected_label.text = names[index] if is_kit else names[index] + " / " + Generator.LAYOUTS[index]
	detail_label.text = current_config.style.to_upper() if is_kit else "%s · %s" % [current_config.genre.to_upper(), current_config.style.to_upper()]
	preview.show_design(current_config, selected_variant)
	_selection_changed(preview.selected_element)

func _refresh_previews() -> void:
	preview.show_design(current_config, selected_variant)
	for i in range(3):
		variant_previews[i].show_design(current_config, i)
	_selection_changed(preview.selected_element)

func _selection_changed(element: String) -> void:
	if not is_instance_valid(position_label):
		return
	var node = preview.hud.get_node_or_null(NodePath(element)) if not element.is_empty() else null
	regenerate_button.disabled = ai_busy or node == null or current_config.get("mode", "hud") != "kit"
	if is_instance_valid(ai_selected_button):
		ai_selected_button.disabled = regenerate_button.disabled
		ai_selected_button.tooltip_text = "Generate AI artwork only for " + element if node != null else "Close the studio and select a piece in the large preview first."
	if node != null:
		_position_changed(element, node.position)
	else:
		position_label.text = "Click an element in the preview"

func _position_changed(element: String, at: Vector2) -> void:
	var node = preview.hud.get_node_or_null(NodePath(element))
	var factor = node.scale.x / float(node.get_meta("preset_scale", 1.0)) if node != null else 1.0
	position_label.text = "%s  /  %d%%\nX %d  Y %d" % [element, roundi(factor * 100), at.x, at.y]

func _commit_move(element: String, previous: Vector2, current: Vector2) -> void:
	if previous.is_equal_approx(current):
		return
	layout_history.create_action("Move " + element)
	layout_history.add_do_method(_apply_position.bind(selected_variant, element, current))
	layout_history.add_undo_method(_apply_position.bind(selected_variant, element, previous))
	layout_history.commit_action()

func _apply_position(variant: int, element: String, at: Vector2) -> void:
	var key = str(variant)
	if not current_config.positions.has(key):
		current_config.positions[key] = {}
	current_config.positions[key][element] = at
	preview.selected_element = element
	select_variant(variant)
	_refresh_previews()
	status_label.text = "%s moved · export keeps this position. Ctrl+Z to undo." % element

func _commit_resize(element: String, previous_position: Vector2, previous_scale: float, current_position: Vector2, current_scale: float) -> void:
	layout_history.create_action("Resize " + element)
	layout_history.add_do_method(_apply_transform.bind(selected_variant, element, current_position, current_scale))
	layout_history.add_undo_method(_apply_transform.bind(selected_variant, element, previous_position, previous_scale))
	layout_history.commit_action()

func _apply_transform(variant: int, element: String, at: Vector2, factor: float) -> void:
	var key = str(variant)
	if not current_config.element_scales.has(key):
		current_config.element_scales[key] = {}
	current_config.element_scales[key][element] = factor
	_apply_position(variant, element, at)
	status_label.text = "%s resized · export keeps its size and position. Ctrl+Z to undo." % element

func _reset_layout() -> void:
	var key = str(selected_variant)
	var previous: Dictionary = current_config.positions.get(key, {}).duplicate(true)
	var previous_scales: Dictionary = current_config.element_scales.get(key, {}).duplicate(true)
	if previous.is_empty() and previous_scales.is_empty():
		return
	layout_history.create_action("Reset layout")
	layout_history.add_do_method(_restore_layout.bind(selected_variant, {}, {}))
	layout_history.add_undo_method(_restore_layout.bind(selected_variant, previous, previous_scales))
	layout_history.commit_action()

func _restore_layout(variant: int, positions: Dictionary, scales: Dictionary) -> void:
	current_config.positions[str(variant)] = positions.duplicate(true)
	current_config.element_scales[str(variant)] = scales.duplicate(true)
	select_variant(variant)
	_refresh_previews()
	status_label.text = "Layout updated. Ctrl+Z to undo."

func _generate_art() -> void:
	if not preview.hud.get_children().any(func(node): return node is Panel):
		status_label.text = "Frame art needs a panel component, such as Health or Weapon. The crosshair uses native shapes."
		return
	art_update_timer.stop()
	current_config.art = {"enabled": true}
	_apply_art_settings()

func _queue_art_update() -> void:
	if is_instance_valid(art_update_timer) and not current_config.is_empty() and current_config.art.get("enabled", false):
		art_update_timer.start()

func _apply_art_settings() -> void:
	if current_config.is_empty() or not current_config.art.get("enabled", false):
		return
	if preview.dragging or preview.resizing:
		art_update_timer.start()
		return
	current_config.art = {"enabled": true, "seed": int(art_seed.value), "material": Art.MATERIALS[art_material.selected], "detail": Art.DETAILS[art_detail.selected], "texture_scale": art_scale.value / 100.0, "wear": art_wear.value / 100.0, "strength": art_strength.value / 100.0}
	_refresh_previews()
	status_label.text = "%s · seed %d · generated offline. Export includes material PNGs." % [Art.material_for(current_config), current_config.art.seed]

func _flush_art_update() -> void:
	if not art_update_timer.is_stopped():
		art_update_timer.stop()
		_apply_art_settings()

func _clear_art() -> void:
	art_update_timer.stop()
	current_config.art = {"enabled": false}
	_refresh_previews()
	status_label.text = "Material art cleared. Custom positions and scales are kept."

func _apply_genre_defaults() -> void:
	var defaults: Array = Generator.DEFAULTS[Generator.GENRES[genre_picker.selected]]
	for key in component_checks:
		component_checks[key].set_pressed_no_signal(key in defaults)
	_update_count()

func _select_style(style_name: String) -> void:
	selected_style = style_name
	for key in style_buttons:
		style_buttons[key].set_pressed_no_signal(key == style_name)
	_mark_dirty()

func _update_count() -> void:
	var count = 0
	for check in component_checks.values():
		if check.button_pressed:
			count += 1
	if is_instance_valid(component_count):
		component_count.text = "%02d" % count

func _mark_dirty() -> void:
	if is_instance_valid(dirty_label):
		dirty_label.text = "Changes pending · click Generate"
		dirty_label.modulate = Color("edc483")
	if is_instance_valid(status_label):
		status_label.text = "Design brief changed. Generate to apply; export uses the visible preview."

func _change_value(key: String, value: float) -> void:
	if key == "health":
		health_value.text = "Health  /  %d" % value
	else:
		mana_value.text = "Mana  /  %d" % value
	if updating_controls or current_config.is_empty():
		return
	current_config[key] = value
	# Gameplay-value changes update the actual controls without rebuilding scenes.
	var previews = [preview] + variant_previews
	for view in previews:
		var bar = view.hud.get_node_or_null(key.capitalize() + "/Value")
		if bar != null:
			bar.value = value
			view.hud.get_node(key.capitalize() + "/Amount").text = "%d / 100" % value

func _new_ui() -> void:
	if ai_busy:
		status_label.text = "Cancel the current AI job before starting a new UI."
		return
	_set_creation_mode(0)
	genre_picker.select(0)
	resolution_picker.select(0)
	_select_style("Military")
	_apply_genre_defaults()
	generate()

func _open_export() -> void:
	if current_config.is_empty():
		return
	preview._finish_drag()
	_flush_art_update()
	export_dialog.title = "Choose a folder for your fantasy UI kit" if current_config.get("mode", "hud") == "kit" else "Choose a folder for your Godot HUD"
	export_dialog.popup_centered_ratio(0.75)

func _export_to(directory: String) -> void:
	_flush_art_update()
	var result = Exporter.export_hud(current_config, selected_variant, directory)
	if result.ok:
		status_label.text = "Exported to " + result.path
		export_result.title = "Your kit is ready" if current_config.get("mode", "hud") == "kit" else "Your HUD is ready"
		var contents = "Saved your complete kit: menu.tscn, hud.tscn, components.tscn, shared theme, artwork, and guide." if current_config.get("mode", "hud") == "kit" else "Saved your editable scene, theme, preset, and integration guide."
		export_result.dialog_text = contents + "\n\n" + result.path + "\n\nCopy the whole folder into your Godot project."
	else:
		status_label.text = result.error
		export_result.title = "Export needs attention"
		export_result.dialog_text = result.error
	export_result.popup_centered()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.is_command_or_control_pressed():
		if event.keycode == KEY_G:
			generate()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E:
			_open_export()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Z:
			if event.shift_pressed:
				layout_history.redo()
			else:
				layout_history.undo()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Y:
			layout_history.redo()
			get_viewport().set_input_as_handled()

func _panel(parent: Node, width: float, scrollable: bool = false) -> VBoxContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size.x = width
	parent.add_child(panel)
	var margin = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	if scrollable:
		var scroll = ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		margin.add_child(scroll)
		scroll.add_child(body)
	else:
		margin.add_child(body)
	return body

func _label(text: String, font_size: int, color: Color) -> Label:
	var result = Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result

func _wrapped(text: String, font_size: int, color: Color) -> Label:
	var result = _label(text, font_size, color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.custom_minimum_size.x = 170
	return result

func _button(text: String, primary: bool = false) -> Button:
	var result = Button.new()
	result.text = text
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if primary:
		for state in ["normal", "hover", "pressed", "focus"]:
			var bg = GREEN.lightened(0.08) if state == "hover" else GREEN
			var box = Generator.panel_style(bg, GREEN, 7)
			box.content_margin_left = 16
			box.content_margin_right = 16
			box.content_margin_top = 9
			box.content_margin_bottom = 9
			result.add_theme_stylebox_override(state, box)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			result.add_theme_color_override(state, Color("182019"))
	return result

func _slider(parent: Node, minimum: float, maximum: float, value: float) -> HSlider:
	var slider = HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.value = value
	slider.custom_minimum_size.y = 25
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(slider)
	return slider

func _art_slider(parent: Node, caption: String, minimum: float, maximum: float, value: float) -> HSlider:
	var label = _label("%s  /  %d%%" % [caption, value], 11, MUTED)
	parent.add_child(label)
	var slider = _slider(parent, minimum, maximum, value)
	slider.value_changed.connect(func(amount):
		label.text = "%s  /  %d%%" % [caption, amount]
		_queue_art_update())
	return slider

func _space(parent: Node, height: float) -> void:
	var space = Control.new()
	space.custom_minimum_size.y = height
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(space)
