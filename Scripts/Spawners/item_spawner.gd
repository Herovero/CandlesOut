extends Node2D

var items = [
	preload("res://Scenes/Items/item1.tscn"),
	preload("res://Scenes/Items/item_bomb.tscn"),
	preload("res://Scenes/Items/item_coffee.tscn"),
	preload("res://Scenes/Items/item_shoe.tscn"),
	preload("res://Scenes/Items/item_lighter.tscn"),
	preload("res://Scenes/Items/item_oil.tscn"),
	preload("res://Scenes/Items/item_shield.tscn")
]

var normal_weights = [15, 10, 15, 10, 5, 10, 10]
var bomb_weights =   [10,  10, 10,  0,  5,  0, 0]  # bomb is index 1, much higher chance
var current_weights: Array

var can_spawn: bool = false
var active_ghost_slots: Dictionary = {}
@onready var spawn_area = $Area2D/CollisionShape2D
@export var min_x: float = 0
@export var min_y: float = 0
var items_alive:int = 0
const MAX_ITEMS:int = 10

func get_random_spawn_position() -> Vector2:
	var shape = spawn_area.shape as RectangleShape2D
	var extents = shape.size / 2
	
	# minimum distance from center
	var rand_x: float
	var rand_y: float
	
	# randomly pick a side to spawn on
	if randf() > 0.5:
		# spawn on left or right side
		rand_x = randf_range(min_x, extents.x) * (1 if randf() > 0.5 else -1)
		rand_y = randf_range(-extents.y, extents.y)
		return spawn_area.global_position + Vector2(rand_x, rand_y)
	else:
		# spawn on top or bottom side
		rand_x = randf_range(-extents.x, extents.x)
		rand_y = randf_range(min_y, extents.y) * (1 if randf() > 0.5 else -1)
		return spawn_area.global_position + Vector2(rand_x, rand_y)

func set_spawn_state(state: bool) -> void:
	can_spawn = state

func spawn_one() -> void:
	if NetworkSession.is_in_lobby() or not NetworkSession.has_simulation_authority() or not can_spawn:
		return
	if items_alive >= MAX_ITEMS:
		#print_debug("max item reached")
		return
	
	var random_item = get_weighted_random_item()
	var item_instance := NetworkSession.spawn_replicated(random_item, {
		"global_position": get_random_spawn_position(),
	})
	if item_instance == null:
		return
	
	# Call show_item directly on the new instance instead of using SignalBus 
	if item_instance.has_method("show_item"):
		item_instance.show_item()
	
	item_instance.add_to_group("items")
	items_alive += 1
	item_instance.tree_exited.connect(_on_item_removed)
	
func _on_item_removed() -> void:
	items_alive -= 1
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	current_weights = normal_weights.duplicate()
	if NetworkSession.is_in_lobby() or not NetworkSession.has_simulation_authority():
		$Timer.stop()
		return
	Global.item_spawner = self
	SignalBus.connect("ghost_mode_started", _on_ghost_mode_started)
	SignalBus.connect("ghost_mode_ended", _on_ghost_mode_ended)

func _on_ghost_mode_started(player_slot: int) -> void:
	active_ghost_slots[player_slot] = true
	set_spawn_state(true)


func _on_ghost_mode_ended(player_slot: int) -> void:
	active_ghost_slots.erase(player_slot)
	if active_ghost_slots.is_empty():
		set_spawn_state(false)
		destroy_all_items()


func set_bomb_phase(enabled: bool) -> void:
	current_weights = bomb_weights.duplicate() if enabled else normal_weights.duplicate()


func destroy_all_items() -> void:
	# get all children of current scene and remove items
	print("destroy all items")
	for item in get_tree().get_nodes_in_group("items"):
		if int(item.get("item_state")) == 0:
			if item.has_method("hide_item"):
				item.hide_item()
			else:
				item.queue_free()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func get_weighted_random_item():
	var total_weight = 0
	for w in current_weights:
		total_weight += w
	
	var roll = randi() % total_weight
	var cumulative = 0
	for i in items.size():
		cumulative += current_weights[i]
		if roll < cumulative:
			return items[i]
	return items[0]

func _on_timer_timeout() -> void:
	if NetworkSession.is_in_lobby():
		return
	spawn_one()
	pass # Replace with function body.
