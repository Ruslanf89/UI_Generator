extends RefCounted
## Adapts reviewed, locally cached PNG artwork to native Godot controls.
## This module performs no network requests and never needs Godot imports.

const ROLES = ["panel", "button", "bar_frame", "fill_health", "fill_mana", "slot", "banner", "icon_sword", "icon_shield", "icon_potion", "icon_heart", "icon_gear", "icon_bag", "icon_arrow", "icon_star", "icon_coin", "icon_scroll", "icon_mana", "icon_close"]
const MAX_SOURCE_BYTES = 32 * 1024 * 1024
const MAX_IMAGE_SIDE = 4096
static var texture_cache: Dictionary = {}
static var source_cache: Dictionary = {}

static func texture(config: Dictionary, dimensions: Vector2, component: String, kind: String, state: String = "normal") -> ImageTexture:
	var ai: Dictionary = config.get("ai", {})
	if not ai.get("enabled", false) or kind not in ROLES:
		return null
	var component_assets: Dictionary = ai.get("component_assets", {}).get(component, {})
	var family_assets: Dictionary = ai.get("assets", {})
	# A missing or invalid component override must not hide a valid family image.
	for record in [component_assets.get(kind, {}), family_assets.get(kind, {})]:
		if not record is Dictionary or str(record.get("path", "")).is_empty():
			continue
		var image: Image = _source(record)
		if image == null:
			continue
		var width: int = maxi(1, roundi(dimensions.x))
		var height: int = maxi(1, roundi(dimensions.y))
		var pixel: bool = str(config.get("style", "")) == "Medieval pixel"
		var key: String = JSON.stringify([record.path, record.get("sha256", ""), width, height, state, pixel, component, kind])
		if texture_cache.has(key):
			return texture_cache[key]
		if texture_cache.size() >= 384:
			texture_cache.clear()
		var output: Image = _fit_icon(image, width * 2, height * 2, pixel) if kind.begins_with("icon_") else _nine_slice(image, width * 2, height * 2, kind, pixel)
		if pixel:
			_pixel_grid(output, width, height, kind)
		_state(output, state, pixel)
		var result := ImageTexture.create_from_image(output)
		result.set_meta("kit_art_role", kind)
		result.set_meta("kit_art_component", component)
		result.set_meta("kit_art_source", "ai")
		result.set_meta("kit_art_asset_sha256", record.get("sha256", ""))
		texture_cache[key] = result
		return result
	return null

static func _source(record: Dictionary) -> Image:
	var path: String = str(record.get("path", ""))
	if not FileAccess.file_exists(path):
		return null
	var expected: String = str(record.get("sha256", "")).to_lower()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 24 or file.get_length() > MAX_SOURCE_BYTES:
		return null
	var stamp: int = FileAccess.get_modified_time(path)
	var length: int = file.get_length()
	var key: String = JSON.stringify([path, expected, stamp, length])
	if source_cache.has(key):
		return source_cache[key]
	var bytes: PackedByteArray = file.get_buffer(length)
	if bytes.size() != length or not _valid_png_header(bytes):
		return null
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	var actual: String = hash.finish().hex_encode()
	if not expected.is_empty() and actual != expected:
		return null
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK or image.is_empty():
		return null
	image.convert(Image.FORMAT_RGBA8)
	if source_cache.size() >= 64:
		source_cache.clear()
	source_cache[key] = image
	return image

static func _valid_png_header(bytes: PackedByteArray) -> bool:
	if bytes.size() < 24 or bytes.slice(0, 8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]):
		return false
	var width: int = (int(bytes[16]) << 24) | (int(bytes[17]) << 16) | (int(bytes[18]) << 8) | int(bytes[19])
	var height: int = (int(bytes[20]) << 24) | (int(bytes[21]) << 16) | (int(bytes[22]) << 8) | int(bytes[23])
	return width > 0 and height > 0 and width <= MAX_IMAGE_SIDE and height <= MAX_IMAGE_SIDE

static func _fit_icon(source: Image, width: int, height: int, pixel: bool) -> Image:
	var output := Image.create(width, height, false, Image.FORMAT_RGBA8)
	output.fill(Color.TRANSPARENT)
	var factor: float = minf(float(width) / source.get_width(), float(height) / source.get_height())
	var fit_w: int = clampi(roundi(source.get_width() * factor), 1, width)
	var fit_h: int = clampi(roundi(source.get_height() * factor), 1, height)
	var icon: Image = source.duplicate()
	icon.resize(fit_w, fit_h, Image.INTERPOLATE_NEAREST if pixel else Image.INTERPOLATE_LANCZOS)
	output.blit_rect(icon, Rect2i(0, 0, fit_w, fit_h), Vector2i((width - fit_w) / 2, (height - fit_h) / 2))
	return output

static func _nine_slice(source: Image, width: int, height: int, kind: String, pixel: bool) -> Image:
	var output := Image.create(width, height, false, Image.FORMAT_RGBA8)
	output.fill(Color.TRANSPARENT)
	# Square source corners remain square after composition. Stretch only the
	# quiet middle and straight border runs, rather than the complete illustration.
	var source_corner: int = maxi(1, roundi(minf(source.get_width(), source.get_height()) * .15))
	source_corner = mini(source_corner, mini(source.get_width() / 3, source.get_height() / 3))
	var logical_corner: int = 28 if kind == "panel" else (20 if kind == "banner" else 16)
	var corner: int = mini(logical_corner * 2, mini(width / 3, height / 3))
	if source_corner < 1 or corner < 1:
		output = source.duplicate()
		output.resize(width, height, Image.INTERPOLATE_NEAREST if pixel else Image.INTERPOLATE_LANCZOS)
		return output
	var source_x: Array[int] = [0, source_corner, source.get_width() - source_corner, source.get_width()]
	var source_y: Array[int] = [0, source_corner, source.get_height() - source_corner, source.get_height()]
	var target_x: Array[int] = [0, corner, width - corner, width]
	var target_y: Array[int] = [0, corner, height - corner, height]
	for row in range(3):
		for column in range(3):
			var piece: Image = source.get_region(Rect2i(source_x[column], source_y[row], source_x[column + 1] - source_x[column], source_y[row + 1] - source_y[row]))
			var target_w: int = target_x[column + 1] - target_x[column]
			var target_h: int = target_y[row + 1] - target_y[row]
			piece.resize(target_w, target_h, Image.INTERPOLATE_NEAREST if pixel else Image.INTERPOLATE_LANCZOS)
			output.blit_rect(piece, Rect2i(0, 0, target_w, target_h), Vector2i(target_x[column], target_y[row]))
	return output

static func _pixel_grid(image: Image, width: int, height: int, kind: String) -> void:
	var divisor: int = 1 if kind.begins_with("icon_") else 2
	image.resize(maxi(1, width / divisor), maxi(1, height / divisor), Image.INTERPOLATE_NEAREST)
	var bytes: PackedByteArray = image.get_data()
	for offset in range(3, bytes.size(), 4):
		bytes[offset] = 255 if bytes[offset] >= 128 else 0
	image.set_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, bytes)
	image.resize(width * 2, height * 2, Image.INTERPOLATE_NEAREST)

static func _state(image: Image, state: String, pixel: bool) -> void:
	if state == "normal":
		return
	var bytes: PackedByteArray = image.get_data()
	var width: int = image.get_width()
	var height: int = image.get_height()
	var original: PackedByteArray = bytes.duplicate() if state == "focus" else PackedByteArray()
	for offset in range(0, bytes.size(), 4):
		if bytes[offset + 3] == 0:
			continue
		if state == "hover":
			for channel in range(3):
				bytes[offset + channel] = mini(255, roundi(bytes[offset + channel] * .83 + 255 * .17))
		elif state == "pressed":
			for channel in range(3):
				bytes[offset + channel] = roundi(bytes[offset + channel] * .7)
		elif state == "disabled":
			var gray: int = roundi(bytes[offset] * .299 + bytes[offset + 1] * .587 + bytes[offset + 2] * .114)
			for channel in range(3):
				bytes[offset + channel] = roundi(gray * .7 + 35)
		elif state == "focus":
			var index: int = offset / 4
			var x: int = index % width
			var y: int = index / width
			var thickness: int = 4 if pixel else 2
			var edge: bool = x < thickness or y < thickness or x >= width - thickness or y >= height - thickness
			if not edge:
				for delta in [-thickness, thickness, -width * thickness, width * thickness]:
					if original[(index + delta) * 4 + 3] < 128:
						edge = true
						break
			if edge:
				bytes[offset] = 255
				bytes[offset + 1] = 234
				bytes[offset + 2] = 157
	image.set_data(width, height, false, Image.FORMAT_RGBA8, bytes)

static func prepare_image(source: Image, role: String) -> Dictionary:
	if role not in ROLES:
		return _failure("The generated artwork has an unknown component role.")
	if source == null or source.is_empty() or source.get_width() > MAX_IMAGE_SIDE or source.get_height() > MAX_IMAGE_SIDE:
		return _failure("The generated image is empty or exceeds the 4096-pixel limit.")
	var image: Image = source.duplicate()
	image.convert(Image.FORMAT_RGBA8)
	var width: int = image.get_width()
	var height: int = image.get_height()
	var bytes: PackedByteArray = image.get_data()
	var mode: int = _background_mode(bytes, width, height)
	var removed: int = _remove_background(bytes, width, height, mode) if mode != 0 else 0
	var bounds: Rect2i = Rect2i(width, height, 0, 0)
	var left: int = width
	var top: int = height
	var right: int = -1
	var bottom: int = -1
	var visible: int = 0
	var minimum: Vector3i = Vector3i(255, 255, 255)
	var maximum: Vector3i = Vector3i.ZERO
	for offset in range(0, bytes.size(), 4):
		if bytes[offset + 3] < 16:
			continue
		var index: int = offset / 4
		var x: int = index % width
		var y: int = index / width
		left = mini(left, x)
		top = mini(top, y)
		right = maxi(right, x)
		bottom = maxi(bottom, y)
		visible += 1
		for channel in range(3):
			minimum[channel] = mini(minimum[channel], bytes[offset + channel])
			maximum[channel] = maxi(maximum[channel], bytes[offset + channel])
	if visible < maxi(4, int(width * height * .0005)):
		return _failure("The generated image contains no usable visible artwork.", removed > 0)
	if visible == width * height and (maximum - minimum).length_squared() < 12:
		return _failure("The generated image is a blank, solid-color canvas.", removed > 0)
	image.set_data(width, height, false, Image.FORMAT_RGBA8, bytes)
	var padding: int = clampi(roundi(maxi(right - left + 1, bottom - top + 1) * .02), 2, 24)
	left = maxi(0, left - padding)
	top = maxi(0, top - padding)
	right = mini(width - 1, right + padding)
	bottom = mini(height - 1, bottom + padding)
	bounds = Rect2i(left, top, right - left + 1, bottom - top + 1)
	image = image.get_region(bounds)
	return {"ok": true, "image": image, "error": "", "background_removed": removed > 0, "original_size": Vector2i(width, height), "prepared_size": image.get_size()}

static func _background_mode(bytes: PackedByteArray, width: int, height: int) -> int:
	var magenta: int = 0
	var white: int = 0
	var samples: int = 0
	var step_size: int = maxi(1, (width + height) / 256)
	for x in range(0, width, step_size):
		for y in [0, height - 1]:
			var offset: int = (y * width + x) * 4
			if bytes[offset + 3] >= 128:
				magenta += int(_background_pixel(bytes, offset, 1))
				white += int(_background_pixel(bytes, offset, 2))
			samples += 1
	for y in range(0, height, step_size):
		for x in [0, width - 1]:
			var offset: int = (y * width + x) * 4
			if bytes[offset + 3] >= 128:
				magenta += int(_background_pixel(bytes, offset, 1))
				white += int(_background_pixel(bytes, offset, 2))
			samples += 1
	if magenta >= maxi(2, int(samples * .3)) and magenta >= white:
		return 1
	if white >= maxi(2, int(samples * .3)):
		return 2
	return 0

static func _background_pixel(bytes: PackedByteArray, offset: int, mode: int) -> bool:
	if bytes[offset + 3] < 16:
		return true
	var red: int = bytes[offset]
	var green: int = bytes[offset + 1]
	var blue: int = bytes[offset + 2]
	if mode == 1:
		return red >= 190 and blue >= 190 and green <= 75 and absi(red - blue) <= 48
	return mini(red, mini(green, blue)) >= 228 and maxi(red, maxi(green, blue)) - mini(red, mini(green, blue)) <= 24

static func _remove_background(bytes: PackedByteArray, width: int, height: int, mode: int) -> int:
	var visited := PackedByteArray()
	visited.resize(width * height)
	var queue := PackedInt32Array()
	for x in range(width):
		for index in [x, (height - 1) * width + x]:
			if visited[index] == 0 and _background_pixel(bytes, index * 4, mode):
				visited[index] = 1
				queue.append(index)
	for y in range(height):
		for index in [y * width, y * width + width - 1]:
			if visited[index] == 0 and _background_pixel(bytes, index * 4, mode):
				visited[index] = 1
				queue.append(index)
	var head: int = 0
	var removed: int = 0
	while head < queue.size():
		var index: int = queue[head]
		head += 1
		var offset: int = index * 4
		if bytes[offset + 3] != 0:
			removed += 1
		bytes[offset] = 0
		bytes[offset + 1] = 0
		bytes[offset + 2] = 0
		bytes[offset + 3] = 0
		var neighbors: Array[int] = []
		if index % width > 0: neighbors.append(index - 1)
		if index % width < width - 1: neighbors.append(index + 1)
		if index >= width: neighbors.append(index - width)
		if index < width * (height - 1): neighbors.append(index + width)
		for neighbor in neighbors:
			if visited[neighbor] == 0 and _background_pixel(bytes, neighbor * 4, mode):
				visited[neighbor] = 1
				queue.append(neighbor)
	return removed

static func _failure(error: String, background_removed: bool = false) -> Dictionary:
	return {"ok": false, "image": null, "error": error, "background_removed": background_removed}
