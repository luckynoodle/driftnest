class_name Data
extends RefCounted
## All static game content lives here: creatures, eggs and chores.
## Colors are hex strings so they can live in constants; convert with Color(hex).

const MAX_LEVEL := 5
const STAGES := ["Sprout", "Fledgling", "Bloom", "Elder", "Radiant"]
const PRISM_CHANCE := 0.04 # 1 in 25 hatches is a hue-shifted "Prismatic" variant

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

# ears: round, pointy, long, gills, antenna, crest, none
# tail: puff, long, striped, fin, fan, none
# extra: spikes, wings, stripes, whiskers, tusk, mane, antlers, antlers_big, horns, spots, glow, ""
const SPECIES := {
	# Meadow
	"hedgehog": {"name": "Hedgehog", "mythic": false, "habitat": "meadow", "rarity": "common", "body": "#b08a63", "accent": "#f3dfc4", "ears": "round", "tail": "none", "extra": "spikes"},
	"fennec": {"name": "Fennec Fox", "mythic": false, "habitat": "meadow", "rarity": "common", "body": "#f0c48a", "accent": "#fff4e2", "ears": "big", "tail": "puff", "extra": ""},
	"capybara": {"name": "Capybara", "mythic": false, "habitat": "meadow", "rarity": "uncommon", "body": "#a8794f", "accent": "#c99a6d", "ears": "round", "tail": "none", "extra": "whiskers"},
	"red_panda": {"name": "Red Panda", "mythic": false, "habitat": "meadow", "rarity": "uncommon", "body": "#d4642f", "accent": "#fff1de", "ears": "pointy", "tail": "striped", "extra": ""},
	"luna_moth": {"name": "Luna Moth", "mythic": false, "habitat": "meadow", "rarity": "rare", "body": "#bfeeb0", "accent": "#f6ffe9", "ears": "antenna", "tail": "none", "extra": "wings"},
	"okapi": {"name": "Okapi", "mythic": false, "habitat": "meadow", "rarity": "legendary", "body": "#5b3a2e", "accent": "#f4eadc", "ears": "pointy", "tail": "long", "extra": "stripes"},
	# Tide
	"axolotl": {"name": "Axolotl", "mythic": false, "habitat": "tide", "rarity": "common", "body": "#ffb3c7", "accent": "#ffe3ea", "ears": "gills", "tail": "fin", "extra": ""},
	"seal": {"name": "Harbor Seal", "mythic": false, "habitat": "tide", "rarity": "common", "body": "#8f9aa8", "accent": "#d4dbe3", "ears": "none", "tail": "fin", "extra": "whiskers"},
	"sea_otter": {"name": "Sea Otter", "mythic": false, "habitat": "tide", "rarity": "uncommon", "body": "#7a5a44", "accent": "#e9d6c0", "ears": "round", "tail": "long", "extra": "whiskers"},
	"narwhal": {"name": "Narwhal", "mythic": false, "habitat": "tide", "rarity": "rare", "body": "#6f8fb3", "accent": "#dbe8f5", "ears": "none", "tail": "fin", "extra": "tusk"},
	"kelpie": {"name": "Kelpie", "mythic": true, "habitat": "tide", "rarity": "legendary", "body": "#2f8f86", "accent": "#a8f0d8", "ears": "pointy", "tail": "fin", "extra": "mane"},
	# Ember
	"jackalope": {"name": "Jackalope", "mythic": true, "habitat": "ember", "rarity": "common", "body": "#c9a57a", "accent": "#f7ead6", "ears": "long", "tail": "puff", "extra": "antlers"},
	"salamander": {"name": "Fire Salamander", "mythic": false, "habitat": "ember", "rarity": "common", "body": "#2b2b33", "accent": "#ffcf33", "ears": "none", "tail": "long", "extra": "spots"},
	"kitsune": {"name": "Kitsune", "mythic": true, "habitat": "ember", "rarity": "uncommon", "body": "#ff9d4d", "accent": "#fff3e3", "ears": "pointy", "tail": "fan", "extra": ""},
	"qilin": {"name": "Qilin", "mythic": true, "habitat": "ember", "rarity": "rare", "body": "#7fd6b0", "accent": "#ffe08a", "ears": "pointy", "tail": "puff", "extra": "horns"},
	"thunderbird": {"name": "Thunderbird", "mythic": true, "habitat": "ember", "rarity": "legendary", "body": "#3d4a8c", "accent": "#ffe14d", "ears": "crest", "tail": "fan", "extra": "wings"},
	# Aurora
	"wolpertinger": {"name": "Wolpertinger", "mythic": true, "habitat": "aurora", "rarity": "common", "body": "#9c7b5c", "accent": "#efe0cc", "ears": "round", "tail": "puff", "extra": "wings"},
	"moon_hare": {"name": "Moon Hare", "mythic": true, "habitat": "aurora", "rarity": "uncommon", "body": "#dfe2ff", "accent": "#ffffff", "ears": "long", "tail": "puff", "extra": "glow"},
	"sky_whale": {"name": "Sky Whale", "mythic": true, "habitat": "aurora", "rarity": "rare", "body": "#7aa5e8", "accent": "#e2eeff", "ears": "none", "tail": "fin", "extra": "wings"},
	"aurora_stag": {"name": "Aurora Stag", "mythic": true, "habitat": "aurora", "rarity": "legendary", "body": "#b48cff", "accent": "#e9ddff", "ears": "pointy", "tail": "puff", "extra": "antlers_big"},
}

const SPECIES_ORDER := [
	"hedgehog", "fennec", "capybara", "red_panda", "luna_moth", "okapi",
	"axolotl", "seal", "sea_otter", "narwhal", "kelpie",
	"jackalope", "salamander", "kitsune", "qilin", "thunderbird",
	"wolpertinger", "moon_hare", "sky_whale", "aurora_stag",
]

# pool entries are [species_id, weight]
const EGGS := {
	"dawn": {"name": "Dawn Egg", "price": 0, "warmth": 40, "shell": "#fff0c2", "spots": "#ffb86b", "habitat": "meadow", "buyable": false,
		"pool": [["hedgehog", 35], ["fennec", 35], ["axolotl", 20], ["salamander", 10]]},
	"meadow": {"name": "Meadow Egg", "price": 60, "warmth": 60, "shell": "#d9f5c0", "spots": "#7cc95a", "habitat": "meadow", "buyable": true,
		"pool": [["hedgehog", 30], ["fennec", 28], ["capybara", 18], ["red_panda", 15], ["luna_moth", 7], ["okapi", 2]]},
	"tide": {"name": "Tide Egg", "price": 150, "warmth": 90, "shell": "#cdeefa", "spots": "#3fa9d6", "habitat": "tide", "buyable": true,
		"pool": [["axolotl", 30], ["seal", 28], ["sea_otter", 25], ["narwhal", 13], ["kelpie", 4]]},
	"ember": {"name": "Ember Egg", "price": 320, "warmth": 130, "shell": "#ffd9c2", "spots": "#ff6a3d", "habitat": "ember", "buyable": true,
		"pool": [["jackalope", 30], ["salamander", 30], ["kitsune", 25], ["qilin", 12], ["thunderbird", 3]]},
	"aurora": {"name": "Aurora Egg", "price": 700, "warmth": 180, "shell": "#e7dcff", "spots": "#9a6bff", "habitat": "aurora", "buyable": true,
		"pool": [["wolpertinger", 35], ["moon_hare", 35], ["sky_whale", 24], ["aurora_stag", 6]]},
}

const EGG_ORDER := ["meadow", "tide", "ember", "aurora"]

# A companion whose habitat matches a chore's habitat does it 50% faster.
const JOBS := {
	"nap": {"name": "Nap in the Nest", "short": "Nap", "time": 5.0, "glimmer": 4, "xp": 6, "warmth": 16, "habitat": ""},
	"berries": {"name": "Pick Moonberries", "short": "Berries", "time": 3.0, "glimmer": 10, "xp": 8, "warmth": 8, "habitat": "meadow"},
	"windmill": {"name": "Wind the Cloudmill", "short": "Cloudmill", "time": 4.0, "glimmer": 14, "xp": 10, "warmth": 10, "habitat": "aurora"},
	"tidepool": {"name": "Tidy the Tidepool", "short": "Tidepool", "time": 3.5, "glimmer": 12, "xp": 9, "warmth": 9, "habitat": "tide"},
	"starmail": {"name": "Deliver Starmail", "short": "Starmail", "time": 1.5, "glimmer": 22, "xp": 14, "warmth": 12, "habitat": ""},
	"lanterns": {"name": "Light the Lanterns", "short": "Lanterns", "time": 1.2, "glimmer": 26, "xp": 16, "warmth": 14, "habitat": "ember"},
}

const JOB_ORDER := ["nap", "berries", "windmill", "tidepool", "starmail", "lanterns"]


static func xp_needed(level: int) -> int:
	return 25 + 20 * (level - 1)


static func stage_name(level: int) -> String:
	return STAGES[clampi(level, 1, MAX_LEVEL) - 1]


static func stage_scale(level: int) -> float:
	return 0.78 + 0.12 * float(clampi(level, 1, MAX_LEVEL) - 1)
