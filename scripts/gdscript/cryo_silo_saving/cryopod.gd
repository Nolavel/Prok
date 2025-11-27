extends Node3D

# === СОСТОЯНИЯ КАПСУЛЫ ===
enum CapsuleState {
	CLOSED,
	OPENING,
	OPEN,
	CLOSING,
	SLEEP_MODE
}

# === СИГНАЛЫ ===
signal capsule_state_changed(new_state: CapsuleState)
signal player_in_capsule_range_changed(is_in_range: bool)
signal player_inside_capsule_changed(is_inside: bool)
signal sleep_initiated()  # Сигнал для запуска последовательности засыпания

# === ССЫЛКИ ===
@onready var anima: AnimationPlayer = $anima
@onready var interaction_area: Area3D = $interaction_area
@onready var area_capsule: Area3D = $Area_Capsule
@export var collision_ground: CollisionShape3D
@export var silo: Node3D  # Ссылка на Cryo_Silo

# === СОСТОЯНИЕ ===
var current_state: CapsuleState = CapsuleState.CLOSED
var player_in_range: bool = false
var player_inside_capsule: bool = false

func _ready() -> void:
	_change_state(CapsuleState.CLOSED)
	
	# Зона взаимодействия с криоподом
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_entered)
		interaction_area.body_exited.connect(_on_interaction_exited)
		print("✅ Cryopod: interaction_area подключена")
	else:
		push_error("❌ interaction_area не найдена!")
	
	# Зона внутри капсулы
	if area_capsule:
		area_capsule.body_entered.connect(_on_capsule_entered)
		area_capsule.body_exited.connect(_on_capsule_exited)
		print("✅ Area_Capsule подключена")
	else:
		push_error("❌ Area_Capsule не найдена!")
	
	# ДИНАМИЧЕСКИЙ ПОИСК СИЛО (если не назначен)
	call_deferred("_find_silo")

func _find_silo() -> void:
	if not silo:
		silo = get_tree().root.find_child("Cryo_Silo", true, false)
		if silo:
			print("🔍 Cryopod: Silo найден динамически - ", silo.name)
		else:
			push_error("❌ Cryopod: Silo не найден! Последовательность засыпания не будет работать!")

# === СМЕНА СОСТОЯНИЯ ===
func _change_state(new_state: CapsuleState) -> void:
	current_state = new_state
	capsule_state_changed.emit(new_state)
	print("🔄 Capsule State: ", CapsuleState.keys()[new_state])

# === ПУБЛИЧНЫЙ МЕТОД ДЛЯ ПОЛУЧЕНИЯ ТЕКУЩЕГО СОСТОЯНИЯ ===
func get_current_state() -> CapsuleState:
	return current_state

# === ПУБЛИЧНЫЙ МЕТОД ДЛЯ UI ===
func on_button_pressed() -> void:
	match current_state:
		CapsuleState.CLOSED:
			_open_capsule()
		CapsuleState.OPEN:
			if player_inside_capsule:
				_initiate_sleep()
			else:
				_close_capsule()

# === ОТКРЫТИЕ КАПСУЛЫ ===
func _open_capsule() -> void:
	_change_state(CapsuleState.OPENING)
	anima.play("open_cryopod")
	await anima.animation_finished
	_change_state(CapsuleState.OPEN)
	_update_ground_collision()  # Включаем пол (капсула открыта)
	print("🔓 Капсула открыта")

# === ЗАКРЫТИЕ КАПСУЛЫ ===
func _close_capsule() -> void:
	_change_state(CapsuleState.CLOSING)
	anima.play_backwards("open_cryopod")
	await anima.animation_finished
	_change_state(CapsuleState.CLOSED)
	_update_ground_collision()  # Обновляем коллизию (зависит от положения игрока)
	print("🔒 Капсула закрыта")

# === ИНИЦИАЛИЗАЦИЯ СНА ===
func _initiate_sleep() -> void:
	print("💤 ========== НАЧИНАЕМ ПОСЛЕДОВАТЕЛЬНОСТЬ ЗАСЫПАНИЯ ==========")
	_change_state(CapsuleState.SLEEP_MODE)
	
	# ВАЖНО: Сразу отключаем коллизию пола перед закрытием капсулы
	_update_ground_collision()
	
	# Закрываем капсулу
	print("🔒 Закрываем капсулу...")
	anima.play_backwards("open_cryopod")
	await anima.animation_finished
	print("✅ Капсула закрыта")
	
	# КРИТИЧЕСКИ ВАЖНО: Ищем Silo если его нет
	print("🔍 Проверяем наличие Silo... silo=", silo)
	if not silo:
		print("⚠️ Silo не найден, ищем динамически...")
		silo = get_tree().root.find_child("Cryo_Silo", true, false)
		if silo:
			print("🔍 Cryopod: Silo найден для засыпания - ", silo.name)
		else:
			print("❌❌❌ КРИТИЧЕСКАЯ ОШИБКА: Silo НЕ НАЙДЕН!")
	
	# Отправляем сигнал в Silo для запуска полной последовательности
	if silo:
		print("✅ Silo найден: ", silo.name)
		if silo.has_method("start_sleep_sequence"):
			print("📞 Вызываем silo.start_sleep_sequence()...")
			await silo.start_sleep_sequence()
			print("✅ Последовательность сило завершена")
		else:
			print("❌❌❌ У Silo НЕТ метода start_sleep_sequence!")
	else:
		print("❌❌❌ Silo = null! Не могу опустить капсулы и сило!")
	
	# ✅ ИСПРАВЛЕНИЕ БАГА #1: После завершения последовательности сбрасываем ВСЕ флаги
	# Это нужно для того, чтобы UI корректно показала кнопку "Поднять Сило"
	print("🔄 Сбрасываем флаги игрока для корректного отображения UI")
	player_inside_capsule = false
	player_inside_capsule_changed.emit(false)
	
	# КРИТИЧЕСКИ ВАЖНО: Также сбрасываем флаг "в зоне капсулы"
	player_in_range = false
	player_in_capsule_range_changed.emit(false)
	print("✅ Все флаги капсулы сброшены - UI должен показать только 'Поднять Сило'")
	
	# После завершения возвращаемся в закрытое состояние
	_change_state(CapsuleState.CLOSED)
	# ✅ НЕ ВЫЗЫВАЕМ _update_ground_collision() - пол должен остаться ВЫКЛЮЧЕН
	# Пол включится только когда капсула откроется после подъёма
	print("💤 ========== ПОСЛЕДОВАТЕЛЬНОСТЬ ЗАСЫПАНИЯ ЗАВЕРШЕНА ==========")

# === ЗОНА ВЗАИМОДЕЙСТВИЯ С КРИОПОДОМ ===
func _on_interaction_entered(body: Node3D) -> void:
	if body.name == "Player":
		player_in_range = true
		player_in_capsule_range_changed.emit(true)
		print("👤 Игрок вошёл в зону взаимодействия капсулы")

func _on_interaction_exited(body: Node3D) -> void:
	if body.name == "Player":
		player_in_range = false
		player_in_capsule_range_changed.emit(false)
		print("🚶 Игрок вышел из зоны взаимодействия капсулы")

# === ЗОНА ВНУТРИ КАПСУЛЫ ===
func _on_capsule_entered(body: Node3D) -> void:
	if body.name == "Player":
		player_inside_capsule = true
		player_inside_capsule_changed.emit(true)
		_update_ground_collision()
		print("🚪 Игрок внутри капсулы")

func _on_capsule_exited(body: Node3D) -> void:
	if body.name == "Player":
		player_inside_capsule = false
		player_inside_capsule_changed.emit(false)
		# ✅ НЕ ОБНОВЛЯЕМ КОЛЛИЗИЮ если капсула закрыта (игрок внутри закрытой капсулы)
		# Это предотвращает включение пола когда сило поднимается с игроком внутри
		if current_state != CapsuleState.CLOSED:
			_update_ground_collision()
		print("🚪 Игрок вышел из капсулы")

# === УПРАВЛЕНИЕ КОЛЛИЗИЕЙ ПОЛА ===
func _update_ground_collision() -> void:
	if not collision_ground:
		return
	
	# ✅ ЛОГИКА:
	# ПОЛ ВЫКЛЮЧЕН: Когда игрок внутри И уходит в сон (SLEEP_MODE)
	# ПОЛ ВКЛЮЧЕН: По умолчанию во всех остальных случаях
	
	var disable_ground := false  # По умолчанию пол ВКЛЮЧЕН
	
	if current_state == CapsuleState.SLEEP_MODE and player_inside_capsule:
		# Игрок внутри капсулы и нажал "Уйти в сон" - ВЫКЛЮЧАЕМ пол
		disable_ground = true
		print("🔧 Коллизия пола: ВЫКЛ (засыпание)")
	else:
		# Во всех остальных случаях - ВКЛЮЧАЕМ пол
		disable_ground = false
		print("🔧 Коллизия пола: ВКЛ")
	
	collision_ground.set_deferred("disabled", disable_ground)
