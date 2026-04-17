extends Control

@onready var play_button: Button = $Center/PlayButton
@onready var volume_slider: HSlider = $Center/SoundRow/VolumeSlider


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	play_button.mouse_entered.connect(_on_play_hovered)
	play_button.mouse_exited.connect(_on_play_unhovered)
	play_button.button_down.connect(_on_play_button_down)
	play_button.button_up.connect(_on_play_button_up)

	volume_slider.value_changed.connect(_on_volume_changed)

	await get_tree().process_frame
	play_button.pivot_offset = play_button.size * 0.5

	var master_bus = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_bus, false)
	var current_db = AudioServer.get_bus_volume_db(master_bus)
	var current_linear = db_to_linear(current_db)
	volume_slider.value = clamp(current_linear, 0.0, 1.0)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main.tscn")


func _on_volume_changed(value: float) -> void:
	var master_bus = AudioServer.get_bus_index("Master")
	var clamped = clamp(value, 0.0, 1.0)
	var db = -80.0 if clamped <= 0.001 else linear_to_db(clamped)
	AudioServer.set_bus_mute(master_bus, false)
	AudioServer.set_bus_volume_db(master_bus, db)


func _on_play_hovered() -> void:
	animate_play_button_scale(Vector2(1.04, 1.04), 0.14)


func _on_play_unhovered() -> void:
	animate_play_button_scale(Vector2.ONE, 0.14)


func _on_play_button_down() -> void:
	animate_play_button_scale(Vector2(0.97, 0.97), 0.08)


func _on_play_button_up() -> void:
	animate_play_button_scale(Vector2(1.04, 1.04), 0.08)


func animate_play_button_scale(target: Vector2, duration: float) -> void:
	var tween = create_tween()
	tween.tween_property(play_button, "scale", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
