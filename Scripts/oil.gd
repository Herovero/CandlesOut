extends "res://Scripts/item.gd"

@export var boost_duration: float = 10.0

func _ready():
	super()
	custom_throw_distance = 250.0 

func _on_body_entered(body):
	if is_thrown and body.is_in_group("Players"):
		if is_instance_valid(throwing_ghost):
			throwing_ghost.set_deferred("is_picking", false)
				
		var p_id = body.input_prefix
		
		# Losing Control: 50% chance to backfire
		if randf() < 0.5:
			SignalBus.emit_signal.call_deferred("apply_flamethrower_backfire", boost_duration, p_id)
		else:
			SignalBus.emit_signal.call_deferred("apply_triple_shot", boost_duration, p_id)
			
		queue_free()
