class_name EnemyStatsDatabase
extends Resource

@export var melee: Dictionary = {}
@export var ranged: Dictionary = {}
@export var boss: Dictionary = {}


func get_stats(enemy_id: String) -> Dictionary:
	match enemy_id:
		"melee":
			return melee.duplicate(true)
		"ranged":
			return ranged.duplicate(true)
		"boss":
			return boss.duplicate(true)
		_:
			push_error("Unknown enemy stats id: %s" % enemy_id)
			return {}
