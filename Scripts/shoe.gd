extends "res://Scripts/item.gd"

@export var speed_multiplier: float = 2.0
@export var duration: float = 10.0
@onready var shoe_sfx: AudioStreamPlayer2D = $ShoeSFX

# Called when the node enters the scene tree for the first time.
func _ready():
	super()
	custom_throw_distance = 250.0 # Shoes are aerodynamic!

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_body_entered(body):
	if is_thrown and body.is_in_group("Players"):
		if is_instance_valid(throwing_ghost):
			throwing_ghost.set_deferred("is_picking", false)
				
		var p_id = body.input_prefix
		
		if randf() < 0.5:
			SignalBus.emit_signal.call_deferred("apply_speed_backfire", speed_multiplier * 2.5, duration, p_id)
		else:
			SignalBus.emit_signal.call_deferred("apply_speed_boost", speed_multiplier, duration, p_id)
		
		queue_free()
