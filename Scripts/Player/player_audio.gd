extends Node

@onready var player = $".."
@onready var footstep_player: AudioStreamPlayer2D = $"../SoundEffects/FootstepPlayer"


func play_sleep_sfx() -> void:
	NetworkSession.broadcast_sfx(GameplayAudio.Cue.PLAYER_SLEEP, player.global_position)


func play_block_sfx() -> void:
	NetworkSession.broadcast_sfx(GameplayAudio.Cue.PLAYER_BLOCK, player.global_position)


func play_shoot_sfx() -> void:
	NetworkSession.broadcast_sfx(GameplayAudio.Cue.PLAYER_SHOOT, player.global_position)

func handle_footsteps(delta: float, direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		player.footstep_timer = 0.0
		return

	player.footstep_timer -= delta
	if player.footstep_timer <= 0.0:
		footstep_player.pitch_scale = randf_range(0.9, 1.1)
		footstep_player.play()
		player.footstep_timer = player.footstep_interval
