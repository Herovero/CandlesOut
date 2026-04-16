extends CharacterBody2D

const speed: float = 50.0
const hp: float = 100.0
@export var damage_amount: float = 1.0

@onready var hitbox: Area2D = $Hitbox
@onready var attack_timer: Timer = $AttackTimer

var target_player: CharacterBody2D = null

func _ready():
	pass

func _physics_process(delta: float) -> void:
	var target = find_closest_player()
	var direction = Vector2.ZERO
	
	if target:
		direction = global_position.direction_to(target.global_position)

	velocity = direction * speed
	move_and_slide()

func find_closest_player() -> CharacterBody2D:
	var players = get_tree().get_nodes_in_group("Players") # Matches your group name
	var closest_player = null
	var shortest_distance = INF # Start with infinity
	
	for player in players:
		# Avoid targeting the 'Ghost' if it's in the same group but shouldn't be chased
		if player.has_method("is_sleeping") and player.is_sleeping:
			continue
			
		var distance = global_position.distance_to(player.global_position)
		if distance < shortest_distance:
			shortest_distance = distance
			closest_player = player
			
	return closest_player
	
func _on_hitbox_body_entered(body):
	if body.is_in_group("Players"):
		# body.input_prefix will grab "p1_" or "p2_" based on which player it just touched
		SignalBus.emit_signal("take_damage", 1.0, body.input_prefix)
		
