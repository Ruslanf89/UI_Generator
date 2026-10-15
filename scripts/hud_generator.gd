extends RefCounted
## Creates native, editable Godot controls. Generated scenes depend on no scripts.

const GENRES = ["FPS", "RPG", "RTS", "Racing", "Survival", "Platformer"]
const STYLES = ["Military", "Fantasy", "Modern", "Horror", "Sci-fi", "Minimal"]
const COMPONENTS = {
	"health": "Health bar", "mana": "Mana bar", "armor": "Armor bar",
	"minimap": "Minimap", "weapon": "Weapon & ammo", "crosshair": "Crosshair",
	"abilities": "Ability slots", "objective": "Objective tracker", "speed": "Speedometer",
	"lap": "Lap counter", "resources": "Resources", "squad": "Squad / selection",
}
const DEFAULTS = {
	"FPS": ["health", "armor", "minimap", "weapon", "crosshair", "objective"],
	"RPG": ["health", "mana", "minimap", "abilities", "objective"],
	"RTS": ["minimap", "resources", "abilities", "squad", "objective"],
	"Racing": ["speed", "lap", "minimap", "objective"],
	"Survival": ["health", "weapon", "crosshair", "objective"],
	"Platformer": ["health", "resources", "abilities", "objective"],
}
const PALETTES = {
	"Military": {"accent": "b9d995", "panel": "141d19", "round": 2, "names": ["Vanguard", "Recon", "Sentinel"]},
	"Fantasy": {"accent": "edc483", "panel": "211d29", "round": 12, "names": ["Arcanist", "Warden", "Relic"]},
	"Modern": {"accent": "8de3ce", "panel": "122027", "round": 8, "names": ["Horizon", "Pulse", "Atlas"]},
	"Horror": {"accent": "ed7e85", "panel": "24171c", "round": 1, "names": ["Aftermath", "Last Light", "Dread"]},
	"Sci-fi": {"accent": "86caff", "panel": "111e31", "round": 4, "names": ["Orbital", "Nexus", "Vector"]},
	"Minimal": {"accent": "d9d4f5", "panel": "1d1d28", "round": 16, "names": ["Quiet", "Essential", "Outline"]},
}
const LAYOUTS = ["Balanced", "Compact", "Cinematic"]
const CANVAS = Vector2(1280, 720)

static func make_config(genre: String = "FPS", style: String = "Military") -> Dictionary:
	return {"genre": genre, "style": style, "components": DEFAULTS[genre].duplicate(),
		"accent": PALETTES[style].accent, "scale": 1.0, "health": 78.0, "mana": 62.0,
		"resolution": Vector2i(1920, 1080)}

static func panel_style(bg: Color, border: Color, radius: int = 4, width: int = 1) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	return box

static func make_theme(config: Dictionary, variant: int) -> Theme:
	var palette: Dictionary = PALETTES[config.style]
	var accent = Color(config.accent)
	var bg = Color(palette.panel)
	bg.a = 0.94 if variant != 2 else 0.80
	var result = Theme.new()
	result.default_font_size = 17
	result.set_color("font_color", "Label", Color("f0f3ed"))
	result.set_stylebox("panel", "Panel", panel_style(bg, Color(accent, 0.32), palette.round + variant * 2))
	result.set_stylebox("background", "ProgressBar", panel_style(Color(accent, 0.12), Color.TRANSPARENT, palette.round))
	result.set_stylebox("fill", "ProgressBar", panel_style(accent, Color.TRANSPARENT, palette.round, 0))
	return result

static func label_at(parent: Node, node_name: String, value: String, rect: Rect2, font_size: int = 17, color: Color = Color("f0f3ed")) -> Label:
	var label = Label.new()
	label.name = node_name
	label.text = value
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

static func block(parent: Node, node_name: String, rect: Rect2, color: Color) -> ColorRect:
	var shape = ColorRect.new()
	shape.name = node_name
	shape.position = rect.position
	shape.size = rect.size
	shape.color = color
	shape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shape)
	return shape

static func component(root: Control, node_name: String, at: Vector2, dimensions: Vector2, config: Dictionary, variant: int) -> Panel:
	var result = Panel.new()
	result.name = node_name
	var factor = float(config.scale)
	result.size = dimensions
	result.scale = Vector2.ONE * factor
	# Grow toward the canvas center, preserving the outer safe area.
	if at.x > 850:
		at.x -= dimensions.x * (factor - 1.0)
	elif at.x > 350:
		at.x -= dimensions.x * (factor - 1.0) * 0.5
	if at.y > 400:
		at.y -= dimensions.y * (factor - 1.0)
	result.position = at
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(result)
	if variant == 0:
		block(result, "AccentEdge", Rect2(0, 12, 3, dimensions.y - 24), Color(config.accent))
	return result

static func build(config: Dictionary, variant: int = 0) -> Control:
	var root = Control.new()
	root.name = "HUD"
	root.size = CANVAS
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = make_theme(config, variant)
	root.set_meta("generator", "UI Forge")
	root.set_meta("genre", config.genre)
	root.set_meta("style", config.style)
	root.set_meta("layout", LAYOUTS[variant])
	var accent = Color(config.accent)
	var muted = Color("a3b3b3")
	var selected: Array = config.components
	var stat_index = 0
	var stat_count = 0
	for key in ["health", "mana", "armor"]:
		if key in selected:
			stat_count += 1
	for key in ["health", "mana", "armor"]:
		if key not in selected:
			continue
		var y: float = 680 - (stat_count - stat_index) * 76.0
		if variant == 1:
			y = 40 + stat_index * 76.0
		var x: float = 960 if variant == 2 else 40
		var panel = component(root, key.capitalize(), Vector2(x, y), Vector2(280, 64), config, variant)
		var value: float = config.get(key, 100.0)
		label_at(panel, "Title", key.to_upper(), Rect2(16, 7, 180, 24), 14, muted)
		var amount = label_at(panel, "Amount", "%d / 100" % value, Rect2(175, 7, 88, 24), 15)
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var bar = ProgressBar.new()
		bar.name = "Value"
		bar.position = Vector2(16, 39)
		bar.size = Vector2(248, 8)
		bar.value = value
		bar.show_percentage = false
		bar.add_theme_font_size_override("font_size", 1)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if key == "mana":
			bar.add_theme_stylebox_override("fill", panel_style(Color("8eafff"), Color.TRANSPARENT, 3, 0))
		elif key == "armor":
			bar.add_theme_stylebox_override("fill", panel_style(accent.lightened(0.3), Color.TRANSPARENT, 3, 0))
		panel.add_child(bar)
		stat_index += 1
	if "minimap" in selected:
		var map = component(root, "Minimap", Vector2(1040, 40), Vector2(200, 200), config, variant)
		label_at(map, "Title", "N   /   SECTOR 07", Rect2(15, 8, 180, 24), 12, muted)
		var content = Control.new()
		content.name = "MapContent"
		content.position = Vector2(12, 40)
		content.size = Vector2(176, 145)
		content.clip_contents = true
		map.add_child(content)
		for i in range(5):
			block(content, "Road%d" % i, Rect2(i * 43 - 10, 0, 5, 145), Color(accent, 0.12))
			block(content, "Lane%d" % i, Rect2(0, i * 37, 176, 4), Color(accent, 0.12))
		for i in range(6):
			block(content, "Building%d" % i, Rect2(12 + (i % 3) * 54, 12 + (i / 3) * 66, 29, 36), Color(accent, 0.17))
		var player = block(content, "Player", Rect2(83, 66, 10, 10), accent)
		player.pivot_offset = Vector2(5, 5)
		player.rotation = PI / 4
		block(content, "ObjectiveMarker", Rect2(140, 22, 7, 7), Color("e5be78"))
	if "weapon" in selected:
		var weapon = component(root, "Weapon", Vector2(40 if variant == 2 else 920, 570), Vector2(320, 110), config, variant)
		label_at(weapon, "Title", "01 / CARBINE", Rect2(18, 10, 280, 24), 14, muted)
		label_at(weapon, "Ammo", "28", Rect2(18, 30, 100, 58), 42, accent)
		label_at(weapon, "Reserve", "/ 120", Rect2(93, 48, 100, 30), 21, muted)
		label_at(weapon, "Mode", "AUTO", Rect2(233, 57, 70, 26), 14)
		block(weapon, "WeaponSilhouette", Rect2(207, 29, 76, 7), accent)
		block(weapon, "Grip", Rect2(224, 36, 9, 13), accent)
		block(weapon, "Magazine", Rect2(249, 36, 13, 10), Color(accent, 0.55))
	if "crosshair" in selected:
		var crosshair = Control.new()
		crosshair.name = "Crosshair"
		crosshair.position = CANVAS / 2 - Vector2(16, 16)
		crosshair.size = Vector2(32, 32)
		crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(crosshair)
		for rect in [Rect2(15, 0, 2, 9), Rect2(15, 23, 2, 9), Rect2(0, 15, 9, 2), Rect2(23, 15, 9, 2)]:
			block(crosshair, "Reticle", rect, accent)
	if "abilities" in selected:
		var abilities = component(root, "Abilities", Vector2(440, 605), Vector2(400, 75), config, variant)
		for i in range(4):
			var slot = Panel.new()
			slot.name = "Slot%d" % (i + 1)
			slot.position = Vector2(12 + i * 96, 10)
			slot.size = Vector2(88, 55)
			abilities.add_child(slot)
			label_at(slot, "Key", ["Q", "E", "R", "F"][i], Rect2(10, 3, 22, 24), 13, muted)
			label_at(slot, "Ability", ["DASH", "WARD", "PULSE", "ULT"][i], Rect2(10, 26, 70, 22), 13, accent)
	if "objective" in selected:
		var objective = component(root, "Objective", Vector2(450, 40), Vector2(380, 78), config, variant)
		label_at(objective, "Title", "CURRENT OBJECTIVE", Rect2(18, 10, 345, 24), 12, accent)
		var title: String = {"Racing": "Reach the next checkpoint", "RTS": "Secure the eastern outpost", "RPG": "Find the ancient sanctuary"}.get(config.genre, "Reach the extraction point")
		label_at(objective, "Description", title, Rect2(18, 34, 345, 30), 18)
	if "speed" in selected:
		var speed = component(root, "Speed", Vector2(530, 440), Vector2(220, 130), config, variant)
		label_at(speed, "Value", "184", Rect2(18, 12, 175, 67), 52, accent)
		label_at(speed, "Unit", "KM/H     /     GEAR  4", Rect2(20, 89, 185, 24), 13, muted)
	if "lap" in selected:
		var lap = component(root, "Lap", Vector2(1040, 270), Vector2(200, 75), config, variant)
		label_at(lap, "Title", "LAP   02 / 03", Rect2(15, 10, 175, 24), 14, accent)
		label_at(lap, "Time", "01:24.680", Rect2(15, 35, 175, 28), 23)
	if "resources" in selected:
		var resources = component(root, "Resources", Vector2(450, 140), Vector2(380, 58), config, variant)
		label_at(resources, "Values", "GOLD  1,240    /    ENERGY  85", Rect2(18, 16, 350, 26), 16, accent)
	if "squad" in selected:
		var squad = component(root, "Squad", Vector2(40, 400 if variant == 1 else 40), Vector2(280, 110), config, variant)
		label_at(squad, "Title", "SQUAD / 03 ACTIVE", Rect2(16, 10, 250, 22), 13, muted)
		for i in range(3):
			block(squad, "Unit%d" % i, Rect2(16 + i * 86, 43, 70, 3), accent)
			label_at(squad, "UnitName%d" % i, ["SCOUT", "MEDIC", "HEAVY"][i], Rect2(16 + i * 86, 58, 76, 24), 12)
	assign_owners(root, root)
	return root

static func assign_owners(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		assign_owners(child, root)
