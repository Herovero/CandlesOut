extends "res://Scripts/Item/item.gd"

@export var speed_multiplier: float = 2.0
@export var duration: float = 10.0
@onready var shoe_sfx: AudioStreamPlayer2D = $ShoeSFX
@onready var shoes_fast_sfx: AudioStreamPlayer2D = $ShoesFastSFX

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
			play_shoes_fast_sfx()
			SignalBus.emit_signal.call_deferred("apply_speed_backfire", speed_multiplier * 2.5, duration, target_slot)
		else:
			play_shoes_sfx()
			SignalBus.emit_signal.call_deferred("apply_speed_boost", speed_multiplier, duration, target_slot)
		
		queue_free()
		
func play_shoes_sfx():
	var sfx = AudioStreamPlayer2D.new()
	sfx.stream = shoe_sfx.stream
	sfx.global_position = global_position
	
	sfx.volume_db = 6.0   
	
	get_tree().current_scene.add_child(sfx)
	sfx.play()
	
	sfx.finished.connect(sfx.queue_free)
	
func play_shoes_fast_sfx():
	var sfx = AudioStreamPlayer2D.new()
	sfx.stream = shoes_fast_sfx.stream
	sfx.global_position = global_position
	
	get_tree().current_scene.add_child(sfx)
	sfx.play()
	
	sfx.finished.connect(sfx.queue_free)
