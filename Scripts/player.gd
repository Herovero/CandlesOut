extends CharacterBody2D

@export var input_prefix: String = "p1_"
@export var speed: float = 150.0

@export var projectile_scene: PackedScene = preload("res://Scenes/projectile.tscn")
@export var shoot_interval: float = 0.5
@export var projectile_speed: float = 200.0
@export var projectile_damage: float = 1.0
@export var muzzle_offset: float = 24.0
@export var autoaim_enabled: bool = true
@export var autoaim_range: float = 300.0
@export var hit_stun_duration: float = 0.32
@export var invincibility_duration: float = 0.32
@export var flash_interval: float = 0.06

@export var max_stamina: float = 100.0
var current_stamina: float = 100.0
@export var depletion_rate: float = 50.0
@export var recharge_rate: float = 10.0
#@export var depletion_rate: float = 10.0
#@export var recharge_rate: float = 5.0

var is_sleeping: bool = false
var ghost_scene = preload("res://Scenes/player_ghost.tscn")
var active_ghost: CharacterBody2D = null

var knockback_velocity: Vector2 = Vector2.ZERO
var shoot_cooldown: float = 0.0
var last_move_dir: Vector2 = Vector2.RIGHT
var is_hit_stunned: bool = false
var is_invincible: bool = false
var flash_tint_on: bool = false

@onready var stamina_bar = $Stats/StaminaBar
@onready var sprite: Sprite2D = $Sprite2D
@onready var hit_stun_timer: Timer = $HitStunTimer
@onready var invincibility_timer: Timer = $InvincibilityTimer
@onready var flash_timer: Timer = $FlashTimer


func _ready():
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	stamina_bar.max_value = max_stamina
	stamina_bar.value = max_stamina
	hit_stun_timer.wait_time = hit_stun_duration
	invincibility_timer.wait_time = invincibility_duration
	flash_timer.wait_time = flash_interval


func _physics_process(delta: float) -> void:
	update_ui()
	
	if is_sleeping:
		handle_sleep(delta)
		return

	var direction = Vector2.ZERO
	if not is_hit_stunned:
		direction = Input.get_vector(
			input_prefix + "move_left",
			input_prefix + "move_right",
			input_prefix + "move_up",
			input_prefix + "move_down"
		)

	var move_velocity = direction * speed
	velocity = move_velocity + knockback_velocity
	knockback_velocity *= 0.91
	if knockback_velocity.length() < 15.0:
		knockback_velocity = Vector2.ZERO

	shoot_cooldown -= delta
	if not is_hit_stunned and direction != Vector2.ZERO:
		last_move_dir = direction
		consume_stamina(delta)
	else:
		velocity = knockback_velocity

	if not is_hit_stunned and shoot_cooldown <= 0.0:
		var target_in_radius = find_autoaim_target()
		if target_in_radius:
			shoot_projectile(target_in_radius)
			shoot_cooldown = shoot_interval

	move_and_slide()


func consume_stamina(delta):
	current_stamina -= depletion_rate * delta
	if current_stamina <= 0:
		enter_sleep()


func enter_sleep():
	is_sleeping = true
	velocity = Vector2.ZERO
	modulate = Color(0.5, 0.5, 1.0) # Turn slightly blue/dark to show sleeping
	
	active_ghost = ghost_scene.instantiate()
	active_ghost.input_prefix = input_prefix # Give the ghost your controls
	active_ghost.global_position = global_position # Start at player's body
	get_parent().add_child(active_ghost)
	
	SignalBus.emit_signal("ghost_mode_started")
	
func handle_sleep(delta):
	current_stamina += recharge_rate * delta
	
	current_stamina = min(current_stamina, max_stamina)
	
	if current_stamina >= max_stamina:
		wake_up()

func wake_up():
	is_sleeping = false
	modulate = Color(1, 1, 1)
	if active_ghost:
		active_ghost.queue_free() # Remove the ghost when waking up
	
	SignalBus.emit_signal("ghost_mode_ended")

func update_ui():
	stamina_bar.value = current_stamina

func is_damage_blocked() -> bool:
	return is_invincible


func start_invincibility_flash() -> void:
	is_invincible = true
	flash_tint_on = true
	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	invincibility_timer.start()
	flash_timer.start()


func start_hit_stun() -> void:
	is_hit_stunned = true
	hit_stun_timer.start()


func receive_hit(damage_amount: float, knockback_force: Vector2 = Vector2.ZERO, apply_stun: bool = false) -> void:
	if is_damage_blocked():
		return

	SignalBus.emit_signal("take_damage", damage_amount, input_prefix)
	start_invincibility_flash()

	if knockback_force != Vector2.ZERO:
		knockback_velocity = knockback_force

	if apply_stun:
		start_hit_stun()


func apply_knockback(force: Vector2):
	knockback_velocity = force
	start_invincibility_flash()
	start_hit_stun()


func find_autoaim_target() -> Node2D:
	if not autoaim_enabled:
		return null

	var enemies = get_tree().get_nodes_in_group("Enemies")
	var best_target: Node2D = null
	var best_dist := INF
	var max_dist_sq := autoaim_range * autoaim_range

	for e in enemies:
		if not (e is Node2D):
			continue

		var to_enemy = (e as Node2D).global_position - global_position
		var dist_sq = to_enemy.length_squared()
		if dist_sq > max_dist_sq or dist_sq == 0.0:
			continue

		if dist_sq < best_dist:
			best_dist = dist_sq
			best_target = e as Node2D

	return best_target


func shoot_projectile(target: Node2D = null) -> void:
	if projectile_scene == null:
		return

	var shot_dir = last_move_dir
	if target:
		shot_dir = global_position.direction_to(target.global_position)

	var projectile = projectile_scene.instantiate()
	projectile.global_position = global_position + (shot_dir * muzzle_offset)
	projectile.direction = shot_dir
	projectile.speed = projectile_speed
	projectile.damage = projectile_damage
	projectile.owner_group = "Players"
	projectile.target_group = "Enemies"
	get_tree().current_scene.add_child(projectile)


func _on_flash_timer_timeout() -> void:
	flash_tint_on = not flash_tint_on
	if flash_tint_on:
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		sprite.modulate = Color(0.75, 0.75, 0.75, 1.0)


func _on_hit_stun_timer_timeout() -> void:
	is_hit_stunned = false


func _on_invincibility_timer_timeout() -> void:
	is_invincible = false
	flash_timer.stop()
	flash_tint_on = false
	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
