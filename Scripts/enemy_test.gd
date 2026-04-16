extends CharacterBody2D

@export var speed : float = 100.0


func _physics_process(delta: float) -> void:                    
	var direction = Vector2.ZERO                                   														   
	var player = get_node_or_null("/root/main/Player1")            
	if player:                                                     
		direction = (player.global_position - global_position).normalized() 															 
		velocity = direction * speed                                   
		move_and_slide()   


#func _process(delta: float) -> void:
	#position.y -= speed * delta
