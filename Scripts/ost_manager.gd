extends Node


@onready var tracks = [ $OST1, $OST2, $OST3 ]

@export var fade_speed: float = 1.0 # how fast tracks crossfade 
var current_track: AudioStreamPlayer = null

func play_wave_ost(wave_number: int):
	var index = wave_number - 1
	if index < 0 or index >= tracks.size():
		return
	
	var next_track = tracks[index]
	
	if current_track == next_track:
		return
	
	if current_track:
		fade_out(current_track)
	
	current_track = next_track
	current_track.play()
	fade_in(current_track)


func fade_out(track: AudioStreamPlayer):
	var tween = create_tween()
	tween.tween_property(track, "volume_db", -40.0, fade_speed)
	await tween.finished
	track.stop()
	track.volume_db = 0.0

func fade_in(track: AudioStreamPlayer):
	track.volume_db = -40.0
	var tween = create_tween()
	tween.tween_property(track, "volume_db", -5.0, fade_speed)

func set_volume(value: float):
	for track in tracks:
		track.volume_db = value
