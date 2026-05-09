extends "res://Scripts/Item/item.gd"

@export var boost_duration: float = 10.0
@onready var oil_good: AudioStreamPlayer2D = $OilGood
@onready var oil_bad: AudioStreamPlayer2D = $OilBad

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
			play_oil_sfx(oil_bad)
			SignalBus.emit_signal.call_deferred("apply_flamethrower_backfire", boost_duration, p_id)	
		else:
			play_oil_sfx(oil_good)
			SignalBus.emit_signal.call_deferred("apply_triple_shot", boost_duration, p_id)
			
			
		queue_free()

func play_oil_sfx(sound : AudioStreamPlayer2D):
	var sfx = AudioStreamPlayer2D.new()
	sfx.stream = sound.stream
	sfx.global_position = global_position
	
	sfx.volume_db = 6.0   
	
	get_tree().current_scene.add_child(sfx)
	sfx.play()
	
	sfx.finished.connect(sfx.queue_free)
