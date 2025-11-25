extends Area3D

#📦 Hazard Cube — тестовая болванка (демо-актер), используемая в демонстрационной сборке проекта
#для проверки и визуализации работы системы ShakeCam.
#
#⚙️ ОБЩЕЕ НАЗНАЧЕНИЕ:
#Этот объект представляет собой упрощённый триггер, который посылает сигналы в камеру при 
#входе и выходе игрока из области. При пересечении зоны Cube вызывает тряску камеры — 
#имитируя срабатывание эффекта от внешнего воздействия (взрыв, удар, землетрясение и т.д.).
#
#🧩 ВАЖНО:
#Использование `Area3D` в данном примере — **не обязательно**.  
#Hazard Cube просто демонстрирует принцип связи системы ShakeCam с любыми игровыми событиями.  
#В реальном проекте генерацию сигнала можно производить из:
#- систем урона или попаданий;
#- триггеров кат-сцен и QTE;
#- скриптов окружения (например, вибрация при работе механизмов);
# пример --> // Взрыв бочки с расстоянием
#var strength = clamp(5.0 / distance, 0.5, 3.0)
#camera.add_impulse_shake(strength)
#📡 СИГНАЛЫ:
#- `shake_cam_process(amplitude, time)` — активирует эффект тряски камеры;
#- `stop_shake_cam_process()` — завершает эффект (обычно при выходе игрока из зоны или окончании события).
#
#🧠 ЦЕЛЬ:
#Обеспечить удобный способ протестировать ShakeCam без необходимости полноценной логики геймплея.
#Этот объект можно свободно модифицировать под любые игровые события или заменить на свои системы.

signal shake_cam_process(amplitude: float, time: float)
signal stop_shake_cam_process

@export_category("Testing Shake Camera")
@export var player: CharacterBody3D
@export var camera: Camera3D

@export_group("Shake Settings")
@export_enum("Continuous", "Impulse") var shake_mode: int = 0
@export var amplitude: float = 0.5
@export var time: float = 1.0
@export var continuous_interval: float = 0.1  # Для Continuous режима

var is_player_inside: bool = false
var shake_timer: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_player_entered_area_hazard_cube)
	body_exited.connect(_on_player_exited_area_hazard_cube)
	
	var mode_names = ["CONTINUOUS", "IMPULSE"]
	print("✅ HazardArea ready | mode: %s | amplitude: %.2f, time: %.2fs" % [
		mode_names[shake_mode], amplitude, time
	])

func _process(delta: float) -> void:
	if shake_mode != 0 or not is_player_inside:  # 0 = Continuous
		return
	
	shake_timer += delta
	
	if shake_timer >= continuous_interval:
		shake_timer = 0.0
		shake_cam_process.emit(amplitude, time)

func _on_player_entered_area_hazard_cube(body: Node3D) -> void:
	if body.name == "Player":
		is_player_inside = true
		shake_timer = 0.0
		
		match shake_mode:
			0:  # Continuous
				print("💥 CONTINUOUS shake started")
				shake_cam_process.emit(amplitude, time)
			1:  # Impulse
				print("💥 IMPULSE shake")
				if camera and camera.has_method("add_impulse_shake"):
					camera.add_impulse_shake(amplitude)
				else:
					shake_cam_process.emit(amplitude, time)

func _on_player_exited_area_hazard_cube(body: Node3D) -> void:
	if body.name == "Player":
		is_player_inside = false
		shake_timer = 0.0
		
		if shake_mode == 0:  # Только для Continuous
			print("🚪 CONTINUOUS shake stopped")
			stop_shake_cam_process.emit()
