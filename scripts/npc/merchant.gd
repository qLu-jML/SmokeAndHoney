# merchant.gd -- Frank Fischbach (Cedar Bend Feed & Supply shopkeeper)
# -----------------------------------------------------------------------------
# Loads Frank's spritesheet at runtime (bypasses Godot import pipeline).
# Standing idle, south-facing. Opens the shop screen on interaction.
# -----------------------------------------------------------------------------
extends Node2D

const SHEET_PATH := "res://assets/sprites/npc/Frank_Fischbach/frank_fischbach_spritesheet.png"
const SHEET_COLS := 8
const SHEET_ROWS := 24

@onready var _sprite: Sprite2D = get_node_or_null("FrankSprite")

## Initialize merchant: load Frank's spritesheet at runtime.
func _ready() -> void:
	add_to_group("merchant")
	_load_spritesheet()

## Load Frank's spritesheet from disk and set up sprite animation frames.
func _load_spritesheet() -> void:
	if not _sprite:
		return
	var abs_path := ProjectSettings.globalize_path(SHEET_PATH)
	var img := Image.load_from_file(abs_path)
	if img == null:
		push_error("Merchant: failed to load spritesheet from %s" % abs_path)
		return
	var tex := ImageTexture.create_from_image(img)
	_sprite.texture  = tex
	_sprite.hframes  = SHEET_COLS
	_sprite.vframes  = SHEET_ROWS
	# South-facing idle = row 0, col 0 -> frame 0
	_sprite.frame    = 0

## Instantiate and open the shop screen UI.
func open_shop() -> void:
	var scene = load("res://scenes/ui/shop_screen.tscn")
	if scene == null:
		push_error("Merchant: failed to load shop_screen.tscn")
		return
	var shop = scene.instantiate()
	get_tree().root.add_child(shop)
