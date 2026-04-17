extends CharacterBody2D

@export var input_prefix: String = "p1_"
@export var speed: float = 300.0 # Maybe ghosts move faster?
@export var throw_distance: float = 250.0

@onready var interaction_area: Area2D = $InteractionArea

var is_picking: bool = false
var held_item: Node2D = null
var current_dir: Vector2 = Vector2.ZERO # Store the latest movement

func _physics_process(_delta: float) -> void:
	if is_picking:
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	var direction = Input.get_vector(
		input_prefix + "move_left", input_prefix + "move_right",
		input_prefix + "move_up", input_prefix + "move_down"
	)
	
	current_dir = direction # Update aim direction
	velocity = direction * speed
	move_and_slide()

func _input(event):
	if is_picking: 
		return
		
	# Shared Spacebar logic you mentioned
	if event.is_action_pressed("item_pickup&throw"):
		if held_item == null:
			attempt_pickup()
		else:
			# If we are moving (direction != 0), THROW. If standing still, DROP.
			if current_dir != Vector2.ZERO:
				throw_item(current_dir)
			else:
				drop_item()

func attempt_pickup():
	var overlapping_areas = interaction_area.get_overlapping_areas()
	for area in overlapping_areas:
		# Check if the area is a spiritual item
		if area.is_in_group("Items"):
			# If the item has a collect function, call it
			if area.has_method("on_collected"):
				is_picking = true
				held_item = area # Store the item reference
				area.on_collected(self)
				break

func drop_item():
	if held_item and held_item.has_method("on_dropped"):
		is_picking = true
		held_item.on_dropped()
		held_item = null # Clear the reference immediately

func throw_item(dir: Vector2):
	if held_item and held_item.has_method("on_thrown"):
		is_picking = true
		
		# Check if the item has a custom distance, otherwise use ghost default
		var dist = throw_distance
		if "custom_throw_distance" in held_item:
			dist = held_item.custom_throw_distance
			
		# Calculate target based on the ITEM'S preferred distance
		var target_pos = global_position + (dir.normalized() * dist)
		
		held_item.on_thrown(target_pos)
		held_item = null
