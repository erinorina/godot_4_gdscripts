extends Node3D
@onready var singleton_ai_control = SingletonAiControl
@onready var animation_player = $AnimationPlayer
#@onready var ray = $ray
@onready var ray_jump = $ray_jump
@onready var ray_forward = $ray_forward
@onready var ray_backward = $ray_backward
@onready var ray_left = $ray_left
@onready var ray_right = $ray_right



const GRAVITY = 9.8

enum States {
IDLE,
WALK,
WALK_BACK,
JUMPING,
FALLING,
FLYING,
LANDING
}
var current_state = States.IDLE



func fsm():
	match current_state:
		States.IDLE:
			animation_player.queue("idle")
			return

		States.WALK:
			animation_player.play("walk",-1, get_velocity_z)
			current_state = States.IDLE
			
		States.WALK_BACK:
			animation_player.play("walk_back",-1, get_velocity_z)
			current_state = States.IDLE

			
		States.JUMPING:
			animation_player.play("jump")
			await get_tree().create_timer(0.25).timeout
			is_jumping= false
			
		States.FALLING:

				animation_player.play("jump_fall")

				
		States.FLYING:
			animation_player.play("fall")

		States.LANDING:		
			animation_player.play("ground_impact")
			await get_tree().create_timer(0.25).timeout
			ground_landing_impact= false

			
var ray
func _ready():
	ray = add_ray()
	prev_position = self.global_transform.origin # get_velocity

func add_ray():
	ray = RayCast3D.new()
	add_child(ray)
	ray.name = "MyRay"
	ray.transform.origin = Vector3(0,1.0,0)
	ray.enabled = true
	ray.debug_shape_custom_color = Color(0,0,1) # Red
	ray.debug_shape_thickness = 10
	return ray

var is_on_floor=false

func _physics_process(delta):
#	print(name," current_state ", current_state)
	print (name , " is_on_floor ", is_on_floor)
	
	
	fsm()	
#
	player_rotation(delta)
	player_direction_y(delta)
	player_direction_z(delta)
#
	get_velocity() # For on_ground_animation
#
	player_jump(delta)
#
#

	check_previous_distance(delta)
	adjust_ray_on_collision_surface(delta)
	free_fall_kinematics(delta)

#	ai_advance_or_stop_on_holes(delta)
#	ai_rotation_behavior_on_holes(delta)
	
	
	
var objective_a = Vector3(-10,0,0)
func look_objective_a(_delta):
	var direction_to_target = (objective_a - self.global_transform.origin).normalized()
	var current_direction = self.global_transform.basis.z
	var angle = current_direction.angle_to(direction_to_target)

	var angle_diff = abs(current_direction.angle_to(direction_to_target))
	if angle_diff < 0.1:
		print("stop")
		return
		
	self.rotate_y(angle*_delta)







var ai_advance_speed=0.0
func ai_advance_or_stop_on_holes(_delta):	
	
	if singleton_ai_control.ai_walk==false:
		ai_advance_speed = 0.0
	
	if singleton_ai_control.ai_walk==true:
		if ray_jump.is_colliding():
			ai_advance_speed += 0.01
			animation_player.play("walk",-1, ai_advance_speed)
			
		if !ray_jump.is_colliding():
			ai_advance_speed = 0.0
	#		animation_player.play("idle")
	

		
		var motion = player_direction * ai_advance_speed * _delta	
		var new_position = self.transform.origin + motion
		self.transform.origin = new_position
	
	



func ai_rotation_avoid_holes(_delta):

	if !ray_left.is_colliding():
		ai_rotation(-0.25,_delta)
		
	if !ray_right.is_colliding():
		ai_rotation(0.25,_delta)

	
	if !ray_left.is_colliding() and !ray_right.is_colliding():
#				print("urgent")
		ai_rotation_urgent(_delta)
	
var ai_rotation_speed = 2
var ai_target_rotation = 0.0
var ai_current_rotation = 0.0

func ai_rotation(_rotation, _delta):
	var rotation_input = _rotation * speed * _delta
	ai_target_rotation = rotation_input * ai_rotation_speed
	ai_current_rotation = lerp(ai_current_rotation, ai_target_rotation, _delta * ai_rotation_speed)
	self.rotation += Vector3(0,ai_current_rotation,0)

func ai_random_rotation(_delta):
	ai_rotation(randi_range(-1, 1), _delta)

func ai_rotation_urgent(_delta):
	ai_rotation(0.5, _delta)




var rotation_direction = 0
var rotation_speed=3.6
var player_direction:Vector3
func player_rotation(_delta):
	var rotation_input = Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")
#	print("rotation_input " , rotation_input) # return -1 or 0 or -1
	var player_rot = self.rotation
	player_rot = rotation_input * _delta * rotation_speed
	player_rot = fmod(player_rot, 2 * PI)
	self.rotation += Vector3(0,player_rot,0)
	
	player_direction = self.global_transform.basis.z
#	print("player_direction ", player_direction)




func player_direction_y(_delta):
	var vertical_direction = Input.get_action_strength("ui_page_up") - Input.get_action_strength("ui_page_down")
	var motion = Vector3.UP * GRAVITY * vertical_direction * _delta
	self.global_transform.origin += motion


var current_speed = 0.0
var deceleration = 3.2
var last_direction = Vector3(0, 0, 0)
var speed = 3.2
func player_direction_z(_delta):
#	print("current_speed ", current_speed)
	# Calculate direction
	var direction = Vector3(0, 0, Input.get_action_strength("ui_up") - Input.get_action_strength("ui_down"))
	# If there's input, accelerate
	if direction.length() > 0:
		current_speed = min(speed, current_speed + speed * _delta)
		last_direction = direction
	else:
		current_speed = max(0.0, current_speed - deceleration * _delta)
		direction = last_direction
	# Use the direction of the player
	var motion = player_direction * current_speed * _delta
#	print("player_motion_z ", motion)
	self.global_transform.origin += motion



var prev_position # inside tree error fix for get_velocity
var get_velocity_z = 0.0
func get_velocity():
	var current_position = self.global_transform.origin
	var velo = current_position - prev_position # Invalid operands 'Vector3' and 'Nil' in operator '-'.
	prev_position = current_position

	var b = self.transform.basis
	var v_len = velo.length()
	var v_nor = velo.normalized()

	var vel : Vector3
	vel.x = b.x.dot(v_nor) * v_len
	vel.y = b.y.dot(v_nor) * v_len
	vel.z = b.z.dot(v_nor) * v_len
	get_velocity_z= vel.z
#	print("velocity_z", vel.z)


var walking=false
func on_ground_animation(_delta):
	if get_velocity_z > 0:
		current_state = States.WALK
		walking=true
	if get_velocity_z < 0:
		current_state = States.WALK_BACK
		walking=true
	if get_velocity_z==0:
		walking=false

var is_jumping=false
func player_jump(_delta):
	if Input.is_action_pressed("jump"):
		is_jumping=true
		current_state=States.JUMPING

var distance
func get_ray_distance():
	var start= ray.transform.origin - Vector3(0,1,0) # adjust the ray origin to be zero
	var end = ray.target_position
	distance = (start-end).length()


func adjust_ray_on_collision_surface(_delta):

	if !ray.is_colliding():
		ray_expand(_delta)

		if distance > 1.5: # adjust for moving platform y
			ground_landing_impact=true
			is_jumping=false

			current_state = States.IDLE
			
		if distance > 2.0 and distance < 5.0 :

			current_state=States.FALLING

		if distance > 5.0 and distance < 100.0:

			current_state=States.FLYING

		if distance >= 100.0:
			print(name," deleted by distance ", distance)
			self.queue_free()
		
		
	if ray.is_colliding():
		ray_shrink(_delta)
		if distance ==1.0:
			is_on_floor=true
		else:
			is_on_floor=false
			
		if distance ==1.0 and get_velocity_z!=0.0:
			on_ground_animation(_delta)
			

		if distance ==1.0 and !ground_landing_impact :
			ai_advance_or_stop_on_holes(_delta)

		if distance ==1.0 and get_velocity_z==0.0 and !ground_landing_impact :
			ai_rotation_avoid_holes(_delta)

#			look_objective_a(_delta)
		if distance ==1.0 and get_velocity_z==0.0 and ground_landing_impact :
			current_state=States.LANDING
			
		if distance ==1.0 and get_velocity_z==0.0 and !ground_landing_impact :
			current_state=States.IDLE

		if distance ==1.0 and walking and is_jumping:
			current_state=States.JUMPING
	

var ground_landing_impact=false

var previous_distance = 0
func check_previous_distance(_delta):
	var old_distance = previous_distance
	get_ray_distance()
	if old_distance >= distance and distance < 1.2 and distance > 0.9 :
		var collision_point = ray.get_collision_point()
		if collision_point != Vector3.ZERO:
			var target_y = collision_point.y - 0.05
			var current_y = self.global_transform.origin.y
			var smooth_y = lerp(current_y, target_y, 0.1)
			self.global_transform.origin.y = smooth_y
	previous_distance = distance


var shrink_speed = GRAVITY
func ray_shrink(_delta):
	distance -= _delta * shrink_speed
	distance = max(distance, 1.00)  # Prevent going below minimum length
	ray.target_position = Vector3(0, -distance, 0)


var expand_speed = GRAVITY
func ray_expand(_delta):
	distance += _delta * expand_speed
	distance = min(distance, 100.0) # Prevent going up maximum length
	ray.target_position = Vector3(0, -distance, 0)



var velocity=0.0
var max_velocity =10.0
func free_fall_kinematics(_delta):
	var initial_height = 1
	var falling_height = distance - initial_height

	var initial_speed = 0
	velocity = min(sqrt(2 * GRAVITY * falling_height), max_velocity)
#	print(name , " falling_height m : ", falling_height," velocity m/s: ", velocity)
	var distance_in_this_step = velocity * _delta
	self.global_transform.origin += Vector3(0, -distance_in_this_step, 0)






'''
var original_transform: Transform3D
var speed = 0.4
var on_ground=false
var is_jumping=false



func _physics_process(delta):
	if !is_on_ground():
		falling_in_the_void_kill_by_time(delta)
		simulate_gravity(delta)
		ray_length = get_ray_length()
		set_ray_target(ray_length)

		if get_ray_length()>=40:
#			print(name," get_ray_length ",ray_length)		
			animation_player.play("fall")

#		shrink_ray_length(delta)
	if is_on_ground():
		return
#		shrink_ray_length(delta)
#		get_ray_length()
#		simulate_gravity(delta)
#		set_ray_length(1)



func get_ray_length():
	var start_pos = ray.to_local(ray.position+Vector3(0,1,0))
	var end_pos = ray.target_position
	ray_length = abs(end_pos.y - start_pos.y)
#	print(name," Start position:", start_pos)
#	print(name," End position:", end_pos)
	print(name," Ray length:", ray_length)
	return ray_length



func set_ray_target(new_length):
	ray.target_position = Vector3(0,-new_length,0)



func get_needed_ray_length(_delta):
	if ray_length <=0.0:
		expand_ray_length(_delta)
	if ray_length >=1.0:
		shrink_ray_length(_delta)


var ray_length = 10.0
var ray_expand_speed = 0.5
var ray_shrink_speed = 0.5

func expand_ray_length(_delta):
	var hit_pos = ray.get_collision_point()
	var start_pos = ray.global_transform.origin
	ray_length = (hit_pos - start_pos).length()
	if ray.is_colliding():
		return
	if !ray.is_colliding():
		ray_length += _delta * ray_expand_speed
#		print("Expanded Ray length:", ray_length)
	ray.target_position = Vector3(0,-ray_length,0)

func shrink_ray_length(_delta):
	var hit_pos = ray.get_collision_point()
	var start_pos = ray.global_transform.origin
	ray_length = (hit_pos - start_pos).length()
	if !ray.is_colliding():
		return
	if ray.is_colliding() and ray_length>1.0:
		ray_length -= _delta * ray_expand_speed
#		print("shrink Ray length:", ray_length)
	ray.target_position = Vector3(0,-ray_length,0)




func random_walker(_collider,_delta):
	on_ground_animation(_collider, _delta)
	_holes_detector(_collider, _delta)
	collide_with_sphere(_collider, _delta)
	jump_over_holes(_delta)
		
func controled_rotation(_delta):

	if !ray_left.is_colliding():
		ai_rotation(-0.1,_delta)
		
	if !ray_right.is_colliding():
		ai_rotation(0.1,_delta)

	
	if !ray_left.is_colliding() and !ray_right.is_colliding():
#				print("urgent")
		ai_rotation_urgent(_delta)


var objective_a=Vector3(0,0,0)
func go_to_objective_a(_delta):

	if self.global_position!=Vector3.ZERO and global_position.distance_to(objective_a) > 0.5 and global_position.distance_to(objective_a) <5.0:
		look_at_from_position(self.global_position,objective_a,Vector3.UP,true)
#		velocity_z=0.8
		
#		translate_object_local(Vector3(0,0,velocity_z) * _delta)
	else:
		velocity_z=0.0
		print("stop")
		pass

func escape_objective_a(_delta):
	if self.global_position!=Vector3.ZERO:
		look_at_from_position(self.global_position,objective_a,Vector3.UP,false)
		velocity_z=0.8

		if global_position.distance_to(objective_a) > 0.1:
			translate_object_local(Vector3(0,0,velocity_z) * _delta)
		else:
			print("stop")
			pass

func advance_or_stop_on_holes(_collider, _delta):
	if ray_jump.is_colliding() :
		velocity_z=0.8
		translate_object_local(Vector3(0,0,velocity_z) * _delta)
	else:
		velocity_z = 0.0
		translate_object_local(Vector3(0,0,velocity_z) * _delta)


var reset_distance_stop_pos_set = false
func falling_in_the_void_reset_at_last_stoped(_reset_distance):
	if not reset_distance_stop_pos_set:
		stoped_position = kill_distance_current_pos
		reset_distance_stop_pos_set = true
	kill_distance_current_pos = position
	var distance = stoped_position.distance_to(kill_distance_current_pos)
	if distance >= _reset_distance:
		print(name, " reset by distance at ", distance)
		self.global_transform.origin = stoped_position

		
var kill_distance_stop_pos_set = false
func falling_in_the_void_kill_by_distance_from_last_stoped(_kill_distance):
	if not kill_distance_stop_pos_set:
		stoped_position = kill_distance_current_pos
		kill_distance_stop_pos_set = true
	kill_distance_current_pos = position
	var distance = stoped_position.distance_to(kill_distance_current_pos)
	if distance >= _kill_distance:
		print(name, " killed by distance at ", distance)
		self.queue_free()


var kill_distance_current_pos: Vector3
var kill_distance_previous_pos: Vector3
var kill_distance_previous_pos_set = false
func falling_in_the_void_kill_by_distance(_kill_distance):
	if not kill_distance_previous_pos_set:
		kill_distance_previous_pos = kill_distance_current_pos
		kill_distance_previous_pos_set = true
	kill_distance_current_pos = position
	var distance = kill_distance_previous_pos.distance_to(kill_distance_current_pos)
	if distance >= _kill_distance:
		print(name, " killed by distance at ", distance)
		self.queue_free()

	


var falling_timer = 0.0
var falling_delay = 10.0 # Delay in seconds
var falling_once=true
var falling_in_the_void=false
func falling_in_the_void_kill_by_time(_delta):
	if falling_once:
		falling_timer += _delta
		if falling_timer >= falling_delay:
			falling_timer -= falling_delay
			print(name, "killed by time")
			self.queue_free()
			falling_in_the_void = true
			falling_once = false
	else:
		falling_in_the_void = false
		falling_once = true
		
	return falling_in_the_void
			


var stop_once = true
var stoped = false
var stoped_position:Vector3
func is_stoped():
	if velocity_z == 0.0:
		if stop_once:
			print(name, " stoped at ", position)
			stoped_position=position



			stoped = true
			stop_once = false
	else:
		stoped = false
		stop_once = true
	return stoped
	
	
var move_once = true
var moving = false
var moving_position:Vector3
func is_moving():
	if velocity_z != 0.0:
		if move_once:
			print(name, " moving from ", position )
			moving_position=position
			


			
			
			moving = true
			move_once = false

	else:
		moving = false
		move_once = true
	return moving

func distance_between_moving_and_stop():
	if moving_position != null and stoped_position != null:
		var distance=moving_position.distance_to(stoped_position)
		print("distance ", distance)
		return distance



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

func on_ground_animation(_collider, _delta):

	if ray.is_colliding() and _collider.name == "StaticBody3D"  : #and is_in_group("ground"): #
		change_ray_length(ray,-1)
		
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








var dir = 0.0
var rotation_speed = 2.5 # Maximum rotation speed on the Y-axis in degrees per second
var rotation_angle = 180.0 # Rotation angle in degrees
var timer=0.0
func _holes_detector(_collider, _delta):
	if ray.is_colliding():
		if !ray_forward.is_colliding():
			print("forward")
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
#				print("urgent")
				ai_rotation_urgent(_delta)
		
		translate_object_local(Vector3(0,0,dir) * _delta)
		if ray.is_colliding() and ray_backward.is_colliding() and ray_forward.is_colliding() and ray_left.is_colliding() and ray_right.is_colliding():
			await get_tree().create_timer(0.8).timeout # avoid tight corner out falling in water
			ai_random_rotation(_delta)
			on_ground = true

		if !ray.is_colliding() and !ray_backward.is_colliding() and !ray_forward.is_colliding() and !ray_left.is_colliding() and !ray_right.is_colliding():
			print("falling in the void")

#			await get_tree().create_timer(0.2).timeout
			on_ground = false
#			self.queue_free()


func is_on_ground():
	if ray.is_colliding():
		on_ground=true
		return on_ground
	else:
		on_ground=false
		return on_ground



func detect_360_deg_rotation(delta):
	var new_rotation = transform.basis.get_rotation_quaternion()
#	print(new_rotation)
	

	
func jump_over_holes(_delta):
	if !ray_jump.is_colliding() and ray_left.is_colliding() and ray_right.is_colliding():
		## jumping over holes
		print("jump")
		is_jumping=true
		translate(Vector3(0,1.0,0.25))
		print("jump over")
		is_jumping=false


func climb_up(_delta):
	# in dev dirty bugged
	var raycol = ray.get_collision_point()
	var rayfor = ray_forward.get_collision_point()
	var rayback = ray_backward.get_collision_point()
	if raycol.y < rayfor.y or raycol.y < rayback.y:
#		print("upstair")
		change_ray_length(ray,-1.5)
		self.position.y = rayfor.y - _delta
	if raycol.y > rayfor.y or raycol.y > rayback.y:
		change_ray_length(ray,-1.5)
#		print("downstair")
	else:
		await get_tree().create_timer(1).timeout
		change_ray_length(ray,-1.0)

var translation= Vector3()
func falling(_delta):
	if !ray.is_colliding() and !ray_forward.is_colliding():
		change_ray_length(ray,-1.0)
		
		var direction = Vector3(0, 0, 1)
		translate_object_local(Vector3(0,0,0.8) * speed * direction * _delta)

		animation_player.play("fall")

		
var ai_rotation_speed = 2
var ai_target_rotation = 0.0
var ai_current_rotation = 0.0

func ai_rotation(_rotation, _delta):
	var rotation_input = _rotation * speed * _delta
	ai_target_rotation = rotation_input * ai_rotation_speed
	ai_current_rotation = lerp(ai_current_rotation, ai_target_rotation, _delta * ai_rotation_speed)
	rotate_y(ai_current_rotation)

func ai_random_rotation(_delta):
	ai_rotation(randi_range(-1, 1), _delta)

func ai_rotation_urgent(_delta):
	ai_rotation(0.5, _delta)


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
			change_ray_length(ray,-1.5)

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
				change_ray_length(ray,-1)
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


func change_ray_length(_ray, new_length):
	_ray.target_position = Vector3(0, new_length, 0)


var max_speed = 2
var g_speed = 0.0
var deceleration = 0.1 # add deceleration factor

func simulate_gravity(_delta):
	if ray.is_colliding():
#		state = State.GROUND
		pass
	if !ray.is_colliding():
		g_speed += 0.1
		g_speed = clamp(g_speed, 0, max_speed)
		self.global_translate(Vector3(0,-g_speed,0) *_delta)

'''
