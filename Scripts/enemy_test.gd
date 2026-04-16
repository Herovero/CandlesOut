extends CharacterBody2D

@export var speed: float = 150.0
@export var damage_amount: float = 1.0

@onready var hitbox: Area2D = $Hitbox
@onready var attack_timer: Timer = $AttackTimer

var target_player: CharacterBody2D = null

func _ready():
	pass
	
func _on_hitbox_body_entered(body):
	if body.is_in_group("Players"):
		# body.input_prefix will grab "p1_" or "p2_" based on which player it just touched
		SignalBus.emit_signal("take_damage", 1.0, body.input_prefix)
		
