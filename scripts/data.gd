class_name Data
extends RefCounted
## All static game content: creatures, eggs, jobs, tools, buildings, town levels and goals.
## Colours are hex strings so they can live in constants; convert with Color(hex).

# ------------------------------------------------------------------ pets

const MAX_LEVEL := 10
const MAX_STAGE := 5
const STAGES := ["Sprout", "Fledgling", "Bloom", "Elder", "Radiant"]
const PRISM_CHANCE := 0.04 # 1 in 25 hatches is a hue-shifted "Prismatic" variant
const TALENT_MULT := 1.5

const HABITATS := {
	"meadow": {"name": "Meadow", "color": "#7cc95a"},
	"tide": {"name": "Tide", "color": "#3fa9d6"},
	"ember": {"name": "Ember", "color": "#ff6a3d"},
	"aurora": {"name": "Aurora", "color": "#9a6bff"},
}

const RARITY := {
	"common": {"name": "Common", "color": "#8d9aa5"},
	"uncommon": {"name": "Uncommon", "color": "#3fae5a"},
	"rare": {"name": "Rare", "color": "#2f86e0"},
	"legendary": {"name": "Legendary", "color": "#e8960c"},
}

# ears: round, pointy, long, big, gills, antenna, crest, none
# tail: puff, long, striped, fin, fan, none
# extra: spikes, wings, stripes, whiskers, tusk, mane, antlers, antlers_big, horns, spots, glow, ""
# talents: jobs this species is naturally good at (x1.5 output)
const SPECIES := {
	# Meadow
	"hedgehog": {"name": "Hedgehog", "mythic": false, "habitat": "meadow", "rarity": "common", "body": "#b08a63", "accent": "#f3dfc4", "ears": "round", "tail": "none", "extra": "spikes", "talents": ["foraging"]},
	"fennec": {"name": "Fennec Fox", "mythic": false, "habitat": "meadow", "rarity": "common", "body": "#f0c48a", "accent": "#fff4e2", "ears": "big", "tail": "puff", "extra": "", "talents": ["exploring"]},
	"capybara": {"name": "Capybara", "mythic": false, "habitat": "meadow", "rarity": "uncommon", "body": "#a8794f", "accent": "#c99a6d", "ears": "round", "tail": "none", "extra": "whiskers", "talents": ["fishing", "foraging"]},
	"red_panda": {"name": "Red Panda", "mythic": false, "habitat": "meadow", "rarity": "uncommon", "body": "#d4642f", "accent": "#fff1de", "ears": "pointy", "tail": "striped", "extra": "", "talents": ["woodcutting"]},
	"luna_moth": {"name": "Luna Moth", "mythic": false, "habitat": "meadow", "rarity": "rare", "body": "#bfeeb0", "accent": "#f6ffe9", "ears": "antenna", "tail": "none", "extra": "wings", "talents": ["foraging", "exploring"]},
	"okapi": {"name": "Okapi", "mythic": false, "habitat": "meadow", "rarity": "legendary", "body": "#5b3a2e", "accent": "#f4eadc", "ears": "pointy", "tail": "long", "extra": "stripes", "talents": ["exploring", "woodcutting"]},
	# Tide
	"axolotl": {"name": "Axolotl", "mythic": false, "habitat": "tide", "rarity": "common", "body": "#ffb3c7", "accent": "#ffe3ea", "ears": "gills", "tail": "fin", "extra": "", "talents": ["fishing"]},
	"seal": {"name": "Harbor Seal", "mythic": false, "habitat": "tide", "rarity": "common", "body": "#8f9aa8", "accent": "#d4dbe3", "ears": "none", "tail": "fin", "extra": "whiskers", "talents": ["fishing"]},
	"sea_otter": {"name": "Sea Otter", "mythic": false, "habitat": "tide", "rarity": "uncommon", "body": "#7a5a44", "accent": "#e9d6c0", "ears": "round", "tail": "long", "extra": "whiskers", "talents": ["fishing", "mining"]},
	"narwhal": {"name": "Narwhal", "mythic": false, "habitat": "tide", "rarity": "rare", "body": "#6f8fb3", "accent": "#dbe8f5", "ears": "none", "tail": "fin", "extra": "tusk", "talents": ["mining", "fishing"]},
	"kelpie": {"name": "Kelpie", "mythic": true, "habitat": "tide", "rarity": "legendary", "body": "#2f8f86", "accent": "#a8f0d8", "ears": "pointy", "tail": "fin", "extra": "mane", "talents": ["fishing", "building"]},
	# Ember
	"jackalope": {"name": "Jackalope", "mythic": true, "habitat": "ember", "rarity": "common", "body": "#c9a57a", "accent": "#f7ead6", "ears": "long", "tail": "puff", "extra": "antlers", "talents": ["woodcutting"]},
	"salamander": {"name": "Fire Salamander", "mythic": false, "habitat": "ember", "rarity": "common", "body": "#2b2b33", "accent": "#ffcf33", "ears": "none", "tail": "long", "extra": "spots", "talents": ["mining"]},
	"kitsune": {"name": "Kitsune", "mythic": true, "habitat": "ember", "rarity": "uncommon", "body": "#ff9d4d", "accent": "#fff3e3", "ears": "pointy", "tail": "fan", "extra": "", "talents": ["exploring"]},
	"qilin": {"name": "Qilin", "mythic": true, "habitat": "ember", "rarity": "rare", "body": "#7fd6b0", "accent": "#ffe08a", "ears": "pointy", "tail": "puff", "extra": "horns", "talents": ["building", "foraging"]},
	"thunderbird": {"name": "Thunderbird", "mythic": true, "habitat": "ember", "rarity": "legendary", "body": "#3d4a8c", "accent": "#ffe14d", "ears": "crest", "tail": "fan", "extra": "wings", "talents": ["building", "mining"]},
	# Aurora
	"wolpertinger": {"name": "Wolpertinger", "mythic": true, "habitat": "aurora", "rarity": "common", "body": "#9c7b5c", "accent": "#efe0cc", "ears": "round", "tail": "puff", "extra": "wings", "talents": ["woodcutting"]},
	"moon_hare": {"name": "Moon Hare", "mythic": true, "habitat": "aurora", "rarity": "uncommon", "body": "#dfe2ff", "accent": "#ffffff", "ears": "long", "tail": "puff", "extra": "glow", "talents": ["foraging", "building"]},
	"sky_whale": {"name": "Sky Whale", "mythic": true, "habitat": "aurora", "rarity": "rare", "body": "#7aa5e8", "accent": "#e2eeff", "ears": "none", "tail": "fin", "extra": "wings", "talents": ["building", "exploring"]},
	"aurora_stag": {"name": "Aurora Stag", "mythic": true, "habitat": "aurora", "rarity": "legendary", "body": "#b48cff", "accent": "#e9ddff", "ears": "pointy", "tail": "puff", "extra": "antlers_big", "talents": ["woodcutting", "building"]},
}

const SPECIES_ORDER := [
	"hedgehog", "fennec", "capybara", "red_panda", "luna_moth", "okapi",
	"axolotl", "seal", "sea_otter", "narwhal", "kelpie",
	"jackalope", "salamander", "kitsune", "qilin", "thunderbird",
	"wolpertinger", "moon_hare", "sky_whale", "aurora_stag",
]

# warmth = seconds to hatch while carried (half speed in the Nest). pool entries: [species, weight]
const EGGS := {
	"dawn": {"name": "Dawn Egg", "price": 0, "warmth": 25, "shell": "#fff0c2", "spots": "#ffb86b", "habitat": "meadow",
		"pool": [["hedgehog", 35], ["fennec", 35], ["axolotl", 15], ["salamander", 15]]},
	"meadow": {"name": "Meadow Egg", "price": 60, "warmth": 50, "shell": "#d9f5c0", "spots": "#7cc95a", "habitat": "meadow",
		"pool": [["hedgehog", 30], ["fennec", 28], ["capybara", 18], ["red_panda", 15], ["luna_moth", 7], ["okapi", 2]]},
	"tide": {"name": "Tide Egg", "price": 150, "warmth": 80, "shell": "#cdeefa", "spots": "#3fa9d6", "habitat": "tide",
		"pool": [["axolotl", 30], ["seal", 28], ["sea_otter", 25], ["narwhal", 13], ["kelpie", 4]]},
	"ember": {"name": "Ember Egg", "price": 320, "warmth": 120, "shell": "#ffd9c2", "spots": "#ff6a3d", "habitat": "ember",
		"pool": [["jackalope", 30], ["salamander", 30], ["kitsune", 25], ["qilin", 12], ["thunderbird", 3]]},
	"aurora": {"name": "Aurora Egg", "price": 700, "warmth": 180, "shell": "#e7dcff", "spots": "#9a6bff", "habitat": "aurora",
		"pool": [["wolpertinger", 35], ["moon_hare", 35], ["sky_whale", 24], ["aurora_stag", 6]]},
}

const EGG_ORDER := ["meadow", "tide", "ember", "aurora"]

# ------------------------------------------------------------------ resources

const RESOURCES := {
	"glimmer": {"name": "Glimmer", "color": "#7fd6ff", "sell": 0},
	"wood": {"name": "Wood", "color": "#b07a45", "sell": 1},
	"stone": {"name": "Stone", "color": "#9aa3ad", "sell": 1},
	"berries": {"name": "Berries", "color": "#6b5cff", "sell": 1},
	"fish": {"name": "Fish", "color": "#4fb6dd", "sell": 3},
	"crystal": {"name": "Crystal", "color": "#c58cff", "sell": 8},
}
const RES_ORDER := ["wood", "stone", "berries", "fish", "crystal"]

# Feeding a pet: xp per item
const FOOD_XP := {"berries": 4, "fish": 12}

# ------------------------------------------------------------------ jobs & tools

# time = seconds per unit for a skill-1 pet with a Wooden tool.
const JOBS := {
	"woodcutting": {"name": "Woodcutting", "verb": "Chopping", "tool": "axe", "time": 6.0, "xp": 3, "sxp": 1.0},
	"foraging": {"name": "Foraging", "verb": "Foraging", "tool": "basket", "time": 5.0, "xp": 3, "sxp": 1.0},
	"mining": {"name": "Mining", "verb": "Mining", "tool": "pickaxe", "time": 7.0, "xp": 4, "sxp": 1.0},
	"fishing": {"name": "Fishing", "verb": "Fishing", "tool": "rod", "time": 8.0, "xp": 4, "sxp": 1.0},
	"building": {"name": "Building", "verb": "Building", "tool": "hammer", "time": 1.0, "xp": 1, "sxp": 0.15},
	"exploring": {"name": "Exploring", "verb": "Exploring", "tool": "compass", "time": 45.0, "xp": 20, "sxp": 4.0},
}
const JOB_ORDER := ["woodcutting", "foraging", "mining", "fishing", "building", "exploring"]

const TOOLS := {
	"axe": {"name": "Axe", "job": "woodcutting"},
	"basket": {"name": "Basket", "job": "foraging"},
	"pickaxe": {"name": "Pickaxe", "job": "mining"},
	"rod": {"name": "Fishing Rod", "job": "fishing"},
	"hammer": {"name": "Hammer", "job": "building"},
	"compass": {"name": "Compass", "job": "exploring"},
}
const TOOL_ORDER := ["axe", "basket", "pickaxe", "rod", "hammer", "compass"]

const TIERS := [
	{"name": "Wooden", "mult": 1.0, "color": "#c08a55", "cost": {"wood": 6, "stone": 2}},
	{"name": "Stone", "mult": 1.5, "color": "#9aa3ad", "cost": {"wood": 10, "stone": 15}},
	{"name": "Crystal", "mult": 2.2, "color": "#c58cff", "cost": {"wood": 15, "stone": 15, "crystal": 10}},
]

# ------------------------------------------------------------------ buildings

# size: footprint in tiles. job/res/slots: work building. need: placement rule.
# charm: decoration value (each point = +1% production, max 50%).
const BUILDINGS := {
	"town_hall": {"name": "Town Hall", "size": Vector2i(3, 3), "cost": {}, "work": 0, "fixed": true,
		"desc": "The heart of your town. Upgrade it to push the town border out and unlock new buildings."},
	"nest": {"name": "The Nest", "size": Vector2i(2, 2), "cost": {}, "work": 0, "fixed": true,
		"desc": "Eggs placed here warm up on their own (at half the speed of carrying them)."},
	"kiosk": {"name": "Egg Kiosk", "size": Vector2i(2, 2), "cost": {}, "work": 0, "fixed": true,
		"desc": "Spend glimmer on new eggs."},
	"builder_hut": {"name": "Builder's Hut", "size": Vector2i(2, 2), "cost": {}, "work": 0, "fixed": true,
		"job": "building", "slots": 3, "desc": "Pets with a hammer work here and build anything under construction."},
	"house": {"name": "House", "size": Vector2i(2, 2), "cost": {"wood": 20, "stone": 10}, "work": 25, "th": 1,
		"desc": "Room for 2 more pets. Residents leave a little glimmer each day."},
	"lumber_camp": {"name": "Lumber Camp", "size": Vector2i(2, 2), "cost": {"wood": 12}, "work": 15, "th": 1,
		"job": "woodcutting", "res": "wood", "slots": 2, "need": "tree", "need_n": 3,
		"desc": "Pets with an axe chop wood. Must be near at least 3 trees."},
	"berry_farm": {"name": "Berry Farm", "size": Vector2i(2, 2), "cost": {"wood": 10}, "work": 15, "th": 1,
		"job": "foraging", "res": "berries", "slots": 2,
		"desc": "Pets with a basket gather berries. Feed berries to pets for XP."},
	"quarry": {"name": "Quarry", "size": Vector2i(2, 2), "cost": {"wood": 20}, "work": 20, "th": 1,
		"job": "mining", "res": "stone", "slots": 2, "need": "rock", "need_n": 2,
		"desc": "Pets with a pickaxe dig stone. Must be near at least 2 rocks."},
	"workshop": {"name": "Workshop", "size": Vector2i(2, 2), "cost": {"wood": 25, "stone": 15}, "work": 30, "th": 1,
		"desc": "Craft tools for your pets. Better tools mean faster work."},
	"market": {"name": "Market", "size": Vector2i(2, 2), "cost": {"wood": 20, "stone": 20}, "work": 30, "th": 1,
		"desc": "Sell spare resources for glimmer."},
	"fishing_dock": {"name": "Fishing Dock", "size": Vector2i(2, 2), "cost": {"wood": 30, "stone": 10}, "work": 30, "th": 2,
		"job": "fishing", "res": "fish", "slots": 2, "need": "water", "need_n": 1,
		"desc": "Pets with a rod catch fish. Must touch the lake. Fish are great pet food."},
	"explorer_lodge": {"name": "Explorer's Lodge", "size": Vector2i(2, 2), "cost": {"wood": 40, "stone": 30, "berries": 15}, "work": 40, "th": 2,
		"job": "exploring", "slots": 2,
		"desc": "Pets with a compass go on trips and bring back glimmer, resources and sometimes eggs."},
	"crystal_mine": {"name": "Crystal Mine", "size": Vector2i(2, 2), "cost": {"wood": 50, "stone": 50}, "work": 50, "th": 3,
		"job": "mining", "res": "crystal", "slots": 2, "need": "crystal", "need_n": 1, "time_mult": 2.0,
		"desc": "Pets with a pickaxe mine crystal. Must be near a crystal outcrop."},
	"path": {"name": "Path", "size": Vector2i(1, 1), "cost": {"stone": 1}, "work": 0, "th": 1, "deco": true, "charm": 0,
		"desc": "A stone path tile."},
	"flower_bed": {"name": "Flower Bed", "size": Vector2i(1, 1), "cost": {"wood": 3, "berries": 3}, "work": 2, "th": 1, "deco": true, "charm": 1,
		"desc": "+1 charm."},
	"sapling": {"name": "Planted Tree", "size": Vector2i(1, 1), "cost": {"berries": 4}, "work": 2, "th": 1, "deco": true, "charm": 1, "counts_as": "tree",
		"desc": "+1 charm, and counts as a tree for Lumber Camps."},
	"lamp": {"name": "Lamp Post", "size": Vector2i(1, 1), "cost": {"stone": 6, "wood": 2}, "work": 3, "th": 1, "deco": true, "charm": 2,
		"desc": "+2 charm."},
	"fountain": {"name": "Fountain", "size": Vector2i(2, 2), "cost": {"stone": 40, "crystal": 5}, "work": 30, "th": 3, "deco": true, "charm": 8,
		"desc": "+8 charm."},
	"statue": {"name": "Pet Statue", "size": Vector2i(2, 2), "cost": {"stone": 80, "crystal": 25, "glimmer": 300}, "work": 60, "th": 4, "deco": true, "charm": 15,
		"desc": "+15 charm. A monument to your best friends."},
}

const BUILD_ORDER := ["house", "lumber_camp", "berry_farm", "quarry", "workshop", "market", "fishing_dock",
	"explorer_lodge", "crystal_mine", "path", "flower_bed", "sapling", "lamp", "fountain", "statue"]

const HOUSE_CAPACITY := 2
const BASE_CAPACITY := 2
const HOUSE_GLIMMER_TIME := 15.0 # seconds per glimmer per house
const OFFLINE_CAP := 8.0 * 3600.0

# Town Hall: radius = town border in tiles from the centre
const TOWN_LEVELS := [
	{"radius": 10.0, "cost": {}},
	{"radius": 14.0, "cost": {"wood": 60, "stone": 40, "glimmer": 100}},
	{"radius": 18.5, "cost": {"wood": 150, "stone": 120, "fish": 20, "glimmer": 300}},
	{"radius": 23.0, "cost": {"wood": 300, "stone": 250, "crystal": 40, "glimmer": 800}},
	{"radius": 28.0, "cost": {"wood": 600, "stone": 500, "crystal": 120, "glimmer": 2000}},
]

# ------------------------------------------------------------------ goals (tutorial chain)

const GOALS := [
	{"id": "hatch", "text": "Carry your Dawn Egg until it hatches", "reward": {"glimmer": 20}},
	{"id": "builder", "text": "Tap a pet, give it the Hammer and send it to the Builder's Hut", "reward": {"wood": 10}},
	{"id": "lumber", "text": "Build a Lumber Camp next to the forest (Build menu)", "reward": {"glimmer": 20}},
	{"id": "woodcutter", "text": "Give a pet the Axe and put it to work at the Lumber Camp", "reward": {"stone": 10}},
	{"id": "house", "text": "Build a House so more pets can live in town", "reward": {"glimmer": 30}},
	{"id": "quarry", "text": "Build a Quarry by the rocks to the north", "reward": {"wood": 20}},
	{"id": "workshop", "text": "Build a Workshop", "reward": {"glimmer": 30}},
	{"id": "craft", "text": "Craft a tool at the Workshop", "reward": {"berries": 10}},
	{"id": "feed", "text": "Feed a pet some berries", "reward": {"glimmer": 20}},
	{"id": "egg", "text": "Buy an egg at the Egg Kiosk", "reward": {"wood": 20, "stone": 20}},
	{"id": "town2", "text": "Upgrade the Town Hall to grow your town", "reward": {"glimmer": 60}},
	{"id": "dock", "text": "Build a Fishing Dock on the lake shore", "reward": {"glimmer": 40}},
	{"id": "charm", "text": "Decorate until your town has 10 charm", "reward": {"glimmer": 80}},
	{"id": "level5", "text": "Raise a pet to level 5", "reward": {"glimmer": 100}},
	{"id": "explore", "text": "Build an Explorer's Lodge and send a pet exploring", "reward": {"glimmer": 100}},
	{"id": "dex8", "text": "Discover 8 species in your Pet Log", "reward": {"glimmer": 200}},
	{"id": "town3", "text": "Upgrade the Town Hall to level 3", "reward": {"glimmer": 200}},
	{"id": "crystal", "text": "Build a Crystal Mine", "reward": {"glimmer": 300}},
]

# ------------------------------------------------------------------ helpers

static func xp_needed(level: int) -> int:
	return 20 + 15 * (level - 1)


static func skill_xp_needed(skill: int) -> int:
	return 8 + 6 * (skill - 1)


static func stage_of(level: int) -> int:
	return clampi((level + 1) / 2, 1, MAX_STAGE)


static func stage_name(level: int) -> String:
	return STAGES[stage_of(level) - 1]


static func stage_scale(stage: int) -> float:
	return 0.78 + 0.12 * float(clampi(stage, 1, MAX_STAGE) - 1)


static func skill_mult(skill: int) -> float:
	return 1.0 + 0.15 * float(skill - 1)


static func cost_text(cost: Dictionary) -> String:
	var parts: Array = []
	for r in ["glimmer"] + RES_ORDER:
		if cost.has(r):
			parts.append("%d %s" % [int(cost[r]), RESOURCES[r]["name"].to_lower()])
	return ", ".join(parts) if not parts.is_empty() else "free"


static func tool_name(tool: Dictionary) -> String:
	return "%s %s" % [TIERS[int(tool["tier"])]["name"], TOOLS[str(tool["kind"])]["name"]]
