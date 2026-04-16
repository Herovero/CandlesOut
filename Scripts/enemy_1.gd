extends CharacterBody2D

const SPEED = 100.0
const HP = 100.0

func _physics_process(delta: float) -> void:
	var direction = Vector2.ZERO
	
	var player = get_tree().get_nodes_in_group("Players")
	if player:
		direction = (player.global_position - global_position).normalized()

	velocity = direction * SPEED
	move_and_slide()
