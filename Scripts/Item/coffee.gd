extends "res://Scripts/Item/item.gd"

@export var stamina_restore_amount: float = 50.0

func _ready():
	super()
	custom_throw_distance = 250.0 

# We override this to change the effect from Healing to Stamina
func _on_body_entered(body):
	if not NetworkSession.has_simulation_authority():
		return
	if is_thrown and body.is_in_group("Players"):
		# Unlock the ghost movement before the item is deleted 
		if is_instance_valid(throwing_ghost):
			throwing_ghost.is_picking = false
				
		var target_slot: int = body.player_slot
		
		# Instead of 'take_damage', we emit a stamina restoration signal
		# Make sure your SignalBus and Player script are set up to receive this
		SignalBus.emit_signal("restore_stamina", stamina_restore_amount, target_slot)
		
		# Item is consumed
		NetworkSession.broadcast_sfx(GameplayAudio.Cue.ITEM_COFFEE, global_position)
		call_deferred("queue_free")
