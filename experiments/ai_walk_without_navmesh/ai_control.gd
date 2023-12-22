extends Control
@onready var singleton_ai_control = SingletonAiControl


func _on_ai_walk_start_pressed():
	singleton_ai_control.ai_walk=true
	pass # Replace with function body.


func _on_ai_walk_stop_pressed():
	singleton_ai_control.ai_walk=false
	pass # Replace with function body.



func _on_ai_go_to_objective_a_pressed():
	singleton_ai_control.ai_go_to_objective_a=true
	pass # Replace with function body.
