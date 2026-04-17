extends CharacterBody2D

const SPEED: float = 100.0
const SEPARATION_RADIUS: float = 40.0
const SEPARATION_FORCE: float = 200.0

@export var damage_amount: float = 1.0
@export var projectile_scene: PackedScene = preload("res://Scenes/projectile.tscn")
@export var shoot_interval: float = 1.0
@export var projectile_speed: float = 250.0
@export var projectile_damage: float = 1.0
@export var muzzle_offset: float = 24.0
@export var max_hp: float = 5.0

var hp: float = 5.0
var knockback_velocity: Vector2 = Vector2.ZERO
var shoot_cooldown: float = 0.0
var last_move_dir: Vector2 = Vector2.RIGHT


func _ready() -> void:
	hp = max_hp


func _physics_process(delta: float) -> void:
	var target = find_closest_player()
	var direction = Vector2.ZERO

	if target:
		direction = global_position.direction_to(target.global_position)

	if direction != Vector2.ZERO:
		last_move_dir = direction

	var separation = compute_separation()

	var move_velocity = (direction * SPEED) + separation
	velocity = move_velocity + knockback_velocity
	knockback_velocity *= 0.85

	shoot_cooldown -= delta
	if target and shoot_cooldown <= 0.0:
		shoot_projectile()
		shoot_cooldown = shoot_interval

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

func shoot_projectile() -> void:
	if projectile_scene == null:
		return

	var projectile = projectile_scene.instantiate()
	projectile.global_position = global_position + (last_move_dir * muzzle_offset)
	projectile.direction = last_move_dir
	projectile.speed = projectile_speed
	projectile.damage = projectile_damage
	projectile.owner_group = "Enemies"
	projectile.target_group = "Players"
	get_tree().current_scene.add_child(projectile)


func take_damage(amount: float) -> void:
	hp = clamp(hp - amount, 0.0, max_hp)
	if hp <= 0.0:
		queue_free()


func _on_hitbox_body_entered(body):
	if body.is_in_group("Players"):
		SignalBus.emit_signal("take_damage", 1.0, body.input_prefix)
		#body.take_damage(damage_amount)

		var dir = (body.global_position - global_position).normalized()
		if body.has_method("apply_knockback"):
			body.apply_knockback(dir * 150)
