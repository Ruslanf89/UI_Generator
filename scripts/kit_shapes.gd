extends RefCounted
## Shared aperture geometry for vector frames, native clipping, and reservoirs.
## Mask textures are utility resources, not requests for an AI artwork role.

static var mask_cache: Dictionary = {}

static func map_rect(dimensions: Vector2) -> Rect2:
	var side: float = minf(24.0, dimensions.x * .08)
	var top: float = minf(76.0, dimensions.y * .25)
	var bottom: float = minf(52.0, dimensions.y * .18)
	var diameter: float = maxf(1.0, minf(dimensions.x - side * 2, dimensions.y - top - bottom))
	return Rect2(roundf((dimensions.x - diameter) * .5), roundf(top + (dimensions.y - top - bottom - diameter) * .5), diameter, diameter)

static func stat_geometry(dimensions: Vector2, _presentation: String = "orb") -> Dictionary:
	var diameter: float = maxf(16.0, minf(minf(dimensions.y - 28.0, dimensions.x * .36), 132.0))
	var reservoir := Rect2(16, roundf((dimensions.y - diameter) * .5), diameter, diameter)
	var left: float = diameter + 42.0
	return {"reservoir": reservoir, "plaque": Rect2(left, 24, maxf(32, dimensions.x - left - 22), maxf(28, dimensions.y - 48))}

static func path(shape: String, rect: Rect2) -> String:
	var x: float = rect.position.x
	var y: float = rect.position.y
	var w: float = rect.size.x
	var h: float = rect.size.y
	var r: float = x + w
	var b: float = y + h
	var cx: float = x + w * .5
	var cy: float = y + h * .5
	match shape:
		"circle", "orb":
			return "M %s %s A %s %s 0 1 1 %s %s A %s %s 0 1 1 %s %s Z" % [r, cy, w * .5, h * .5, x, cy, w * .5, h * .5, r, cy]
		"hexagon":
			return "M %s %s H %s L %s %s L %s %s H %s L %s %s Z" % [x + w * .25, y, x + w * .75, r, cy, x + w * .75, b, x + w * .25, x, cy]
		"shield":
			return "M %s %s Q %s %s %s %s L %s %s Q %s %s %s %s Q %s %s %s %s L %s %s Q %s %s %s %s Z" % [cx, y, x + w * .75, y + h * .1, r, y + h * .1, r - w * .06, y + h * .6, r - w * .1, b - h * .2, cx, b, x + w * .1, b - h * .2, x + w * .06, y + h * .6, x, y + h * .1, x + w * .25, y + h * .1, cx, y]
		"diamond":
			return "M %s %s L %s %s L %s %s L %s %s Z" % [cx, y, r, cy, cx, b, x, cy]
		"octagon":
			return "M %s %s H %s L %s %s V %s L %s %s H %s L %s %s V %s Z" % [x + w * .28, y, r - w * .28, r, y + h * .28, b - h * .28, r - w * .28, b, x + w * .28, x, b - h * .28, y + h * .28]
		"vial":
			return "M %s %s H %s V %s Q %s %s %s %s V %s Q %s %s %s %s H %s Q %s %s %s %s V %s Q %s %s %s %s Z" % [x + w * .34, y, x + w * .66, y + h * .18, r, y + h * .3, r, y + h * .45, b - h * .15, r, b, r - w * .15, b, x + w * .15, x, b, x, b - h * .15, y + h * .45, x, y + h * .3, x + w * .34, y + h * .18]
		_:
			var cut: float = minf(w, h) * .1
			return "M %s %s H %s Q %s %s %s %s V %s Q %s %s %s %s H %s Q %s %s %s %s V %s Q %s %s %s %s Z" % [x + cut, y, r - cut, r, y, r, y + cut, b - cut, r, b, r - cut, b, x + cut, x, b, x, b - cut, y + cut, x, y, x + cut, y]

static func mask_texture(dimensions: Vector2, shape: String, pixel: bool = false) -> ImageTexture:
	var width: int = maxi(1, roundi(dimensions.x))
	var height: int = maxi(1, roundi(dimensions.y))
	var key: String = "%s/%d/%d/%s" % [shape, width, height, pixel]
	if mask_cache.has(key):
		return mask_cache[key]
	if mask_cache.size() > 128:
		mask_cache.clear()
	var output_width: int = maxi(1, width / 2) if pixel else width * 2
	var output_height: int = maxi(1, height / 2) if pixel else height * 2
	var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d"><path d="%s" fill="white"/></svg>' % [output_width, output_height, width, height, path(shape, Rect2(0, 0, width, height))]
	var image := Image.new()
	if image.load_svg_from_string(svg) != OK:
		return null
	if pixel:
		image.convert(Image.FORMAT_RGBA8)
		var bytes: PackedByteArray = image.get_data()
		for offset in range(3, bytes.size(), 4):
			bytes[offset] = 255 if bytes[offset] >= 128 else 0
		image.set_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, bytes)
		image.resize(width * 2, height * 2, Image.INTERPOLATE_NEAREST)
	var texture := ImageTexture.create_from_image(image)
	texture.set_meta("kit_mask_shape", shape)
	mask_cache[key] = texture
	return texture
