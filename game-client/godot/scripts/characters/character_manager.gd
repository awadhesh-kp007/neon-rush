## CharacterManager — Manages unlockable characters and the active character selection.
##
## Responsibilities:
##   - Loads character resource definitions from disk
##   - Tracks which characters are unlocked (persistent via ConfigFile)
##   - Applies the selected character's scene/skin to the player node
##   - Exposes API for CharacterSelector UI
##
## Add to Autoload as "CharacterManager".

class_name CharacterManager
extends Node

const SAVE_PATH := "user://character_data.cfg"
const SECTION  := "characters"

## Default character identifier (always unlocked).
const DEFAULT_CHARACTER := "nova"

# ─────────────────────────────────────────────────────────────────────────────
# Character Registry
# Each entry: id, display_name, cost (coins), scene_path, thumbnail_path
# ─────────────────────────────────────────────────────────────────────────────

const CHARACTER_REGISTRY: Array[Dictionary] = [
	{
		"id":           "nova",
		"name":         "Nova",
		"cost":         0,
		"scene":        "res://scenes/characters/nova/nova.tscn",
		"thumbnail":    "res://assets/ui/characters/nova_thumb.png",
		"description":  "The street explorer who started it all.",
	},
	{
		"id":           "blaze",
		"name":         "Blaze",
		"cost":         5000,
		"scene":        "res://scenes/characters/blaze/blaze.tscn",
		"thumbnail":    "res://assets/ui/characters/blaze_thumb.png",
		"description":  "Speed-enhanced runner from the neon districts.",
	},
	{
		"id":           "cyra",
		"name":         "Cyra",
		"cost":         8000,
		"scene":        "res://scenes/characters/cyra/cyra.tscn",
		"thumbnail":    "res://assets/ui/characters/cyra_thumb.png",
		"description":  "AI-enhanced operative from Sector 7.",
	},
	{
		"id":           "echo",
		"name":         "Echo",
		"cost":         0,
		"scene":        "res://scenes/characters/echo/echo.tscn",
		"thumbnail":    "res://assets/ui/characters/echo_thumb.png",
		"description":  "Requires completing Mission Set 3.",
		"unlock_via":   "mission",
		"mission_id":   "mission_set_3",
	},
]

# ─────────────────────────────────────────────────────────────────────────────
# State
# ─────────────────────────────────────────────────────────────────────────────

var _config := ConfigFile.new()
var _unlocked: Dictionary = {}   ## id -> bool
var _selected_id: String = DEFAULT_CHARACTER

# ─────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_load()
	# Ensure default is always unlocked
	_unlocked[DEFAULT_CHARACTER] = true


# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

## Returns all character data with unlock status.
func get_all_characters() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in CHARACTER_REGISTRY:
		var copy: Dictionary = entry.duplicate()
		copy["unlocked"] = is_unlocked(copy["id"])
		copy["selected"] = copy["id"] == _selected_id
		result.append(copy)
	return result


## Returns data dict for the currently selected character.
func get_selected_character() -> Dictionary:
	for entry in CHARACTER_REGISTRY:
		if entry["id"] == _selected_id:
			return entry
	return CHARACTER_REGISTRY[0]


## Select a character (must be unlocked).
func select_character(character_id: String) -> bool:
	if not is_unlocked(character_id):
		push_warning("CharacterManager: '%s' is locked." % character_id)
		return false
	_selected_id = character_id
	_save()
	EventBus.character_selected.emit(character_id)
	return true


## Unlock a character using coins.
func unlock_with_coins(character_id: String) -> bool:
	var data := _find_by_id(character_id)
	if data.is_empty():
		push_warning("CharacterManager: Character '%s' not found." % character_id)
		return false
	if is_unlocked(character_id):
		return true  ## Already unlocked
	var cost: int = data.get("cost", 0)
	if cost > 0 and not CoinManager.spend(cost):
		push_warning("CharacterManager: Not enough coins to unlock '%s'." % character_id)
		return false
	_unlocked[character_id] = true
	_save()
	EventBus.character_unlocked.emit(character_id)
	return true


## Unlock a character via mission completion (no coin cost).
func unlock_via_mission(mission_id: String) -> void:
	for entry in CHARACTER_REGISTRY:
		if entry.get("unlock_via") == "mission" and entry.get("mission_id") == mission_id:
			if not is_unlocked(entry["id"]):
				_unlocked[entry["id"]] = true
				_save()
				EventBus.character_unlocked.emit(entry["id"])


## Returns true if the character is unlocked.
func is_unlocked(character_id: String) -> bool:
	return _unlocked.get(character_id, false)


## Returns the PackedScene for the active character (or null if scene missing).
func load_selected_scene() -> PackedScene:
	var data := get_selected_character()
	var path: String = data.get("scene", "")
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("CharacterManager: Scene not found for '%s' at '%s'." % [_selected_id, path])
		return null
	return load(path) as PackedScene

# ─────────────────────────────────────────────────────────────────────────────
# Persistence
# ─────────────────────────────────────────────────────────────────────────────

func _save() -> void:
	_config.set_value(SECTION, "unlocked", _unlocked)
	_config.set_value(SECTION, "selected", _selected_id)
	_config.save(SAVE_PATH)


func _load() -> void:
	if _config.load(SAVE_PATH) == OK:
		_unlocked = _config.get_value(SECTION, "unlocked", {DEFAULT_CHARACTER: true})
		_selected_id = _config.get_value(SECTION, "selected", DEFAULT_CHARACTER)
	else:
		_unlocked = {DEFAULT_CHARACTER: true}
		_selected_id = DEFAULT_CHARACTER


func _find_by_id(character_id: String) -> Dictionary:
	for entry in CHARACTER_REGISTRY:
		if entry["id"] == character_id:
			return entry
	return {}
