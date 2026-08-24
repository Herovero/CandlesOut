extends HBoxContainer

@export_range(1, 2) var player_slot: int = 1

var heart_full: Texture2D = preload("res://Assets/UIs/heart_full.png")
var heart_half: Texture2D = preload("res://Assets/UIs/heart_half.png")
var heart_empty: Texture2D = preload("res://Assets/UIs/heart_empty.png")

var hearts_list: Array[TextureRect] = []
var observed_player: Node = null
var _last_health: float = -1.0


func _ready() -> void:
	for child in get_children():
		if child is TextureRect:
			hearts_list.append(child)
	_find_player()
	update_heart_visuals()


func _process(_delta: float) -> void:
	if not is_instance_valid(observed_player):
		_find_player()
	if not is_instance_valid(observed_player):
		return
	var current_health := float(observed_player.health)
	if not is_equal_approx(current_health, _last_health):
		_last_health = current_health
		update_heart_visuals()


func _find_player() -> void:
	for player in get_tree().get_nodes_in_group("Players"):
		if int(player.get("player_slot")) == player_slot:
			observed_player = player
			_last_health = float(player.get("health"))
			return


func update_heart_visuals() -> void:
	var health := _last_health if _last_health >= 0.0 else 0.0
	for i in range(hearts_list.size()):
		var heart_node := hearts_list[i]
		if health >= i + 1:
			heart_node.texture = heart_full
		elif health >= i + 0.5:
			heart_node.texture = heart_half
		else:
			heart_node.texture = heart_empty
