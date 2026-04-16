extends Area2D

# Called when the node enters the scene tree for the first time.
func _ready():
	visible = false
	monitorable = false
	monitoring = false
	
	SignalBus.connect("ghost_mode_started", show_item)
	SignalBus.connect("ghost_mode_ended", hide_item)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func show_item():
	visible = true
	monitorable = true
	monitoring = true

func hide_item():
	visible = false
	monitorable = false
	monitoring = false

func on_collected(target_ghost: CharacterBody2D):
	# Now 'target_ghost' is declared and usable!
	monitorable = false
	monitoring = false
	
	var tween = create_tween()
	var target_pos = Vector2(0, -40) # Position above head
	var global_target = target_ghost.global_position + target_pos
	
	tween.tween_property(self, "global_position", global_target, 0.3)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
	
	# Attach to ghost after flying
	tween.tween_callback(func(): _finish_pickup(target_ghost, target_pos))

func _finish_pickup(ghost: CharacterBody2D, offset: Vector2):
	_attach_to_ghost(ghost, offset)
	
	if is_instance_valid(ghost):
		ghost.is_picking = false

func on_dropped():
	# 1. Get the ghost (current parent) and the world (the ghost's parent)
	var ghost = get_parent()
	var world = ghost.get_parent()
	
	# 2. Record current global position before reparenting
	var current_global_pos = global_position
	var drop_target_pos = ghost.global_position # Drop to the ghost's center
	
	# 3. Move from Ghost back to World scene tree
	ghost.remove_child(self)
	world.add_child(self)
	global_position = current_global_pos
	
	# 4. Tween downward to the ghost's middle position
	var tween = create_tween()
	tween.tween_property(self, "global_position", drop_target_pos, 0.3)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN_OUT)
	
	# 5. Unlock the ghost and re-enable item detection
	tween.tween_callback(func(): _finish_drop(ghost))

func _finish_drop(ghost):
	monitoring = true
	monitorable = true
	if is_instance_valid(ghost):
		ghost.is_picking = false
		
func _attach_to_ghost(ghost: CharacterBody2D, offset: Vector2):
	if is_instance_valid(ghost):
		get_parent().remove_child(self)
		ghost.add_child(self)
		position = offset
