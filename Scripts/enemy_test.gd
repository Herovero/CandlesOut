extends CharacterBody2D

const SPEED: float = 100.0
const SEPARATION_RADIUS: float = 40.0
const SEPARATION_FORCE: float = 200.0

@export var damage_amount: float = 1.0
@export var max_hp: float = 2
@export var melee_attack_buffer: float = 1.2
@export var max_hp: float = 5.0

var hp: float = 5.0
var knockback_velocity: Vector2 = Vector2.ZERO

@onready var attack_timer: Timer = $AttackTimer


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	hp = max_hp
	attack_timer.wait_time = melee_attack_buffer


func _physics_process(delta: float) -> void:
	var target = find_closest_player()
	var direction = Vector2.ZERO

	if target:
		direction = global_position.direction_to(target.global_position)

	var separation = compute_separation()

	var move_velocity = (direction * SPEED) + separation
	velocity = move_velocity + knockback_velocity
	knockback_velocity *= 0.85

	move_and_slide()


func find_closest_player() -> CharacterBody2D:
	var players = get_tree().get_nodes_in_group("Players")
	var closest = null
	var best_dist = INF

	for p in players:
		var d = global_position.distance_to(p.global_position)
		if d < best_dist:
			best_dist = d
			closest = p

	return closest


func compute_separation() -> Vector2:
	var enemies = get_tree().get_nodes_in_group("Enemies")
	var push = Vector2.ZERO
	var count = 0

	for e in enemies:
		if e == self:
			continue

		var dist = global_position.distance_to(e.global_position)

		if dist < SEPARATION_RADIUS and dist > 0:
			var away = (global_position - e.global_position).normalized()
			push += away * (SEPARATION_RADIUS - dist)
			count += 1

	if count > 0:
		push = push / count
		push = push.normalized() * SEPARATION_FORCE

	return push

func take_damage(amount: float) -> void:
	hp = clamp(hp - amount, 0.0, max_hp)
	if hp <= 0.0:
		queue_free()


func _on_hitbox_body_entered(body):
	if not attack_timer.is_stopped():
		return

	if body.is_in_group("Players"):
		SignalBus.emit_signal("take_damage", damage_amount, body.input_prefix)
		attack_timer.start()

		var dir = (body.global_position - global_position).normalized()
		if body.has_method("apply_knockback"):
			body.apply_knockback(dir * 150)
