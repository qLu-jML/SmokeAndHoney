# HiveManager.gd -- Central registry for all active HiveSimulation objects.
# Broadcasts the daily tick to every registered simulation.
# Autoloaded as "HiveManager" in project.godot.
extends Node

# -- Signals -------------------------------------------------------------------
signal all_hives_ticked()          # Fires after every simulation has run its day

# -- Registry ------------------------------------------------------------------
var _hives: Array[Node] = []             # Array of HiveSimulation nodes

# -- Lifecycle -----------------------------------------------------------------

## Connects to TimeManager day_advanced signal for daily simulation ticks.
func _ready() -> void:
	# Connect to TimeManager so we tick every time a day advances.
	# TimeManager is guaranteed to be loaded first (order in project.godot).
	TimeManager.day_advanced.connect(_on_day_advanced)

## Disconnects from TimeManager signal when exiting.
func _exit_tree() -> void:
	if TimeManager and TimeManager.day_advanced.is_connected(_on_day_advanced):
		TimeManager.day_advanced.disconnect(_on_day_advanced)

# -- Registration --------------------------------------------------------------

## Called by each HiveSimulation node in its _ready()
func register(sim: Node) -> void:
	if not _hives.has(sim):
		_hives.append(sim)

## Called by each HiveSimulation node on queue_free()
func unregister(sim: Node) -> void:
	_hives.erase(sim)

## Returns all currently registered simulations (read-only copy)
## Returns a copy of all currently registered HiveSimulation nodes.
func get_all_hives() -> Array:
	return _hives.duplicate()

## Returns the number of registered hives
func hive_count() -> int:
	return _hives.size()

# -- Daily Tick ----------------------------------------------------------------

## Ticks all registered hive simulations when a day advances.
func _on_day_advanced(_new_day: int) -> void:
	for sim in _hives:
		if is_instance_valid(sim) and sim.has_method("tick"):
			sim.tick()
	all_hives_ticked.emit()
