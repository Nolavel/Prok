extends Node3D

# === СОСТОЯНИЯ СИЛО ===
enum SiloState {
	SILO_DOWN,
	SILO_RISING,
	SILO_UP,
	CAPS_RISING,
	CAPS_UP,
	CAPS_LOWERING,
	SILO_LOWERING
}

# === СИГНАЛЫ ===
signal silo_state_changed(new_state: SiloState)
signal player_in_silo_range_changed(is_in_range: bool)

# === ССЫЛКИ ===
@onready var anima_cryo_silo: AnimationPlayer = $Anima
@onready var interaction_area: Area3D = $Area_Interaction

# === СОСТОЯНИЕ ===
var current_state: SiloState = SiloState.SILO_DOWN
var player_in_range: bool = false

func _ready() -> void:
	anima_cryo_silo.play("Cryo_Pit_Locked")  # Idle состояние
	_change_state(SiloState.SILO_DOWN)
	
	# Подключаем сигналы Area3D
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)
		print("✅ Cryo_Silo: Area3D подключена")
	else:
		push_error("❌ Area3D не найдена!")

# === СМЕНА СОСТОЯНИЯ ===
func _change_state(new_state: SiloState) -> void:
	current_state = new_state
	silo_state_changed.emit(new_state)
	print("🔄 Silo State: ", SiloState.keys()[new_state])

# === ПУБЛИЧНЫЙ МЕТОД ДЛЯ ПОЛУЧЕНИЯ ТЕКУЩЕГО СОСТОЯНИЯ ===
func get_current_state() -> SiloState:
	return current_state

# === ПУБЛИЧНЫЙ МЕТОД ДЛЯ UI ===
func on_button_pressed() -> void:
	match current_state:
		SiloState.SILO_DOWN:
			_raise_silo()
		SiloState.SILO_UP:
			_raise_caps()
		SiloState.CAPS_UP:
			_lower_caps()

# === ПУБЛИЧНЫЕ МЕТОДЫ ДЛЯ ВТОРОЙ КНОПКИ UI ===
func lower_silo_from_ui() -> void:
	if current_state == SiloState.SILO_UP:
		_lower_silo()

func lower_caps_from_ui() -> void:
	if current_state == SiloState.CAPS_UP:
		_lower_caps()

# === ПОДНЯТИЕ СИЛО ===
func _raise_silo() -> void:
	_change_state(SiloState.SILO_RISING)
	anima_cryo_silo.play_backwards("down_caps")
	await anima_cryo_silo.animation_finished
	_change_state(SiloState.SILO_UP)

# === ПОДНЯТИЕ КАПСУЛ ===
func _raise_caps() -> void:
	_change_state(SiloState.CAPS_RISING)
	
	anima_cryo_silo.play("caps_1_move")
	await anima_cryo_silo.animation_finished
	
	anima_cryo_silo.play("caps_2_move")
	await anima_cryo_silo.animation_finished
	
	anima_cryo_silo.play("caps_3_move")
	await anima_cryo_silo.animation_finished
	
	_change_state(SiloState.CAPS_UP)

# === ОПУСКАНИЕ КАПСУЛ ===
func _lower_caps() -> void:
	_change_state(SiloState.CAPS_LOWERING)
	
	anima_cryo_silo.play_backwards("caps_3_move")
	await anima_cryo_silo.animation_finished
	
	anima_cryo_silo.play_backwards("caps_2_move")
	await anima_cryo_silo.animation_finished
	
	anima_cryo_silo.play_backwards("caps_1_move")
	await anima_cryo_silo.animation_finished
	
	_change_state(SiloState.SILO_UP)

# === ОПУСКАНИЕ СИЛО ===
func _lower_silo() -> void:
	_change_state(SiloState.SILO_LOWERING)
	anima_cryo_silo.play("down_caps")
	await anima_cryo_silo.animation_finished
	_change_state(SiloState.SILO_DOWN)

# === ПОЛНАЯ ПОСЛЕДОВАТЕЛЬНОСТЬ ЗАСЫПАНИЯ ===
func start_sleep_sequence() -> void:
	print("🌙 Silo: Начинаем полную последовательность засыпания...")
	
	# Вызывается из Cryopod после закрытия капсулы
	_change_state(SiloState.CAPS_LOWERING)
	
	# Опускаем капсулы
	print("⬇️ Опускаем капсулу 3...")
	anima_cryo_silo.play_backwards("caps_3_move")
	await anima_cryo_silo.animation_finished
	
	print("⬇️ Опускаем капсулу 2...")
	anima_cryo_silo.play_backwards("caps_2_move")
	await anima_cryo_silo.animation_finished
	
	print("⬇️ Опускаем капсулу 1...")
	anima_cryo_silo.play_backwards("caps_1_move")
	await anima_cryo_silo.animation_finished
	print("✅ Капсулы опущены")
	
	# Опускаем сило
	_change_state(SiloState.SILO_LOWERING)
	print("⬇️ Опускаем сило...")
	anima_cryo_silo.play("down_caps")
	await anima_cryo_silo.animation_finished
	print("✅ Сило опущен")
	
	# Возврат в начальное состояние
	_change_state(SiloState.SILO_DOWN)
	print("🌙 Последовательность засыпания ЗАВЕРШЕНА! Все системы в исходном положении.")

# === КОЛЛБЭКИ AREA3D ===
func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		player_in_range = true
		player_in_silo_range_changed.emit(true)
		print("👤 Игрок вошёл в зону Сило")

func _on_body_exited(body: Node3D) -> void:
	if body.name == "Player":
		player_in_range = false
		player_in_silo_range_changed.emit(false)
		print("🚶 Игрок вышел из зоны Сило")
