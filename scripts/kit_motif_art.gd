extends RefCounted
## Original prepared ornament drawings, assembled with seeded relief and curves.
## Source SVGs are authored parts, not generated images or third-party game art.

const MOTIFS = ["griffin", "stag", "golem", "celestial", "dragon", "wolf", "raven", "sun", "skull", "kraken"]
const PARTS = {
	"griffin": preload("res://assets/ornaments/griffin.svg"),
	"stag": preload("res://assets/ornaments/stag.svg"),
	"golem": preload("res://assets/ornaments/golem.svg"),
	"celestial": preload("res://assets/ornaments/celestial.svg"),
	"dragon": preload("res://assets/ornaments/dragon.svg"),
	"wolf": preload("res://assets/ornaments/wolf.svg"),
	"raven": preload("res://assets/ornaments/raven.svg"),
	"sun": preload("res://assets/ornaments/sun.svg"),
	"skull": preload("res://assets/ornaments/skull.svg"),
	"kraken": preload("res://assets/ornaments/kraken.svg"),
}
const HEAD_CROPS = {
	"griffin": Rect2(74, 32, 108, 194), "stag": Rect2(64, 8, 128, 238),
	"golem": Rect2(44, 12, 168, 232), "celestial": Rect2(64, 20, 128, 216),
	"dragon": Rect2(64, 4, 128, 240), "wolf": Rect2(50, 10, 156, 234),
	"raven": Rect2(64, 20, 144, 222), "sun": Rect2(60, 42, 136, 172),
	"skull": Rect2(44, 8, 168, 238), "kraken": Rect2(68, 4, 120, 190),
}
static var prepared_cache: Dictionary = {}

static func header_height(dimensions: Vector2, role: String = "panel") -> float:
	if role == "panel" and dimensions.x >= 280 and dimensions.y > 300:
		return clampf(dimensions.y * .25, 80, 104)
	return 0

static func side_clearance(dimensions: Vector2, role: String) -> float:
	return minf(110, dimensions.y * .85) if role == "banner" else (minf(42, dimensions.y * .62) if role == "button" else 0.0)

static func compose(image: Image, dimensions: Vector2, role: String, recipe: Dictionary, ornaments: String, state: String = "normal") -> void:
	if role.begins_with("icon_") or role in ["fill_health", "fill_mana", "bar_frame", "slot", "reservoir_health", "reservoir_mana", "reservoir_empty"]:
		return
	var motif: String = str(recipe.get("motif", MOTIFS[int(recipe.get("family_index", 0)) % 4]))
	if motif not in MOTIFS:
		motif = MOTIFS[0]
	var placements: Array[Rect2] = _placements(dimensions, role, recipe)
	var factor: Vector2 = Vector2(image.get_width(), image.get_height()) / dimensions
	var pose: int = posmod(int(recipe.get("component_seed", 1)), 4)
	for index in range(placements.size()):
		var rect: Rect2 = placements[index]
		var target: Vector2i = Vector2i(maxi(1, roundi(rect.size.x * factor.x)), maxi(1, roundi(rect.size.y * factor.y)))
		var mirrored: bool = (index % 2 == 1) != (pose == 3)
		var drawing: Image = _prepared(motif, target, recipe, mirrored, state)
		if drawing != null:
			image.blend_rect(drawing, Rect2i(Vector2i.ZERO, drawing.get_size()), Vector2i(roundi(rect.position.x * factor.x), roundi(rect.position.y * factor.y)))

static func _placements(dimensions: Vector2, role: String, recipe: Dictionary) -> Array[Rect2]:
	var w: float = dimensions.x
	var h: float = dimensions.y
	var result: Array[Rect2] = []
	var variation: float = .9 + posmod(int(recipe.get("component_seed", 1)), 7) * .025
	var head: float = header_height(dimensions, role)
	if head > 0:
		var width: float = minf(w * .56, head * 1.65) * variation
		result.append(Rect2((w - width) * .5, 0, width, head))
	elif role == "banner":
		var clearance: float = side_clearance(dimensions, role)
		var size: Vector2 = Vector2(clearance, minf(h, clearance * 1.25))
		result.append(Rect2(Vector2(0, (h - size.y) * .5), size))
		result.append(Rect2(Vector2(w - size.x, (h - size.y) * .5), size))
	elif role == "button" and w >= 170 and h >= 42:
		var clearance: float = side_clearance(dimensions, role)
		var size: Vector2 = Vector2(clearance, minf(h - 2, clearance * 1.32))
		result.append(Rect2(Vector2(2, (h - size.y) * .5), size))
		result.append(Rect2(Vector2(w - size.x - 2, (h - size.y) * .5), size))
	elif role == "map_frame":
		# The shared map window leaves a top cap; titles sit below this drawing.
		var size: Vector2 = Vector2(minf(w * .65, 164), minf(h * .23, 72))
		result.append(Rect2(Vector2((w - size.x) * .5, 0), size))
	elif role == "stat_frame":
		var size: Vector2 = Vector2(minf(w * .18, 66), minf(h - 8, 108))
		result.append(Rect2(Vector2(w - size.x - 2, (h - size.y) * .5), size))
	return result

static func _prepared(motif: String, target: Vector2i, recipe: Dictionary, mirrored: bool, state: String) -> Image:
	var rendering: String = str(recipe.get("rendering", "painted"))
	var accent: String = str(recipe.get("accent", "ecc17b")).trim_prefix("#")
	var gem: String = str(recipe.get("gem", "69b8bb")).trim_prefix("#")
	var key: String = JSON.stringify([motif, target, rendering, accent, gem, mirrored, state])
	if prepared_cache.has(key):
		return prepared_cache[key]
	var texture: Texture2D = _source(motif)
	if texture == null:
		return null
	var source: Image = texture.get_image()
	if source == null or source.is_empty():
		return null
	if target.y > target.x * 1.1:
		# Tall endcaps use the prepared portrait region. Its geometry is kept
		# intact; only the surrounding wing/tentacle fan is cropped away.
		var crop: Rect2 = HEAD_CROPS.get(motif, Rect2(0, 0, 256, 256))
		var source_scale: Vector2 = Vector2(source.get_size()) / 256.0
		var crop_pixels := Rect2i(crop.position * source_scale, crop.size * source_scale)
		source = source.get_region(crop_pixels.intersection(Rect2i(Vector2i.ZERO, source.get_size())))
	var used: Rect2i = source.get_used_rect()
	if used.size.x > 0 and used.size.y > 0:
		source = source.get_region(used)
	else:
		source = source.duplicate()
	source.convert(Image.FORMAT_RGBA8)
	if mirrored:
		source.flip_x()
	# Color only the posed output pixels, rather than recoloring a full 512px
	# drawing for every small button state and every pixel-art thumbnail.
	var fit: float = minf(float(target.x) / source.get_width(), float(target.y) / source.get_height())
	var fitted: Vector2i = Vector2i(clampi(roundi(source.get_width() * fit), 1, target.x), clampi(roundi(source.get_height() * fit), 1, target.y))
	source.resize(fitted.x, fitted.y, Image.INTERPOLATE_NEAREST if rendering == "pixel" else Image.INTERPOLATE_LANCZOS)
	var bytes: PackedByteArray = source.get_data()
	var metal := Color(accent)
	var jewel := Color(gem)
	var painted_color := Color({"griffin": "bca27d", "stag": "a8784b", "golem": "7f9497", "celestial": "8e9acb", "dragon": "65906f", "wolf": "8195a4", "raven": "687b9b", "sun": "d5a24f", "skull": "d5c9a6", "kraken": "689f9a"}.get(motif, "bca27d"))
	var shadow: Color = metal.darkened(.83)
	var light: Color = metal.lightened(.64)
	for offset in range(0, bytes.size(), 4):
		if bytes[offset + 3] == 0:
			continue
		var original := Color(bytes[offset] / 255.0, bytes[offset + 1] / 255.0, bytes[offset + 2] / 255.0)
		var brightness: float = original.r * .299 + original.g * .587 + original.b * .114
		var color: Color
		if original.g > original.r * 1.18 and original.b > original.r * 1.1:
			color = jewel.darkened(.45).lerp(jewel.lightened(.4), clampf(brightness * 1.35, 0, 1))
		elif brightness < .52:
			color = shadow.lerp(metal.darkened(.12), clampf((brightness - .045) / .475, 0, 1))
		else:
			color = metal.darkened(.12).lerp(light, clampf((brightness - .52) / .44, 0, 1))
		if rendering in ["painted", "pixel"] and not (original.g > original.r * 1.18 and original.b > original.r * 1.1):
			# Matte animal/stone/bone colors distinguish illustration from the
			# cast-metal rendering. Strong ink planes remain crisp in pixel art.
			if brightness < .22:
				color = Color("131d29").lerp(painted_color.darkened(.52), clampf(brightness / .22, 0, 1))
			elif brightness < .53:
				color = painted_color.darkened(.45).lerp(painted_color, (brightness - .22) / .31)
			else:
				color = painted_color.lerp(painted_color.lightened(.59), clampf((brightness - .53) / .44, 0, 1))
		elif rendering == "sculpted":
			color = color.darkened(.13) if brightness < .28 else color.lightened(.07)
		if state == "hover": color = color.lightened(.1)
		elif state == "pressed": color = color.darkened(.16)
		elif state == "disabled":
			var gray: float = color.r * .299 + color.g * .587 + color.b * .114
			color = color.lerp(Color(gray, gray, gray), .76).darkened(.15)
		bytes[offset] = clampi(roundi(color.r * 255), 0, 255)
		bytes[offset + 1] = clampi(roundi(color.g * 255), 0, 255)
		bytes[offset + 2] = clampi(roundi(color.b * 255), 0, 255)
	source.set_data(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8, bytes)
	var canvas := Image.create(target.x, target.y, false, Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	canvas.blit_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), Vector2i((target.x - fitted.x) / 2, (target.y - fitted.y) / 2))
	if prepared_cache.size() >= 128:
		prepared_cache.clear()
	prepared_cache[key] = canvas
	return canvas

static func _source(motif: String) -> Texture2D:
	return PARTS.get(motif) as Texture2D

static func assembly(parts: Array[String], dimensions: Vector2, role: String, recipe: Dictionary, ornaments: String, gold: String, light: String, dark: String) -> void:
	if role.begins_with("icon_") or role in ["fill_health", "fill_mana", "bar_frame", "reservoir_health", "reservoir_mana", "reservoir_empty"]:
		return
	var w: float = dimensions.x
	var h: float = dimensions.y
	var motif: String = str(recipe.get("motif", "griffin"))
	var head: float = header_height(dimensions, role)
	var rich: bool = ornaments == "Rich"
	if head > 0:
		var shoulder: float = minf(w * .31, head * 1.4)
		var cy: float = head * .63
		var bend: float = 8 + posmod(int(recipe.get("component_seed", 1)), 9)
		for direction in [-1, 1]:
			parts.append('<g transform="translate(%s %s) scale(%d 1)">' % [w * .5, cy, direction])
			if motif in ["dragon", "griffin", "raven", "celestial"]:
				parts.append('<path d="M 22 4 Q %s -%s %s -%s L %s 14 Q 68 17 30 25 Z" fill="url(#gold)" stroke="%s" stroke-width="2"/>' % [shoulder * .7, bend, shoulder, bend * 1.7, shoulder * .78, dark])
				for i in range(3 if not rich else 6):
					var tip: float = shoulder - i * 10
					parts.append('<path d="M 35 %s Q %s -4 %s -%s" fill="none" stroke="%s" stroke-width="1.3"/>' % [13 + i * 1.8, tip * .7, tip, bend * 1.3 - i * 2, light])
			elif motif in ["stag", "wolf", "skull"]:
				parts.append('<path d="M 26 18 Q %s 5 %s -%s M %s 3 l -7 -16 M %s -4 l 14 -12" fill="none" stroke="%s" stroke-width="8"/><path d="M 26 18 Q %s 5 %s -%s" fill="none" stroke="%s" stroke-width="3"/>' % [shoulder * .68, shoulder, bend, shoulder * .62, shoulder * .83, dark, shoulder * .68, shoulder, bend, gold])
			elif motif == "kraken":
				parts.append('<path d="M 23 7 C %s -14 %s 27 %s 26 C %s 27 %s -5 %s 6" fill="none" stroke="%s" stroke-width="10"/><path d="M 23 7 C %s -14 %s 27 %s 26" fill="none" stroke="%s" stroke-width="5"/>' % [shoulder * .6, shoulder * .7, shoulder, shoulder * 1.1, shoulder * .9, shoulder * .83, dark, shoulder * .6, shoulder * .7, shoulder, gold])
			else:
				parts.append('<path d="M 28 0 H %s l 12 12 l -12 12 H 28 Z" fill="url(#steel)" stroke="%s" stroke-width="2"/>' % [shoulder - 14, dark])
			parts.append('</g>')
		if rich:
			# Claws, rivets, scales, or hanging crystals attach the cap to the body.
			for x in [w * .5 - shoulder * .86, w * .5 + shoulder * .86]:
				parts.append('<path d="M %s %s l 5 8 l -5 12 l -5 -12 Z" fill="url(#gold)" stroke="%s"/><path d="M %s %s v 11" stroke="%s"/>' % [x, cy + 10, dark, x, cy + 13, light])
	elif role == "banner" and rich:
		var end: float = side_clearance(dimensions, role)
		for side in [0, 1]:
			var x: float = end * .6 if side == 0 else w - end * .6
			parts.append('<path d="M %s 5 Q %s %s %s %s" fill="none" stroke="%s" stroke-width="4"/>' % [x, x - 18, h * .5, x, h - 5, gold])
