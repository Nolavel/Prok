## ============================================
## CRYO_UI_CONTROLLER.gd - Контроллер UI (ФИНАЛЬНАЯ ВЕРСИЯ)
## ============================================
extends Control
class_name CryoUIController

@onready var vbox: VBoxContainer = $VBox

# Кнопки
@onready var btn_computer: Button = $VBox/BtnComputer
@onready var btn_silo: Button = $VBox/BtnSilo
@onready var btn_capsules: Button = $VBox/BtnCapsules
@onready var btn_capsule_1: Button = $VBox/BtnCapsule1
@onready var btn_capsule_2: Button = $VBox/BtnCapsule2
@onready var btn_capsule_3: Button = $VBox/BtnCapsule3
@onready var btn_sleep_wake: Button = $VBox/BtnSleepWake

# Компоненты
var control_panel: ControlPanel
var silo_manager: CryoSiloManager

var active_cryopod: CryoPod = null
var player_at_panel: bool = false
var is_initialized: bool = false

func _ready() -> void:
	visible = false
	_hide_all_buttons()
	
	# Подключаем кнопки
	btn_computer.pressed.connect(_on_computer_pressed)
	btn_silo.pressed.connect(_on_silo_pressed)
	btn_capsules.pressed.connect(_on_capsules_pressed)
	btn_capsule_1.pressed.connect(_on_capsule_1_pressed)
	btn_capsule_2.pressed.connect(_on_capsule_2_pressed)
	btn_capsule_3.pressed.connect(_on_capsule_3_pressed)
	btn_sleep_wake.pressed.connect(_on_sleep_wake_pressed)
	
	print("🔍 UI: Начинаем поиск компонентов...")
	
	# Ждём загрузки сцены
	await get_tree().process_frame
	await get_tree().process_frame
	
	_find_components()
	_connect_signals()
	
	print("✅ Cryo UI Controller: Инициализирован")

## === АВТОПОИСК КОМПОНЕНТОВ ===
func _find_components() -> void:
	var root = get_tree().current_scene
	
	control_panel = _find_node_by_type(root, ControlPanel)
	if control_panel:
		print("✅ UI: ControlPanel найдена: %s" % control_panel.name)
	else:
		print("❌ UI: ControlPanel НЕ найдена!")
	
	silo_manager = _find_node_by_type(root, CryoSiloManager)
	if silo_manager:
		print("✅ UI: SiloManager найден: %s" % silo_manager.name)
	else:
		print("❌ UI: SiloManager НЕ найден!")

func _find_node_by_type(node: Node, type) -> Node:
	if is_instance_of(node, type):
		return node
	for child in node.get_children():
		var result = _find_node_by_type(child, type)
		if result:
			return result
	return null

## === ПОДКЛЮЧЕНИЕ СИГНАЛОВ ===
func _connect_signals() -> void:
	if not control_panel or not silo_manager:
		print("⚠️ UI: Отсутствуют необходимые компоненты")
		return
	
	# Подключаем панель управления
	control_panel.player_entered_control_zone.connect(_on_player_at_panel)
	control_panel.player_exited_control_zone.connect(_on_player_left_panel)
	control_panel.computer_activated.connect(_on_computer_activated)
	control_panel.computer_deactivated.connect(_on_computer_deactivated)
	print("✅ UI: Подключена к ControlPanel")
	
	# Подключаем менеджер
	silo_manager.silo_state_changed.connect(_on_silo_state_changed)
	silo_manager.capsules_state_changed.connect(_on_capsules_state_changed)
	silo_manager.animation_started.connect(_on_animation_started)
	silo_manager.animation_finished.connect(_on_animation_finished)
	print("✅ UI: Подключена к SiloManager")
	
	# Подключаем капсулы
	if silo_manager.cryopod_1:
		silo_manager.cryopod_1.player_entered_capsule.connect(_on_player_entered_capsule)
		silo_manager.cryopod_1.player_exited_capsule.connect(_on_player_exited_capsule)
		silo_manager.cryopod_1.capsule_state_changed.connect(_on_capsule_changed)
		print("✅ UI: Подключена к Cryopod 1")
	
	if silo_manager.cryopod_2:
		silo_manager.cryopod_2.player_entered_capsule.connect(_on_player_entered_capsule)
		silo_manager.cryopod_2.player_exited_capsule.connect(_on_player_exited_capsule)
		silo_manager.cryopod_2.capsule_state_changed.connect(_on_capsule_changed)
		print("✅ UI: Подключена к Cryopod 2")
	
	if silo_manager.cryopod_3:
		silo_manager.cryopod_3.player_entered_capsule.connect(_on_player_entered_capsule)
		silo_manager.cryopod_3.player_exited_capsule.connect(_on_player_exited_capsule)
		silo_manager.cryopod_3.capsule_state_changed.connect(_on_capsule_changed)
		print("✅ UI: Подключена к Cryopod 3")
	
	is_initialized = true

## === ОБРАБОТЧИКИ КНОПОК ===
func _on_computer_pressed() -> void:
	print("🖱️ UI: Нажата кнопка компьютера")
	if control_panel:
		control_panel.toggle_computer()

func _on_silo_pressed() -> void:
	print("🖱️ UI: Нажата кнопка сило")
	if silo_manager:
		silo_manager.toggle_silo()

func _on_capsules_pressed() -> void:
	print("🖱️ UI: Нажата кнопка капсул")
	if silo_manager:
		silo_manager.toggle_capsules()

func _on_capsule_1_pressed() -> void:
	print("🖱️ UI: Нажата кнопка капсулы 1")
	if silo_manager and silo_manager.cryopod_1:
		await silo_manager.cryopod_1.toggle_capsule()

func _on_capsule_2_pressed() -> void:
	print("🖱️ UI: Нажата кнопка капсулы 2")
	if silo_manager and silo_manager.cryopod_2:
		await silo_manager.cryopod_2.toggle_capsule()

func _on_capsule_3_pressed() -> void:
	print("🖱️ UI: Нажата кнопка капсулы 3")
	if silo_manager and silo_manager.cryopod_3:
		await silo_manager.cryopod_3.toggle_capsule()

func _on_sleep_wake_pressed() -> void:
	print("🖱️ UI: Нажата кнопка сон/пробуждение")
	if not active_cryopod or not silo_manager:
		return
	
	if active_cryopod.player_inside:
		active_cryopod.disable_ground_collision()
		await silo_manager.start_sleep_sequence(active_cryopod)
	else:
		await silo_manager.start_wake_sequence(active_cryopod)
		active_cryopod.enable_ground_collision()

## === ОБРАБОТЧИКИ СИГНАЛОВ ===
func _on_player_at_panel() -> void:
	player_at_panel = true
	visible = true
	btn_computer.visible = true
	print("🖥️ UI: Игрок у панели - показываем кнопку компьютера")

func _on_player_left_panel() -> void:
	player_at_panel = false
	# ИСПРАВЛЕНИЕ: Если компьютер выключен - скрываем UI
	if control_panel and not control_panel.is_computer_on:
		visible = false
		print("🖥️ UI: Игрок отошёл - скрываем UI")
	else:
		# Если компьютер включён - скрываем только кнопку компьютера
		btn_computer.visible = false
		print("🖥️ UI: Игрок отошёл, но компьютер включён - управление остаётся")

func _on_computer_activated() -> void:
	print("💻 UI: Компьютер ВКЛЮЧЁН - показываем управление")
	btn_computer.text = "Выключить компьютер"
	btn_computer.visible = player_at_panel  # Показываем только если игрок у панели
	_update_ui()

func _on_computer_deactivated() -> void:
	print("💻 UI: Компьютер ВЫКЛЮЧЕН - скрываем управление")
	btn_computer.text = "Включить компьютер"
	_hide_all_buttons()
	btn_computer.visible = player_at_panel
	
	# НОВОЕ: Если игрок отошёл - полностью скрываем UI
	if not player_at_panel:
		visible = false

func _on_silo_state_changed(is_raised: bool) -> void:
	btn_silo.text = "Опустить сило" if is_raised else "Поднять сило"
	_update_ui()

func _on_capsules_state_changed(are_raised: bool) -> void:
	btn_capsules.text = "Опустить капсулы" if are_raised else "Поднять капсулы"
	_update_ui()

func _on_capsule_changed(is_open: bool, capsule_id: int) -> void:
	print("📡 UI: Капсула %d изменилась: %s" % [capsule_id, "открыта" if is_open else "закрыта"])
	_update_ui()

func _on_animation_started() -> void:
	_lock_all_buttons(true)

func _on_animation_finished() -> void:
	_lock_all_buttons(false)
	_update_ui()

func _on_player_entered_capsule(capsule_id: int) -> void:
	match capsule_id:
		1: active_cryopod = silo_manager.cryopod_1
		2: active_cryopod = silo_manager.cryopod_2
		3: active_cryopod = silo_manager.cryopod_3
	print("🛏️ UI: Игрок в капсуле %d" % capsule_id)
	_update_ui()

func _on_player_exited_capsule(capsule_id: int) -> void:
	active_cryopod = null
	print("🚪 UI: Игрок вышел из капсулы")
	_update_ui()

## === ОБНОВЛЕНИЕ UI ===
func _update_ui() -> void:
	if not is_initialized or not silo_manager or not control_panel:
		return
	
	var computer_on = control_panel.is_computer_on
	var caps_raised = silo_manager.are_capsules_raised
	
	# Если компьютер выключен - скрываем всё кроме кнопки компьютера
	if not computer_on:
		_hide_all_buttons()
		btn_computer.visible = player_at_panel
		return
	
	# Компьютер включён - показываем управление только если игрок у панели
	if player_at_panel:
		btn_computer.visible = true
	else:
		btn_computer.visible = false
	
	btn_silo.visible = true
	btn_capsules.visible = true
	
	# Кнопки капсул видны только если капсулы подняты
	btn_capsule_1.visible = caps_raised
	btn_capsule_2.visible = caps_raised
	btn_capsule_3.visible = caps_raised
	
	# Кнопка сон/пробуждение видна только когда игрок внутри капсулы
	btn_sleep_wake.visible = (active_cryopod != null and active_cryopod.player_inside)
	
	# Обновляем текст кнопок капсул
	if silo_manager.cryopod_1:
		btn_capsule_1.text = "Закрыть капсулу 1" if silo_manager.cryopod_1.is_open else "Открыть капсулу 1"
	if silo_manager.cryopod_2:
		btn_capsule_2.text = "Закрыть капсулу 2" if silo_manager.cryopod_2.is_open else "Открыть капсулу 2"
	if silo_manager.cryopod_3:
		btn_capsule_3.text = "Закрыть капсулу 3" if silo_manager.cryopod_3.is_open else "Открыть капсулу 3"
	
	if active_cryopod and active_cryopod.player_inside:
		btn_sleep_wake.text = "Уйти в сон"

func _hide_all_buttons() -> void:
	btn_silo.visible = false
	btn_capsules.visible = false
	btn_capsule_1.visible = false
	btn_capsule_2.visible = false
	btn_capsule_3.visible = false
	btn_sleep_wake.visible = false

func _lock_all_buttons(locked: bool) -> void:
	btn_computer.disabled = locked
	btn_silo.disabled = locked
	btn_capsules.disabled = locked
	btn_capsule_1.disabled = locked
	btn_capsule_2.disabled = locked
	btn_capsule_3.disabled = locked
	btn_sleep_wake.disabled = locked
