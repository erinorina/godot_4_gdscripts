extends StaticBody3D

enum State {
	UP,
	DOWN
}

var speed = 0.01
var direction = State.DOWN
var pos = 0.0

func _physics_process(delta):
	match direction:
	
		State.UP:
			pos += speed * delta
			self.transform.origin.y += pos
			if pos >= 0.05:
				direction = State.DOWN
		
		State.DOWN:
			pos += -speed * delta
			self.transform.origin.y -= pos
			if pos <= 0:
				direction = State.UP




