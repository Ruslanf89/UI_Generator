extends RefCounted
## Builds a coordinated, script-free kit of native Godot controls.

const Art = preload("res://scripts/kit_art.gd")
const Design = preload("res://scripts/kit_design.gd")
const Shapes = preload("res://scripts/kit_shapes.gd")
const STYLES = Design.ART_STYLES
const PAGES = ["Menu", "HUD", "Components"]
const MATERIALS = ["Wood", "Stone", "Parchment"]
const ORNAMENTS = ["Simple", "Balanced", "Rich"]
const DESIGNS = Design.FAMILIES
const CANVAS = Vector2(1280, 720)
const MIN_ELEMENT_SCALE = 0.35
const MAX_ELEMENT_SCALE = 3.0
static var contour_texture_cache: Dictionary = {}

static func make_config(style: String = STYLES[0]) -> Dictionary:
	return {"mode": "kit", "genre": "Fantasy kit", "style": style,
		"components": ["health", "mana", "minimap", "abilities", "objective", "resources"],
		"accent": "ecc17b" if style == STYLES[0] else "f3bd70", "scale": 1.0,
		"health": 78.0, "mana": 62.0, "resolution": Vector2i(1920, 1080),
		"positions": {}, "element_scales": {}, "art": {"enabled": false},
		"kit": {"seed": randi_range(1, 2147483647), "material": "Wood",
			"ornaments": "Balanced", "design": DESIGNS[0], "component_seeds": {}}}

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
	var recipe = Design.recipe(config)
	root.set_meta("design_family", recipe.family)
	root.set_meta("layout_recipe", recipe.layout)
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

static func _seeded_layout(config: Dictionary) -> Dictionary:
	# Only the kit seed drives composition. Artwork overrides never move controls.
	var recipe = Design.recipe(config)
	var rng = RandomNumberGenerator.new()
	rng.seed = int(recipe.seed) * 104729 + 7919
	return {"layout": int(recipe.layout), "rng": rng}

static func _menu_geometry(config: Dictionary) -> Dictionary:
	var parameters = _seeded_layout(config)
	var layout = int(parameters.layout)
	var rng: RandomNumberGenerator = parameters.rng
	var banner_rect: Rect2
	var menu_rect: Rect2
	var profile_rect: Rect2
	var buttons: Array[Rect2] = []
	match layout:
		0: # Split court: a vertical menu beside a heraldic character card.
			var spread = float(rng.randi_range(960, 1080))
			var gutter = float(rng.randi_range(44, 62))
			var column = roundf((spread - gutter) * rng.randf_range(0.38, 0.43))
			var top = float(rng.randi_range(180, 204))
			var left = roundf((CANVAS.x - spread) / 2.0)
			var height = 674.0 - top
			var banner_width = float(rng.randi_range(600, 720))
			banner_rect = Rect2(roundf((CANVAS.x - banner_width) / 2.0), 30, banner_width, rng.randi_range(108, 124))
			menu_rect = Rect2(left, top, column, height)
			profile_rect = Rect2(left + column + gutter, top, spread - column - gutter, height)
			var button_top = _header_height(menu_rect.size) + 50
			var available = height - button_top - 53
			var gap = float(rng.randi_range(10, 14))
			var button_height = minf(float(rng.randi_range(54, 60)), floorf((available - 3.0 * gap) / 4.0))
			var inset = float(rng.randi_range(32, 40))
			var first_y = top + button_top + floorf((available - button_height * 4 - gap * 3) / 2.0)
			for i in 4:
				buttons.append(Rect2(left + inset, first_y + i * (button_height + gap), column - inset * 2, button_height))
		1: # Story sidebar: navigation is a tall left rail; the story leads right.
			var column = float(rng.randi_range(320, 376))
			var gutter = float(rng.randi_range(40, 56))
			var story_x = 44.0 + column + gutter
			var story_width = 1236.0 - story_x
			var banner_height = float(rng.randi_range(104, 126))
			banner_rect = Rect2(story_x + 20, 42, story_width - 40, banner_height)
			menu_rect = Rect2(44, 42, column, 626)
			var story_y = banner_rect.end.y + rng.randi_range(40, 52)
			profile_rect = Rect2(story_x, story_y, story_width, 668.0 - story_y)
			var gap = float(rng.randi_range(22, 34))
			var button_top = _header_height(menu_rect.size) + 70
			var available = menu_rect.size.y - button_top - 90
			var button_height = minf(float(rng.randi_range(64, 72)), floorf((available - 3 * gap) / 4.0))
			var inset = float(rng.randi_range(30, 36))
			var first_y = menu_rect.position.y + button_top + floorf((available - button_height * 4 - gap * 3) / 2.0)
			for i in 4:
				buttons.append(Rect2(44 + inset, first_y + i * (button_height + gap), column - inset * 2, button_height))
		2: # Command grid: wide character summary above a two-column action tray.
			var margin = float(rng.randi_range(40, 64))
			var banner_width = float(rng.randi_range(570, 700))
			banner_rect = Rect2(roundf((CANVAS.x - banner_width) / 2.0), 26, banner_width, rng.randi_range(92, 108))
			profile_rect = Rect2(margin, rng.randi_range(158, 170), CANVAS.x - margin * 2, rng.randi_range(232, 260))
			var tray_y = profile_rect.end.y + rng.randi_range(30, 38)
			var tray_width = float(rng.randi_range(864, 1000))
			menu_rect = Rect2(roundf((CANVAS.x - tray_width) / 2.0), tray_y, tray_width, 680 - tray_y)
			var inset = float(rng.randi_range(34, 44))
			var column_gap = float(rng.randi_range(26, 48))
			var row_gap = float(rng.randi_range(14, 22))
			var available = menu_rect.size.y - 86
			var button_height = minf(float(rng.randi_range(54, 62)), floorf((available - row_gap) / 2.0))
			var button_width = floorf((tray_width - inset * 2 - column_gap) / 2.0)
			var first_y = tray_y + 71 + floorf((available - button_height * 2 - row_gap) / 2.0)
			for i in 4:
				buttons.append(Rect2(menu_rect.position.x + inset + (i % 2) * (button_width + column_gap), first_y + (i / 2) * (button_height + row_gap), button_width, button_height))
		_: # Ribbon hall: four equal commands share one broad central ribbon.
			var banner_width = float(rng.randi_range(620, 760))
			banner_rect = Rect2(roundf((CANVAS.x - banner_width) / 2.0), 32, banner_width, rng.randi_range(108, 130))
			var ribbon_width = float(rng.randi_range(1140, 1216))
			menu_rect = Rect2(roundf((CANVAS.x - ribbon_width) / 2.0), rng.randi_range(196, 216), ribbon_width, rng.randi_range(204, 228))
			var profile_width = float(rng.randi_range(560, 660))
			var profile_y = menu_rect.end.y + rng.randi_range(36, 44)
			profile_rect = Rect2(roundf((CANVAS.x - profile_width) / 2.0), profile_y, profile_width, minf(float(rng.randi_range(198, 222)), 680 - profile_y))
			var inset = float(rng.randi_range(24, 34))
			var gap = float(rng.randi_range(14, 28))
			var button_width = floorf((ribbon_width - inset * 2 - gap * 3) / 4.0)
			var button_height = minf(float(rng.randi_range(66, 82)), menu_rect.size.y - 128)
			for i in 4:
				buttons.append(Rect2(menu_rect.position.x + inset + i * (button_width + gap), menu_rect.position.y + 80, button_width, button_height))
	return {"layout": layout, "banner": banner_rect, "menu": menu_rect, "profile": profile_rect, "buttons": buttons}

static func _menu(root: Control, config: Dictionary) -> void:
	var geometry = _menu_geometry(config)
	var layout = int(geometry.layout)
	var banner_rect: Rect2 = geometry.banner
	var menu_rect: Rect2 = geometry.menu
	var profile_rect: Rect2 = geometry.profile
	var buttons: Array[Rect2] = geometry.buttons
	_banner(root, config, "TitleBanner", "REALMBOUND", "A TALE OF EMBERS & ANCIENT MAGIC", banner_rect)
	var menu = _panel(root, config, "MenuPanel", menu_rect)
	var heading = Rect2(30, 27, menu.size.x - 60, 42)
	var footer = Rect2(28, menu.size.y - 39, menu.size.x - 56, 26)
	var rule = Rect2(50, 83, menu.size.x - 100, 2)
	if layout < 2:
		heading.position.y = _header_height(menu.size) + 3
		heading.size.y = 34
		rule.position.y = heading.end.y + 3
	elif layout == 2:
		heading = Rect2(30, 13, 330, 34)
		footer = Rect2(menu.size.x - 320, 20, 286, 24)
		rule = Rect2(34, 55, menu.size.x - 68, 2)
	elif layout == 3:
		heading = Rect2(30, 15, menu.size.x - 60, 35)
		rule = Rect2(52, 60, menu.size.x - 104, 2)
		footer.position.y = menu.size.y - 38
	_label(menu, "Heading", "Your adventure", heading, 26 if layout > 1 else 28, _ink(config), true)
	if layout != 2:
		_divider(menu, config, rule)
	for i in range(4):
		var title: String = ["Continue", "New journey", "Settings", "Exit game"][i]
		var node_name: String = ["ContinueButton", "NewJourneyButton", "SettingsButton", "ExitButton"][i]
		_button(root, config, node_name, title, buttons[i])
	_label(menu, "Footer", "CHAPTER I  /  THE OLD KINGDOM", footer, 13 if layout == 2 else 14, _muted(config), true)
	var profile = _panel(root, config, "CharacterPanel", profile_rect)
	_profile_content(profile, config, layout)
	var baselines = [Vector2(548, 476), Vector2(806, 448), Vector2(1192, 248), Vector2(572, 214)]
	_resize_contents(profile, profile.size / baselines[layout], config, "CharacterPanel")

static func _profile_content(profile: Panel, config: Dictionary, layout: int) -> void:
	var crest: Rect2
	var name_rect: Rect2
	var class_rect: Rect2
	var quest_rect: Rect2
	var gold_at: Vector2
	var shard_at: Vector2
	var centered = false
	match layout:
		0:
			crest = Rect2(219, 22, 110, 110)
			name_rect = Rect2(24, 139, 500, 40)
			class_rect = Rect2(30, 182, 488, 28)
			quest_rect = Rect2(30, 312, 488, 132)
			gold_at = Vector2(85, 246)
			shard_at = Vector2(324, 246)
			centered = true
		1:
			crest = Rect2(42, 90, 150, 150)
			name_rect = Rect2(236, 116, 526, 40)
			class_rect = Rect2(238, 160, 520, 28)
			quest_rect = Rect2(232, 266, 534, 142)
			gold_at = Vector2(238, 204)
			shard_at = Vector2(500, 204)
		2:
			crest = Rect2(34, 51, 132, 132)
			name_rect = Rect2(200, 36, 420, 45)
			class_rect = Rect2(202, 87, 418, 28)
			quest_rect = Rect2(656, 32, 500, 184)
			gold_at = Vector2(202, 150)
			shard_at = Vector2(432, 150)
		_:
			crest = Rect2(26, 52, 108, 108)
			name_rect = Rect2(156, 25, 390, 40)
			class_rect = Rect2(158, 68, 388, 28)
			quest_rect = Rect2(154, 110, 388, 76)
	var crest_node = _icon(profile, config, "CharacterPanel", "Crest", "icon_shield", crest)
	crest_node.visible = layout != 0
	_label(profile, "Name", "Elara, the Wayfarer", name_rect, 26 if layout == 3 else 28, _ink(config), centered)
	_label(profile, "Class", "LEVEL 12  /  SPELLBLADE", class_rect, 16, _muted(config), centered)
	if layout != 3:
		_icon(profile, config, "CharacterPanel", "GoldIcon", "icon_coin", Rect2(gold_at, Vector2(36, 36)))
		_label(profile, "Gold", "1,240 gold", Rect2(gold_at + Vector2(45, 2), Vector2(160, 30)), 20)
		_icon(profile, config, "CharacterPanel", "ManaIcon", "icon_mana", Rect2(shard_at, Vector2(36, 36)))
		_label(profile, "Crystals", "85 shards", Rect2(shard_at + Vector2(46, 2), Vector2(132, 30)), 20)
	if layout == 0:
		_divider(profile, config, Rect2(60, 225, 428, 2))
	var quest = _nested_panel(profile, config, "CharacterPanel", "Quest", quest_rect, "panel")
	var compact = layout == 3
	_icon(quest, config, "CharacterPanel", "Scroll", "icon_scroll", Rect2(16 if compact else 22, 20 if compact else 39, 34 if compact else 58, 34 if compact else 58))
	var inset = 65.0 if compact else 100.0
	_label(quest, "Heading", "THE FORGOTTEN SANCTUARY", Rect2(inset, 12 if compact else 20, quest.size.x - inset - 18, 24 if compact else 28), 14 if compact else 16, _muted(config))
	var description_y = 37.0 if compact else (57.0 if quest.size.y < 150 else 70.0)
	var description = _label(quest, "Description", "Beyond the Whispering Woods." if compact else "Follow the lanterns beyond\nthe Whispering Woods.", Rect2(inset, description_y, quest.size.x - inset - 22, quest.size.y - description_y - 14), 14 if compact else 20)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

static func _resize_contents(parent: Control, factor: Vector2, config: Dictionary, component: String) -> void:
	# Reflow native child rectangles inside a resized profile. Fonts retain their
	# readable point sizes; regenerated images match their new logical dimensions.
	for child in parent.get_children():
		if not child is Control:
			continue
		child.position *= factor
		child.size *= factor
		if child is TextureRect and child.texture != null:
			var role = str(child.texture.get_meta("kit_art_role", ""))
			if not role.is_empty():
				child.texture = Art.texture(config, child.size, component, role)
		elif child is Panel:
			var style = child.get_theme_stylebox("panel") as StyleBoxTexture
			if style != null and style.texture != null:
				var role = str(style.texture.get_meta("kit_art_role", "panel"))
				child.add_theme_stylebox_override("panel", _texture_style(config, child.size, component, role))
		_resize_contents(child, factor, config, component)

static func _hud_geometry(config: Dictionary) -> Dictionary:
	var parameters = _seeded_layout(config)
	var layout = int(parameters.layout)
	var rng: RandomNumberGenerator = parameters.rng
	var banner_rect: Rect2
	var health_rect: Rect2
	var mana_rect: Rect2
	var currency_rect: Rect2
	var map_rect: Rect2
	var objective_rect: Rect2
	var quest_rect: Rect2
	var abilities: Array[Rect2] = []
	match layout:
		0: # Classic corner HUD with a low horizontal hotbar.
			var banner_width = float(rng.randi_range(400, 500))
			banner_rect = Rect2(roundf((CANVAS.x - banner_width) / 2.0), 28, banner_width, rng.randi_range(84, 100))
			var stat_width = float(rng.randi_range(350, 400))
			var stat_height = float(rng.randi_range(148, 164))
			var stat_gap = float(rng.randi_range(14, 22))
			health_rect = Rect2(44, 686 - stat_height * 2 - stat_gap, stat_width, stat_height)
			mana_rect = Rect2(44, 686 - stat_height, stat_width, stat_height)
			currency_rect = Rect2(44, 34, rng.randi_range(232, 264), rng.randi_range(64, 74))
			var map_size = float(rng.randi_range(264, 292))
			map_rect = Rect2(1236 - map_size, 32, map_size, rng.randi_range(310, 328))
			var objective_width = float(rng.randi_range(300, 328))
			objective_rect = Rect2(1236 - objective_width, map_rect.end.y + 26, objective_width, rng.randi_range(178, 204))
			quest_rect = Rect2(1052, 630, 184, 54)
			var slot = float(rng.randi_range(74, 82))
			var gap = float(rng.randi_range(10, 20))
			var width = slot * 4 + gap * 3
			var first_x = maxf(roundf((CANVAS.x - width) / 2.0), health_rect.end.x + 28)
			for i in 4:
				abilities.append(Rect2(first_x + i * (slot + gap), 686 - slot, slot, slot))
		1: # Explorer: health and mana balance the two bottom corners.
			var stat_width = float(rng.randi_range(348, 380))
			var stat_height = float(rng.randi_range(148, 164))
			health_rect = Rect2(44, 686 - stat_height, stat_width, stat_height)
			mana_rect = Rect2(1236 - stat_width, 686 - stat_height, stat_width, stat_height)
			var map_size = float(rng.randi_range(264, 292))
			map_rect = Rect2(44, 32, map_size, rng.randi_range(310, 328))
			currency_rect = Rect2(44, map_rect.end.y + 24, map_size, 68)
			var objective_width = float(rng.randi_range(320, 350))
			objective_rect = Rect2(1236 - objective_width, 36, objective_width, rng.randi_range(188, 220))
			quest_rect = Rect2(1052, objective_rect.end.y + 28, 184, 54)
			var corridor_left = map_rect.end.x + 30
			var corridor_width = objective_rect.position.x - 30 - corridor_left
			var banner_width = minf(float(rng.randi_range(430, 480)), corridor_width)
			banner_rect = Rect2(corridor_left + floorf((corridor_width - banner_width) / 2.0), 32, banner_width, rng.randi_range(96, 110))
			var slot = float(rng.randi_range(74, 82))
			var gap = float(rng.randi_range(12, 20))
			var first_x = roundf((CANVAS.x - (slot * 4 + gap * 3)) / 2.0)
			for i in 4:
				abilities.append(Rect2(first_x + i * (slot + gap), 686 - slot, slot, slot))
		2: # Tactical: upper-left resources and a vertical right ability rail.
			var stat_width = float(rng.randi_range(350, 394))
			var stat_height = float(rng.randi_range(148, 160))
			health_rect = Rect2(44, 32, stat_width, stat_height)
			mana_rect = Rect2(44, health_rect.end.y + rng.randi_range(14, 22), stat_width, stat_height)
			var map_size = float(rng.randi_range(270, 292))
			map_rect = Rect2(1236 - map_size, 32, map_size, rng.randi_range(304, 318))
			var banner_x = health_rect.end.x + 44
			var banner_width = minf(float(rng.randi_range(400, 470)), map_rect.position.x - banner_x - 30)
			banner_rect = Rect2(banner_x, 34, banner_width, rng.randi_range(88, 104))
			var currency_width = float(rng.randi_range(236, 264))
			currency_rect = Rect2(roundf((CANVAS.x - currency_width) / 2.0), 598, currency_width, rng.randi_range(68, 78))
			objective_rect = Rect2(44, mana_rect.end.y + 24, rng.randi_range(310, 340), rng.randi_range(174, 190))
			quest_rect = Rect2(44, 612, 210, 56)
			var slot = float(rng.randi_range(64, 68))
			var first_y = map_rect.end.y + 22
			var gap = minf(float(rng.randi_range(10, 16)), floorf((686 - first_y - slot * 4) / 3.0))
			for i in 4:
				abilities.append(Rect2(1236 - slot, first_y + i * (slot + gap), slot, slot))
		_: # Cinematic: top-row bars, a lower map, and a compact 2 x 2 hotbar.
			var stat_width = float(rng.randi_range(316, 350))
			var stat_height = float(rng.randi_range(148, 164))
			var stat_gap = float(rng.randi_range(24, 40))
			health_rect = Rect2(1236 - stat_width * 2 - stat_gap, 38, stat_width, stat_height)
			mana_rect = Rect2(1236 - stat_width, 38, stat_width, stat_height)
			banner_rect = Rect2(44, 34, health_rect.position.x - 76, rng.randi_range(88, 104))
			var map_width = float(rng.randi_range(264, 288))
			var map_height = float(rng.randi_range(304, 320))
			map_rect = Rect2(44, 686 - map_height, map_width, map_height)
			currency_rect = Rect2(map_rect.end.x + 24, 618, rng.randi_range(200, 220), 68)
			var objective_width = float(rng.randi_range(300, 328))
			var objective_height = float(rng.randi_range(198, 224))
			objective_rect = Rect2(1236 - objective_width, 686 - objective_height, objective_width, objective_height)
			quest_rect = Rect2(1052, health_rect.end.y + 28, 184, 54)
			var slot = float(rng.randi_range(74, 82))
			var gap = float(rng.randi_range(10, 18))
			var block_size = slot * 2 + gap
			var first_x = maxf(roundf((CANVAS.x - block_size) / 2.0), currency_rect.end.x + 26)
			for i in 4:
				abilities.append(Rect2(first_x + (i % 2) * (slot + gap), 686 - block_size + (i / 2) * (slot + gap), slot, slot))
	return {"banner": banner_rect, "health": health_rect, "mana": mana_rect, "currency": currency_rect,
		"map": map_rect, "objective": objective_rect, "quest": quest_rect, "abilities": abilities}

static func _hud(root: Control, config: Dictionary) -> void:
	var geometry = _hud_geometry(config)
	var banner_rect: Rect2 = geometry.banner
	var health_rect: Rect2 = geometry.health
	var mana_rect: Rect2 = geometry.mana
	var currency_rect: Rect2 = geometry.currency
	var map_rect: Rect2 = geometry.map
	var objective_rect: Rect2 = geometry.objective
	var quest_rect: Rect2 = geometry.quest
	var abilities: Array[Rect2] = geometry.abilities
	_banner(root, config, "TitleBanner", "ASHEN HOLLOW", "THE NORTHERN REACHES", banner_rect)
	_stat(root, config, "Health", "VITALITY", "icon_heart", health_rect, float(config.get("health", 78)))
	_stat(root, config, "Mana", "MANA", "icon_mana", mana_rect, float(config.get("mana", 62)))
	var purse = _panel(root, config, "Currency", currency_rect)
	_icon(purse, config, "Currency", "Coin", "icon_coin", Rect2(16, 13, 42, 42))
	_label(purse, "Value", "1,240", Rect2(76, 12, purse.size.x - 96, 42), 28)
	var map_recipe = Design.recipe(config, "Minimap", "map_frame")
	var map_shape = str(map_recipe.get("map_shape", "circle"))
	var map = _panel(root, config, "Minimap", map_rect, "map_frame")
	map.set_meta("map_shape", map_shape)
	var aperture = Shapes.map_rect(map.size)
	var content = TextureRect.new()
	content.name = "MapContent"
	content.position = aperture.position
	content.size = aperture.size
	content.texture = Shapes.mask_texture(aperture.size, map_shape, _pixel(config))
	content.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	content.stretch_mode = TextureRect.STRETCH_SCALE
	content.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_meta("map_shape", map_shape)
	map.add_child(content)
	var world = Control.new()
	world.name = "World"
	world.size = Vector2(190, 153)
	world.scale = aperture.size / world.size
	world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(world)
	var ground = ColorRect.new()
	ground.name = "Terrain"
	ground.size = world.size
	ground.color = Color("526548") if _light(config) else Color("293f35")
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(ground)
	_map_landmark(world, "River", PackedVector2Array([Vector2(-8, 18), Vector2(56, 40), Vector2(74, 91), Vector2(134, 116), Vector2(150, 160)]), Color("4c8393", 0.85), 12)
	_map_landmark(world, "Road", PackedVector2Array([Vector2(1, 125), Vector2(42, 112), Vector2(72, 70), Vector2(128, 61), Vector2(187, 16)]), Color("ba9b64", 0.8), 5)
	for i in range(11):
		var tree = Polygon2D.new()
		tree.name = "Tree%d" % (i + 1)
		tree.polygon = PackedVector2Array([Vector2(0, 17), Vector2(8, 0), Vector2(17, 17)])
		tree.position = Vector2(12 + (i * 43) % 158, 8 + (i * 31) % 112)
		tree.color = Color("47794b") if _light(config) else Color("6b8a59")
		world.add_child(tree)
	_icon(world, config, "Minimap", "Player", "icon_arrow", Rect2(84, 75, 27, 27))
	_icon(world, config, "Minimap", "QuestMarker", "icon_star", Rect2(144, 16, 25, 25))
	_label(map, "Title", "WHISPERING WOODS", Rect2(18, map.size.y - 28, map.size.x - 36, 20), 12, _muted(config), true)
	_label(map, "Compass", "N", Rect2(map.size.x / 2.0 - 12, aperture.position.y + 3, 24, 23), 13, _ink(config), true)
	var objective = _panel(root, config, "Objective", objective_rect)
	_icon(objective, config, "Objective", "Scroll", "icon_scroll", Rect2(20, 19, 38, 38))
	_label(objective, "Title", "A light in the dark", Rect2(67, 22, objective.size.x - 90, 33), 18 if _pixel(config) else 20)
	_divider(objective, config, Rect2(24, 70, objective.size.x - 48, 2))
	var description = _label(objective, "Description", "Find the ancient sanctuary", Rect2(26, 81, objective.size.x - 52, 46), 18)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(objective, "Progress", "Lanterns lit    2 / 3", Rect2(26, objective.size.y - 40, objective.size.x - 52, 25), 16, _muted(config))
	var icons = ["icon_sword", "icon_shield", "icon_potion", "icon_mana"]
	for i in range(4):
		var node_name = "Ability%d" % (i + 1)
		var button = _button(root, config, node_name, "", abilities[i], "normal", "slot")
		var icon_size = floorf(button.size.x * 0.52)
		_icon(button, config, node_name, "Icon", icons[i], Rect2((button.size.x - icon_size) / 2.0, 9, icon_size, icon_size))
		_label(button, "Key", ["Q", "E", "R", "F"][i], Rect2(8, button.size.y - 26, button.size.x - 16, 23), 13, _ink(config), true)
	_button(root, config, "QuestLogButton", "Quest log", quest_rect)

static func _components(root: Control, config: Dictionary) -> void:
	_banner(root, config, "TitleBanner", "THE ADVENTURER'S KIT", "ONE SEED  /  A COORDINATED COLLECTION", Rect2(322, 24, 636, 104))
	var panel = _panel(root, config, "SamplePanel", Rect2(44, 158, 348, 364))
	var crest = _icon(panel, config, "SamplePanel", "Crest", "icon_shield", Rect2(132, 27, 84, 84))
	crest.hide()
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
	var header = _header_height(inventory.size)
	_label(inventory, "Title", "Inventory", Rect2(28, header + 9, 280, 36), 25)
	_label(inventory, "Capacity", "15 / 30", Rect2(298, header + 15, 124, 27), 16, _muted(config))
	_divider(inventory, config, Rect2(26, header + 52, 400, 2))
	var items = ["icon_sword", "icon_shield", "icon_potion", "icon_bag", "icon_scroll", "icon_heart", "icon_mana", "icon_coin", "icon_gear"]
	for i in range(15):
		var slot = _nested_panel(inventory, config, "Inventory", "Slot%d" % (i + 1), Rect2(40 + (i % 5) * 79, header + 65 + (i / 5) * 65, 55, 55), "slot")
		if i < items.size():
			_icon(slot, config, "Inventory", "Icon", items[i], Rect2(9, 6, 37, 37))
			if i in [2, 6, 7]:
				_label(slot, "Count", ["3", "8", "24"][[2, 6, 7].find(i)], Rect2(29, 30, 24, 22), 12, _ink(config), true)
	_stat(root, config, "Health", "VITALITY", "icon_heart", Rect2(44, 540, 348, 148), float(config.get("health", 78)))
	_stat(root, config, "Mana", "MANA", "icon_mana", Rect2(438, 540, 300, 148), float(config.get("mana", 62)))
	var icons = ["icon_sword", "icon_shield", "icon_potion", "icon_heart", "icon_gear", "icon_bag", "icon_arrow", "icon_star", "icon_coin", "icon_scroll", "icon_mana", "icon_close"]
	for i in range(icons.size()):
		var name = "Icon%d" % (i + 1)
		var icon = _icon(root, config, name, name, icons[i], Rect2(791 + (i % 6) * 74, 550 + (i / 6) * 72, 62, 62))
		icon.set_meta("kit_component", name)
	_arrange_library(root, int(Design.recipe(config).layout))

static func _arrange_library(root: Control, layout: int) -> void:
	# Reorder the demonstration columns as whole pieces; keep each root control
	# independent so selection, regeneration and exports use the same identities.
	var panel_x = 44.0
	var buttons_x = 438.0
	var inventory_x = 784.0
	match layout:
		1:
			panel_x = 888
			buttons_x = 544
			inventory_x = 44
		2:
			panel_x = 44
			buttons_x = 932
			inventory_x = 430
		3:
			panel_x = 888
			buttons_x = 44
			inventory_x = 386
	root.get_node("SamplePanel").position.x = panel_x
	root.get_node("Inventory").position.x = inventory_x
	root.get_node("Health").position.x = panel_x
	root.get_node("Mana").position.x = buttons_x
	for name in ["PrimaryButton", "HoverButton", "PressedButton", "DisabledButton"]:
		root.get_node(NodePath(name)).position.x = buttons_x
	for i in 12:
		root.get_node(NodePath("Icon%d" % (i + 1))).position.x = inventory_x + 7 + (i % 6) * 74

static func _banner(root: Control, config: Dictionary, id: String, title: String, subtitle: String, rect: Rect2) -> Panel:
	var panel = _panel(root, config, id, rect, "banner")
	var title_size = 40 if rect.size.y > 100 else 29
	if _pixel(config):
		title_size -= 4
	var inset = minf(110, rect.size.y * 0.85)
	var text_width = rect.size.x - inset * 2
	var font = panel.get_theme_font("font", "Label")
	var desired_width = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	if desired_width > text_width:
		title_size = maxi(18, floori(title_size * text_width / desired_width))
	_label(panel, "Title", title, Rect2(inset, rect.size.y * 0.16, text_width, rect.size.y * 0.47), title_size, _ink(config), true)
	_label(panel, "Subtitle", subtitle, Rect2(inset, rect.size.y * 0.62, text_width, rect.size.y * 0.23), 13 if _pixel(config) else 14, _muted(config), true)
	return panel

static func _header_height(dimensions: Vector2) -> float:
	return clampf(dimensions.y * 0.25, 80, 104) if dimensions.y > 300 else 0.0

static func _stat(root: Control, config: Dictionary, id: String, title: String, icon_kind: String, rect: Rect2, value: float) -> Panel:
	var recipe = Design.recipe(config, id, "stat_frame")
	var presentation = str(recipe.get("stat_presentation", "bar"))
	var panel = _panel(root, config, id, rect, "stat_frame")
	panel.set_meta("stat_presentation", presentation)
	var geometry = Shapes.stat_geometry(rect.size, presentation)
	var reservoir: Rect2 = geometry.reservoir
	var plaque: Rect2 = geometry.plaque
	# The sculpted head owns the far-right end of the plaque. Native text stays
	# in the quiet strip beside the reservoir, and values remain easy to read.
	var text_width = maxf(56, plaque.size.x - 68)
	_label(panel, "Title", title, Rect2(plaque.position + Vector2(2, 7), Vector2(text_width, 27)), 18, _muted(config))
	if presentation in ["orb", "vial"]:
		var liquid = TextureProgressBar.new()
		liquid.name = "Value"
		liquid.nine_patch_stretch = true
		liquid.position = reservoir.position
		liquid.size = reservoir.size
		liquid.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
		liquid.texture_under = _contour_texture(Art.texture(config, reservoir.size, id, "reservoir_empty"), reservoir.size, presentation, _pixel(config))
		liquid.texture_progress = _contour_texture(Art.texture(config, reservoir.size, id, "reservoir_health" if id == "Health" else "reservoir_mana"), reservoir.size, presentation, _pixel(config))
		liquid.value = value
		liquid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(liquid)
	else:
		var emblem_size = minf(96, floorf(reservoir.size.x * 0.75))
		_icon(panel, config, id, "Emblem", icon_kind, Rect2(reservoir.position + Vector2((reservoir.size.x - emblem_size) / 2.0, 8), Vector2(emblem_size, emblem_size)))
		var bar = ProgressBar.new()
		bar.name = "Value"
		# Run the gauge under the creature's chin rather than stopping in the
		# narrow text column. Its full plaque width reads clearly in the preview.
		var bar_y = rect.size.y * 0.5 + 56
		bar.position = Vector2(plaque.position.x + 2, bar_y)
		bar.size = Vector2(plaque.size.x - 4, minf(18, rect.size.y - bar_y - 6))
		bar.value = value
		bar.show_percentage = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("background", _texture_style(config, bar.size, id, "bar_frame"))
		bar.add_theme_stylebox_override("fill", _texture_style(config, bar.size, id, "fill_health" if id == "Health" else "fill_mana"))
		panel.add_child(bar)
		if presentation == "segmented":
			for i in range(1, 8):
				var gap = ColorRect.new()
				gap.name = "Segment%d" % i
				gap.position = Vector2(roundf(bar.size.x * i / 8.0), 4)
				gap.size = Vector2(2, bar.size.y - 8)
				gap.color = Color("191e24")
				gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
				bar.add_child(gap)
	var amount_y = reservoir.position.y + reservoir.size.y * (0.57 if presentation in ["orb", "vial"] else 0.72)
	var amount = _label(panel, "Amount", "%d / 100" % value, Rect2(reservoir.position.x, amount_y, reservoir.size.x, 27), 17, Color("fff2d9"), true)
	amount.add_theme_color_override("font_shadow_color", Color("11101a", 0.95))
	amount.add_theme_constant_override("shadow_offset_x", 1)
	amount.add_theme_constant_override("shadow_offset_y", 1)
	return panel

static func _contour_texture(source: ImageTexture, dimensions: Vector2, shape: String, pixel: bool) -> ImageTexture:
	if source == null:
		return null
	var key = "%d/%s/%s/%s" % [source.get_instance_id(), dimensions, shape, pixel]
	if contour_texture_cache.has(key):
		return contour_texture_cache[key]
	if contour_texture_cache.size() >= 128:
		contour_texture_cache.clear()
	var image = source.get_image()
	var mask = Shapes.mask_texture(dimensions, shape, pixel).get_image()
	image.convert(Image.FORMAT_RGBA8)
	mask.convert(Image.FORMAT_RGBA8)
	if mask.get_size() != image.get_size():
		mask.resize(image.get_width(), image.get_height(), Image.INTERPOLATE_NEAREST if pixel else Image.INTERPOLATE_LANCZOS)
	var pixels = image.get_data()
	var mask_pixels = mask.get_data()
	for index in range(3, pixels.size(), 4):
		pixels[index] = roundi(float(pixels[index]) * float(mask_pixels[index]) / 255.0)
	var result = ImageTexture.create_from_image(Image.create_from_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, pixels))
	for metadata in source.get_meta_list():
		result.set_meta(metadata, source.get_meta(metadata))
	contour_texture_cache[key] = result
	return result

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
