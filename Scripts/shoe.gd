extends "res://Scripts/item.gd"

@export var speed_multiplier: float = 2.0
@export var duration: float = 10.0

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
			throwing_ghost.is_picking = false
				
		var p_id = body.input_prefix
		
		SignalBus.emit_signal("apply_speed_boost", speed_multiplier, duration, p_id)
		
		queue_free()
