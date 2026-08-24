extends "res://Scripts/Item/item.gd"

@export var duration: float = 10.0

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
		
		# 50/50 chance for Immunity vs. Imprisonment
		if randf() < 0.5:
			# Backfire: The Wall
			SignalBus.emit_signal.call_deferred("apply_shield_backfire", duration, target_slot)
		else:
			# Blessing: Immunity
			SignalBus.emit_signal.call_deferred("apply_shield_boost", duration, target_slot)
		
		NetworkSession.broadcast_sfx(GameplayAudio.Cue.ITEM_SHIELD, global_position)
		queue_free()
