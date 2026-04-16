extends HBoxContainer

var heart_full = preload("res://Assets/UIs/heart_full.png")
var heart_half = preload("res://Assets/UIs/heart_half.png")
var heart_empty = preload("res://Assets/UIs/heart_empty.png")

var hearts_list: Array[TextureRect]
var health: float = 5

func _ready() -> void:
	var hearts_parent = $"."
	for child in hearts_parent.get_children():
		hearts_list.append(child)
	update_heart_visuals()

func take_damage(amount: float):
	health -= amount
	health = clamp(health, 0, hearts_list.size()) # Prevent negative health
	update_heart_visuals()
		
func update_heart_visuals():
	for i in range(hearts_list.size()):
		var heart_node = hearts_list[i]
		
		# Example: if i is 4 (5th heart) and health is 4.5
		# i < 4.5 is true for 0,1,2,3,4. 
		# But we need to check the 'remainder' for the half heart.
		
		if health >= i + 1:
			heart_node.texture = heart_full
		elif health >= i + 0.5:
			heart_node.texture = heart_half
		else:
			heart_node.texture = heart_empty
