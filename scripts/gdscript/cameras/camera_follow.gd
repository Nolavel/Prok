extends Camera3D

@export var target: Node3D
@export var rotation_speed: float = 8.0

@export_group("Camera Modes")
@export var follow_rotation_damping: float = 3.0
@export var follow_rotation_delay: float = 0.2

var follow_player_rotation: bool = false

@export_group("Orbit")
@export var orbit_distance: float = 20.0
@export var orbit_height: float = 15.0
@export var camera_angle: float = -35.0

@export_group("Top-Down View")
@export var top_down_height: float = 15.0
@export var top_down_angle: float = -90.0
@export var view_transition_speed: float = 4.0

@export_group("Camera States")
@export var input_manager: NodePath
@export var hud_node: NodePath
@export var pause_menu_node: NodePath

# === КОНФИГУРАЦИЯ СОСТОЯНИЙ ===
@export_subgroup("STATUS")
@export var status_offset: Vector3 = Vector3(0, 1.5, -3.0)
@export var status_pitch_deg: float = -15.0
@export var status_transition_duration: float = 0.6

@export_subgroup("MENU_PAUSE")
@export var menu_pause_offset: Vector3 = Vector3(0, 1.5, -5.0)
@export var menu_pause_pitch_deg: float = -7.5
@export var menu_pause_transition_duration: float = 0.6

@export_subgroup("INVENTORY")
@export var inventory_offset: Vector3 = Vector3(-2, 1.5, -4.0)
@export var inventory_pitch_deg: float = -25.0
@export var inventory_transition_duration: float = 0.6

@export_subgroup("CRAFTING")
@export var crafting_offset: Vector3 = Vector3(2, 2.0, -4.0)
@export var crafting_pitch_deg: float = -30.0
@export var crafting_transition_duration: float = 0.6

@export_subgroup("INTERACT")
@export var interact_offset: Vector3 = Vector3(0, 1.2, -2.5)
@export var interact_pitch_deg: float = -10.0
@export var interact_transition_duration: float = 0.5

@export_subgroup("MAP")
@export var map_offset: Vector3 = Vector3(0, 1.2, -2.5)
@export var map_pitch_deg: float = -10.0
@export var map_transition_duration: float = 0.5


@export_group("Camera Effects")
@export_subgroup("X-Ray Wall System")

var blocked_walls: Array = []  # Текущие заблокированные стены
var raycast_cooldown: float = 0.0
const RAYCAST_INTERVAL: float = 0.1  # Проверка каждые 100ms (оптимизация!)

@export_subgroup("Shake")
@export var shake_enabled_in_game_only: bool = true  # Shake только в GAME состоянии
@export var shake_trauma_power: float = 2.0  # Экспоненциальное затухание (2-3 для реализма)
@export var shake_max_angle: float = 10.0  # Максимальный наклон камеры (градусы)
@export var shake_frequency: float = 20.0  # Частота вибрации (Hz)
@export var shake_smooth_recovery: bool = true  # Плавное возвращение к нормали
@export var shake_area: NodePath

# === ORBITAL SYSTEM ===
enum OrbitalPosition { NORTH, EAST, SOUTH, WEST }
const ORBITAL_POSITIONS = [OrbitalPosition.NORTH, OrbitalPosition.EAST, OrbitalPosition.SOUTH, OrbitalPosition.WEST]
const POSITION_ANGLES = {
	OrbitalPosition.NORTH: 0.0,
	OrbitalPosition.EAST: PI / 2,
	OrbitalPosition.SOUTH: PI,
	OrbitalPosition.WEST: 3 * PI / 2
}
var current_position: OrbitalPosition = OrbitalPosition.NORTH
var target_angle: float = 0.0
var current_angle: float = 0.0
var player_rotation_timer: float = 0.0
var last_player_rotation: float = 0.0
var is_top_down_view: bool = false
var topdown_target_yaw: float = 0.0
var topdown_current_yaw: float = 0.0

var camera_target_pos: Vector3
var camera_current_pos: Vector3
var camera_target_pitch: float
var camera_current_pitch: float
var camera_target_yaw: float
var camera_current_yaw: float

# === ZOOM SYSTEM ===
var current_zoom_distance: float = 0.0
var target_zoom_distance: float = 0.0
var zoom_animating: bool = false
var zoom_anim_time: float = 0.0
var zoom_start_distance: float = 0.0

const ISOMETRIC_ZOOM_MIN: float = 10.0
const ISOMETRIC_ZOOM_MAX: float = 17.5
const TOPDOWN_ZOOM_MIN: float = 7.5
const TOPDOWN_ZOOM_MAX: float = 15.0
const ZOOM_STEP: float = 2.5

# === ORBITAL ROTATION (Q/E) ===
var orbit_rotation_animating: bool = false
var orbit_anim_time: float = 0.0
var orbit_start_angle: float = 0.0
var orbit_target_angle: float = 0.0

# === VIEW MODE SWITCHING (V) ===
var view_mode_animating: bool = false
var view_anim_time: float = 0.0
var view_start_distance: float = 0.0
var view_target_distance: float = 0.0
var view_start_pitch: float = 0.0
var view_target_pitch: float = 0.0

# === FOLLOW ROTATION (P) ===
var follow_rotation_animating: bool = false
var follow_anim_time: float = 0.0
var follow_start_angle: float = 0.0
var follow_target_angle: float = 0.0

# === TOP-DOWN FOLLOW ===
var topdown_follow_animating: bool = false
var topdown_follow_anim_time: float = 0.0
var topdown_follow_start_yaw: float = 0.0
var topdown_follow_target_yaw: float = 0.0

# === УНИФИЦИРОВАННАЯ СИСТЕМА СОСТОЯНИЙ ===
enum CameraState { GAME, STATUS, INVENTORY, MENU_PAUSE, MAP, INTERACT, CRAFTING }
var current_state: CameraState = CameraState.GAME
var saved_game_transform: Transform3D

# Единая система анимации состояний
var state_animating: bool = false
var state_anim_time: float = 0.0
var state_start_transform: Transform3D
var state_target_transform: Transform3D
var state_duration: float = 0.6

# === ОРБИТАЛЬНОЕ ВРАЩЕНИЕ В STATUS ===
var status_orbit_angle: float = 0.0  # Текущий угол вращения вокруг игрока
var status_orbit_rotating: bool = false  # Флаг активного вращения
const STATUS_ROTATION_SPEED: float = 1.5  # Скорость вращения (радианы/сек)
var status_rotation_direction: int = 0  # -1 = влево, 1 = вправо, 0 = стоп


### CAMERA EFFECTS

# === ШЕЙК КАМЕРы ===

var shake_amplitude: float = 0.0
var shake_time: float = 0.0
var shake_timer: float = 0.0
var shake_active: bool = false
var rng := RandomNumberGenerator.new()
var shake_trauma: float = 0.0  # Текущая "травма" (0.0 - 1.0)
var shake_noise_offset: float = 0.0  # Offset для Perlin noise
var shake_original_rotation: Vector3 = Vector3.ZERO  # Сохранённая ротация

@onready var lbl_current_mode = $CameraSettings/VBoxContainer/CurrentMode
@onready var lbl_orbital = $CameraSettings/VBoxContainer/Orbital
@onready var lbl_follow = $CameraSettings/VBoxContainer/Follow

var input_manager_node: Node
var pause_menu: Control

func _ready():
	projection = PROJECTION_PERSPECTIVE
	current_angle = POSITION_ANGLES[current_position]
	target_angle = current_angle
	topdown_target_yaw = POSITION_ANGLES[current_position]
	topdown_current_yaw = topdown_target_yaw
	camera_target_pitch = camera_angle
	camera_current_pitch = camera_angle
	camera_target_yaw = current_angle
	camera_current_yaw = current_angle
	camera_target_pos = global_position
	camera_current_pos = global_position
	current_zoom_distance = orbit_distance
	target_zoom_distance = orbit_distance
	
	# Подключение к InputManager
	if input_manager:
		input_manager_node = get_node(input_manager)
		if input_manager_node:
			input_manager_node.status_camera_toggled.connect(_on_status_camera_toggled)
			input_manager_node.menu_pause_toggled.connect(_on_menu_pause_toggled)
			input_manager_node.inventory_toggled.connect(_on_inventory_camera_toggled)  # 🔥 НОВОЕ
			input_manager_node.crafting_toggled.connect(_on_crafting_camera_toggled)    # 🔥 НОВОЕ
			input_manager_node.map_toggled.connect(_on_map_camera_toggled)
			print("✅ SystemCamera: Подключен к InputManager")
		else:
			push_error("❌ InputManager node not found!")
	
	# Подключение к HUD
	if hud_node:
		var hud = get_node(hud_node)
		if hud:
			hud.status_camera_toggled.connect(_on_status_camera_toggled)
			hud.inventory_camera_toggled.connect(_on_inventory_camera_toggled)
			hud.crafting_camera_toggled.connect(_on_crafting_camera_toggled)
			hud.map_camera_toggled.connect(_on_map_camera_toggled)
			print("✅ SystemCamera: Подключен к HUD (STATUS, INVENTORY, CRAFTING, MAP)")
		else:
			push_error("❌ HUD node not found!")
	
	# Подключение к PauseMenu
	if pause_menu_node:
		pause_menu = get_node(pause_menu_node)
		if pause_menu:
			# Подключаемся к сигналу кнопки Continue
			if pause_menu.has_signal("continue_pressed"):
				pause_menu.continue_pressed.connect(_on_pause_menu_continue)
			print("✅ SystemCamera: Подключен к PauseMenu")
		else:
			push_error("❌ PauseMenu node not found!")
	if shake_area:
		var area = get_node_or_null(shake_area)
		if area:
			area.shake_cam_process.connect(_on_shake_cam_process)
			area.stop_shake_cam_process.connect(_on_stop_shake_cam_process)
			print("✅ Камера подключена к Area3D для ShakeCam")
	
		
	make_current()




func _process(delta):
	if not target:
		return

	# ПРИОРИТЕТ: Анимация перехода между состояниями
	if state_animating:
		_update_state_animation(delta)
		_apply_shake(delta)
		return
		
	if current_state == CameraState.GAME:
		raycast_cooldown -= delta
		
		if raycast_cooldown <= 0.0:
			raycast_cooldown = RAYCAST_INTERVAL
			_check_blocked_walls()

	# GAME состояние - полное управление камерой
	if current_state == CameraState.GAME:
		_handle_follow_toggle()
		_handle_view_toggle()
		_handle_zoom_input()

		if follow_player_rotation and is_top_down_view:
			_handle_topdown_follow_rotation(delta)
		elif follow_player_rotation and not is_top_down_view:
			_handle_follow_rotation(delta)
		else:
			_handle_rotation_input()

		_update_zoom_animation(delta)
		_update_orbit_rotation_animation(delta)
		_update_view_mode_animation(delta)
		_update_follow_rotation_animation(delta)
		
		if not orbit_rotation_animating and not follow_rotation_animating:
			current_angle = lerp_angle(current_angle, target_angle, delta * rotation_speed)
		topdown_current_yaw = lerp_angle(topdown_current_yaw, topdown_target_yaw, delta * rotation_speed)
		
		_update_camera_position(delta)
		_apply_shake(delta)
	
	# 🔥 STATUS состояние - орбитальное вращение вокруг игрока
	elif current_state == CameraState.STATUS:
		if status_orbit_rotating:
			_update_status_orbit(delta)
		if not shake_enabled_in_game_only:
			_apply_shake(delta)
	# СТАТИЧЕСКИЕ СОСТОЯНИЯ - камера заморожена
	else:
		if not state_animating:
			global_transform = state_target_transform
		if not shake_enabled_in_game_only:
			_apply_shake(delta)
			
	_update_labels()

# ============================================
# УНИФИЦИРОВАННАЯ АНИМАЦИЯ СОСТОЯНИЙ (25% - 50% - 25%)
# ============================================
func _update_state_animation(delta: float):
	state_anim_time += delta
	var t: float = 0.0
	var phase1 = state_duration * 0.33  # 33%
	var phase2 = state_duration * 0.67  # 67%
	
	if state_anim_time < phase1:
		var progress = state_anim_time / phase1
		t = progress * 0.25
	elif state_anim_time < phase2:
		var progress = (state_anim_time - phase1) / (phase2 - phase1)
		t = 0.25 + progress * 0.5
	elif state_anim_time < state_duration:
		var progress = (state_anim_time - phase2) / (state_duration - phase2)
		t = 0.75 + progress * 0.25
	else:
		t = 1.0
		state_animating = false
	
	var te = t * t * (3.0 - 2.0 * t)
	var interp_pos = state_start_transform.origin.lerp(state_target_transform.origin, te)
	var start_quat = Quaternion(state_start_transform.basis)
	var target_quat = Quaternion(state_target_transform.basis)
	var interp_quat = start_quat.slerp(target_quat, te)
	global_transform = Transform3D(Basis(interp_quat), interp_pos)
	
	if not state_animating:
		global_transform = state_target_transform
		var state_name = CameraState.keys()[current_state]
		print("✅ Анимация %s завершена | distance: %.2fm" % [state_name, global_position.distance_to(target.global_position)])

# ============================================
# ПЕРЕХОДЫ МЕЖДУ СОСТОЯНИЯМИ
# ============================================
func _transition_to_state(new_state: CameraState, offset: Vector3, pitch: float, duration: float):
	if current_state == new_state:
		return
	
	# Сохраняем GAME трансформ перед первым переходом
	if current_state == CameraState.GAME:
		saved_game_transform = global_transform
	
	var old_state = current_state
	current_state = new_state
	
	# Вычисляем целевой трансформ
	var frozen_pos = target.global_position
	var frozen_yaw = target.rotation.y
	
	# 🔥 Для STATUS: инициализируем орбитальный угол
	if new_state == CameraState.STATUS:
		status_orbit_angle = frozen_yaw + PI  # Начинаем позади игрока
		status_orbit_rotating = false
		status_rotation_direction = 0
	
	var local_offset = offset.rotated(Vector3.UP, frozen_yaw)
	var target_pos = frozen_pos + local_offset
	
	var rot = Basis()
	rot = rot.rotated(Vector3.RIGHT, deg_to_rad(pitch))
	rot = rot.rotated(Vector3.UP, frozen_yaw + PI)
	
	state_start_transform = global_transform
	state_target_transform = Transform3D(rot, target_pos)
	state_anim_time = 0.0
	state_duration = duration
	state_animating = true
	
	# 🔥 Отключаем управление игроком для неигровых состояний
	if target and target.has_method("set_movement_enabled"):
		var should_enable = (new_state == CameraState.GAME)
		target.set_movement_enabled(should_enable)
		print("🎮 Player movement: %s (state: %s)" % ["ENABLED" if should_enable else "DISABLED", CameraState.keys()[new_state]])
	
	print("🎬 %s → %s | dist: %.2fm" % [
		CameraState.keys()[old_state], 
		CameraState.keys()[new_state],
		state_start_transform.origin.distance_to(state_target_transform.origin)
	])

func _return_to_game():
	if current_state == CameraState.GAME:
		return
	
	var old_state = current_state
	current_state = CameraState.GAME
	
	state_start_transform = global_transform
	state_target_transform = saved_game_transform
	state_anim_time = 0.0
	state_duration = 0.6
	state_animating = true
	
	# 🔥 Включаем движение
	if target and target.has_method("set_movement_enabled"):
		target.set_movement_enabled(true)
		print("✅ Движение игрока ВКЛЮЧЕНО при возврате в GAME")
	
	# 🔥 Синхронизация с InputManager
	if input_manager_node:
		if "current_ui_state" in input_manager_node:
			input_manager_node.current_ui_state = 0  # UIState.GAME
		if "status_camera_active" in input_manager_node:
			input_manager_node.status_camera_active = false
		if "inventory_active" in input_manager_node:
			input_manager_node.inventory_active = false
		if "crafting_active" in input_manager_node:
			input_manager_node.crafting_active = false
		if "map_active" in input_manager_node:
			input_manager_node.map_active = false
		print("✅ InputManager синхронизирован с GAME")
	
	print("🎬 %s → GAME" % CameraState.keys()[old_state])

# ============================================
# ОБРАБОТЧИКИ СИГНАЛОВ
# ============================================
func _on_status_camera_toggled(active: bool):
	if active:
		_transition_to_state(
			CameraState.STATUS,
			status_offset,
			status_pitch_deg,
			status_transition_duration
		)
	else:
		_return_to_game()

func _on_menu_pause_toggled(active: bool):
	if active:
		_transition_to_state(
			CameraState.MENU_PAUSE,
			menu_pause_offset,
			menu_pause_pitch_deg,
			menu_pause_transition_duration
		)
		#await get_tree().create_timer(0.6).timeout

		$"../Player/player_base_mesh/AnimationPlayer".play("new3/legs_idle_2")
		
	else:
		$"../Player/player_base_mesh/AnimationPlayer".play("new4/idle")
		_return_to_game()

func _on_pause_menu_continue():
	print("🎮 Continue нажата - возврат в GAME")
	# Сообщаем InputManager что меню закрыто
	if input_manager_node and input_manager_node.has_method("close_pause_menu"):
		input_manager_node.close_pause_menu()
	_return_to_game()

func _on_inventory_camera_toggled(active: bool):
	if active:
		_transition_to_state(
			CameraState.INVENTORY,
			inventory_offset,
			inventory_pitch_deg,
			inventory_transition_duration
		)
		$"../Player/player_base_mesh/AnimationPlayer".play("new4/idle")
	else:
		_return_to_game()

func _on_crafting_camera_toggled(active: bool):
	if active:
		_transition_to_state(
			CameraState.CRAFTING,
			crafting_offset,
			crafting_pitch_deg,
			crafting_transition_duration
		)
		$"../Player/player_base_mesh/AnimationPlayer".play("new4/idle")
	else:
		_return_to_game()
		
func _on_map_camera_toggled(active: bool):
	if active:
		_transition_to_state(
			CameraState.MAP,
			map_offset,
			map_pitch_deg,
			map_transition_duration
		)
		$"../Player/player_base_mesh/AnimationPlayer".play("Guarding")
		$"../Player/player_base_mesh/AnimationPlayer".stop(false)
	else:
		$"../Player/player_base_mesh/AnimationPlayer".play("new4/idle")
		_return_to_game()

# Публичные методы для других состояний
func enter_inventory_mode():
	_transition_to_state(CameraState.INVENTORY, inventory_offset, inventory_pitch_deg, inventory_transition_duration)

func enter_crafting_mode():
	_transition_to_state(CameraState.CRAFTING, crafting_offset, crafting_pitch_deg, crafting_transition_duration)

func enter_interact_mode():
	_transition_to_state(CameraState.INTERACT, interact_offset, interact_pitch_deg, interact_transition_duration)
	
func enter_map_mode():
	_transition_to_state(CameraState.MAP, map_offset, map_pitch_deg, map_transition_duration)

# ============================================
# ОРБИТАЛЬНОЕ ВРАЩЕНИЕ В STATUS
# ============================================
func start_status_orbit_left():
	"""Начать вращение камеры влево (против часовой стрелки)"""
	if current_state != CameraState.STATUS:
		return
	status_rotation_direction = -1
	status_orbit_rotating = true
	print("🔄 STATUS: Вращение ВЛЕВО")

func start_status_orbit_right():
	"""Начать вращение камеры вправо (по часовой стрелке)"""
	if current_state != CameraState.STATUS:
		return
	status_rotation_direction = 1
	status_orbit_rotating = true
	print("🔄 STATUS: Вращение ВПРАВО")

func stop_status_orbit():
	"""Остановить орбитальное вращение"""
	status_orbit_rotating = false
	status_rotation_direction = 0
	print("⏹️ STATUS: Вращение ОСТАНОВЛЕНО")

func _update_status_orbit(delta: float):
	if not target or status_rotation_direction == 0:
		return
	
	status_orbit_angle += status_rotation_direction * STATUS_ROTATION_SPEED * delta
	
	if status_orbit_angle > TAU:
		status_orbit_angle -= TAU
	elif status_orbit_angle < 0:
		status_orbit_angle += TAU
	
	var player_pos = target.global_position
	var horizontal_distance = sqrt(status_offset.x * status_offset.x + status_offset.z * status_offset.z)
	var vertical_offset = status_offset.y
	
	var orbit_x = sin(status_orbit_angle) * horizontal_distance
	var orbit_z = cos(status_orbit_angle) * horizontal_distance
	var new_pos = player_pos + Vector3(orbit_x, vertical_offset, orbit_z)
	
	# 🔥 Исправление: вектор от камеры к игроку
	var direction_to_player = player_pos - new_pos
	direction_to_player.y = 0
	
	# yaw с поправкой на 180°, чтобы не отворачивалась
	var yaw = atan2(direction_to_player.x, direction_to_player.z) + PI
	
	var pitch = deg_to_rad(status_pitch_deg)
	
	global_position = new_pos
	global_rotation = Vector3(pitch, yaw, 0)




# ============================================
# ОСТАЛЬНЫЕ ФУНКЦИИ (без изменений)
# ============================================
func _update_zoom_animation(delta: float):
	if not zoom_animating:
		return
	
	zoom_anim_time += delta
	var t: float = 0.0
	
	if zoom_anim_time < 0.4:
		var phase1_progress = zoom_anim_time / 0.4
		t = phase1_progress * 0.75
	elif zoom_anim_time < 0.6:
		var phase2_progress = (zoom_anim_time - 0.4) / 0.2
		t = 0.75 + phase2_progress * 0.25
	else:
		t = 1.0
		zoom_animating = false
	
	var te = t * t * (3.0 - 2.0 * t)
	current_zoom_distance = lerp(zoom_start_distance, target_zoom_distance, te)
	
	if not zoom_animating:
		current_zoom_distance = target_zoom_distance

func _update_orbit_rotation_animation(delta: float):
	if not orbit_rotation_animating:
		return
	
	orbit_anim_time += delta
	var t: float = 0.0
	
	if orbit_anim_time < 0.4:
		var phase1_progress = orbit_anim_time / 0.4
		t = phase1_progress * 0.75
	elif orbit_anim_time < 0.6:
		var phase2_progress = (orbit_anim_time - 0.4) / 0.2
		t = 0.75 + phase2_progress * 0.25
	else:
		t = 1.0
		orbit_rotation_animating = false
	
	var te = t * t * (3.0 - 2.0 * t)
	current_angle = lerp_angle(orbit_start_angle, orbit_target_angle, te)
	
	if not orbit_rotation_animating:
		current_angle = orbit_target_angle

func _update_view_mode_animation(delta: float):
	if not view_mode_animating:
		return
	
	view_anim_time += delta
	var t: float = 0.0
	
	if view_anim_time < 0.2:
		var phase1_progress = view_anim_time / 0.2
		t = phase1_progress * 0.25
	elif view_anim_time < 0.4:
		var phase2_progress = (view_anim_time - 0.2) / 0.2
		t = 0.25 + phase2_progress * 0.5
	elif view_anim_time < 0.6:
		var phase3_progress = (view_anim_time - 0.4) / 0.2
		t = 0.75 + phase3_progress * 0.25
	else:
		t = 1.0
		view_mode_animating = false
	
	var te = t * t * (3.0 - 2.0 * t)
	current_zoom_distance = lerp(view_start_distance, view_target_distance, te)
	camera_current_pitch = lerp(view_start_pitch, view_target_pitch, te)
	
	if not view_mode_animating:
		current_zoom_distance = view_target_distance
		camera_current_pitch = view_target_pitch

func _update_follow_rotation_animation(delta: float):
	if not follow_rotation_animating:
		return
	
	follow_anim_time += delta
	var t: float = 0.0
	
	if follow_anim_time < 0.4:
		var phase1_progress = follow_anim_time / 0.4
		t = phase1_progress * 0.25
	elif follow_anim_time < 0.6:
		var phase2_progress = (follow_anim_time - 0.4) / 0.2
		t = 0.25 + phase2_progress * 0.5
	elif follow_anim_time < 1.0:
		var phase3_progress = (follow_anim_time - 0.6) / 0.4
		t = 0.75 + phase3_progress * 0.25
	else:
		t = 1.0
		follow_rotation_animating = false
	
	var te = t * t * (3.0 - 2.0 * t)
	current_angle = lerp_angle(follow_start_angle, follow_target_angle, te)
	
	if not follow_rotation_animating:
		current_angle = follow_target_angle

func _update_camera_position(delta):
	if is_top_down_view:
		camera_target_pos = target.global_position + Vector3(0, current_zoom_distance, 0)
		camera_target_pitch = top_down_angle
		camera_target_yaw = topdown_current_yaw
	else:
		var horizontal_direction = Vector3(sin(current_angle), 0, cos(current_angle))
		var pitch_rad = deg_to_rad(camera_angle)
		var horizontal_distance = current_zoom_distance * cos(pitch_rad)
		var vertical_distance = -current_zoom_distance * sin(pitch_rad)
		var orbit_offset = horizontal_direction * horizontal_distance + Vector3(0, vertical_distance, 0)
		camera_target_pos = target.global_position + orbit_offset
		camera_target_pitch = camera_angle
		camera_target_yaw = current_angle

	camera_current_pos = camera_current_pos.lerp(camera_target_pos, delta * view_transition_speed)
	if not view_mode_animating:
		camera_current_pitch = lerp(camera_current_pitch, camera_target_pitch, delta * view_transition_speed)
	camera_current_yaw = lerp_angle(camera_current_yaw, camera_target_yaw, delta * view_transition_speed)

	global_position = camera_current_pos
	global_rotation = Vector3(deg_to_rad(camera_current_pitch), camera_current_yaw, 0)

func _handle_follow_toggle():
	if Input.is_action_just_pressed("toggle_follow"):
		follow_player_rotation = !follow_player_rotation
		if follow_player_rotation:
			last_player_rotation = target.rotation.y
			player_rotation_timer = 0.0

func _handle_view_toggle():
	if Input.is_action_just_pressed("toggle_view"):
		is_top_down_view = !is_top_down_view
		
		view_start_distance = current_zoom_distance
		view_start_pitch = camera_current_pitch
		
		if is_top_down_view:
			var ratio = (current_zoom_distance - ISOMETRIC_ZOOM_MIN) / (ISOMETRIC_ZOOM_MAX - ISOMETRIC_ZOOM_MIN)
			view_target_distance = TOPDOWN_ZOOM_MIN + ratio * (TOPDOWN_ZOOM_MAX - TOPDOWN_ZOOM_MIN)
			view_target_pitch = top_down_angle
			topdown_target_yaw = current_angle
			topdown_current_yaw = current_angle
		else:
			var ratio = (current_zoom_distance - TOPDOWN_ZOOM_MIN) / (TOPDOWN_ZOOM_MAX - TOPDOWN_ZOOM_MIN)
			view_target_distance = ISOMETRIC_ZOOM_MIN + ratio * (ISOMETRIC_ZOOM_MAX - ISOMETRIC_ZOOM_MIN)
			view_target_pitch = camera_angle
			target_angle = topdown_current_yaw
		
		target_zoom_distance = view_target_distance
		view_anim_time = 0.0
		view_mode_animating = true

func _handle_follow_rotation(delta):
	var player_y_rotation = target.rotation.y
	var desired_angle = player_y_rotation + PI
	
	if abs(player_y_rotation - last_player_rotation) > 0.01:
		player_rotation_timer += delta
		if player_rotation_timer >= follow_rotation_delay:
			if not follow_rotation_animating:
				follow_start_angle = current_angle
				follow_target_angle = desired_angle
				follow_anim_time = 0.0
				follow_rotation_animating = true
				target_angle = desired_angle
		last_player_rotation = player_y_rotation
	else:
		player_rotation_timer = 0.0

func _handle_topdown_follow_rotation(delta):
	var player_y_rotation = target.rotation.y + PI
	
	if abs(player_y_rotation - last_player_rotation - PI) > 0.01:
		player_rotation_timer += delta
		if player_rotation_timer >= follow_rotation_delay:
			if not follow_rotation_animating:
				topdown_target_yaw = player_y_rotation
		last_player_rotation = target.rotation.y
	else:
		player_rotation_timer = 0.0

func _handle_rotation_input():
	if follow_player_rotation:
		return
	if Input.is_action_just_pressed("lean_left"):
		_rotate_camera_left()
	elif Input.is_action_just_pressed("lean_right"):
		_rotate_camera_right()

func _rotate_camera_left():
	var idx = ORBITAL_POSITIONS.find(current_position)
	idx = (idx - 1) % ORBITAL_POSITIONS.size()
	if idx < 0: idx = ORBITAL_POSITIONS.size() - 1
	current_position = ORBITAL_POSITIONS[idx]
	
	orbit_start_angle = current_angle
	orbit_target_angle = POSITION_ANGLES[current_position]
	orbit_anim_time = 0.0
	orbit_rotation_animating = true
	
	target_angle = orbit_target_angle
	topdown_target_yaw = orbit_target_angle

func _rotate_camera_right():
	var idx = ORBITAL_POSITIONS.find(current_position)
	idx = (idx + 1) % ORBITAL_POSITIONS.size()
	if idx >= ORBITAL_POSITIONS.size(): idx = 0
	current_position = ORBITAL_POSITIONS[idx]
	
	orbit_start_angle = current_angle
	orbit_target_angle = POSITION_ANGLES[current_position]
	orbit_anim_time = 0.0
	orbit_rotation_animating = true
	
	target_angle = orbit_target_angle
	topdown_target_yaw = orbit_target_angle

func _handle_zoom_input():
	if Input.is_action_just_released("zoom_in"):
		_start_zoom(-ZOOM_STEP)
	elif Input.is_action_just_released("zoom_out"):
		_start_zoom(ZOOM_STEP)

func _start_zoom(amount: float):
	var min_zoom: float
	var max_zoom: float
	
	if is_top_down_view:
		min_zoom = TOPDOWN_ZOOM_MIN
		max_zoom = TOPDOWN_ZOOM_MAX
	else:
		min_zoom = ISOMETRIC_ZOOM_MIN
		max_zoom = ISOMETRIC_ZOOM_MAX
	
	var new_distance = clamp(target_zoom_distance + amount, min_zoom, max_zoom)
	
	if abs(new_distance - target_zoom_distance) > 0.01:
		zoom_start_distance = current_zoom_distance
		target_zoom_distance = new_distance
		zoom_anim_time = 0.0
		zoom_animating = true

func _update_labels():
	if not lbl_current_mode:
		return
		
	lbl_current_mode.text = "Режим: %s (нажми V для изменения)" % get_current_mode()
	if follow_player_rotation:
		lbl_orbital.visible = false
	else:
		lbl_orbital.visible = true
		lbl_orbital.text = "Изменить орбиту: Q или E"
	var follow_state = "ON" if follow_player_rotation else "OFF"
	lbl_follow.text = "Слежение за игроком (P): %s" % follow_state

# ============================================
# CAMERA SHAKE SYSTEM (ПРАВИЛЬНАЯ РЕАЛИЗАЦИЯ)
# ============================================
func _on_shake_cam_process(amplitude: float, time: float) -> void:
	# 🔥 ПРОВЕРКА: Shake только в GAME если включен флаг
	if shake_enabled_in_game_only and current_state != CameraState.GAME:
		print("⚠️ Shake blocked: camera not in GAME state")
		return
	
	shake_amplitude = amplitude
	shake_time = time
	shake_timer = 0.0
	shake_active = true
	
	# 🔥 Устанавливаем trauma (чем больше amplitude, тем сильнее)
	shake_trauma = clamp(amplitude / 5.0, 0.0, 1.0)  # 5.0 = нормализация
	shake_original_rotation = global_rotation
	
	print("🎥 Professional Shake started | amp: %.2f, time: %.2fs, trauma: %.2f, state: %s" % [
		amplitude, time, shake_trauma, CameraState.keys()[current_state]
	])

func _on_stop_shake_cam_process() -> void:
	if shake_smooth_recovery:
		# Плавное затухание вместо резкой остановки
		shake_trauma = 0.0
		print("🛑 Shake smooth stop initiated")
	else:
		shake_active = false
		shake_timer = 0.0
		shake_trauma = 0.0
		print("🛑 Shake stopped manually")

func _apply_shake(delta: float) -> void:
	"""
	Shake с использованием:
	- Trauma System (экспоненциальное затухание)
	- Perlin-подобный noise для плавности
	- Независимое движение по 3 осям
	- Ротация + позиция
	"""
	
	if not shake_active:
		return
	
	# 🔥 Обновляем таймер и trauma
	shake_timer += delta
	
	# Автоматическое затухание trauma
	if shake_time > 0:
		var decay_rate = 1.0 / shake_time
		shake_trauma = max(0.0, shake_trauma - decay_rate * delta)
	
	# Останавливаем shake когда trauma близка к нулю
	if shake_trauma < 0.01:
		shake_active = false
		shake_trauma = 0.0
		print("✅ Professional shake ended (trauma depleted)")
		return
	
	# 🔥 Экспоненциальное затухание (делает эффект более реалистичным)
	var shake_power = pow(shake_trauma, shake_trauma_power)
	
	# 🔥 Генерируем "псевдо-Perlin" смещение (плавнее чем случайный шум)
	shake_noise_offset += delta * shake_frequency
	
	# Используем синусоиды с разными частотами для каждой оси
	var offset_x = sin(shake_noise_offset * 1.3) * shake_amplitude * shake_power
	var offset_y = sin(shake_noise_offset * 1.7) * shake_amplitude * shake_power * 0.5  # Y меньше
	var offset_z = sin(shake_noise_offset * 1.1) * shake_amplitude * shake_power
	
	var position_offset = Vector3(offset_x, offset_y, offset_z)
	
	# 🔥 Добавляем ротационный shake (самое важное для реализма!)
	var rotation_x = sin(shake_noise_offset * 2.1) * deg_to_rad(shake_max_angle) * shake_power
	var rotation_y = sin(shake_noise_offset * 1.9) * deg_to_rad(shake_max_angle) * shake_power * 0.7
	var rotation_z = sin(shake_noise_offset * 2.3) * deg_to_rad(shake_max_angle) * shake_power * 0.5
	
	var rotation_offset = Vector3(rotation_x, rotation_y, rotation_z)
	
	# 🔥 Применяем offset
	global_position += position_offset
	
	# 🔥 Применяем ротацию (КРИТИЧНО для AAA-эффекта!)
	# Сохраняем текущую ротацию и добавляем shake
	var current_rot = global_rotation
	global_rotation = current_rot + rotation_offset


# ============================================
# АЛЬТЕРНАТИВА: "ИМПУЛЬСНЫЙ" SHAKE (для взрывов)
# ============================================
func add_impulse_shake(strength: float = 1.0):
	"""
	Быстрый импульсный shake (для взрывов, ударов)
	strength: 0.5-2.0 (сила импульса)
	"""
	if shake_enabled_in_game_only and current_state != CameraState.GAME:
		return
	
	shake_trauma = clamp(shake_trauma + strength, 0.0, 1.0)
	shake_active = true
	shake_timer = 0.0
	shake_time = 0.5  # Короткий импульс
	
	print("💥 Impulse shake added | strength: %.2f, trauma: %.2f" % [strength, shake_trauma])

# ============================================
# TRANSPARENT WALL SYSTEM (DUAL CAMERA)
# ============================================
	
func _check_blocked_walls():
	"""Проверяет какие стены блокируют обзор (оптимизированный raycast)"""
	if not target:
		return
	
	var space_state = get_world_3d().direct_space_state
	var from = global_position
	var to = target.global_position
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 0xFFFFFFFF  # Все слои
	query.exclude = [target]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var new_blocked_walls: Array = []
	
	# Множественные raycast'ы до попадания в игрока
	var max_iterations = 10
	var current_pos = from
	
	for i in range(max_iterations):
		var ray_query = PhysicsRayQueryParameters3D.create(current_pos, to)
		ray_query.collision_mask = query.collision_mask
		ray_query.exclude = query.exclude
		
		var result = space_state.intersect_ray(ray_query)
		
		if result.is_empty():
			break
		
		var collider = result.collider
		
		# 🔥 ПРОВЕРКА ГРУППЫ НАПРЯМУЮ
		if collider.is_in_group("wall"):
			if collider is StaticBody3D:
				print("🚧 Найдена стена (StaticBody3D) в группе 'wall'")
		
		# Двигаем луч дальше
		current_pos = result.position + (to - current_pos).normalized() * 0.01
		
		# Если дошли до игрока - стоп
		if current_pos.distance_to(to) < 0.1:
			break

func _find_mesh_in_wall(wall_node: Node) -> MeshInstance3D:
	"""Находит MeshInstance3D в стене"""
	if wall_node is MeshInstance3D:
		return wall_node
	
	if wall_node.get_parent() is MeshInstance3D:
		return wall_node.get_parent()
	
	for child in wall_node.get_children():
		if child is MeshInstance3D:
			return child
	
	return null
			
func get_current_mode() -> String:
	if is_top_down_view:
		return "Top-Down"
	elif follow_player_rotation:
		return "Follow Player"
	else:
		return "Orbital (%s)" % get_current_direction_name()

func get_current_direction_name() -> String:
	match current_position:
		OrbitalPosition.NORTH: return "North"
		OrbitalPosition.EAST: return "East"
		OrbitalPosition.SOUTH: return "South"
		OrbitalPosition.WEST: return "West"
		_: return "Unknown"
