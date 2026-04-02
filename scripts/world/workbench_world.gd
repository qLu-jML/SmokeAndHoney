@tool
# workbench_world.gd -- Visual placeholder for the shed workbench in-world.
# Renders a small brown table in both the editor and at runtime.
# home_property.gd handles interaction logic (E key, UI overlay).
extends Node2D

func _ready() -> void:
	z_index = 1
	# Only build children once
	if get_child_count() > 0:
		return
	# Table base (dark wood)
	var table := ColorRect.new()
	table.name = "TableBase"
	table.color = Color(0.50, 0.35, 0.18, 1.0)
	table.size = Vector2(28, 16)
	table.position = Vector2(-14, -8)
	add_child(table)
	# Table top (lighter wood)
	var top := ColorRect.new()
	top.name = "TableTop"
	top.color = Color(0.62, 0.48, 0.28, 1.0)
	top.size = Vector2(24, 12)
	top.position = Vector2(-12, -6)
	add_child(top)
	# Label (always visible in editor, runtime controlled by home_property.gd)
	var lbl := Label.new()
	lbl.name = "WorkbenchLabel"
	lbl.text = "Workbench"
	lbl.add_theme_font_size_override("font_size", 4)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.5, 0.8))
	lbl.position = Vector2(-16, -18)
	lbl.visible = true
	add_child(lbl)
