extends "res://Scripts/Enemy/enemy_base.gd"

var damage_amount: float = 1.0
var melee_attack_buffer: float = 1.2
var attack_trigger_range: float = 78.0
var attack_hit_delay: float = 0.14
var attack_cone_range: float = 92.0
var attack_cone_angle_deg: float = 85.0
var post_hit_pause_duration: float = 1.0

var post_hit_pause_left: float = 0.0

var attack_in_progress: bool = false
var attack_damage_applied: bool = false
var attack_elapsed: float = 0.0
var attack_dir: Vector2 = Vector2.RIGHT

@onready var attack_timer: Timer = $AttackTimer
@onready var slash_sfx: AudioStreamPlayer2D = get_node_or_null("Slash")
var footstep_interval: float = 0.5
var footstep_timer: float = 0.0
var attacking_animation: bool = false


func get_enemy_id() -> String:
	return "melee"


func apply_stats(stats: Dictionary) -> void:
	damage_amount = float(stats.get("damage_amount", damage_amount))
	melee_attack_buffer = float(stats.get("melee_attack_buffer", melee_attack_buffer))
	attack_trigger_range = float(stats.get("attack_trigger_range", attack_trigger_range))
	attack_hit_delay = float(stats.get("attack_hit_delay", attack_hit_delay))
	attack_cone_range = float(stats.get("attack_cone_range", attack_cone_range))
	attack_cone_angle_deg = float(stats.get("attack_cone_angle_deg", attack_cone_angle_deg))
	post_hit_pause_duration = float(stats.get("post_hit_pause_duration", post_hit_pause_duration))
	footstep_interval = float(stats.get("footstep_interval", footstep_interval))


func _ready() -> void:
	super()
	attack_timer.wait_time = melee_attack_buffer
	sprite.sprite_frames.set_animation_speed("idle", 10)
	sprite.sprite_frames.set_animation_speed("move", 10)
	sprite.sprite_frames.set_animation_speed("attack", 10)
	sprite.sprite_frames.set_animation_speed("death", 17)
	sprite.play("idle")


func _physics_process(delta: float) -> void:
	if not NetworkSession.has_simulation_authority():
		return
	if is_dying:
		return

	var target = find_closest_player()
	var direction = Vector2.ZERO
	var target_dist := INF
	var to_target := Vector2.ZERO

	if target:
		to_target = global_position.direction_to(target.global_position)
		target_dist = global_position.distance_to(target.global_position)
		if to_target != Vector2.ZERO:
			attack_dir = to_target

	post_hit_pause_left = max(post_hit_pause_left - delta, 0.0)

	if attack_in_progress:
		attack_elapsed += delta
		if not attack_damage_applied and sprite.animation == "attack" and sprite.frame == 4:
			attack_damage_applied = true
			perform_cone_attack()
			post_hit_pause_left = post_hit_pause_duration
			attack_in_progress = false
	elif target and attack_timer.is_stopped() and post_hit_pause_left <= 0.0 and target_dist <= attack_trigger_range:
		start_attack()
	elif target and post_hit_pause_left <= 0.0:
		direction = to_target

	var separation = compute_separation()
	var move_velocity = (direction * speed) + separation
	velocity = move_velocity + knockback_velocity
	if velocity.x != 0:
		sprite.flip_h = velocity.x < 0

	knockback_velocity *= 0.85

	move_and_slide()
	handle_footsteps(delta, direction)


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

		if dist < separation_radius and dist > 0:
			var away = (global_position - e.global_position).normalized()
			push += away * (separation_radius - dist)
			count += 1

	if count > 0:
		push = push / count
		push = push.normalized() * separation_force

	return push

func play_hurt_tint() -> void:
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
		is_dying = true
		sprite.play("death")
		print(self, " is dying")
		death_sound.volume_db = -10.0
		death_sound.play()
		await death_sound.finished
		queue_free()
		return

	play_hurt_tint()


func start_attack() -> void:
	attack_in_progress = true
	attack_damage_applied = false
	attacking_animation = true

	sprite.play("attack")
	attack_timer.start()

	if slash_sfx:
		play_slash_sfx()


func perform_cone_attack() -> void:
	var players = get_tree().get_nodes_in_group("Players")
	var min_dot = cos(deg_to_rad(attack_cone_angle_deg * 0.5))

	for p in players:
		if not (p is Node2D):
			continue

		var to_player = (p as Node2D).global_position - global_position
		if to_player.length() == 0.0 or to_player.length() > attack_cone_range:
			continue

		var dir_to_player = to_player.normalized()
		if attack_dir.dot(dir_to_player) < min_dot:
			continue

		if p.has_method("receive_hit"):
			p.receive_hit(damage_amount, dir_to_player * 240, true)
		elif not (p.has_method("is_damage_blocked") and p.is_damage_blocked()):
			p.apply_damage(damage_amount)


func _on_hitbox_body_entered(_body):
	return


func _on_hitbox_body_exited(_body):
	return


func _on_attack_timer_timeout() -> void:
	return

func play_footstep():
	if Global.active_footstep_count >= Global.MAX_ENEMY_FOOTSTEPS:
		return
	Global.active_footstep_count += 1
	footstep_enemy.pitch_scale = randf_range(0.85, 1.15)
	footstep_enemy.volume_db = randf_range(-6.0, 0.0)
	footstep_enemy.play()
	await footstep_enemy.finished
	Global.active_footstep_count -= 1

func handle_footsteps(delta, direction):

	if direction == Vector2.ZERO:
		if attacking_animation == false:
			sprite.play("idle")
		footstep_timer = 0.0
		return

	footstep_timer -= delta
	if footstep_timer <= 0.0:
		if attacking_animation == false:
			sprite.play("move")
		play_footstep()
		footstep_timer = footstep_interval

func _on_animation_finished():
	if sprite.animation == "attack":
		attacking_animation = false

func play_slash_sfx():
	await get_tree().create_timer(0.5).timeout
	var sfx = AudioStreamPlayer2D.new()
	sfx.volume_db = -5.0
	sfx.stream = slash_sfx.stream
	sfx.global_position = global_position

	get_tree().current_scene.add_child(sfx)
	sfx.play()

	sfx.finished.connect(sfx.queue_free)
