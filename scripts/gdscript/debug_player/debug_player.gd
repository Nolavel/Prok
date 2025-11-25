# PlayerController.gd - Enhanced Momentum System
extends CharacterBody3D

# --- Параметры движения ---
@export_group("Movement")
@export var walk_speed := 10.0
@export var sprint_speed := 15.0
@export var jump_velocity := 9.0
@export var acceleration := 10.0
@export var friction := 10.0
@export var air_acceleration := 5.0
@export var air_friction := 2.0

# --- УЛУЧШЕННАЯ СИСТЕМА BUNNY HOP ---
@export_group("Momentum & Bunny Hop")
@export var bunny_hop_enabled := true
@export var momentum_preservation := 0.92  # сохраняем 92% скорости
@export var max_bunny_speed := 25.0        # максимальная скорость от bunny hop
@export var air_strafe_power := 1.8        # сила воздушного стрейфа
@export var pre_speed_cap := 30.0          # лимит скорости до прыжка
@export var landing_speed_bonus := 1.15    # 15% бонус при идеальном приземлении
@export var perfect_landing_window := 0.1  # окно для perfect landing (сек)

@export_group("Camera")
@export var mouse_sensitivity := 0.003
@export var max_look_angle := 90.0 
@export var crouch_height_normal := 1.5
@export var crouch_height_crouched := 0.5
@export var collision_height_ratio := 0.5

@export_group("Arena Settings")
@export var max_air_speed := 15.0
@export var slide_fov_bonus := 20.0
@export var momentum_chain_multiplier := 1.3

@export_group("Lean")
@export var max_lean_angle: float = 25.0
@export var lean_speed: float = 8.0
@export var lean_return_speed: float = 6.0

@export_group("Weapon System")
@export var weapon_holder: Node3D 
@export var weapon_scenes: Array[PackedScene] = []

@export_group("Quick Turn")
@export var quick_turn_enabled := true
@export var turn_duration := 0.8
@export var turn_fov_boost := 25.0


# === ВСЕ ПЕРЕМЕННЫЕ СОСТОЯНИЯ ===
# Momentum система
var momentum_vector := Vector3.ZERO
var last_ground_speed := 0.0
var air_time := 0.0
var perfect_landing_available := false
var consecutive_jumps := 0
var speed_at_jump := 0.0

# Lean система
var current_lean: float = 0.0
var target_lean: float = 0.0

# Weapon система
var current_weapon: Weapon
var current_weapon_index: int = 0

# Quick Turn система
var is_quick_turning := false
var quick_turn_timer := 0.0
var sprint_time := 0.0
var min_sprint_time_for_slide := 1.5
var jump_held := false
var turn_cooldown := 0.0
var turn_cooldown_duration := 1.0



# === СИСТЕМА ЗАРЯЖЕННОГО ПРЫЖКА ===
var jump_charge_time := 0.0  # текущее время зарядки
var jump_charge_max_time := 1.5  # максимальное время зарядки (секунды)
var jump_charge_min_velocity := 9.0  # минимальная высота прыжка (без зарядки)
var jump_charge_max_velocity := 14.0  # максимальная высота прыжка (полная зарядка)
var jump_charge_camera_dip := 0.75  # максимальное опускание камеры
var jump_charge_camera_speed := 8.0  # скорость опускания камеры
var jump_charge_camera_return_speed := 12.0  # скорость возврата камеры
var jump_charge_current_offset := 0.0  # текущее смещение камеры

var jump_timer: Timer
var jump_hud_shown := false

# Основные переменные состояния
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var can_double_jump := false
var is_double_jumping := false
var is_sprinting := false
var landing_timer := 0.0
var previous_floor_state := false
var landing_camera_offset: float = 0.0
var camera_landing_transform: Transform3D
var is_landing_active: bool = false

# Crouch и slide система
var is_crouching := false
var is_sliding := false
var slide_timer := 0.0
var crouch_speed := 4.0
var slide_cooldown := 0.0
var slide_cooldown_duration := 0.3
var crouch_toggled := false
var slide_duration := 2.0
var slide_speed := 25.0
var slide_friction := 8.0
var collision_height_normal: float
var collision_height_crouched: float

var slide_momentum := Vector3.ZERO
var slide_fov_active := false
var slide_camera_roll := 0.0
var slide_direction_x := 0.0
var camera_base_position: Vector3
var dash_visual_offset := Vector3.ZERO
var dash_visual_active := false

# Ссылки на узлы
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera_controller: CameraController = $CameraPivot/CameraPlayer
@onready var ground_check: ShapeCast3D = $GroundCheck
@onready var collision_shape: CollisionShape3D = $CollisionPlayer
#@onready var wall_check_left: ShapeCast3D = $WallCheckLeft
#@onready var wall_check_right: ShapeCast3D = $WallCheckRight

var ammo_frame

func _ready() -> void:
	camera_base_position = camera_pivot.position
	camera_landing_transform = camera_pivot.transform
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_spawn_weapon(0)
	
	if camera_controller:
		camera_controller.player = self
		print("✅ Camera controller connected")
	else:
		push_error("❌ CameraController not found! Check node path.")
		
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule = collision_shape.shape as CapsuleShape3D
		collision_height_normal = capsule.height
		collision_height_crouched = collision_height_normal * collision_height_ratio

func _physics_process(delta: float) -> void:
	_handle_sprint_state()
	_handle_gravity_and_jumps(delta)
	_handle_enhanced_movement(delta)
	_handle_lean(delta)
	_update_camera_states()
	_handle_crouch_state(delta)
	
	if turn_cooldown > 0:
		turn_cooldown -= delta

	move_and_slide()

# === НОВАЯ УЛУЧШЕННАЯ СИСТЕМА ДВИЖЕНИЯ ===
func _handle_enhanced_movement(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var current_speed = sprint_speed if is_sprinting else walk_speed
	var current_accel = acceleration
	var current_friction = friction
	
	if is_crouching:
		current_speed = crouch_speed
	
	# === УЛУЧШЕННОЕ ВОЗДУШНОЕ ДВИЖЕНИЕ ===
	if not is_on_floor():
		air_time += delta
		_handle_air_movement(delta, input_dir, direction)
	else:
		# === УЛУЧШЕННОЕ НАЗЕМНОЕ ДВИЖЕНИЕ ===
		air_time = 0.0
		_handle_ground_movement(delta, direction, current_speed, current_accel, current_friction)

func _handle_air_movement(delta: float, input_dir: Vector2, direction: Vector3) -> void:
	if not bunny_hop_enabled:
		# Обычное воздушное движение
		if direction.length() > 0 and not is_sliding:
			velocity.x = move_toward(velocity.x, direction.x * (sprint_speed if is_sprinting else walk_speed), air_acceleration * delta)
			velocity.z = move_toward(velocity.z, direction.z * (sprint_speed if is_sprinting else walk_speed), air_acceleration * delta)
		return
	
	# === ПРОДВИНУТЫЙ AIR STRAFING ===
	if input_dir.length() > 0.1:
		var wish_dir = direction
		var current_vel = Vector3(velocity.x, 0, velocity.z)
		var current_speed = current_vel.length()
		
		# Проекция текущей скорости на желаемое направление
		var vel_dot_wish = current_vel.dot(wish_dir)
		
		# Air strafing - добавляем скорость перпендикулярно к текущему движению
		var accel_amount = air_acceleration * air_strafe_power * delta
		
		# Ограничиваем ускорение если уже двигаемся быстро в этом направлении
		if vel_dot_wish > 0:
			accel_amount *= max(0.1, 1.0 - (vel_dot_wish / max_air_speed))
		
		# Применяем ускорение
		var new_velocity = current_vel + wish_dir * accel_amount
		
		# Ограничиваем максимальную скорость в воздухе
		if new_velocity.length() > max_air_speed and current_speed < max_air_speed:
			new_velocity = new_velocity.normalized() * max_air_speed
		
		velocity.x = new_velocity.x
		velocity.z = new_velocity.z
		
		# ДЕБАГ для воздушного движения
		if Input.is_action_just_pressed("debug_info"):
			print("🌪️ AIR STRAFE - Speed: %.1f | Dot: %.2f | Accel: %.2f" % [
				current_speed, vel_dot_wish, accel_amount
			])
	
	# Небольшое трение в воздухе для контроля
	var air_drag = 0.98
	velocity.x *= air_drag
	velocity.z *= air_drag

func _handle_ground_movement(delta: float, direction: Vector3, current_speed: float, current_accel: float, current_friction: float) -> void:
	if direction.length() > 0 and not is_sliding:
		var target_vel = direction * current_speed
		var current_horizontal = Vector3(velocity.x, 0, velocity.z)
		
		# === MOMENTUM PRESERVATION ===
		if bunny_hop_enabled and consecutive_jumps > 0:
			# Сохраняем импульс от предыдущих прыжков
			var preserved_speed = last_ground_speed * momentum_preservation
			
			if preserved_speed > current_speed:
				# Смешиваем сохраненную скорость с новым направлением
				var momentum_influence = min(preserved_speed / current_speed, 2.5)  # макс 250% скорости
				target_vel = target_vel * momentum_influence
				
				# Плавный переход направления для сохранения скорости
				var direction_change = direction.dot(momentum_vector.normalized())
				if direction_change > 0.3:  # если направления схожи
					target_vel = momentum_vector.lerp(target_vel, 0.7)
				
				print("🏃 MOMENTUM PRESERVED - Speed: %.1f → %.1f | Jumps: %d" % [
					current_horizontal.length(), target_vel.length(), consecutive_jumps
				])
		
		# Применяем движение
		velocity.x = move_toward(velocity.x, target_vel.x, current_accel * delta)
		velocity.z = move_toward(velocity.z, target_vel.z, current_accel * delta)
		
		# Сохраняем текущую скорость для следующего прыжка
		last_ground_speed = Vector3(velocity.x, 0, velocity.z).length()
		momentum_vector = Vector3(velocity.x, 0, velocity.z)
		
	elif not is_sliding:
		# Применяем трение
		velocity.x = move_toward(velocity.x, 0.0, current_friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, current_friction * delta)
		
		# Сбрасываем счетчик прыжков если остановились
		if Vector3(velocity.x, 0, velocity.z).length() < 1.0:
			consecutive_jumps = 0
			sprint_time = 0.0  # сбрасываем время спринта при остановке

func _handle_crouch_state(delta: float) -> void:
	var crouch_input = Input.is_action_pressed("crouch")

	if crouch_input and not is_crouching:
		_start_crouch()
	elif not crouch_input and is_crouching:
		_stop_crouch()

func _start_crouch() -> void:
	is_crouching = true
	is_sprinting = false  # нельзя спринтовать во время приседа

	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule = collision_shape.shape as CapsuleShape3D
		capsule.height = collision_height_crouched

	# Камера немного опускается
	var tween = get_tree().create_tween()
	tween.tween_property(camera_pivot, "position:y", crouch_height_crouched, 0.15)

func _stop_crouch() -> void:
	# Проверка, можно ли встать (нет ли потолка)
	var space_above = !test_move(transform, Vector3.UP * (collision_height_normal - collision_height_crouched))
	if not space_above:
		return  # не встаём, если сверху препятствие

	is_crouching = false
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule = collision_shape.shape as CapsuleShape3D
		capsule.height = collision_height_normal

	# Камера возвращается обратно
	var tween = get_tree().create_tween()
	tween.tween_property(camera_pivot, "position:y", crouch_height_normal, 0.15)

func _handle_gravity_and_jumps(delta: float) -> void:
	var was_on_floor = previous_floor_state
	var is_on_floor_now = is_on_floor()
	
	# Гравитация
	if not is_on_floor_now:
		velocity.y -= gravity * delta
		velocity.y = max(velocity.y, -25.0)
	
	# Приземление
	if is_on_floor_now and not was_on_floor:
		_handle_landing()
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		_perform_jump()

func _perform_jump() -> void:
	# Сбрасываем время спринта при прыжке
	sprint_time = 0.0
	
	# Сохраняем скорость перед прыжком
	speed_at_jump = Vector3(velocity.x, 0, velocity.z).length()
	
	# Pre-speed: если двигаемся быстро, даем больше высоты
	var jump_height = jump_velocity
	if bunny_hop_enabled and speed_at_jump > sprint_speed:
		var speed_bonus = min((speed_at_jump - sprint_speed) / sprint_speed, 1.0)
		jump_height += speed_bonus * 2.0  # до +2 единиц высоты
		print("🚀 PRE-SPEED JUMP! Speed: %.1f | Bonus height: +%.1f" % [
			speed_at_jump, speed_bonus * 2.0
		])
	
	velocity.y = jump_height
	can_double_jump = true
	consecutive_jumps += 1
	perfect_landing_available = true
	
	if camera_controller:
		camera_controller.add_trauma(0.1)
	
	print("🦘 JUMP #%d | Speed: %.1f" % [consecutive_jumps, speed_at_jump])


func _handle_landing() -> void:
	# Perfect Landing бонус
	if bunny_hop_enabled and perfect_landing_available and consecutive_jumps > 1:
		var current_speed = Vector3(velocity.x, 0, velocity.z).length()
		var bonus_speed = current_speed * (landing_speed_bonus - 1.0)
		
		# Применяем бонус в направлении движения
		if current_speed > 0.1:
			var direction = Vector3(velocity.x, 0, velocity.z).normalized()
			velocity.x += direction.x * bonus_speed
			velocity.z += direction.z * bonus_speed
			
			print("⭐ PERFECT LANDING! Speed: %.1f → %.1f (+%.1f)" % [
				current_speed, Vector3(velocity.x, 0, velocity.z).length(), bonus_speed
			])
			
			if camera_controller:
				# Специальный эффект для perfect landing
				camera_controller.add_trauma(0.2)
				var tween = get_tree().create_tween()
				tween.tween_property(camera_controller, "fov", camera_controller.fov + 5, 0.1)
				tween.tween_property(camera_controller, "fov", camera_controller.fov_normal, 0.3)
	
	perfect_landing_available = false

# === ДЕБАГ ФУНКЦИИ ===
func _print_debug_info() -> void:
	var horizontal_speed = Vector3(velocity.x, 0, velocity.z).length()
	print("=== MOVEMENT DEBUG ===")
	print("🏃 Current Speed: %.1f (%.1f%% of max bunny)" % [
		horizontal_speed, (horizontal_speed / max_bunny_speed) * 100.0
	])
	print("🦘 Consecutive Jumps: %d" % consecutive_jumps)
	print("📊 Last Ground Speed: %.1f" % last_ground_speed)
	print("⏱️ Air Time: %.2f sec" % air_time)
	print("✨ Perfect Landing: %s" % ("✅" if perfect_landing_available else "❌"))
	print("🏠 On Floor: %s | DoubleJump: %s | Sprint: %s" % [
		"✅" if is_on_floor() else "❌",
		"✅" if can_double_jump else "❌",
		"✅" if is_sprinting else "❌"
	])
	print("🎯 Momentum Vector: (%.1f, %.1f)" % [momentum_vector.x, momentum_vector.z])

# === ОСНОВНЫЕ ФУНКЦИИ ===
func _handle_sprint_state() -> void:
	var new_sprint_state = Input.is_action_pressed("sprint")
	if new_sprint_state != is_sprinting:
		is_sprinting = new_sprint_state
		if is_sprinting:
			sprint_time = 0.0  # сбрасываем таймер при начале спринта
		if camera_controller:
			camera_controller.set_sprinting(is_sprinting)
	
	# Обновляем время спринта
	if is_sprinting:
		sprint_time += get_process_delta_time()
	else:
		sprint_time = 0.0  # сбрасываем если не спринтим

func _input(event: InputEvent) -> void:
	# Блокируем мышь во время quick turn
	if is_quick_turning and event is InputEventMouseMotion:
		return
		
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_pivot.rotation_degrees.x = clamp(camera_pivot.rotation_degrees.x, -max_look_angle, max_look_angle)
	
	if not is_landing_active:
				camera_landing_transform = camera_controller.transform
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_switch_weapon(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_switch_weapon(-1)
	
	var s_held = Input.is_action_pressed("move_backward")
	if event.is_action_pressed("jump") and s_held and turn_cooldown <= 0:
		print("TRYING QUICK TURN! (S held + Jump pressed)")
		_try_quick_turn()
		turn_cooldown = turn_cooldown_duration
	
	if event.is_action_pressed("debug_info"):
		_print_debug_info()
		

func _update_camera_states() -> void:
	if not camera_controller:
		return
	camera_controller.set_sprinting(is_sprinting)
	camera_controller.set_aiming(Input.is_action_pressed("aim"))
	camera_controller.set_crouching(is_crouching or is_sliding)

func _check_landing_effects() -> void:
	if not camera_controller:
		return
		
	var was_in_air = not previous_floor_state
	var landed = was_in_air and is_on_floor()
	
	if landed:
		var fall_speed = abs(velocity.y)
		
		if fall_speed > 5.0:
			_create_landing_effect(fall_speed * 0.1)
		elif fall_speed > 15.0:
			_create_landing_effect(fall_speed * 0.15)
		elif is_double_jumping:
			_create_landing_effect(1.4)

func _create_landing_effect(intensity: float) -> void:
	if not camera_controller:
		return
	
	is_landing_active = true
	var drop_amount = intensity * 1.2
	var original_pos = camera_controller.position
	
	var tween = get_tree().create_tween()
	tween.tween_property(camera_controller, "position:y", original_pos.y - drop_amount, 0.08)
	tween.tween_property(camera_controller, "position:y", original_pos.y, 0.4).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(func(): is_landing_active = false)
	
	camera_controller.add_trauma(intensity * 0.5)

func _update_camera_lean(delta: float) -> void:
	# НЕ обновляем lean во время quick turn
	if is_quick_turning:
		return
		
	var can_lean = (not is_sprinting and is_on_floor()) or is_sliding
	
	if can_lean:
		if Input.is_action_pressed("lean_left"):
			target_lean = -max_lean_angle
		elif Input.is_action_pressed("lean_right"):
			target_lean = max_lean_angle
		else:
			target_lean = 0.0
	else:
		target_lean = 0.0
	
	var speed = lean_speed if target_lean != 0.0 else lean_return_speed
	current_lean = lerp(current_lean, target_lean, delta * speed)
	rotation_degrees.z = current_lean


func _switch_weapon(dir: int) -> void:
	if weapon_scenes.is_empty():
		return

	current_weapon_index += dir
	current_weapon_index = clampi(current_weapon_index, 0, weapon_scenes.size() - 1)
	_spawn_weapon(current_weapon_index)

func _spawn_weapon(index: int) -> void:
	if current_weapon:
		if current_weapon.has_method("reset_recoil"):
			current_weapon.reset_recoil()
		current_weapon.queue_free()
	if weapon_scenes.is_empty():
		return
		
	var weapon_instance = weapon_scenes[index].instantiate()
	weapon_holder.add_child(weapon_instance)
	current_weapon = weapon_instance

func get_aim_target() -> Vector3:
	var viewport_center = get_viewport().get_visible_rect().size / 2.0
	var ray_length = 2000.0
	var ray_origin = camera_controller.project_ray_origin(viewport_center)
	var ray_direction = camera_controller.project_ray_normal(viewport_center)
	var ray_end = ray_origin + ray_direction * ray_length
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [self]
	var result = get_world_3d().direct_space_state.intersect_ray(query)
	return result.position if result else ray_end

# === QUICK TURN ФУНКЦИИ ===
func _try_quick_turn() -> void:
	if not quick_turn_enabled or is_quick_turning:
		return
	
	_perform_quick_turn()

func _perform_quick_turn() -> void:
	print("🔄 _perform_quick_turn STARTED")
	
	is_quick_turning = true
	quick_turn_timer = turn_duration
	
	var current_speed = Vector3(velocity.x, 0, velocity.z).length()
	var preserved_momentum = Vector3(velocity.x, 0, velocity.z)
	
	# Определяем направление поворота
	var turn_direction = 1
	
	# === ЭФФЕКТНЫЙ ПОВОРОТ С КРЕНОМ ===
	var start_rotation = rotation_degrees.y
	var overshoot_rotation = start_rotation + (180 + 20) * turn_direction
	var final_rotation = start_rotation + 180 * turn_direction
	
	# Создаем отдельные tween'ы
	var main_tween = get_tree().create_tween()
	var body_tilt_tween = get_tree().create_tween()
	var camera_tween = get_tree().create_tween()
	
	# 1. ПОВОРОТ ТЕЛА (Y-ось) - основной поворот
	main_tween.tween_property(self, "rotation_degrees:y", 
		overshoot_rotation, turn_duration * 0.95).set_trans(Tween.TRANS_CUBIC)
	
	# Возврат к точному углу
	main_tween.tween_property(self, "rotation_degrees:y", 
		final_rotation, turn_duration * 0.35).set_trans(Tween.TRANS_BACK)
	
	# 2. КРЕН ТЕЛА (Z-ось)
	var tilt_amount = 15.0 * turn_direction
	body_tilt_tween.tween_property(self, "rotation_degrees:z", 
		tilt_amount, turn_duration * 0.3).set_trans(Tween.TRANS_CUBIC)
	body_tilt_tween.tween_property(self, "rotation_degrees:z", 
		0.0, turn_duration * 0.7).set_trans(Tween.TRANS_ELASTIC)
	
	# 3. КАМЕРНЫЕ ЭФФЕКТЫ
	if camera_controller:
		var original_fov = camera_controller.fov
		camera_tween.tween_property(camera_controller, "fov", 
			original_fov + turn_fov_boost, turn_duration * 0.4)
		camera_tween.tween_property(camera_controller, "fov", 
			original_fov, turn_duration * 0.6).set_trans(Tween.TRANS_BACK)
		
		camera_controller.add_trauma(0.4)
		
		# Roll камеры (отдельный tween)
		var camera_roll_tween = get_tree().create_tween()
		var camera_roll = -tilt_amount * 0.5
		camera_roll_tween.tween_property(camera_pivot, "rotation_degrees:z", 
			camera_roll, turn_duration * 0.3).set_trans(Tween.TRANS_CUBIC)
		camera_roll_tween.tween_property(camera_pivot, "rotation_degrees:z", 
			0.0, turn_duration * 0.7).set_trans(Tween.TRANS_ELASTIC)
	
	# Финализация - привязываем к основному tween
	main_tween.tween_callback(func(): _finish_quick_turn(preserved_momentum, current_speed))
	
	print("🔄 Эффектный поворот: %d° → %d° → %d°" % [start_rotation, overshoot_rotation, final_rotation])


func _handle_lean(delta: float) -> void:
	var lean_left = Input.is_action_pressed("lean_left")
	var lean_right = Input.is_action_pressed("lean_right")

	if lean_left and not lean_right:
		target_lean = max_lean_angle   # наклон влево
	elif lean_right and not lean_left:
		target_lean = -max_lean_angle    # наклон вправо
	else:
		target_lean = 0.0               # возвращаемся в центр

	# плавный переход к нужному углу
	current_lean = lerp(current_lean, target_lean, delta * (lean_speed if target_lean != 0 else lean_return_speed))

	# применяем наклон к камере
	if camera_pivot:
		camera_pivot.rotation_degrees.z = current_lean


func _finish_quick_turn(original_momentum: Vector3, original_speed: float) -> void:
	print("🔄 TURN FINISHED - Final rotation: %.1f" % rotation_degrees.y)
	is_quick_turning = false
	rotation_degrees.z = 0.0
	
	if bunny_hop_enabled and original_speed > 5.0:
		var new_momentum = -original_momentum
		velocity.x = new_momentum.x
		velocity.z = new_momentum.z
		momentum_vector = new_momentum
		last_ground_speed = original_speed
		print("🔄 Momentum reversed: %.1f" % original_speed)

# === ФУНКЦИИ ДЛЯ UI И СТАТИСТИКИ ===
func get_horizontal_speed() -> float:
	return Vector3(velocity.x, 0, velocity.z).length()

func get_total_speed() -> float:
	return velocity.length()

func get_momentum_info() -> Dictionary:
	return {
		"current_speed": get_horizontal_speed(),
		"last_ground_speed": last_ground_speed,
		"consecutive_jumps": consecutive_jumps,
		"air_time": air_time,
		"perfect_landing_available": perfect_landing_available,
		"momentum_vector": momentum_vector,
		"speed_percentage": (get_horizontal_speed() / max_bunny_speed) * 100.0
	}

# === ФУНКЦИИ ДЛЯ НАСТРОЙКИ И БАЛАНСИРОВКИ ===
func set_bunny_hop_settings(enabled: bool, preservation: float = 0.92, max_speed: float = 25.0) -> void:
	bunny_hop_enabled = enabled
	momentum_preservation = preservation
	max_bunny_speed = max_speed
	print("🐰 Bunny hop settings updated: Enabled=%s, Preservation=%.2f, Max Speed=%.1f" % [
		enabled, preservation, max_speed
	])

func reset_momentum() -> void:
	"""Сбрасывает всю накопленную скорость (для респавна или телепортации)"""
	momentum_vector = Vector3.ZERO
	last_ground_speed = 0.0
	consecutive_jumps = 0
	perfect_landing_available = false
	air_time = 0.0
	print("🔄 Momentum reset")

func add_speed_boost(boost_amount: float, duration: float = 0.0) -> void:
	"""Добавляет временный буст скорости"""
	var current_horizontal = Vector3(velocity.x, 0, velocity.z)
	if current_horizontal.length() > 0.1:
		var boost_direction = current_horizontal.normalized()
		velocity.x += boost_direction.x * boost_amount
		velocity.z += boost_direction.z * boost_amount
		
		# Обновляем momentum систему
		momentum_vector = Vector3(velocity.x, 0, velocity.z)
		last_ground_speed = momentum_vector.length()
		
		print("⚡ Speed boost: +%.1f | New speed: %.1f" % [
			boost_amount, Vector3(velocity.x, 0, velocity.z).length()
		])
		
		# Временный буст с автоматическим снижением
		if duration > 0.0:
			var tween = get_tree().create_tween()
			tween.tween_delay(duration)
			tween.tween_callback(func(): _apply_speed_reduction(boost_amount))

func _apply_speed_reduction(reduction: float) -> void:
	var current_horizontal = Vector3(velocity.x, 0, velocity.z)
	var current_speed = current_horizontal.length()
	
	if current_speed > reduction:
		var reduction_factor = max(0.1, (current_speed - reduction) / current_speed)
		velocity.x *= reduction_factor
		velocity.z *= reduction_factor
		print("⬇️ Speed boost expired: %.1f → %.1f" % [
			current_speed, Vector3(velocity.x, 0, velocity.z).length()
		])

# === СОБЫТИЯ ДЛЯ ИНТЕГРАЦИИ С ДРУГИМИ СИСТЕМАМИ ===
signal momentum_gained(speed: float, jumps: int)
@warning_ignore("unused_signal")
signal perfect_landing_achieved(speed_bonus: float)
signal speed_threshold_reached(speed: float, threshold_name: String)

func _emit_momentum_events() -> void:
	"""Вызывается при значительных изменениях скорости"""
	var current_speed = get_horizontal_speed()
	
	# Эмитим события для достижения определенных скоростей
	if current_speed > sprint_speed * 1.5 and consecutive_jumps >= 3:
		momentum_gained.emit(current_speed, consecutive_jumps)
	
	# Пороги скорости для достижений/эффектов
	if current_speed > max_bunny_speed * 0.8:
		speed_threshold_reached.emit(current_speed, "high_speed")
	elif current_speed > max_bunny_speed * 0.6:
		speed_threshold_reached.emit(current_speed, "medium_speed")

# === ДОПОЛНИТЕЛЬНЫЕ УТИЛИТЫ ===
func is_bunny_hopping() -> bool:
	"""Проверяет, активно ли bunny hopping"""
	return bunny_hop_enabled and consecutive_jumps >= 2 and get_horizontal_speed() > sprint_speed * 1.2

func get_movement_style() -> String:
	"""Возвращает текущий стиль движения для UI/статистики"""
	if is_sliding:
		return "sliding"
	elif is_bunny_hopping():
		return "bunny_hopping"
	elif not is_on_floor() and air_time > 0.5:
		return "air_strafing"
	elif is_sprinting:
		return "sprinting"
	elif is_crouching:
		return "crouching"
	else:
		return "walking"

func get_speed_rating() -> String:
	"""Возвращает рейтинг текущей скорости"""
	var speed_percent = (get_horizontal_speed() / max_bunny_speed) * 100.0
	
	if speed_percent >= 90:
		return "INSANE"
	elif speed_percent >= 75:
		return "EXTREME"
	elif speed_percent >= 60:
		return "HIGH"
	elif speed_percent >= 40:
		return "MEDIUM"
	elif speed_percent >= 20:
		return "LOW"
	else:
		return "SLOW"

func get_current_lean() -> float:
	"""Возвращает текущий угол lean для камеры"""
	return current_lean

func _horizontal_speed() -> float:
	return Vector3(velocity.x, 0.0, velocity.z).length()
