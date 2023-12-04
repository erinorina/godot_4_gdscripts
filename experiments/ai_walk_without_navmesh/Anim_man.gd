extends Node3D
@onready var animation_player = $AnimationPlayer
@onready var ray = $ray
@onready var ray_forward = $ray_forward
@onready var ray_backward = $ray_backward
@onready var ray_left = $ray_left
@onready var ray_right = $ray_right


var speed = 0.4
var original_transform: Transform3D


func _ready():
	prev_position = self.global_transform.origin # inside tree error fix for get_velocity
	ray.target_position = Vector3(0,-1,0)
	original_transform = global_transform

func _physics_process(delta):

	var collider = ray.get_collider()
#	if collider !=null:
#		print("collider ", collider.name)
	
#	ai_random_rotation(delta)
#	ai_random_forward_backward(delta)
	
	player_rotation(delta)
	player_direction(delta)

	get_velocity()
	
	simulate_gravity(delta)
	
	falling(delta)
	on_ground(collider, delta)
	holes_detector(collider, delta)
	collide_with_sphere(collider, delta)
	

func player_direction(_delta):
	var direction = Vector3(0, 0, Input.get_action_strength("ui_up") - Input.get_action_strength("ui_down"))
	translate_object_local(Vector3(0,0,1) * speed * direction * _delta)

var player_rotation_speed = 5
func player_rotation(_delta):
	var rotation_input = Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")
	rotate_y(rotation_input* player_rotation_speed * _delta) # to keep

var prev_position # inside tree error fix for get_velocity
var velocity_z = 0.0
func get_velocity():
	var current_position = self.global_transform.origin
	var velocity = current_position - prev_position
	prev_position = current_position

	var b = self.transform.basis
	var v_len = velocity.length()
	var v_nor = velocity.normalized()

	var vel : Vector3
	vel.x = b.x.dot(v_nor) * v_len
	vel.y = b.y.dot(v_nor) * v_len
	vel.z = b.z.dot(v_nor) * v_len
	velocity_z= vel.z
#	print(vel.z)


var speed_increase = 0.004
var MAX_SPEED = 3.6
var MAX_SPEED_BACK = 1.6

func on_ground(_collider, _delta):
	if ray.is_colliding() and _collider.name == "StaticBody3D"  : #and is_in_group("ground"): # 
		change_ray_length(-1)
		
		if velocity_z > 0:
			animation_player.play("walk",-1, speed)
			speed += speed_increase
			speed = clamp(speed + speed_increase, 0, MAX_SPEED)
			climb_up(_delta)
		if velocity_z < 0:
			animation_player.play("walk_back",-1, speed)
			speed += speed_increase
			speed = clamp(speed + speed_increase, 0, MAX_SPEED_BACK)
		if velocity_z == 0:
			speed = 0.4
			animation_player.play("idle")


var dir = 1
var rotation_speed = 2.5 # Maximum rotation speed on the Y-axis in degrees per second
var rotation_angle = 180.0 # Rotation angle in degrees
var timer=0.0
func holes_detector(_collider, _delta):
	if ray.is_colliding():
		if !ray_forward.is_colliding():
			dir = -0.4
			self.rotate_object_local(Vector3(0,1,0), clamp(rotation_angle, 0, rotation_speed * _delta))
		timer += _delta
		if timer >=10:
			timer = 0
			dir = 0.8
				
		if !ray_backward.is_colliding():
			dir = 0.8
		if velocity_z <=0.1:
			if !ray_left.is_colliding():
				ai_rotation(-0.1,_delta)
				
			if !ray_right.is_colliding():
				ai_rotation(0.1,_delta)

			
			if !ray_left.is_colliding() and !ray_right.is_colliding():
				ai_rotation_urgent(_delta)
		
		translate_object_local(Vector3(0,0,dir) * _delta)
		if ray.is_colliding() and ray_backward.is_colliding() and ray_forward.is_colliding() and ray_left.is_colliding() and ray_right.is_colliding():
			await get_tree().create_timer(0.8).timeout # avoid tight corner out falling in water
			ai_random_rotation(_delta)
		if !ray.is_colliding() and !ray_backward.is_colliding() and !ray_forward.is_colliding() and !ray_left.is_colliding() and !ray_right.is_colliding():
			print("falling in the void")

func climb_up(_delta):
	# in dev dirty bugged
	var raycol = ray.get_collision_point()
	var rayfor = ray_forward.get_collision_point()
	var rayback = ray_backward.get_collision_point()
	if raycol.y < rayfor.y or raycol.y < rayback.y:
#		print("upstair")
		change_ray_length(-2.0)
		self.position.y = rayfor.y - _delta
	if raycol.y > rayfor.y or raycol.y > rayback.y:
		change_ray_length(-2.0)
#		print("downstair")

func falling(_delta):
	if !ray.is_colliding() and !ray_forward.is_colliding():
		change_ray_length(-1)
		animation_player.play("fall")

		
var ai_rotation_speed = 2
var ai_target_rotation = 0.0
var ai_current_rotation = 0.0
func ai_random_rotation(_delta):
	var rotation_input = randi_range(-1, 1) *speed * _delta
	ai_target_rotation = rotation_input * ai_rotation_speed
	ai_current_rotation = lerp(ai_current_rotation, ai_target_rotation, _delta * ai_rotation_speed)
	rotate_y(ai_current_rotation)


func ai_rotation(_rotation,_delta):
	var rotation_input = _rotation *speed * _delta
	ai_target_rotation = rotation_input * ai_rotation_speed
	ai_current_rotation = lerp(ai_current_rotation, ai_target_rotation, _delta * ai_rotation_speed)
	rotate_y(ai_current_rotation)
	
	
func ai_rotation_urgent(_delta):
	var rotation_input = 0.5 *speed * _delta
	ai_target_rotation = rotation_input * ai_rotation_speed
	ai_current_rotation = lerp(ai_current_rotation, ai_target_rotation, _delta * ai_rotation_speed)
	rotate_y(ai_current_rotation)

var direction_z = 0.0
var total_time = 4.0
var elapsed_time = 0.0
func ai_random_forward_backward(_delta):
	elapsed_time += _delta
	if elapsed_time >= total_time:
		if randi() % 2 == 0: # forward
			direction_z = 0.8
		else: # backward
			direction_z = -0.4
		elapsed_time = 0.0 # Reset the timer
		
	# translate
	translate_object_local(Vector3(0,0, direction_z * _delta))
	#

func collide_with_sphere(_collider, _delta):
	if _collider != null :
		
		if ray.is_colliding() and _collider.name == "sphere":
#			print("Object's up direction: ", self.global_transform.basis.y)
			change_ray_length(-1.5)

			var normal = ray.get_collision_normal()

			self.global_transform.basis = _sphere_align_up(self.global_transform.basis, normal )
			animation_player.play("crawl")

#			# Detect The bottom of the mesh
			var up_direction = self.global_transform.basis.y
			var negative_y_axis = Vector3(0, -1, 0)
			var epsilon = 0.5 # Adjust this value, 1 is half bottom
			if abs(up_direction.x - negative_y_axis.x) < epsilon and \
			   abs(up_direction.y - negative_y_axis.y) < epsilon and \
			   abs(up_direction.z - negative_y_axis.z) < epsilon:
#				print("The object's up direction is pointing towards the negative y-axis")
				ray.enabled = false
				self.translate_object_local(Vector3(0,0,0))
				self.global_rotation = Vector3(0,0,0)
				animation_player.play("fall")
				await get_tree().create_timer(0.25).timeout
				change_ray_length(-1)
				ray.enabled = true


func _sphere_align_up(node_basis, normal):
	var result = Basis()
	scale = node_basis.get_scale().abs()
	result.x = normal.cross(node_basis.z)
	result.y = normal
	result.z = node_basis.x.cross(normal)
	result = result.orthonormalized()
	result.x *= scale.x
	result.y *= scale.y
	result.z *= scale.z
	return result


func change_ray_length(new_length):
	ray.target_position = Vector3(0, new_length, 0)


var max_speed = 2
var g_speed = 0.0
var deceleration = 0.1 # add deceleration factor

func simulate_gravity(_delta):
	if ray.is_colliding():
		pass
	if !ray.is_colliding():
		g_speed += 0.1
		g_speed = clamp(g_speed, 0, max_speed)
		self.global_translate(Vector3(0,-g_speed,0) *_delta)


