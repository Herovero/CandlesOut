extends Area2D

var is_thrown: bool = false
var throwing_ghost: CharacterBody2D = null
@export var custom_throw_distance: float = 250.0

@onready var heart_sfx: AudioStreamPlayer2D = $HeartSFX

# Called when the node enters the scene tree for the first time.
func _ready():
	visible = false
	monitorable = false
	monitoring = false
	
	SignalBus.connect("item_spawned", show_item)
	SignalBus.connect("ghost_mode_ended", hide_item)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func show_item():
	visible = true
	set_deferred("monitorable", true)
	set_deferred("monitoring", true)

func hide_item():
	visible = false
	set_deferred("monitorable", false)
	set_deferred("monitoring", false)

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

func on_thrown(target_global_pos: Vector2):
	is_thrown = true # Mark as active projectile
	monitoring = true
	monitorable = true
	
	throwing_ghost = get_parent()
	
	# 1. Identify the ghost (current parent) and the world
	var ghost = get_parent()
	var world = ghost.get_parent()
	
	# 2. Record global position before changing the hierarchy
	var current_pos = global_position
	
	# 3. Detach from ghost and add to world so it stays in place
	ghost.remove_child(self)
	world.add_child(self)
	global_position = current_pos
	
	# 4. Create the throw animation
	var tween = create_tween()
	
	# Move to the target calculated by ghost movement
	tween.tween_property(self, "global_position", target_global_pos, 0.4)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	
	# Parallel rotation for visual "juice"
	tween.parallel().tween_property(self, "rotation", rotation + PI * 2, 0.4)
	
	# 5. Unlock the ghost once the throw is complete
	tween.tween_callback(func(): _finish_throw(ghost))

func _finish_throw(ghost):
	# Re-enable detection so it can be picked up again at its new location
	monitoring = true
	monitorable = true
	if is_instance_valid(ghost):
		ghost.is_picking = false

func _on_body_entered(body):
	# Only trigger if the item is currently flying
	if is_thrown and body.is_in_group("Players"):
		if is_instance_valid(throwing_ghost):
			throwing_ghost.is_picking = false
				
		# Since your players have an 'input_prefix' 
		var p_id = body.input_prefix
		
		# Trigger the heal via SignalBus [cite: 5]
		SignalBus.emit_signal("take_damage", -1.0, p_id)
		
		# Item is 'consumed'
		play_heart_sfx()
		queue_free()
		
func play_heart_sfx():
	var sfx = AudioStreamPlayer2D.new()
	sfx.stream = heart_sfx.stream
	sfx.global_position = global_position
	
	get_tree().current_scene.add_child(sfx)
	sfx.play()
	
	sfx.finished.connect(sfx.queue_free)
