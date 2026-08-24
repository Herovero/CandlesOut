extends Node


@onready var tracks = [ $OST1, $OST2, $OST3 ]
@onready var intros = [ $Intro1, $Intro2, $Intro3 ]
@export var fade_speed: float = 1.0 # how fast tracks crossfade 
var current_track: AudioStreamPlayer = null
var transition_token: int = 0


func _ready() -> void:
	Global.ost_manager = self
	GameplayAudio.register_ost_manager(self)


func _exit_tree() -> void:
	GameplayAudio.unregister_ost_manager(self)
	if Global.ost_manager == self:
		Global.ost_manager = null


func play_wave_ost(wave_number: int):
	var index = wave_number - 1
	if index < 0 or index >= tracks.size():
		return
	
	var next_track = tracks[index]
	
	if current_track == next_track:
		return
	
	transition_token += 1
	var token := transition_token
	if current_track:
		fade_out(current_track)
	
	await _play_intro(wave_number)  # wait for intro to finish before wave ost
	if token != transition_token:
		return
	
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
		
func _play_intro(wave_number: int):
	var index = wave_number - 1 
	if index < 0 or index >= intros.size():
		return
	var intro = intros[index]
	intro.volume_db = -40.0
	intro.play()
	var tween = create_tween()
	tween.tween_property(intro, "volume_db", 0.0, fade_speed)
	await intro.finished
	intro.stop()

func stop_all():
	transition_token += 1
	for intro in intros:
		intro.stop()
	for track in tracks:
		track.stop()
	current_track = null
