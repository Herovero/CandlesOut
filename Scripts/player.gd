extends CharacterBody2D

@export var input_prefix: String = "p1_"
@export var speed: float = 300.0

func _physics_process(_delta):
	# Construct the action names dynamically
	var move_left = input_prefix + "move_left"
	var move_right = input_prefix + "move_right"
	var move_up = input_prefix + "move_up"
	var move_down = input_prefix + "move_down"
	
	# Get the vector based on the dynamic names
	var direction = Input.get_vector(move_left, move_right, move_up, move_down)
	
	velocity = direction * speed
	move_and_slide()
