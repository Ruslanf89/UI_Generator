extends RefCounted
## Seeded SVG artwork rasterized locally. No remote service or credentials.

static var texture_cache: Dictionary = {}
const DETAILS = ["Style native", "Ornate", "Tech", "Weathered"]

static func make_texture(config: Dictionary, dimensions: Vector2, element: String, variant: int) -> ImageTexture:
	var settings: Dictionary = config.get("art", {})
	var detail: String = settings.get("detail", "Style native")
	var seed_value: int = int(settings.get("seed", 0)) + element.hash() + variant * 7919
	var key = "%s/%s/%s/%d/%d/%d" % [config.style, config.accent, detail, seed_value, dimensions.x, dimensions.y]
	if texture_cache.has(key):
		return texture_cache[key]
	if texture_cache.size() >= 128:
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
	var panel = "#" + str(config.get("panel", "121c22"))
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	if detail == "Style native":
		detail = {"Fantasy": "Ornate", "Military": "Weathered", "Horror": "Weathered", "Sci-fi": "Tech", "Modern": "Tech", "Minimal": "Clean"}.get(config.style, "Clean")
	var parts: Array[String] = []
	parts.append('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">' % [w * 2, h * 2, w, h])
	parts.append('<defs><linearGradient id="metal" x2="0.2" y2="1"><stop stop-color="%s" stop-opacity=".14"/><stop offset=".4" stop-color="%s" stop-opacity=".7"/><stop offset="1" stop-color="#03090c" stop-opacity=".9"/></linearGradient><linearGradient id="shine"><stop stop-color="%s" stop-opacity=".2"/><stop offset=".5" stop-color="%s"/><stop offset="1" stop-color="%s" stop-opacity=".2"/></linearGradient></defs>' % [accent, panel, accent, accent, accent])
	var cut = 10 if detail in ["Tech", "Weathered"] else 3
	parts.append('<path d="M %d 1 H %d L %d %d V %d L %d %d H 1 V %d Z" fill="url(#metal)" stroke="%s" stroke-opacity=".7"/>' % [cut, w - cut, w - 1, cut, h - cut, w - cut, h - 1, cut, accent])
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
