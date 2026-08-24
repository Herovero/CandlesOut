extends "res://Scripts/Item/item.gd"

@onready var lighter_sfx: AudioStreamPlayer2D = $LighterSFX

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
		
		play_lighter_sfx()
		queue_free()
		
func play_lighter_sfx():
	var sfx = AudioStreamPlayer2D.new()
	sfx.stream = lighter_sfx.stream
	sfx.global_position = global_position
	
	get_tree().current_scene.add_child(sfx)
	sfx.play()
	
	sfx.finished.connect(sfx.queue_free)
