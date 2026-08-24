extends Node2D

# HUD Elements
@onready var gameover_label = $HUDs/gameover_label
@onready var wave_label = $HUDs/wave_label
@onready var huds: CanvasLayer = $HUDs
@onready var paused_label = $HUDs/PauseContainer/paused_label
@onready var restart_button = $HUDs/PauseContainer/restart_button
@onready var resume_button = $HUDs/PauseContainer/resume_button
@onready var main_menu_button = $HUDs/PauseContainer/main_menu_button
@onready var replicated_entities: Node = $ReplicatedEntities
@onready var multiplayer_spawner: MultiplayerSpawner = $MultiplayerSpawner

# Player Elemetns
@onready var p1 = $Player1
@onready var p2 = $Player2
@onready var p1_effect_label = $HUDs/Player1/EffectLabel
@onready var p1_effect_icon = $HUDs/Player1/EffectIcon
@onready var p2_effect_label = $HUDs/Player2/EffectLabel
@onready var p2_effect_icon = $HUDs/Player2/EffectIcon

# ???
const UI_FONT: FontFile = preload("res://Assets/False Earthdream.ttf")
const PAUSE_BLUR_SHADER: Shader = preload("res://Assets/ui_pause_blur.gdshader")
const PLAYER_WALK_TEXTURE: Texture2D = preload("res://Assets/walk.png")

# Boss related elements
var boss_hp_container: VBoxContainer
var boss_hp_label: Label
var boss_hp_bar: ProgressBar
var phase_overlay: Control
var phase_overlay_bg: ColorRect
var phase_overlay_label: Label

# Pause Elements
var pause_overlay: Control
var pause_blur_rect: ColorRect
var pause_icon_label: Label


#Victory Elemetnts
var victory_overlay: Control
var victory_bg: ColorRect
var victory_label: Label
var victory_candle: AnimatedSprite2D

# Boss Phase
var phase_transition_running: bool = false
var pending_phase_two_refill: bool = false
var is_manual_paused: bool = false


func _ready():
	process_mode = Node.PROCESS_MODE_INHERIT
	Engine.time_scale = 1.0
	get_tree().paused = false
	multiplayer_spawner.spawn_function = _spawn_replicated_from_data
	multiplayer_spawner.process_mode = Node.PROCESS_MODE_ALWAYS
	_configure_player_slots()
	gameover_label.hide()
	_hide_pause_menu()

	p1_effect_icon.visible = false
	p2_effect_icon.visible = false
	p1_effect_label.visible = false
	p2_effect_label.visible = false

	_setup_boss_ui()
	_setup_phase_overlay()
	_setup_pause_overlay()
	_setup_victory_overlay()

	SignalBus.connect("game_over", _on_game_over)
	SignalBus.connect("boss_hp_init", _on_boss_hp_init)
	SignalBus.connect("boss_hp_changed", _on_boss_hp_changed)
	SignalBus.connect("boss_phase_two_transition_started", _on_boss_phase_two_transition_started)
	SignalBus.connect("boss_defeated", _on_boss_defeated)

	if NetworkSession.is_online():
		get_tree().paused = true
		NetworkSession.scene_ready.call_deferred(NetworkSession.match_generation)


func _configure_player_slots() -> void:
	p1.player_slot = 1
	p2.player_slot = 2
	p1.controlling_peer_id = NetworkSession.get_peer_for_slot(1)
	p2.controlling_peer_id = NetworkSession.get_peer_for_slot(2)
	var ghost1 := $Ghosts/PlayerGhost1
	var ghost2 := $Ghosts/PlayerGhost2
	ghost1.controlling_peer_id = p1.controlling_peer_id
	ghost2.controlling_peer_id = p2.controlling_peer_id


func spawn_replicated(scene_path: String, properties: Dictionary = {}) -> Node:
	if not NetworkSession.has_simulation_authority() or not _is_allowed_spawn_scene(scene_path):
		return null
	var data := {
		"generation": NetworkSession.match_generation,
		"scene_path": scene_path,
		"properties": properties,
	}
	if NetworkSession.is_online():
		return multiplayer_spawner.spawn(data)
	return _spawn_replicated_from_data(data)


func _spawn_replicated_from_data(data: Dictionary) -> Node:
	var scene_path := String(data.get("scene_path", ""))
	if not _is_allowed_spawn_scene(scene_path):
		return null
	if NetworkSession.is_online() and int(data.get("generation", -1)) != NetworkSession.match_generation:
		return null
	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		return null
	var instance := packed_scene.instantiate()
	var properties: Dictionary = data.get("properties", {})
	for property in properties:
		if property in instance:
			instance.set(property, properties[property])
	if not NetworkSession.is_online():
		replicated_entities.add_child(instance)
	return instance


func _is_allowed_spawn_scene(scene_path: String) -> bool:
	return scene_path.begins_with("res://Scenes/Enemy/") \
		or scene_path.begins_with("res://Scenes/Items/") \
		or scene_path == "res://Scenes/Player/player_ghost.tscn" \
		or scene_path == "res://Scenes/projectile.tscn"


func _input(event):
	# Check for Esc key press
	if event.is_action_pressed("pause"):
		if NetworkSession.is_joining_peer():
			if paused_label.visible:
				_hide_joining_peer_menu()
			else:
				_show_joining_peer_menu()
			return
		if get_tree().paused:
			_request_host_pause(false)
		else:
			_request_host_pause(true)


func _hide_pause_menu():
	paused_label.hide()
	get_tree().paused = false
	resume_button.hide()
	restart_button.hide()
	main_menu_button.hide()


func _show_pause_menu():
	paused_label.text = "PAUSED"
	paused_label.show()
	get_tree().paused = true
	resume_button.show()
	restart_button.visible = not NetworkSession.is_joining_peer()
	main_menu_button.show()
	main_menu_button.text = "MAIN MENU"


func _show_joining_peer_menu() -> void:
	NetworkSession.local_input_suppressed = true
	paused_label.text = "LOCAL MENU\nMATCH IS STILL RUNNING\nYOU ARE VULNERABLE"
	paused_label.show()
	resume_button.show()
	restart_button.hide()
	main_menu_button.text = "DISCONNECT"
	main_menu_button.show()


func _hide_joining_peer_menu() -> void:
	NetworkSession.local_input_suppressed = false
	paused_label.hide()
	resume_button.hide()
	restart_button.hide()
	main_menu_button.hide()


func _request_host_pause(paused: bool) -> void:
	if NetworkSession.is_online():
		if not NetworkSession.is_online_host():
			return
		_set_network_pause.rpc(paused, NetworkSession.match_generation)
	else:
		_apply_pause(paused)


@rpc("authority", "call_local", "reliable")
func _set_network_pause(paused: bool, generation: int) -> void:
	if not NetworkSession.is_online() or generation != NetworkSession.match_generation:
		return
	_apply_pause(paused)


func _apply_pause(paused: bool) -> void:
	NetworkSession.match_phase = NetworkSession.MatchPhase.PAUSED if paused else NetworkSession.MatchPhase.PLAYING
	if paused:
		_show_pause_menu()
	else:
		_hide_pause_menu()

func _process(_delta):
	if NetworkSession.has_simulation_authority():
		check_total_sleep_condition()
	update_effect_ui()


"""func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	if not event.is_action_pressed("ui_cancel") or event.is_echo():
		return
	if phase_transition_running:
		return

	toggle_pause()"""


func _setup_boss_ui() -> void:
	boss_hp_container = VBoxContainer.new()
	boss_hp_container.name = "BossHPContainer"
	boss_hp_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	boss_hp_container.offset_left = 300
	boss_hp_container.offset_top = 14
	boss_hp_container.offset_right = -300
	boss_hp_container.offset_bottom = 78
	boss_hp_container.alignment = BoxContainer.ALIGNMENT_CENTER
	boss_hp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_hp_container.visible = false

	boss_hp_label = Label.new()
	boss_hp_label.text = "Birthday Boy"
	boss_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_hp_label.modulate = Color(1.0, 0.93, 0.78, 1.0)
	boss_hp_label.add_theme_font_override("font", UI_FONT)
	boss_hp_label.add_theme_font_size_override("font_size", 26)

	boss_hp_bar = ProgressBar.new()
	boss_hp_bar.custom_minimum_size = Vector2(540, 24)
	boss_hp_bar.show_percentage = false
	boss_hp_bar.step = 0.01
	boss_hp_bar.value = 0.0
	boss_hp_bar.modulate = Color(0.96, 0.24, 0.24, 1.0)

	boss_hp_container.add_child(boss_hp_label)
	boss_hp_container.add_child(boss_hp_bar)
	huds.add_child(boss_hp_container)


func _setup_phase_overlay() -> void:
	phase_overlay = Control.new()
	phase_overlay.name = "PhaseOverlay"
	phase_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	phase_overlay.offset_left = 0.0
	phase_overlay.offset_top = 0.0
	phase_overlay.offset_right = 0.0
	phase_overlay.offset_bottom = 0.0
	phase_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phase_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	phase_overlay.visible = false

	phase_overlay_bg = ColorRect.new()
	phase_overlay_bg.name = "Background"
	phase_overlay_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	phase_overlay_bg.offset_left = 0.0
	phase_overlay_bg.offset_top = 0.0
	phase_overlay_bg.offset_right = 0.0
	phase_overlay_bg.offset_bottom = 0.0
	phase_overlay_bg.color = Color(0, 0, 0, 1)
	phase_overlay_bg.modulate.a = 0.0
	phase_overlay.add_child(phase_overlay_bg)

	phase_overlay_label = Label.new()
	phase_overlay_label.name = "Title"
	phase_overlay_label.set_anchors_preset(Control.PRESET_CENTER)
	phase_overlay_label.offset_left = -420
	phase_overlay_label.offset_top = -72
	phase_overlay_label.offset_right = 420
	phase_overlay_label.offset_bottom = 72
	phase_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	phase_overlay_label.text = "PHASE 2 STARTS"
	phase_overlay_label.add_theme_font_override("font", UI_FONT)
	phase_overlay_label.add_theme_font_size_override("font_size", 72)
	phase_overlay_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	phase_overlay_label.add_theme_constant_override("outline_size", 12)
	phase_overlay_label.modulate = Color(0.96, 0.86, 1.0, 0.0)
	phase_overlay.add_child(phase_overlay_label)

	huds.add_child(phase_overlay)


func _setup_pause_overlay() -> void:
	pause_overlay = Control.new()
	pause_overlay.name = "PauseOverlay"
	pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.offset_left = 0.0
	pause_overlay.offset_top = 0.0
	pause_overlay.offset_right = 0.0
	pause_overlay.offset_bottom = 0.0
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_overlay.visible = false

	pause_blur_rect = ColorRect.new()
	pause_blur_rect.name = "Blur"
	pause_blur_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_blur_rect.offset_left = 0.0
	pause_blur_rect.offset_top = 0.0
	pause_blur_rect.offset_right = 0.0
	pause_blur_rect.offset_bottom = 0.0
	pause_blur_rect.color = Color(1, 1, 1, 1)

	var blur_material := ShaderMaterial.new()
	blur_material.shader = PAUSE_BLUR_SHADER
	pause_blur_rect.material = blur_material
	pause_overlay.add_child(pause_blur_rect)

	pause_icon_label = Label.new()
	pause_icon_label.name = "PauseIcon"
	pause_icon_label.set_anchors_preset(Control.PRESET_CENTER)
	pause_icon_label.offset_left = -220
	pause_icon_label.offset_top = -120
	pause_icon_label.offset_right = 220
	pause_icon_label.offset_bottom = 120
	pause_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pause_icon_label.text = "II"
	pause_icon_label.add_theme_font_override("font", UI_FONT)
	pause_icon_label.add_theme_font_size_override("font_size", 170)
	pause_icon_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.84, 1.0))
	pause_icon_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	pause_icon_label.add_theme_constant_override("outline_size", 10)
	pause_overlay.add_child(pause_icon_label)

	huds.add_child(pause_overlay)


func _setup_victory_overlay() -> void:
	victory_overlay = Control.new()
	victory_overlay.name = "VictoryOverlay"
	victory_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	victory_overlay.offset_left = 0.0
	victory_overlay.offset_top = 0.0
	victory_overlay.offset_right = 0.0
	victory_overlay.offset_bottom = 0.0
	victory_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	victory_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	victory_overlay.visible = false

	victory_bg = ColorRect.new()
	victory_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	victory_bg.color = Color(0.02, 0.02, 0.03, 0.7)
	victory_overlay.add_child(victory_bg)

	victory_label = Label.new()
	victory_label.set_anchors_preset(Control.PRESET_CENTER)
	victory_label.offset_left = -760.0
	victory_label.offset_top = -120.0
	victory_label.offset_right = 760.0
	victory_label.offset_bottom = 120.0
	victory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	victory_label.text = "THANKS FOR PLAYING!"
	victory_label.add_theme_font_override("font", UI_FONT)
	victory_label.add_theme_font_size_override("font_size", 100)
	victory_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.84, 1.0))
	victory_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	victory_label.add_theme_constant_override("outline_size", 12)
	victory_overlay.add_child(victory_label)

	victory_candle = AnimatedSprite2D.new()
	victory_candle.sprite_frames = _create_walking_candle_frames()
	victory_candle.animation = "walking"
	victory_candle.scale = Vector2(8, 8)
	victory_candle.process_mode = Node.PROCESS_MODE_ALWAYS
	victory_overlay.add_child(victory_candle)
	_position_victory_candle()

	huds.add_child(victory_overlay)


func _create_walking_candle_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation("walking")
	frames.set_animation_loop("walking", true)
	frames.set_animation_speed("walking", 5.0)

	for i in 5:
		var frame := AtlasTexture.new()
		frame.atlas = PLAYER_WALK_TEXTURE
		frame.region = Rect2(float(i) * 20.0, 0.0, 20.0, 23.0)
		frames.add_frame("walking", frame)

	return frames


func _position_victory_candle() -> void:
	if not is_instance_valid(victory_candle):
		return
	var size = get_viewport_rect().size
	victory_candle.position = Vector2(size.x * 0.5 + 520.0, size.y * 0.5 + 8.0)


func toggle_pause() -> void:
	if phase_transition_running:
		return

	if is_manual_paused:
		is_manual_paused = false
		pause_overlay.visible = false
		Engine.time_scale = 1.0
		get_tree().paused = false
		return

	if get_tree().paused:
		return

	is_manual_paused = true
	pause_overlay.visible = true
	Engine.time_scale = 0.0
	get_tree().paused = true


func _on_boss_hp_init(_boss: Node, current_hp: float, max_hp: float, is_phase_two: bool) -> void:
	boss_hp_container.visible = true
	boss_hp_bar.max_value = max_hp
	boss_hp_bar.value = current_hp
	_set_boss_bar_phase_color(is_phase_two)
	if NetworkSession.is_online_host():
		_sync_boss_hp.rpc(current_hp, max_hp, is_phase_two, NetworkSession.match_generation)


func _on_boss_hp_changed(current_hp: float, max_hp: float, is_phase_two: bool) -> void:
	if not is_instance_valid(boss_hp_bar):
		return

	boss_hp_container.visible = true
	boss_hp_bar.max_value = max_hp
	_set_boss_bar_phase_color(is_phase_two)

	if pending_phase_two_refill and is_phase_two:
		pending_phase_two_refill = false
		boss_hp_bar.value = 0.0
		var refill_tween = create_tween()
		refill_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		refill_tween.tween_property(boss_hp_bar, "value", current_hp, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		return

	boss_hp_bar.value = current_hp
	if NetworkSession.is_online_host():
		_sync_boss_hp.rpc(current_hp, max_hp, is_phase_two, NetworkSession.match_generation)


@rpc("authority", "call_remote", "reliable")
func _sync_boss_hp(current_hp: float, max_hp: float, is_phase_two: bool, generation: int) -> void:
	if not NetworkSession.is_joining_peer() or generation != NetworkSession.match_generation:
		return
	_on_boss_hp_changed(current_hp, max_hp, is_phase_two)


func _set_boss_bar_phase_color(is_phase_two: bool) -> void:
	if is_phase_two:
		boss_hp_bar.modulate = Color(0.72, 0.46, 1.0, 1.0)
	else:
		boss_hp_bar.modulate = Color(0.96, 0.24, 0.24, 1.0)


func _on_boss_phase_two_transition_started() -> void:
	if not NetworkSession.has_simulation_authority():
		return
	if NetworkSession.is_online_host():
		_show_phase_two_transition.rpc(NetworkSession.match_generation)
	else:
		_show_phase_two_transition(NetworkSession.match_generation)


@rpc("authority", "call_local", "reliable")
func _show_phase_two_transition(generation: int) -> void:
	if NetworkSession.is_online() and generation != NetworkSession.match_generation:
		return
	if phase_transition_running:
		return

	phase_transition_running = true
	phase_overlay.visible = true
	phase_overlay_bg.modulate.a = 0.0
	phase_overlay_label.modulate.a = 0.0

	get_tree().paused = true

	var fade_in = create_tween()
	fade_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_in.set_parallel(true)
	fade_in.tween_property(phase_overlay_bg, "modulate:a", 0.92, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fade_in.tween_property(phase_overlay_label, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await fade_in.finished

	await get_tree().create_timer(3.0, true).timeout

	var fade_out = create_tween()
	fade_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_out.set_parallel(true)
	fade_out.tween_property(phase_overlay_bg, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fade_out.tween_property(phase_overlay_label, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	await get_tree().create_timer(0.36, true).timeout
	get_tree().paused = false

	await fade_out.finished

	pending_phase_two_refill = true
	if NetworkSession.has_simulation_authority():
		SignalBus.emit_signal("boss_activate_phase_two")

	phase_overlay.visible = false
	phase_transition_running = false


func _on_boss_defeated() -> void:
	if not NetworkSession.has_simulation_authority():
		return
	NetworkSession.broadcast_music_stop()
	if NetworkSession.is_online_host():
		_show_victory.rpc(NetworkSession.match_generation)
	else:
		_show_victory(NetworkSession.match_generation)


@rpc("authority", "call_local", "reliable")
func _show_victory(generation: int) -> void:
	if NetworkSession.is_online() and generation != NetworkSession.match_generation:
		return
	NetworkSession.match_phase = NetworkSession.MatchPhase.VICTORY
	boss_hp_container.visible = false
	wave_label.hide()
	is_manual_paused = false
	_hide_pause_menu()
	await get_tree().create_timer(2.0).timeout
	victory_overlay.visible = true
	_position_victory_candle()
	victory_candle.play("walking")
	restart_button.visible = not NetworkSession.is_joining_peer()
	main_menu_button.visible = true
	main_menu_button.text = "DISCONNECT" if NetworkSession.is_joining_peer() else "MAIN MENU"
	get_tree().paused = true


func check_total_sleep_condition():
	var players = get_tree().get_nodes_in_group("Players")
	var sleeping_count = 0
	var is_anybody_still_transitioning = false

	for p in players:
		if p.is_sleeping:
			sleeping_count += 1
		if p.get("is_transitioning_to_ghost"):
			is_anybody_still_transitioning = true

	if not is_anybody_still_transitioning:
		if players.size() > 0 and sleeping_count >= players.size():
			SignalBus.emit_signal("game_over", "Both players fell asleep!")


func update_one_effect_ui(player, label: Label, icon: TextureRect) -> void:
	if player and player.has_method("has_active_effect") and player.has_active_effect():
		label.text = "%s (%ds)" % [player.active_effect_name, int(ceil(player.active_effect_time_left))]
		label.visible = true
		icon.texture = player.active_effect_icon
		icon.visible = player.active_effect_icon != null
	else:
		label.visible = false
		icon.texture = null
		icon.visible = false


func update_effect_ui() -> void:
	update_one_effect_ui(p1, p1_effect_label, p1_effect_icon)
	update_one_effect_ui(p2, p2_effect_label, p2_effect_icon)


func _on_game_over(reason: String):
	if not NetworkSession.has_simulation_authority():
		return
	NetworkSession.broadcast_music_stop()
	if NetworkSession.is_online_host():
		_show_game_over.rpc(reason, NetworkSession.match_generation)
	else:
		_show_game_over(reason, NetworkSession.match_generation)


@rpc("authority", "call_local", "reliable")
func _show_game_over(reason: String, generation: int) -> void:
	if NetworkSession.is_online() and generation != NetworkSession.match_generation:
		return
	NetworkSession.match_phase = NetworkSession.MatchPhase.GAME_OVER
	# 1. Clean up any existing manual pause state so it doesn't interfere
	is_manual_paused = false
	_hide_pause_menu() 
	
	# 2. Display the Game Over UI
	wave_label.hide()
	gameover_label.text = "GAME OVER\n" + reason
	gameover_label.show()

	restart_button.visible = not NetworkSession.is_joining_peer()
	main_menu_button.visible = true
	main_menu_button.text = "DISCONNECT" if NetworkSession.is_joining_peer() else "MAIN MENU"

	# 3. Pause the game engine 
	get_tree().paused = true


func _on_resume_button_pressed():
	if NetworkSession.is_joining_peer():
		_hide_joining_peer_menu()
	else:
		_request_host_pause(false)
