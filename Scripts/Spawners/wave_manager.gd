extends Node2D

@export var ost_manager: Node
@onready var spawn_timer = $Timer  # add a Timer node as child of WaveManager
signal wave_completed(wave_number : int)

@onready var wave_notice_label = $"../HUDs/wave_label"

const WAVE_DATA = {
	1: [
		{"scene": preload("res://Scenes/Enemy/enemy_test.tscn"), "count": 6},
		{"scene": preload("res://Scenes/Enemy/enemy_ranged.tscn"), "count": 0},
		{"scene": preload("res://Scenes/Enemy/enemy_boss.tscn"), "count": 0}
		],
	2: [
		{"scene": preload("res://Scenes/Enemy/enemy_ranged.tscn"), "count": 4},
		{"scene": preload("res://Scenes/Enemy/enemy_test.tscn"), "count": 4},
		],
	3: [
		{"scene": preload("res://Scenes/Enemy/enemy_ranged.tscn"), "count": 6},
		{"scene": preload("res://Scenes/Enemy/enemy_test.tscn"), "count": 6},
		{"scene": preload("res://Scenes/Enemy/enemy_boss.tscn"), "count": 0}
	],
	4: [
		{"scene": preload("res://Scenes/Enemy/enemy_ranged.tscn"), "count": 0},
		{"scene": preload("res://Scenes/Enemy/enemy_test.tscn"), "count": 0},
		{"scene": preload("res://Scenes/Enemy/enemy_boss.tscn"), "count": 1}
	]
}

var MAX_ENEMIES_ON_SCREEN = 0
const WAVE_1_TOTAL = 50

var spawn_queue: Array = []  # will hold one entry per enemy to spawn
var enemies_alive = 0
var current_wave = 0
var spawner_ref = null

func set_max_enemy(number : int) -> void:
	MAX_ENEMIES_ON_SCREEN = number

func _ready() -> void:
	if not NetworkSession.has_simulation_authority():
		spawn_timer.stop()
		$StartTimer.stop()
		return
	wave_completed.connect(_on_wave_completed)
	Global.wave = self
	print("OST:", ost_manager)
	pass # Replace with function body.

func start_wave(wave_number: int):
	if not NetworkSession.has_simulation_authority():
		return
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
	
	if wave_notice_label:
		if wave_number == 4:
			wave_notice_label.text = "BOSS WAVE" # Or "THE FINAL RITUAL"
			wave_notice_label.add_theme_color_override("font_color", Color(0.882, 0.0, 0.086, 1.0)) # Red for danger
			wave_notice_label.pivot_offset = wave_notice_label.size / 2
		else:
			wave_notice_label.text = "WAVE " + str(wave_number)
			wave_notice_label.add_theme_color_override("font_color", Color(1, 1, 1)) # White for normal waves)
			wave_notice_label.pivot_offset = Vector2.ZERO
		
		wave_notice_label.modulate.a = 0 # Start fully transparent
		wave_notice_label.show()
		
		# Create a tween for the sequence
		var tween = create_tween()
		
		tween.set_parallel(true)
		
		# 1. Fade In (0.5 seconds)
		if wave_number == 4:
			tween.tween_property(wave_notice_label, "modulate:a", 1.0, 0.4)
			tween.tween_property(wave_notice_label, "scale", Vector2(1.5, 1.5), 0.4)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			# Standard entrance for normal waves
			tween.tween_property(wave_notice_label, "modulate:a", 1.0, 0.5)
			tween.tween_property(wave_notice_label, "scale", Vector2(1.0, 1.0), 0.5)
		
		tween.set_parallel(false)
		
		# 2. Stay visible
		tween.tween_interval(2.0)
		
		# 3. Fade Out (0.5 seconds)
		tween.tween_property(wave_notice_label, "modulate:a", 0.0, 0.5)
		
		# 4. Final Cleanup
		tween.tween_callback(wave_notice_label.hide)
		
		# Wait for the whole sequence to finish before spawning
		await tween.finished

	print("Wave %d started! Total enemies: %d" % [current_wave, spawn_queue.size()])
	try_spawn()


func try_spawn():
	var slots_available = MAX_ENEMIES_ON_SCREEN - enemies_alive

	if slots_available <= 0 or spawn_queue.is_empty():
		print("Max enemy on screen")
		return

	if not spawn_timer.is_stopped():
		return  # timer already running, let it handle it

	spawn_timer.start()


func _on_timer_timeout():
	if not NetworkSession.has_simulation_authority():
		return
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
	if not is_inside_tree() or not NetworkSession.has_simulation_authority():
		return
	enemies_alive = maxi(enemies_alive - 1, 0)

	if not spawn_queue.is_empty():
		try_spawn()
	elif enemies_alive == 0:
		print("Wave %d complete!" % current_wave)
		wave_completed.emit(current_wave)


func _on_start_timer_timeout() -> void:
	if not NetworkSession.has_simulation_authority():
		return
	if Global.skip_to_boss:
		# Reset the flag so it doesn't stay true next time
		Global.skip_to_boss = false
		
		# Boss logic setup [cite: 65]
		NetworkSession.broadcast_music(3) # Play the 3rd OST (Boss track) [cite: 66]
		set_max_enemy(5) # Set appropriate enemy count for boss [cite: 65]
		start_wave(4) # Start the defined Boss Wave [cite: 60, 62]
		
		# Ensure items are in the correct phase [cite: 65]
		if Global.item_spawner:
			Global.item_spawner.set_bomb_phase(true)
	else:
		# Standard start 
		NetworkSession.broadcast_music(1)
		set_max_enemy(3)
		start_wave(1)

func _on_wave_completed(wave_number: int):
	print("Wave signal emmitted")
	
	NetworkSession.broadcast_music_stop()
	
	# Guard against null tree during scene transitions/restarts 
	if not is_inside_tree():
		return
	
	await get_tree().create_timer(2.0).timeout
	
	# Re-check after the await, as the scene might have changed during the 2s wait
	if not is_inside_tree():
		return
	
	match wave_number:
		1:
			await get_tree().create_timer(2.0).timeout
			set_max_enemy(4)
			start_wave(2)
			NetworkSession.broadcast_music(1)
		2:
			await get_tree().create_timer(2.0).timeout
			set_max_enemy(4)
			start_wave(3)
			NetworkSession.broadcast_music(2)
			Global.item_spawner.set_bomb_phase(true)
		3:
			await get_tree().create_timer(2.0).timeout
			set_max_enemy(5)
			start_wave(4)
			NetworkSession.broadcast_music(3)
			Global.item_spawner.set_bomb_phase(true)
		4:
			print("Boss defeated! All waves complete.")
