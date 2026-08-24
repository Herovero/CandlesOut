@abstract
extends CharacterBody2D

const ENEMY_STATS_DATABASE: EnemyStatsDatabase = preload("res://Data/enemy_stats.tres")

var enemy_stats: Dictionary = {}
var speed: float = 0.0
var separation_radius: float = 0.0
var separation_force: float = 0.0
var max_hp: float = 1.0
var hp: float = 1.0
var knockback_velocity: Vector2 = Vector2.ZERO
var hurt_tint_color: Color = Color(1.0, 0.35, 0.35, 1.0)
var hurt_tint_duration: float = 0.12
var hurt_tint_token: int = 0
var base_sprite_modulate: Color = Color(1, 1, 1, 1)
var is_dying: bool = false
var network_generation: int = 0
var network_position: Vector2 = Vector2.ZERO
var network_velocity: Vector2 = Vector2.ZERO
var remote_footstep_timer: float = 0.0

@onready var hitbox: Area2D = get_node_or_null("Hitbox")
@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var death_sound: AudioStreamPlayer2D = get_node_or_null("EnemyDies")
@onready var footstep_enemy: AudioStreamPlayer2D = get_node_or_null("EnemyFootStep")


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	enemy_stats = ENEMY_STATS_DATABASE.get_stats(get_enemy_id())
	apply_base_stats(enemy_stats)
	apply_stats(enemy_stats)
	hp = max_hp
	if sprite:
		base_sprite_modulate = sprite.modulate
	network_generation = NetworkSession.match_generation
	network_position = position
	network_velocity = velocity
	NetworkSession.configure_moving_synchronizer(self, [&"hp", &"is_dying"])
	if not NetworkSession.has_simulation_authority() and hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)


func _process(delta: float) -> void:
	if NetworkSession.has_simulation_authority():
		return
	NetworkSession.interpolate_movement(self, delta)
	if sprite and network_velocity.x != 0.0:
		sprite.flip_h = network_velocity.x < 0.0
	if has_method("_present_remote_state"):
		call("_present_remote_state")
	if is_dying and sprite and sprite.animation != &"death":
		sprite.play(&"death")
	_update_remote_footsteps(delta)


func _update_remote_footsteps(delta: float) -> void:
	if footstep_enemy == null or not has_method("play_footstep"):
		return
	if network_velocity.length_squared() <= 1.0 or is_dying:
		remote_footstep_timer = 0.0
		return
	remote_footstep_timer -= delta
	if remote_footstep_timer <= 0.0:
		call("play_footstep")
		var interval_value: Variant = get("footstep_interval")
		remote_footstep_timer = float(interval_value) if interval_value != null else 0.5


@abstract func get_enemy_id() -> String


@abstract func apply_stats(stats: Dictionary) -> void


func apply_base_stats(stats: Dictionary) -> void:
	speed = float(stats.get("speed", speed))
	separation_radius = float(stats.get("separation_radius", separation_radius))
	separation_force = float(stats.get("separation_force", separation_force))
	max_hp = float(stats.get("max_hp", max_hp))
	hurt_tint_color = stats.get("hurt_tint_color", hurt_tint_color)
	hurt_tint_duration = float(stats.get("hurt_tint_duration", hurt_tint_duration))


func find_closest_player() -> CharacterBody2D:
	var players = get_tree().get_nodes_in_group("Players")
	var closest = null
	var best_dist = INF

	for p in players:
		if p.get("is_sleeping") == true:
			continue

		var d = global_position.distance_to(p.global_position)
		if d < best_dist:
			best_dist = d
			closest = p

	return closest


func compute_separation() -> Vector2:
	if separation_radius <= 0.0 or separation_force <= 0.0:
		return Vector2.ZERO

	var enemies = get_tree().get_nodes_in_group("Enemies")
	var push = Vector2.ZERO
	var count = 0

	for e in enemies:
		if e == self:
			continue

		var dist = global_position.distance_to(e.global_position)

		if dist < separation_radius and dist > 0:
			var away = (global_position - e.global_position).normalized()
			push += away * (separation_radius - dist)
			count += 1

	if count > 0:
		push = push / count
		push = push.normalized() * separation_force

	return push


func play_hurt_tint() -> void:
	if sprite == null:
		return

	hurt_tint_token += 1
	var token := hurt_tint_token
	sprite.modulate = hurt_tint_color
	await get_tree().create_timer(hurt_tint_duration).timeout
	if token == hurt_tint_token and is_instance_valid(sprite):
		sprite.modulate = base_sprite_modulate


func take_damage(amount: float) -> void:
	if not NetworkSession.has_simulation_authority() or is_dying:
		return
	hp = clamp(hp - amount, 0.0, max_hp)
	if hp <= 0.0:
		await die()
		return

	play_hurt_tint()


func die() -> void:
	if not NetworkSession.has_simulation_authority():
		return
	is_dying = true
	velocity = Vector2.ZERO
	NetworkSession.publish_movement(self, velocity)
	if sprite:
		sprite.play("death")
	print(self, " is dying")
	NetworkSession.broadcast_sfx(GameplayAudio.Cue.ENEMY_DEATH, global_position)
	if death_sound and death_sound.stream:
		await get_tree().create_timer(death_sound.stream.get_length()).timeout
	queue_free()
