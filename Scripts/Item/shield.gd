extends "res://Scripts/Item/item.gd"

@export var duration: float = 10.0
@onready var shield_sfx: AudioStreamPlayer2D = $ShieldSFX

func _ready():
	super()
	custom_throw_distance = 250.0

func _on_body_entered(body):
	if is_thrown and body.is_in_group("Players"):
		if is_instance_valid(throwing_ghost):
			throwing_ghost.set_deferred("is_picking", false)
		
		var p_id = body.input_prefix
		
		# 50/50 chance for Immunity vs. Imprisonment
		if randf() < 0.5:
			# Backfire: The Wall
			SignalBus.emit_signal.call_deferred("apply_shield_backfire", duration, p_id)
		else:
			# Blessing: Immunity
			SignalBus.emit_signal.call_deferred("apply_shield_boost", duration, p_id)
		
		if shield_sfx:
			play_sfx(shield_sfx)
		queue_free()

func play_sfx(template):
	var sfx = AudioStreamPlayer2D.new()
	sfx.stream = template.stream
	sfx.volume_db = 4.0
	sfx.global_position = global_position
	get_tree().current_scene.add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)
