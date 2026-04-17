extends "res://Scripts/enemy_test.gd"

@export var ranged_max_hp: float = 3.0
@export var projectile_scene: PackedScene = preload("res://Scenes/projectile.tscn")
@export var shoot_interval: float = 1.6
@export var projectile_speed: float = 200.0
@export var projectile_damage: float = 1.0
@export var muzzle_offset: float = 24.0
@export var preferred_distance: float = 220.0
@export var distance_tolerance: float = 32.0
@export var shoot_range: float = 320.0

var shoot_cooldown: float = 0.0
var last_move_dir: Vector2 = Vector2.RIGHT


func _ready() -> void:
	super()
	max_hp = ranged_max_hp
	hp = max_hp


func _physics_process(delta: float) -> void:
	var target = find_closest_player()
	var direction = Vector2.ZERO
	var target_distance: float = INF

	if target:
		var to_target = global_position.direction_to(target.global_position)
		target_distance = global_position.distance_to(target.global_position)

		if target_distance > preferred_distance + distance_tolerance:
			direction = to_target

	if direction != Vector2.ZERO:
		last_move_dir = direction
	elif target:
		last_move_dir = global_position.direction_to(target.global_position)

	var separation = compute_separation()
	var move_velocity = (direction * SPEED) + separation
	velocity = move_velocity + knockback_velocity
	knockback_velocity *= 0.85

	shoot_cooldown -= delta
	if target and target_distance <= shoot_range and shoot_cooldown <= 0.0:
		shoot_projectile()
		shoot_cooldown = shoot_interval

	move_and_slide()


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


func _on_hitbox_body_entered(_body):
	return
