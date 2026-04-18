extends CharacterBody2D

const SPEED: float = 50.0

enum BossState {
	IDLE,
	ATTACK_RADIAL,
	ATTACK_CHARGE,
	ATTACK_CONE
}

@export var max_hp: float = 10.0
@export var hurt_tint_color: Color = Color(1.0, 0.35, 0.35, 1.0)
@export var hurt_tint_duration: float = 0.12

@export var idle_duration: float = 1.0
@export var idle_move_speed: float = 35.0

@export var projectile_scene: PackedScene = preload("res://Scenes/projectile.tscn")
@export var projectile_speed: float = 180.0
@export var radial_projectile_count: int = 10
@export var radial_damage: float = 1.0
@export var radial_windup: float = 0.5
@export var radial_recover: float = 0.5

@export var charge_damage: float = 2.0
@export var charge_speed: float = 360.0
@export var charge_windup: float = 0.45
@export var charge_duration: float = 0.5
@export var charge_knockback: float = 280.0
@export var contact_damage: float = 1.0
@export var phase_two_threshold: float = 3.0
@export var phase_two_bomb_damage: float = 1.0

@export var cone_damage: float = 2.0
@export var cone_range: float = 180.0
@export var cone_angle_deg: float = 70.0
@export var cone_windup: float = 0.35
@export var cone_recover: float = 0.45

var hp: float = 100.0
var is_phase_two: bool = false
var is_phase_transitioning: bool = false
var state: BossState = BossState.IDLE
var state_time_left: float = 0.0
var last_attack_state: BossState = BossState.IDLE
var facing_dir: Vector2 = Vector2.RIGHT
var charge_dir: Vector2 = Vector2.RIGHT
var is_charging: bool = false
var radial_fired: bool = false
var cone_fired: bool = false
var charge_cone_fired: bool = false
var hurt_tint_token: int = 0
var base_sprite_modulate: Color = Color(1, 1, 1, 1)

@onready var hitbox: Area2D = $Hitbox
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	sprite.animation_finished.connect(_on_animation_finished)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	hp = max_hp
	base_sprite_modulate = sprite.modulate
	enter_idle()
	sprite.sprite_frames.set_animation_speed("idle", 10)
	sprite.play("idle")

	if not SignalBus.is_connected("boss_activate_phase_two", activate_phase_two):
		SignalBus.connect("boss_activate_phase_two", activate_phase_two)

	SignalBus.emit_signal("boss_hp_init", self, hp, get_current_phase_max_hp(), is_phase_two)
	SignalBus.emit_signal("boss_hp_changed", hp, get_current_phase_max_hp(), is_phase_two)

func _physics_process(delta: float) -> void:
	if is_phase_transitioning:
		velocity = Vector2.ZERO
		return

	var target = find_closest_player()
	if target:
		var to_target = global_position.direction_to(target.global_position)
		if to_target != Vector2.ZERO:
			facing_dir = to_target

	state_time_left -= delta

	match state:
		BossState.IDLE:
			handle_idle(delta, target)
		BossState.ATTACK_RADIAL:
			handle_radial_attack()
		BossState.ATTACK_CHARGE:
			handle_charge_attack()
		BossState.ATTACK_CONE:
			handle_cone_attack()

	move_and_slide()


func handle_idle(_delta: float, target: CharacterBody2D) -> void:
	if target:
		velocity = global_position.direction_to(target.global_position) * idle_move_speed
	else:
		velocity = Vector2.ZERO

	if state_time_left <= 0.0:
		pick_random_attack(target)

func handle_radial_attack() -> void:
	velocity = Vector2.ZERO

	if not radial_fired and state_time_left <= radial_recover:
		radial_fired = true
		fire_radial_burst()

	# if state_time_left <= 0.0:
	# 	enter_idle()

func handle_charge_attack() -> void:
	if state_time_left > charge_duration:
		is_charging = false
		velocity = Vector2.ZERO
		charge_cone_fired = false
	elif not charge_cone_fired:
		is_charging = true
		velocity = charge_dir * charge_speed
	else:
		is_charging = false
		velocity = Vector2.ZERO

	if state_time_left <= 0.0 and not charge_cone_fired:
		is_charging = false
		velocity = Vector2.ZERO
		facing_dir = charge_dir
		do_cone_attack()
		charge_cone_fired = true
		state_time_left = cone_recover
	elif state_time_left <= 0.0 and charge_cone_fired:
		enter_idle()
	#	enter_idle()

func handle_cone_attack() -> void:
	velocity = Vector2.ZERO

	if not cone_fired and state_time_left <= cone_recover:
		cone_fired = true
		do_cone_attack()

	# if state_time_left <= 0.0:
	#	enter_idle()

func pick_random_attack(target: CharacterBody2D) -> void:
	var candidates = [
		BossState.ATTACK_RADIAL,
		BossState.ATTACK_CHARGE
	]

	if candidates.size() > 1 and candidates.has(last_attack_state):
		candidates.erase(last_attack_state)

	var next_attack = candidates[randi() % candidates.size()]
	last_attack_state = next_attack
	state = next_attack

	match state:
		BossState.ATTACK_RADIAL:
			radial_fired = false
			state_time_left = radial_windup + radial_recover
			sprite.play("death")
		BossState.ATTACK_CHARGE:
			is_charging = false
			sprite.play("charge")
			charge_cone_fired = false
			state_time_left = charge_windup + charge_duration
			if target:
				charge_dir = global_position.direction_to(target.global_position)
			elif facing_dir != Vector2.ZERO:
				charge_dir = facing_dir
			else:
				charge_dir = Vector2.RIGHT
		BossState.ATTACK_CONE:
			cone_fired = false
			state_time_left = cone_windup + cone_recover
			sprite.play("attack")

func enter_idle() -> void:
	state = BossState.IDLE
	state_time_left = idle_duration
	is_charging = false
	velocity = Vector2.ZERO
	sprite.stop()
	sprite.play("idle")

func fire_radial_burst() -> void:
	if projectile_scene == null:
		return

	var count = maxi(1, radial_projectile_count)
	for i in count:
		var dir = Vector2.RIGHT.rotated((TAU * float(i)) / float(count))
		spawn_projectile(dir, radial_damage)


func spawn_projectile(dir: Vector2, dmg: float) -> void:
	var projectile = projectile_scene.instantiate()
	projectile.global_position = global_position + (dir * 32.0)
	projectile.direction = dir
	projectile.speed = projectile_speed
	projectile.damage = dmg
	projectile.lifetime = 99.0
	projectile.owner_group = "Enemies"
	projectile.target_group = "Players"
	get_tree().current_scene.add_child(projectile)


func do_cone_attack() -> void:
	var players = get_tree().get_nodes_in_group("Players")
	var min_dot = cos(deg_to_rad(cone_angle_deg * 0.5))

	for p in players:
		if not (p is Node2D):
			continue

		var to_player = (p as Node2D).global_position - global_position
		if to_player.length() > cone_range or to_player.length() == 0.0:
			continue

		var dir_to_player = to_player.normalized()
		if facing_dir.dot(dir_to_player) < min_dot:
			continue

		if p.has_method("receive_hit"):
			p.receive_hit(cone_damage)


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


func play_hurt_tint() -> void:
	hurt_tint_token += 1
	var token := hurt_tint_token
	sprite.modulate = hurt_tint_color
	await get_tree().create_timer(hurt_tint_duration).timeout
	if token == hurt_tint_token and is_instance_valid(sprite):
		sprite.modulate = base_sprite_modulate


func take_damage(amount: float) -> void:
	if is_phase_two or is_phase_transitioning:
		return

	hp = clamp(hp - amount, 0.0, max_hp)
	SignalBus.emit_signal("boss_hp_changed", hp, get_current_phase_max_hp(), is_phase_two)
	if hp <= 0.0:
		hp = 0.0
		is_phase_transitioning = true
		SignalBus.emit_signal("boss_phase_two_transition_started")
		return

	play_hurt_tint()


func take_bomb_damage(amount: float = 1.0) -> void:
	if is_phase_transitioning:
		return

	var phase_max_hp = get_current_phase_max_hp()
	hp = clamp(hp - amount, 0.0, phase_max_hp)
	SignalBus.emit_signal("boss_hp_changed", hp, phase_max_hp, is_phase_two)
	if hp <= 0.0:
		if is_phase_two:
			SignalBus.emit_signal("boss_defeated")
			queue_free()
			return

		hp = 0.0
		is_phase_transitioning = true
		SignalBus.emit_signal("boss_phase_two_transition_started")
		return

	play_hurt_tint()


func activate_phase_two() -> void:
	if is_phase_two:
		return

	is_phase_two = true
	is_phase_transitioning = false
	hp = phase_two_threshold
	SignalBus.emit_signal("boss_phase_two_activated", phase_two_threshold)
	SignalBus.emit_signal("boss_hp_changed", hp, get_current_phase_max_hp(), is_phase_two)


func get_current_phase_max_hp() -> float:
	return phase_two_threshold if is_phase_two else max_hp


func _on_hitbox_body_entered(_body: Node) -> void:
	# Collision with boss body no longer deals damage.
	# Damage is now applied by explicit attack patterns only.
	return

func _on_animation_finished() -> void:
	match state:
		BossState.ATTACK_RADIAL, BossState.ATTACK_CONE:
			enter_idle()
		BossState.ATTACK_CHARGE:
			if not is_charging:
				enter_idle()
