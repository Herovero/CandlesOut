extends "res://Scripts/Item/item.gd"

@export var stamina_restore_amount: float = 50.0
@onready var coffee_sfx: AudioStreamPlayer2D = $CoffeeSFX

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
		play_coffee_sfx()
		call_deferred("queue_free")
		
func play_coffee_sfx():
	var sfx = AudioStreamPlayer2D.new()
	sfx.stream = coffee_sfx.stream
	sfx.global_position = global_position
	
	get_tree().current_scene.add_child(sfx)
	sfx.play()
	
	sfx.finished.connect(sfx.queue_free)
