extends RefCounted
## Seeded geometry, with optional reviewed local PNG artwork from the AI workflow.
## Both styles export at 2x the requested logical size. Pixel artwork is snapped
## to a small palette and enlarged with nearest-neighbor interpolation.

const AIArt = preload("res://scripts/ai_art.gd")

const STYLES = ["Illustrated fantasy", "Medieval pixel"]
const MATERIALS = ["Wood", "Stone", "Parchment"]
const ORNAMENTS = ["Simple", "Balanced", "Rich"]
static var texture_cache: Dictionary = {}
static var pixel_color_cache: Dictionary = {}
static var pixel_cache_accent: String = ""

static func texture(config: Dictionary, dimensions: Vector2, component: String, kind: String = "panel", state: String = "normal") -> ImageTexture:
	var accepted_art: ImageTexture = AIArt.texture(config, dimensions, component, kind, state)
	if accepted_art != null:
		return accepted_art
	var kit: Dictionary = config.get("kit", {})
	var material: String = str(kit.get("material", "Wood"))
	if material not in MATERIALS:
		material = "Wood"
	var style: String = str(config.get("style", STYLES[0]))
	var accent: String = str(config.get("accent", "dcb461")).trim_prefix("#")
	var decorations: String = str(kit.get("ornaments", "Balanced"))
	var overrides: Dictionary = kit.get("component_seeds", {})
	var seed_value: int = int(kit.get("seed", 1)) + int(component.hash()) + int(overrides.get(component, 0)) * 7919
	var width: int = maxi(1, roundi(dimensions.x))
	var height: int = maxi(1, roundi(dimensions.y))
	var key: String = JSON.stringify([style, accent, material, decorations, seed_value, component, kind, state, width, height])
	if texture_cache.has(key):
		return texture_cache[key]
	if texture_cache.size() >= 384:
		texture_cache.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pixel: bool = style == STYLES[1]
	var svg: String = _svg(width, height, material, decorations, accent, kind, state, rng, pixel)
	var image := Image.new()
	if image.load_svg_from_string(svg) != OK:
		return null
	if pixel:
		_pixelize(image, width, height, material, accent, kind)
	var result := ImageTexture.create_from_image(image)
	result.set_meta("kit_art_role", kind)
	result.set_meta("kit_art_component", component)
	result.set_meta("kit_art_source", "procedural")
	texture_cache[key] = result
	return result

static func _svg(w: int, h: int, material: String, ornaments: String, accent: String, kind: String, state: String, rng: RandomNumberGenerator, pixel: bool) -> String:
	# SVG only describes local vector geometry; it never refers to external files.
	var density: float = 1.0 if not pixel else (1.0 if kind.begins_with("icon_") else 0.5)
	var output_w: int = w * 2 if not pixel else maxi(1, roundi(w * density))
	var output_h: int = h * 2 if not pixel else maxi(1, roundi(h * density))
	var parts: Array[String] = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">' % [output_w, output_h, w, h]]
	var palettes: Dictionary = {
		"Wood": ["8f5028", "5c301e", "301b17"],
		"Stone": ["697278", "3c474e", "222e36"],
		"Parchment": ["f1d599", "c9a66c", "9d7547"],
	}
	var colors: Array = palettes[material]
	var gold: String = "#" + Color(accent).to_html(false)
	var light: String = "#" + Color(accent).lightened(.4).to_html(false)
	var dark: String = "#" + Color(accent).darkened(.6).to_html(false)
	parts.append('<defs><linearGradient id="gold" x2="0" y2="1"><stop stop-color="%s"/><stop offset=".26" stop-color="%s"/><stop offset=".52" stop-color="%s"/><stop offset=".76" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>' % [light, gold, dark, gold, dark])
	parts.append('<linearGradient id="face" x1="0" y1="0" x2=".2" y2="1"><stop stop-color="#%s"/><stop offset=".48" stop-color="#%s"/><stop offset="1" stop-color="#%s"/></linearGradient>' % colors)
	parts.append('<linearGradient id="steel" x2="1" y2=".2"><stop stop-color="#465965"/><stop offset=".42" stop-color="#d9e5df"/><stop offset=".52" stop-color="#f7f3dc"/><stop offset=".56" stop-color="#80938d"/><stop offset="1" stop-color="#354751"/></linearGradient>')
	parts.append('<linearGradient id="red" x2="0" y2="1"><stop stop-color="#ffb187"/><stop offset=".25" stop-color="#d34f46"/><stop offset=".6" stop-color="#9b2637"/><stop offset="1" stop-color="#471c2c"/></linearGradient>')
	parts.append('<linearGradient id="blue" x2="0" y2="1"><stop stop-color="#b6f4f2"/><stop offset=".25" stop-color="#5fbbd6"/><stop offset=".6" stop-color="#2d659f"/><stop offset="1" stop-color="#233055"/></linearGradient></defs>')
	if kind.begins_with("icon_"):
		_icon(parts, w, h, kind.trim_prefix("icon_"), gold, light, dark, rng)
	elif kind in ["fill_health", "fill_mana"]:
		_fill(parts, w, h, kind, rng)
	else:
		_frame(parts, w, h, material, ornaments, gold, light, dark, kind, state, rng)
	parts.append('</svg>')
	return "".join(parts)

static func _outline(x: float, y: float, w: float, h: float, cut: float, banner: bool = false) -> String:
	if banner:
		return 'M %s %s H %s L %s %s L %s %s H %s L %s %s Z' % [x, y, x + w, x + w - cut, y + h * .5, x + w, y + h, x, x + cut, y + h * .5]
	return 'M %s %s H %s L %s %s V %s L %s %s H %s L %s %s V %s Z' % [x + cut, y, x + w - cut, x + w, y + cut, y + h - cut, x + w - cut, y + h, x + cut, x, y + h - cut, y + cut]

static func _frame(parts: Array[String], w: int, h: int, material: String, ornaments: String, gold: String, light: String, dark: String, kind: String, state: String, rng: RandomNumberGenerator) -> void:
	var small: bool = kind in ["bar_frame", "slot"]
	var trim: float = minf(minf(w, h) * .14, 10.0)
	if kind in ["button", "banner"]:
		trim = minf(trim, 7.0)
	if kind == "bar_frame":
		trim = minf(trim, 5.0)
	trim = maxf(1.0, trim)
	var cut: float = maxf(1, trim * (1.5 if kind == "panel" else .7))
	var banner: bool = kind == "banner"
	var edge: String = _outline(1, 1, w - 2, h - 3, cut, banner)
	var face: String = _outline(trim, trim, w - 2 * trim, h - 2 * trim - 1, maxf(1, cut - trim * .6), banner)
	parts.append('<path d="%s" fill="#0f141a" stroke="#080c10" stroke-width="2"/>' % edge)
	parts.append('<path d="%s" fill="url(#gold)" stroke="%s" stroke-width=".7"/>' % [_outline(2, 2, w - 4, h - 6, cut, banner), dark])
	parts.append('<path d="%s" fill="none" stroke="%s" stroke-width="1" opacity=".7"/>' % [_outline(3.5, 3.5, w - 7, h - 9, maxf(1, cut - 1), banner), light])
	parts.append('<path d="%s" fill="#211b1a" stroke="%s" stroke-width="1.5"/>' % [face, dark])
	parts.append('<path d="%s" fill="url(#face)" stroke="#100e14" stroke-width="1"/>' % [_outline(trim + 1, trim + 1, w - 2 * trim - 2, h - 2 * trim - 3, maxf(1, cut - trim * .6), banner)])
	parts.append('<defs><clipPath id="inside"><path d="%s"/></clipPath></defs><g clip-path="url(#inside)">' % face)
	_surface(parts, w, h, trim, material, rng)
	# Shallow inset on the top edge and a shadow below it create carved depth.
	parts.append('<path d="M %s %s H %s V %s" fill="none" stroke="#0b1015" stroke-opacity=".45" stroke-width="3"/>' % [trim + 1, trim + 2, w - trim - 1, h - trim])
	parts.append('<path d="M %s %s H %s" stroke="#fff1c4" stroke-opacity=".2"/>' % [trim + 2, h - trim - 2, w - trim - 2])
	if state == "hover":
		parts.append('<rect width="%d" height="%d" fill="%s" opacity=".18"/>' % [w, h, light])
	elif state == "pressed":
		parts.append('<rect width="%d" height="%d" fill="#080b12" opacity=".36"/><path d="M 0 %s H %d" stroke="#03070b" stroke-width="5" opacity=".55"/>' % [w, h, trim + 2, w])
	elif state == "disabled":
		parts.append('<rect width="%d" height="%d" fill="#555b60" opacity=".75"/>' % [w, h])
	parts.append('</g>')
	if state in ["hover", "focus"]:
		parts.append('<path d="%s" fill="none" stroke="%s" stroke-width="%s"/>' % [edge, light, "2" if state == "focus" else "1"])
	if ornaments != "Simple":
		_decorations(parts, w, h, trim, gold, light, dark, kind, ornaments == "Rich", rng)
	elif not small:
		for x in [trim * .6, w - trim * .6]:
			_rivet(parts, x, h * .5, maxf(1, trim * .22), light, dark)
	# This tiny maker's stamp changes even an otherwise plain frame per seed.
	var mark_x: float = rng.randf_range(w * .3, w * .7)
	parts.append('<path d="M %.2f %s l 2 -1 l 2 1 l -2 1 Z" fill="%s" opacity=".6"/>' % [mark_x, h - trim * .5 - 1, light])

static func _surface(parts: Array[String], w: int, h: int, trim: float, material: String, rng: RandomNumberGenerator) -> void:
	var x0: float = trim + 1
	var x1: float = w - trim - 1
	var y0: float = trim + 1
	var y1: float = h - trim - 2
	var area: float = maxf(1, (x1 - x0) * (y1 - y0))
	match material:
		"Wood":
			for i in range(maxi(3, int((y1 - y0) / 2.5))):
				var y: float = rng.randf_range(y0, y1)
				var wave: float = rng.randf_range(1, 5)
				parts.append('<path d="M %s %.2f C %.2f %.2f %.2f %.2f %s %.2f" fill="none" stroke="%s" stroke-width="%.2f" opacity="%.2f"/>' % [x0, y, w * .33, y - wave, w * .66, y + wave, x1, y, "#d9a15b" if i % 3 else "#211118", rng.randf_range(.45, 1.4), rng.randf_range(.08, .28)])
			if h > 120:
				for x in range(64, w - 30, 79):
					parts.append('<path d="M %d %s V %s" stroke="#1b1011" stroke-width="2" opacity=".42"/><path d="M %d %s V %s" stroke="#eab775" opacity=".12"/>' % [x, y0, y1, x + 2, y0, y1])
			var knot_x: float = rng.randf_range(w * .2, w * .8)
			var knot_y: float = rng.randf_range(y0, y1)
			for i in range(1, 4):
				parts.append('<ellipse cx="%.2f" cy="%.2f" rx="%d" ry="%s" fill="none" stroke="#251116" stroke-width=".7" opacity=".32"/>' % [knot_x, knot_y, i * 5, i * 1.6])
		"Stone":
			for i in range(mini(180, maxi(6, int(area / 190)))):
				var x: float = rng.randf_range(x0, x1)
				var y: float = rng.randf_range(y0, y1)
				parts.append('<path d="M %.2f %.2f l %.2f -2 l 3 4 l -5 2 Z" fill="%s" opacity="%.2f"/>' % [x, y, rng.randf_range(3, 10), "#adb7ae" if i % 2 else "#111f2a", rng.randf_range(.05, .21)])
			for i in range(3):
				parts.append('<path d="M %.2f %.2f l 6 7 l -3 8 l 12 6 m -12 -6 l -5 3" fill="none" stroke="#111d26" stroke-width="1.1" opacity=".5"/>' % [rng.randf_range(x0, x1), rng.randf_range(y0, y1)])
		_:
			for i in range(mini(230, maxi(8, int(area / 110)))):
				parts.append('<ellipse cx="%.2f" cy="%.2f" rx="%.2f" ry="%.2f" fill="%s" opacity="%.2f"/>' % [rng.randf_range(x0, x1), rng.randf_range(y0, y1), rng.randf_range(.4, 2.5), rng.randf_range(.2, 1), "#fff3cb" if i % 2 else "#6f452e", rng.randf_range(.07, .25)])
			parts.append('<path d="M %s %s H %s M %s %s H %s" stroke="#694526" stroke-width="4" opacity=".14"/>' % [x0, y0, x1, x0, y1, x1])

static func _rivet(parts: Array[String], x: float, y: float, size: float, light: String, dark: String) -> void:
	parts.append('<circle cx="%s" cy="%s" r="%s" fill="%s"/><circle cx="%s" cy="%s" r="%s" fill="url(#gold)" stroke="%s" stroke-width=".5"/><path d="M %s %s l %s -%s" stroke="%s" stroke-width=".7" opacity=".65"/>' % [x, y + .7, size + .6, dark, x, y, size, light, x - size * .5, y + size * .3, size, size * .6, dark])

static func _decorations(parts: Array[String], w: int, h: int, trim: float, gold: String, light: String, dark: String, kind: String, rich: bool, rng: RandomNumberGenerator) -> void:
	if kind == "bar_frame":
		for x in [trim * .7, w - trim * .7]:
			_rivet(parts, x, h * .5, maxf(1, trim * .22), light, dark)
		return
	if kind in ["button", "banner"]:
		var jewel_y: float = h * .5
		var gem_color: String = ["#ca6550", "#4eaa98", "#668bb6"][rng.randi_range(0, 2)]
		for x in [trim * .9, w - trim * .9]:
			parts.append('<path d="M %s %s l 4 5 l -4 5 l -4 -5 Z" fill="%s" stroke="%s" stroke-width="1.5"/><path d="M %s %s l 2 3" stroke="#fff4c9" stroke-opacity=".55"/>' % [x, jewel_y - 5, gem_color, gold, x - 1, jewel_y - 3])
		if rich:
			for side in [1, -1]:
				var x: float = 14 if side == 1 else w - 14
				parts.append('<path d="M %s %s q %s -6 %s -3 m %s 0 q %s 6 %s 3" fill="none" stroke="%s" stroke-width="1" opacity=".85"/>' % [x, jewel_y, side * 4, side * 8, side * 1, side * 4, side * 8, gold])
		return
	var corner: float = minf(minf(w, h) * .24, 26.0)
	for x in [0, w]:
		for y in [0, h]:
			parts.append('<g transform="translate(%d %d) scale(%d %d)">' % [x, y, 1 if x == 0 else -1, 1 if y == 0 else -1])
			parts.append('<path d="M 3 %s L 3 %s L %s 3 L %s 3 Q %s %s 3 %s Z" fill="url(#gold)" stroke="%s" stroke-width=".7"/>' % [corner * 1.2, trim, trim, corner * 1.2, corner * .8, corner * .8, corner * 1.2, dark])
			parts.append('<path d="M 6 %s Q %s %s %s 6 M 8 %s Q %s %s %s 8" fill="none" stroke="%s" stroke-width=".8"/>' % [corner * .9, corner * .65, corner * .65, corner * .9, corner * .65, corner * .45, corner * .45, corner * .65, light])
			_rivet(parts, trim * .7, trim * .7, maxf(1, trim * .2), light, dark)
			parts.append('</g>')
	if rich and w > 120:
		var cx: float = w * .5
		var gem: String = ["#ab4648", "#448e83", "#657fa7"][rng.randi_range(0, 2)]
		for y in [trim * .6, h - trim * .6 - 1]:
			parts.append('<path d="M %s %s l 9 -4 l 9 4 l -9 4 Z M %s %s l -9 -4 l -9 4 l 9 4 Z" fill="none" stroke="%s" stroke-width="1.2"/><path d="M %s %s l 5 5 l -5 5 l -5 -5 Z" fill="%s" stroke="%s"/>' % [cx + 4, y, cx - 4, y, gold, cx, y - 5, gem, light])
			parts.append('<path d="M %s %s h 14 m 48 0 h 14" stroke="%s" opacity=".8"/>' % [cx - 38, y, gold])

static func _fill(parts: Array[String], w: int, h: int, kind: String, rng: RandomNumberGenerator) -> void:
	var fill: String = "red" if kind == "fill_health" else "blue"
	parts.append('<path d="%s" fill="url(#%s)" stroke="#191b2a" stroke-width="1"/>' % [_outline(1, 1, w - 2, h - 2, minf(h * .25, 4)), fill])
	parts.append('<path d="M 4 3 H %d" stroke="#fff3d1" opacity=".55"/><path d="M 4 %d H %d" stroke="#1b192c" opacity=".5"/>' % [w - 4, h - 3, w - 4])
	for i in range(maxi(3, int(w / 21))):
		var x: float = rng.randf_range(5, maxf(6, w - 7))
		parts.append('<path d="M %.2f 3 l -3 %d" stroke="#fff5cf" stroke-width="%.2f" opacity="%.2f"/>' % [x, maxi(1, h - 6), rng.randf_range(.5, 2.5), rng.randf_range(.05, .19)])

static func _icon(parts: Array[String], w: int, h: int, name: String, gold: String, light: String, dark: String, rng: RandomNumberGenerator) -> void:
	parts.append('<g transform="scale(%s %s)" stroke-linejoin="round" stroke-linecap="round">' % [w / 64.0, h / 64.0])
	var line: String = 'stroke="#211a20" stroke-width="2.5"'
	match name:
		"sword":
			parts.append('<path d="M 18 46 L 42 7 L 56 5 L 55 19 L 28 50 Z" fill="url(#steel)" %s/><path d="M 23 47 L 51 11" stroke="#fff5d1" stroke-width="1.4"/><path d="M 12 38 L 36 52 L 32 57 L 9 43 Z" fill="url(#gold)" %s/><path d="M 17 47 L 10 58 L 5 55 L 12 43 Z" fill="#714328" %s/><path d="M 5 53 l 7 5 l -4 4 l -7 -4 Z" fill="url(#gold)" %s/>' % [line, line, line, line])
		"shield":
			parts.append('<path d="M 32 4 Q 45 11 57 11 L 54 37 Q 48 52 32 60 Q 16 52 10 37 L 7 11 Q 19 11 32 4 Z" fill="url(#gold)" %s/><path d="M 32 11 L 49 17 L 47 35 Q 43 44 32 51 Q 21 44 17 35 L 15 17 Z" fill="#365b61" stroke="%s" stroke-width="2"/><path d="M 32 16 V 44 M 23 29 H 41" stroke="%s" stroke-width="5"/><path d="M 32 11 V 51" stroke="#fff6ca" opacity=".2"/>' % [line, dark, gold])
		"potion":
			parts.append('<path d="M 24 6 H 40 V 24 Q 54 32 54 45 Q 54 59 32 59 Q 10 59 10 45 Q 10 32 24 24 Z" fill="#9cb8b0" %s/><path d="M 18 36 Q 32 31 47 36 Q 58 54 32 54 Q 6 54 18 36 Z" fill="url(#red)"/><path d="M 24 7 H 40 V 16 H 24 Z" fill="#80522f" %s/><path d="M 22 18 H 42" stroke="%s" stroke-width="5"/><path d="M 21 29 Q 13 39 17 45" fill="none" stroke="#f2f5d8" stroke-width="3" opacity=".7"/><circle cx="40" cy="43" r="3" fill="#ffe5c2" opacity=".5"/>' % [line, line, gold])
		"heart":
			parts.append('<path d="M 32 56 C 22 47 4 34 6 20 C 8 6 26 4 32 18 C 38 4 56 6 58 20 C 60 34 42 47 32 56 Z" fill="url(#red)" %s/><path d="M 13 23 Q 13 13 23 14" fill="none" stroke="#ffdab4" stroke-width="3" opacity=".7"/>' % line)
		"mana":
			parts.append('<path d="M 32 4 L 52 23 L 46 48 L 32 60 L 18 48 L 12 23 Z" fill="url(#blue)" %s/><path d="M 32 4 L 27 24 L 18 48 M 27 24 L 52 23 M 27 24 L 32 60" fill="none" stroke="#b9e7e3" stroke-width="1.5" opacity=".65"/><path d="M 32 4 L 52 23 L 42 22 Z" fill="#e6fff1" opacity=".55"/>' % line)
		"gear":
			parts.append('<path d="M 26 5 H 38 L 40 14 L 47 10 L 55 18 L 50 26 L 59 27 V 38 L 50 40 L 54 47 L 46 55 L 38 50 L 37 59 H 26 L 24 50 L 17 54 L 9 46 L 14 38 L 5 37 V 26 L 14 24 L 10 17 L 18 9 L 26 14 Z" fill="url(#gold)" %s/><circle cx="32" cy="32" r="15" fill="#574134" stroke="%s" stroke-width="2"/><circle cx="32" cy="32" r="8" fill="#1e2931" stroke="%s" stroke-width="2"/>' % [line, light, gold])
		"bag":
			parts.append('<path d="M 23 6 Q 32 12 41 6 L 39 21 Q 55 33 55 49 Q 54 60 32 59 Q 10 60 9 49 Q 9 33 25 21 Z" fill="url(#face)" %s/><path d="M 22 22 Q 32 27 42 22" fill="none" stroke="%s" stroke-width="4"/><path d="M 24 12 L 28 21 M 37 12 L 35 21 M 18 35 Q 12 45 18 51" fill="none" stroke="#f2cd8e" stroke-width="2" opacity=".5"/><circle cx="33" cy="43" r="8" fill="url(#gold)" stroke="%s"/><path d="M 33 37 V 49 M 36 39 H 31 Q 28 42 34 44 Q 38 47 30 47" fill="none" stroke="%s"/>' % [line, gold, dark, dark])
		"arrow":
			parts.append('<path d="M 5 26 H 36 V 12 L 59 32 L 36 52 V 38 H 5 Z" fill="url(#gold)" %s/><path d="M 9 29 H 39 V 20 L 52 32" fill="none" stroke="%s" stroke-width="2"/>' % [line, light])
		"star":
			parts.append('<path d="M 32 3 L 41 22 L 62 25 L 46 40 L 50 61 L 32 51 L 14 61 L 18 40 L 2 25 L 23 22 Z" fill="url(#gold)" %s/><path d="M 32 3 V 34 L 2 25 M 32 34 L 50 61 M 32 34 L 62 25" fill="none" stroke="#fff5cc" opacity=".35"/>' % line)
		"coin":
			parts.append('<ellipse cx="33" cy="34" rx="25" ry="27" fill="%s" %s/><ellipse cx="30" cy="30" rx="25" ry="27" fill="url(#gold)" %s/><ellipse cx="30" cy="30" rx="18" ry="20" fill="none" stroke="%s" stroke-width="2"/><path d="M 30 15 L 40 30 L 30 45 L 20 30 Z" fill="%s" stroke="%s"/>' % [dark, line, line, dark, gold, light])
		"scroll":
			parts.append('<path d="M 15 8 H 48 L 47 48 Q 47 57 38 57 H 8 Q 17 53 15 45 Z" fill="#e3c38a" %s/><path d="M 15 8 Q 4 6 6 17 H 17 M 38 57 Q 31 51 37 46 H 55 Q 60 57 48 57 Z" fill="#b88d54" %s/><path d="M 22 20 H 40 M 22 27 H 38 M 22 34 H 40" stroke="#765033" stroke-width="2" opacity=".7"/>' % [line, line])
		"close":
			parts.append('<path d="M 16 7 L 32 23 L 48 7 L 57 16 L 41 32 L 57 48 L 48 57 L 32 41 L 16 57 L 7 48 L 23 32 L 7 16 Z" fill="url(#gold)" %s/><path d="M 16 12 L 32 28 L 48 12 M 12 48 L 28 32" stroke="%s" fill="none" stroke-width="2"/>' % [line, light])
		_:
			parts.append('<circle cx="32" cy="32" r="25" fill="url(#gold)" %s/>' % line)
	# A seeded glint varies an individual icon without changing its meaning.
	var glint_x: float = rng.randf_range(22, 42)
	var glint_y: float = rng.randf_range(22, 40)
	parts.append('<path d="M %.2f %.2f h 3 m -1.5 -1.5 v 3" stroke="#fff5d5" opacity=".78" stroke-width="1.3"/></g>' % [glint_x, glint_y])

static func _pixelize(image: Image, width: int, height: int, material: String, accent: String, kind: String) -> void:
	var palette: Array[Color] = [Color("151921"), Color("302029"), Color("513229"), Color("795034"), Color("a37643"), Color("d1a465"), Color("f2d699"), Color("fff1c5"), Color("283640"), Color("465762"), Color("738889"), Color("bdc8b5"), Color("6d2738"), Color("ab3b47"), Color("dc705a"), Color("ffb187"), Color("263954"), Color("365d88"), Color("559cb9"), Color("a9e2dc"), Color("396158"), Color("5c9680")]
	var accent_color := Color(accent)
	palette.append(accent_color)
	palette.append(accent_color.lightened(.35))
	palette.append(accent_color.darkened(.55))
	if pixel_cache_accent != accent or pixel_color_cache.size() > 65536:
		pixel_color_cache.clear()
		pixel_cache_accent = accent
	# Alpha is binary and every painted pixel belongs to the same compact palette.
	# Quantization happens before nearest scaling, so there is no antialiased edge.
	# SVG rasterization returns RGBA8. Cache the exact nearest result for each RGB
	# triplet: this preserves every pixel while avoiding a palette scan for every
	# repeated grain color, gradient step, and button state across the whole kit.
	image.convert(Image.FORMAT_RGBA8)
	var pixels: PackedByteArray = image.get_data()
	for offset in range(0, pixels.size(), 4):
		if pixels[offset + 3] < 128:
			# Color.TRANSPARENT is transparent white in Godot. Preserve its hidden
			# RGB values as well, keeping generated PNGs byte-for-byte identical.
			pixels[offset] = 255
			pixels[offset + 1] = 255
			pixels[offset + 2] = 255
			pixels[offset + 3] = 0
			continue
		var rgb: int = (int(pixels[offset]) << 16) | (int(pixels[offset + 1]) << 8) | int(pixels[offset + 2])
		var chosen: int
		if pixel_color_cache.has(rgb):
			chosen = pixel_color_cache[rgb]
		else:
			var c := Color(pixels[offset] / 255.0, pixels[offset + 1] / 255.0, pixels[offset + 2] / 255.0)
			var nearest: Color = palette[0]
			var best: float = INF
			for candidate in palette:
				var distance: float = (c.r - candidate.r) ** 2 + (c.g - candidate.g) ** 2 + (c.b - candidate.b) ** 2
				if distance < best:
					best = distance
					nearest = candidate
			chosen = nearest.to_rgba32()
			pixel_color_cache[rgb] = chosen
		pixels[offset] = (chosen >> 24) & 255
		pixels[offset + 1] = (chosen >> 16) & 255
		pixels[offset + 2] = (chosen >> 8) & 255
		pixels[offset + 3] = 255
	image.set_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, pixels)
	image.resize(width * 2, height * 2, Image.INTERPOLATE_NEAREST)
