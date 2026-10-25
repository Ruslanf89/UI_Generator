extends RefCounted
## Seeded geometry, with optional reviewed local PNG artwork from the AI workflow.
## Both styles export at 2x the requested logical size. Pixel artwork is snapped
## to a small palette and enlarged with nearest-neighbor interpolation.

const AIArt = preload("res://scripts/ai_art.gd")
const Design = preload("res://scripts/kit_design.gd")
const Frames = preload("res://scripts/kit_frame_art.gd")
const Icons = preload("res://scripts/kit_icon_art.gd")
const Motifs = preload("res://scripts/kit_motif_art.gd")
const Shapes = preload("res://scripts/kit_shapes.gd")

const STYLES = ["Illustrated fantasy", "Medieval pixel", "Sculpted fantasy"]
const MATERIALS = ["Wood", "Stone", "Parchment"]
const ORNAMENTS = ["Simple", "Balanced", "Rich"]
static var texture_cache: Dictionary = {}
static var pixel_color_cache: Dictionary = {}
static var pixel_cache_accent: String = ""

static func texture(config: Dictionary, dimensions: Vector2, component: String, kind: String = "panel", state: String = "normal") -> ImageTexture:
	var recipe: Dictionary = Design.recipe(config, component, kind)
	var role: String = art_role(kind)
	var accepted_art: ImageTexture = AIArt.texture(config, dimensions, component, role, state)
	if accepted_art != null:
		if kind in ["map_frame", "stat_frame", "reservoir_health", "reservoir_mana", "reservoir_empty"]:
			return _adapt_accepted(accepted_art, dimensions, component, kind, recipe, state)
		return accepted_art
	var kit: Dictionary = config.get("kit", {})
	var material: String = str(kit.get("material", "Wood"))
	if material not in MATERIALS:
		material = "Wood"
	var style: String = str(config.get("style", STYLES[0]))
	var accent: String = str(config.get("accent", "dcb461")).trim_prefix("#")
	var decorations: String = str(kit.get("ornaments", "Balanced"))
	var seed_value: int = int(recipe.component_seed)
	var width: int = maxi(1, roundi(dimensions.x))
	var height: int = maxi(1, roundi(dimensions.y))
	var key: String = JSON.stringify([style, accent, material, decorations, recipe, component, kind, state, width, height])
	if texture_cache.has(key):
		return texture_cache[key]
	if texture_cache.size() >= 384:
		texture_cache.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pixel: bool = style == STYLES[1]
	var svg: String = _svg(width, height, material, decorations, accent, kind, state, rng, pixel, recipe)
	var image := Image.new()
	if image.load_svg_from_string(svg) != OK:
		return null
	Motifs.compose(image, dimensions, kind, recipe, decorations, state)
	_apply_role_mask(image, dimensions, kind, recipe)
	if pixel:
		_pixelize(image, width, height, material, accent, kind, recipe)
	var result := ImageTexture.create_from_image(image)
	result.set_meta("kit_art_role", role)
	result.set_meta("kit_art_kind", kind)
	result.set_meta("kit_art_component", component)
	result.set_meta("kit_art_source", "procedural")
	result.set_meta("kit_art_family", recipe.family)
	result.set_meta("kit_art_silhouette", recipe.silhouette)
	result.set_meta("kit_art_motif", recipe.get("motif", "griffin"))
	result.set_meta("kit_art_rendering", recipe.get("rendering", "painted"))
	texture_cache[key] = result
	return result

static func art_role(kind: String) -> String:
	return {"map_frame": "panel", "stat_frame": "panel", "reservoir_empty": "bar_frame", "reservoir_health": "fill_health", "reservoir_mana": "fill_mana"}.get(kind, kind)

static func _adapt_accepted(source: ImageTexture, dimensions: Vector2, component: String, kind: String, recipe: Dictionary, state: String) -> ImageTexture:
	var key: String = JSON.stringify(["accepted", source.get_instance_id(), dimensions, component, kind, recipe, state])
	if texture_cache.has(key):
		return texture_cache[key]
	if texture_cache.size() >= 384:
		texture_cache.clear()
	var image: Image = source.get_image()
	_apply_role_mask(image, dimensions, kind, recipe, true)
	var result := ImageTexture.create_from_image(image)
	for meta in source.get_meta_list():
		result.set_meta(meta, source.get_meta(meta))
	result.set_meta("kit_art_role", art_role(kind))
	result.set_meta("kit_art_kind", kind)
	texture_cache[key] = result
	return result

static func _apply_role_mask(image: Image, dimensions: Vector2, kind: String, recipe: Dictionary, accepted: bool = false) -> void:
	var shape: String
	var rect: Rect2
	var outside: bool = false
	if kind == "map_frame":
		shape = str(recipe.get("map_shape", "circle"))
		rect = Shapes.map_rect(dimensions)
		if accepted:
			# An accepted panel image becomes a shaped ring too; its original
			# rectangular canvas must not reintroduce a slab around the minimap.
			var exterior: String = Shapes.path(shape, rect.grow(15))
			var footer: String = Shapes.path("square", Rect2(20, dimensions.y - 35, dimensions.x - 40, 30))
			_alpha_mask(image, dimensions, exterior + " " + footer, true)
	elif kind == "stat_frame":
		shape = str(recipe.get("stat_presentation", "orb"))
		rect = Shapes.stat_geometry(dimensions, shape).reservoir
	elif kind in ["reservoir_empty", "reservoir_health", "reservoir_mana"]:
		shape = str(recipe.get("stat_presentation", "orb"))
		rect = Rect2(1, 1, dimensions.x - 2, dimensions.y - 2)
		outside = true
	else:
		return
	_alpha_mask(image, dimensions, Shapes.path(shape, rect), outside)

static func _alpha_mask(image: Image, dimensions: Vector2, path: String, inside: bool) -> void:
	var mask := Image.new()
	var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %s %s"><path d="%s" fill="white"/></svg>' % [image.get_width(), image.get_height(), dimensions.x, dimensions.y, path]
	if mask.load_svg_from_string(svg) != OK:
		return
	image.convert(Image.FORMAT_RGBA8)
	mask.convert(Image.FORMAT_RGBA8)
	var bytes: PackedByteArray = image.get_data()
	var mask_bytes: PackedByteArray = mask.get_data()
	for offset in range(3, bytes.size(), 4):
		var alpha: int = int(mask_bytes[offset]) if inside else 255 - int(mask_bytes[offset])
		bytes[offset] = int(bytes[offset]) * alpha / 255
	image.set_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, bytes)

static func _svg(w: int, h: int, material: String, ornaments: String, accent: String, kind: String, state: String, rng: RandomNumberGenerator, pixel: bool, recipe: Dictionary = {}) -> String:
	# SVG only describes local vector geometry; it never refers to external files.
	var density: float = 1.0 if not pixel else (1.0 if kind.begins_with("icon_") else 0.5)
	var output_w: int = w * 2 if not pixel else maxi(1, roundi(w * density))
	var output_h: int = h * 2 if not pixel else maxi(1, roundi(h * density))
	var parts: Array[String] = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">' % [output_w, output_h, w, h]]
	var colors: Array[String] = _surface_colors(material, recipe)
	var gold: String = "#" + Color(accent).to_html(false)
	var light: String = "#" + Color(accent).lightened(.4).to_html(false)
	var dark: String = "#" + Color(accent).darkened(.6).to_html(false)
	var sculpted: bool = str(recipe.get("rendering", "painted")) == "sculpted"
	parts.append('<defs><linearGradient id="gold" x2="0" y2="1"><stop stop-color="%s"/><stop offset=".13" stop-color="%s"/><stop offset=".26" stop-color="%s"/><stop offset=".52" stop-color="%s"/><stop offset=".76" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>' % [light, "#fff8da" if sculpted else light, gold, dark, gold, dark])
	parts.append('<linearGradient id="face" x1="0" y1="0" x2=".2" y2="1"><stop stop-color="#%s"/><stop offset=".48" stop-color="#%s"/><stop offset="1" stop-color="#%s"/></linearGradient>' % colors)
	parts.append('<linearGradient id="steel" x2="1" y2=".2"><stop stop-color="#465965"/><stop offset=".42" stop-color="#d9e5df"/><stop offset=".52" stop-color="#f7f3dc"/><stop offset=".56" stop-color="#80938d"/><stop offset="1" stop-color="#354751"/></linearGradient>')
	parts.append('<linearGradient id="red" x2="0" y2="1"><stop stop-color="#ffb187"/><stop offset=".25" stop-color="#d34f46"/><stop offset=".6" stop-color="#9b2637"/><stop offset="1" stop-color="#471c2c"/></linearGradient>')
	parts.append('<linearGradient id="blue" x2="0" y2="1"><stop stop-color="#b6f4f2"/><stop offset=".25" stop-color="#5fbbd6"/><stop offset=".6" stop-color="#2d659f"/><stop offset="1" stop-color="#233055"/></linearGradient></defs>')
	if kind.begins_with("icon_"):
		Icons.draw(parts, w, h, kind.trim_prefix("icon_"), gold, light, dark, rng, recipe)
	elif kind == "map_frame":
		_map_frame(parts, Vector2(w, h), recipe, gold, light, dark, ornaments)
	elif kind == "stat_frame":
		_stat_frame(parts, Vector2(w, h), recipe, gold, light, dark, ornaments)
	elif kind in ["reservoir_empty", "reservoir_health", "reservoir_mana"]:
		_reservoir(parts, w, h, kind, recipe)
	elif kind in ["fill_health", "fill_mana"]:
		Frames.fill(parts, w, h, kind, recipe, rng)
	else:
		_frame(parts, w, h, material, ornaments, gold, light, dark, kind, state, rng, recipe)
	parts.append('</svg>')
	return "".join(parts)

static func _surface_colors(material: String, recipe: Dictionary) -> Array[String]:
	# The house determines the broad material tone; a kit-wide seeded blend
	# varies each generation while keeping panels, buttons, and icons coordinated.
	# Parchment remains light enough for brown ink; other materials suit light text.
	var palettes: Dictionary = {
		"Wood": [
			[["a16c3c", "673b24", "301e1b"], ["805036", "4d3027", "281d22"]],
			[["7c824e", "4b542f", "283320"], ["6d754b", "414f35", "223129"]],
			[["5d6660", "3c4442", "202a2d"], ["665e51", "3c3d38", "23282a"]],
			[["60577e", "3b3a5b", "22263e"], ["4c647b", "303e5b", "1d293b"]],
		],
		"Stone": [
			[["867f71", "514c47", "2c2d32"], ["7d7774", "4d494b", "292b33"]],
			[["7b8673", "475244", "29392f"], ["708377", "40534a", "25362f"]],
			[["818a8d", "474f57", "28343d"], ["7c7e7b", "484b4b", "2d3238"]],
			[["8183a3", "4a516d", "2c324d"], ["798b9e", "435b70", "283b50"]],
		],
		"Parchment": [
			[["f3dba8", "dabd88", "b49260"], ["eed2a5", "d5b287", "b28c63"]],
			[["ebe0b7", "cfc398", "a99b70"], ["e1ddbb", "c3bf99", "9f9a73"]],
			[["e9e0c6", "cfbf9f", "ac9673"], ["e2ded0", "c5bda9", "a29783"]],
			[["eee4e5", "d0c1d0", "b09caf"], ["e3e6ed", "c1c8d9", "9da8c1"]],
		],
	}
	var family: int = clampi(int(recipe.get("family_index", 0)), 0, 3)
	var endpoints: Array = palettes.get(material, palettes.Wood)[family]
	var palette_rng := RandomNumberGenerator.new()
	palette_rng.seed = int(recipe.get("seed", 1)) ^ (family * 7919 + 0x5f3759df)
	var blend: float = palette_rng.randf()
	var result: Array[String] = []
	for index in range(3):
		result.append(Color(endpoints[0][index]).lerp(Color(endpoints[1][index]), blend).to_html(false))
	return result

static func _frame(parts: Array[String], w: int, h: int, material: String, ornaments: String, gold: String, light: String, dark: String, kind: String, state: String, rng: RandomNumberGenerator, recipe: Dictionary) -> void:
	var full_height: int = h
	var top: int = roundi(Motifs.header_height(Vector2(w, h), kind) * .36)
	var bottom: int = 0
	if kind in ["button", "banner"]:
		top = roundi(minf(h * .12, 12))
		bottom = top
	if top > 0:
		parts.append('<g transform="translate(0 %d)">' % top)
		h -= top + bottom
	var trim: float = minf(minf(w, h) * .14, 11.0)
	if kind in ["button", "banner"]:
		trim = minf(trim, 7.0)
	if kind == "bar_frame":
		trim = minf(trim, 3.5)
	trim = maxf(1.4, minf(trim * float(recipe.get("border_scale", 1)), minf(w, h) * .23))
	var cut: float = maxf(1.2, trim * rng.randf_range(1.2, 2.4))
	var edge: String = Frames.shape(1.5, 1.5, w - 3, h - 4, cut, recipe, kind)
	var face: String = Frames.shape(trim, trim, w - 2 * trim, h - 2 * trim - 1, maxf(1, cut - trim * .35), recipe, kind)
	parts.append('<path d="%s" fill="#10151c" stroke="#080c10" stroke-width="2.2"/>' % edge)
	parts.append('<path d="%s" fill="url(#gold)" stroke="%s" stroke-width="1"/>' % [Frames.shape(2.5, 2.5, w - 5, h - 7, cut, recipe, kind), dark])
	parts.append('<path d="%s" fill="none" stroke="%s" stroke-width=".9" opacity=".85"/>' % [Frames.shape(4, 4, w - 8, h - 10, maxf(1, cut - 1), recipe, kind), light])
	if int(recipe.get("frame_variant", 0)) in [1, 3] and trim > 5:
		parts.append('<path d="%s" fill="none" stroke="%s" stroke-width="1.6"/>' % [Frames.shape(trim * .68, trim * .68, w - trim * 1.36, h - trim * 1.36 - 2, cut * .85, recipe, kind), dark])
	parts.append('<path d="%s" fill="url(#face)" stroke="%s" stroke-width="2.5"/>' % [face, dark])
	parts.append('<path d="%s" fill="none" stroke="#fff0cd" stroke-width=".8" opacity=".24"/>' % [Frames.shape(trim + 1.6, trim + 1.6, w - 2 * trim - 3.2, h - 2 * trim - 4.2, maxf(1, cut - trim * .4), recipe, kind)])
	parts.append('<defs><clipPath id="inside"><path d="%s"/></clipPath></defs><g clip-path="url(#inside)">' % face)
	_surface(parts, w, h, trim, material, rng, recipe)
	# A broad, faint central wash keeps active labels calm despite the rich edges.
	parts.append('<rect x="%s" y="%s" width="%s" height="%s" fill="%s" opacity=".08"/>' % [trim, trim, w - trim * 2, h - trim * 2, "#fce9bd" if material == "Parchment" else "#0c1220"])
	if state == "hover":
		parts.append('<rect width="%d" height="%d" fill="%s" opacity=".2"/>' % [w, h, light])
	elif state == "pressed":
		parts.append('<rect width="%d" height="%d" fill="#080b12" opacity=".4"/><path d="%s" fill="none" stroke="#03070b" stroke-width="4" opacity=".65"/>' % [w, h, face])
	elif state == "disabled":
		parts.append('<rect width="%d" height="%d" fill="#555b60" opacity=".75"/>' % [w, h])
	parts.append('</g>')
	Frames.border(parts, w, h, trim, recipe, gold, light, dark, kind)
	Frames.decorate(parts, w, h, trim, recipe, gold, light, dark, kind, ornaments)
	if state == "focus":
		parts.append('<path d="%s" fill="none" stroke="%s" stroke-width="2.2"/>' % [edge, light])
	if top > 0:
		parts.append('</g>')
	Motifs.assembly(parts, Vector2(w, full_height), kind, recipe, ornaments, gold, light, dark)

static func _map_frame(parts: Array[String], dimensions: Vector2, recipe: Dictionary, gold: String, light: String, dark: String, ornaments: String) -> void:
	var rect: Rect2 = Shapes.map_rect(dimensions)
	var shape: String = str(recipe.get("map_shape", "circle"))
	var aperture: String = Shapes.path(shape, rect)
	var exterior: String = Shapes.path(shape, rect.grow(14))
	parts.append('<path d="%s %s" fill="url(#face)" fill-rule="evenodd" stroke="%s" stroke-width="4"/>' % [exterior, aperture, dark])
	parts.append('<path d="%s" fill="none" stroke="url(#gold)" stroke-width="13"/><path d="%s" fill="none" stroke="%s" stroke-width="1.2"/>' % [Shapes.path(shape, rect.grow(7)), Shapes.path(shape, rect.grow(13)), light])
	parts.append('<path d="%s" fill="none" stroke="%s" stroke-width="2"/>' % [aperture, dark])
	var footer: String = Shapes.path("square", Rect2(20, dimensions.y - 35, dimensions.x - 40, 30))
	parts.append('<path d="%s" fill="url(#face)" stroke="%s" stroke-width="3"/><path d="%s" fill="none" stroke="url(#gold)" stroke-width="1.2"/>' % [footer, dark, footer])
	for side in [-1, 1]:
		parts.append('<path d="M %s 45 Q %s 33 %s %s" fill="none" stroke="%s" stroke-width="9"/><path d="M %s 45 Q %s 33 %s %s" fill="none" stroke="url(#gold)" stroke-width="5"/>' % [dimensions.x * .5 + side * 35, dimensions.x * .5 + side * 105, rect.get_center().x + side * rect.size.x * .48, rect.position.y + rect.size.y * .33, dark, dimensions.x * .5 + side * 35, dimensions.x * .5 + side * 105, rect.get_center().x + side * rect.size.x * .48, rect.position.y + rect.size.y * .33])
	if ornaments != "Simple":
		for i in range(8 if ornaments == "Rich" else 4):
			var angle: float = i * TAU / (8 if ornaments == "Rich" else 4) + .15
			var at: Vector2 = rect.get_center() + Vector2(cos(angle), sin(angle)) * (rect.size.x * .5 + 10)
			parts.append('<circle cx="%s" cy="%s" r="3" fill="url(#gold)" stroke="%s"/><circle cx="%s" cy="%s" r="1" fill="%s"/>' % [at.x, at.y, dark, at.x - .6, at.y - .6, light])

static func _stat_frame(parts: Array[String], dimensions: Vector2, recipe: Dictionary, gold: String, light: String, dark: String, ornaments: String) -> void:
	var presentation: String = str(recipe.get("stat_presentation", "orb"))
	var geometry: Dictionary = Shapes.stat_geometry(dimensions, presentation)
	var reservoir: Rect2 = geometry.reservoir
	var plaque: Rect2 = geometry.plaque
	var rim: String = Shapes.path(presentation, reservoir.grow(8))
	parts.append('<path d="%s" fill="url(#face)" stroke="%s" stroke-width="4"/><path d="%s" fill="none" stroke="url(#gold)" stroke-width="7"/><path d="%s" fill="none" stroke="%s" stroke-width="1.2"/>' % [rim, dark, rim, Shapes.path(presentation, reservoir.grow(12)), light])
	var board: String = Frames.shape(plaque.position.x - 8, plaque.position.y, plaque.size.x + 26, plaque.size.y, 13, recipe, "panel")
	parts.append('<path d="%s" fill="url(#face)" stroke="%s" stroke-width="7"/><path d="%s" fill="none" stroke="url(#gold)" stroke-width="3.5"/>' % [board, dark, board])
	if ornaments != "Simple":
		for side in [-1, 1]:
			var cy: float = reservoir.get_center().y
			parts.append('<path d="M %s %s Q %s %s %s %s" fill="none" stroke="%s" stroke-width="8"/><path d="M %s %s Q %s %s %s %s" fill="none" stroke="url(#gold)" stroke-width="4"/>' % [reservoir.position.x + reservoir.size.x * .3, cy + side * reservoir.size.y * .5, reservoir.position.x - 12, cy + side * reservoir.size.y * .52, reservoir.position.x - 4, cy, dark, reservoir.position.x + reservoir.size.x * .3, cy + side * reservoir.size.y * .5, reservoir.position.x - 12, cy + side * reservoir.size.y * .52, reservoir.position.x - 4, cy])

static func _reservoir(parts: Array[String], w: int, h: int, kind: String, recipe: Dictionary) -> void:
	var presentation: String = str(recipe.get("stat_presentation", "orb"))
	var path: String = Shapes.path(presentation, Rect2(1, 1, w - 2, h - 2))
	var fill: String = "url(#red)" if kind == "reservoir_health" else "url(#blue)"
	if kind == "reservoir_empty":
		fill = "#101d2b"
	parts.append('<path d="%s" fill="%s" stroke="#b7d4d2" stroke-width="1.4" stroke-opacity=".6"/><defs><clipPath id="reservoir"><path d="%s"/></clipPath></defs><g clip-path="url(#reservoir)">' % [path, fill, path])
	if kind != "reservoir_empty":
		for i in range(4):
			parts.append('<path d="M -4 %s Q %s %s %s %s T %s %s" fill="none" stroke="#effff5" stroke-width="%s" opacity=".14"/>' % [h * (.2 + i * .2), w * .23, h * (.05 + i * .2), w * .5, h * (.2 + i * .2), w + 4, h * (.2 + i * .2), 1.5 + i * .5])
	parts.append('<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="#e6fff2" opacity=".15"/><path d="M %s %s Q %s %s %s %s" fill="none" stroke="#f1fff1" stroke-width="%s" opacity=".65"/></g>' % [w * .31, h * .3, w * .12, h * .23, w * .2, h * .24, w * .13, h * .48, w * .2, h * .62, maxf(1.5, w * .025)])

static func _surface(parts: Array[String], w: int, h: int, trim: float, material: String, rng: RandomNumberGenerator, recipe: Dictionary = {}) -> void:
	var x0: float = trim + 1
	var x1: float = w - trim - 1
	var y0: float = trim + 1
	var y1: float = h - trim - 2
	var area: float = maxf(1, (x1 - x0) * (y1 - y0))
	var tones: Array[String] = _surface_colors(material, recipe)
	var grain_light: String = "#" + Color(tones[0]).lightened(.36).to_html(false)
	var grain_dark: String = "#" + Color(tones[2]).darkened(.24).to_html(false)
	match material:
		"Wood":
			for i in range(maxi(3, int((y1 - y0) / 2.5))):
				var y: float = rng.randf_range(y0, y1)
				var wave: float = rng.randf_range(1, 5)
				parts.append('<path d="M %s %.2f C %.2f %.2f %.2f %.2f %s %.2f" fill="none" stroke="%s" stroke-width="%.2f" opacity="%.2f"/>' % [x0, y, w * .33, y - wave, w * .66, y + wave, x1, y, grain_light if i % 3 else grain_dark, rng.randf_range(.45, 1.4), rng.randf_range(.08, .28)])
			if h > 120:
				for x in range(64, w - 30, 79):
					parts.append('<path d="M %d %s V %s" stroke="%s" stroke-width="2" opacity=".42"/><path d="M %d %s V %s" stroke="%s" opacity=".15"/>' % [x, y0, y1, grain_dark, x + 2, y0, y1, grain_light])
			var knot_x: float = rng.randf_range(w * .2, w * .8)
			var knot_y: float = rng.randf_range(y0, y1)
			for i in range(1, 4):
				parts.append('<ellipse cx="%.2f" cy="%.2f" rx="%d" ry="%s" fill="none" stroke="%s" stroke-width=".7" opacity=".4"/>' % [knot_x, knot_y, i * 5, i * 1.6, grain_dark])
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

static func _pixelize(image: Image, width: int, height: int, material: String, accent: String, kind: String, recipe: Dictionary = {}) -> void:
	var palette: Array[Color] = [Color("151921"), Color("302029"), Color("513229"), Color("795034"), Color("a37643"), Color("d1a465"), Color("f2d699"), Color("fff1c5"), Color("283640"), Color("465762"), Color("738889"), Color("bdc8b5"), Color("6d2738"), Color("ab3b47"), Color("dc705a"), Color("ffb187"), Color("263954"), Color("365d88"), Color("559cb9"), Color("a9e2dc"), Color("396158"), Color("5c9680"), Color("303c27"), Color("525d36"), Color("78804a"), Color("282a43"), Color("444666"), Color("69668a"), Color("2b3034"), Color("454b4d"), Color("626868"), Color("8f9698")]
	var accent_color := Color(accent)
	palette.append(accent_color)
	palette.append(accent_color.lightened(.35))
	palette.append(accent_color.darkened(.55))
	var surface_tones: Array[String] = _surface_colors(material, recipe)
	for tone in surface_tones:
		palette.append(Color(tone))
	var palette_key: String = JSON.stringify([accent, material, surface_tones])
	if pixel_cache_accent != palette_key or pixel_color_cache.size() > 65536:
		pixel_color_cache.clear()
		pixel_cache_accent = palette_key
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
