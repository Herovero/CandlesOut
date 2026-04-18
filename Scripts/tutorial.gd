extends Control

const TUTORIAL_PAGES := [
	{
		"section_a_title": "Controls",
		"section_a_body": "Player 1 Move - WASD\nPlayer 2 Move - Arrow Keys\nPick Up Items - Space",
		"section_b_title": "Objective",
		"section_b_body": "Survive enemy waves together. Don't lose to the CHAOS.\nPass items, manage stamina, protect sleeping teammates.\nDefeat the final boss."
	},
	{
		"section_a_title": "Effect",
		"section_a_body": "Heart — Restores 1 heart point\nCoffee — Restores 50% stamina\nLighter — Swaps player and ghost\nShoe — Get a speed boost\nShield — Player immune to damage\nOil — Get a triple-shot gun\nBomb — Get a MASSIVE explosion",
		"section_b_title": "Chaos Effect",
		"section_b_body": "Heart — None\nCoffee — None\nLighter — None\nShoe — Did a hedgehog wear this?\nShield — Can't Touch Grass\nOil — Inverted Minigun brrr\nBomb — Why is it Flying?"
	}
]

@onready var controls_title: Label = $Center/TutorialCard/Margin/Content/LeftColumn/ControlsTitle
@onready var controls_body: Label = $Center/TutorialCard/Margin/Content/LeftColumn/ControlsBody
@onready var objective_title: Label = $Center/TutorialCard/Margin/Content/RightColumn/ObjectiveTitle
@onready var objective_body: Label = $Center/TutorialCard/Margin/Content/RightColumn/ObjectiveBody
@onready var page_label: Label = $Center/PageNav/PageLabel
@onready var prev_button: Button = $Center/PageNav/PrevButton
@onready var next_button: Button = $Center/PageNav/NextButton
@onready var back_button: Button = $Center/BackButton

var current_page: int = 0


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)

	_bind_button_feedback(back_button)
	_bind_button_feedback(prev_button)
	_bind_button_feedback(next_button)

	await get_tree().process_frame
	back_button.pivot_offset = back_button.size * 0.5
	prev_button.pivot_offset = prev_button.size * 0.5
	next_button.pivot_offset = next_button.size * 0.5

	_update_page()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		return
	if event.is_action_pressed("ui_left"):
		_on_prev_pressed()
		return
	if event.is_action_pressed("ui_right"):
		_on_next_pressed()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")


func _on_prev_pressed() -> void:
	current_page = posmod(current_page - 1, TUTORIAL_PAGES.size())
	_update_page()


func _on_next_pressed() -> void:
	current_page = posmod(current_page + 1, TUTORIAL_PAGES.size())
	_update_page()


func _update_page() -> void:
	var page = TUTORIAL_PAGES[current_page]
	controls_title.text = page["section_a_title"]
	controls_body.text = page["section_a_body"]
	objective_title.text = page["section_b_title"]
	objective_body.text = page["section_b_body"]

	controls_title.visible = controls_title.text.strip_edges() != ""
	objective_title.visible = objective_title.text.strip_edges() != ""

	page_label.text = "%d / %d" % [current_page + 1, TUTORIAL_PAGES.size()]


func _bind_button_feedback(button: Button) -> void:
	button.mouse_entered.connect(func() -> void:
		_animate_button_scale(button, Vector2(1.04, 1.04), 0.14)
	)
	button.mouse_exited.connect(func() -> void:
		_animate_button_scale(button, Vector2.ONE, 0.14)
	)
	button.button_down.connect(func() -> void:
		_animate_button_scale(button, Vector2(0.97, 0.97), 0.08)
	)
	button.button_up.connect(func() -> void:
		_animate_button_scale(button, Vector2(1.04, 1.04), 0.08)
	)


func _animate_button_scale(button: Button, target: Vector2, duration: float) -> void:
	var tween = create_tween()
	tween.tween_property(button, "scale", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
