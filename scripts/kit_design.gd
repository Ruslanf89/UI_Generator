extends RefCounted
## Shared, deterministic design rules for the offline artwork and composition.
## A design language coordinates the kit; independent choices keep seeds varied.

const FAMILIES = ["Surprise me", "Royal court", "Wildwood", "Runic forge", "Astral order", "Dragon covenant", "Moonfang clan", "Raven court", "Sun temple", "Bone crypt", "Tidal shrine"]
const ART_STYLES = ["Illustrated fantasy", "Medieval pixel", "Sculpted fantasy"]
const MATERIALS = ["Wood", "Stone", "Parchment"]
const MAP_SHAPES = ["circle", "hexagon", "shield", "octagon", "diamond", "square"]
const RESOURCE_FORMS = ["bar", "orb", "vial", "segmented"]
const MOTIFS = ["griffin", "stag", "golem", "celestial", "dragon", "wolf", "raven", "sun", "skull", "kraken"]
const FAMILY_PALETTES = [0, 1, 2, 3, 0, 1, 3, 0, 2, 3]
const SILHOUETTES = ["chamfered", "arched", "scalloped", "stepped", "pointed", "scroll"]
const COMPOSITIONS = ["Split court", "Story sidebar", "Command grid", "Ribbon hall"]
const GEMS = [
	["d55760", "5ea9bd", "a983d3", "62bba5"],
	["74b775", "d9b75b", "5bb9b1", "c57b57"],
	["e9954e", "71becb", "dfb962", "b27ed4"],
	["9a8ce0", "75cbe0", "df91bb", "74cbb5"],
]
const METALS = [
	["e8bd70", "d8aa67", "e1cda3"],
	["c8ad71", "c79667", "d4be85"],
	["a8bdc5", "d3ac6c", "b7b5c4"],
	["bbc0e4", "9fc9d6", "d7bf86"],
]

static func recipe(config: Dictionary, component: String = "", _role: String = "panel") -> Dictionary:
	var kit: Dictionary = config.get("kit", {})
	var base_seed: int = posmod(int(kit.get("seed", 1)), 2147483647)
	var selected: String = str(kit.get("design", FAMILIES[0]))
	var family_choice: int = FAMILIES.find(selected) - 1
	if family_choice < 0:
		family_choice = posmod(base_seed / 4, MOTIFS.size())
	var family_index: int = FAMILY_PALETTES[family_choice]
	var overrides: Dictionary = kit.get("component_seeds", {})
	var override_seed: int = int(overrides.get(component, 0))
	var local_seed: int = posmod(base_seed + int(component.hash()) + override_seed * 7919, 2147483647)
	var rng := RandomNumberGenerator.new()
	rng.seed = local_seed
	var silhouette_index: int = posmod(base_seed / 16 + int(component.hash()) + override_seed, SILHOUETTES.size())
	var selected_map: String = str(kit.get("map_shape", "Surprise me")).to_lower()
	var map_shape: String = selected_map if selected_map in MAP_SHAPES else MAP_SHAPES[posmod(base_seed / 7 + int(overrides.get("Minimap", 0)), MAP_SHAPES.size())]
	var selected_stat: String = str(kit.get("stat_presentation", "Surprise me")).to_lower()
	var stat_form: String = selected_stat if selected_stat in RESOURCE_FORMS else RESOURCE_FORMS[posmod(base_seed / 11 + override_seed, RESOURCE_FORMS.size())]
	var rendering: String = "pixel" if str(config.get("style", ART_STYLES[0])) == ART_STYLES[1] else ("sculpted" if str(config.get("style", ART_STYLES[0])) == ART_STYLES[2] else "painted")
	return {
		"family": FAMILIES[family_choice + 1], "family_index": family_index,
		"motif": MOTIFS[family_choice], "motif_index": family_choice,
		"map_shape": map_shape, "stat_presentation": stat_form, "rendering": rendering,
		"seed": base_seed, "component_seed": local_seed,
		"silhouette_index": silhouette_index, "silhouette": SILHOUETTES[silhouette_index],
		"ornament_variant": posmod(base_seed / 384 + int(component.hash()) + override_seed, 4),
		"frame_variant": posmod(base_seed / 96 + override_seed, 4),
		"border_scale": rng.randf_range(0.8, 1.35),
		"gem": GEMS[family_index][posmod(base_seed / 16, 4)],
		"layout": posmod(base_seed, COMPOSITIONS.size()),
		"accent": str(config.get("accent", "ecc17b")).trim_prefix("#"),
		"material": str(kit.get("material", "Wood")),
	}

static func suggested_accent(config: Dictionary) -> String:
	var design: Dictionary = recipe(config)
	return METALS[int(design.family_index)][posmod(int(design.seed) / 64, 3)]

static func description(config: Dictionary) -> String:
	var design: Dictionary = recipe(config)
	return "%s · %s map · %s resources" % [design.family, str(design.map_shape).capitalize(), str(design.stat_presentation).capitalize()]

static func surprise_brief(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(seed_value, 2147483647) * 65537 + 104729
	return {"style": ART_STYLES[rng.randi_range(0, ART_STYLES.size() - 1)],
		"design": FAMILIES[rng.randi_range(1, FAMILIES.size() - 1)],
		"material": MATERIALS[rng.randi_range(0, MATERIALS.size() - 1)],
		"ornaments": "Rich"}

static func generation_signature(config: Dictionary) -> String:
	var design: Dictionary = recipe(config)
	return "%s/%s/%s/%s/%d" % [config.get("style", ART_STYLES[0]), design.motif, design.map_shape, design.stat_presentation, design.layout]
