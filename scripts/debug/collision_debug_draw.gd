# collision_debug_draw.gd -- Shared debug overlay for collision visualization
# Attach to a Node2D child with z_index=100 (z_as_relative=false) so it
# draws on top of all game objects regardless of y-sort or z-index.
#
# Parent sets metadata to define what to draw:
#   set_meta("rects", [Rect2, ...])    -- collision rectangles
#   set_meta("circles", [[center: Vector2, radius: float], ...])
#
# Then call queue_redraw() to update.
extends Node2D

func _draw() -> void:
	var col_outline := Color(0.0, 1.0, 0.0, 0.7)
	var col_fill := Color(0.0, 1.0, 0.0, 0.12)

	# Draw rectangles
	if has_meta("rects"):
		var rects: Array = get_meta("rects")
		for r in rects:
			if r is Rect2:
				draw_rect(r, col_fill, true)
				draw_rect(r, col_outline, false, 1.0)

	# Draw circles
	if has_meta("circles"):
		var circles: Array = get_meta("circles")
		for c in circles:
			if c is Array and c.size() >= 2:
				var center: Vector2 = c[0]
				var radius: float = c[1]
				draw_arc(center, radius, 0.0, TAU, 32, col_outline, 1.0)
				# Fill with 32-segment polygon
				var points: PackedVector2Array = PackedVector2Array()
				for i in range(33):
					var angle: float = TAU * float(i) / 32.0
					points.append(center + Vector2(cos(angle), sin(angle)) * radius)
				draw_colored_polygon(points, col_fill)
