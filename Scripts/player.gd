extends CharacterBody2D

@export var speed = 300.0

func _physics_process(_delta):
	# Get input direction (-1, 0, or 1 for both axes)
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# Apply movement
	velocity = direction * speed
	
	# move_and_slide uses the 'velocity' property automatically
	move_and_slide()
