extends Node3D

#testing

@onready var area = $Hatch/Lock_Unlock_Hatch
@onready var anima = $Anima
@onready var area_airlock = $InnerAirlockHatch/Lock_Unlock_Airlock

func _ready() -> void:
	$CSGCombiner3D/roof1.visible = false
	$CSGCombiner3D/roof2.visible = false
	area.body_entered.connect(_on_player_entered_on_hatch_area)
	area.body_exited.connect(_on_player_exited_on_hatch_area)
	area_airlock.body_entered.connect(_on_player_entered_on_airlock_area)
	area_airlock.body_exited.connect(_on_player_exited_on_airlock_area)
	
func _on_player_entered_on_hatch_area(body):
	if body.name == "Player":
		anima.play("Hatch_Opening")
	$CSGCombiner3D/roof1.visible = true
	$CSGCombiner3D/roof2.visible = true
	
func _on_player_exited_on_hatch_area(body):
	if body.name == "Player":
		anima.play("Hatch_Closing")
		
func _on_player_entered_on_airlock_area(body):
	if body.name == "Player":
		anima.play("Airlock_Opening")

func _on_player_exited_on_airlock_area(body):
	if body.name == "Player":
		anima.play("Airlock_Closing")
