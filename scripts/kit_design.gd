extends RefCounted
## Shared, deterministic design rules for the offline artwork and composition.
## A design language coordinates the kit; independent choices keep seeds varied.

const FAMILIES = ["Surprise me", "Royal court", "Wildwood", "Runic forge", "Astral order"]
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
	var family_index: int = FAMILIES.find(selected) - 1
	if family_index < 0:
		family_index = posmod(base_seed / 4, 4)
	var overrides: Dictionary = kit.get("component_seeds", {})
	var override_seed: int = int(overrides.get(component, 0))
	var local_seed: int = posmod(base_seed + int(component.hash()) + override_seed * 7919, 2147483647)
	var rng := RandomNumberGenerator.new()
	rng.seed = local_seed
	var silhouette_index: int = posmod(base_seed / 16 + int(component.hash()) + override_seed, SILHOUETTES.size())
	return {
		"family": FAMILIES[family_index + 1], "family_index": family_index,
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
	return "%s · %s" % [design.family, COMPOSITIONS[int(design.layout)]]
