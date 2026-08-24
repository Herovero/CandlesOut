extends "res://Scripts/Item/item.gd"

@export var boost_duration: float = 10.0

func _ready():
	super()
	custom_throw_distance = 250.0 

func _on_body_entered(body):
	if not NetworkSession.has_simulation_authority():
		return
	if is_thrown and body.is_in_group("Players"):
		if is_instance_valid(throwing_ghost):
			throwing_ghost.set_deferred("is_picking", false)
				
		var target_slot: int = body.player_slot
		
		# Losing Control: 50% chance to backfire
		if randf() < 0.5:
			NetworkSession.broadcast_sfx(GameplayAudio.Cue.ITEM_OIL_BAD, global_position)
			SignalBus.emit_signal.call_deferred("apply_flamethrower_backfire", boost_duration, target_slot)	
		else:
			NetworkSession.broadcast_sfx(GameplayAudio.Cue.ITEM_OIL_GOOD, global_position)
			SignalBus.emit_signal.call_deferred("apply_triple_shot", boost_duration, target_slot)
			
		queue_free()
