extends Node2D

@onready var gameover_label = $HUDs/gameover_label
@onready var restart_button = $HUDs/restart_button

# Called when the node enters the scene tree for the first time.
func _ready():
	get_tree().paused = false
	gameover_label.hide()
	restart_button.hide()
	
	SignalBus.connect("game_over", _on_game_over)

# Called every frame. 'delta' is the elapsed time since the previous frame.
# In a central script (e.g., Main.gd or GameManager.gd)
func _process(_delta):
	check_total_sleep_condition()

func check_total_sleep_condition():
	var players = get_tree().get_nodes_in_group("Players")
	var sleeping_count = 0
	
	for p in players:
		if p.is_sleeping:
			sleeping_count += 1
			
	# Condition 2: Both players are ghosts/sleeping
	if players.size() > 0 and sleeping_count >= players.size():
		SignalBus.emit_signal("game_over", "Both players fell asleep!")

func _on_game_over(reason: String):
	pass
	"""## Pause the game
	gameover_label.show()
	restart_button.show()
	get_tree().paused = true
	# Show your Game Over UI here
	pass"""
