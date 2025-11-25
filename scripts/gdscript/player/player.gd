extends CharacterBody3D

# --- Movement Parameters ---
@export_group("Movement")
@export var walk_speed: float = 5.0
@export var run_speed: float = 10.0
@export var accel_time: float = 0.55
@export var decel_time: float = 0.8

@export_group("Jump/Gravity")
@export var jump_force: float = 8.0
@export var gravity: float = 20.0

# --- Components ---
@onready var navigation_component: NavigationComponent = $NavComponent
@onready var stamina_manager: StaminaManager = $StaminaManager

# --- Movement State ---
enum MovementState { IDLE, WALKING, RUNNING, DECELERATING }
var current_state: MovementState = MovementState.IDLE
var speed: float = 0.0
var target_speed: float = 0.0
var movement_enabled: bool = true

# --- Sprint State (для UI курсора) ---
var is_running_mode: bool = false
var wants_to_run: bool = false  # 🔥 НОВЫЙ: игрок хочет бежать (даже если не может)
var sprint_blend: float = 0.0
var sprint_blend_speed: float = 4.0

# --- Signals ---
signal movement_started
signal movement_stopped
signal state_changed(new_state: MovementState)

# --- Initialization ---
func _ready():
	$player_base_mesh/AnimationPlayer.play("new4/idle")
	if navigation_component:
		navigation_component.path_updated.connect(_on_path_updated)
		navigation_component.destination_reached.connect(_on_destination_reached)
	else:
		push_warning("NavigationComponent not found - direct movement only")
	
	if stamina_manager == null:
		push_warning("StaminaManager not found - stamina system will not work")

# --- Public API ---
func move_to_position(pos: Vector3) -> void:
	if not movement_enabled:
		print("⚠️ Player: Движение заблокировано, игнорируем move_to_position()")
		return
	
	if navigation_component:
		navigation_component.set_target_position(pos)

func set_movement_speed(new_speed: float) -> void:
	if not movement_enabled:
		return
	
	target_speed = clamp(new_speed, 0.0, run_speed)
	
	# 🔥 Запоминаем, что игрок ХОЧЕТ бежать (даже если не может)
	wants_to_run = (new_speed > walk_speed * 1.1)
	
	# Определяем режим бега по скорости
	is_running_mode = wants_to_run
	
	_update_state()

func stop_moving(smooth: bool = true) -> void:
	if navigation_component:
		navigation_component.clear_path()
	
	is_running_mode = false
	wants_to_run = false  # 🔥
	
	if smooth:
		target_speed = 0.0
		_change_state(MovementState.DECELERATING)
		$player_base_mesh/AnimationPlayer.play("new4/walk")
	else:
		target_speed = 0.0
		speed = 0.0
		_change_state(MovementState.IDLE)
		$player_base_mesh/AnimationPlayer.play("new4/idle")
	
	emit_signal("movement_stopped")

func is_moving() -> bool:
	return current_state != MovementState.IDLE

# 🔥 СИСТЕМА БЛОКИРОВКИ ДВИЖЕНИЯ
func set_movement_enabled(enabled: bool):
	movement_enabled = enabled
	
	if not enabled:
		velocity = Vector3.ZERO
		speed = 0.0
		target_speed = 0.0
		is_running_mode = false
		wants_to_run = false  # 🔥
		
		if navigation_component:
			navigation_component.clear_path()
		
		if stamina_manager:
			stamina_manager.stop_consuming_stamina()
		
		if current_state != MovementState.IDLE:
			_change_state(MovementState.IDLE)
			$player_base_mesh/AnimationPlayer.play("new4/idle")
		
		print("🔒 Player: Движение ЗАБЛОКИРОВАНО")
	else:
		print("✅ Player: Движение РАЗБЛОКИРОВАНО")

func is_movement_enabled() -> bool:
	return movement_enabled

# === МЕТОДЫ ДЛЯ КУРСОРА (совместимость с MouseCursorUI) ===

## Проверяет, находится ли игрок в спринте (беге)
func is_currently_sprinting(current_velocity: Vector3) -> bool:
	if not movement_enabled:
		return false
	
	var horizontal_speed = Vector2(current_velocity.x, current_velocity.z).length()
	return is_running_mode and horizontal_speed > walk_speed * 1.2

## Возвращает прогресс спринта (0.0 - 1.0)
func get_sprint_blend() -> float:
	return sprint_blend

## 🔥 НОВЫЙ: Проверяет, хочет ли игрок бежать (независимо от стамины)
func is_wanting_to_run() -> bool:
	return wants_to_run

# --- Physics Update ---
func _physics_process(delta: float) -> void:
	if not movement_enabled:
		_apply_gravity(delta)
		move_and_slide()
		return
	
	_update_sprint_blend(delta)
	_handle_stamina_consumption()
	_handle_jump()
	_apply_gravity(delta)
	_update_speed(delta)
	_handle_navigation(delta)
	_apply_deceleration(delta)
	
	move_and_slide()

# --- Sprint Blend (для плавной UI анимации) ---
func _update_sprint_blend(delta: float) -> void:
	var target_blend = 1.0 if is_running_mode else 0.0
	sprint_blend = lerp(sprint_blend, target_blend, sprint_blend_speed * delta)

# --- Stamina Consumption (расход стамины при беге) ---
func _handle_stamina_consumption() -> void:
	if not stamina_manager:
		return
	
	var can_run = stamina_manager.is_sprint_allowed()
	
	if is_running_mode and is_moving():
		if can_run:
			if not stamina_manager.is_consuming_stamina:
				stamina_manager.start_consuming_stamina()
		else:
			# Стамина кончилась - принудительно переходим на ходьбу
			if stamina_manager.is_consuming_stamina:
				stamina_manager.stop_consuming_stamina()
			
			# 🔥 ВАЖНО: Снижаем РЕАЛЬНУЮ скорость, но НЕ сбрасываем wants_to_run
			target_speed = walk_speed
			is_running_mode = false
			print("⚠️ Стамина истощена - переход на ходьбу")
	else:
		if stamina_manager.is_consuming_stamina:
			stamina_manager.stop_consuming_stamina()

# --- Jump Logic ---
func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		if stamina_manager and stamina_manager.try_jump():
			velocity.y = jump_force
		elif not stamina_manager:
			velocity.y = jump_force

# --- Gravity ---
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

# --- Speed Interpolation ---
func _update_speed(delta: float) -> void:
	var acceleration = (run_speed - walk_speed) / accel_time
	speed = move_toward(speed, target_speed, delta * acceleration)

# --- Navigation Movement ---
func _handle_navigation(delta: float) -> void:
	if not navigation_component or not navigation_component.has_active_path():
		return
	
	var next_point = navigation_component.get_next_point()
	if next_point == Vector3.ZERO:
		return
	
	var direction = next_point - global_position
	direction.y = 0.0
	var distance = direction.length()
	
	if distance > 0.15:
		var normalized_dir = direction / distance
		velocity.x = normalized_dir.x * speed
		velocity.z = normalized_dir.z * speed
		
		if distance > 0.01:
			var target_angle = atan2(normalized_dir.x, normalized_dir.z)
			rotation.y = lerp_angle(rotation.y, target_angle, delta * 10.0)
	else:
		navigation_component.advance_path()

# --- Deceleration when not navigating ---
func _apply_deceleration(delta: float) -> void:
	if navigation_component and navigation_component.has_active_path():
		return
	
	if speed > 0.1:
		var decel_rate = run_speed / decel_time
		velocity.x = move_toward(velocity.x, 0.0, delta * decel_rate)
		velocity.z = move_toward(velocity.z, 0.0, delta * decel_rate)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if current_state != MovementState.IDLE:
			_change_state(MovementState.IDLE)
			$player_base_mesh/AnimationPlayer.play("new4/idle")

# --- State Management ---
func _update_state() -> void:
	var new_state: MovementState
	
	if not navigation_component or not navigation_component.has_active_path():
		new_state = MovementState.DECELERATING if speed > 0.1 else MovementState.IDLE
	elif is_running_mode:
		new_state = MovementState.RUNNING
		$player_base_mesh/AnimationPlayer.play("new4/root-sneak-run-s")
	elif target_speed > walk_speed + 0.1:
		new_state = MovementState.RUNNING
		$player_base_mesh/AnimationPlayer.play("new4/root-sneak-run-s")
	else:
		new_state = MovementState.WALKING
		$player_base_mesh/AnimationPlayer.play("new4/root-sneak-walk")
	
	if new_state != current_state:
		_change_state(new_state)

func _change_state(new_state: MovementState) -> void:
	current_state = new_state
	emit_signal("state_changed", new_state)

# --- Navigation Callbacks ---
func _on_path_updated() -> void:
	if not movement_enabled:
		return
	
	if navigation_component.has_active_path():
		emit_signal("movement_started")
		_update_state()

func _on_destination_reached() -> void:
	stop_moving(true)

# --- Getters ---
func get_current_speed() -> float:
	return speed

func get_state_name() -> String:
	if not movement_enabled:
		return "заблокирован"
	
	match current_state:
		MovementState.IDLE: return "не движется"
		MovementState.WALKING: return "идёт"
		MovementState.RUNNING: return "бежит"
		MovementState.DECELERATING: return "тормозит"
		_: return "неизвестно"
