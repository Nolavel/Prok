## ============================================
## CONTROL_PANEL.gd - Зона активации компьютера
## ============================================
extends Area3D
class_name ControlPanel

signal computer_activated
signal computer_deactivated
signal player_entered_control_zone
signal player_exited_control_zone

var player_in_zone: bool = false
var is_computer_on: bool = false

func _ready() -> void:
	body_entered.connect(_on_player_entered_zone)
	body_exited.connect(_on_player_exited_zone)
	print("✅ Control Panel: Инициализирована")

func _on_player_entered_zone(body: Node3D) -> void:
	if body.name == "Player":
		player_in_zone = true
		player_entered_control_zone.emit()
		print("👤 Игрок подошёл к панели управления")

func _on_player_exited_zone(body: Node3D) -> void:
	if body.name == "Player":
		player_in_zone = false
		player_exited_control_zone.emit()
		print("🚶 Игрок отошёл от панели управления")

func toggle_computer() -> void:
	is_computer_on = !is_computer_on
	if is_computer_on:
		computer_activated.emit()
		print("💻 Компьютер включён")
	else:
		computer_deactivated.emit()
		print("💻 Компьютер выключен")
