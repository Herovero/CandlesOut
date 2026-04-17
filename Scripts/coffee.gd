extends "res://Scripts/item.gd"

@export var stamina_restore_amount: float = 50.0

func _ready():
	super()
	custom_throw_distance = 250.0 

# We override this to change the effect from Healing to Stamina
func _on_body_entered(body):
	if is_thrown and body.is_in_group("Players"):
		# Unlock the ghost movement before the item is deleted 
		if is_instance_valid(throwing_ghost):
			throwing_ghost.is_picking = false
				
		var p_id = body.input_prefix
		
		# Instead of 'take_damage', we emit a stamina restoration signal
		# Make sure your SignalBus and Player script are set up to receive this
		SignalBus.emit_signal("restore_stamina", stamina_restore_amount, p_id)
		
		# Item is consumed
		queue_free()
