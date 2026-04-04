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
	# Spring Day 1 (Quickening Day 1): assess winter damage + reset winterization
	if _new_day == 1:
		_spring_damage_check()

	# Safety net checks (Winter Workshop S5)
	_check_safety_nets(_new_day)

	# Annual Beekeeping Catalogue delivery (Winter Workshop S6)
	_check_catalogue_delivery(_new_day)

	for sim in _hives:
		if is_instance_valid(sim) and sim.has_method("tick"):
			sim.tick()
	all_hives_ticked.emit()

# -- Safety Net Systems (Winter Workshop S5) -----------------------------------

## Check and trigger safety net systems based on current game state.
func _check_safety_nets(day: int) -> void:
	var day_in_year: int = ((day - 1) % 224) + 1

	# Dr. Harwick research nuc: Spring Day 1-7, if 0-1 colonized hives, once per game
	if day_in_year >= 1 and day_in_year <= 7:
		if not GameData.harwick_nuc_offered:
			var colonized: int = _count_colonized_hives()
			if colonized <= 1:
				GameData.harwick_nuc_offered = true
				_offer_harwick_nuc()

	# Dr. Harwick periodic visits (3-4 per year after nuc accepted)
	if GameData.harwick_nuc_accepted and GameData.harwick_visit_count < 4:
		# Visit roughly every 56 days (quarterly)
		var visit_days: Array = [28, 84, 140, 196]
		if day_in_year in visit_days:
			GameData.harwick_visit_count += 1
			if NotificationManager:
				NotificationManager.notify(
					"Dr. Harwick is visiting to check on the research nuc.",
					NotificationManager.T_INFO, 4.0)
			# Reset visit count at year boundary
			if day_in_year == 196:
				GameData.harwick_visit_count = 0

	# Carl's tab: spring (days 1-56), cash < $50, tab not already active
	if day_in_year >= 1 and day_in_year <= 56:
		if not GameData.carls_tab_active and GameData.money < 50.0:
			_offer_carls_tab()

	# Carl's tab deadline check: end of High-Sun (day 112)
	if day_in_year == 112 and GameData.carls_tab_active:
		if GameData.carls_tab_amount > 0.01:
			# Missed deadline: -5 Standing
			GameData.reputation = maxf(0.0, GameData.reputation - 50.0)
			if NotificationManager:
				NotificationManager.notify(
					"Carl's tab overdue. Community standing decreased.",
					NotificationManager.T_WARNING, 5.0)
			GameData.carls_tab_active = false
			GameData.carls_tab_amount = 0.0


## Count hives with living colonies.
func _count_colonized_hives() -> int:
	var count: int = 0
	for sim in _hives:
		if not is_instance_valid(sim):
			continue
		var hive_node: Node = sim.get_parent()
		if hive_node and hive_node.get("colony_installed"):
			var pop: int = sim.nurse_count + sim.house_count + sim.forager_count
			if pop > 0:
				count += 1
	return count


## Offer Dr. Harwick's subsidized research nuc.
func _offer_harwick_nuc() -> void:
	if NotificationManager:
		NotificationManager.notify(
			"Dr. Harwick offers a subsidized research nuc ($80). Visit her to accept.",
			NotificationManager.T_INFO, 6.0)


## Offer Carl's $150 credit tab.
func _offer_carls_tab() -> void:
	if NotificationManager:
		NotificationManager.notify(
			"Carl notices you're running low. He offers $150 credit at Tanner's.",
			NotificationManager.T_INFO, 5.0)
	# Auto-accept for now (player can repay later)
	GameData.accept_carls_tab()

# -- Winterization & Spring Damage (Winter Workshop S4) -----------------------

## On Quickening Day 1, check each hive for winter damage based on what
## winterization was (or was not) applied. Then reset winterization state.
func _spring_damage_check() -> void:
	for sim in _hives:
		if not is_instance_valid(sim):
			continue
		var hive_node: Node = sim.get_parent()
		if hive_node == null or not hive_node.has_method("get_winterization_bonus"):
			continue
		if not hive_node.colony_installed:
			continue
		var wstate: Dictionary = hive_node.winterization
		var damages: Array[String] = []

		# Mouse damage: no mouse guard
		if not wstate.get("mouse_guard", false):
			# 60% chance of mice nesting if no guard
			if randf() < 0.60:
				damages.append("mouse_damage")
				# Mice destroy comb and contaminate stores
				if sim.has_method("apply_mouse_damage"):
					sim.apply_mouse_damage()
				else:
					# Fallback: reduce health and honey stores
					sim.health_score = maxf(0.0, sim.health_score - 15.0)
					sim.honey_stores = maxf(0.0, sim.honey_stores - 5.0)

		# Moisture damage: no moisture quilt
		if not wstate.get("moisture_quilt", false):
			# 40% chance of moisture drip damage
			if randf() < 0.40:
				damages.append("moisture_damage")
				sim.health_score = maxf(0.0, sim.health_score - 10.0)

		# Starvation risk: no candy board and low stores
		if not wstate.get("candy_board", false) and sim.honey_stores < 10.0:
			# High starvation risk
			if randf() < 0.50:
				damages.append("starvation_risk")
				sim.honey_stores = 0.0
				sim.health_score = maxf(0.0, sim.health_score - 20.0)

		# Winter loss probability based on missing components
		var base_loss: float = 0.15   # Base 15% winter loss chance
		if not wstate.get("entrance_reducer", false):
			base_loss += 0.05
		if not wstate.get("top_insulation", false):
			base_loss += 0.05
		if not wstate.get("moisture_quilt", false):
			base_loss += 0.10
		if not wstate.get("hive_wrap", false):
			base_loss += 0.08
		# Survival bonus from winterization
		base_loss -= hive_node.get_winterization_bonus()
		base_loss = clampf(base_loss, 0.02, 0.80)

		# Colony death check (only if colony still alive)
		var pop: int = sim.nurse_count + sim.house_count + sim.forager_count
		if pop > 0 and randf() < base_loss:
			damages.append("colony_dead")
			sim.nurse_count = 0
			sim.house_count = 0
			sim.forager_count = 0
			sim.drone_count = 0
			sim.health_score = 0.0

		hive_node.spring_damage = damages

		# Notify player of damage
		if damages.size() > 0:
			var hname: String = hive_node.hive_name if hive_node.hive_name != "" else "Hive"
			if "colony_dead" in damages:
				if NotificationManager:
					NotificationManager.notify(
						"%s did not survive the winter." % hname,
						NotificationManager.T_WARNING, 6.0)
			else:
				var dmg_text: String = ", ".join(damages).replace("_", " ")
				if NotificationManager:
					NotificationManager.notify(
						"%s: spring damage -- %s" % [hname, dmg_text],
						NotificationManager.T_WARNING, 5.0)

		# Reset winterization for the new year
		hive_node.reset_winterization()

# -- Annual Beekeeping Catalogue (Winter Workshop S6) --------------------------

## Check if it is time to deliver the annual catalogue (Kindlemonth Day 5-7).
func _check_catalogue_delivery(day: int) -> void:
	var day_in_year: int = ((day - 1) % 224) + 1
	var current_year: int = GameData.get_game_year()

	# Deliver catalogue on Kindlemonth Day 5 (day 201)
	if day_in_year >= 201 and day_in_year <= 203:
		if GameData.catalogue_year_delivered < current_year:
			GameData.catalogue_delivered = true
			GameData.catalogue_delivery_day = day
			GameData.catalogue_year_delivered = current_year
			GameData.catalogue_orders = []
			if NotificationManager:
				NotificationManager.notify(
					"June delivered the Annual Beekeeping Catalogue! Browse and order within 7 days.",
					NotificationManager.T_INFO, 6.0)

	# Close the catalogue window after 7 days (day 210)
	if day_in_year == 211 and GameData.catalogue_delivered:
		GameData.catalogue_delivered = false
		if GameData.catalogue_orders.size() > 0:
			if NotificationManager:
				NotificationManager.notify(
					"Catalogue window closed. %d order(s) arriving Quickening Day 1." % GameData.catalogue_orders.size(),
					NotificationManager.T_INFO, 4.0)
		else:
			if NotificationManager:
				NotificationManager.notify(
					"Catalogue window closed. No orders placed this year.",
					NotificationManager.T_DEFAULT, 3.0)
