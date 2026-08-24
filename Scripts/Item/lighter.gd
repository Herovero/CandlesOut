extends "res://Scripts/Item/item.gd"


func _ready():
	super()
	custom_throw_distance = 250.0 

func _on_body_entered(body):
	if not NetworkSession.has_simulation_authority():
		return
	if is_thrown and body.is_in_group("Players"):
		if is_instance_valid(throwing_ghost):
			throwing_ghost.set_deferred("is_picking", false)
			
		body.apply_damage(-3.0)
		SignalBus.emit_signal.call_deferred("swap_player")
		
		NetworkSession.broadcast_sfx(GameplayAudio.Cue.ITEM_LIGHTER, global_position)
		queue_free()
