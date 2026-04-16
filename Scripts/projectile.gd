extends Area2D

@export var speed: float = 600
@export var damage: int = 1
var direction: Vector2 = Vector2.RIGHT

func _process(delta):
	position += direction * speed * delta

#func _on_body_entered(body):
 #   if body.has_method("take_damage"):
  #      body.take_damage(damage)
   # queue_free()
