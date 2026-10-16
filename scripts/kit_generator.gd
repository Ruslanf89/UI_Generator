extends RefCounted
## Builds a coordinated, script-free kit of native Godot controls.

const Art = preload("res://scripts/kit_art.gd")
const STYLES = ["Illustrated fantasy", "Medieval pixel"]
const PAGES = ["Menu", "HUD", "Components"]
const MATERIALS = ["Wood", "Stone", "Parchment"]
const ORNAMENTS = ["Simple", "Balanced", "Rich"]
const CANVAS = Vector2(1280, 720)
const MIN_ELEMENT_SCALE = 0.35
const MAX_ELEMENT_SCALE = 3.0

static func make_config(style: String = STYLES[0]) -> Dictionary:
	return {"mode": "kit", "genre": "Fantasy kit", "style": style,
		"components": ["health", "mana", "minimap", "abilities", "objective", "resources"],
		"accent": "ecc17b" if style == STYLES[0] else "f3bd70", "scale": 1.0,
		"health": 78.0, "mana": 62.0, "resolution": Vector2i(1920, 1080),
		"positions": {}, "element_scales": {}, "art": {"enabled": false},
		"kit": {"seed": randi_range(1, 2147483647), "material": "Wood",
			"ornaments": "Balanced", "component_seeds": {}}}

static func make_theme(config: Dictionary) -> Theme:
	var result = Theme.new()
	var font = SystemFont.new()
	if _pixel(config):
		font.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "Courier New"])
		font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		font.hinting = TextServer.HINTING_LIGHT
	else:
		font.font_names = PackedStringArray(["Georgia", "DejaVu Serif", "Times New Roman"])
	result.default_font = font
	result.default_font_size = 20
	result.set_color("font_color", "Label", _ink(config))
	result.set_color("font_shadow_color", "Label", Color("100d0b", 0.65) if not _light(config) else Color.TRANSPARENT)
	result.set_constant("shadow_offset_x", "Label", 1 if _pixel(config) else 0)
	result.set_constant("shadow_offset_y", "Label", 2 if _pixel(config) else 1)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		result.set_color(state, "Button", _ink(config))
	result.set_color("font_disabled_color", "Button", _ink(config).lerp(_muted(config), 0.7))
	result.set_font_size("font_size", "Button", 23 if not _pixel(config) else 21)
	return result

static func build(config: Dictionary, page: int = 0) -> Control:
	page = clampi(page, 0, PAGES.size() - 1)
	var root = Control.new()
	root.name = "FantasyKit"
	root.size = CANVAS
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if _pixel(config) else CanvasItem.TEXTURE_FILTER_LINEAR
	root.theme = make_theme(config)
	root.set_meta("generator", "UI Forge")
	root.set_meta("genre", "Fantasy kit")
	root.set_meta("style", config.style)
	root.set_meta("layout", PAGES[page])
	match page:
		0: _menu(root, config)
		1: _hud(root, config)
		2: _components(root, config)
	var positions: Dictionary = config.get("positions", {}).get(str(page), {})
	var scales: Dictionary = config.get("element_scales", {}).get(str(page), {})
	var global_scale = float(config.get("scale", 1.0))
	for child in root.get_children():
		child.set_meta("preset_scale", global_scale)
		var factor = clampf(float(scales.get(str(child.name), 1.0)), MIN_ELEMENT_SCALE, MAX_ELEMENT_SCALE)
		var maximum = minf(CANVAS.x / child.size.x, CANVAS.y / child.size.y)
		child.scale = Vector2.ONE * minf(global_scale * factor, maximum)
		# Keep a centered composition when the global kit size changes.
		child.position += (CANVAS / 2.0 - child.position - child.size / 2.0) * (1.0 - global_scale)
		if positions.has(str(child.name)):
			child.position = positions[str(child.name)]
		child.position = bound_position(child, child.position)
	assign_owners(root, root)
	return root

static func _menu(root: Control, config: Dictionary) -> void:
	_banner(root, config, "TitleBanner", "REALMBOUND", "A TALE OF EMBERS & ANCIENT MAGIC", Rect2(322, 30, 636, 120))
	var menu = _panel(root, config, "MenuPanel", Rect2(146, 192, 384, 476))
	_label(menu, "Heading", "Your adventure", Rect2(32, 27, 320, 42), 28, _ink(config), true)
	_divider(menu, config, Rect2(50, 83, 284, 2))
	for i in range(4):
		var title: String = ["Continue", "New journey", "Settings", "Exit game"][i]
		var node_name: String = ["ContinueButton", "NewJourneyButton", "SettingsButton", "ExitButton"][i]
		_button(root, config, node_name, title, Rect2(182, 294 + i * 80, 312, 62))
	_label(menu, "Footer", "CHAPTER I  /  THE OLD KINGDOM", Rect2(28, 425, 328, 26), 14, _muted(config), true)
	var profile = _panel(root, config, "CharacterPanel", Rect2(580, 192, 548, 476))
	_icon(profile, config, "CharacterPanel", "Crest", "icon_shield", Rect2(219, 22, 110, 110))
	_label(profile, "Name", "Elara, the Wayfarer", Rect2(24, 139, 500, 40), 28, _ink(config), true)
	_label(profile, "Class", "LEVEL 12  /  SPELLBLADE", Rect2(30, 182, 488, 28), 16, _muted(config), true)
	_divider(profile, config, Rect2(60, 225, 428, 2))
	_icon(profile, config, "CharacterPanel", "GoldIcon", "icon_coin", Rect2(85, 246, 36, 36))
	_label(profile, "Gold", "1,240 gold", Rect2(130, 248, 172, 30), 20)
	_icon(profile, config, "CharacterPanel", "ManaIcon", "icon_mana", Rect2(324, 246, 36, 36))
	_label(profile, "Crystals", "85 shards", Rect2(370, 248, 150, 30), 20)
	var quest = _nested_panel(profile, config, "CharacterPanel", "Quest", Rect2(30, 312, 488, 132), "panel")
	_icon(quest, config, "CharacterPanel", "Scroll", "icon_scroll", Rect2(21, 33, 58, 58))
	_label(quest, "Heading", "THE FORGOTTEN SANCTUARY", Rect2(97, 23, 370, 28), 16, _muted(config))
	var description = _label(quest, "Description", "Follow the lanterns beyond\nthe Whispering Woods.", Rect2(97, 55, 364, 62), 20)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

static func _hud(root: Control, config: Dictionary) -> void:
	_banner(root, config, "TitleBanner", "ASHEN HOLLOW", "THE NORTHERN REACHES", Rect2(432, 28, 416, 88))
	_stat(root, config, "Health", "VITALITY", "icon_heart", Rect2(44, 518, 380, 78), float(config.get("health", 78)))
	_stat(root, config, "Mana", "MANA", "icon_mana", Rect2(44, 608, 380, 78), float(config.get("mana", 62)))
	var purse = _panel(root, config, "Currency", Rect2(44, 34, 254, 68))
	_icon(purse, config, "Currency", "Coin", "icon_coin", Rect2(16, 13, 42, 42))
	_label(purse, "Value", "1,240", Rect2(76, 12, 154, 42), 28)
	var map = _panel(root, config, "Minimap", Rect2(1010, 34, 226, 230))
	_label(map, "Title", "WHISPERING WOODS", Rect2(15, 12, 196, 25), 13, _muted(config), true)
	var content = Control.new()
	content.name = "MapContent"
	content.position = Vector2(18, 45)
	content.size = Vector2(190, 153)
	content.clip_contents = true
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.add_child(content)
	_map_landmark(content, "River", PackedVector2Array([Vector2(-8, 18), Vector2(56, 40), Vector2(74, 91), Vector2(134, 116), Vector2(150, 160)]), Color("4c8393", 0.85), 12)
	_map_landmark(content, "Road", PackedVector2Array([Vector2(1, 125), Vector2(42, 112), Vector2(72, 70), Vector2(128, 61), Vector2(187, 16)]), Color("ba9b64", 0.8), 5)
	for i in range(11):
		var tree = Polygon2D.new()
		tree.name = "Tree%d" % (i + 1)
		tree.polygon = PackedVector2Array([Vector2(0, 17), Vector2(8, 0), Vector2(17, 17)])
		tree.position = Vector2(12 + (i * 43) % 158, 8 + (i * 31) % 112)
		tree.color = Color("47794b") if _light(config) else Color("6b8a59")
		content.add_child(tree)
	_icon(content, config, "Minimap", "Player", "icon_arrow", Rect2(84, 75, 27, 27))
	_icon(content, config, "Minimap", "QuestMarker", "icon_star", Rect2(144, 16, 25, 25))
	_label(map, "Compass", "N   ·   E   ·   S   ·   W", Rect2(10, 200, 206, 20), 12, _muted(config), true)
	var objective = _panel(root, config, "Objective", Rect2(926, 296, 310, 194))
	_icon(objective, config, "Objective", "Scroll", "icon_scroll", Rect2(20, 19, 38, 38))
	_label(objective, "Title", "A light in the dark", Rect2(67, 22, 220, 33), 21)
	_divider(objective, config, Rect2(24, 70, 262, 2))
	var description = _label(objective, "Description", "Find the ancient sanctuary", Rect2(26, 83, 260, 54), 20)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(objective, "Progress", "Lanterns lit    2 / 3", Rect2(26, 145, 260, 27), 17, _muted(config))
	var icons = ["icon_sword", "icon_shield", "icon_potion", "icon_mana"]
	for i in range(4):
		var node_name = "Ability%d" % (i + 1)
		var button = _button(root, config, node_name, "", Rect2(478 + i * 88, 602, 78, 78), "normal", "slot")
		_icon(button, config, node_name, "Icon", icons[i], Rect2(17, 10, 44, 44))
		_label(button, "Key", ["Q", "E", "R", "F"][i], Rect2(8, 53, 62, 20), 13, _ink(config), true)
	_button(root, config, "QuestLogButton", "Quest log", Rect2(1052, 630, 184, 54))

static func _components(root: Control, config: Dictionary) -> void:
	_banner(root, config, "TitleBanner", "THE ADVENTURER'S KIT", "ONE SEED  /  A COORDINATED COLLECTION", Rect2(322, 24, 636, 104))
	var panel = _panel(root, config, "SamplePanel", Rect2(44, 158, 348, 364))
	_icon(panel, config, "SamplePanel", "Crest", "icon_shield", Rect2(132, 27, 84, 84))
	_label(panel, "Title", "Guild of the Dawn", Rect2(22, 125, 304, 38), 25, _ink(config), true)
	_label(panel, "Subtitle", "An editable framed panel", Rect2(22, 170, 304, 30), 16, _muted(config), true)
	_divider(panel, config, Rect2(36, 220, 276, 2))
	_icon(panel, config, "SamplePanel", "QuestIcon", "icon_scroll", Rect2(28, 252, 48, 48))
	_label(panel, "QuestTitle", "The first chapter", Rect2(91, 250, 230, 30), 19)
	_label(panel, "QuestDetail", "Your story begins here.", Rect2(91, 282, 230, 27), 15, _muted(config))
	for i in range(4):
		var node_name: String = ["PrimaryButton", "HoverButton", "PressedButton", "DisabledButton"][i]
		var state: String = ["normal", "hover", "pressed", "disabled"][i]
		var title: String = ["Begin adventure", "Hovered", "Pressed", "Unavailable"][i]
		_button(root, config, node_name, title, Rect2(438, 166 + i * 89, 300, 64), state)
	var inventory = _panel(root, config, "Inventory", Rect2(784, 158, 452, 364))
	_label(inventory, "Title", "Inventory", Rect2(28, 17, 300, 40), 27)
	_label(inventory, "Capacity", "15 / 30", Rect2(298, 25, 124, 27), 16, _muted(config))
	_divider(inventory, config, Rect2(26, 69, 400, 2))
	var items = ["icon_sword", "icon_shield", "icon_potion", "icon_bag", "icon_scroll", "icon_heart", "icon_mana", "icon_coin", "icon_gear"]
	for i in range(15):
		var slot = _nested_panel(inventory, config, "Inventory", "Slot%d" % (i + 1), Rect2(26 + (i % 5) * 81, 88 + (i / 5) * 82, 70, 70), "slot")
		if i < items.size():
			_icon(slot, config, "Inventory", "Icon", items[i], Rect2(13, 10, 44, 44))
			if i in [2, 6, 7]:
				_label(slot, "Count", ["3", "8", "24"][[2, 6, 7].find(i)], Rect2(35, 46, 26, 18), 12, _ink(config), true)
	_stat(root, config, "Health", "VITALITY", "icon_heart", Rect2(44, 562, 348, 90), float(config.get("health", 78)))
	_stat(root, config, "Mana", "MANA", "icon_mana", Rect2(438, 562, 300, 90), float(config.get("mana", 62)))
	var icons = ["icon_sword", "icon_shield", "icon_potion", "icon_heart", "icon_gear", "icon_bag", "icon_arrow", "icon_star", "icon_coin", "icon_scroll", "icon_mana", "icon_close"]
	for i in range(icons.size()):
		var name = "Icon%d" % (i + 1)
		var icon = _icon(root, config, name, name, icons[i], Rect2(791 + (i % 6) * 74, 550 + (i / 6) * 72, 62, 62))
		icon.set_meta("kit_component", name)

static func _banner(root: Control, config: Dictionary, id: String, title: String, subtitle: String, rect: Rect2) -> Panel:
	var panel = _panel(root, config, id, rect, "banner")
	var title_size = 40 if rect.size.y > 100 else 29
	if _pixel(config):
		title_size -= 4
	_label(panel, "Title", title, Rect2(25, rect.size.y * 0.16, rect.size.x - 50, rect.size.y * 0.47), title_size, _ink(config), true)
	_label(panel, "Subtitle", subtitle, Rect2(25, rect.size.y * 0.62, rect.size.x - 50, rect.size.y * 0.23), 13 if _pixel(config) else 14, _muted(config), true)
	return panel

static func _stat(root: Control, config: Dictionary, id: String, title: String, icon_kind: String, rect: Rect2, value: float) -> Panel:
	var panel = _panel(root, config, id, rect)
	_icon(panel, config, id, "Emblem", icon_kind, Rect2(16, (rect.size.y - 48) / 2.0, 48, 48))
	_label(panel, "Title", title, Rect2(78, 11, rect.size.x - 190, 23), 16, _muted(config))
	var amount = _label(panel, "Amount", "%d / 100" % value, Rect2(rect.size.x - 115, 11, 94, 23), 16)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var bar = ProgressBar.new()
	bar.name = "Value"
	bar.position = Vector2(78, 43 if rect.size.y < 85 else 48)
	bar.size = Vector2(rect.size.x - 102, 18 if rect.size.y < 85 else 22)
	bar.value = value
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _texture_style(config, bar.size, id, "bar_frame"))
	bar.add_theme_stylebox_override("fill", _texture_style(config, bar.size, id, "fill_health" if id == "Health" else "fill_mana"))
	panel.add_child(bar)
	return panel

static func _panel(root: Control, config: Dictionary, id: String, rect: Rect2, kind: String = "panel") -> Panel:
	var result = _nested_panel(root, config, id, id, rect, kind)
	result.set_meta("kit_component", id)
	return result

static func _nested_panel(parent: Control, config: Dictionary, component: String, node_name: String, rect: Rect2, kind: String) -> Panel:
	var result = Panel.new()
	result.name = node_name
	result.position = rect.position
	result.size = rect.size
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_stylebox_override("panel", _texture_style(config, rect.size, component, kind))
	parent.add_child(result)
	return result

static func _button(root: Control, config: Dictionary, id: String, title: String, rect: Rect2, sample_state: String = "normal", kind: String = "button") -> Button:
	var button = Button.new()
	button.name = id
	button.position = rect.position
	button.size = rect.size
	button.text = title
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.set_meta("kit_component", id)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, _texture_style(config, rect.size, id, kind, sample_state if state == "normal" else state))
	button.add_theme_constant_override("outline_size", 0)
	button.add_theme_constant_override("h_separation", 0)
	button.add_theme_font_size_override("font_size", 22 if _pixel(config) else 24)
	button.disabled = sample_state == "disabled"
	root.add_child(button)
	return button

static func _texture_style(config: Dictionary, dimensions: Vector2, component: String, kind: String, state: String = "normal") -> StyleBoxTexture:
	var style = StyleBoxTexture.new()
	style.texture = Art.texture(config, dimensions, component, kind, state)
	# Art is drawn for these exact native control dimensions. Keep its full
	# silhouette, bevel and ornament proportions when downsampling the @2x image.
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

static func _icon(parent: Control, config: Dictionary, component: String, node_name: String, kind: String, rect: Rect2) -> TextureRect:
	var icon = TextureRect.new()
	icon.name = node_name
	icon.position = rect.position
	icon.size = rect.size
	icon.texture = Art.texture(config, rect.size, component, kind)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon

static func _label(parent: Control, node_name: String, value: String, rect: Rect2, font_size: int = 20, color: Color = Color.TRANSPARENT, centered: bool = false) -> Label:
	var result = Label.new()
	result.name = node_name
	result.text = value
	result.position = rect.position
	result.size = rect.size
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	result.add_theme_font_size_override("font_size", font_size)
	if color != Color.TRANSPARENT:
		result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result

static func _divider(parent: Control, config: Dictionary, rect: Rect2) -> void:
	var line = ColorRect.new()
	line.name = "Divider"
	line.position = rect.position
	line.size = rect.size
	line.color = Color(config.accent, 0.4) if not _light(config) else Color("74512f", 0.4)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)

static func _map_landmark(parent: Control, node_name: String, points: PackedVector2Array, color: Color, width: float) -> void:
	var line = Line2D.new()
	line.name = node_name
	line.points = points
	line.default_color = color
	line.width = width
	line.joint_mode = Line2D.LINE_JOINT_SHARP
	line.begin_cap_mode = Line2D.LINE_CAP_NONE
	line.end_cap_mode = Line2D.LINE_CAP_NONE
	parent.add_child(line)

static func _pixel(config: Dictionary) -> bool:
	return config.get("style", STYLES[0]) == STYLES[1]

static func _light(config: Dictionary) -> bool:
	return config.get("kit", {}).get("material", "Wood") == "Parchment"

static func _ink(config: Dictionary) -> Color:
	return Color("3f291e") if _light(config) else Color("fff0cd")

static func _muted(config: Dictionary) -> Color:
	return Color("755037") if _light(config) else Color("e2c69a")

static func bound_position(element: Control, requested: Vector2) -> Vector2:
	var maximum = (CANVAS - element.size * element.scale).max(Vector2.ZERO)
	return requested.clamp(Vector2.ZERO, maximum)

static func assign_owners(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		assign_owners(child, root)
