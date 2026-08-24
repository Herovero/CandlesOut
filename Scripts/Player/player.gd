extends CharacterBody2D

@export var input_prefix: String = "p1_"
@export_range(1, 2) var player_slot: int = 1
var controlling_peer_id: int = 1
@export var walk_speed: float = 70.0
var is_sprinting: bool = false
var speed: float = 200.0
var sprint_speed:float = 200.0
var base_speed: float = 200.0 # Store reference

@export var projectile_scene: PackedScene = preload("res://Scenes/projectile.tscn")
@export var afterimage_scene: PackedScene = preload("res://Scenes/Player/afterimage.tscn")
@export var shoot_interval: float = 1
@export var projectile_speed: float = 200.0
@export var projectile_damage: float = 1.0
@export var muzzle_offset: float = 24.0
@export var autoaim_enabled: bool = true
@export var autoaim_range: float = 300.0
@export var hit_stun_duration: float = 0.32
@export var invincibility_duration: float = 0.32
@export var flash_interval: float = 0.06
@export var spawn_interval: float = 0.05
@export var glow_base_energy: float = 0.72
@export var glow_flicker_strength: float = 0.10
@export var glow_flicker_speed: float = 4.2
@export var glow_sleep_multiplier: float = 0.42
@onready var static_fx: ColorRect = $CanvasLayer/TvStatic
var static_tween: Tween

const SHOE_ICON = preload("res://Assets/Sprites/item_shoe.png")

const SHOE_EFFECT_LABEL := "Speed Boost"
const SHOE_CHAOS_LABEL := "Hedgehog Shoes?"
const SHIELD_EFFECT_LABEL := "Immune"
const SHIELD_CHAOS_LABEL := "Social Distancing"
const OIL_EFFECT_LABEL := "Triple Shot"
const OIL_CHAOS_LABEL := "Minigun"

@export var max_health: float = 5.0
var health: float = 5.0
@export var max_stamina: float = 100.0
var current_stamina: float = 100.0
@export var depletion_rate: float = 10.0
@export var recharge_rate: float = 5.0
@export var health_regen_rate: float = 0.25 # Amount of heart restored per second
var regen_accumulator: float = 0.0

var is_sleeping: bool = false
var is_returning: bool = false
var active_ghost: CharacterBody2D = null
var is_transitioning_to_ghost: bool = false

var knockback_velocity: Vector2 = Vector2.ZERO
var shoot_cooldown: float = 0.0
var last_move_dir: Vector2 = Vector2.RIGHT
var is_hit_stunned: bool = false
var is_invincible: bool = false
var flash_tint_on: bool = false
var is_triple_shot_active: bool = false
var is_flamethrower_active: bool = false
var is_panicked_fire_active: bool = false
var is_ramming_active: bool = false
var is_shield_active: bool = false
var is_prison_active: bool = false
@onready var shield_visual = $Asset/shield_barrier # Create a blue circle sprite
@onready var prison_visual = $Asset/wall  # Create a square wall sprite

var active_effect_name: String = ""
var active_effect_time_left: float = 0.0
var active_effect_icon: Texture2D = null
var active_effect_token: int = 0
var default_shoot_interval: float = 1.0

@onready var stamina_bar = $Stats/StaminaBar
@onready var sprite: AnimatedSprite2D = $Asset/AnimatedSprite2D
@onready var transition: AnimatedSprite2D = $Asset/GhostTransitionAnimation
@onready var hit_stun_timer: Timer = $Timer/HitStunTimer
@onready var invincibility_timer: Timer = $Timer/InvincibilityTimer
@onready var flash_timer: Timer = $Timer/FlashTimer

@onready var audio = $PlayerAudio
@export var footstep_interval: float = 0.35  # time between footstep sounds
var footstep_timer: float = 0.0
var glow_time: float = 0.0

const INPUT_SEND_INTERVAL := 1.0 / 30.0
const INPUT_STALE_MSEC := 500
var command_direction: Vector2 = Vector2.ZERO
var command_sprinting: bool = false
var remote_direction: Vector2 = Vector2.ZERO
var remote_sprinting: bool = false
var last_remote_input_msec: int = 0
var input_send_accumulator: float = 0.0

@onready var candle_light: Sprite2D = $Asset/CandleLight

func _ready():
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	stamina_bar.max_value = max_stamina
	stamina_bar.value = max_stamina
	sprite.sprite_frames.set_animation_speed("idle", 4)
	sprite.sprite_frames.set_animation_speed("sleeping", 2)
	sprite.sprite_frames.set_animation_speed("walking", 8)
	transition.sprite_frames.set_animation_speed("default", 12)
	sprite.play("idle")
	var mat := static_fx.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("intensity", 0.0)
	static_fx.visible = false

	shield_visual.hide()
	prison_visual.hide()
	default_shoot_interval = shoot_interval

	# item effects signal
	SignalBus.connect("restore_stamina", _on_restore_stamina)
	SignalBus.connect("apply_speed_boost", _on_speed_boost_received)
	SignalBus.connect("swap_player", _on_swap_player)
	SignalBus.connect("apply_triple_shot", _on_triple_shot_received)
	SignalBus.connect("apply_shield_boost", _on_shield_boost_received)

	# item side effects signal
	SignalBus.connect("apply_speed_backfire", _on_speed_backfire_received)
	SignalBus.connect("apply_flamethrower_backfire", _on_flamethrower_received)
	SignalBus.connect("apply_shield_backfire", _on_shield_backfire_received)

	hit_stun_timer.wait_time = hit_stun_duration
	invincibility_timer.wait_time = invincibility_duration
	flash_timer.wait_time = flash_interval

	glow_time = randf_range(0.0, TAU)
	if candle_light:
		candle_light.modulate.a = glow_base_energy

	NetworkSession.configure_synchronizer(self, [
		&"position", &"velocity", &"health", &"current_stamina", &"is_sleeping",
		&"is_returning", &"is_invincible", &"is_hit_stunned", &"active_effect_name",
		&"active_effect_time_left", &"last_move_dir", &"is_triple_shot_active",
		&"is_panicked_fire_active", &"is_ramming_active", &"is_shield_active", &"is_prison_active",
	])
	NetworkSession.local_focus_changed.connect(_on_local_focus_changed)


func _physics_process(delta: float) -> void:
	update_ui()

	if NetworkSession.is_online() and not NetworkSession.has_simulation_authority():
		_process_joining_peer_input(delta)
		_update_remote_presentation()
		return

	update_effect_state(delta)
	var command := _get_authoritative_command()
	apply_command(command, delta)

	if is_prison_active:
		speed = 0.0
	else:
		is_sprinting = command_sprinting and current_stamina > 0.0
		if speed <= sprint_speed:
			speed = sprint_speed if is_sprinting else walk_speed
		
	update_candle_glow(delta)

	if is_sleeping:
		handle_sleep(delta)
		return

	var direction := Vector2.ZERO
	if not is_hit_stunned:
		direction = command_direction
		is_sprinting = command_sprinting and current_stamina > 0.0
	else:
		is_sprinting = false

	var move_velocity = direction * speed
	velocity = move_velocity + knockback_velocity
	knockback_velocity *= 0.91
	if knockback_velocity.length() < 15.0:
		knockback_velocity = Vector2.ZERO

	if speed > base_speed:
		spawn_afterimage()

	shoot_cooldown -= delta
	if not is_hit_stunned and direction != Vector2.ZERO:
		last_move_dir = direction
		if is_sprinting:
			consume_stamina(delta)
			if current_stamina <= 0:
				enter_sleep()
				return
		sprite.play("walking")

	else:
		velocity = knockback_velocity
		sprite.sprite_frames.set_animation_speed("idle", 4)
		sprite.play("idle")

	if not is_hit_stunned and shoot_cooldown <= 0.0:
		var target_in_radius = find_autoaim_target()
		if target_in_radius:
			shoot_projectile(target_in_radius)
			shoot_cooldown = shoot_interval

	move_and_slide()

	if is_ramming_active:
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()

			if collider.is_in_group("Enemies") and collider.has_method("take_damage"):
				collider.take_damage(1.0) # Deal ramming damage
				# Add a tiny bounce back so you don't stick to them
				knockback_velocity = -velocity.normalized() * 150.0

	audio.handle_footsteps(delta, direction)


func sample_local_input(use_online_actions: bool = false) -> Dictionary:
	if not NetworkSession.local_has_focus or NetworkSession.local_input_suppressed:
		return {"direction": Vector2.ZERO, "sprinting": false}
	var prefix := "" if use_online_actions else input_prefix
	return {
		"direction": Input.get_vector(
			prefix + "move_left", prefix + "move_right",
			prefix + "move_up", prefix + "move_down"
		).limit_length(1.0),
		"sprinting": Input.is_action_pressed(prefix + "sprint"),
	}


func apply_command(command: Dictionary, _delta: float) -> void:
	command_direction = (command.get("direction", Vector2.ZERO) as Vector2).limit_length(1.0)
	command_sprinting = bool(command.get("sprinting", false)) and current_stamina > 0.0 and not is_prison_active


func _get_authoritative_command() -> Dictionary:
	if not NetworkSession.is_online():
		return sample_local_input(false)
	if controlling_peer_id == NetworkSession.HOST_PEER_ID:
		return sample_local_input(true)
	if Time.get_ticks_msec() - last_remote_input_msec > INPUT_STALE_MSEC:
		return {"direction": Vector2.ZERO, "sprinting": false}
	return {"direction": remote_direction, "sprinting": remote_sprinting}


func _input(event: InputEvent) -> void:
	if not NetworkSession.is_joining_peer() or player_slot != NetworkSession.get_local_player_slot():
		return
	if event.is_action_pressed("interact") and not event.is_echo():
		var command := sample_local_input(true)
		submit_interact.rpc_id(
			NetworkSession.HOST_PEER_ID,
			NetworkSession.match_generation,
			command["direction"]
		)


func _process_joining_peer_input(delta: float) -> void:
	if player_slot != NetworkSession.get_local_player_slot() or NetworkSession.session_state != NetworkSession.SessionState.IN_MATCH:
		return
	input_send_accumulator += delta
	if input_send_accumulator < INPUT_SEND_INTERVAL:
		return
	input_send_accumulator = fmod(input_send_accumulator, INPUT_SEND_INTERVAL)
	var command := sample_local_input(true)
	submit_input.rpc_id(
		NetworkSession.HOST_PEER_ID,
		NetworkSession.match_generation,
		command["direction"],
		command["sprinting"]
	)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func submit_input(generation: int, direction: Vector2, sprinting: bool) -> void:
	if not multiplayer.is_server() or generation != NetworkSession.match_generation:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != controlling_peer_id or player_slot != 2:
		return
	remote_direction = direction.limit_length(1.0)
	remote_sprinting = sprinting
	last_remote_input_msec = Time.get_ticks_msec()


@rpc("any_peer", "call_remote", "reliable")
func submit_interact(generation: int, direction: Vector2) -> void:
	if not multiplayer.is_server() or generation != NetworkSession.match_generation:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != controlling_peer_id or player_slot != 2 or not is_sleeping:
		return
	if not is_instance_valid(active_ghost) or active_ghost.is_picking:
		return
	if active_ghost.held_item == null:
		active_ghost.attempt_pickup()
	elif direction.length_squared() > 0.01:
		active_ghost.throw_item(direction.limit_length(1.0))
	else:
		active_ghost.drop_item()


func _on_local_focus_changed(has_focus: bool) -> void:
	if has_focus or not NetworkSession.is_joining_peer() or player_slot != NetworkSession.get_local_player_slot():
		return
	submit_input.rpc_id(NetworkSession.HOST_PEER_ID, NetworkSession.match_generation, Vector2.ZERO, false)


func _update_remote_presentation() -> void:
	shield_visual.visible = is_shield_active
	prison_visual.visible = is_prison_active
	active_effect_icon = SHOE_ICON if active_effect_name in [SHOE_EFFECT_LABEL, SHOE_CHAOS_LABEL] else null
	if is_panicked_fire_active:
		modulate = Color(1.0, 0.5, 0.5)
	elif is_ramming_active:
		modulate = Color(1.5, 1.5, 0.5, 0.8)
	elif not is_sleeping:
		modulate = Color.WHITE
	if is_sleeping:
		sprite.play("sleeping")
	elif velocity.length_squared() > 1.0:
		sprite.play("walking")
	else:
		sprite.play("idle")


func consume_stamina(delta):
	current_stamina -= depletion_rate * delta

	if current_stamina <= 0:
		enter_sleep()

func _on_restore_stamina(amount: float, target_slot: int):
	if target_slot == player_slot and NetworkSession.has_simulation_authority():
		current_stamina += amount
		# Prevent stamina from exceeding the maximum limit
		current_stamina = min(current_stamina, max_stamina)

func enter_sleep():
	is_transitioning_to_ghost = true
	is_sleeping = true
	transition.show()
	transition.play("default")
	velocity = Vector2.ZERO

	# modulate = Color(0.5, 0.5, 1.0) # Turn slightly blue/dark to show sleeping

	audio.play_sleep_sfx()
	active_ghost = get_parent().get_node_or_null("Ghosts/PlayerGhost%d" % player_slot) as CharacterBody2D
	if active_ghost == null:
		is_transitioning_to_ghost = false
		return
	active_ghost.input_prefix = input_prefix
	active_ghost.player_slot = player_slot
	active_ghost.controlling_peer_id = controlling_peer_id
	active_ghost.global_position = global_position
	active_ghost.active = true
	active_ghost.modulate.a = 0.0 # Start invisible
	var end_pos = global_position + Vector2(0, -60) # Float up slightly

	await get_tree().process_frame

	var tween = create_tween().set_parallel(true)
	tween.tween_property(active_ghost, "modulate:a", 1.0, 0.5) # Fade in
	tween.tween_property(active_ghost, "global_position", end_pos, 0.8)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Wait for the tween to finish before allowing a Game Over
	await tween.finished
	is_transitioning_to_ghost = false

	SignalBus.emit_signal("ghost_mode_started", player_slot)


func handle_sleep(delta):
	sprite.play("sleeping")
	current_stamina += recharge_rate * delta
	current_stamina = min(current_stamina, max_stamina)

	regen_accumulator += health_regen_rate * delta
	if regen_accumulator >= 0.5: # Heal in half-heart increments
		# Sending negative damage to the SignalBus restores health
		apply_damage(-0.5)
		regen_accumulator = 0.0

	if current_stamina >= max_stamina and not is_returning:
		if active_ghost:
			trigger_ghost_return()
		else:
			wake_up() # Fallback if ghost was already destroyed

func trigger_ghost_return():
	is_returning = true

	if is_instance_valid(active_ghost):
		if active_ghost.held_item != null:
			active_ghost.drop_item()
			await get_tree().create_timer(0.5).timeout

		# Ensure ghost is still valid after the await
		if is_instance_valid(active_ghost):
			active_ghost.set_physics_process(false)
			active_ghost.set_process_input(false)

			var tween = create_tween().set_parallel(true)
			tween.tween_property(active_ghost, "global_position", global_position, 0.8)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tween.tween_property(active_ghost, "modulate:a", 0.0, 0.8)

			await tween.finished

			# Persistent Ghosts keep stable scene paths for replication.
			if is_instance_valid(active_ghost):
				active_ghost.active = false
				active_ghost = null

	is_returning = false
	wake_up()

func wake_up():
	is_sleeping = false
	modulate = Color(1, 1, 1)
	sprite.play("idle")

	SignalBus.emit_signal("ghost_mode_ended", player_slot)

func _on_swap_player():
	if is_sleeping:
		# 1. Force the ghost to disappear immediately on swap
		if is_instance_valid(active_ghost):
			if active_ghost.held_item != null:
				active_ghost.drop_item()
			active_ghost.active = false
			active_ghost = null

		# 2. Reset the transition flag just in case it was mid-entrance
		is_transitioning_to_ghost = false
		is_returning = false

		wake_up()
	else:
		# 3. If waking player is hit by lighter, they fall asleep
		enter_sleep()

func update_ui():
	stamina_bar.value = current_stamina


func update_candle_glow(delta: float) -> void:
	if not candle_light:
		return

	glow_time += delta * glow_flicker_speed

	var flicker := 0.0
	flicker += sin(glow_time) * 0.55
	flicker += sin((glow_time * 2.23) + 1.7) * 0.3
	flicker += sin((glow_time * 3.97) + 0.4) * 0.15
	flicker = clamp(flicker, -1.0, 1.0)

	var target_energy = glow_base_energy + (flicker * glow_flicker_strength)
	if is_sleeping:
		target_energy *= glow_sleep_multiplier

	candle_light.modulate.a = clamp(target_energy, 0.28, 0.95)
	var scale_jitter = 1.38 + (flicker * 0.05)
	candle_light.scale = Vector2.ONE * clamp(scale_jitter, 4.30, 3.48)


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


func apply_damage(amount: float) -> void:
	if not NetworkSession.has_simulation_authority():
		return
	health = clampf(health - amount, 0.0, max_health)
	if health <= 0.0:
		SignalBus.emit_signal("game_over", "Player %d died!" % player_slot)


func receive_hit(damage_amount: float, knockback_force: Vector2 = Vector2.ZERO, apply_stun: bool = false) -> void:
	if not NetworkSession.has_simulation_authority():
		return
	if is_damage_blocked():
		audio.play_block_sfx()
		return

	apply_damage(damage_amount)
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

	var base_dir = last_move_dir
	if target:
		base_dir = global_position.direction_to(target.global_position)

		if is_panicked_fire_active:
			base_dir = -base_dir # Flip the vector

	# Decide how many shots to fire
	var shot_angles = [0.0]
	if is_flamethrower_active or is_panicked_fire_active or is_triple_shot_active:
		shot_angles = [-0.52, 0.0, 0.52] # -30, 0, +30 degrees

	for angle in shot_angles:
		var final_dir = base_dir.rotated(angle)
		NetworkSession.spawn_replicated(projectile_scene, {
			"global_position": global_position + (final_dir * muzzle_offset),
			"direction": final_dir,
			"speed": projectile_speed,
			"damage": projectile_damage,
			"owner_group": "Players",
			"target_group": "Enemies",
		})
		audio.play_shoot_sfx()

func _on_triple_shot_received(duration: float, target_slot: int):
	if target_slot == player_slot and NetworkSession.has_simulation_authority():
		is_triple_shot_active = true
		var effect_token := begin_timed_effect(OIL_EFFECT_LABEL, duration)
		await get_tree().create_timer(duration).timeout
		if effect_token != active_effect_token:
			return
		is_triple_shot_active = false
		end_timed_effect(effect_token)

func _on_flamethrower_received(duration: float, target_slot: int):
	if target_slot == player_slot and NetworkSession.has_simulation_authority():
		var original_interval = shoot_interval
		var effect_token := begin_timed_effect(OIL_CHAOS_LABEL, duration)

		is_panicked_fire_active = true # Start shooting backwards
		shoot_interval = 0.05

		# Make the player spin or look confused with modulate
		modulate = Color(1.0, 0.5, 0.5) # Panicked red tint

		await get_tree().create_timer(duration).timeout
		if effect_token != active_effect_token:
			return

		# Reset
		is_panicked_fire_active = false
		shoot_interval = original_interval
		modulate = Color(1, 1, 1)
		end_timed_effect(effect_token)

func set_active_effect(name: String, duration: float, icon: Texture2D = null) -> void:
	active_effect_name = name
	active_effect_time_left = duration
	active_effect_icon = icon


func begin_timed_effect(name: String, duration: float, icon: Texture2D = null) -> int:
	_cleanup_timed_effect_modifiers()
	active_effect_token += 1
	var token := active_effect_token
	set_active_effect(name, duration, icon)
	return token


func _cleanup_timed_effect_modifiers() -> void:
	is_triple_shot_active = false
	is_flamethrower_active = false
	is_panicked_fire_active = false
	is_ramming_active = false
	if is_shield_active:
		is_invincible = false
	is_shield_active = false
	is_prison_active = false
	speed = base_speed
	shoot_interval = default_shoot_interval
	shield_visual.hide()
	prison_visual.hide()
	modulate = Color.WHITE


func end_timed_effect(token: int) -> void:
	if token == active_effect_token:
		clear_active_effect()


func clear_active_effect() -> void:
	active_effect_name = ""
	active_effect_time_left = 0.0
	active_effect_icon = null


func has_active_effect() -> bool:
	return active_effect_time_left > 0.0 and active_effect_name != ""


func update_effect_state(delta: float) -> void:
	if active_effect_time_left > 0.0:
		active_effect_time_left = max(active_effect_time_left - delta, 0.0)
		if active_effect_time_left == 0.0:
			clear_active_effect()


func _on_speed_boost_received(multiplier: float, duration: float, target_slot: int):
	if target_slot == player_slot and NetworkSession.has_simulation_authority():
		var effect_token := begin_timed_effect(SHOE_EFFECT_LABEL, duration, SHOE_ICON)

		speed = base_speed * multiplier

		await get_tree().create_timer(duration).timeout

		if effect_token != active_effect_token:
			return

		speed = base_speed
		end_timed_effect(effect_token)

func _on_speed_backfire_received(multiplier: float, duration: float, target_slot: int):
	if target_slot == player_slot and NetworkSession.has_simulation_authority():
		play_tv_static(0.25)
		var original_speed = base_speed
		var effect_token := begin_timed_effect(SHOE_CHAOS_LABEL, duration, SHOE_ICON)
		is_ramming_active = true
		speed = base_speed * multiplier

		# Visual feedback: Turn yellow and slightly transparent to look like a blur
		modulate = Color(1.5, 1.5, 0.5, 0.8)

		await get_tree().create_timer(duration).timeout
		if effect_token != active_effect_token:
			return

		is_ramming_active = false
		speed = base_speed
		modulate = Color(1, 1, 1, 1)
		end_timed_effect(effect_token)

func _on_shield_boost_received(duration: float, target_slot: int):
	if target_slot == player_slot and NetworkSession.has_simulation_authority():
		print_debug("shield boost")
		var effect_token := begin_timed_effect(SHIELD_EFFECT_LABEL, duration)
		is_invincible = true
		is_shield_active = true
		shield_visual.show()

		await get_tree().create_timer(duration).timeout
		if effect_token != active_effect_token:
			return

		is_shield_active = false
		is_invincible = false
		shield_visual.hide()
		end_timed_effect(effect_token)

func _on_shield_backfire_received(duration: float, target_slot: int):
	if target_slot == player_slot and NetworkSession.has_simulation_authority():
		play_tv_static(0.25)
		print_debug("shield side effect boost")
		var effect_token := begin_timed_effect(SHIELD_CHAOS_LABEL, duration)
		is_prison_active = true
		speed = 0
		prison_visual.show()

		# Optional: Add a screen shake or visual glitch for "Losing Control"

		await get_tree().create_timer(duration).timeout
		if effect_token != active_effect_token:
			return

		is_prison_active = false
		speed = base_speed # Restore movement [cite: 17]
		prison_visual.hide()
		end_timed_effect(effect_token)

func spawn_afterimage():
	var afterimg = afterimage_scene.instantiate()
	get_parent().add_child(afterimg)

	afterimg.global_position = global_position
	afterimg.show_afterimage(sprite)
	afterimg.modulate = modulate

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



func play_tv_static(duration: float = 0.2) -> void:
	if static_tween:
		static_tween.kill()

	var mat := static_fx.material as ShaderMaterial
	if mat == null:
		return

	static_fx.visible = true
	mat.set_shader_parameter("intensity", 0.0)

	static_tween = create_tween()

	# FAST fade in
	static_tween.tween_method(
		func(v): mat.set_shader_parameter("intensity", v),
		0.0,
		1.0,
		0.05
	)

	# short hold
	static_tween.tween_interval(duration)

	# FAST fade out
	static_tween.tween_method(
		func(v): mat.set_shader_parameter("intensity", v),
		1.0,
		0.0,
		0.08
	)

	static_tween.tween_callback(func():
		static_fx.visible = false
	)

func _on_transition_animation_finished() -> void:
	transition.visible = false
	transition.stop()
	transition.frame = 0
