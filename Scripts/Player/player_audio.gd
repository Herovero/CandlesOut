extends Node

@onready var player = $".."
@onready var footstep_player: AudioStreamPlayer2D = $"../SoundEffects/FootstepPlayer"
@onready var shoot_sound: AudioStreamPlayer2D = $"../SoundEffects/ShootPlayer"
@onready var blocked_sfx: AudioStreamPlayer2D = $"../SoundEffects/Blocked"
@onready var sleep_sfx: Array = [
	$"../SoundEffects/Sleep_1",
	$"../SoundEffects/Sleep_2"
]

func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = stream
	sfx.volume_db = volume_db
	sfx.global_position = player.global_position
	get_tree().current_scene.add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

func play_sleep_sfx() -> void:
	var picked = sleep_sfx[randi() % sleep_sfx.size()]
	play_sfx(picked.stream, 10.0)

func play_block_sfx() -> void:
	play_sfx(blocked_sfx.stream, -5.0)

func play_shoot_sfx() -> void:
	shoot_sound.pitch_scale = randf_range(0.95, 1.05)
	shoot_sound.play()

func handle_footsteps(delta: float, direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		player.footstep_timer = 0.0
		return

	player.footstep_timer -= delta
	if player.footstep_timer <= 0.0:
		footstep_player.pitch_scale = randf_range(0.9, 1.1)
		footstep_player.play()
		player.footstep_timer = player.footstep_interval
