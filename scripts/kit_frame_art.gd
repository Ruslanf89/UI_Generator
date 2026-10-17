extends RefCounted
## Seed-driven silhouettes and heraldic construction for the four offline houses.

static func shape(x: float, y: float, w: float, h: float, depth: float, recipe: Dictionary, role: String = "panel") -> String:
	var cut: float = clampf(depth, .7, minf(w, h) * .24)
	var right: float = x + w
	var bottom: float = y + h
	var cx: float = x + w * .5
	var cy: float = y + h * .5
	var variant: int = int(recipe.get("silhouette_index", 0))
	if role == "banner":
		cut = minf(cut * 1.45, h * .3)
	match variant:
		1: # A shallow arch leaves the center available for editable labels.
			return 'M %s %s Q %s %s %s %s V %s Q %s %s %s %s Z' % [x, y + cut, cx, y - cut, right, y + cut, bottom - cut, cx, bottom + cut, x, bottom - cut]
		2: # Scalloped shoulders and a little recessed central notch.
			return 'M %s %s Q %s %s %s %s H %s Q %s %s %s %s H %s Q %s %s %s %s V %s Q %s %s %s %s H %s Q %s %s %s %s H %s Q %s %s %s %s Z' % [x, y + cut, x, y, x + cut, y, cx - cut, cx, y + cut * .65, cx + cut, y, right - cut, right, y, right, y + cut, bottom - cut, right, bottom, right - cut, bottom, cx + cut, cx, bottom - cut * .65, cx - cut, bottom, x + cut, x, bottom, x, bottom - cut]
		3: # Layered smith's plates have genuine rectangular steps in the edge.
			return 'M %s %s H %s V %s H %s V %s H %s V %s H %s V %s H %s V %s H %s V %s H %s V %s H %s V %s H %s V %s H %s Z' % [x + cut * 1.8, y, right - cut * 1.8, y + cut * .5, right - cut * .5, y + cut * 1.8, right, bottom - cut * 1.8, right - cut * .5, bottom - cut * .5, right - cut * 1.8, bottom, x + cut * 1.8, bottom - cut * .5, x + cut * .5, bottom - cut * 1.8, x, y + cut * 1.8, x + cut * .5, y + cut * .5, x + cut * 1.8]
		4: # A six-sided crystal plaque.
			return 'M %s %s H %s L %s %s L %s %s H %s L %s %s Z' % [x + cut, y, right - cut, right, cy, right - cut, bottom, x + cut, x, cy]
		5: # Rolled parchment-like ends and pinched, curved sides.
			return 'M %s %s H %s Q %s %s %s %s C %s %s %s %s %s %s Q %s %s %s %s H %s Q %s %s %s %s C %s %s %s %s %s %s Q %s %s %s %s Z' % [x + cut, y, right - cut, right, y, right, y + cut, right - cut, cy - cut, right - cut, cy + cut, right, bottom - cut, right, bottom, right - cut, bottom, x + cut, x, bottom, x, bottom - cut, x + cut, cy + cut, x + cut, cy - cut, x, y + cut, x, y, x + cut, y]
		_:
			return 'M %s %s H %s L %s %s V %s L %s %s H %s L %s %s V %s Z' % [x + cut, y, right - cut, right, y + cut, bottom - cut, right - cut, bottom, x + cut, x, bottom - cut, y + cut]

static func border(parts: Array[String], w: int, h: int, trim: float, recipe: Dictionary, gold: String, light: String, dark: String, role: String) -> void:
	var family: int = int(recipe.get("family_index", 0))
	var variant: int = int(recipe.get("frame_variant", 0))
	var step_size: int = 13 + variant * 3
	if role in ["button", "bar_frame", "slot"]:
		step_size += 5
	# Different methods of construction are visible even with Simple ornaments.
	match family:
		0:
			for y in [trim * .48, h - trim * .48 - 1]:
				parts.append('<path d="M %s %s H %s" stroke="%s" stroke-width=".75" opacity=".7"/>' % [trim * 2, y, w - trim * 2, light])
				if variant % 2 == 1 and w > 90:
					for x in range(int(trim * 2.2), int(w - trim * 2), step_size):
						parts.append('<path d="M %s %s l 3 -1.3 l 3 1.3 l -3 1.3 Z" fill="%s" opacity=".5"/>' % [x, y, dark])
		1:
			for y in [trim * .45, h - trim * .45 - 1]:
				parts.append('<path d="M %s %s Q %s %s %s %s T %s %s" fill="none" stroke="%s" stroke-width="1.1" opacity=".75"/>' % [trim * 2, y, w * .25, y - trim * .32, w * .5, y, w - trim * 2, y, dark])
		2:
			for y in [trim * .5, h - trim * .5 - 1]:
				for x in range(int(trim * 2), int(w - trim * 2), step_size):
					parts.append('<path d="M %d %s l 3 %s h 6 l 3 -%s" fill="none" stroke="%s" stroke-width="1.1" opacity=".8"/>' % [x, y, trim * .18, trim * .18, dark])
		3:
			for y in [trim * .5, h - trim * .5 - 1]:
				parts.append('<path d="M %s %s H %s" stroke="%s" stroke-width=".7" opacity=".65"/>' % [trim * 2, y, w - trim * 2, light])
				if w > 80:
					for x in range(int(trim * 2), int(w - trim * 2), step_size + 5):
						parts.append('<circle cx="%d" cy="%s" r="1" fill="%s"/>' % [x, y, gold])

static func decorate(parts: Array[String], w: int, h: int, trim: float, recipe: Dictionary, gold: String, light: String, dark: String, role: String, ornaments: String) -> void:
	var family: int = int(recipe.get("family_index", 0))
	var variant: int = int(recipe.get("ornament_variant", 0))
	var gem: String = "#" + str(recipe.get("gem", "8aa69a")).trim_prefix("#")
	if role == "bar_frame":
		for side in [0, 1]:
			var x: float = trim * .75 if side == 0 else w - trim * .75
			if family in [0, 2]:
				_rivet(parts, x, h * .5, maxf(.8, trim * .27), light, dark)
			else:
				parts.append('<path d="M %s %s l %s -2 l %s 2 l -%s 2 Z" fill="%s" stroke="%s" stroke-width=".5"/>' % [x - 1, h * .5, trim * .4, trim * .4, trim * .4, gem, light])
		return
	if ornaments == "Simple":
		for x in [trim * .7, w - trim * .7]:
			_rivet(parts, x, h * .5, maxf(.9, trim * .22), light, dark)
		return
	var rich: bool = ornaments == "Rich"
	if role == "button":
		var size: float = minf(h * .3, 19)
		for side in [0, 1]:
			var x: float = trim + size * .4 if side == 0 else w - trim - size * .4
			parts.append('<g transform="translate(%s %s) scale(%s %s)">' % [x, h * .5, size / 24.0 * (1 if side == 0 else -1), size / 24.0])
			_emblem(parts, family, variant, gold, light, dark, gem, rich)
			parts.append('</g>')
		return
	var size: float = minf(minf(w, h) * .26, 36 + variant * 2)
	if role == "slot": size = minf(size, 18)
	if role == "banner": size = minf(size, 26)
	for side_x in [0, 1]:
		for side_y in [0, 1]:
			var x: float = 0 if side_x == 0 else w
			var y: float = 0 if side_y == 0 else h
			parts.append('<g transform="translate(%s %s) scale(%s %s)">' % [x, y, size / 36.0 * (1 if side_x == 0 else -1), size / 36.0 * (1 if side_y == 0 else -1)])
			_corner(parts, family, variant, gold, light, dark, gem, rich)
			parts.append('</g>')
	if w > 115 and role != "slot":
		var crest_width: float = minf(w * .16, 74.0) * (1.25 if rich else 1.0)
		var crest_height: float = minf(h * .16, 19.0)
		for bottom in [false, true]:
			var cy: float = crest_height * .62 if not bottom else h - crest_height * .62 - 1
			parts.append('<g transform="translate(%s %s) scale(%s %s)">' % [w * .5, cy, crest_width / 64.0, crest_height / 24.0 * (1 if not bottom else -1)])
			_crest(parts, family, variant, gold, light, dark, gem, rich)
			parts.append('</g>')

static func _rivet(parts: Array[String], x: float, y: float, radius: float, light: String, dark: String) -> void:
	parts.append('<circle cx="%s" cy="%s" r="%s" fill="%s"/><circle cx="%s" cy="%s" r="%s" fill="url(#gold)" stroke="%s" stroke-width=".5"/><path d="M %s %s l %s -%s" stroke="%s" stroke-width=".8"/>' % [x, y + .7, radius + .6, dark, x, y, radius, light, x - radius * .5, y + radius * .3, radius, radius * .6, dark])

static func _corner(parts: Array[String], family: int, variant: int, gold: String, light: String, dark: String, gem: String, rich: bool) -> void:
	match family:
		0:
			parts.append('<path d="M 3 33 C 2 14 8 7 33 3 L 28 10 Q 15 12 11 21 L 9 31 Z" fill="url(#gold)" stroke="%s" stroke-width="1"/>' % dark)
			for i in range(3 if rich else 2):
				parts.append('<path d="M %s %s Q %s 8 %s 6" fill="none" stroke="%s" stroke-width="1.2"/>' % [6 + i * 3, 26 - i * 5, 12 + i * 5, 27 - i * 4, light])
			if variant % 2 == 0:
				parts.append('<path d="M 14 14 Q 20 4 20 13 Q 29 9 23 17 Q 20 20 17 18 Q 17 25 13 21 Z" fill="%s" stroke="%s" stroke-width=".8"/>' % [gold, dark])
			else:
				parts.append('<path d="M 12 10 L 18 15 L 24 7 L 24 20 L 12 24 Z" fill="%s" stroke="%s"/>' % [gem, light])
		1:
			parts.append('<path d="M 4 35 Q 9 19 8 9 Q 18 13 35 4 M 7 21 Q 18 20 24 12 M 9 10 L 5 4" fill="none" stroke="%s" stroke-width="5"/><path d="M 4 35 Q 9 19 8 9 Q 18 13 35 4" fill="none" stroke="%s" stroke-width="2"/>' % [dark, gold])
			for i in range(3 if rich else 2):
				var x: float = 9 + i * 8
				var y: float = 20 - i * 5
				parts.append('<path d="M %s %s Q %s %s %s %s Q %s %s %s %s Z" fill="%s" stroke="%s" stroke-width=".7"/><path d="M %s %s l 7 -7" stroke="%s" stroke-width=".7"/>' % [x, y, x - 4, y - 9, x + 7, y - 10, x + 10, y - 1, x, y, gem, dark, x, y, light])
			if variant % 2 == 1:
				parts.append('<path d="M 8 29 C 26 34 30 15 18 17 C 10 18 17 26 21 21" fill="none" stroke="%s" stroke-width="1.5"/>' % gold)
		2:
			parts.append('<path d="M 2 30 V 13 H 8 V 6 H 27 L 33 12 H 18 V 18 H 12 V 33 Z" fill="url(#steel)" stroke="%s" stroke-width="1.1"/><path d="M 4 27 V 15 H 10 V 8 H 25" fill="none" stroke="%s"/>' % [dark, light])
			_rivet(parts, 7, 20, 2.5, light, dark)
			_rivet(parts, 19, 10, 2.5, light, dark)
			if rich:
				parts.append('<path d="M 15 23 l 6 -6 l 5 5 l -5 7 Z" fill="%s" stroke="%s"/><path d="M 18 25 l 6 -5 m -3 2 l -3 -3" stroke="%s"/>' % [gem, dark, light])
		3:
			parts.append('<path d="M 7 30 A 23 23 0 0 1 30 7 A 17 17 0 0 0 7 30 Z" fill="url(#gold)" stroke="%s" stroke-width=".8"/><path d="M 4 31 A 28 28 0 0 1 31 4" fill="none" stroke="%s" stroke-width=".8"/>' % [dark, light])
			parts.append('<path d="M 15 12 L 22 19 L 15 28 L 10 20 Z" fill="%s" stroke="%s"/><path d="M 15 12 L 14 20 L 22 19 M 14 20 L 15 28" fill="none" stroke="%s" opacity=".7"/>' % [gem, gold, light])
			if rich:
				parts.append('<path d="M 29 10 l 1.5 4 l 4 1.5 l -4 1.5 l -1.5 4 l -1.5 -4 l -4 -1.5 l 4 -1.5 Z" fill="%s"/><circle cx="9" cy="6" r="1.5" fill="%s"/>' % [light, gem])

static func _emblem(parts: Array[String], family: int, variant: int, gold: String, light: String, dark: String, gem: String, rich: bool) -> void:
	match family:
		0:
			parts.append('<path d="M -5 10 L -11 -5 L -3 -1 L 0 -15 L 4 -1 L 12 -5 L 6 10 Z" fill="url(#gold)" stroke="%s" stroke-width="1.3"/><path d="M -5 8 H 6 M -1 -6 V 4" stroke="%s"/>' % [dark, light])
		1:
			parts.append('<path d="M -8 13 Q -12 -9 8 -15 Q 15 4 -8 13 Z" fill="%s" stroke="%s" stroke-width="1.4"/><path d="M -8 13 L 7 -12 M -3 4 L -6 -2 M 1 -3 L 7 -3" fill="none" stroke="%s" stroke-width="1.1"/>' % [gem, gold, light])
		2:
			parts.append('<path d="M -10 -7 L -3 -13 H 5 L 11 -7 V 7 L 5 13 H -4 L -10 7 Z" fill="url(#steel)" stroke="%s"/><path d="M -4 8 V -7 L 5 -1 L -4 4 M 0 -4 L 5 -9" fill="none" stroke="%s" stroke-width="2"/>' % [dark, gem])
		3:
			if variant % 2 == 0:
				parts.append('<path d="M 3 -14 A 15 15 0 1 0 3 14 A 11 11 0 0 1 3 -14 Z" fill="url(#gold)" stroke="%s"/><path d="M 5 -5 l 2 5 l 5 2 l -5 2 l -2 5 l -2 -5 l -5 -2 l 5 -2 Z" fill="%s"/>' % [dark, gem])
			else:
				parts.append('<path d="M 0 -15 L 8 0 L 0 15 L -8 0 Z" fill="%s" stroke="%s"/><ellipse rx="14" ry="5" fill="none" stroke="%s" transform="rotate(-30)"/>' % [gem, light, gold])
	if rich:
		parts.append('<circle cx="0" cy="0" r="2.4" fill="%s" stroke="%s" stroke-width=".6"/>' % [gem, light])

static func _crest(parts: Array[String], family: int, variant: int, gold: String, light: String, dark: String, gem: String, rich: bool) -> void:
	match family:
		0:
			parts.append('<path d="M -30 0 Q -16 -1 -9 8 L -15 -4 L -5 1 L 0 -10 L 5 1 L 15 -4 L 9 8 Q 16 -1 30 0 L 20 7 L 8 11 H -8 L -20 7 Z" fill="url(#gold)" stroke="%s"/><path d="M -22 3 L -11 8 M 22 3 L 11 8 M -8 8 H 8" stroke="%s"/>' % [dark, light])
		1:
			parts.append('<path d="M -30 2 Q -15 15 0 3 Q 15 15 30 2 M 0 3 V -6" fill="none" stroke="%s" stroke-width="3"/><path d="M -22 7 Q -25 -5 -12 0 Q -11 8 -22 7 M 22 7 Q 25 -5 12 0 Q 11 8 22 7 M 0 4 Q -11 -6 0 -12 Q 11 -6 0 4 Z" fill="%s" stroke="%s" stroke-width=".8"/>' % [gold, gem, light])
		2:
			parts.append('<path d="M -32 1 H -20 V -3 H -11 V -7 H 11 V -3 H 20 V 1 H 32 V 5 H 18 V 9 H -18 V 5 H -32 Z" fill="url(#steel)" stroke="%s"/><path d="M -6 4 V -4 L 2 0 L -6 4 M 6 -4 V 5" fill="none" stroke="%s" stroke-width="1.5"/>' % [dark, gem])
		3:
			parts.append('<path d="M -29 0 Q -13 16 0 0 Q 13 16 29 0 M -24 0 Q -12 9 0 -4 Q 12 9 24 0" fill="none" stroke="%s" stroke-width="1.4"/><path d="M 0 -12 L 5 -2 L 0 9 L -5 -2 Z" fill="%s" stroke="%s"/><circle cx="-24" cy="0" r="2" fill="%s"/><circle cx="24" cy="0" r="2" fill="%s"/>' % [gold, gem, light, light, light])
	if rich and variant % 2 == 1:
		parts.append('<path d="M -34 2 l -5 4 l 5 3 l 5 -3 Z M 34 2 l 5 4 l -5 3 l -5 -3 Z" fill="%s" stroke="%s" stroke-width=".8"/>' % [gem, gold])

static func fill(parts: Array[String], w: int, h: int, role: String, recipe: Dictionary, rng: RandomNumberGenerator) -> void:
	var family: int = int(recipe.get("family_index", 0))
	var variant: int = int(recipe.get("frame_variant", 0))
	var depth: float = minf(h * rng.randf_range(.15, .3), 7)
	var path: String = shape(1, 1, w - 2, h - 2, depth, recipe, role)
	var gradient: String = "red" if role == "fill_health" else "blue"
	parts.append('<defs><clipPath id="liquid"><path d="%s"/></clipPath></defs><path d="%s" fill="url(#%s)" stroke="#151c2b" stroke-width="1"/><g clip-path="url(#liquid)">' % [path, path, gradient])
	var step_size: int = 18 + variant * 7
	match family:
		0:
			for x in range(3, w, step_size):
				parts.append('<path d="M %d 1 l %d %d l -%d 0 Z" fill="#fff8df" opacity=".15"/><path d="M %d %s l 3 -3 l 3 3 l -3 3 Z" fill="#fff7d1" opacity=".26"/>' % [x, step_size / 2, h, step_size / 3, x + step_size / 2, h * .5])
		1:
			for i in range(3):
				var y: float = h * (.25 + i * .23)
				parts.append('<path d="M 0 %s Q %s %s %s %s T %s %s" fill="none" stroke="#e9ffdc" stroke-width="%s" opacity=".22"/>' % [y, w * .22, y - h * .3, w * .48, y, w, y, 1 + variant * .2])
		2:
			for x in range(step_size, w, step_size):
				parts.append('<path d="M %d 1 V %d" stroke="#131b2b" opacity=".55" stroke-width="2"/><path d="M %d 3 V %d" stroke="#fff6d1" opacity=".25"/>' % [x, h, x + 2, h - 3])
		3:
			for x in range(6, w, step_size):
				var y: float = rng.randf_range(h * .25, h * .75)
				parts.append('<path d="M %d %s l 1.2 -3 l 1.2 3 l 3 1.2 l -3 1.2 l -1.2 3 l -1.2 -3 l -3 -1.2 Z" fill="#e8f8ff" opacity=".48"/><ellipse cx="%d" cy="%s" rx="7" ry="2" fill="none" stroke="#e8f8ff" opacity=".15"/>' % [x, y, x, y])
	parts.append('<path d="M 2 3 H %d" stroke="#fff6db" stroke-width="1" opacity=".55"/><path d="M 2 %d H %d" stroke="#10182a" opacity=".45"/></g>' % [w - 2, h - 3, w - 2])
