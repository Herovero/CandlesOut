extends Node2D


@onready var enemy = preload("res://Scenes/enemy_test.tscn")
@onready var ranged_enemy = preload("res://Scenes/enemy_ranged.tscn")
@onready var spawn_area = $Area2D/CollisionShape2D
@export var min_x: float = 0
@export var min_y: float = 0
@export var ranged_spawn_chance: float = 0.35

var wave_ref = null
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("spawner")
	Global.spawners.append(self)
	pass # Replace with function body.


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

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func spawn_n(count: int, enemy_toSpawn):
	for i in count:
		spawn_one(enemy_toSpawn)

func spawn_one(enemy_toSpawn):
	var scene_to_spawn = enemy_toSpawn
	if enemy_toSpawn == enemy and randf() < ranged_spawn_chance:
		scene_to_spawn = ranged_enemy

	var ene = scene_to_spawn.instantiate()
	ene.position = get_random_spawn_position()
	get_tree().current_scene.add_child(ene)
	# tell wave manager when this enemy dies
	var wm = Global.wave
	ene.tree_exited.connect(wm.on_enemy_died)

func _exit_tree() -> void:
	Global.spawners.erase(self)
