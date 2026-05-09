extends Node2D

@export var lifetime: float = 0.3
@export var fade_curve: Curve

var time := 0.0

func _process(delta):
	time += delta
	
	var t := time / lifetime
	if t >= 1.0:
		queue_free()
		return
	
	var alpha := 1.0 - t
	if fade_curve:
		alpha = fade_curve.sample(t)
	
	$Sprite2D.modulate.a = alpha


func show_afterimage(player_sprite: AnimatedSprite2D):
	var sprite = $Sprite2D
	
	sprite.texture = player_sprite.sprite_frames.get_frame_texture(
		player_sprite.animation,
		player_sprite.frame
	)
	
	sprite.flip_h = player_sprite.flip_h
	sprite.scale = player_sprite.scale
