extends "res://Scripts/item.gd"

@onready var lighter_sfx: AudioStreamPlayer2D = $LighterSFX

func _ready():
	super()
	custom_throw_distance = 250.0 

func _on_body_entered(body):
	if is_thrown and body.is_in_group("Players"):
		if is_instance_valid(throwing_ghost):
			throwing_ghost.set_deferred("is_picking", false)
			
		var p_id = body.input_prefix
		
		
		SignalBus.emit_signal("take_damage", -3.0, p_id)
		SignalBus.emit_signal("restore_stamina", 100, p_id)
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
