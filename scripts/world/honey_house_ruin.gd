# honey_house_ruin.gd -- DEPRECATED (Winter Workshop spec, Section 2)
# -----------------------------------------------------------------------------
# The Honey House is now functional from game start (inherited from Uncle Bob).
# This script is retained as a no-op so any scene nodes referencing it do not
# break.  The examination interaction and quest gating are removed.
# Silas Q1-Q3 (Honey House restoration) are deprecated; his chain is being
# redesigned from "gatekeeper" to "craftsman who helps you upgrade."
# -----------------------------------------------------------------------------
extends Node2D

func _ready() -> void:
	# Hide any visual associated with the ruin node -- house is not ruined.
	visible = false
