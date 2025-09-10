extends CharacterBody2D

signal player_died

var health: int = 3
var can_move: bool = true  # Controls movement during dialogue
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var freeze_timer: Timer = $FreezeTimer  # Add a Timer node as a child
@onready var guide_label: Label = $GuideLabel  # Add a Label node as a child

func apply_hit() -> void:
	health -= 1
	print("Player hit! Health: %d" % health)
	if health <= 0:
		die()

func die() -> void:
	print("You Died!!")
	Engine.time_scale = 0.5
	collision_shape.queue_free()
	emit_signal("player_died")

# --- Movement Settings ---
@export var speed: float = 200
@export var jump_force: float = 350
@export var gravity: float = 1000
@export var dash_speed: float = 500
@export var dash_time: float = 0.7

# --- Drag your Skeleton2D (or visual root) here in the Inspector ---
@export var flip_node: Node2D

# --- Node References (resolved at runtime) ---
@onready var anim_tree: AnimationTree = $AnimationTree
var state_machine: AnimationNodeStateMachinePlayback

# Picked/Throw
var canPick: bool = true

# --- Dash / Facing ---
var is_dashing := false
var dash_timer := 0.0
var facing_dir := 1  # 1 = right, -1 = left

func _ready() -> void:
	add_to_group("player")  # Ensure Nicole is in the "player" group
	if anim_tree == null:
		push_error("AnimationTree not found at $AnimationTree. Update the path or add one.")
	else:
		anim_tree.active = true
		state_machine = anim_tree["parameters/playback"]
	
	# Auto-detect flip_node if not set in Inspector
	if flip_node == null:
		for node_name in ["Skeleton2D", "Sprite2D", "AnimatedSprite2D"]:
			var node = get_node_or_null(node_name)
			if node is Node2D:
				flip_node = node
				break
		if flip_node == null:
			push_error("Flip node not set/found. Set 'Flip Node' to your Skeleton2D/Sprite2D in the Inspector.")
	
	# Initialize timer and guide label with safety check
	freeze_timer.one_shot = true
	freeze_timer.timeout.connect(_on_freeze_timer_timeout)
	if guide_label != null:
		guide_label.text = "Press Left Arrow to move left or Right Arrow to move right"  # Default text
		guide_label.visible = false
		print("GuideLabel initialized at:", guide_label.global_position)
	else:
		push_error("GuideLabel node not found. Add a Label node named 'GuideLabel' as a child of Nicole.")

func _physics_process(delta: float) -> void:
	if can_move != old_can_move:  # Debug can_move changes
		print("can_move changed to:", can_move, " at frame:", Engine.get_frames_drawn())
		old_can_move = can_move
	if not can_move:
		velocity = Vector2.ZERO  # Stop movement
		if is_on_floor():
			_travel("Idle")  # Force idle animation
		return  # Skip all movement/animation logic

	# Update guide label position to float above Nicole only if needed
	if guide_label != null and guide_label.visible and guide_label.global_position != global_position + Vector2(0, -60):
		guide_label.global_position = global_position + Vector2(0, -60)
		print("Guide repositioned to:", guide_label.global_position)
	# Check input only after delay
	if guide_label != null and guide_label.visible and $GuideInputDelayTimer and $GuideInputDelayTimer.is_stopped():
		if Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("ui_right") or Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("dash"):
			guide_label.visible = false
			print("Floating guide dismissed by player input")

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
		_travel("Jump_D")

	var input_dir := Input.get_axis("ui_left", "ui_right")

	# Dash movement
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
		velocity.x = dash_speed * facing_dir
		_travel("Dash")

	# Duck
	elif Input.is_action_pressed("ui_down") and is_on_floor():
		velocity.x = 0
		_travel("Duck")

	# Run
	elif Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right"):
		velocity.x = input_dir * speed
		_face_direction(input_dir)
		_travel("Run")

	# Idle
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		if is_on_floor():
			_travel("Idle")

	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_force
		_travel("Jump")

	# Melee Idle
	elif Input.is_action_pressed("ui_AttackM") and is_on_floor() and input_dir == 0 and not is_dashing:
		_travel("AttackM_2")

	# Melee Run
	elif Input.is_action_just_pressed("ui_AttackM") and is_on_floor() and input_dir != 0 and not is_dashing:
		_travel("Run_Attack")

	# Melee Air Dash
	elif Input.is_action_pressed("ui_AttackM") and is_dashing:
		_travel("Attack_Air")

	# Melee Air Jump
	elif Input.is_action_just_pressed("ui_AttackM") and not is_on_floor():
		_travel("Attack_Air")

	# Range
	elif Input.is_action_pressed("ui_AttackR") and is_on_floor():
		velocity.x = 0
		_travel("AttackR")

	# Dash start
	if Input.is_action_just_pressed("ui_Dash") and not is_dashing:
		is_dashing = true
		dash_timer = dash_time
		if input_dir != 0.0:
			facing_dir = sign(input_dir)
		velocity.x = dash_speed * facing_dir
		_travel("Dash")

	move_and_slide()

# Handle freeze timer timeout
func _on_freeze_timer_timeout() -> void:
	if get("can_move") != null:
		set("can_move", false)
		print("Freeze timer timed out, set can_move to false for", name)

# Handle dialogue end to show floating guide
func _on_dialogue_ended() -> void:
	if get("can_move") != null:
		set("can_move", true)
		print("Dialogue ended, set can_move to true for", name)
		if guide_label != null:
			guide_label.visible = true
			print("Floating guide displayed above Nicole at:", guide_label.global_position)
			# Add a short delay before allowing input
			if not $GuideInputDelayTimer:
				var timer = Timer.new()
				timer.name = "GuideInputDelayTimer"
				add_child(timer)
			$GuideInputDelayTimer.wait_time = 0.5  # 0.5-second delay
			$GuideInputDelayTimer.one_shot = true
			$GuideInputDelayTimer.start()
		else:
			push_error("GuideLabel is null, cannot display floating guide.")

# --- Animation helper ---
func _travel(state: String) -> void:
	if state_machine != null:
		state_machine.travel(state)

# --- Flip helper ---
func _face_direction(dir: float) -> void:
	if dir < 0 and facing_dir != -1:
		facing_dir = -1
		_set_flip_x(-1)
	elif dir > 0 and facing_dir != 1:
		facing_dir = 1
		_set_flip_x(1)

func _set_flip_x(sign_x: int) -> void:
	if flip_node == null:
		return
	var sx := flip_node.scale.x
	var sy := flip_node.scale.y
	flip_node.scale = Vector2(sign_x * abs(sx if sx != 0.0 else 1.0), sy if sy != 0.0 else 1.0)

# Debug variable to track can_move changes
var old_can_move: bool = true
