# wildflower_scatter.gd -- Organic wildflower scattering system
# -----------------------------------------------------------------------------
# Replaces static rectangular wildflower patches with natural-looking clusters.
# Each WildflowerCluster spawns multiple small flower sprites scattered
# organically around a center point, blending seamlessly with the grass.
#
# Attach this script to the WildflowerPatches node in home_property.tscn.
# On _ready(), it removes any old static Sprite2D children and spawns
# organic clusters based on the cluster definitions below.
# -----------------------------------------------------------------------------
extends Node2D

# -- Cluster definitions -----------------------------------------------------
# Each entry defines a cluster of flowers to scatter organically.
# center: approximate center position in world space
# type: forage type key (used for metadata + texture lookup)
# count: number of individual flower sprites to scatter
# radius: scatter radius in pixels around the center
# metadata: forage metadata for game systems
const CLUSTER_DEFS: Array = [
	# -- Clover clusters (scattered across lawn) --------------------------
	{
		"center": Vector2(100, 350), "type": "clover", "count": 8,
		"radius": 40.0,
		"meta": { "nectar_nu": 1.5, "pollen_nu": 0.8, "bloom_start": 1, "bloom_end": 4 }
	},
	{
		"center": Vector2(260, 400), "type": "clover", "count": 10,
		"radius": 50.0,
		"meta": { "nectar_nu": 1.5, "pollen_nu": 0.8, "bloom_start": 1, "bloom_end": 4 }
	},
	{
		"center": Vector2(550, 320), "type": "clover", "count": 12,
		"radius": 55.0,
		"meta": { "nectar_nu": 1.5, "pollen_nu": 0.8, "bloom_start": 1, "bloom_end": 4 }
	},
	{
		"center": Vector2(750, 450), "type": "clover", "count": 14,
		"radius": 60.0,
		"meta": { "nectar_nu": 1.5, "pollen_nu": 0.8, "bloom_start": 1, "bloom_end": 4 }
	},
	{
		"center": Vector2(920, 200), "type": "clover", "count": 12,
		"radius": 55.0,
		"meta": { "nectar_nu": 1.5, "pollen_nu": 0.8, "bloom_start": 1, "bloom_end": 4 }
	},
	# -- Goldenrod clusters (ditch edges, far right) ----------------------
	{
		"center": Vector2(700, 260), "type": "goldenrod", "count": 6,
		"radius": 35.0,
		"meta": { "nectar_nu": 1.3, "pollen_nu": 0.5, "bloom_start": 4, "bloom_end": 5 }
	},
	{
		"center": Vector2(850, 300), "type": "goldenrod", "count": 8,
		"radius": 45.0,
		"meta": { "nectar_nu": 1.3, "pollen_nu": 0.5, "bloom_start": 4, "bloom_end": 5 }
	},
	{
		"center": Vector2(420, 480), "type": "goldenrod", "count": 6,
		"radius": 35.0,
		"meta": { "nectar_nu": 1.3, "pollen_nu": 0.5, "bloom_start": 4, "bloom_end": 5 }
	},
	# -- Aster clusters (late fall, ditch and field edges) ----------------
	{
		"center": Vector2(630, 420), "type": "aster", "count": 7,
		"radius": 40.0,
		"meta": { "nectar_nu": 0.7, "pollen_nu": 0.9, "bloom_start": 4, "bloom_end": 5 }
	},
	{
		"center": Vector2(200, 460), "type": "aster", "count": 5,
		"radius": 35.0,
		"meta": { "nectar_nu": 0.7, "pollen_nu": 0.9, "bloom_start": 4, "bloom_end": 5 }
	},
	# -- Wild Bergamot scatter (near garden area) ------------------------
	{
		"center": Vector2(340, 380), "type": "bergamot", "count": 5,
		"radius": 30.0,
		"meta": { "nectar_nu": 1.3, "pollen_nu": 0.8, "bloom_start": 2, "bloom_end": 3 }
	},
	# -- Purple Coneflower scatter (prairie edge) -------------------------
	{
		"center": Vector2(500, 420), "type": "coneflower", "count": 6,
		"radius": 35.0,
		"meta": { "nectar_nu": 0.9, "pollen_nu": 1.4, "bloom_start": 2, "bloom_end": 4 }
	},
]

# -- Texture paths per flower type --------------------------------------------
const TEXTURE_PATHS: Dictionary = {
	"clover":    "res://assets/sprites/world/forage/clover_mature.png",
	"goldenrod": "res://assets/sprites/world/forage/goldenrod_mature.png",
	"aster":     "res://assets/sprites/world/forage/aster_mature.png",
	"bergamot":    "res://assets/sprites/world/forage/bergamot_mature.png",
	"coneflower":  "res://assets/sprites/world/forage/coneflower_mature.png",
	"sunflower": "res://assets/sprites/world/forage/sunflower_mature.png",
}

# Consistent seed so clusters look the same every load (but still organic)
const SCATTER_SEED := 48271953

func _ready() -> void:
	# Remove any old static flower patch Sprite2D children (keep WillowTree etc.)
	for child in get_children():
		if child is Sprite2D and child.name != "WillowTree":
			child.queue_free()

	# Spawn organic clusters
	var rng := RandomNumberGenerator.new()
	rng.seed = SCATTER_SEED

	for def in CLUSTER_DEFS:
		_spawn_cluster(def, rng)

func _spawn_cluster(def: Dictionary, rng: RandomNumberGenerator) -> void:
	var center: Vector2 = def["center"]
	var flower_type: String = def["type"]
	var count: int = def["count"]
	var radius: float = def["radius"]
	var meta: Dictionary = def["meta"]

	var tex: Texture2D = load(TEXTURE_PATHS[flower_type]) as Texture2D
	if tex == null:
		push_warning("WildflowerScatter: Could not load texture for %s" % flower_type)
		return

	for i in range(count):
		var sprite := Sprite2D.new()
		sprite.texture = tex

		# -- Random position within an elliptical area (more natural than circle)
		var angle := rng.randf() * TAU
		# Use sqrt for uniform distribution within circle
		var dist := sqrt(rng.randf()) * radius
		# Slight ellipse: wider horizontally than vertically
		var offset := Vector2(cos(angle) * dist * 1.3, sin(angle) * dist * 0.9)
		sprite.position = center + offset

		# -- Random rotation (subtle, ?15 degrees)
		sprite.rotation = rng.randf_range(-0.26, 0.26)

		# -- Random scale variation (0.7-1.1 for variety)
		var s := rng.randf_range(0.7, 1.1)
		sprite.scale = Vector2(s, s)

		# -- Random flip for extra variety
		if rng.randf() > 0.5:
			sprite.flip_h = true

		# -- Subtle alpha variation for depth (0.75-0.95)
		var alpha := rng.randf_range(0.75, 0.95)
		sprite.modulate = Color(1.0, 1.0, 1.0, alpha)

		# -- Z-index: flowers sit just above grass tiles
		sprite.z_index = 1

		# -- Metadata for forage system
		sprite.set_meta("forage_type", flower_type)
		sprite.set_meta("nectar_nu", meta["nectar_nu"])
		sprite.set_meta("pollen_nu", meta["pollen_nu"])
		sprite.set_meta("bloom_start", meta["bloom_start"])
		sprite.set_meta("bloom_end", meta["bloom_end"])

		# Name for debugging
		sprite.name = "%s_%d" % [flower_type, i]

		add_child(sprite)
