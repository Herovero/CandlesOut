extends "res://Scripts/enemy_test.gd"

@export var ranged_max_hp: float = 3
@export var projectile_scene: PackedScene = preload("res://Scenes/projectile.tscn")
@export var shoot_interval: float = 2.3
@export var projectile_speed: float = 200.0
@export var projectile_damage: float = 0.5
@export var muzzle_offset: float = 24.0
@export var preferred_distance: float = 220.0
@export var distance_tolerance: float = 32.0
@export var shoot_range: float = 320.0
@export var orbit_duration: float = 0.6

var shoot_cooldown: float = 0.0
var orbit_time_left: float = 0.0
var orbit_sign: float = 1.0
var last_move_dir: Vector2 = Vector2.RIGHT

@onready var shoot_sound = $ShootEnemy


func _ready() -> void:
	super()
	max_hp = ranged_max_hp
	hp = max_hp

	# Ranged enemy should not deal melee collision damage.
	hitbox.monitoring = false
	hitbox.monitorable = false
	sprite.sprite_frames.set_animation_speed("idle", 9)
	sprite.sprite_frames.set_animation_speed("run", 9)
	sprite.sprite_frames.set_animation_speed("attack", 9)
	sprite.play("idle")

func _physics_process(delta: float) -> void:
	var target = find_closest_player()
	var direction = Vector2.ZERO
	var target_distance: float = INF
	var aim_dir = last_move_dir

	orbit_time_left = max(orbit_time_left - delta, 0.0)

	if target:
		var to_target = global_position.direction_to(target.global_position)
		target_distance = global_position.distance_to(target.global_position)
		aim_dir = to_target

		if target_distance > preferred_distance + distance_tolerance:
			direction = to_target
		elif orbit_time_left > 0.0:
			var tangent = Vector2(-to_target.y, to_target.x) * orbit_sign
			var radial_correction = to_target * clamp((target_distance - preferred_distance) / preferred_distance, -0.6, 0.6)
			direction = (tangent + radial_correction).normalized()

	if direction != Vector2.ZERO:
		last_move_dir = direction
	elif target:
		last_move_dir = aim_dir

	var separation = compute_separation()
	var move_velocity = (direction * SPEED) + separation
	velocity = move_velocity + knockback_velocity
	if ( velocity.x != 0 || velocity.y != 0):
		sprite.play("run")
	if velocity.x != 0:
		sprite.flip_h = velocity.x < 0
	knockback_velocity *= 0.85

	shoot_cooldown -= delta
	if target and target_distance <= shoot_range and shoot_cooldown <= 0.0:
		shoot_projectile(aim_dir)
		shoot_cooldown = shoot_interval
		orbit_time_left = orbit_duration
		orbit_sign *= -1.0

	move_and_slide()


func shoot_projectile(shoot_dir: Vector2) -> void:
	sprite.play("attack")
	if projectile_scene == null:
		return

	var projectile = projectile_scene.instantiate()
	projectile.global_position = global_position + (shoot_dir * muzzle_offset)
	projectile.direction = shoot_dir
	projectile.speed = projectile_speed
	projectile.damage = projectile_damage
	projectile.owner_group = "Enemies"
	projectile.target_group = "Players"
	get_tree().current_scene.add_child(projectile)
	play_shoot_sound()

func play_footstep():
	if Global.active_footstep_count >= Global.MAX_ENEMY_FOOTSTEPS:
		return
	Global.active_footstep_count += 1
	footstep_enemy.pitch_scale = randf_range(1.1, 1.4)  # higher pitch than base enemy
	footstep_enemy.volume_db = randf_range(-6.0, 0.0)
	footstep_enemy.play()
	await footstep_enemy.finished
	Global.active_footstep_count -= 1

func _on_hitbox_body_entered(_body):
	return
	
func play_shoot_sound():
	if Global.active_shoot_sound_count >= Global.MAX_SHOOT_SOUNDS:
		return
	Global.active_shoot_sound_count += 1
	shoot_sound.pitch_scale = randf_range(0.95, 1.05)
	shoot_sound.play()
	await shoot_sound.finished
	Global.active_shoot_sound_count -= 1
	
