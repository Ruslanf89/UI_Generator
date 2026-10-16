extends Control

const Generator = preload("res://scripts/hud_generator.gd")
const Exporter = preload("res://scripts/hud_exporter.gd")
const Preview = preload("res://scripts/hud_preview.gd")
const Art = preload("res://scripts/hud_art.gd")
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

func _ready() -> void:
	DisplayServer.window_set_min_size(Vector2i(1120, 900))
	_build_theme()
	_build_ui()
	_apply_genre_defaults()
	generate()

func _exit_tree() -> void:
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
	row.add_child(_label("/   HUD STUDIO", 11, MUTED))
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(_label("LOCAL GENERATION   ·   GODOT 4", 11, MUTED))
	var fresh = _button("+  New UI")
	fresh.pressed.connect(_new_ui)
	row.add_child(fresh)
	export_button = _button("Export to Godot  ↗", true)
	export_button.custom_minimum_size.x = 170
	export_button.pressed.connect(_open_export)
	row.add_child(export_button)

func _sidebar(parent: Node) -> void:
	var body = _panel(parent, 268)
	body.add_child(_label("DESIGN BRIEF", 11, GREEN))
	body.add_child(_label("Make it your world.", 21, INK))
	body.add_child(_label("Choose a direction. We’ll build the HUD.", 12, MUTED))
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
	body.add_child(_label("TARGET RESOLUTION", 11, MUTED))
	resolution_picker = OptionButton.new()
	for resolution in ["1920 × 1080  /  Full HD", "2560 × 1440  /  QHD", "1280 × 720  /  HD"]:
		resolution_picker.add_item(resolution)
	resolution_picker.item_selected.connect(func(_index): _mark_dirty())
	body.add_child(resolution_picker)
	var generate_button = _button("Generate 3 variations   →", true)
	generate_button.custom_minimum_size.y = 45
	generate_button.pressed.connect(generate)
	body.add_child(generate_button)
	body.add_child(_label("Curated templates · no account or API key", 11, MUTED))

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
	body.add_child(HSeparator.new())
	body.add_child(_label("OFFLINE FRAME ART", 11, GREEN))
	body.add_child(_wrapped("Generate decorative frames locally. Your text and bars stay editable.", 11, MUTED))
	art_detail = OptionButton.new()
	for detail in Art.DETAILS:
		art_detail.add_item(detail)
	body.add_child(art_detail)
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
	var selected: Array = []
	for key in component_checks:
		if component_checks[key].button_pressed:
			selected.append(key)
	if selected.is_empty():
		status_label.text = "Choose at least one component before generating."
		return
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
	select_variant(0)
	_refresh_previews()
	health_slider.editable = "health" in selected
	mana_slider.editable = "mana" in selected
	health_value.modulate.a = 1.0 if health_slider.editable else 0.35
	mana_value.modulate.a = 1.0 if mana_slider.editable else 0.35
	dirty_label.text = "3 coordinated variations"
	dirty_label.modulate = Color.WHITE
	status_label.text = "%s / %s · %d components · 3 variations generated locally." % [genre, selected_style, selected.size()]

func select_variant(index: int) -> void:
	selected_variant = index
	if current_config.is_empty():
		return
	var names: Array = Generator.PALETTES[current_config.style].names
	for i in range(3):
		variant_buttons[i].set_pressed_no_signal(i == index)
		variant_buttons[i].text = "%02d  %s%s" % [i + 1, names[i], "  ✓" if i == index else ""]
		variant_labels[i].modulate = GREEN if i == index else Color.WHITE
	title_label.text = "%02d  /  %s" % [index + 1, names[index]]
	selected_label.text = names[index] + " / " + Generator.LAYOUTS[index]
	detail_label.text = "%s · %s" % [current_config.genre.to_upper(), current_config.style.to_upper()]
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
	current_config.art = {"enabled": true, "seed": randi_range(0, 2147483647), "detail": Art.DETAILS[art_detail.selected], "strength": 0.85}
	_refresh_previews()
	status_label.text = "Generated %s frame art locally. Generate again for a new seed; export includes PNG assets." % current_config.art.detail.to_lower()

func _clear_art() -> void:
	current_config.art = {"enabled": false}
	_refresh_previews()
	status_label.text = "Frame art cleared. Custom element positions are kept."

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
	genre_picker.select(0)
	resolution_picker.select(0)
	_select_style("Military")
	_apply_genre_defaults()
	generate()

func _open_export() -> void:
	if current_config.is_empty():
		return
	preview._finish_drag()
	export_dialog.popup_centered_ratio(0.75)

func _export_to(directory: String) -> void:
	var result = Exporter.export_hud(current_config, selected_variant, directory)
	if result.ok:
		status_label.text = "Exported to " + result.path
		export_result.title = "Your HUD is ready"
		export_result.dialog_text = "Saved your editable scene, theme, preset, and integration guide.\n\n" + result.path + "\n\nCopy the whole folder into your Godot project and instance hud.tscn."
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

func _space(parent: Node, height: float) -> void:
	var space = Control.new()
	space.custom_minimum_size.y = height
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(space)
