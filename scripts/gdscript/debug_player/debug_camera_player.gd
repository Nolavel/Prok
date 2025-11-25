extends Camera3D
class_name CameraController

@export_group("FOV Settings")
@export var fov_normal := 90.0
@export var fov_sprint := 110.0
@export var fov_aim := 60.0
@export var fov_jump := 105.0
@export var fov_transition_speed := 8.0

@export_group("Head Bob (Camera)")
@export var head_bob_enabled := true
@export var head_bob_frequency := 1.2
@export var head_bob_amplitude := 0.06
@export var walk_bob_speed := 1.0
@export var sprint_bob_speed := 1.2
@export var crouch_bob_speed := 0.6

@export_group("Landing Impact")
@export var landing_impact_strength := 0.3
@export var landing_fov_punch := 5.0

@export_group("ADS Settings")
@export var ads_position_offset: Vector3 = Vector3(-0.301, 0.15, 0.2)  
@export var ads_rotation_offset: Vector3 = Vector3(0, 0, 0)
@export var ads_transition_speed: float = 10.0

@export_group("Weapon Lean")
@export var weapon_lean_enabled := true
@export var weapon_lean_amount := 15.0
@export var weapon_lean_speed := 8.0
@export var weapon_lean_smoothness := 6.0

@export_group("Camera Shake")
@export var camera_shake_decay := 5.0

@export_group("Jump Camera Effects")
@export var jump_charge_enabled := true
@export var jump_charge_amount := 0.08  # насколько опускается камера при зажатии
@export var jump_charge_speed := 15.0   # скорость опускания
@export var jump_release_speed := 12.0  # скорость возврата после отпускания

@export_group("Weapon Sway")
@export var sway_amount := 0.003
@export var sway_smoothness := 6.0
@export var max_sway_rotation := 2.0
@export var sway_enabled := true

@export_group("Weapon Bob")
@export var weapon_position_offset: Vector3 = Vector3.ZERO
@export var weapon_bob_frequency := 2.0
@export var weapon_bob_amplitude := 0.02
@export var weapon_bob_variance := 0.5

@export_group("Look Limits")
@export var max_look_angle := 80.0

@export_group("Air Movement")
@export var air_bob_reduction := 0.3
@export var air_sway_increase := 1.5

@export_group("Weapon Recoil")
@export_enum("Light", "Medium", "Heavy") var recoil_mode: int = 0
@export var recoil_recovery_speed: float = 8.0
@export var recoil_recovery_delay: float = 0.2

@export_group("Competitive Settings")
@export var disable_all_effects := false
@export var minimal_effects := false

# Runtime state
var is_sprinting := false
var is_aiming := false
var is_crouching := false
var is_jumping := false
var was_in_air := false
var head_bob_timer := 0.0
var weapon_bob_timer := 0.0
var camera_shake := 0.0
var previous_velocity_y := 0.0
var sway_rotation := Vector3.ZERO
var weapon_base_rotation := Vector3.ZERO
var weapon_base_position := Vector3.ZERO
var original_camera_position: Vector3
var jump_fov_active := false
var camera_pivot_offset_y: float = 0.0

# Weapon lean система
var current_weapon_lean_rotation := Vector3.ZERO

# Система отдачи
var accumulated_recoil := Vector2.ZERO
var recoil_recovery_timer := 0.0

# Jump charge система (заменяет jump nod)
var jump_charge_active := false
var current_jump_charge_offset := 0.0
var jump_key_pressed := false
var jump_performed := false  # флаг что прыжок уже выполнен


# References
var player: CharacterBody3D
var camera_pivot: Node3D
var weapon_holder: Node3D

@export var weapon_camera: Camera3D

var landing_recovery := false
var landing_target_y := 0.0
var landing_recovery_speed := 2.5
var landing_drop_phase := false
var landing_rise_phase := false
var landing_timer := 0.0
var current_landing_offset := 0.0
var idle_sway_timer := 0.0
var initialization_frames := 0
var min_fall_speed_y: float = 0.0
var had_real_air: bool = false
var impact_strength: float = 0.0

func _ready() -> void:
	camera_pivot = get_parent()
	player = camera_pivot.get_parent()
	weapon_holder = camera_pivot.get_node("weapon_holder")
	original_camera_position = position
	weapon_base_rotation = weapon_holder.rotation_degrees
	weapon_base_position = weapon_holder.position + weapon_position_offset
	fov = fov_normal
	previous_velocity_y = player.velocity.y

func _process(delta: float) -> void:
	initialization_frames += 1
	
	if weapon_camera:
		weapon_camera.global_transform = global_transform

	if disable_all_effects:
		position = original_camera_position
		if weapon_holder:
			weapon_holder.position = weapon_base_position
			weapon_holder.rotation_degrees = weapon_base_rotation
		return

	_check_landing_impact(delta)
	_update_fov(delta)
	_handle_air_movement()
	_handle_jump_charge_effects(delta)  # новая функция для эффекта присядания
	_update_recoil_recovery(delta)

	var final_position := original_camera_position
	
	# Jump charge effect - применяется всегда
	if jump_charge_enabled:
		final_position.y += current_jump_charge_offset
	
	if not minimal_effects:
		var horizontal_velocity = Vector3(player.velocity.x, 0, player.velocity.z).length()
		if not landing_drop_phase and not landing_rise_phase:
			final_position += _get_head_bob_offset(delta, horizontal_velocity)
		
		final_position.y += _update_landing_effect(delta)
		final_position += _get_shake_offset(delta)
		
		if sway_enabled:
			_apply_weapon_sway(delta)
		_apply_weapon_bob(delta, horizontal_velocity)
	
	position = final_position
	_limit_look_angle()

func _update_fov(delta: float) -> void:
	var target_fov := fov_normal
	
	if jump_fov_active:
		target_fov = fov_jump
	elif is_aiming:
		target_fov = fov_aim
	elif is_sprinting:
		target_fov = fov_sprint
	
	fov = lerp(fov, target_fov, fov_transition_speed * delta)

func _handle_air_movement() -> void:
	var was_on_floor = not was_in_air
	var is_on_floor = player.is_on_floor()

	if was_on_floor and not is_on_floor:
		is_jumping = player.velocity.y > 5
		jump_fov_active = is_jumping
		min_fall_speed_y = 0.0
		had_real_air = true

	if not is_on_floor:
		min_fall_speed_y = min(min_fall_speed_y, player.velocity.y)
	else:
		if player.velocity.y < 1.0:
			is_jumping = false
			jump_fov_active = false

	was_in_air = not is_on_floor

func _handle_jump_charge_effects(delta: float) -> void:
	if not jump_charge_enabled:
		return
	
	# Отслеживаем состояние кнопки прыжка
	var jump_pressed = Input.is_action_pressed("jump")
	
	# На земле и зажали прыжок - активируем присядание
	if jump_pressed and player.is_on_floor() and not jump_performed:
		jump_charge_active = true
		# Опускаем камеру вниз
		var target_offset = jump_charge_amount
		current_jump_charge_offset = lerp(current_jump_charge_offset, target_offset, delta * jump_charge_speed)
	
	# Отпустили прыжок - возвращаем камеру
	elif not jump_pressed or not player.is_on_floor():
		if jump_charge_active:
			jump_charge_active = false
			jump_performed = true  # помечаем что прыжок выполнен
		
		# Плавно возвращаем камеру на место
		current_jump_charge_offset = lerp(current_jump_charge_offset, 0.0, delta * jump_release_speed)
		
		# Сбрасываем флаг когда камера вернулась и мы на земле
		if abs(current_jump_charge_offset) < 0.001 and player.is_on_floor():
			jump_performed = false

func _apply_weapon_sway(delta: float) -> void:
	if not weapon_holder:
		return
	
	var mouse_delta = Input.get_last_mouse_velocity() * 0.001
	var sway_multiplier := 1.0
	
	if not player.is_on_floor():
		sway_multiplier = air_sway_increase
	
	var target_sway = Vector3(
		clamp(mouse_delta.y * sway_amount * sway_multiplier, -max_sway_rotation, max_sway_rotation),
		clamp(-mouse_delta.x * sway_amount * sway_multiplier, -max_sway_rotation, max_sway_rotation),
		clamp(mouse_delta.x * sway_amount * 0.5, -max_sway_rotation * 0.5, max_sway_rotation * 0.5)
	)
	
	sway_rotation = sway_rotation.lerp(target_sway, sway_smoothness * delta)
	
	var lean_rotation = Vector3.ZERO
	if weapon_lean_enabled and player and player.has_method("get_current_lean"):
		var player_lean = player.get_current_lean()
		lean_rotation.x = -player_lean * (weapon_lean_amount / 25.0)
	
	weapon_holder.rotation_degrees = weapon_base_rotation + sway_rotation + lean_rotation

func _set_landing_fov(value: float) -> void:
	if not jump_fov_active:
		fov = value

func _limit_look_angle() -> void:
	var rot = camera_pivot.rotation
	rot.x = clamp(rot.x, deg_to_rad(-max_look_angle), deg_to_rad(max_look_angle))
	camera_pivot.rotation = rot

func add_trauma(amount: float) -> void:
	if not disable_all_effects and not minimal_effects:
		camera_shake = min(camera_shake + amount, 1.0)

func set_sprinting(value: bool) -> void:
	is_sprinting = value

func set_aiming(value: bool) -> void:
	is_aiming = value

func set_crouching(value: bool) -> void:
	is_crouching = value

func apply_recoil(strength: Vector2) -> void:
	if disable_all_effects:
		return
	
	var rot = camera_pivot.rotation
	rot.x += deg_to_rad(strength.y)
	rot.y += deg_to_rad(strength.x)
	camera_pivot.rotation = rot
	
	accumulated_recoil += strength
	recoil_recovery_timer = recoil_recovery_delay

func _update_recoil_recovery(delta: float) -> void:
	recoil_recovery_timer -= delta
	
	if recoil_recovery_timer <= 0.0 and accumulated_recoil.length() > 0.1:
		match recoil_mode:
			0:  # Light
				var recovery_amount = accumulated_recoil * recoil_recovery_speed * delta
				camera_pivot.rotation.x -= deg_to_rad(recovery_amount.y)
				camera_pivot.rotation.y -= deg_to_rad(recovery_amount.x)
				accumulated_recoil = accumulated_recoil.lerp(Vector2.ZERO, recoil_recovery_speed * delta)
			1:  # Medium
				var recovery_amount = accumulated_recoil * recoil_recovery_speed * 0.4 * delta
				camera_pivot.rotation.x -= deg_to_rad(recovery_amount.y)
				camera_pivot.rotation.y -= deg_to_rad(recovery_amount.x)
				accumulated_recoil = accumulated_recoil.lerp(Vector2.ZERO, recoil_recovery_speed * 0.4 * delta)
			2:  # Heavy
				pass

func reset_recoil() -> void:
	accumulated_recoil = Vector2.ZERO
	recoil_recovery_timer = 0.0

func set_recoil_mode(mode: int) -> void:
	recoil_mode = clamp(mode, 0, 2)

func set_jump_fov_active(value: bool) -> void:
	jump_fov_active = value

func enable_competitive_mode() -> void:
	disable_all_effects = true
	reset_recoil()
	fov = 90.0

func enable_minimal_mode() -> void:
	minimal_effects = true
	sway_enabled = false
	head_bob_amplitude *= 0.5
	weapon_bob_amplitude *= 0.3
	reset_recoil()

func apply_speed_fov(speed: float, max_speed: float = 12.0) -> void:
	if disable_all_effects:
		return
	var speed_ratio = clamp(speed / max_speed, 0.0, 1.0)
	var speed_fov_bonus = speed_ratio * 10.0
	if not jump_fov_active and not is_aiming:
		fov = lerp(fov, fov_normal + speed_fov_bonus, 5.0 * get_process_delta_time())

func create_impact_effect(intensity: float) -> void:
	add_trauma(intensity)

func _screen_punch(amount: float) -> void:
	if not disable_all_effects:
		position.x = original_camera_position.x + randf_range(-amount, amount) * 0.01
		position.z = original_camera_position.z + randf_range(-amount, amount) * 0.01

func _get_head_bob_offset(delta: float, horizontal_velocity: float) -> Vector3:
	if not head_bob_enabled or not player:
		return Vector3.ZERO
	
	var velocity_factor = smoothstep(0.1, 1.0, horizontal_velocity)
	
	if player.is_on_floor() and velocity_factor > 0.01:
		var speed_multiplier := walk_bob_speed
		if is_sprinting:
			speed_multiplier = sprint_bob_speed
		elif is_crouching:
			speed_multiplier = crouch_bob_speed
		
		head_bob_timer += delta * head_bob_frequency * speed_multiplier * velocity_factor
		
		return Vector3(
			cos(head_bob_timer) * head_bob_amplitude * 0.3 * velocity_factor,
			sin(head_bob_timer * 2) * head_bob_amplitude * velocity_factor,
			sin(head_bob_timer * 1.5) * head_bob_amplitude * 0.2 * velocity_factor
		) 
	else:
		head_bob_timer *= 0.95
	
	return Vector3.ZERO

func _update_landing_effect(delta: float) -> float:
	if landing_drop_phase:
		landing_timer += delta
		var down_dur := 0.25
		var t: float = clamp(landing_timer / down_dur, 0.0, 1.0)
		current_landing_offset = lerp(0.0, -impact_strength, t * t * (3.0 - 2.0 * t))

		if landing_timer >= down_dur:
			landing_drop_phase = false
			landing_rise_phase = true
			landing_timer = 0.0

	elif landing_rise_phase:
		landing_timer += delta
		var up_speed := 6.0
		current_landing_offset = lerp(current_landing_offset, 0.0, 1.0 - exp(-up_speed * delta))
		if abs(current_landing_offset) < 0.003:
			landing_rise_phase = false
			current_landing_offset = 0.0

	return current_landing_offset

func _check_landing_impact(delta: float) -> void:
	if not player:
		return

	if had_real_air and player.is_on_floor() and was_in_air:
		var impact_speed: float = abs(min_fall_speed_y)
		var threshold := 1.25
		if impact_speed > threshold and not landing_drop_phase and not landing_rise_phase:
			var k := 0.02
			var drop: float = clamp(impact_speed * k, 0.05, 0.40)
			_start_landing_drop(drop)
		min_fall_speed_y = 0.0

	previous_velocity_y = player.velocity.y
	
func _start_landing_drop(drop_amount: float) -> void:
	landing_drop_phase = true
	landing_rise_phase = false
	landing_timer = 0.0
	current_landing_offset = 0.0
	impact_strength = drop_amount

func _get_shake_offset(delta: float) -> Vector3:
	if camera_shake > 0:
		camera_shake -= delta * camera_shake_decay
		camera_shake = max(camera_shake, 0)
		return Vector3(
			randf_range(-camera_shake, camera_shake),
			randf_range(-camera_shake, camera_shake),
			0
		)
	return Vector3.ZERO

func _apply_weapon_bob(delta: float, horizontal_velocity: float) -> void:
	if not weapon_holder:
		return

	var velocity_factor = smoothstep(0.1, 1.0, horizontal_velocity)
	var rot_off := Vector3.ZERO
	var pos_off := Vector3.ZERO

	if player.is_on_floor() and velocity_factor > 0.01 and not minimal_effects and not is_aiming:
		weapon_bob_timer += delta * weapon_bob_frequency * velocity_factor

		var speed_factor := 1.0
		if is_sprinting: speed_factor = 1.3
		elif is_crouching: speed_factor = 0.7

		pos_off = Vector3(
			sin(weapon_bob_timer * 0.8) * weapon_bob_amplitude * 0.7 * speed_factor * velocity_factor,
			cos(weapon_bob_timer * 1.6) * weapon_bob_amplitude * speed_factor * velocity_factor,
			sin(weapon_bob_timer * 1.2 + weapon_bob_variance) * weapon_bob_amplitude * 0.4 * velocity_factor
		)

		rot_off = Vector3(
			cos(weapon_bob_timer * 0.9) * 0.5 * velocity_factor,
			sin(weapon_bob_timer * 0.7) * 0.3 * velocity_factor,
			sin(weapon_bob_timer * 1.1) * 0.8 * velocity_factor
		)
	elif not is_aiming:
		weapon_bob_timer *= 0.85
		idle_sway_timer += delta

		pos_off = Vector3(
			sin(idle_sway_timer * 0.9) * 0.015,
			cos(idle_sway_timer * 1.1) * 0.010,
			sin(idle_sway_timer * 0.7) * 0.008
		)

		rot_off = Vector3(
			cos(idle_sway_timer * 0.8) * 0.35,
			sin(idle_sway_timer * 0.6) * 0.25,
			sin(idle_sway_timer * 0.9) * 0.40
		)

	var ads_pos_factor: float = 0.0
	var ads_rot_factor: float = 0.0
	
	if is_aiming:
		ads_pos_factor = 1.0
		ads_rot_factor = 1.0
		weapon_bob_timer *= 0.9
		pos_off *= 0.1
		rot_off *= 0.1

	var current_ads_pos_offset = ads_position_offset * ads_pos_factor
	var current_ads_rot_offset = ads_rotation_offset * ads_rot_factor

	var pos_target = weapon_base_position + pos_off + current_ads_pos_offset
	var rot_target = weapon_base_rotation + sway_rotation + rot_off + current_ads_rot_offset

	var transition_speed = ads_transition_speed if is_aiming else 10.0

	if pos_target.distance_to(weapon_holder.position) < 0.001:
		weapon_holder.position = pos_target
	else:
		weapon_holder.position = weapon_holder.position.lerp(pos_target, delta * transition_speed)

	if rot_target.distance_to(weapon_holder.rotation_degrees) < 0.1:
		weapon_holder.rotation_degrees = rot_target
	else:
		weapon_holder.rotation_degrees = weapon_holder.rotation_degrees.lerp(rot_target, delta * transition_speed)
