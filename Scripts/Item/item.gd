extends Area2D

enum ItemState { WORLD, HELD, THROWN }

var item_state: ItemState = ItemState.WORLD
var held_by_slot: int = 0
var is_thrown: bool = false
var holding_ghost: CharacterBody2D = null
var throwing_ghost: CharacterBody2D = null
@export var custom_throw_distance: float = 250.0

@onready var heart_sfx: AudioStreamPlayer2D = get_node_or_null("HeartSFX")
@onready var item_sprite = $Sprite2D

var float_time: float = 0.0
@export var float_speed: float = 2.0
@export var float_amplitude: float = 4.0


func _ready() -> void:
	visible = false
	monitorable = false
	monitoring = false
	NetworkSession.configure_synchronizer(self, [
		&"position", &"rotation", &"visible", &"is_thrown", &"item_state", &"held_by_slot",
	])
	if not NetworkSession.has_simulation_authority():
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)


func _process(delta: float) -> void:
	item_sprite.modulate.a = randf_range(0.4, 0.6)
	if not NetworkSession.has_simulation_authority():
		return
	if item_state == ItemState.HELD:
		if not is_instance_valid(holding_ghost):
			holding_ghost = _find_ghost_for_slot(held_by_slot)
		if is_instance_valid(holding_ghost):
			global_position = holding_ghost.global_position + Vector2(0, -40)
		return
	if item_state == ItemState.WORLD:
		float_time += delta
		item_sprite.position.y = sin(float_time * float_speed) * float_amplitude


func show_item() -> void:
	if not NetworkSession.has_simulation_authority():
		return
	modulate.a = 0.0
	visible = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	set_deferred("monitorable", true)
	set_deferred("monitoring", true)


func hide_item() -> void:
	if not NetworkSession.has_simulation_authority() or item_state != ItemState.WORLD:
		return
	set_deferred("monitorable", false)
	set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func on_collected(target_ghost: CharacterBody2D) -> void:
	if not NetworkSession.has_simulation_authority() or item_state != ItemState.WORLD:
		return
	item_state = ItemState.HELD
	held_by_slot = int(target_ghost.player_slot)
	holding_ghost = target_ghost
	is_thrown = false
	monitorable = false
	monitoring = false
	var target_pos := Vector2(0, -40)
	var global_target := target_ghost.global_position + target_pos
	var tween := create_tween()
	tween.tween_property(self, "global_position", global_target, 0.3) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: _finish_pickup(target_ghost, target_pos))


func _finish_pickup(ghost: CharacterBody2D, _offset: Vector2) -> void:
	if is_instance_valid(ghost):
		ghost.is_picking = false


func on_dropped() -> void:
	if not NetworkSession.has_simulation_authority() or item_state != ItemState.HELD:
		return
	var ghost := holding_ghost
	if not is_instance_valid(ghost):
		ghost = _find_ghost_for_slot(held_by_slot)
	if not is_instance_valid(ghost):
		return
	item_state = ItemState.WORLD
	held_by_slot = 0
	holding_ghost = null
	is_thrown = false
	var tween := create_tween()
	tween.tween_property(self, "global_position", ghost.global_position, 0.3) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void: _finish_drop(ghost))


func _finish_drop(ghost: CharacterBody2D) -> void:
	monitoring = true
	monitorable = true
	if is_instance_valid(ghost):
		ghost.is_picking = false


func on_thrown(target_global_pos: Vector2) -> void:
	if not NetworkSession.has_simulation_authority() or item_state != ItemState.HELD:
		return
	var ghost := holding_ghost
	if not is_instance_valid(ghost):
		ghost = _find_ghost_for_slot(held_by_slot)
	if not is_instance_valid(ghost):
		return
	throwing_ghost = ghost
	holding_ghost = null
	held_by_slot = 0
	item_state = ItemState.THROWN
	is_thrown = true
	monitoring = true
	monitorable = true
	var tween := create_tween()
	tween.tween_property(self, "global_position", target_global_pos, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "rotation", rotation + PI * 2, 0.4)
	tween.tween_callback(func() -> void: _finish_throw(ghost))


func _finish_throw(ghost: CharacterBody2D) -> void:
	item_state = ItemState.WORLD
	is_thrown = false
	throwing_ghost = null
	monitoring = true
	monitorable = true
	if is_instance_valid(ghost):
		ghost.is_picking = false
	if Global.item_spawner and Global.item_spawner.active_ghost_slots.is_empty():
		hide_item()


func _find_ghost_for_slot(slot: int) -> CharacterBody2D:
	for ghost in get_tree().get_nodes_in_group("Ghost"):
		if int(ghost.get("player_slot")) == slot:
			return ghost as CharacterBody2D
	return null


func _on_body_entered(body: Node) -> void:
	if not NetworkSession.has_simulation_authority():
		return
	if is_thrown and body.is_in_group("Players"):
		if is_instance_valid(throwing_ghost):
			throwing_ghost.is_picking = false
		body.apply_damage(-3.0)
		if heart_sfx:
			play_heart_sfx()
		queue_free()


func play_heart_sfx() -> void:
	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = heart_sfx.stream
	sfx.global_position = global_position
	get_tree().current_scene.add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)
