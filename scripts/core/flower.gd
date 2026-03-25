extends Node2D

var current_day = 0
var is_seeding = false

# Called when the node is added to the scene.
func _ready():
	# Add StageLabel to dev_label group so it only shows in G-mode (developer mode)
	var stage_label = get_node_or_null("Placeholder/StageLabel")
	if stage_label:
		stage_label.add_to_group("dev_label")
		stage_label.visible = GameData.dev_labels_visible
	update_appearance()

func update_appearance():
	var stage_label = get_node_or_null("Placeholder/StageLabel")
	if stage_label != null:
		# Update text content (visibility is controlled by dev_label group / G-key)
		if is_seeding:
			stage_label.text = "Dry (Seeding)"
			stage_label.modulate = Color(0.6, 0.4, 0.2) # Browned withered state
		elif current_day < 2:
			stage_label.text = "Seed"
		elif current_day < 7:
			stage_label.text = "Sprout"
		elif current_day < 10:
			stage_label.text = "Growing"
		else:
			stage_label.text = "Mature"

# Fallback for unconnected advancement
func advance_day():
	current_day += 1
	update_appearance()

# Global world-driven advancement
func advance_day_with_global(global_day: int):
	current_day += 1
	
	# GDD calendar: 224-day year, 56-day seasons. Fall = months 4-5 (days 113-168).
	# Seeds set during fall months; reset seeding flag outside that window.
	var day_in_year = (global_day - 1) % 224
	if day_in_year >= 112 and day_in_year <= 167:
		is_seeding = true
	else:
		is_seeding = false
		
	update_appearance()

func harvest_seeds() -> int:
	if is_seeding:
		# Flower shatters on harvest, freeing the dirt block
		var yield_amount = randi_range(2, 4)
		queue_free()
		return yield_amount
	return 0

# Example connection for button pressed signal
func _on_next_day_button_pressed():
	advance_day()  # Call advance_day when the button is pressed
