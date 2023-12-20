extends Control
@onready var singleton_ai_control = SingletonAiControl

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_ai_walk_start_pressed():
	singleton_ai_control.ai_walk=true
	pass # Replace with function body.


func _on_ai_walk_stop_pressed():
	singleton_ai_control.ai_walk=false
	pass # Replace with function body.
