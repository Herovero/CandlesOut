extends Control

@onready var back_button: Button = $Center/BackButton


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	back_button.mouse_entered.connect(_on_back_hovered)
	back_button.mouse_exited.connect(_on_back_unhovered)
	back_button.button_down.connect(_on_back_button_down)
	back_button.button_up.connect(_on_back_button_up)

	await get_tree().process_frame
	back_button.pivot_offset = back_button.size * 0.5


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")


func _on_back_hovered() -> void:
	_animate_back_button_scale(Vector2(1.04, 1.04), 0.14)


func _on_back_unhovered() -> void:
	_animate_back_button_scale(Vector2.ONE, 0.14)


func _on_back_button_down() -> void:
	_animate_back_button_scale(Vector2(0.97, 0.97), 0.08)


func _on_back_button_up() -> void:
	_animate_back_button_scale(Vector2(1.04, 1.04), 0.08)


func _animate_back_button_scale(target: Vector2, duration: float) -> void:
	var tween = create_tween()
	tween.tween_property(back_button, "scale", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
