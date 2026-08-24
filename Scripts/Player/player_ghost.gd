extends CharacterBody2D

@export var input_prefix: String = "p1_"
@export_range(1, 2) var player_slot: int = 1
var controlling_peer_id: int = 1
@export var speed: float = 400.0 # Maybe ghosts move faster?
@export var throw_distance: float = 250.0

@onready var interaction_area: Area2D = $InteractionArea
@onready var anim := $AnimatedSprite2D

var active: bool = false:
	set(value):
		active = value
		if is_node_ready():
			_apply_active_state()
var is_picking: bool = false
var held_item: Node2D = null
var current_dir: Vector2 = Vector2.ZERO # Store the latest movement
var network_generation: int = 0
var network_position: Vector2 = Vector2.ZERO
var network_velocity: Vector2 = Vector2.ZERO
var _presented_active: bool = false

func _ready():
	anim.sprite_frames.set_animation_speed("default", 10)
	anim.play()
	network_generation = NetworkSession.match_generation
	network_position = position
	network_velocity = velocity
	_presented_active = active
	NetworkSession.configure_moving_synchronizer(self, [&"active"])
	_apply_active_state()
	if not NetworkSession.has_simulation_authority():
		interaction_area.set_deferred("monitoring", false)
		interaction_area.set_deferred("monitorable", false)

func _physics_process(delta: float) -> void:
	if not NetworkSession.has_simulation_authority():
		NetworkSession.interpolate_movement(self, delta, active != _presented_active)
		if network_velocity.x != 0:
			anim.flip_h = network_velocity.x > 0
		_presented_active = active
		return
	if not active:
		return
	if velocity.x != 0:
		anim.flip_h = velocity.x > 0
	if is_picking:
		velocity = Vector2.ZERO
		move_and_slide()
		NetworkSession.publish_movement(self, velocity)
		return

	var direction := Vector2.ZERO
	if NetworkSession.is_online():
		var owner_player := _get_owner_player()
		if owner_player:
			direction = owner_player.command_direction
	else:
		direction = Input.get_vector(
			input_prefix + "move_left", input_prefix + "move_right",
			input_prefix + "move_up", input_prefix + "move_down"
		)
	
	current_dir = direction # Update aim direction
	velocity = direction * speed
	move_and_slide()
	NetworkSession.publish_movement(self, velocity)

func _input(event):
	if not active or not NetworkSession.has_simulation_authority():
		return
	if NetworkSession.is_online() and controlling_peer_id != NetworkSession.HOST_PEER_ID:
		return
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

func _apply_active_state() -> void:
	visible = active
	$CollisionShape2D.set_deferred("disabled", not active)
	$InteractionArea/CollisionShape2D.set_deferred("disabled", not active)
	if not active:
		velocity = Vector2.ZERO
		is_picking = false
		held_item = null
		if NetworkSession.has_simulation_authority():
			NetworkSession.publish_movement(self, velocity)


func _get_owner_player() -> Node:
	for player in get_tree().get_nodes_in_group("Players"):
		if int(player.get("player_slot")) == player_slot:
			return player
	return null


func attempt_pickup():
	if not NetworkSession.has_simulation_authority():
		return
	var overlapping_areas = interaction_area.get_overlapping_areas()
	for area in overlapping_areas:
		# Check if the area is a spiritual item
		if area.is_in_group("Items"):
			# If the item has a collect function, call it
			if area.has_method("on_collected"):
				is_picking = true
				held_item = area # Store the item reference
				area.on_collected(self)
				
				# FAILSAFE: If the item doesn't unlock the ghost within 0.5s, 
				# unlock it manually to prevent the movement bug.
				get_tree().create_timer(0.5).connect("timeout", func(): is_picking = false)
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
