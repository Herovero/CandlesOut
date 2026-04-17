extends "res://Scripts/item.gd"

@onready var explosion_area = $ExplosionArea
@onready var anim_sprite = $ExplosionVFX
@onready var sprite = $Sprite2D # Your original bomb sprite
@onready var left_wing = $LeftWing   # Your AnimatedSprite2D
@onready var right_wing = $RightWing # Your AnimatedSprite2D
@onready var explosion_sfx: AudioStreamPlayer2D = $ExplosionSFX
@onready var fly_sfx: AudioStreamPlayer2D = $FlySFX

@export var bomb_throw_distance: float = 450.0
var is_stalking: bool = false
var was_stalking := false
@export var max_stalk_time: float = 5.0
var stalk_timer: float = 0.0

func _ready():
	super()
	custom_throw_distance = 450.0
	
func _finish_throw(ghost):
	super._finish_throw(ghost)
	
	# 50% chance to grow wings instead of exploding
	if randf() < 0.5:
		start_stalking()
	else:
		explode()

func explode():
	# Stop the bomb from moving/being picked up again
	is_thrown = false 
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	# Hide the bomb sprite and show/play the explosion 
	if sprite: sprite.visible = false
	anim_sprite.visible = true
	anim_sprite.play("explode")
	
	print("explode sounds")
	explosion_sfx.global_position = global_position
	explosion_sfx.play()
	# AOE Logic
	var targets = explosion_area.get_overlapping_bodies()
	for target in targets:
		if target.is_in_group("Enemies"):
			if target.has_method("take_bomb_damage"):
				target.take_bomb_damage(1.0)
			elif target.has_method("take_damage"):
				target.take_damage(10.0)
		elif target.is_in_group("Players"):
			SignalBus.emit_signal("take_damage", 3.0, target.input_prefix)
	
	await anim_sprite.animation_finished
	queue_free()

func start_stalking():
	is_stalking = true
	stalk_timer = 0.0 # Reset timer
	left_wing.visible = true
	right_wing.visible = true
	left_wing.play("default")
	right_wing.play("default")

func _physics_process(delta):
	if is_stalking:
		stalk_timer += delta
		if not was_stalking:
			fly_sfx.play()
		# Condition: Explode if chase lasts too long
		if stalk_timer >= max_stalk_time:
			explode()
			return
		var target = find_active_player()
		if target:
			var dir = global_position.direction_to(target.global_position)
			global_position += dir * 150.0 * delta # Speed of the flying bomb
	was_stalking = is_stalking
	
func find_active_player() -> CharacterBody2D:
	var players = get_tree().get_nodes_in_group("Players")
	for p in players:
		# Don't move toward the sleeping player
		if not p.is_sleeping:
			return p
	return null

func _on_body_entered(body):
	# If the bomb is stalking and hits the active player
	if is_stalking and body.is_in_group("Players") and not body.is_sleeping:
		explode()
