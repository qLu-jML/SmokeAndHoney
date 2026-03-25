# HiveManager.gd -- Central registry for all active HiveSimulation objects.
# Broadcasts the daily tick to every registered simulation.
# Autoloaded as "HiveManager" in project.godot.
extends Node

# -- Signals -------------------------------------------------------------------
signal all_hives_ticked()          # Fires after every simulation has run its day

# -- Registry ------------------------------------------------------------------
var _hives: Array = []             # Array of HiveSimulation nodes

# -- Lifecycle -----------------------------------------------------------------

func _ready() -> void:
	# Connect to TimeManager so we tick every time a day advances.
	# TimeManager is guaranteed to be loaded first (order in project.godot).
	TimeManager.day_advanced.connect(_on_day_advanced)

# -- Registration --------------------------------------------------------------

## Called by each HiveSimulation node in its _ready()
func register(sim: Node) -> void:
	if not _hives.has(sim):
		_hives.append(sim)

## Called by each HiveSimulation node on queue_free()
func unregister(sim: Node) -> void:
	_hives.erase(sim)

## Returns all currently registered simulations (read-only copy)
func get_all_hives() -> Array:
	return _hives.duplicate()

## Returns the number of registered hives
func hive_count() -> int:
	return _hives.size()

# -- Daily Tick ----------------------------------------------------------------

func _on_day_advanced(_new_day: int) -> void:
	for sim in _hives:
		if is_instance_valid(sim) and sim.has_method("tick"):
			sim.tick()
	all_hives_ticked.emit()
