extends Control

@onready var play_button: Button = $Center/PlayButton
@onready var tutorial_button: Button = $Center/TutorialButton
@onready var volume_slider: HSlider = $Center/SoundRow/VolumeSlider
@onready var title_music: AudioStreamPlayer = $TitleMusic

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	tutorial_button.pressed.connect(_on_tutorial_pressed)

	_bind_button_feedback(play_button)
	_bind_button_feedback(tutorial_button)

	volume_slider.value_changed.connect(_on_volume_changed)

	await get_tree().process_frame
	play_button.pivot_offset = play_button.size * 0.5
	tutorial_button.pivot_offset = tutorial_button.size * 0.5

	var master_bus = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_bus, false)
	var current_db = AudioServer.get_bus_volume_db(master_bus)
	var current_linear = db_to_linear(current_db)
	volume_slider.value = clamp(current_linear, 0.0, 1.0)
	title_music.volume_db = -10.0 
	title_music.play()


func _on_play_pressed() -> void:
	title_music.stop()
	get_tree().change_scene_to_file("res://Scenes/main.tscn")


func _on_tutorial_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/tutorial.tscn")


func _on_volume_changed(value: float) -> void:
	var master_bus = AudioServer.get_bus_index("Master")
	var clamped = clamp(value, 0.0, 1.0)
	var db = -80.0 if clamped <= 0.001 else linear_to_db(clamped)
	AudioServer.set_bus_mute(master_bus, false)
	AudioServer.set_bus_volume_db(master_bus, db)


func _bind_button_feedback(button: Button) -> void:
	button.mouse_entered.connect(func() -> void:
		animate_button_scale(button, Vector2(1.04, 1.04), 0.14)
	)
	button.mouse_exited.connect(func() -> void:
		animate_button_scale(button, Vector2.ONE, 0.14)
	)
	button.button_down.connect(func() -> void:
		animate_button_scale(button, Vector2(0.97, 0.97), 0.08)
	)
	button.button_up.connect(func() -> void:
		animate_button_scale(button, Vector2(1.04, 1.04), 0.08)
	)


func animate_button_scale(button: Button, target: Vector2, duration: float) -> void:
	var tween = create_tween()
	tween.tween_property(button, "scale", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
