extends RefCounted
## Seeded material surfaces and frame details rasterized locally at 2x resolution.

static var texture_cache: Dictionary = {}
const DETAILS = ["Style native", "Ornate", "Tech", "Weathered", "Clean"]
const MATERIALS = ["Style native", "Brushed metal", "Leather", "Stone", "Wood", "Glass", "Carbon fiber", "Parchment"]
const STYLE_MATERIALS = {"Military": "Brushed metal", "Fantasy": "Leather", "Horror": "Stone", "Modern": "Glass", "Sci-fi": "Carbon fiber", "Minimal": "Glass"}
const SURFACE_COLORS = {
	"Brushed metal": ["697984", "28353d", "101d26"],
	"Leather": ["70432d", "3f2920", "211916"],
	"Stone": ["606768", "353d40", "1c2428"],
	"Wood": ["805335", "503424", "2d211a"],
	"Glass": ["3c8798", "214b63", "0c2436"],
	"Carbon fiber": ["39414d", "202630", "111720"],
	"Parchment": ["9a7950", "685337", "3a3024"],
}

static func material_for(config: Dictionary) -> String:
	var material: String = config.get("art", {}).get("material", "Style native")
	if material == "Style native" or material not in MATERIALS:
		return STYLE_MATERIALS.get(config.style, "Brushed metal")
	return material

static func make_texture(config: Dictionary, dimensions: Vector2, element: String, variant: int) -> ImageTexture:
	var settings: Dictionary = config.get("art", {})
	var detail: String = settings.get("detail", "Style native")
	var seed_value: int = int(settings.get("seed", 0)) + element.hash() + variant * 7919
	var key = JSON.stringify([config.style, config.accent, config.get("panel", "121c22"), detail, material_for(config), settings.get("texture_scale", 1.0), settings.get("wear", 0.3), seed_value, dimensions.x, dimensions.y])
	if texture_cache.has(key):
		return texture_cache[key]
	if texture_cache.size() >= 192:
		texture_cache.clear()
	var svg = make_svg(config, dimensions, seed_value, detail)
	var image = Image.new()
	if image.load_svg_from_string(svg) != OK:
		return null
	var texture = ImageTexture.create_from_image(image)
	texture_cache[key] = texture
	return texture

static func make_svg(config: Dictionary, dimensions: Vector2, seed_value: int, detail: String) -> String:
	var w = int(dimensions.x)
	var h = int(dimensions.y)
	var accent = "#" + Color(config.accent).to_html(false)
	var settings: Dictionary = config.get("art", {})
	var material = material_for(config)
	var texture_scale = clampf(float(settings.get("texture_scale", 1.0)), 0.5, 2.0)
	var wear = clampf(float(settings.get("wear", 0.3)), 0.0, 1.0)
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	if detail == "Style native":
		detail = {"Fantasy": "Ornate", "Military": "Weathered", "Horror": "Weathered", "Sci-fi": "Tech", "Modern": "Tech", "Minimal": "Clean"}.get(config.style, "Clean")
	var parts: Array[String] = []
	parts.append('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">' % [w * 2, h * 2, w, h])
	parts.append('<defs><linearGradient id="shine"><stop stop-color="%s" stop-opacity=".2"/><stop offset=".5" stop-color="%s"/><stop offset="1" stop-color="%s" stop-opacity=".2"/></linearGradient></defs>' % [accent, accent, accent])
	var colors: Array = SURFACE_COLORS[material]
	parts.append('<defs><linearGradient id="surface" x1="0" y1="0" x2="0.35" y2="1"><stop stop-color="#%s" stop-opacity="%s"/><stop offset=".45" stop-color="#%s" stop-opacity="%s"/><stop offset="1" stop-color="#%s" stop-opacity="%s"/></linearGradient></defs>' % [colors[0], ".55" if material == "Glass" else "1", colors[1], ".35" if material == "Glass" else "1", colors[2], ".7" if material == "Glass" else "1"])
	var cut = 10 if detail in ["Tech", "Weathered"] else 3
	parts.append('<path d="M %d 1 H %d L %d %d V %d L %d %d H 1 V %d Z" fill="url(#surface)" stroke="%s" stroke-opacity=".7"/>' % [cut, w - cut, w - 1, cut, h - cut, w - cut, h - 1, cut, accent])
	var surface_rng = RandomNumberGenerator.new()
	surface_rng.seed = seed_value ^ 0x5f3759df
	_surface(parts, w, h, material, texture_scale, surface_rng)
	_wear_surface(parts, w, h, wear, surface_rng)
	parts.append('<path d="M 16 4 H %d M 16 %d H %d" fill="none" stroke="url(#shine)" stroke-width="1" opacity=".7"/>' % [w - 16, h - 4, w - 16])
	match detail:
		"Ornate":
			_ornament(parts, w, h, accent, rng)
		"Tech":
			_circuits(parts, w, h, accent, rng)
		"Weathered":
			_weather(parts, w, h, accent, rng)
		_:
			var inset = rng.randi_range(4, 8)
			parts.append('<rect x="%d" y="%d" width="%d" height="%d" rx="%d" fill="none" stroke="%s" opacity="%.2f"/>' % [inset, inset, w - inset * 2, h - inset * 2, rng.randi_range(4, 12), accent, rng.randf_range(.12, .3)])
	# A quiet inner surface keeps labels and bars readable on top of the artwork.
	parts.append('<rect x="13" y="12" width="%d" height="%d" rx="3" fill="#081015" opacity=".16"/>' % [w - 26, h - 24])
	parts.append('</svg>')
	return "".join(parts)

static func _surface(parts: Array[String], w: int, h: int, material: String, size: float, rng: RandomNumberGenerator) -> void:
	# All marks are inset from the silhouette, leaving its outer corners transparent.
	var area = (w - 28) * (h - 28)
	match material:
		"Brushed metal":
			for i in range(int((h - 24) * 2 / size)):
				var x = rng.randf_range(13, w * .4)
				var y = rng.randf_range(13, h - 13)
				parts.append('<path d="M %.2f %.2f H %.2f" stroke="%s" stroke-width="%.2f" opacity="%.2f"/>' % [x, y, rng.randf_range(w * .6, w - 13), "#cce6ef" if i % 3 else "#02070a", rng.randf_range(.2, .65) * size, rng.randf_range(.05, .22)])
			parts.append('<path d="M %d 12 L %d 12 L %d %d L %d %d Z" fill="#c6e8ef" opacity=".055"/>' % [w / 3, w / 2, w / 3, h - 12, w / 6, h - 12])
		"Leather":
			for i in range(int(area / (32 * size * size))):
				var x = rng.randf_range(15, w - 15)
				var y = rng.randf_range(15, h - 15)
				parts.append('<path d="M %.2f %.2f q %.2f -1 %.2f 0" fill="none" stroke="%s" stroke-width="%.2f" opacity="%.2f"/>' % [x, y, size, size * 2, "#ce9d6c" if i % 3 else "#130b08", size * .7, rng.randf_range(.12, .35)])
			# Individual stitches stay legible in narrow health and mana panels too.
			for x in range(14, w - 14, maxi(3, int(6 * size))):
				for y in [10, h - 10]:
					parts.append('<path d="M %d %d l 2 -1" stroke="#dfbb88" stroke-width="1" opacity=".55"/>' % [x, y])
		"Stone":
			for i in range(int(area / (190 * size * size))):
				var x = rng.randf_range(15, w - 28)
				var y = rng.randf_range(15, h - 25)
				var length = rng.randf_range(4, 14) * size
				parts.append('<path d="M %.1f %.1f l %.1f 1 l -2 %.1f Z" fill="%s" opacity="%.2f"/>' % [x, y, minf(length, w - 14 - x), minf(length * .5, h - 14 - y), "#b3beb9" if i % 2 else "#0d181c", rng.randf_range(.06, .23)])
			for i in range(5):
				var x = rng.randf_range(18, w - 50)
				var y = rng.randf_range(14, h - 24)
				parts.append('<path d="M %.1f %.1f l 12 2 l 6 -3 l 14 6 m -14 -6 l 3 9" fill="none" stroke="#081318" stroke-width="%.2f" opacity=".45"/>' % [x, y, size * .7])
		"Wood":
			for i in range(int((h - 28) / (1.7 * size))):
				var y = 14 + i * 1.7 * size
				var bend = rng.randf_range(-4, 4) * size
				parts.append('<path d="M 13 %.1f C %d %.1f %d %.1f %d %.1f" fill="none" stroke="%s" stroke-width="%.2f" opacity="%.2f"/>' % [y, w / 3, clampf(y + bend, 13, h - 13), w * 2 / 3, clampf(y - bend, 13, h - 13), w - 13, y, "#d8aa70" if i % 3 else "#1b100a", rng.randf_range(.35, 1) * size, rng.randf_range(.12, .32)])
			var knot_x = rng.randf_range(w * .25, w * .75)
			var knot_y = rng.randf_range(h * .35, h * .65)
			for i in range(1, 5):
				parts.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="none" stroke="#1b100a" stroke-width=".6" opacity=".35"/>' % [knot_x, knot_y, i * 4 * size, i * 1.2 * size])
		"Glass":
			parts.append('<rect x="7" y="7" width="%d" height="%d" rx="3" fill="none" stroke="#a4edff" stroke-opacity=".35"/>' % [w - 14, h - 14])
			for i in range(3):
				var x = rng.randf_range(16, w - 55)
				var width = rng.randf_range(4, 13) * size
				parts.append('<path d="M %.1f 12 h %.1f l -12 %d h -%.1f Z" fill="#d1f7ff" opacity="%.2f"/>' % [x + 12, width, h - 24, width, rng.randf_range(.035, .12)])
		"Carbon fiber":
			var step_size = maxi(3, int(6 * size))
			for y in range(13, h - 16, step_size):
				for x in range(13, w - 16, step_size):
					var horizontal = (x / step_size + y / step_size) % 2 == 0
					parts.append('<path d="M %d %d h %d v %d h -%d Z" fill="%s" opacity="%.2f"/>' % [x, y, mini(step_size - 1, w - 13 - x), mini(step_size - 1, h - 13 - y), mini(step_size - 1, w - 13 - x), "#667380" if horizontal else "#050a10", rng.randf_range(.18, .4)])
					parts.append('<path d="M %d %d l %d %d" stroke="#98a7b3" stroke-width=".5" opacity=".2"/>' % [x + 1, y + 1, step_size - 3 if horizontal else 0, 0 if horizontal else step_size - 3])
		"Parchment":
			for i in range(int(area / (90 * size * size))):
				var x = rng.randf_range(16, w - 16)
				var y = rng.randf_range(16, h - 16)
				parts.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s" opacity="%.2f"/>' % [x, y, rng.randf_range(1, 3) * size, size, "#e0c58b" if i % 2 else "#25170d", rng.randf_range(.05, .17)])
			for i in range(int(area / (130 * size))):
				var x = rng.randf_range(16, w - 24)
				var y = rng.randf_range(16, h - 16)
				parts.append('<path d="M %.1f %.1f l %.1f 1" stroke="#efd9a4" stroke-width=".35" opacity=".2"/>' % [x, y, 4 * size])

static func _wear_surface(parts: Array[String], w: int, h: int, amount: float, rng: RandomNumberGenerator) -> void:
	for i in range(int(60 * amount)):
		var x = rng.randf_range(14, w - 30)
		var y = rng.randf_range(5, 11) if i % 2 else rng.randf_range(h - 11, h - 5)
		parts.append('<path d="M %.1f %.1f l %.1f -1" stroke="%s" stroke-width="%.2f" opacity="%.2f"/>' % [x, y, rng.randf_range(2, 16), "#d5c4a1" if i % 3 else "#080c0d", rng.randf_range(.5, 1.5), rng.randf_range(.1, .4) * amount])
	for i in range(int(18 * amount)):
		var x = rng.randf_range(18, w - 32)
		var y = rng.randf_range(14, h - 16)
		parts.append('<path d="M %.1f %.1f l 12 -2" stroke="#c7d2cd" stroke-width=".5" opacity="%.2f"/>' % [x, y, amount * .2])

static func _ornament(parts: Array[String], w: int, h: int, accent: String, rng: RandomNumberGenerator) -> void:
	for x in [0, w]:
		for y in [0, h]:
			parts.append('<g transform="translate(%d %d) scale(%d %d)" fill="none" stroke="%s">' % [x, y, 1 if x == 0 else -1, 1 if y == 0 else -1, accent])
			parts.append('<path d="M 5 28 Q 18 28 16 15 Q 29 18 32 5 M 7 22 Q 10 11 22 7 M 9 31 Q 18 35 22 23 Q 33 23 35 11" opacity=".75"/>')
			parts.append('<path d="M 7 14 L 11 6 L 15 10 L 10 16 Z" fill="%s" opacity=".6"/></g>' % accent)
	var jewel = rng.randi_range(3, 5)
	parts.append('<path d="M %d 2 l %d 5 l -%d 5 l -%d -5 Z" fill="%s" opacity=".9"/>' % [w / 2, jewel, jewel, jewel, accent])
	for i in range(6):
		var x = rng.randi_range(42, maxi(43, w - 42))
		parts.append('<path d="M %d 6 l 2 3 l -2 3 l -2 -3 Z" fill="%s" opacity="%.2f"/>' % [x, accent, rng.randf_range(.2, .65)])
	for i in range(5):
		var x = w / 2 - 30 + i * 15
		parts.append('<path d="M %d %d l 3 -3 l 3 3 l -3 3 Z" fill="%s" opacity=".35"/>' % [x, h - 8, accent])

static func _circuits(parts: Array[String], w: int, h: int, accent: String, rng: RandomNumberGenerator) -> void:
	for side in [0, 1]:
		var x = 5 if side == 0 else w - 5
		var direction = 1 if side == 0 else -1
		parts.append('<path d="M %d 18 h %d v 10 h %d M %d %d h %d v -9 h %d" fill="none" stroke="%s" opacity=".65"/>' % [x, direction * 8, direction * 12, x, h - 16, direction * 8, direction * 16, accent])
		for i in range(3):
			var y = 10 + i * 5
			parts.append('<path d="M %d %d h %d" stroke="%s" stroke-width="2" opacity=".8"/>' % [w - 48 if side else 28, y, rng.randi_range(7, 15), accent])
	for i in range(4):
		var x = w / 2 + i * 9 - 18
		parts.append('<rect x="%d" y="%d" width="5" height="2" fill="%s" opacity=".5"/>' % [x, h - 9, accent])

static func _weather(parts: Array[String], w: int, h: int, accent: String, rng: RandomNumberGenerator) -> void:
	for x in [8, w - 8]:
		for y in [8, h - 8]:
			parts.append('<circle cx="%d" cy="%d" r="2.7" fill="#0a1011" stroke="%s" opacity=".7"/><path d="M %d %d h 3" stroke="%s" opacity=".6"/>' % [x, y, accent, x - 1, y, accent])
	for i in range(28):
		var x = rng.randf_range(12, w - 20)
		var y = rng.randf_range(4, h - 4)
		var length = rng.randf_range(3, 22)
		parts.append('<path d="M %.1f %.1f l %.1f -1" stroke="%s" stroke-width=".5" opacity="%.2f"/>' % [x, y, length, accent, rng.randf_range(.04, .17)])
	for i in range(6):
		parts.append('<path d="M %d %d l 4 -4" stroke="%s" opacity=".5"/>' % [w - 50 + i * 6, h - 6, accent])
