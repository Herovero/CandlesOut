extends Node2D

@onready var spawn_timer = $Timer  # add a Timer node as child of WaveManager
@onready var enemy = preload("res://Scenes/enemy_test.tscn")

const MAX_ENEMIES_ON_SCREEN = 10
const WAVE_1_TOTAL = 50

var current_wave = 0
var enemies_remaining_to_spawn = 0
var enemies_alive = 0
var spawner_ref = null


func _ready() -> void:
	Global.wave = self
	print("Children:", get_children())
	print("I am:", self)
	print("Path:", get_path())
	pass # Replace with function body.

func start_wave(wave_number: int):
	current_wave = wave_number
	match wave_number:
		1:
			enemies_remaining_to_spawn = WAVE_1_TOTAL
	
	print("Wave %d started!" % current_wave)
	try_spawn()


func try_spawn():
	var slots_available = MAX_ENEMIES_ON_SCREEN - enemies_alive
	var to_spawn = mini(slots_available, enemies_remaining_to_spawn)
	
	if to_spawn > 0 and not spawn_timer.is_stopped():
		return  # timer already running, let it handle it
	
	if to_spawn > 0:
		spawn_timer.start()
		
func _on_timer_timeout():
	var slots_available = MAX_ENEMIES_ON_SCREEN - enemies_alive
	
	if slots_available <= 0 or enemies_remaining_to_spawn <= 0:
		spawn_timer.stop()
		return
	
	# pick a random spawner from all registered spawners
	if Global.spawners.is_empty():
		push_error("No spawners registered!")
		return
	
	var random_spawner = Global.spawners[randi() % Global.spawners.size()]
	random_spawner.spawn_one(random_spawner.enemy)
	enemies_remaining_to_spawn -= 1
	enemies_alive += 1
	
	if enemies_remaining_to_spawn <= 0:
		spawn_timer.stop()

func on_enemy_died():
	enemies_alive -= 1
	
	if enemies_remaining_to_spawn > 0:
		try_spawn()
	elif enemies_alive == 0:
		print("Wave %d complete!" % current_wave)


func _on_start_timer_timeout() -> void:
	start_wave(1)
	Global.item_spawner.set_spawn_state(true)
	pass # Replace with function body.
