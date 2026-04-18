extends Node2D

var items = [
	#preload("res://Scenes/item1.tscn"),
	#preload("res://Scenes/item_bomb.tscn"),
	#preload("res://Scenes/item_coffee.tscn"),
	#preload("res://Scenes/item_shoe.tscn"),
	#preload("res://Scenes/item_lighter.tscn"),
	#preload("res://Scenes/item_oil.tscn"),
	preload("res://Scenes/item_shield.tscn")
]

var normal_weights = [30, 10, 30, 10, 10, 10, 10]
var bomb_weights =   [10,  10, 10,  0,  5,  0, 0]  # bomb is index 1, much higher chance
var current_weights: Array

var can_spawn : bool = false
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
	if not can_spawn:
		return
	if items_alive >= MAX_ITEMS:
		print_debug("max item reached")
		return
	
	var random_item = get_weighted_random_item()  # replace old randi() line
	var item_instance = random_item.instantiate()
	print_debug("spawning item")
	item_instance.global_position = get_random_spawn_position()
	get_tree().current_scene.add_child(item_instance)
	
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
	Global.item_spawner = self
	SignalBus.connect("ghost_mode_started",  func(): set_spawn_state(true))
	SignalBus.connect("ghost_mode_ended",  func(): set_spawn_state(false))
	SignalBus.connect("ghost_mode_ended", func(): destroy_all_items())
	pass # Replace with function body.

func set_bomb_phase(enabled: bool) -> void:
	current_weights = bomb_weights.duplicate() if enabled else normal_weights.duplicate()


func destroy_all_items() -> void:
	# get all children of current scene and remove items
	print("destroy all items")
	for item in get_tree().get_nodes_in_group("items"):
		if item.has_method("hide_item"):
			item.hide_item() # This triggers your new fade-out tween!
		else:
			item.queue_free()
	items_alive = 0

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
	spawn_one()
	pass # Replace with function body.
