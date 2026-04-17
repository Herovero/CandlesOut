extends Node2D

@onready var spawn_timer = $Timer  # add a Timer node as child of WaveManager
signal wave_completed(wave_number : int)
			
const WAVE_DATA = {
	1: [
		{"scene": preload("res://Scenes/enemy_test.tscn"), "count": 10},
		{"scene": preload("res://Scenes/enemy_ranged.tscn"), "count": 0},
		],
	2: [
		{"scene": preload("res://Scenes/enemy_ranged.tscn"), "count": 15},
		{"scene": preload("res://Scenes/enemy_test.tscn"), "count": 30},
		],
	3: [
		{"scene": preload("res://Scenes/enemy_ranged.tscn"), "count": 15},
		{"scene": preload("res://Scenes/enemy_test.tscn"), "count": 30},
		]
}

const MAX_ENEMIES_ON_SCREEN = 10
const WAVE_1_TOTAL = 50

var spawn_queue: Array = []  # will hold one entry per enemy to spawn
var enemies_alive = 0
var current_wave = 0
var spawner_ref = null


func _ready() -> void:
	wave_completed.connect(_on_wave_completed)
	Global.wave = self
	print("Children:", get_children())
	print("I am:", self)
	print("Path:", get_path())
	pass # Replace with function body.

func start_wave(wave_number: int):
	current_wave = wave_number
	spawn_queue.clear()
	
	if not WAVE_DATA.has(wave_number):
		push_error("Wave %d not defined!" % wave_number)
		return
	
	# build a flat queue of enemy scenes to spawn
	for entry in WAVE_DATA[wave_number]:
		for i in entry["count"]:
			spawn_queue.append(entry["scene"])
	
	# optional: shuffle so enemy types are mixed
	spawn_queue.shuffle()
	
	print("Wave %d started! Total enemies: %d" % [current_wave, spawn_queue.size()])
	try_spawn()


func try_spawn():
	var slots_available = MAX_ENEMIES_ON_SCREEN - enemies_alive
	
	if slots_available <= 0 or spawn_queue.is_empty():
		return
	
	if not spawn_timer.is_stopped():
		return  # timer already running, let it handle it
	
	spawn_timer.start()
	
		
func _on_timer_timeout():
	var slots_available = MAX_ENEMIES_ON_SCREEN - enemies_alive
	
	if slots_available <= 0 or spawn_queue.is_empty():
		spawn_timer.stop()
		return
	
	if Global.spawners.is_empty():
		push_error("No spawners registered!")
		return
	
	var enemy_scene = spawn_queue.pop_front()  # grab next enemy from queue
	var random_spawner = Global.spawners[randi() % Global.spawners.size()]
	#print("spawning %d", enemy_scene)
	random_spawner.spawn_one(enemy_scene)
	enemies_alive += 1
	
	if spawn_queue.is_empty():
		spawn_timer.stop()

func on_enemy_died():
	enemies_alive -= 1
	
	if not spawn_queue.is_empty():
		try_spawn()
	elif enemies_alive == 0:
		print("Wave %d complete!" % current_wave)
		wave_completed.emit(current_wave)


func _on_start_timer_timeout() -> void:
	start_wave(1)
	pass # Replace with function body.

func _on_wave_completed(wave_number: int):
	print("Wave signal emmitted")
	match wave_number:
		1:
			start_wave(2)
		2:
			start_wave(3)
		
