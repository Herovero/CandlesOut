extends "res://Scripts/item.gd"

func _ready():
	super()
	custom_throw_distance = 250.0 

func _on_body_entered(body):
	if is_thrown and body.is_in_group("Players"):
		if is_instance_valid(throwing_ghost):
			throwing_ghost.set_deferred("is_picking", false)
		
		SignalBus.emit_signal.call_deferred("swap_player")
		
		queue_free()
