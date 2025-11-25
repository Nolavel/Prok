extends CanvasLayer

# === КНОПКИ ===
@export var btn_hud: Button
@export var btn_return: Button
@export var btn_status: Button
@export var btn_inventory: Button
@export var btn_crafting: Button
@export var btn_map: Button

@export var btn_rotate_left: Button
@export var btn_rotate_right: Button

# === UI ЭЛЕМЕНТЫ ===
@onready var face_player = $Face_player
@onready var tabs_interface = $TABS_INTERFACE
@onready var current_tabs = $TABS_INTERFACE/lbl_current_tabs

# === ССЫЛКИ ===
@export var input_manager: NodePath
@export var camera: NodePath
var input_manager_node: Node
var camera_node: Camera3D

# === СИГНАЛЫ ===
signal status_camera_toggled(status_is_active: bool)
signal inventory_camera_toggled(inventory_is_active: bool)
signal crafting_camera_toggled(crafting_is_active: bool)
signal map_camera_toggled(map_is_active: bool)

# === СОСТОЯНИЯ ===
enum UIState { GAME, STATUS, INVENTORY, CRAFTING, MAP }
var current_state: UIState = UIState.GAME
var menu_pause_active: bool = false

func _ready() -> void:
	tabs_interface.visible = false
	
	# Инициализируем кнопки rotate как скрытые
	btn_rotate_left.visible = false
	btn_rotate_right.visible = false
	
	# Подключаем кнопки
	btn_hud.pressed.connect(_on_hud_pressed)
	btn_return.pressed.connect(_on_return_pressed)
	btn_status.pressed.connect(_on_status_pressed)
	btn_inventory.pressed.connect(_on_inventory_pressed)
	btn_crafting.pressed.connect(_on_crafting_pressed)
	btn_map.pressed.connect(_on_map_pressed)
	
	# Подключаем кнопки орбитального вращения
	btn_rotate_left.button_down.connect(_on_rotate_left_pressed)
	btn_rotate_left.button_up.connect(_on_rotate_stopped)
	btn_rotate_right.button_down.connect(_on_rotate_right_pressed)
	btn_rotate_right.button_up.connect(_on_rotate_stopped)
	
	# Подключаемся к InputManager
	if input_manager:
		input_manager_node = get_node(input_manager)
		if input_manager_node:
			input_manager_node.status_camera_toggled.connect(_on_input_manager_status_toggled)
			input_manager_node.menu_pause_toggled.connect(_on_menu_pause_toggled)
			input_manager_node.inventory_toggled.connect(_on_input_manager_inventory_toggled)
			input_manager_node.crafting_toggled.connect(_on_input_manager_crafting_toggled)
			input_manager_node.map_toggled.connect(_on_input_manager_map_toggled)
			print("✅ HUD: Подключен к InputManager (STATUS, INVENTORY, CRAFTING)")
		else:
			push_error("❌ InputManager node not found!")
	
	# Подключаемся к камере
	if camera:
		camera_node = get_node(camera)
		if camera_node:
			print("✅ HUD: Подключен к Camera")
		else:
			push_error("❌ Camera node not found!")
	
	_update_ui()

# ============================================
# ОБРАБОТЧИКИ МЕНЮ ПАУЗЫ (ПРИОРИТЕТ)
# ============================================
func _on_menu_pause_toggled(active: bool) -> void:
	menu_pause_active = active
	
	if active:
		print("🎮 HUD: Menu Pause открыта - скрываем TABS")
		if tabs_interface.visible:
			_animate_hide(tabs_interface)
		current_tabs.text = ""
	else:
		print("🎮 HUD: Menu Pause закрыта - восстанавливаем TABS если нужно")
		if current_state != UIState.GAME:
			_animate_show(tabs_interface)
	
	_update_ui()

# ============================================
# ОБРАБОТЧИКИ КНОПОК
# ============================================
func _on_hud_pressed():
	if menu_pause_active:
		print("⚠️ Нельзя открыть STATUS - активна Menu Pause")
		return
	
	if current_state == UIState.GAME:
		_switch_to_state(UIState.STATUS)

func _on_return_pressed():
	if current_state != UIState.GAME:
		_switch_to_state(UIState.GAME)

func _on_status_pressed():
	if menu_pause_active:
		print("⚠️ Нельзя переключиться на STATUS - активна Menu Pause")
		return
	
	if current_state != UIState.STATUS:
		_switch_to_state(UIState.STATUS)

func _on_inventory_pressed():
	if menu_pause_active:
		print("⚠️ Нельзя открыть Inventory - активна Menu Pause")
		return
	
	if current_state != UIState.INVENTORY:
		_switch_to_state(UIState.INVENTORY)

func _on_crafting_pressed():
	if menu_pause_active:
		print("⚠️ Нельзя открыть Crafting - активна Menu Pause")
		return
	
	if current_state != UIState.CRAFTING:
		_switch_to_state(UIState.CRAFTING)
		
func _on_map_pressed():
	if menu_pause_active:
		print("⚠️ Нельзя открыть MAP - активна Menu Pause")
		return
	
	if current_state != UIState.MAP:
		_switch_to_state(UIState.MAP)

# ============================================
# ОБРАБОТЧИКИ СИГНАЛОВ ОТ INPUTMANAGER (ХОТКЕИ)
# ============================================
func _on_input_manager_status_toggled(active: bool) -> void:
	if menu_pause_active and active:
		print("⚠️ Нельзя открыть STATUS через хоткей - активна Menu Pause")
		return
	
	if active:
		_switch_to_state(UIState.STATUS)
	else:
		_switch_to_state(UIState.GAME)

func _on_input_manager_inventory_toggled(active: bool) -> void:
	if menu_pause_active and active:
		print("⚠️ Нельзя открыть INVENTORY через хоткей - активна Menu Pause")
		return
	
	if active:
		_switch_to_state(UIState.INVENTORY)
	else:
		_switch_to_state(UIState.GAME)

func _on_input_manager_crafting_toggled(active: bool) -> void:
	if menu_pause_active and active:
		print("⚠️ Нельзя открыть CRAFTING через хоткей - активна Menu Pause")
		return
	
	if active:
		_switch_to_state(UIState.CRAFTING)
	else:
		_switch_to_state(UIState.GAME)
		
func _on_input_manager_map_toggled(active: bool) -> void:
	if menu_pause_active and active:
		print("⚠️ Нельзя открыть MAP через хоткей - активна Menu Pause")
		return
	
	if active:
		_switch_to_state(UIState.MAP)
	else:
		_switch_to_state(UIState.GAME)

# ============================================
# ОБРАБОТЧИКИ ОРБИТАЛЬНОГО ВРАЩЕНИЯ
# ============================================
func _on_rotate_left_pressed():
	if not camera_node:
		return
	if camera_node.has_method("start_status_orbit_left"):
		camera_node.start_status_orbit_left()

func _on_rotate_right_pressed():
	if not camera_node:
		return
	if camera_node.has_method("start_status_orbit_right"):
		camera_node.start_status_orbit_right()

func _on_rotate_stopped():
	if not camera_node:
		return
	if camera_node.has_method("stop_status_orbit"):
		camera_node.stop_status_orbit()

# ============================================
# СИСТЕМА ПЕРЕКЛЮЧЕНИЯ СОСТОЯНИЙ
# ============================================
func _switch_to_state(new_state: UIState) -> void:
	if new_state == current_state:
		return
	
	var old_state = current_state
	current_state = new_state
	
	# Отправляем сигналы камере
	match new_state:
		UIState.STATUS:
			status_camera_toggled.emit(true)
		UIState.INVENTORY:
			inventory_camera_toggled.emit(true)
		UIState.CRAFTING:
			crafting_camera_toggled.emit(true)
		UIState.MAP:
			map_camera_toggled.emit(true)	
		UIState.GAME:
			# Закрываем предыдущее состояние
			match old_state:
				UIState.STATUS:
					status_camera_toggled.emit(false)
				UIState.INVENTORY:
					inventory_camera_toggled.emit(false)
				UIState.CRAFTING:
					crafting_camera_toggled.emit(false)
				UIState.MAP:
					map_camera_toggled.emit(false)
	
	_update_ui()
	
	print("🎬 HUD: %s → %s" % [UIState.keys()[old_state], UIState.keys()[new_state]])

# ============================================
# ОБНОВЛЕНИЕ UI
# ============================================
func _update_ui() -> void:
	# Если активна Menu Pause - скрываем всё кроме неё
	if menu_pause_active:
		_animate_hide(btn_hud)
		_animate_hide(face_player)
		_animate_hide(tabs_interface)
		# 🔥 ВАЖНО: Принудительно скрываем rotate кнопки
		btn_rotate_left.visible = false
		btn_rotate_right.visible = false
		return
	
	# Обычная логика состояний
	match current_state:
		UIState.GAME:
			_animate_hide(current_tabs)
			_animate_show(btn_hud)
			_animate_show(face_player)
			_animate_hide(tabs_interface)
			# 🔥 ВАЖНО: Принудительно скрываем rotate в GAME
			btn_rotate_left.visible = false
			btn_rotate_right.visible = false
			current_tabs.text = ""
		
		UIState.STATUS:
			_animate_hide(btn_hud)
			_animate_hide(face_player)
			_animate_show(tabs_interface)
			_animate_show(current_tabs)
			_update_tab_buttons_disabled(btn_status)
			$TABS_INTERFACE/BoxBtnsConfigurate/anima_btn_highlighting.play("btn_status_activated")
			# 🔥 ВАЖНО: Показываем rotate ТОЛЬКО здесь
			$TABS_INTERFACE/HBoxContainer2/anima_rotate_btn.play("anima_rotate_btn")
			_animate_show(btn_rotate_left)
			_animate_show(btn_rotate_right)
			current_tabs.text = "STATUS"
		
		UIState.INVENTORY:
			_animate_hide(btn_hud)
			_animate_hide(face_player)
			_animate_show(tabs_interface)
			_update_tab_buttons_disabled(btn_inventory)
			$TABS_INTERFACE/BoxBtnsConfigurate/anima_btn_highlighting.play("btn_invetory_activated")
			# 🔥 ВАЖНО: Принудительно скрываем rotate
			btn_rotate_left.visible = false
			btn_rotate_right.visible = false
			current_tabs.text = "INVENTORY"
		
		UIState.CRAFTING:
			_animate_hide(btn_hud)
			_animate_hide(face_player)
			_animate_show(tabs_interface)
			_animate_show(current_tabs)
			_update_tab_buttons_disabled(btn_crafting)
			$TABS_INTERFACE/BoxBtnsConfigurate/anima_btn_highlighting.play("btn_crafting_activated")
			# 🔥 ВАЖНО: Принудительно скрываем rotate
			btn_rotate_left.visible = false
			btn_rotate_right.visible = false
			current_tabs.text = "CRAFTING"
		UIState.MAP:
			_animate_hide(btn_hud)
			_animate_hide(face_player)
			_animate_show(tabs_interface)
			_animate_show(current_tabs)
			_update_tab_buttons_disabled(btn_map)
			$TABS_INTERFACE/BoxBtnsConfigurate/anima_btn_highlighting.play("btn_map_activated")
			# 🔥 ВАЖНО: Принудительно скрываем rotate
			btn_rotate_left.visible = false
			btn_rotate_right.visible = false
			current_tabs.text = "MAP"

# 🔥 НОВАЯ ФУНКЦИЯ: Делаем активную кнопку disabled, остальные enabled
func _update_tab_buttons_disabled(active_button: Button) -> void:
	var all_buttons = [btn_status, btn_inventory, btn_crafting, btn_map]
	
	for btn in all_buttons:
		btn.visible = true  # Все кнопки видимы
		if btn == active_button:
			btn.disabled = true   # Активная кнопка неактивна
		else:
			btn.disabled = false  # Остальные кликабельны

# ============================================
# АНИМАЦИИ
# ============================================
func _animate_show(node: CanvasItem) -> void:
	if node.visible and node.modulate.a > 0.9:
		return
	
	node.visible = true
	node.modulate.a = 0.0
	var tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate:a", 1.0, 0.6)

func _animate_hide(node: CanvasItem) -> void:
	if not node.visible:
		return
	
	var tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(node, "modulate:a", 0.0, 0.6)
	tw.finished.connect(func(): node.visible = false)

# ============================================
# ПУБЛИЧНЫЕ МЕТОДЫ
# ============================================
func force_close_tabs() -> void:
	"""Принудительное закрытие табов (например, при открытии диалога)"""
	if current_state != UIState.GAME:
		_switch_to_state(UIState.GAME)

func is_any_tab_open() -> bool:
	return current_state != UIState.GAME

func get_current_state() -> UIState:
	return current_state
