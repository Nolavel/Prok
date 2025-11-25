# InputManager.gd
extends Node3D

# === СИГНАЛЫ ===
signal status_camera_toggled(status_is_active: bool)
signal menu_pause_toggled(mp_is_active: bool)
signal inventory_toggled(inventory_is_active: bool)
signal crafting_toggled(crafting_is_active: bool)
signal map_toggled(map_is_active: bool)
signal fog_effect_toggled(is_paused: bool)

@export_group("References")
@export var player: NodePath
@export var menu_pause: Control
@export var hud: NodePath
@export_subgroup("Cameras")
@export var camera_follow: Camera3D

@onready var target_indicator: TargetIndicator = $TargetIndicator
@onready var orbital_particles: OrbitalParticleEffect = $OrbitalParticleEffect
@onready var terrain_scanner: TerrainScannerEffect = $TerrainScannerEffect
@onready var label_actives = $"WidgetCursor/VBoxContainer/P-actives"

@export_subgroup("Debug")
@export var label_debug: Label

@export_subgroup("Audio")
@export var error_sound: AudioStreamPlayer

# --- Ground Detection ---
const GROUND_LAYER = 2

# --- Input State ---
var right_click_duration: float = 0.0
var is_running: bool = false
const RUN_TRIGGER_TIME: float = 0.5

var status_pressed_time: float = 0.0
var status_pressing: bool = false
var status_notifier: bool = false

var status_camera_active: bool = false
var menu_pause_active: bool = false
var inventory_active: bool = false
var crafting_active: bool = false
var map_active: bool = false

# --- Cached References ---
var player_node: CharacterBody3D
var camera: Camera3D
var hud_node: CanvasLayer

enum UIState { GAME, STATUS, INVENTORY, CRAFTING, MENU_PAUSE, MAP }
var current_ui_state: UIState = UIState.GAME

# ============================================
# ИНИЦИАЛИЗАЦИЯ
# ============================================
func _ready():
	player_node = get_node(player)
	
	if player_node:
		player_node.movement_started.connect(_on_movement_started)
		player_node.movement_stopped.connect(_on_movement_stopped)
		
		# 🔥 Передаём референс игрока индикатору
		if target_indicator:
			target_indicator.set_player_reference(player_node)
		if orbital_particles:
			orbital_particles.set_player_reference(player_node)
		if terrain_scanner:
			terrain_scanner.set_player_reference(player_node)
	else:
		push_error("Player node not found!")
	
	camera = get_viewport().get_camera_3d()
	
	if hud:
		hud_node = get_node(hud)
		if hud_node:
			print("✅ InputManager: HUD подключен")
		else:
			push_error("❌ HUD node not found!")
	
	if camera_follow:
		camera_follow.make_current()
	
	if not error_sound:
		push_warning("⚠️ AudioStreamPlayer для error_sound не назначен!")
	
	# 🔥 Проверка наличия индикатора
	if not target_indicator:
		push_warning("⚠️ TargetIndicator не найден!")

# ============================================
# ОСНОВНОЙ ЦИКЛ
# ============================================
func _physics_process(delta: float) -> void:
	if not player_node:
		return
	
	var can_control_movement = current_ui_state == UIState.GAME
	
	if can_control_movement and player_node.is_movement_enabled():
		_handle_right_click(delta)
		_handle_left_click()
	
	_update_ui()
	_update_system_press_time(delta)
	_handle_camera_status()
	_handle_menu_pause()
	_handle_inventory_hotkey()
	_handle_crafting_hotkey()
	_handle_map_hotkey()
	_handle_scanner_toggle()

# ============================================
# ХОТКЕИ
# ============================================

func _handle_scanner_toggle() -> void:
	# Работает только в состоянии GAME
	if current_ui_state != UIState.GAME:
		return
	
	# Проверяем нажатие кнопки S (нужно добавить в Input Map)
	if Input.is_action_just_pressed("toggle_scanner"):
		if terrain_scanner:
			if terrain_scanner.is_active:
				terrain_scanner.deactivate()
				print("🔍 Сканер: ВЫКЛ (через S)")
			else:
				terrain_scanner.activate()
				print("🔍 Сканер: ВКЛ (через S)")
				
func _handle_inventory_hotkey() -> void:
	if Input.is_action_just_pressed("Inventory"):
		if menu_pause_active:
			print("⚠️ Нельзя открыть Inventory - активна Menu Pause")
			return
		_switch_to_tabs_state(UIState.INVENTORY)

func _handle_crafting_hotkey() -> void:
	if Input.is_action_just_pressed("Crafting"):
		if menu_pause_active:
			print("⚠️ Нельзя открыть Crafting - активна Menu Pause")
			return
		_switch_to_tabs_state(UIState.CRAFTING)
		
func _handle_map_hotkey() -> void:
	if Input.is_action_just_pressed("Map"):
		if menu_pause_active:
			print("⚠️ Нельзя открыть Map - активна Menu Pause")
			return
		_switch_to_tabs_state(UIState.MAP)

func _handle_menu_pause():
	if Input.is_action_just_released("pause"):
		if menu_pause_active:
			menu_pause_active = false
			current_ui_state = UIState.GAME
			menu_pause_toggled.emit(false)
			fog_effect_toggled.emit(false)
			print("🎮 Menu Pause: CLOSED")
			return
		
		if current_ui_state != UIState.GAME:
			_return_to_game_from_tabs()
			return
		
		menu_pause_active = true
		current_ui_state = UIState.MENU_PAUSE
		menu_pause_toggled.emit(true)
		fog_effect_toggled.emit(true)
		if hud_node and hud_node.has_method("force_close_tabs"):
			hud_node.force_close_tabs()
		
		print("🎮 Menu Pause: OPENED")

func _return_to_game_from_tabs():
	var old_state = current_ui_state
	current_ui_state = UIState.GAME
	
	if status_camera_active:
		status_camera_active = false
		status_camera_toggled.emit(false)
	if inventory_active:
		inventory_active = false
		inventory_toggled.emit(false)
	if crafting_active:
		crafting_active = false
		crafting_toggled.emit(false)
	if map_active:
		map_active = false
		map_toggled.emit(false)
	
	if player_node and player_node.has_method("set_movement_enabled"):
		player_node.set_movement_enabled(true)
		
	fog_effect_toggled.emit(false)
	
	print("⏎ ESC: %s → GAME" % UIState.keys()[old_state])

func close_pause_menu():
	if menu_pause_active:
		menu_pause_active = false
		menu_pause_toggled.emit(false)
		fog_effect_toggled.emit(false)
		
		if player_node and player_node.has_method("set_movement_enabled"):
			player_node.set_movement_enabled(true)
		
		print("🎮 Menu Pause закрыто через Continue | Движение восстановлено")

# ============================================
# STATUS CAMERA
# ============================================
func _update_system_press_time(delta: float) -> void:
	if status_pressing:
		status_pressed_time += delta
		if Input.is_action_just_released("toggle_tabs"):
			if status_pressed_time < 0.5:
				_toggle_status_notifier()
			else:
				_toggle_status_camera()
			status_pressing = false

func _handle_camera_status() -> void:
	if Input.is_action_just_pressed("toggle_tabs"):
		status_pressed_time = 0.0
		status_pressing = true
	if Input.is_action_just_pressed("Status"):
		_toggle_status_camera()

func _toggle_status_notifier() -> void:
	status_notifier = !status_notifier
	label_debug.text = "Status Notifier: %s" % ("ON" if status_notifier else "OFF")

func _toggle_status_camera() -> void:
	if menu_pause_active:
		print("⚠️ Нельзя открыть STATUS - активна Menu Pause")
		return
	_switch_to_tabs_state(UIState.STATUS)

# ============================================
# 🔥 ОБРАБОТКА КЛИКОВ С УЛУЧШЕННЫМ ИНДИКАТОРОМ
# ============================================
func _handle_right_click(delta: float) -> void:
	if Input.is_action_just_pressed("Mouse_Right_Button"):
		right_click_duration = 0.0
		is_running = false
		_set_target_from_raycast()
		player_node.set_movement_speed(player_node.walk_speed)
	
	if Input.is_action_pressed("Mouse_Right_Button"):
		right_click_duration += delta
		_set_target_from_raycast()

		if right_click_duration > RUN_TRIGGER_TIME and not is_running:
			is_running = true
			player_node.set_movement_speed(player_node.run_speed)
			
			# 🔥 Обновляем цвет индикатора на оранжевый (бег)
			if target_indicator and target_indicator.is_visible:
				target_indicator.show_at_position(target_indicator.global_position, true)
	
	if Input.is_action_just_released("Mouse_Right_Button"):
		right_click_duration = 0.0
		is_running = false

func _handle_left_click() -> void:
	if Input.is_action_just_pressed("Mouse_Left_Button"):
		player_node.stop_moving(true)
		right_click_duration = 0.0
		is_running = false
		
		# 🔥 Скрываем индикатор
		if target_indicator:
			target_indicator.hide_indicator()

func _set_target_from_raycast() -> void:
	if not camera:
		return
	
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)
	var ray_end = ray_origin + ray_direction * 1000.0
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collision_mask = 1 << (GROUND_LAYER - 1)
	
	var result = get_world_3d().direct_space_state.intersect_ray(query)
	
	if result:
		var collider = result.collider
		
		if collider.is_in_group("ground"):
			# ✅ Валидная поверхность
			player_node.move_to_position(result.position)
			
			# 🔥 Показываем красивый индикатор
			if target_indicator:
				target_indicator.show_at_position(result.position, is_running)
		else:
			_handle_invalid_click(collider, "не в группе 'ground'")
	else:
		_handle_invalid_click(null, "не является ground")

func _handle_invalid_click(collider, reason: String) -> void:
	# Останавливаем игрока
	if player_node and player_node.has_method("stop_moving"):
		player_node.stop_moving(true)
	
	# 🔥 Показываем красный голографический индикатор ошибки
	if target_indicator and camera:
		var mouse_pos = get_viewport().get_mouse_position()
		var ray_origin = camera.project_ray_origin(mouse_pos)
		var ray_direction = camera.project_ray_normal(mouse_pos)
		var ray_end = ray_origin + ray_direction * 1000.0
		
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		var result = get_world_3d().direct_space_state.intersect_ray(query)
		
		if result:
			target_indicator.show_invalid_click(result.position)
	
	# Звук ошибки (добавь sci-fi звук!)
	if error_sound:
		error_sound.play()
	
	if collider:
		print("⛔ Клик по объекту '%s' (%s)" % [collider.name, reason])
	else:
		print("⛔ Клик по объекту, который %s" % reason)

# ============================================
# КОЛЛБЭКИ ДВИЖЕНИЯ
# ============================================
func _on_movement_started() -> void:
	# Индикатор уже показан через show_at_position()
	if orbital_particles:
		orbital_particles.deactivate()

func _on_movement_stopped() -> void:
	# 🔥 Скрываем индикатор с анимацией
	if target_indicator:
		target_indicator.hide_indicator()
	if orbital_particles:
		orbital_particles.activate()

# ============================================
# UI
# ============================================
func _update_ui() -> void:
	var status_text = _get_status_text()
	var speed = player_node.get_current_speed()
	
	if status_camera_active:
		label_actives.text = "STATUS CAMERA ACTIVE | скорость: %.1f" % speed
	elif menu_pause_active:
		label_actives.text = "MENU PAUSE ACTIVE | скорость: %.1f" % speed
	else:
		label_actives.text = "%s | скорость: %.1f" % [status_text, speed]

func _get_status_text() -> String:
	if right_click_duration > RUN_TRIGGER_TIME:
		return "зажата ПКМ"
	return player_node.get_state_name()

func _switch_to_tabs_state(new_state: UIState):
	var old_state = current_ui_state
	current_ui_state = new_state
	
	status_camera_active = false
	inventory_active = false
	crafting_active = false
	map_active = false
	
	match new_state:
		UIState.STATUS:
			status_camera_active = true
			status_camera_toggled.emit(true)
		UIState.INVENTORY:
			inventory_active = true
			inventory_toggled.emit(true)
		UIState.CRAFTING:
			crafting_active = true
			crafting_toggled.emit(true)
		UIState.MAP:
			map_active = true
			map_toggled.emit(true)
	
	status_notifier = false
	print("🔄 Хоткей: %s → %s" % [UIState.keys()[old_state], UIState.keys()[new_state]])

func print_input_state() -> void:
	print("=== INPUT MANAGER STATE ===")
	print("menu_pause_active: ", menu_pause_active)
	print("status_camera_active: ", status_camera_active)
	print("Player movement enabled: ", player_node.has_method("is_movement_enabled") and player_node.is_movement_enabled() if player_node else "N/A")
	print("===========================")
