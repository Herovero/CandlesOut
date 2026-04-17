extends Area2D

@export var speed: float = 200.0
@export var damage: float = 1.0
@export var lifetime: float = 2.0

var direction: Vector2 = Vector2.RIGHT
var owner_group: String = ""
var target_group: String = ""


func _ready() -> void:
	direction = direction.normalized()
	$LifetimeTimer.wait_time = lifetime
	$LifetimeTimer.start()


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta


func _on_body_entered(body: Node) -> void:
	if owner_group != "" and body.is_in_group(owner_group):
		return

	if target_group != "" and not body.is_in_group(target_group):
		return

	if body.is_in_group("Players"):
		if body.has_method("is_damage_blocked") and body.is_damage_blocked():
			queue_free()
			return
		SignalBus.emit_signal("take_damage", damage, body.input_prefix)
	elif body.is_in_group("Enemies") and body.has_method("take_damage"):
		body.take_damage(damage)

	queue_free()


func _on_lifetime_timer_timeout() -> void:
	queue_free()
