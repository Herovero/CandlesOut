extends CharacterBody2D

@export var input_prefix: String = "p1_"
@export var speed: float = 200.0 # Maybe ghosts move faster?

@onready var interaction_area: Area2D = $InteractionArea

var is_picking: bool = false

func _physics_process(_delta: float) -> void:
	if is_picking:
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	var direction = Input.get_vector(
		input_prefix + "move_left", input_prefix + "move_right",
		input_prefix + "move_up", input_prefix + "move_down"
	)
	
	velocity = direction * speed
	move_and_slide()

func _input(event):
	# Shared Spacebar logic you mentioned
	if event.is_action_pressed("item_pickup&throw"):
		attempt_pickup()

func attempt_pickup():
	if is_picking: return
	
	var overlapping_areas = interaction_area.get_overlapping_areas()
	for area in overlapping_areas:
		# Check if the area is a spiritual item
		if area.is_in_group("Items"):
			# If the item has a collect function, call it
			if area.has_method("on_collected"):
				is_picking = true
				area.on_collected(self)
				break
