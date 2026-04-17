extends Node2D

@onready var gameover_label = $HUDs/gameover_label
@onready var restart_button = $HUDs/restart_button

@onready var p1 = $Player1
@onready var p2 = $Player2
@onready var p1_effect_label = $HUDs/Player1/EffectLabel
@onready var p1_effect_icon = $HUDs/Player1/EffectIcon
@onready var p2_effect_label = $HUDs/Player2/EffectLabel
@onready var p2_effect_icon = $HUDs/Player2/EffectIcon

# Called when the node enters the scene tree for the first time.
func _ready():
	get_tree().paused = false
	gameover_label.hide()
	restart_button.hide()

	p1_effect_icon.visible = false
	p2_effect_icon.visible = false
	p1_effect_label.visible = false
	p2_effect_label.visible = false
	
	SignalBus.connect("game_over", _on_game_over)

# Called every frame. 'delta' is the elapsed time since the previous frame.
# In a central script (e.g., Main.gd or GameManager.gd)
func _process(_delta):
	check_total_sleep_condition()
	update_effect_ui()

func check_total_sleep_condition():
	var players = get_tree().get_nodes_in_group("Players")
	var sleeping_count = 0
	
	for p in players:
		if p.is_sleeping:
			sleeping_count += 1
			
	# Condition 2: Both players are ghosts/sleeping
	if players.size() > 0 and sleeping_count >= players.size():
		SignalBus.emit_signal("game_over", "Both players fell asleep!")

func update_one_effect_ui(player, label: Label, icon: TextureRect) -> void:
	if player and player.has_method("has_active_effect") and player.has_active_effect():
		label.text = "%s (%ds)" % [player.active_effect_name, int(ceil(player.active_effect_time_left))]
		label.visible = true
		icon.texture = player.active_effect_icon
		icon.visible = player.active_effect_icon != null
	else:
		label.visible = false
		icon.texture = null
		icon.visible = false


func update_effect_ui() -> void:
	update_one_effect_ui(p1, p1_effect_label, p1_effect_icon)
	update_one_effect_ui(p2, p2_effect_label, p2_effect_icon)


func _on_game_over(reason: String):
	#print("Game Over: ", reason)
	## Pause the game
	gameover_label.show()
	restart_button.show()
	get_tree().paused = true
	# Show your Game Over UI here
	pass
