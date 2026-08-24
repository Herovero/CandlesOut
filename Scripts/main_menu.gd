extends Control

@onready var play_button: Button = $Center/PlayButton
@onready var host_button: Button = $Center/HostButton
@onready var join_address: LineEdit = $Center/JoinRow/Address
@onready var join_button: Button = $Center/JoinRow/JoinButton
@onready var disconnect_button: Button = $Center/DisconnectButton
@onready var status_label: Label = $Center/StatusLabel
@onready var tutorial_button: Button = $Center/TutorialButton
@onready var boss_button: Button = $Center/BossButton
@onready var volume_slider: HSlider = $Center/SoundRow/VolumeSlider
@onready var title_music: AudioStreamPlayer = $TitleMusic


func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	play_button.pressed.connect(_on_play_pressed)
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	disconnect_button.pressed.connect(_on_disconnect_pressed)
	tutorial_button.pressed.connect(_on_tutorial_pressed)
	join_address.text_changed.connect(_on_join_address_changed)

	for button in [play_button, host_button, join_button, disconnect_button, tutorial_button, boss_button]:
		_bind_button_feedback(button)

	_setup_volume_slider_visuals()
	volume_slider.value_changed.connect(_on_volume_changed)
	NetworkSession.status_changed.connect(_on_network_status_changed)
	NetworkSession.session_state_changed.connect(_on_session_state_changed)

	boss_button.visible = OS.is_debug_build()
	boss_button.text = "DEBUG: LOCAL BOSS MATCH"
	join_address.text = "127.0.0.1"
	_on_join_address_changed(join_address.text)
	_refresh_session_ui()

	await get_tree().process_frame
	for button in [play_button, host_button, join_button, disconnect_button, tutorial_button, boss_button]:
		button.pivot_offset = button.size * 0.5

	var master_bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_bus, false)
	var current_db := AudioServer.get_bus_volume_db(master_bus)
	volume_slider.value = clamp(db_to_linear(current_db), 0.0, 1.0)
	title_music.volume_db = -10.0
	title_music.play()


func _on_play_pressed() -> void:
	title_music.stop()
	NetworkSession.start_local_match(false)


func _on_host_pressed() -> void:
	var error := NetworkSession.host_game()
	if error == OK:
		_refresh_session_ui()


func _on_join_pressed() -> void:
	var error := NetworkSession.join_game(join_address.text)
	if error == OK:
		_refresh_session_ui()


func _on_disconnect_pressed() -> void:
	NetworkSession.leave_game(false, "Disconnected.")
	_refresh_session_ui()


func _on_tutorial_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/tutorial.tscn")


func _on_volume_changed(value: float) -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	var clamped: float = clampf(value, 0.0, 1.0)
	var db: float = -80.0 if clamped <= 0.001 else linear_to_db(clamped)
	AudioServer.set_bus_mute(master_bus, false)
	AudioServer.set_bus_volume_db(master_bus, db)


func _on_join_address_changed(value: String) -> void:
	join_button.disabled = not NetworkSession.is_valid_ipv4_address(value.strip_edges())


func _on_network_status_changed(message: String) -> void:
	status_label.text = message
	status_label.visible = not message.is_empty()


func _on_session_state_changed(_state: NetworkSession.SessionState) -> void:
	_refresh_session_ui()


func _refresh_session_ui() -> void:
	var idle := NetworkSession.session_state == NetworkSession.SessionState.IDLE
	var connecting := NetworkSession.is_joining_peer() \
		and NetworkSession.session_state == NetworkSession.SessionState.CONNECTING

	play_button.visible = idle
	host_button.visible = idle
	$Center/JoinRow.visible = idle
	tutorial_button.visible = idle
	$Center/SoundRow.visible = idle
	boss_button.visible = idle and OS.is_debug_build()
	disconnect_button.visible = connecting
	status_label.text = NetworkSession.status_message
	status_label.visible = not status_label.text.is_empty()


func _setup_volume_slider_visuals() -> void:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var transparent_icon := ImageTexture.create_from_image(img)
	volume_slider.add_theme_icon_override("grabber", transparent_icon)
	volume_slider.add_theme_icon_override("grabber_highlight", transparent_icon)
	volume_slider.add_theme_icon_override("grabber_disabled", transparent_icon)


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
	var tween := create_tween()
	tween.tween_property(button, "scale", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_boss_button_pressed() -> void:
	if not OS.is_debug_build():
		return
	title_music.stop()
	NetworkSession.start_local_match(true)
