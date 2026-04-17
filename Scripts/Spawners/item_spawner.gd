extends Node2D

var items = [
	preload("res://Scenes/item1.tscn"),
	preload("res://Scenes/item1.tscn"),
	preload("res://Scenes/item1.tscn"),
	preload("res://Scenes/item1.tscn")
]
var can_spawn : bool = false
@onready var spawn_area = $Area2D/CollisionShape2D
@export var min_x: float = 0
@export var min_y: float = 0
var items_alive:int = 0
const MAX_ITEMS:int = 5

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
		return
	
	var random_item = items[randi() % items.size()]
	var item_instance = random_item.instantiate()
	item_instance.global_position = get_random_spawn_position()
	get_tree().current_scene.add_child(item_instance)
	
	items_alive += 1
	item_instance.tree_exited.connect(_on_item_removed)
	
func _on_item_removed() -> void:
	items_alive -= 1
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.item_spawner = self
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_timer_timeout() -> void:
	spawn_one()
	pass # Replace with function body.
