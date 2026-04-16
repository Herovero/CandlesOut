extends CharacterBody2D

@export var input_prefix: String = "p1_"
@export var speed: float = 150.0

# Stamina Variables
@export var max_stamina: float = 100.0
var current_stamina: float = 100.0
@export var depletion_rate: float = 10.0  # Per second while moving
@export var recharge_rate: float = 5.0   # Per second while standing/sleeping

var is_sleeping: bool = false

@onready var stamina_bar = $Stats/StaminaBar

func _ready():
	stamina_bar.max_value = max_stamina
	stamina_bar.value = max_stamina

func _physics_process(delta: float) -> void:
	if is_sleeping:
		handle_sleep(delta)
		return

	var direction = Input.get_vector(
		input_prefix + "move_left", input_prefix + "move_right",
		input_prefix + "move_up", input_prefix + "move_down"
	)

	if direction != Vector2.ZERO:
		velocity = direction * speed
		consume_stamina(delta)
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	update_ui()

func consume_stamina(delta):
	current_stamina -= depletion_rate * delta
	if current_stamina <= 0:
		current_stamina = 0
		enter_sleep()

func recharge_stamina(delta):
	current_stamina += recharge_rate * delta
	current_stamina = min(current_stamina, max_stamina)

func enter_sleep():
	is_sleeping = true
	velocity = Vector2.ZERO
	modulate = Color(0.5, 0.5, 1.0) # Turn slightly blue/dark to show sleeping

func handle_sleep(delta):
	current_stamina += recharge_rate * delta # Maybe recharge faster when forced?
	update_ui()
	
	if current_stamina >= max_stamina:
		current_stamina = max_stamina
		is_sleeping = false
		modulate = Color(1, 1, 1) # Back to normal

func update_ui():
	stamina_bar.value = current_stamina

func die():
	print_debug("player died")
