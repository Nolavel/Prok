## ============================================
## CRYO_SILO_MANAGER.gd - Главный менеджер системы (ИСПРАВЛЕНО)
## ============================================
extends Node3D
class_name CryoSiloManager

signal silo_state_changed(is_raised: bool)
signal capsules_state_changed(are_raised: bool)
signal animation_started
signal animation_finished
signal sleep_sequence_completed
signal wake_sequence_completed

@onready var animation_player: AnimationPlayer = $Anima
@onready var control_panel: ControlPanel = $ControlPanel

# Ссылки на капсулы
@export var cryopod_1: CryoPod
@export var cryopod_2: CryoPod
@export var cryopod_3: CryoPod

# Состояния системы
var is_silo_raised: bool = false
var are_capsules_raised: bool = false
var is_animating: bool = false

func _ready() -> void:
	# Начальное состояние - сило опущен
	animation_player.play("Cryo_Pit_Locked")
	is_silo_raised = false
	are_capsules_raised = false
	
	# Подключаем капсулы к менеджеру
	if cryopod_1:
		cryopod_1.capsule_state_changed.connect(_on_capsule_state_changed)
	if cryopod_2:
		cryopod_2.capsule_state_changed.connect(_on_capsule_state_changed)
	if cryopod_3:
		cryopod_3.capsule_state_changed.connect(_on_capsule_state_changed)
	
	print("✅ Cryo Silo Manager: Инициализирован")

## === УПРАВЛЕНИЕ СИЛО ===
func toggle_silo() -> void:
	if is_animating:
		print("⚠️ Анимация уже выполняется!")
		return
	
	# НОВАЯ ПРОВЕРКА: Нельзя опустить сило если капсулы подняты
	if is_silo_raised and are_capsules_raised:
		print("⚠️ Нельзя опустить сило - сначала опустите капсулы!")
		return
	
	is_animating = true
	animation_started.emit()
	
	if is_silo_raised:
		# Опускаем сило
		animation_player.play("down_caps")
		await animation_player.animation_finished
		is_silo_raised = false
		print("🔽 Сило опущен")
	else:
		# Поднимаем сило
		animation_player.play_backwards("down_caps")
		await animation_player.animation_finished
		is_silo_raised = true
		print("🔼 Сило поднят")
	
	is_animating = false
	animation_finished.emit()
	silo_state_changed.emit(is_silo_raised)

## === УПРАВЛЕНИЕ КАПСУЛАМИ (все 3 одновременно) ===
func toggle_capsules() -> void:
	if is_animating:
		print("⚠️ Анимация уже выполняется!")
		return
	
	# Проверка: нельзя поднять если сило опущен
	if not are_capsules_raised and not is_silo_raised:
		print("⚠️ Нельзя поднять капсулы - сначала поднимите сило!")
		return
	
	# Проверка: нельзя опустить, если хотя бы одна капсула открыта
	if are_capsules_raised and _any_capsule_open():
		print("⚠️ Нельзя опустить капсулы - одна из них открыта!")
		return
	
	is_animating = true
	animation_started.emit()
	
	if are_capsules_raised:
		# Опускаем капсулы
		animation_player.play_backwards("caps_3_move")
		await animation_player.animation_finished
		animation_player.play_backwards("caps_2_move")
		await animation_player.animation_finished
		animation_player.play_backwards("caps_1_move")
		await animation_player.animation_finished
		are_capsules_raised = false
		print("🔽 Капсулы опущены")
	else:
		# Поднимаем капсулы
		animation_player.play("caps_1_move")
		await animation_player.animation_finished
		animation_player.play("caps_2_move")
		await animation_player.animation_finished
		animation_player.play("caps_3_move")
		await animation_player.animation_finished
		are_capsules_raised = true
		print("🔼 Капсулы подняты")
	
	is_animating = false
	animation_finished.emit()
	capsules_state_changed.emit(are_capsules_raised)

## === ПОСЛЕДОВАТЕЛЬНОСТИ ===
func start_sleep_sequence(cryopod: CryoPod) -> void:
	if is_animating:
		return
	
	is_animating = true
	animation_started.emit()
	print("😴 Начало последовательности сна...")
	
	# 1. Закрыть капсулу
	if cryopod.is_open:
		await cryopod.close_capsule()
	
	# 2. Опустить капсулы
	if are_capsules_raised:
		animation_player.play_backwards("caps_3_move")
		await animation_player.animation_finished
		animation_player.play_backwards("caps_2_move")
		await animation_player.animation_finished
		animation_player.play_backwards("caps_1_move")
		await animation_player.animation_finished
		are_capsules_raised = false
	
	# 3. Опустить сило
	if is_silo_raised:
		animation_player.play("down_caps")
		await animation_player.animation_finished
		is_silo_raised = false
	
	is_animating = false
	animation_finished.emit()
	sleep_sequence_completed.emit()
	print("😴 Последовательность сна завершена")

func start_wake_sequence(cryopod: CryoPod) -> void:
	if is_animating:
		return
	
	is_animating = true
	animation_started.emit()
	print("☀️ Начало последовательности пробуждения...")
	
	# 1. Поднять сило
	if not is_silo_raised:
		animation_player.play_backwards("down_caps")
		await animation_player.animation_finished
		is_silo_raised = true
	
	# 2. Поднять капсулы
	if not are_capsules_raised:
		animation_player.play("caps_1_move")
		await animation_player.animation_finished
		animation_player.play("caps_2_move")
		await animation_player.animation_finished
		animation_player.play("caps_3_move")
		await animation_player.animation_finished
		are_capsules_raised = true
	
	# 3. Открыть капсулу
	if not cryopod.is_open:
		await cryopod.open_capsule()
	
	# 4. Опустить сило обратно
	if is_silo_raised:
		animation_player.play("down_caps")
		await animation_player.animation_finished
		is_silo_raised = false
	
	is_animating = false
	animation_finished.emit()
	wake_sequence_completed.emit()
	print("☀️ Последовательность пробуждения завершена")

## === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===
func _any_capsule_open() -> bool:
	var result = false
	if cryopod_1 and cryopod_1.is_open:
		result = true
	if cryopod_2 and cryopod_2.is_open:
		result = true
	if cryopod_3 and cryopod_3.is_open:
		result = true
	return result

func _on_capsule_state_changed(is_open: bool, capsule_id: int) -> void:
	print("📡 Капсула %d изменила состояние: %s" % [capsule_id, "открыта" if is_open else "закрыта"])
