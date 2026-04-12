extends Resource
class_name BiomeDefinitions

# Biome system for procedural terrain generation
# Each biome defines noise traits that shape the landscape

enum BiomeType {
	RING_EDGE_MOUNTAINS,   # Barrier mountains at ring edges
	ROLLING_PLAINS,        # Gentle grasslands
	DENSE_FOREST,          # Info-poor, high occlusion
	HIGHLAND_PLATEAU,      # Elevated flat areas with cliffs
	RIVER_VALLEY,          # Low-lying fertile areas
	ROCKY_BADLANDS,        # Eroded, sparse vegetation
	COASTAL_LOWLANDS,      # Near water level, beaches
}

# Noise trait structure for each biome
class NoiseTraits:
	# Frequency controls (wavelength in world units)
	var continental_freq: float = 0.00025  # ~4000 unit features
	var mountain_freq: float = 0.001       # ~1000 unit features
	var hill_freq: float = 0.003           # ~300 unit features
	var detail_freq: float = 0.01          # ~100 unit features

	# Amplitude weights (must sum to 1.0)
	var continental_weight: float = 0.4
	var mountain_weight: float = 0.3
	var hill_weight: float = 0.2
	var detail_weight: float = 0.1

	# Height scaling
	var height_multiplier: float = 1.0  # Scales final terrain_height
	var base_elevation: float = 0.0     # Offset from sea level (0-1)

	# Domain warping for weathered/ridge-like terrain
	var warp_strength: float = 0.0      # How much to warp coordinates (0=none, 100+=dramatic ridges)
	var warp_frequency: float = 0.002   # Frequency of the warping noise
	var ridge_power: float = 1.0        # Power curve for ridge sharpness (1=normal, 2+=sharper ridges)

	# Micro-detail for close-range features (rocky outcrops, terrain detail within ~500m)
	var micro_freq: float = 0.02        # ~50 unit features
	var micro_weight: float = 0.05      # Amplitude of micro detail
	var micro_warp_strength: float = 15.0  # Warping for micro detail
	var micro_warp_freq: float = 0.01   # Frequency of micro warping

	# Information topology
	var info_opacity: float = 0.3       # How much info is blocked (0=clear, 1=dense)
	var signal_amplification: float = 0.7  # How far info propagates

	# Vegetation
	var tree_density: float = 0.5       # Trees per chunk (0-1)
	var tree_min_height: float = 0.08   # Min normalized height for trees
	var tree_max_height: float = 0.55   # Max normalized height (treeline)

	# Water
	var water_level: float = 0.05       # Local water level override (-1 = use global)

	func _init():
		pass

# Get noise traits for a biome type
static func get_biome_traits(biome: BiomeType) -> NoiseTraits:
	var traits = NoiseTraits.new()

	match biome:
		BiomeType.RING_EDGE_MOUNTAINS:
			# Dramatic barrier mountains - info-rich at peaks, info-poor in valleys
			traits.continental_freq = 0.00025
			traits.mountain_freq = 0.001
			traits.hill_freq = 0.003
			traits.detail_freq = 0.01

			traits.continental_weight = 0.4
			traits.mountain_weight = 0.3
			traits.hill_weight = 0.2
			traits.detail_weight = 0.1

			traits.height_multiplier = 1.0
			traits.base_elevation = 0.1

			# Strong warping for dramatic ridges and weathered peaks
			traits.warp_strength = 80.0
			traits.warp_frequency = 0.0015
			traits.ridge_power = 1.8

			# Micro-detail for rocky outcrops
			traits.micro_freq = 0.025
			traits.micro_weight = 0.06
			traits.micro_warp_strength = 20.0
			traits.micro_warp_freq = 0.015

			traits.info_opacity = 0.4
			traits.signal_amplification = 0.8  # Peaks are visible far away

			traits.tree_density = 0.4
			traits.tree_min_height = 0.08
			traits.tree_max_height = 0.45  # Lower treeline on mountains

			traits.water_level = 0.05  # 5% above base (base 0.1 → water at 0.15)

		BiomeType.ROLLING_PLAINS:
			# Gentle grasslands - high visibility, info-rich
			traits.continental_freq = 0.0002
			traits.mountain_freq = 0.0008
			traits.hill_freq = 0.002
			traits.detail_freq = 0.008

			traits.continental_weight = 0.5
			traits.mountain_weight = 0.25
			traits.hill_weight = 0.15
			traits.detail_weight = 0.1

			traits.height_multiplier = 0.3  # Much flatter
			traits.base_elevation = 0.15

			# Minimal warping - smooth rolling hills
			traits.warp_strength = 10.0
			traits.warp_frequency = 0.001
			traits.ridge_power = 1.0

			# Subtle micro-detail for gentle terrain variation
			traits.micro_freq = 0.015
			traits.micro_weight = 0.02
			traits.micro_warp_strength = 5.0
			traits.micro_warp_freq = 0.008

			traits.info_opacity = 0.1  # Very clear sightlines
			traits.signal_amplification = 0.9

			traits.tree_density = 0.6  # Scattered woods and copses across grasslands
			traits.tree_min_height = 0.1
			traits.tree_max_height = 0.8

			traits.water_level = 0.08  # 8% above base (base 0.15 → water at 0.23)

		BiomeType.DENSE_FOREST:
			# Heavy forest - info-poor, high occlusion, mysterious
			traits.continental_freq = 0.0003
			traits.mountain_freq = 0.001
			traits.hill_freq = 0.004
			traits.detail_freq = 0.015

			traits.continental_weight = 0.35
			traits.mountain_weight = 0.25
			traits.hill_weight = 0.25
			traits.detail_weight = 0.15

			traits.height_multiplier = 0.5
			traits.base_elevation = 0.12

			# Moderate warping - organic undulating terrain
			traits.warp_strength = 30.0
			traits.warp_frequency = 0.002
			traits.ridge_power = 1.2

			# Moderate micro-detail for root mounds and forest floor variation
			traits.micro_freq = 0.02
			traits.micro_weight = 0.04
			traits.micro_warp_strength = 12.0
			traits.micro_warp_freq = 0.012

			traits.info_opacity = 0.85  # Can't see far
			traits.signal_amplification = 0.2  # Rumors don't travel well

			traits.tree_density = 0.95  # Maximum trees
			traits.tree_min_height = 0.06
			traits.tree_max_height = 0.7

			traits.water_level = 0.1  # 10% above base (base 0.12 → water at 0.22)

		BiomeType.HIGHLAND_PLATEAU:
			# Elevated flats with cliff edges
			traits.continental_freq = 0.0001
			traits.mountain_freq = 0.0005
			traits.hill_freq = 0.002
			traits.detail_freq = 0.01

			traits.continental_weight = 0.6  # Large flat areas
			traits.mountain_weight = 0.2
			traits.hill_weight = 0.15
			traits.detail_weight = 0.05

			traits.height_multiplier = 0.7
			traits.base_elevation = 0.35  # Elevated base

			# Low warping - mostly flat with subtle variation
			traits.warp_strength = 15.0
			traits.warp_frequency = 0.001
			traits.ridge_power = 1.0

			# Subtle micro-detail for exposed rock patches on plateaus
			traits.micro_freq = 0.018
			traits.micro_weight = 0.03
			traits.micro_warp_strength = 8.0
			traits.micro_warp_freq = 0.01

			traits.info_opacity = 0.2
			traits.signal_amplification = 0.85

			traits.tree_density = 0.25
			traits.tree_min_height = 0.3
			traits.tree_max_height = 0.6

			traits.water_level = -1  # No local water (above water table)

		BiomeType.RIVER_VALLEY:
			# Wide valleys between distant mountain ranges with rolling foothills
			traits.continental_freq = 0.00006   # Very large features — mountains far apart
			traits.mountain_freq = 0.00035      # Broad mountain masses, not spiky peaks
			traits.hill_freq = 0.0018           # Foothills — mid-scale rolling
			traits.detail_freq = 0.010          # Surface detail

			traits.continental_weight = 0.30
			traits.mountain_weight = 0.50       # Mountains dominate shape
			traits.hill_weight = 0.22           # Clear foothills between valleys and peaks
			traits.detail_weight = 0.08

			traits.height_multiplier = 0.65
			traits.base_elevation = 0.02

			# Moderate warping — organic shapes without chaotic spikes
			traits.warp_strength = 60.0
			traits.warp_frequency = 0.0015
			traits.ridge_power = 1.4

			# Moderate micro-detail for riverbed stones and banks
			traits.micro_freq = 0.022
			traits.micro_weight = 0.04
			traits.micro_warp_strength = 15.0
			traits.micro_warp_freq = 0.012

			traits.info_opacity = 0.5  # Mixed visibility
			traits.signal_amplification = 0.6

			traits.tree_density = 0.6
			traits.tree_min_height = 0.04
			traits.tree_max_height = 0.5

			traits.water_level = 0.08  # 8% = 32m with terrain_height=400 — well below flat plains

		BiomeType.ROCKY_BADLANDS:
			# Eroded, sparse, dramatic rock formations
			traits.continental_freq = 0.0003
			traits.mountain_freq = 0.002
			traits.hill_freq = 0.006
			traits.detail_freq = 0.02

			traits.continental_weight = 0.3
			traits.mountain_weight = 0.35
			traits.hill_weight = 0.25
			traits.detail_weight = 0.1

			traits.height_multiplier = 0.6
			traits.base_elevation = 0.2

			# Strong warping with high ridge power - sharp eroded formations
			traits.warp_strength = 60.0
			traits.warp_frequency = 0.003
			traits.ridge_power = 2.2  # Very sharp ridges

			# Heavy micro-detail for eroded rock spires and outcrops
			traits.micro_freq = 0.03
			traits.micro_weight = 0.08
			traits.micro_warp_strength = 25.0
			traits.micro_warp_freq = 0.02

			traits.info_opacity = 0.3
			traits.signal_amplification = 0.7

			traits.tree_density = 0.05  # Almost no trees
			traits.tree_min_height = 0.15
			traits.tree_max_height = 0.4

			traits.water_level = 0.03  # 3% above base (base 0.2 → water at 0.23) - dry

		BiomeType.COASTAL_LOWLANDS:
			# Beach and coastal areas - very flat with gentle rolling hills
			# Sea erosion creates smooth, low-lying terrain near coasts
			traits.continental_freq = 0.00008  # Very large, gentle features
			traits.mountain_freq = 0.00015     # Almost no mountains
			traits.hill_freq = 0.0005          # Very gentle hills
			traits.detail_freq = 0.002         # Subtle detail

			traits.continental_weight = 0.85   # Dominant smooth continental base
			traits.mountain_weight = 0.02      # Almost no mountain influence
			traits.hill_weight = 0.08          # Gentle rolling hills
			traits.detail_weight = 0.05        # Minimal detail noise

			traits.height_multiplier = 0.25    # Lower max height (200m) for flatter terrain
			traits.base_elevation = 0.02       # Low base near sea level

			# No warping - smooth eroded coastal terrain
			traits.warp_strength = 0.0
			traits.warp_frequency = 0.001
			traits.ridge_power = 1.0

			# No micro-detail - smooth sand/grass
			traits.micro_freq = 0.008
			traits.micro_weight = 0.005        # Almost invisible micro variation
			traits.micro_warp_strength = 0.0
			traits.micro_warp_freq = 0.005

			traits.info_opacity = 0.15
			traits.signal_amplification = 0.9

			traits.tree_density = 0.25
			traits.tree_min_height = 0.15      # Trees start a bit higher (above beach)
			traits.tree_max_height = 0.7

			traits.water_level = 0.35          # 35% - lots of shallow water and beaches

	return traits

# Get a descriptive name for the biome
static func get_biome_name(biome: BiomeType) -> String:
	match biome:
		BiomeType.RING_EDGE_MOUNTAINS:
			return "Ring Edge Mountains"
		BiomeType.ROLLING_PLAINS:
			return "Rolling Plains"
		BiomeType.DENSE_FOREST:
			return "Dense Forest"
		BiomeType.HIGHLAND_PLATEAU:
			return "Highland Plateau"
		BiomeType.RIVER_VALLEY:
			return "River Valley"
		BiomeType.ROCKY_BADLANDS:
			return "Rocky Badlands"
		BiomeType.COASTAL_LOWLANDS:
			return "Coastal Lowlands"
		_:
			return "Unknown"

# Biome colors for vertex coloring (base colors, modified by height/slope)
static func get_biome_colors(biome: BiomeType) -> Dictionary:
	var colors = {}

	match biome:
		BiomeType.RING_EDGE_MOUNTAINS:
			colors["deep_water"] = Color(0.1, 0.2, 0.4)
			colors["shallow_water"] = Color(0.2, 0.4, 0.5)
			colors["beach"] = Color(0.85, 0.80, 0.65)
			colors["grass"] = Color(0.25, 0.50, 0.2)
			colors["dark_grass"] = Color(0.15, 0.38, 0.12)
			colors["forest"] = Color(0.12, 0.30, 0.10)
			colors["rock"] = Color(0.50, 0.48, 0.45)
			colors["snow"] = Color(0.95, 0.95, 0.98)

		BiomeType.ROLLING_PLAINS:
			colors["deep_water"] = Color(0.1, 0.25, 0.4)
			colors["shallow_water"] = Color(0.2, 0.45, 0.5)
			colors["beach"] = Color(0.82, 0.78, 0.62)
			colors["grass"] = Color(0.35, 0.55, 0.25)  # Brighter grass
			colors["dark_grass"] = Color(0.28, 0.48, 0.18)
			colors["forest"] = Color(0.18, 0.35, 0.12)
			colors["rock"] = Color(0.55, 0.52, 0.48)
			colors["snow"] = Color(0.95, 0.95, 0.98)

		BiomeType.DENSE_FOREST:
			colors["deep_water"] = Color(0.08, 0.18, 0.35)
			colors["shallow_water"] = Color(0.15, 0.35, 0.45)
			colors["beach"] = Color(0.45, 0.40, 0.30)  # Dark leaf litter
			colors["grass"] = Color(0.15, 0.35, 0.12)  # Dark understory
			colors["dark_grass"] = Color(0.10, 0.28, 0.08)
			colors["forest"] = Color(0.08, 0.22, 0.06)  # Very dark
			colors["rock"] = Color(0.35, 0.32, 0.28)  # Mossy rocks
			colors["snow"] = Color(0.90, 0.92, 0.88)  # Rarely seen

		BiomeType.HIGHLAND_PLATEAU:
			colors["deep_water"] = Color(0.12, 0.22, 0.42)
			colors["shallow_water"] = Color(0.22, 0.42, 0.52)
			colors["beach"] = Color(0.75, 0.72, 0.60)
			colors["grass"] = Color(0.40, 0.52, 0.32)  # Alpine grass
			colors["dark_grass"] = Color(0.32, 0.45, 0.25)
			colors["forest"] = Color(0.20, 0.35, 0.18)
			colors["rock"] = Color(0.58, 0.55, 0.50)  # Lighter exposed rock
			colors["snow"] = Color(0.96, 0.96, 0.98)

		BiomeType.RIVER_VALLEY:
			colors["deep_water"] = Color(0.08, 0.20, 0.38)
			colors["shallow_water"] = Color(0.18, 0.40, 0.48)
			colors["beach"] = Color(0.65, 0.58, 0.45)  # Muddy banks
			colors["grass"] = Color(0.30, 0.55, 0.22)  # Lush grass
			colors["dark_grass"] = Color(0.22, 0.48, 0.15)
			colors["forest"] = Color(0.15, 0.38, 0.12)
			colors["rock"] = Color(0.45, 0.42, 0.38)  # River stones
			colors["snow"] = Color(0.94, 0.94, 0.96)

		BiomeType.ROCKY_BADLANDS:
			colors["deep_water"] = Color(0.15, 0.18, 0.25)  # Murky
			colors["shallow_water"] = Color(0.25, 0.30, 0.35)
			colors["beach"] = Color(0.70, 0.58, 0.42)  # Sandy/dusty
			colors["grass"] = Color(0.55, 0.50, 0.35)  # Dry scrub
			colors["dark_grass"] = Color(0.48, 0.42, 0.30)
			colors["forest"] = Color(0.40, 0.35, 0.25)  # Sparse brush
			colors["rock"] = Color(0.65, 0.55, 0.45)  # Red/orange rock
			colors["snow"] = Color(0.92, 0.90, 0.85)  # Dusty snow

		BiomeType.COASTAL_LOWLANDS:
			colors["deep_water"] = Color(0.05, 0.18, 0.45)  # Deep ocean blue
			colors["shallow_water"] = Color(0.15, 0.45, 0.55)  # Tropical shallows
			colors["beach"] = Color(0.92, 0.88, 0.75)  # White sand
			colors["grass"] = Color(0.30, 0.52, 0.28)
			colors["dark_grass"] = Color(0.22, 0.45, 0.20)
			colors["forest"] = Color(0.15, 0.35, 0.15)
			colors["rock"] = Color(0.52, 0.50, 0.48)
			colors["snow"] = Color(0.95, 0.95, 0.98)

		_:
			# Default fallback
			colors["deep_water"] = Color(0.1, 0.2, 0.4)
			colors["shallow_water"] = Color(0.2, 0.4, 0.5)
			colors["beach"] = Color(0.85, 0.80, 0.65)
			colors["grass"] = Color(0.25, 0.50, 0.2)
			colors["dark_grass"] = Color(0.15, 0.38, 0.12)
			colors["forest"] = Color(0.12, 0.30, 0.10)
			colors["rock"] = Color(0.50, 0.48, 0.45)
			colors["snow"] = Color(0.95, 0.95, 0.98)

	return colors
