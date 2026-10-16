extends Control
## The illustrative world is preview-only. The overlaid HUD is the real export.

const Generator = preload("res://scripts/hud_generator.gd")
signal element_selected(element: String)
signal element_moving(element: String, at: Vector2)
signal element_moved(element: String, previous: Vector2, current: Vector2)

var editable = false
var snap_to_grid = false
var selected_element = ""
var dragging = false
var drag_offset = Vector2.ZERO
var drag_start = Vector2.ZERO
var selection_overlay: Control
var hud: Control
var config: Dictionary = {}
var design_scale = 1.0
var origin = Vector2.ZERO

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP if editable else Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_ALL if editable else Control.FOCUS_NONE
	if editable:
		selection_overlay = Control.new()
		selection_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selection_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		selection_overlay.draw.connect(_draw_selection)
		add_child(selection_overlay)
	resized.connect(_fit)
	_fit()

func show_design(settings: Dictionary, variant: int) -> void:
	dragging = false
	config = settings.duplicate(true)
	if is_instance_valid(hud):
		remove_child(hud)
		hud.queue_free()
	hud = Generator.build(config, variant)
	_ignore_pointer(hud)
	add_child(hud)
	if is_instance_valid(selection_overlay):
		move_child(selection_overlay, -1)
	if not hud.has_node(NodePath(selected_element)) or selected_element.is_empty():
		selected_element = ""
	_fit()

func _fit() -> void:
	design_scale = minf(size.x / 1280.0, size.y / 720.0)
	origin = (size - Generator.CANVAS * design_scale) / 2.0
	if is_instance_valid(hud):
		hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		hud.position = origin
		hud.size = Generator.CANVAS
		hud.scale = Vector2.ONE * design_scale
	queue_redraw()
	_redraw_selection()

func _ignore_pointer(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_pointer(child)

func _selected() -> Control:
	if selected_element.is_empty() or not is_instance_valid(hud):
		return null
	return hud.get_node_or_null(NodePath(selected_element)) as Control

func _hit_test(at: Vector2) -> Control:
	if not is_instance_valid(hud):
		return null
	var children = hud.get_children()
	children.reverse()
	for child in children:
		if Rect2(child.position, child.size * child.scale).has_point(at):
			return child
	return null

func _gui_input(event: InputEvent) -> void:
	if not editable or design_scale <= 0:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			grab_focus()
			var at = (event.position - origin) / design_scale
			var element = _hit_test(at)
			selected_element = str(element.name) if element != null else ""
			element_selected.emit(selected_element)
			if element != null:
				dragging = true
				drag_start = element.position
				drag_offset = at - element.position
		else:
			_finish_drag()
		_redraw_selection()
		accept_event()
	elif event is InputEventMouseMotion:
		if dragging:
			var element = _selected()
			if element != null:
				var at = (event.position - origin) / design_scale - drag_offset
				if snap_to_grid:
					at = at.snapped(Vector2(8, 8))
				element.position = Generator.bound_position(element, at)
				element_moving.emit(selected_element, element.position)
				_redraw_selection()
		else:
			mouse_default_cursor_shape = Control.CURSOR_MOVE if _hit_test((event.position - origin) / design_scale) != null else Control.CURSOR_ARROW
	elif event is InputEventKey and event.pressed and not event.is_command_or_control_pressed():
		var direction = Vector2.ZERO
		match event.keycode:
			KEY_LEFT: direction = Vector2.LEFT
			KEY_RIGHT: direction = Vector2.RIGHT
			KEY_UP: direction = Vector2.UP
			KEY_DOWN: direction = Vector2.DOWN
		var element = _selected()
		if element != null and direction != Vector2.ZERO:
			var previous = element.position
			element.position = Generator.bound_position(element, previous + direction * (10 if event.shift_pressed else 1))
			element_moved.emit(selected_element, previous, element.position)
			_redraw_selection()
			accept_event()

func _finish_drag() -> void:
	var element = _selected()
	var was_dragging = dragging
	dragging = false
	if was_dragging and element != null and not drag_start.is_equal_approx(element.position):
		element_moved.emit(selected_element, drag_start, element.position)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_finish_drag()

func _redraw_selection() -> void:
	if is_instance_valid(selection_overlay):
		selection_overlay.queue_redraw()

func _draw_selection() -> void:
	var element = _selected()
	if element == null:
		return
	var rect = Rect2(origin + element.position * design_scale, element.size * element.scale * design_scale).grow(3)
	selection_overlay.draw_rect(rect, Color("b9ef77"), false, 1.5)
	for point in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		selection_overlay.draw_rect(Rect2(point - Vector2(3, 3), Vector2(6, 6)), Color("b9ef77"))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("090f13"))
	if config.is_empty():
		return
	draw_set_transform(origin, 0, Vector2.ONE * design_scale)
	var accent = Color(config.accent)
	var sky_top = Color("192e37").lerp(accent.darkened(0.78), 0.3)
	var sky_bottom = Color("617674").lerp(accent.darkened(0.48), 0.3)
	for i in range(32):
		draw_rect(Rect2(0, i * 13, 1280, 14), sky_top.lerp(sky_bottom, i / 32.0))
	draw_circle(Vector2(852, 135), 44, Color(accent, 0.13))
	draw_circle(Vector2(852, 135), 28, Color("cad5bc", 0.18))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 315), Vector2(140, 183), Vector2(244, 257), Vector2(400, 153), Vector2(586, 307), Vector2(758, 226), Vector2(930, 293), Vector2(1110, 181), Vector2(1280, 275), Vector2(1280, 440), Vector2(0, 440)]), Color("263d40"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 383), Vector2(249, 285), Vector2(470, 357), Vector2(690, 261), Vector2(910, 354), Vector2(1160, 293), Vector2(1280, 340), Vector2(1280, 480), Vector2(0, 480)]), Color("304746"))
	draw_rect(Rect2(0, 390, 1280, 330), Color("1d2d30"))
	if config.genre == "Racing":
		_road(accent)
	else:
		_outpost(accent)
	# Ground detail and a subtle frame keep the reference environment quiet.
	for i in range(9):
		var ground_y = 420.0 + i * i * 4.8
		draw_line(Vector2(0, ground_y), Vector2(1280, ground_y), Color("b3cebd", 0.025), 1)
	draw_rect(Rect2(0, 0, 1280, 720), Color("080f16", 0.19))
	draw_rect(Rect2(1, 1, 1278, 718), Color(accent, 0.10), false, 2)
	draw_set_transform(Vector2.ZERO)

func _road(accent: Color) -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(590, 390), Vector2(710, 390), Vector2(1180, 720), Vector2(90, 720)]), Color("303a3e"))
	draw_line(Vector2(590, 390), Vector2(90, 720), Color(accent, 0.5), 4)
	draw_line(Vector2(710, 390), Vector2(1180, 720), Color(accent, 0.5), 4)
	for i in range(6):
		var start = Vector2(650, 405 + i * i * 8)
		draw_line(start, start + Vector2(0, 7 + i * 6), Color("d1d4bb", 0.7), 2 + i)
	for x in [260, 960]:
		draw_rect(Rect2(x, 285, 16, 170), Color("182c30"))
		draw_rect(Rect2(x, 290, 16, 55), Color(accent, 0.7))

func _outpost(accent: Color) -> void:
	# A simple architectural scene; it is not game artwork or part of the HUD.
	draw_colored_polygon(PackedVector2Array([Vector2(0, 260), Vector2(272, 312), Vector2(272, 559), Vector2(0, 690)]), Color("17282d"))
	draw_colored_polygon(PackedVector2Array([Vector2(272, 312), Vector2(394, 279), Vector2(394, 492), Vector2(272, 559)]), Color("253b3d"))
	draw_rect(Rect2(30, 278, 195, 23), Color("48605a"))
	draw_colored_polygon(PackedVector2Array([Vector2(981, 262), Vector2(1280, 185), Vector2(1280, 630), Vector2(981, 495)]), Color("213437"))
	draw_colored_polygon(PackedVector2Array([Vector2(874, 312), Vector2(981, 262), Vector2(981, 495), Vector2(874, 453)]), Color("15292f"))
	for i in range(5):
		draw_line(Vector2(1010, 303 + i * 35), Vector2(1280, 239 + i * 52), Color("688277", 0.16), 3)
	draw_rect(Rect2(488, 335, 247, 115), Color("263d3c"))
	draw_rect(Rect2(508, 353, 205, 7), Color(accent, 0.3))
	draw_rect(Rect2(531, 386, 69, 64), Color("142b30"))
	draw_rect(Rect2(626, 387, 63, 31), Color("719288", 0.3))
	draw_colored_polygon(PackedVector2Array([Vector2(408, 720), Vector2(565, 450), Vector2(676, 450), Vector2(908, 720)]), Color("465650", 0.18))
	for i in range(4):
		var x = 411 + i * 145
		draw_line(Vector2(x, 470), Vector2(x + (x - 640) * 1.1, 720), Color("9ab0a0", 0.065), 2)
	draw_rect(Rect2(784, 425, 48, 53), Color("354a43"))
	draw_line(Vector2(790, 431), Vector2(826, 431), Color(accent, 0.5), 2)
