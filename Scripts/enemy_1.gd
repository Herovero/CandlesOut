extends CharacterBody2D

const SPEED = 300.0
const HP = 100.0

func _physics_process(delta: float) -> void:
	var direction = Vector2.ZERO
	
	var player = get_node_or_null("/root/main/Player1")
	if player:
		direction = (player.global_position - global_position).normalized()

	velocity = direction * SPEED
	move_and_slide()
