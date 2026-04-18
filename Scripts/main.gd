extends Node2D

@onready var gameover_label = $HUDs/gameover_label
@onready var wave_label = $HUDs/wave_label
@onready var huds: CanvasLayer = $HUDs
@onready var restart_button_2 = $HUDs/restart_button2
@onready var paused_label = $HUDs/PauseContainer/paused_label
@onready var restart_button = $HUDs/PauseContainer/restart_button
@onready var resume_button = $HUDs/PauseContainer/resume_button
@onready var main_menu_button = $HUDs/PauseContainer/main_menu_button


@onready var p1 = $Player1
@onready var p2 = $Player2
@onready var p1_effect_label = $HUDs/Player1/EffectLabel
@onready var p1_effect_icon = $HUDs/Player1/EffectIcon
@onready var p2_effect_label = $HUDs/Player2/EffectLabel
@onready var p2_effect_icon = $HUDs/Player2/EffectIcon

const UI_FONT: FontFile = preload("res://Assets/False Earthdream.ttf")
const PAUSE_BLUR_SHADER: Shader = preload("res://Assets/ui_pause_blur.gdshader")

var boss_hp_container: VBoxContainer
var boss_hp_label: Label
var boss_hp_bar: ProgressBar
var phase_overlay: Control
var phase_overlay_bg: ColorRect
var phase_overlay_label: Label

var pause_overlay: Control
var pause_blur_rect: ColorRect
var pause_icon_label: Label

var phase_transition_running: bool = false
var pending_phase_two_refill: bool = false
var is_manual_paused: bool = false


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 1.0
	get_tree().paused = false
	gameover_label.hide()
	_hide_pause_menu()

	p1_effect_icon.visible = false
	p2_effect_icon.visible = false
	p1_effect_label.visible = false
	p2_effect_label.visible = false

	_setup_boss_ui()
	_setup_phase_overlay()
	_setup_pause_overlay()

	SignalBus.connect("game_over", _on_game_over)
	SignalBus.connect("boss_hp_init", _on_boss_hp_init)
	SignalBus.connect("boss_hp_changed", _on_boss_hp_changed)
	SignalBus.connect("boss_phase_two_transition_started", _on_boss_phase_two_transition_started)
	SignalBus.connect("boss_defeated", _on_boss_defeated)

func _input(event):
	# Check for Esc key press
	if event.is_action_pressed("pause"):
		if not get_tree().paused:
			_show_pause_menu()
		else:
			_hide_pause_menu()

func _hide_pause_menu():
	paused_label.hide()
	get_tree().paused = false
	resume_button.hide()
	restart_button.hide()
	main_menu_button.hide()

func _show_pause_menu():
	paused_label.show()
	get_tree().paused = true
	resume_button.show()
	restart_button.show()
	main_menu_button.show()

func _process(_delta):
	check_total_sleep_condition()
	update_effect_ui()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	if not event.is_action_pressed("ui_cancel") or event.is_echo():
		return
	if phase_transition_running:
		return

	toggle_pause()


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
	boss_hp_label.text = "BOSS"
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


func _set_boss_bar_phase_color(is_phase_two: bool) -> void:
	if is_phase_two:
		boss_hp_bar.modulate = Color(0.72, 0.46, 1.0, 1.0)
	else:
		boss_hp_bar.modulate = Color(0.96, 0.24, 0.24, 1.0)


func _on_boss_phase_two_transition_started() -> void:
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
	SignalBus.emit_signal("boss_activate_phase_two")

	phase_overlay.visible = false
	phase_transition_running = false


func _on_boss_defeated() -> void:
	boss_hp_container.visible = false


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


func _on_game_over(_reason: String):
	is_manual_paused = false
	Engine.time_scale = 1.0
	if pause_overlay:
		pause_overlay.visible = false
	wave_label.hide()
	gameover_label.show()
	restart_button.show()
	get_tree().paused = true


func _on_resume_button_pressed():
	_hide_pause_menu()
