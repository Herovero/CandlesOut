extends CharacterBody2D

const SPEED: float = 200.0
const SEPARATION_RADIUS: float = 40.0
const SEPARATION_FORCE: float = 200.0

@export var damage_amount: float = 1.0
@export var max_hp: float = 3
@export var melee_attack_buffer: float = 1.2
@export var post_hit_pause_duration: float = 0.25
@export var hurt_tint_color: Color = Color(1.0, 0.35, 0.35, 1.0)
@export var hurt_tint_duration: float = 0.12

var hp: float = 5.0
var knockback_velocity: Vector2 = Vector2.ZERO
var current_melee_target: Node2D = null
var post_hit_pause_left: float = 0.0
var hurt_tint_token: int = 0
var base_sprite_modulate: Color = Color(1, 1, 1, 1)

@onready var attack_timer: Timer = $AttackTimer
@onready var hitbox: Area2D = $Hitbox
@onready var sprite: Sprite2D = $Sprite2D

@onready var death_sound = $EnemyDies
var is_dying: bool = false
@onready var footstep_enemy = $EnemyFootStep
@export var footstep_interval: float = 0.5
var footstep_timer: float = 0.0

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	hp = max_hp
	attack_timer.wait_time = melee_attack_buffer
	base_sprite_modulate = sprite.modulate


func _physics_process(delta: float) -> void:
	if is_dying:
		return
		
	var target = find_closest_player()
	var direction = Vector2.ZERO

	post_hit_pause_left = max(post_hit_pause_left - delta, 0.0)
	if target and post_hit_pause_left <= 0.0:
		direction = global_position.direction_to(target.global_position)

	var separation = compute_separation()

	var move_velocity = (direction * SPEED) + separation
	velocity = move_velocity + knockback_velocity
	knockback_velocity *= 0.85

	move_and_slide()
	handle_footsteps(delta,direction)


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

func play_hurt_tint() -> void:
	hurt_tint_token += 1
	var token := hurt_tint_token
	sprite.modulate = hurt_tint_color
	await get_tree().create_timer(hurt_tint_duration).timeout
	if token == hurt_tint_token and is_instance_valid(sprite):
		sprite.modulate = base_sprite_modulate


func take_damage(amount: float) -> void:
	if is_dying:
		return
	hp = clamp(hp - amount, 0.0, max_hp)
	if hp <= 0.0:
		is_dying = true
		print(self, " is dying")
		death_sound.volume_db = -10.0 
		death_sound.play()
		await death_sound.finished
		queue_free()
		return

	play_hurt_tint()


func deal_melee_hit(body) -> void:
	var dir = (body.global_position - global_position).normalized()
	if body.has_method("receive_hit"):
		body.receive_hit(damage_amount, dir * 240, true)
		post_hit_pause_left = post_hit_pause_duration
		return

	if body.has_method("is_damage_blocked") and body.is_damage_blocked():
		return

	SignalBus.emit_signal("take_damage", damage_amount, body.input_prefix)
	post_hit_pause_left = post_hit_pause_duration


func _on_hitbox_body_entered(body):
	if not body.is_in_group("Players") or not (body is Node2D):
		return

	current_melee_target = body as Node2D

	if attack_timer.is_stopped():
		deal_melee_hit(body)
		attack_timer.start()


func _on_hitbox_body_exited(body):
	if body == current_melee_target:
		current_melee_target = null


func _on_attack_timer_timeout() -> void:
	if current_melee_target == null or not is_instance_valid(current_melee_target):
		current_melee_target = null
		return

	if not hitbox.overlaps_body(current_melee_target):
		current_melee_target = null
		return

	deal_melee_hit(current_melee_target)
	attack_timer.start()
	
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
		footstep_timer = 0.0
		return
	
	footstep_timer -= delta
	if footstep_timer <= 0.0:
		play_footstep()
		footstep_timer = footstep_interval
