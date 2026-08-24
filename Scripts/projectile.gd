extends Area2D

@export var speed: float = 200.0
@export var damage: float = 1.0
@export var lifetime: float = 2.0
@onready var anim := $AnimatedSprite2D

var direction: Vector2 = Vector2.RIGHT
var owner_group: String = ""
var target_group: String = ""
var network_generation: int = 0
var network_position: Vector2 = Vector2.ZERO
var network_velocity: Vector2 = Vector2.ZERO


func _ready() -> void:
	direction = direction.normalized()
	anim.sprite_frames.set_animation_speed("default", 15)
	anim.play()

	if owner_group == "Enemies":
		anim.modulate = Color(0.45, 0.74, 1.0, 1.0)
		anim.scale = Vector2(2.0, 2.6)
	else:
		anim.modulate = Color(1.0, 1.0, 1.0, 1.0)
		anim.scale = Vector2(3.0, 3.0)

	$LifetimeTimer.wait_time = lifetime
	$LifetimeTimer.start()
	rotation = direction.angle()
	network_generation = NetworkSession.match_generation
	network_position = position
	network_velocity = direction * speed
	NetworkSession.configure_moving_synchronizer(self, [&"rotation"])
	if not NetworkSession.has_simulation_authority():
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)


func _physics_process(delta: float) -> void:
	if NetworkSession.has_simulation_authority():
		global_position += direction * speed * delta
		NetworkSession.publish_movement(self, direction * speed)
	else:
		NetworkSession.interpolate_movement(self, delta)


func _on_body_entered(body: Node) -> void:
	if not NetworkSession.has_simulation_authority():
		return
	if owner_group != "" and body.is_in_group(owner_group):
		return

	if target_group != "" and not body.is_in_group(target_group):
		return

	if body.is_in_group("Players"):
		if body.has_method("receive_hit"):
			body.receive_hit(damage)
		elif body.has_method("is_damage_blocked") and body.is_damage_blocked():
			queue_free()
			return
		else:
			body.apply_damage(damage)
	elif body.is_in_group("Enemies") and body.has_method("take_damage"):
		body.take_damage(damage)

	queue_free()


func _on_lifetime_timer_timeout() -> void:
	if NetworkSession.has_simulation_authority():
		queue_free()
