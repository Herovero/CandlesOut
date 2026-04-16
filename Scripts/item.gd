extends Area2D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func on_collected(target_player_id: String):
	print_debug("collected")
	queue_free()

func _on_body_entered(body):
	if body.is_in_group("Ghost"):
		print("hi")
		modulate = Color(2, 2, 2) # Overbrighten to show it's selectable
