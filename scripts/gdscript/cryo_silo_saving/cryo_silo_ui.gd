extends Control

# === ССЫЛКИ НА УЗЛЫ ===
@export var silo: Node3D  # Cryo_Silo
@export var cryopod_left: Node3D  # Cryopod (левая)
@export var cryopod_right: Node3D  # Cryopod (правая)
@export var cryopod_center: Node3D  # Cryopod (центральная)

@onready var button_primary: Button = $VBoxContainer/BUTTON_PRIMARY
@onready var button_secondary: Button = $VBoxContainer/BUTTON_SECONDARY

# === СОСТОЯНИЕ UI ===
var player_in_silo_range: bool = false
var player_in_capsule_range: bool = false
var player_inside_capsule: bool = false

var current_silo_state = null  # Будет типом SiloState из cryo_silo.gd
var current_capsule_state = null  # Будет типом CapsuleState из cryopod.gd

var active_capsule: Node3D = null  # Какая капсула сейчас в фокусе

func _ready() -> void:
	print("🚀 UI: _ready() запущен")
	
	if not button_primary or not button_secondary:
		push_error("❌ UI: КНОПКИ НЕ НАЙДЕНЫ! Проверь пути $VBoxContainer/BUTTON_PRIMARY и BUTTON_SECONDARY")
		return
	
	button_primary.visible = false
	button_secondary.visible = false
	button_primary.pressed.connect(_on_button_primary_pressed)
	button_secondary.pressed.connect(_on_button_secondary_pressed)
	print("✅ UI: Кнопки найдены и скрыты")
	
	# Отложенное подключение через call_deferred для динамических объектов
	call_deferred("_connect_all_systems")
	
	# Переподключаемся каждые 2 секунды (на случай динамической загрузки чанков)
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.autostart = true
	timer.timeout.connect(_connect_all_systems)
	add_child(timer)

func _connect_all_systems() -> void:
	# ДИНАМИЧЕСКИЙ ПОИСК СИЛО (если не назначен в экспорте)
	if not silo:
		silo = get_tree().root.find_child("Cryo_Silo", true, false)
		if silo:
			print("🔍 UI: Silo найден динамически - ", silo.name)
		else:
			push_error("❌ UI: Silo не найден!")
			return
	
	# Подключаем сигналы от Silo
	if silo:
		if not silo.silo_state_changed.is_connected(_on_silo_state_changed):
			silo.silo_state_changed.connect(_on_silo_state_changed)
		if not silo.player_in_silo_range_changed.is_connected(_on_player_in_silo_range_changed):
			silo.player_in_silo_range_changed.connect(_on_player_in_silo_range_changed)
		
		# ВАЖНО: Получаем текущее состояние сразу после подключения
		if silo.has_method("get_current_state"):
			current_silo_state = silo.current_state
			print("📥 UI: Получено начальное состояние Silo = ", current_silo_state)
			_update_button()
		
		print("✅ UI: Silo подключен - ", silo.name)
	
	# ДИНАМИЧЕСКИЙ ПОИСК КАПСУЛ (если не назначены в экспорте)
	if not cryopod_left:
		cryopod_left = get_tree().root.find_child("Cryopod_Prok2_L", true, false)
	if not cryopod_right:
		cryopod_right = get_tree().root.find_child("Cryopod_Prok_R", true, false)
	if not cryopod_center:
		cryopod_center = get_tree().root.find_child("Cryopod_Prok3_C", true, false)
	
	# Подключаем сигналы от всех капсул
	_connect_capsule(cryopod_left)
	_connect_capsule(cryopod_right)
	_connect_capsule(cryopod_center)

# === ПОДКЛЮЧЕНИЕ КАПСУЛЫ ===
func _connect_capsule(capsule: Node3D) -> void:
	if not capsule:
		return
	
	if not capsule.capsule_state_changed.is_connected(_on_capsule_state_changed):
		capsule.capsule_state_changed.connect(_on_capsule_state_changed)
	if not capsule.player_in_capsule_range_changed.is_connected(_on_player_in_capsule_range_changed.bind(capsule)):
		capsule.player_in_capsule_range_changed.connect(_on_player_in_capsule_range_changed.bind(capsule))
	if not capsule.player_inside_capsule_changed.is_connected(_on_player_inside_capsule_changed):
		capsule.player_inside_capsule_changed.connect(_on_player_inside_capsule_changed)
	
	# ВАЖНО: Получаем начальное состояние капсулы (если это активная капсула)
	if capsule == active_capsule and capsule.has_method("get_current_state"):
		current_capsule_state = capsule.current_state
		print("📥 UI: Получено начальное состояние Capsule = ", current_capsule_state)
		_update_button()
	
	print("✅ UI: Capsule подключена - ", capsule.name)

# === ОБРАБОТКА СИГНАЛОВ ===
func _on_silo_state_changed(new_state) -> void:
	print("📡 UI: Получен сигнал silo_state_changed = ", new_state)
	current_silo_state = new_state
	_update_button()

func _on_player_in_silo_range_changed(is_in_range: bool) -> void:
	print("📡 UI: Получен сигнал player_in_silo_range_changed = ", is_in_range)
	player_in_silo_range = is_in_range
	_update_button()

func _on_capsule_state_changed(new_state) -> void:
	current_capsule_state = new_state
	_update_button()

func _on_player_in_capsule_range_changed(is_in_range: bool, capsule: Node3D) -> void:
	player_in_capsule_range = is_in_range
	active_capsule = capsule if is_in_range else null
	
	# Получаем начальное состояние капсулы при входе в зону
	if is_in_range and capsule and capsule.has_method("get_current_state"):
		current_capsule_state = capsule.current_state
		print("📥 UI: Получено состояние активной капсулы = ", current_capsule_state)
	else:
		current_capsule_state = null  # Сбрасываем состояние капсулы при выходе
	
	_update_button()

func _on_player_inside_capsule_changed(is_inside: bool) -> void:
	player_inside_capsule = is_inside
	_update_button()

# === ПРОВЕРКА ОТКРЫТЫХ КАПСУЛ ===
func _has_open_capsules() -> bool:
	var capsules = [cryopod_left, cryopod_right, cryopod_center]
	for capsule in capsules:
		if capsule and capsule.has_method("get_current_state"):
			var state = capsule.get_current_state()
			# 1 = OPENING, 2 = OPEN
			if state == 1 or state == 2:
				return true
	return false

# === ОБНОВЛЕНИЕ КНОПОК ===
func _update_button() -> void:
	print("🔍 UI DEBUG: in_silo=", player_in_silo_range, " | in_capsule=", player_in_capsule_range, " | inside=", player_inside_capsule, " | silo_state=", current_silo_state, " | capsule_state=", current_capsule_state)
	
	# Скрываем кнопки если игрок не в зоне
	if not player_in_silo_range:
		button_primary.visible = false
		button_secondary.visible = false
		print("❌ UI: Кнопки скрыты - игрок не в зоне сило")
		return
	
	# ЕСЛИ STATE ЕЩЁ НЕ ПОЛУЧЕН - ПОКАЗЫВАЕМ ДЕФОЛТНЫЙ ТЕКСТ
	if current_silo_state == null:
		button_primary.visible = true
		button_primary.text = "Загрузка..."
		button_primary.disabled = true
		button_secondary.visible = false
		print("🔘 UI: Загрузка состояния...")
		return
	
	# Переменные для текстов и состояний кнопок
	var primary_text: String = ""
	var primary_enabled: bool = true
	var secondary_text: String = ""
	var secondary_enabled: bool = true
	var show_secondary: bool = false
	
	# === ЛОГИКА В ЗАВИСИМОСТИ ОТ МЕСТОПОЛОЖЕНИЯ ИГРОКА ===
	
	# ✅ ИСПРАВЛЕНИЕ БАГА #1: Проверяем, не закончилась ли последовательность засыпания
	if player_inside_capsule and current_silo_state == 0:  # SILO_DOWN после засыпания
		# Последовательность засыпания завершена, но игрок всё ещё "внутри"
		# Показываем основную кнопку сило, игнорируем состояние капсулы
		primary_text = "Поднять Сило"
		primary_enabled = true
		show_secondary = false
		print("🌙 UI: Последовательность засыпания завершена, показываем кнопку Сило")
	
	elif player_inside_capsule:
		# ВНУТРИ КАПСУЛЫ (во время обычного использования) - только одна кнопка
		show_secondary = false
		match current_capsule_state:
			2:  # OPEN
				primary_text = "Уйти в Сон"
				primary_enabled = true
			4:  # SLEEP_MODE
				primary_text = "Засыпание..."
				primary_enabled = false
			_:
				# ✅ ИСПРАВЛЕНИЕ: Более понятный текст для неожиданных состояний
				primary_text = "Ожидание..."
				primary_enabled = false
	
	elif player_in_capsule_range and active_capsule:
		# В ЗОНЕ КАПСУЛЫ (но не внутри) - две кнопки
		show_secondary = true
		match current_capsule_state:
			0:  # CLOSED
				primary_text = "Открыть Капсулу"
				primary_enabled = true
			1:  # OPENING
				primary_text = "Открытие..."
				primary_enabled = false
			2:  # OPEN
				primary_text = "Закрыть Капсулу"
				primary_enabled = true
			3:  # CLOSING
				primary_text = "Закрытие..."
				primary_enabled = false
			_:
				primary_text = "..."
				primary_enabled = false
		
		# Вторая кнопка - опустить капсулы (если CAPS_UP)
		if current_silo_state == 4:  # CAPS_UP
			# ✅ ИСПРАВЛЕНИЕ БАГА #2: Проверяем открытые капсулы
			if _has_open_capsules():
				secondary_text = "Закройте все капсулы"
				secondary_enabled = false
			else:
				secondary_text = "Опустить Капсулы"
				secondary_enabled = true
		elif current_silo_state == 5:  # CAPS_LOWERING
			secondary_text = "Опускание Капсул..."
			secondary_enabled = false
		else:
			show_secondary = false
	
	else:
		# ТОЛЬКО В ЗОНЕ СИЛО (не в зоне капсулы)
		match current_silo_state:
			0:  # SILO_DOWN
				primary_text = "Поднять Сило"
				primary_enabled = true
				show_secondary = false
			
			1:  # SILO_RISING
				primary_text = "Поднятие Сило..."
				primary_enabled = false
				show_secondary = false
			
			2:  # SILO_UP
				primary_text = "Поднять Капсулы"
				primary_enabled = true
				# Вторая кнопка - опустить сило
				show_secondary = true
				# ✅ ИСПРАВЛЕНИЕ БАГА #2: Проверяем открытые капсулы перед опусканием сило
				if _has_open_capsules():
					secondary_text = "Закройте все капсулы"
					secondary_enabled = false
				else:
					secondary_text = "Опустить Сило"
					secondary_enabled = true
			
			3:  # CAPS_RISING
				primary_text = "Поднятие Капсул..."
				primary_enabled = false
				show_secondary = false
			
			4:  # CAPS_UP
				# ✅ ИСПРАВЛЕНИЕ БАГА #2: Проверяем открытые капсулы
				if _has_open_capsules():
					primary_text = "Закройте все капсулы"
					primary_enabled = false
				else:
					primary_text = "Опустить Капсулы"
					primary_enabled = true
				show_secondary = false
			
			5:  # CAPS_LOWERING
				primary_text = "Опускание Капсул..."
				primary_enabled = false
				show_secondary = false
			
			6:  # SILO_LOWERING
				primary_text = "Опускание Сило..."
				primary_enabled = false
				show_secondary = false
	
	# Применяем настройки к кнопкам
	button_primary.visible = true
	button_primary.text = primary_text
	button_primary.disabled = not primary_enabled
	
	button_secondary.visible = show_secondary
	if show_secondary:
		button_secondary.text = secondary_text
		button_secondary.disabled = not secondary_enabled
	
	print("🔘 PRIMARY: '", primary_text, "' | enabled=", primary_enabled)
	if show_secondary:
		print("🔘 SECONDARY: '", secondary_text, "' | enabled=", secondary_enabled)

# === ОБРАБОТКА НАЖАТИЯ КНОПОК ===
func _on_button_primary_pressed() -> void:
	print("🖱️ PRIMARY BUTTON нажата")
	
	# ✅ ИСПРАВЛЕНИЕ: Проверяем, не завершилась ли последовательность засыпания
	if player_inside_capsule and current_silo_state == 0:
		# После засыпания - работаем с сило
		if silo and silo.has_method("on_button_pressed"):
			silo.on_button_pressed()
	elif player_inside_capsule:
		# Внутри капсулы - всегда "Уйти в Сон"
		if active_capsule and active_capsule.has_method("on_button_pressed"):
			active_capsule.on_button_pressed()
	
	elif player_in_capsule_range and active_capsule:
		# В зоне капсулы - Открыть/Закрыть капсулу
		if active_capsule.has_method("on_button_pressed"):
			active_capsule.on_button_pressed()
	
	else:
		# Только в зоне сило - Поднять сило/капсулы
		if silo and silo.has_method("on_button_pressed"):
			silo.on_button_pressed()

func _on_button_secondary_pressed() -> void:
	print("🖱️ SECONDARY BUTTON нажата")
	
	# ✅ ИСПРАВЛЕНИЕ БАГА #2: Дополнительная проверка перед опусканием
	if _has_open_capsules():
		print("⚠️ UI: Нельзя опускать - есть открытые капсулы!")
		return
	
	if player_in_capsule_range and not player_inside_capsule:
		# В зоне капсулы - опустить капсулы
		if silo and silo.has_method("lower_caps_from_ui"):
			silo.lower_caps_from_ui()
	
	elif current_silo_state == 2:  # SILO_UP
		# Опустить сило
		if silo and silo.has_method("lower_silo_from_ui"):
			silo.lower_silo_from_ui()
