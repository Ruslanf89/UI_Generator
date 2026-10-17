extends RefCounted
## Local vector icon construction. The same recipe creates the same silhouette
## in every state; the caller handles palette reduction for the pixel style.

static func draw(parts: Array[String], w: int, h: int, name: String, gold: String, light: String, dark: String, rng: RandomNumberGenerator, recipe: Dictionary) -> void:
	var seeded := RandomNumberGenerator.new()
	seeded.seed = int(recipe.get("component_seed", rng.seed)) + int(name.hash()) * 71
	var variant: int = posmod(int(recipe.get("silhouette_index", seeded.randi_range(0, 5))), 6)
	var family: int = posmod(int(recipe.get("family_index", 0)), 4)
	var ornament: int = posmod(int(recipe.get("ornament_variant", 0)), 4)
	var gem: String = "#" + Color(str(recipe.get("gem", "67aaa0")).trim_prefix("#")).to_html(false)
	parts.append('<g transform="scale(%s %s)" stroke-linejoin="round" stroke-linecap="round">' % [w / 64.0, h / 64.0])
	match name:
		"sword": _sword(parts, variant, family, gold, light, dark, gem, seeded)
		"shield": _shield(parts, variant, family, gold, light, dark, gem, seeded)
		"potion": _potion(parts, variant, family, gold, light, dark, gem, seeded)
		"heart": _heart(parts, variant, family, gold, light, dark, gem, seeded)
		"mana": _mana(parts, variant, family, gold, light, dark, gem, seeded)
		"gear": _gear(parts, variant, family, gold, light, dark, gem, seeded)
		"bag": _bag(parts, variant, family, gold, light, dark, gem, seeded)
		"arrow": _arrow(parts, variant, family, gold, light, dark, gem, seeded)
		"star": _star(parts, variant, family, gold, light, dark, gem, seeded)
		"coin": _coin(parts, variant, family, gold, light, dark, gem, seeded)
		"scroll": _scroll(parts, variant, family, gold, light, dark, gem, seeded)
		"close": _close(parts, variant, family, gold, light, dark, gem, seeded)
		_: _shield(parts, variant, family, gold, light, dark, gem, seeded)
	# The larger silhouettes carry their own engraving. These small, deliberate
	# facets use the same recipe instead of a random glint that changes per state.
	if ornament > 1 and name in ["shield", "bag", "scroll"]:
		parts.append('<path d="M 10 30 l 2 -2 l 2 2 l -2 2 Z M 50 30 l 2 -2 l 2 2 l -2 2 Z" fill="%s" opacity=".7"/>' % light)
	parts.append('</g>')

static func _shape(parts: Array[String], path: String, fill: String, dark: String, width: float = 2.0) -> void:
	parts.append('<path d="%s" fill="%s" stroke="%s" stroke-width="%s"/>' % [path, fill, dark, width])

static func _line(parts: Array[String], path: String, color: String, width: float = 1.5, opacity: float = 1.0) -> void:
	parts.append('<path d="%s" fill="none" stroke="%s" stroke-width="%s" opacity="%s"/>' % [path, color, width, opacity])

static func _gem(parts: Array[String], x: float, y: float, radius: float, color: String, light: String, dark: String, cut: int = 0) -> void:
	if cut % 2 == 0:
		_shape(parts, 'M %s %s l %s %s l %s %s l %s %s Z' % [x, y - radius, radius, radius, -radius, radius, -radius, -radius], color, dark, 1.1)
		_line(parts, 'M %s %s l %s %s l %s %s' % [x - radius * .65, y, radius * .65, -radius * .65, radius * .35, radius * .35], light, 1.0, .85)
	else:
		parts.append('<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s" stroke="%s" stroke-width="1.1"/>' % [x, y, radius * .8, radius, color, dark])
		_line(parts, 'M %s %s q -%s %s 0 %s' % [x, y - radius * .6, radius * .5, radius * .3, radius * .6], light, 1.0, .85)

static func _rivet(parts: Array[String], x: float, y: float, gold: String, light: String, dark: String) -> void:
	parts.append('<circle cx="%s" cy="%s" r="1.6" fill="%s" stroke="%s" stroke-width=".65"/><path d="M %s %s l 1 -1" stroke="%s" stroke-width=".7"/>' % [x, y, gold, dark, x - .5, y + .2, light])

static func _emblem(parts: Array[String], family: int, x: float, y: float, size: float, gold: String, light: String, dark: String, gem: String, variant: int = 0) -> void:
	parts.append('<g transform="translate(%s %s) scale(%s)">' % [x, y, size / 12.0])
	match family:
		0:
			if variant % 2 == 0:
				_shape(parts, 'M -11 -5 L -7 5 H 7 L 11 -5 L 4 -1 L 0 -9 L -4 -1 Z', 'url(#gold)', dark, 1.1)
				_line(parts, 'M -7 7 H 7 M -6 3 H 6', light, 1.1)
			else:
				_shape(parts, 'M 0 9 Q -2 3 -6 0 Q -14 -3 -8 -8 Q -3 -9 -2 -3 Q -6 -11 0 -13 Q 6 -11 2 -3 Q 3 -9 8 -8 Q 14 -3 6 0 Q 2 3 0 9 Z', 'url(#gold)', dark, 1.1)
			_gem(parts, 0, 0, 2.3, gem, light, dark)
		1:
			_shape(parts, 'M -9 7 Q -12 -9 7 -11 Q 12 5 -9 7 Z', gem, dark, 1.2)
			_line(parts, 'M -11 11 L 5 -7 M -5 4 L -6 -2 M 0 -2 L 5 -1', gold, 1.5)
			_line(parts, 'M -7 3 Q -8 -5 3 -8', light, 1.0, .7)
		2:
			_shape(parts, 'M 0 -11 L 8 -3 L 0 1 L 8 7 L 0 11 L -8 3 L 0 -1 L -8 -7 Z', 'url(#gold)', dark, 1.2)
			_line(parts, 'M 0 -7 V 7', light, 1.0)
		3:
			_shape(parts, 'M 5 -11 Q -10 -10 -10 0 Q -10 11 5 11 Q -3 6 -3 0 Q -3 -6 5 -11 Z', 'url(#gold)', dark, 1.1)
			_shape(parts, 'M 6 -3 L 8 1 L 12 2 L 9 5 L 10 9 L 6 7 L 2 9 L 3 5 L 0 2 L 4 1 Z', gem, dark, .9)
	parts.append('</g>')

static func _sword(parts: Array[String], variant: int, family: int, gold: String, light: String, dark: String, gem: String, rng: RandomNumberGenerator) -> void:
	var wide: float = rng.randf_range(5.0, 8.0)
	var tip: float = rng.randf_range(3.0, 6.0)
	var blades: Array[String] = [
		'M 32 %s L %s 15 V 40 H %s V 15 Z' % [tip, 32 + wide, 32 - wide],
		'M 32 %s L 42 16 L 37 25 L 39 40 H 25 L 27 25 L 22 16 Z' % tip,
		'M 28 %s H 36 L 40 13 L 36 35 L 38 40 H 26 L 28 35 L 24 13 Z' % tip,
		'M 32 %s Q 45 18 37 40 H 26 Q 32 22 26 17 Z' % tip,
		'M 32 %s L 39 15 L 36 18 L 40 26 L 36 40 H 28 L 24 26 L 28 18 L 25 15 Z' % tip,
		'M 32 %s L 41 20 L 35 36 L 39 40 H 25 L 29 36 L 23 20 Z' % tip,
	]
	_shape(parts, blades[variant], 'url(#steel)', '#18212b', 2.1)
	_line(parts, 'M 32 %s L 32 39 M 32 14 L %s 22' % [tip + 3, 32 + wide * .55], '#eef8e8', 1.2, .85)
	_shape(parts, 'M 27 43 H 37 L 36 57 H 28 Z', '#66422d', dark, 1.7)
	for y in [46, 50, 54]:
		_line(parts, 'M 28 %s l 8 -2' % y, gold, 1.2, .85)
	match family:
		0: _shape(parts, 'M 13 37 L 21 39 L 27 36 H 37 L 43 39 L 51 37 L 46 46 L 36 43 H 28 L 18 46 Z', 'url(#gold)', dark)
		1: _shape(parts, 'M 13 43 Q 20 43 24 36 Q 24 42 31 39 Q 38 43 41 36 Q 43 44 51 42 L 47 47 Q 38 45 32 44 Q 23 45 17 48 Z', 'url(#gold)', dark)
		2: _shape(parts, 'M 14 38 H 24 V 35 H 40 V 38 H 50 V 46 H 40 V 43 H 24 V 46 H 14 Z', 'url(#gold)', dark)
		3: _shape(parts, 'M 13 35 Q 32 48 51 35 Q 48 47 35 46 H 29 Q 16 47 13 35 Z', 'url(#gold)', dark)
	_line(parts, 'M 19 41 H 26 M 38 41 H 45', light, 1.0)
	_gem(parts, 32, 40, 4.2, gem, light, dark, variant)
	_shape(parts, 'M 27 56 H 37 L 39 60 H 25 Z', 'url(#gold)', dark, 1.5)

static func _shield(parts: Array[String], variant: int, family: int, gold: String, light: String, dark: String, gem: String, rng: RandomNumberGenerator) -> void:
	var shoulder: float = rng.randf_range(7, 11)
	var shapes: Array[String] = [
		'M 32 4 Q 46 11 56 10 L 53 35 Q 49 49 32 60 Q 15 49 11 35 L 8 10 Q 18 11 32 4 Z',
		'M 32 3 L 55 12 V 30 Q 52 50 32 61 Q 12 50 9 30 V 12 Z',
		'M 15 5 H 49 L 56 16 L 51 42 L 32 59 L 13 42 L 8 16 Z',
		'M 12 6 H 25 L 32 10 L 39 6 H 52 V 36 L 44 49 L 32 60 L 20 49 L 12 36 Z',
		'M 32 4 Q 56 4 58 25 Q 59 48 32 60 Q 5 48 6 25 Q 8 4 32 4 Z',
		'M 32 4 L %s 10 L 12 21 L 9 26 L 14 42 L 32 60 L 50 42 L 55 26 L 52 21 L %s 10 Z' % [shoulder, 64 - shoulder],
	]
	_shape(parts, shapes[variant], 'url(#gold)', '#171c25', 2.2)
	parts.append('<g transform="translate(32 31) scale(.78 .78) translate(-32 -31)">')
	_shape(parts, shapes[variant], '#304d58' if family != 1 else '#345746', dark, 2.0)
	parts.append('</g>')
	_line(parts, 'M 16 15 Q 32 10 48 15 M 14 21 Q 14 41 29 53', light, 1.2, .75)
	_line(parts, 'M 32 14 V 49', '#a0c5bc', 1.0, .2)
	_emblem(parts, family, 32, 31, 11.0 + rng.randf_range(-1, 1), gold, light, dark, gem, variant)
	for point in [Vector2(13, 17), Vector2(51, 17), Vector2(32, 53)]:
		_rivet(parts, point.x, point.y, gold, light, dark)

static func _potion(parts: Array[String], variant: int, family: int, gold: String, light: String, dark: String, gem: String, rng: RandomNumberGenerator) -> void:
	var neck: float = rng.randf_range(6, 9)
	var l: float = 32 - neck
	var r: float = 32 + neck
	var outlines: Array[String] = [
		'M %s 12 H %s V 25 Q 55 31 55 45 Q 55 59 32 59 Q 9 59 9 45 Q 9 31 %s 25 Z' % [l, r, l],
		'M %s 12 H %s V 23 L 48 29 L 54 49 L 46 59 H 18 L 10 49 L 16 29 L %s 23 Z' % [l, r, l],
		'M %s 12 H %s V 29 L 50 37 V 54 L 44 59 H 20 L 14 54 V 37 L %s 29 Z' % [l, r, l],
		'M %s 12 H %s V 23 Q 48 25 51 38 Q 59 58 32 60 Q 5 58 13 38 Q 16 25 %s 23 Z' % [l, r, l],
		'M %s 12 H %s V 28 L 57 52 Q 58 59 49 59 H 15 Q 6 59 7 52 L %s 28 Z' % [l, r, l],
		'M %s 12 H %s V 25 Q 55 27 52 44 Q 49 52 43 58 H 21 Q 15 52 12 44 Q 9 27 %s 25 Z' % [l, r, l],
	]
	_shape(parts, outlines[variant], '#9bb5ad', '#1b2930', 2.2)
	parts.append('<defs><clipPath id="bottle"><path d="%s"/></clipPath></defs><g clip-path="url(#bottle)">' % outlines[variant])
	var liquid: String = 'blue' if family == 3 else 'red'
	parts.append('<path d="M 9 37 Q 20 32 32 37 Q 44 42 56 36 V 64 H 7 Z" fill="url(#%s)"/><path d="M 13 38 Q 24 34 34 38 Q 43 40 51 37" stroke="#ffe0ba" fill="none" stroke-width="1.4" opacity=".65"/>' % liquid)
	_line(parts, 'M 20 30 Q 12 38 17 48', '#edf6dc', 3.0, .8)
	parts.append('<circle cx="42" cy="46" r="2.2" fill="#ffedcd" opacity=".48"/><circle cx="39" cy="51" r="1.1" fill="#ffedcd" opacity=".55"/></g>')
	_shape(parts, 'M %s 6 H %s L %s 16 H %s Z' % [l - 1, r + 1, r - 1, l + 1], '#94613a', dark, 1.6)
	_line(parts, 'M %s 8 H %s M 30 7 L 29 13' % [l + 2, r - 2], '#e4b275', 1.0, .75)
	_shape(parts, 'M %s 17 H %s V 23 H %s Z' % [l - 2, r + 2, l - 2], 'url(#gold)', dark, 1.4)
	_line(parts, 'M %s 18 H %s' % [l, r], light, 1.0)
	if family == 1:
		_shape(parts, 'M 43 21 Q 58 18 54 29 Q 46 30 43 21 Z', '#52835f', dark, 1.2)
		_line(parts, 'M 44 22 L 51 26', gold, .9)
	elif family == 2:
		_shape(parts, 'M 29 22 H 35 V 29 L 32 32 L 29 29 Z', 'url(#gold)', dark, 1.0)
	else:
		_gem(parts, 32, 22, 3.2, gem, light, dark, variant)

static func _heart(parts: Array[String], variant: int, family: int, gold: String, light: String, dark: String, gem: String, rng: RandomNumberGenerator) -> void:
	var depth: float = rng.randf_range(17, 22)
	var forms: Array[String] = [
		'M 32 57 C 24 49 5 35 6 22 C 6 8 24 5 32 %s C 40 5 58 8 58 22 C 59 35 40 49 32 57 Z' % depth,
		'M 32 59 L 10 38 L 4 23 L 10 10 L 23 9 L 32 20 L 41 9 L 54 10 L 60 23 L 54 38 Z',
		'M 32 58 C 24 45 9 42 8 27 C 6 14 14 8 23 11 L 32 21 L 41 11 C 50 8 58 14 56 27 C 55 42 40 45 32 58 Z',
		'M 32 56 Q 5 42 5 24 Q 5 11 16 9 Q 26 8 32 20 Q 38 8 48 9 Q 59 11 59 24 Q 59 42 32 56 Z',
		'M 32 60 L 13 43 L 6 24 L 13 12 L 25 11 L 32 19 L 39 11 L 51 12 L 58 24 L 51 43 Z',
		'M 32 57 C 26 47 3 39 7 23 Q 10 11 21 12 Q 27 13 32 23 Q 37 13 43 12 Q 54 11 57 23 C 61 39 38 47 32 57 Z',
	]
	_shape(parts, forms[variant], 'url(#gold)', '#2a1724', 2.2)
	parts.append('<g transform="translate(32 32) scale(.86) translate(-32 -32)">')
	_shape(parts, forms[variant], 'url(#red)', dark, 1.3)
	parts.append('</g>')
	_line(parts, 'M 13 25 Q 12 16 22 15 M 15 30 l 1 3', '#ffdcaa', 2.4, .78)
	if family == 0:
		_shape(parts, 'M 22 12 L 19 4 L 28 8 L 32 2 L 36 8 L 45 4 L 42 12 Z', 'url(#gold)', dark, 1.3)
		_gem(parts, 32, 9, 2.1, gem, light, dark)
	elif family == 1:
		_shape(parts, 'M 9 35 Q 0 29 5 19 Q 15 23 9 35 Z M 55 35 Q 64 29 59 19 Q 49 23 55 35 Z', '#568461', dark, 1.2)
		_line(parts, 'M 9 34 L 6 23 M 55 34 L 58 23', gold, 1)
	elif family == 2:
		_shape(parts, 'M 24 30 H 29 V 25 H 35 V 30 H 40 V 36 H 35 V 41 H 29 V 36 H 24 Z', 'url(#gold)', dark, 1.1)
	else:
		_line(parts, 'M 16 43 Q 32 56 48 43 M 16 45 Q 32 58 48 45', gold, 1.2, .9)
		_gem(parts, 32, 52, 2.6, gem, light, dark)

static func _mana(parts: Array[String], variant: int, family: int, gold: String, light: String, dark: String, gem: String, rng: RandomNumberGenerator) -> void:
	var shoulder: float = rng.randf_range(19, 25)
	var shapes: Array[String] = [
		'M 32 3 L 52 22 L 46 47 L 32 60 L 18 47 L 12 22 Z',
		'M 32 3 L 45 15 L 51 36 L 42 55 L 32 61 L 22 55 L 13 36 L 19 15 Z',
		'M 27 4 H 37 L 51 22 V 43 L 37 60 H 27 L 13 43 V 22 Z',
		'M 32 3 L 46 14 L 43 24 L 53 36 L 44 51 L 32 61 L 20 51 L 11 36 L 21 24 L 18 14 Z',
		'M 32 3 L 49 %s L 47 43 L 32 60 L 17 43 L 15 %s Z' % [shoulder, shoulder],
		'M 32 3 L 44 21 L 54 27 L 44 48 L 32 60 L 20 48 L 10 27 L 20 21 Z',
	]
	_shape(parts, shapes[variant], 'url(#blue)', '#172836', 2.1)
	_line(parts, 'M 32 4 L 26 25 L 32 58 M 26 25 L 14 24 M 26 25 L 50 24 M 26 25 L 19 46 M 26 25 L 45 46', '#a9eee6', 1.5, .8)
	_shape(parts, 'M 32 7 L 29 22 L 42 21 Z', '#e0fff0', '#b1ebe0', .4)
	if family == 1:
		_shape(parts, 'M 16 46 Q 3 42 8 31 Q 17 33 18 43 L 24 49 Z M 48 46 Q 61 42 56 31 Q 47 33 46 43 L 40 49 Z', '#4e7b60', dark, 1.3)
	elif family == 2:
		_shape(parts, 'M 17 44 L 22 49 H 27 V 55 H 37 V 49 H 42 L 47 44 V 53 L 40 59 H 24 L 17 53 Z', 'url(#gold)', dark, 1.3)
	elif family == 3:
		parts.append('<ellipse cx="32" cy="34" rx="26" ry="8" transform="rotate(-22 32 34)" fill="none" stroke="%s" stroke-width="2"/>' % gold)
		_gem(parts, 9, 42, 2.3, gem, light, dark)
	else:
		_shape(parts, 'M 16 44 L 22 46 L 25 53 H 39 L 42 46 L 48 44 L 44 55 L 39 59 H 25 L 20 55 Z', 'url(#gold)', dark, 1.3)

static func _gear(parts: Array[String], variant: int, family: int, gold: String, light: String, dark: String, gem: String, rng: RandomNumberGenerator) -> void:
	var teeth: int = [8, 10, 6, 9, 7, 12][variant]
	var radius: float = rng.randf_range(26, 29)
	var points := PackedVector2Array()
	for i in range(teeth):
		for corner in range(4):
			var angle: float = -PI * .5 + (i + [.06, .2, .55, .7][corner]) * TAU / teeth
			var r: float = radius if corner in [1, 2] else radius - 5
			points.append(Vector2(32, 32) + Vector2.from_angle(angle) * r)
	var path: String = 'M '
	for point in points:
		path += '%s %s ' % [point.x, point.y]
	path += 'Z'
	_shape(parts, path, 'url(#gold)', '#20212a', 2.0)
	parts.append('<circle cx="32" cy="32" r="19" fill="url(#steel)" stroke="%s" stroke-width="1.5"/><circle cx="32" cy="32" r="12" fill="#30414b" stroke="%s" stroke-width="2"/>' % [dark, light])
	if family == 2:
		_shape(parts, 'M 26 25 H 38 V 39 H 26 Z', '#18232c', gold, 1.2)
	elif family == 3:
		_shape(parts, 'M 35 22 Q 21 22 22 33 Q 23 43 36 42 Q 29 38 29 32 Q 29 26 35 22 Z', gem, gold, 1.0)
	else:
		parts.append('<circle cx="32" cy="32" r="7" fill="#17222a" stroke="%s" stroke-width="1.5"/>' % gold)
	for i in range(4 if family != 2 else 6):
		var angle: float = i * TAU / (4 if family != 2 else 6) + rng.randf_range(-.05, .05)
		_rivet(parts, 32 + cos(angle) * 15, 32 + sin(angle) * 15, gold, light, dark)
	_line(parts, 'M 18 18 Q 31 7 44 18', light, 1.1, .65)

static func _bag(parts: Array[String], variant: int, family: int, gold: String, light: String, dark: String, gem: String, rng: RandomNumberGenerator) -> void:
	var width: float = rng.randf_range(20, 24)
	var shapes: Array[String] = [
		'M 22 5 Q 32 12 42 5 L 39 22 Q 55 34 55 49 Q 53 60 32 59 Q 11 60 9 49 Q 9 34 25 22 Z',
		'M 21 6 L 30 10 L 41 5 L 38 22 L 50 32 L 57 51 L 49 59 H 15 L 7 51 L 14 32 L 26 22 Z',
		'M 22 6 H 42 L 39 23 Q 56 29 53 47 L 49 58 H 15 L 11 47 Q 8 29 25 23 Z',
		'M 18 6 L 31 11 L 45 6 L 39 24 L 52 35 L 55 51 Q 53 59 32 60 Q 11 59 9 51 L 12 35 L 25 24 Z',
		'M 20 6 Q 32 1 44 6 L 38 22 Q 49 25 %s 38 L %s 54 L 42 60 H 22 L %s 54 L %s 38 Q 15 25 26 22 Z' % [32 + width, 30 + width, 34 - width, 32 - width],
		'M 23 4 L 31 10 L 41 4 L 44 13 L 39 23 Q 59 38 53 54 L 44 60 H 20 L 11 54 Q 5 38 25 23 L 20 13 Z',
	]
	_shape(parts, shapes[variant], 'url(#face)', '#231a20', 2.2)
	_line(parts, 'M 20 13 L 27 23 M 32 12 V 22 M 43 12 L 37 23 M 19 35 Q 12 47 19 53 M 45 35 Q 51 47 45 53', '#efc17e', 1.6, .55)
	_line(parts, 'M 23 24 Q 32 28 41 24 M 23 27 Q 32 30 41 27', gold, 2.4)
	_line(parts, 'M 39 26 Q 50 28 46 37 L 43 39 M 40 27 Q 35 32 41 37', dark, 2.4)
	_line(parts, 'M 39 26 Q 49 28 45 36', light, 1.1)
	parts.append('<ellipse cx="32" cy="44" rx="12" ry="11" fill="#241c20" stroke="%s" stroke-width="1.2"/>' % gold)
	_emblem(parts, family, 32, 44, 8.7, gold, light, dark, gem, variant)
	if family == 2:
		for point in [Vector2(15, 39), Vector2(49, 39), Vector2(17, 52), Vector2(47, 52)]:
			_rivet(parts, point.x, point.y, gold, light, dark)

static func _arrow(parts: Array[String], variant: int, family: int, gold: String, light: String, dark: String, gem: String, rng: RandomNumberGenerator) -> void:
	var center: float = rng.randf_range(27, 34)
	var forms: Array[String] = [
		'M 5 25 H 36 V 10 L 59 32 L 36 54 V 39 H 5 Z',
		'M 4 24 L 12 28 H 36 V 9 L 60 32 L 36 55 V 36 H 12 L 4 40 L 8 32 Z',
		'M 4 27 H 32 L 30 12 L 59 28 V 36 L 30 52 L 32 37 H 4 Z',
		'M 5 23 H 33 V 12 L 43 16 L 60 32 L 43 48 L 33 52 V 41 H 5 L 10 32 Z',
		'M 5 26 H %s V 12 L 59 32 L %s 52 V 38 H 5 L 9 32 Z' % [center + 7, center + 7],
		'M 4 25 L 13 22 L 17 26 H 34 V 9 L 57 26 L 61 32 L 57 38 L 34 55 V 38 H 17 L 13 42 L 4 39 L 8 32 Z',
	]
	_shape(parts, forms[variant], 'url(#gold)', '#211d23', 2.0)
	_shape(parts, 'M 10 29 H 40 V 21 L 52 32 L 40 43 V 35 H 10 Z', 'url(#face)', dark, 1.0)
	_line(parts, 'M 11 27 H 38 V 17 L 54 31', light, 1.3, .9)
	if family == 1:
		_line(parts, 'M 13 32 H 35 M 18 32 l 5 -5 M 25 32 l 5 5', gold, 1.3)
	elif family == 2:
		_shape(parts, 'M 21 25 H 27 V 39 H 21 Z', 'url(#steel)', dark, 1.1)
		_rivet(parts, 24, 28, gold, light, dark)
	else:
		_gem(parts, 23, 32, 3.4, gem, light, dark, variant)

static func _star(parts: Array[String], variant: int, family: int, gold: String, light: String, dark: String, gem: String, rng: RandomNumberGenerator) -> void:
	var points: int = [5, 6, 4, 8, 5, 6][variant]
	var inner: float = rng.randf_range(10, 15)
	var path: String = 'M '
	for i in range(points * 2):
		var angle: float = -PI * .5 + i * PI / points
		var radius: float = 28 if i % 2 == 0 else inner
		if variant == 2 and i % 4 == 0:
			radius = 30
		var point: Vector2 = Vector2(32, 32) + Vector2.from_angle(angle) * radius
		path += '%s %s ' % [point.x, point.y]
	_shape(parts, path + 'Z', 'url(#gold)', '#241c26', 2.0)
	for i in range(points):
		var angle: float = -PI * .5 + i * TAU / points
		var point: Vector2 = Vector2(32, 32) + Vector2.from_angle(angle) * 25
		_line(parts, 'M 32 32 L %s %s' % [point.x, point.y], light if i % 2 == 0 else dark, 1.2, .65)
	if family == 3:
		parts.append('<circle cx="32" cy="32" r="13" fill="#273747" stroke="%s" stroke-width="1.5"/>' % gold)
		_emblem(parts, family, 32, 32, 8.0, gold, light, dark, gem)
	else:
		_gem(parts, 32, 32, 6.5 if family == 0 else 5.0, gem, light, dark, variant)

static func _coin(parts: Array[String], variant: int, family: int, gold: String, light: String, dark: String, gem: String, rng: RandomNumberGenerator) -> void:
	var radius: float = rng.randf_range(23.5, 26)
	var sides: int = [0, 8, 6, 12, 0, 10][variant]
	var path: String = ''
	if sides == 0:
		path = 'M 32 %s A %s %s 0 1 1 31.99 %s Z' % [32 - radius, radius, radius, 32 - radius]
	else:
		path = 'M '
		for i in range(sides):
			var point: Vector2 = Vector2(32, 32) + Vector2.from_angle(-PI * .5 + i * TAU / sides) * radius
			path += '%s %s ' % [point.x, point.y]
		path += 'Z'
	parts.append('<g transform="translate(1.5 2)">')
	_shape(parts, path, dark, '#1f1e25', 2.0)
	parts.append('</g>')
	_shape(parts, path, 'url(#gold)', '#29202a', 2.0)
	parts.append('<circle cx="32" cy="32" r="%s" fill="none" stroke="%s" stroke-width="1.3"/><circle cx="32" cy="32" r="%s" fill="#8e632e" fill-opacity=".4" stroke="%s" stroke-width=".8"/>' % [radius - 4, light, radius - 6.5, dark])
	for i in range(12):
		var angle: float = i * TAU / 12
		var inner: Vector2 = Vector2(32, 32) + Vector2.from_angle(angle) * (radius - 3.2)
		var outer: Vector2 = Vector2(32, 32) + Vector2.from_angle(angle) * (radius - 1.6)
		_line(parts, 'M %s %s L %s %s' % [inner.x, inner.y, outer.x, outer.y], dark, .9, .8)
	_emblem(parts, family, 32, 32, 12.0, gold, light, dark, gem, variant)
	_line(parts, 'M 17 14 Q 31 5 45 15', light, 1.4, .8)

static func _scroll(parts: Array[String], variant: int, family: int, gold: String, light: String, dark: String, gem: String, rng: RandomNumberGenerator) -> void:
	var left: float = rng.randf_range(12, 17)
	var right: float = rng.randf_range(46, 50)
	var bottom: float = 53 if variant % 2 == 0 else 57
	var shapes: Array[String] = [
		'M %s 8 H %s V %s H 12 Q 19 48 15 42 Z' % [left, right, bottom],
		'M %s 8 H %s L 47 40 L 51 %s H 13 L 17 43 Z' % [left, right, bottom],
		'M %s 8 H %s L 45 43 L 48 %s H 13 L 17 40 L 13 25 Z' % [left, right, bottom],
		'M %s 8 H %s L 48 24 L 43 41 L 49 %s H 12 L 18 40 Z' % [left, right, bottom],
		'M %s 8 H %s V 42 L 45 47 L 49 %s H 12 L 18 44 Z' % [left, right, bottom],
		'M %s 8 H %s L 47 17 L 50 29 L 45 42 L 49 %s H 12 L 17 42 L 14 24 Z' % [left, right, bottom],
	]
	_shape(parts, shapes[variant], '#e6c98d', '#4b3024', 2.0)
	_shape(parts, 'M %s 8 Q 4 4 6 18 H 17 Q 13 14 %s 8 Z' % [left, left], '#b1844e', '#4b3024', 1.6)
	_shape(parts, 'M 16 %s Q 6 62 8 48 H 37 Q 33 57 44 57 Q 57 58 55 47 H 38' % bottom, '#c29c61', '#4b3024', 1.7)
	_line(parts, 'M 19 12 H 44 M 20 47 H 31', '#fff0b9', 1.3, .85)
	_line(parts, 'M 22 36 H 40 M 21 41 H 36', '#7f5936', 1.4, .65)
	_emblem(parts, family, 32, 25, 8.6, gold, light, dark, gem, variant)
	if family == 2:
		_line(parts, 'M 21 14 V 19 H 25 M 43 14 V 19 H 39', '#805731', 1.4)
	elif family == 3:
		_line(parts, 'M 20 18 l 1 -2 l 1 2 M 42 35 l 1 -2 l 1 2', '#7c6547', 1.2)

static func _close(parts: Array[String], variant: int, family: int, gold: String, light: String, dark: String, gem: String, rng: RandomNumberGenerator) -> void:
	var half: float = rng.randf_range(4.0, 6.0)
	var end: float = 12 + variant % 3
	var paths: Array[String] = [
		'M 15 6 L 32 23 L 49 6 L 58 15 L 41 32 L 58 49 L 49 58 L 32 41 L 15 58 L 6 49 L 23 32 L 6 15 Z',
		'M 14 7 L 32 25 L 50 7 L 57 14 L 39 32 L 57 50 L 50 57 L 32 39 L 14 57 L 7 50 L 25 32 L 7 14 Z',
		'M 10 7 H 19 L 32 20 L 45 7 H 54 V 16 L 38 32 L 54 48 V 57 H 45 L 32 44 L 19 57 H 10 V 48 L 26 32 L 10 16 Z',
		'M 12 6 L 32 24 L 52 6 L 58 12 L 40 32 L 58 52 L 52 58 L 32 40 L 12 58 L 6 52 L 24 32 L 6 12 Z',
		'M %s 7 L 32 %s L %s 7 L 57 %s L %s 32 L 57 %s L %s 57 L 32 %s L %s 57 L 7 %s L %s 32 L 7 %s Z' % [end, 32 - half * 1.5, 64 - end, end, 32 + half * 1.5, 64 - end, 64 - end, 32 + half * 1.5, end, 64 - end, 32 - half * 1.5, end],
		'M 12 5 L 21 10 L 32 23 L 43 10 L 52 5 L 59 12 L 54 21 L 41 32 L 54 43 L 59 52 L 52 59 L 43 54 L 32 41 L 21 54 L 12 59 L 5 52 L 10 43 L 23 32 L 10 21 L 5 12 Z',
	]
	_shape(parts, paths[variant], 'url(#gold)', '#241c26', 2.0)
	_line(parts, 'M %s 13 L 32 29 L %s 13 M 12 49 L 28 32' % [end, 64 - end], light, 1.4, .85)
	if family == 2:
		_shape(parts, 'M 26 26 H 38 V 38 H 26 Z', 'url(#steel)', dark, 1.3)
		_rivet(parts, 32, 32, gold, light, dark)
	else:
		_gem(parts, 32, 32, 4.5, gem, light, dark, variant)
	if family == 1:
		_line(parts, 'M 14 18 L 25 29 M 14 18 L 15 24 M 50 18 L 39 29 M 50 18 L 49 24', '#365a45', 1.3)
