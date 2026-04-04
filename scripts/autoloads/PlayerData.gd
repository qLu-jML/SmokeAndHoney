# PlayerData.gd -- Player identity: name, pronouns, backstory tag.
# Autoloaded as "PlayerData" in project.godot.
# GDD S3.0: Character customization (name, pronouns, backstory).
extends Node

# -- Player Identity -----------------------------------------------------------
var player_name: String = "Beekeeper"      # Default until character creator runs
var pronoun_they: String = "they"          # They/she/he
var pronoun_them: String = "them"          # Them/her/him
var pronoun_their: String = "their"        # Their/her/his
var pronoun_theirs: String = "theirs"      # Theirs/hers/his
var pronoun_themself: String = "themself"  # Themself/herself/himself

# Backstory tags (GDD S3.0e):
# "hobbyist"   -- long-time hobbyist beekeeper (different Bob dialogue opener)
# "newcomer"   -- city person new to rural life (standard path)
# "farmer"     -- farm background, agriculture familiar
const BACKSTORY_HOBBYIST := "hobbyist"
const BACKSTORY_NEWCOMER := "newcomer"
const BACKSTORY_FARMER   := "farmer"

var backstory_tag: String = BACKSTORY_NEWCOMER

# -- Setup State ---------------------------------------------------------------
var character_created: bool = false   # False until character creator is completed

# -- Persistent Flags (one-time events like tutorials) -------------------------
var _flags: Dictionary = {}

## Check if a persistent flag has been set.
func has_flag(flag_name: String) -> bool:
    return _flags.has(flag_name)

## Set a persistent flag (survives save/load).
func set_flag(flag_name: String) -> void:
    _flags[flag_name] = true

## Clear (remove) a persistent flag.
func clear_flag(flag_name: String) -> void:
    _flags.erase(flag_name)

# -- Pronoun Preset Loading ----------------------------------------------------

## Sets pronouns to they/them.
func set_pronouns_they_them() -> void:
    pronoun_they    = "they"
    pronoun_them    = "them"
    pronoun_their   = "their"
    pronoun_theirs  = "theirs"
    pronoun_themself = "themself"

## Sets pronouns to she/her.
func set_pronouns_she_her() -> void:
    pronoun_they    = "she"
    pronoun_them    = "her"
    pronoun_their   = "her"
    pronoun_theirs  = "hers"
    pronoun_themself = "herself"

## Sets pronouns to he/him.
func set_pronouns_he_him() -> void:
    pronoun_they    = "he"
    pronoun_them    = "him"
    pronoun_their   = "his"
    pronoun_theirs  = "his"
    pronoun_themself = "himself"

# -- Token Replacement Utility -------------------------------------------------
# Replaces tokens like {player_name}, {they}, {them}, {their} in dialogue strings.

## Replaces pronoun and name tokens in dialogue strings for dynamic text.
func inject_tokens(text: String) -> String:
    text = text.replace("{player_name}", player_name)
    text = text.replace("{they}", pronoun_they)
    text = text.replace("{them}", pronoun_them)
    text = text.replace("{their}", pronoun_their)
    text = text.replace("{theirs}", pronoun_theirs)
    text = text.replace("{themself}", pronoun_themself)
    # Capitalized variants
    var they_cap: String = pronoun_they.substr(0, 1).to_upper() + pronoun_they.substr(1)
    var them_cap: String = pronoun_them.substr(0, 1).to_upper() + pronoun_them.substr(1)
    var their_cap: String = pronoun_their.substr(0, 1).to_upper() + pronoun_their.substr(1)
    text = text.replace("{They}", they_cap)
    text = text.replace("{Them}", them_cap)
    text = text.replace("{Their}", their_cap)
    return text

# -- Save/Load -----------------------------------------------------------------

## Collects player identity data for save file.
func collect_save_data() -> Dictionary:
    return {
        "player_name": player_name,
        "pronoun_they": pronoun_they,
        "pronoun_them": pronoun_them,
        "pronoun_their": pronoun_their,
        "pronoun_theirs": pronoun_theirs,
        "pronoun_themself": pronoun_themself,
        "backstory_tag": backstory_tag,
        "character_created": character_created,
        "flags": _flags.duplicate(),
    }

## Applies player identity data from save file.
func apply_save_data(data: Dictionary) -> void:
    player_name      = data.get("player_name", "Beekeeper")
    pronoun_they     = data.get("prono