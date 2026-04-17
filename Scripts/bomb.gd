extends "res://Scripts/item.gd"

@onready var explosion_area = $ExplosionArea
@onready var anim_sprite = $ExplosionVFX
@onready var sprite = $Sprite2D # Your original bomb sprite

@export var bomb_throw_distance: float = 450.0

func _ready():
	super()
	custom_throw_distance = 450.0
	
func _finish_throw(ghost):
	super._finish_throw(ghost)
	
	explode()

func explode():
	# Stop the bomb from moving/being picked up again
	is_thrown = false 
	monitoring = false 
	monitorable = false 
	
	# Hide the bomb sprite and show/play the explosion 
	if sprite: sprite.visible = false
	anim_sprite.visible = true
	anim_sprite.play("explode")
	
	# AOE Logic
	var targets = explosion_area.get_overlapping_bodies()
	for target in targets:
		if target.is_in_group("Enemies"):
			if target.has_method("take_damage"):
				target.take_damage(10.0)
		elif target.is_in_group("Players"):
			SignalBus.emit_signal("take_damage", 3.0, target.input_prefix)
	
	await anim_sprite.animation_finished
	queue_free()
