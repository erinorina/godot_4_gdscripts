extends Node3D
@onready var animation_player = $AnimationTree/AnimationPlayer

var blend_amount = 0.0

func _input(event):
	if event is InputEventKey and event.is_action_pressed("ui_left"):
		animation_player.queue("left")
	if event is InputEventKey and event.is_action_pressed("ui_right"):
		animation_player.queue("right")
	if event is InputEventKey and event.is_action_pressed("ui_up"):
		animation_player.queue("up")
