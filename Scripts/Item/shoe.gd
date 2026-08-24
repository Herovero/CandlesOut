extends "res://Scripts/Item/item.gd"

@export var speed_multiplier: float = 2.0
@export var duration: float = 10.0

# Called when the node enters the scene tree for the first time.
func _ready():
	super()
	custom_throw_distance = 250.0 # Shoes are aerodynamic!

func _on_body_entered(body):
	if not NetworkSession.has_simulation_authority():
		return
	if is_thrown and body.is_in_group("Players"):
		if is_instance_valid(throwing_ghost):
			throwing_ghost.set_deferred("is_picking", false)
				
		var target_slot: int = body.player_slot
		if randf() < 0.5:
			NetworkSession.broadcast_sfx(GameplayAudio.Cue.ITEM_SHOE_FAST, global_position)
			SignalBus.emit_signal.call_deferred("apply_speed_backfire", speed_multiplier * 2.5, duration, target_slot)
		else:
			NetworkSession.broadcast_sfx(GameplayAudio.Cue.ITEM_SHOE, global_position)
			SignalBus.emit_signal.call_deferred("apply_speed_boost", speed_multiplier, duration, target_slot)
		
		queue_free()
