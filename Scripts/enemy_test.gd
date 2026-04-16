extends CharacterBody2D

const SPEED: float = 100.0
@export var damage_amount: float = 1.0

var hp: float = 100.0
var knockback_velocity: Vector2 = Vector2.ZERO

func _physics_process(delta: float) -> void:
	var target = find_closest_player()
	var direction = Vector2.ZERO

	if target:
		direction = global_position.direction_to(target.global_position)

	var move_velocity = direction * SPEED
	velocity = move_velocity + knockback_velocity
	knockback_velocity *= 0.85

	move_and_slide()


func find_closest_player() -> CharacterBody2D:
	var players = get_tree().get_nodes_in_group("Players")
	var closest = null
	var best_dist = INF

	for p in players:
		if p.is_sleeping:
			continue

		var d = global_position.distance_to(p.global_position)
		if d < best_dist:
			best_dist = d
			closest = p

	return closest

func _on_hitbox_body_entered(body):
	if body.is_in_group("Players"):
		SignalBus.emit_signal("take_damage", 1.0, body.input_prefix)
		#body.take_damage(damage_amount)

		var dir = (body.global_position - global_position).normalized()
		if body.has_method("apply_knockback"):
			body.apply_knockback(dir * 150)
