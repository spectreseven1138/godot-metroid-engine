extends Node

var Samus: KinematicBody2D
var Animator: Node
var Physics: Node

const id = "grapple"
var animations: = {}
var swing_animations: = {}

var beam: Node2D
var anchor: Node2D

var SpeedboostTimer: Timer = Global.timer([self, "speedboost", []])
var speedboost_charge_time: float
var collision

enum STATES {STAND, SWING, JUMP}
var state: int = STATES.STAND setget set_state

# PHYSICS
const max_angular_velocity = 0.12
const max_speedboost_angular_velocity = 0.25
var angular_velocity: = 0.0
var angular_acceleration: = 0.0
var linear_velocity = Vector2.ZERO
const gravity = 0.2
const damping = 0.998
const speedboost_damping = 1.0
var angle
var beampos: Vector2

const walk_acceleration = 15
const walk_deceleration = 50
const max_walk_speed = 75

const jump_speed = 250
const jump_acceleration = 99999
const jump_time = 0.3
var jump_current_time = 125

var aim_thresholds: = {}

# Called during Samus's readying period
func _init(_samus: KinematicBody2D):
	self.Samus = _samus
	self.Animator = Samus.Animator
	self.Physics = Samus.Physics
	
	yield(Samus, "ready")
	aim_thresholds = {
		Samus.aim.SKY: [0, 30],
		Samus.aim.UP: [30, 65],
		Samus.aim.FRONT: [65, 115],
		Samus.aim.DOWN: [115, 180]
	}
	speedboost_charge_time = Samus.states["run"].speedboost_charge_time*1.25
	
	self.animations = Animator.load_from_json("grapple")
	self.swing_animations = Animator.load_from_json("jump")

# Called every frame while this state is active
func process(_delta):
	
	var original_facing = Samus.facing
	var play_transition = false
	
	if Settings.get("controls/aiming_style") == 0:
		Animator.set_armed(Input.is_action_pressed("arm_weapon"))
	
	if not Input.is_action_pressed("fire_weapon"):
		
		Samus.aiming = Samus.aim.FRONT
		if Input.is_action_pressed("pad_left"):
			Samus.facing = Enums.dir.LEFT
		elif Input.is_action_pressed("pad_right"):
			Samus.facing = Enums.dir.RIGHT
		
		change_state("jump", {"options": ["spin"] if Samus.boosting else ["fall"]})
		return
	
	if Input.is_action_just_pressed("morph_shortcut"):
		change_state("morphball", {"options": ["animate"]})
		return
	elif Input.is_action_just_pressed("jump"):
		if state == STATES.SWING:
			Samus.aiming = Samus.aim.FRONT
			change_state("jump", {"options": ["spin"]})
			return
		else:
			jump_current_time = jump_time
			set_state(STATES.JUMP)
	
	vOverlay.SET("Angular velocity", angular_velocity)
	vOverlay.SET("Beam length", beam.length)
	vOverlay.SET("Grapple state", STATES.keys()[state])
	
	var animation: String
	match Samus.aiming:
		Samus.aim.SKY: animation = "aim_sky"
		Samus.aim.UP: animation = "aim_up"
		Samus.aim.DOWN: animation = "aim_down"
		Samus.aim.FLOOR: animation = "aim_floor"
		_: animation = "aim_front"
	
	if state == STATES.STAND:
		set_angle()
		
		var turn = set_aiming(angle, true)
		if turn:
			animations["turn_" + animation].play()
			animations["turn_legs"].play()
		elif not Animator.transitioning(false, true):
			var pad_vector = Shortcut.get_pad_vector("pressed")
			if pad_vector.x == 0 or Physics.vel.x == 0:
				animations["stand_" + animation].play(true)
			else:
				animations["walk_" + animation].play(true, false, false, Global.dir2vector(Samus.facing).x != pad_vector.x)
	elif state == STATES.JUMP:
		if jump_current_time == 0 and Physics.vel.y > 50:
			set_state(STATES.SWING)
			return
		
		set_angle()
		
		var turn = set_aiming(angle, true)
		if turn:
			swing_animations["turn_" + animation].play()
			swing_animations["legs_turn"].play()
		elif not Animator.transitioning(false, true):
			swing_animations[animation].play(true)
			swing_animations["legs"].play(true, false, true)
		
	else:
		set_aiming(angle)
		
		if Samus.aiming == Samus.aim.SKY:
			if angular_velocity > 0.01 and Samus.facing == Enums.dir.LEFT:
				Samus.facing = Enums.dir.RIGHT
			elif angular_velocity < -0.01 and Samus.facing == Enums.dir.RIGHT:
				Samus.facing = Enums.dir.LEFT
		
		if Samus.facing != original_facing:
			swing_animations["turn_" + animation].play()
			swing_animations["legs_turn"].play()
		elif not Animator.transitioning(false, true):
			swing_animations[animation].play(true)
			swing_animations["legs"].play(true, false, true)
	
# Changes Samus's state to the passed state script
func change_state(new_state_key: String, data: Dictionary = {}):
	Samus.change_state(new_state_key, data)
	if beam:
		beam.queue_free()
	beam = null
	anchor = null
	SpeedboostTimer.stop()
	
	Samus.rotation = 0
	Physics.vel = get_velocity_carryover()
	Physics.apply_velocity = true

func get_velocity_carryover() -> Vector2:
	var ret = linear_velocity
	ret *= Vector2(85, 45)
	return ret

func set_aiming(angle: float, set_facing:=false):
	
	if angle == null or (state in [STATES.SWING, STATES.SWING] and Samus.aiming == Samus.aim.SKY):
		return
	
	if Samus.aiming == Samus.aim.FLOOR:
		Samus.aiming = Samus.aim.DOWN
	elif Samus.aiming == Samus.aim.NONE:
		Samus.aiming = Samus.aim.FRONT
	angle = rad2deg(angle)
	
	var buffer = 5
	var current = aim_thresholds.keys().find(Samus.aiming)
	if abs(angle) < aim_thresholds[Samus.aiming][0] - buffer and current > 0:
		Samus.aiming = aim_thresholds.keys()[current - 1]
	elif abs(angle) > aim_thresholds[Samus.aiming][1] + buffer and current < len(aim_thresholds) - 1:
		Samus.aiming = aim_thresholds.keys()[current + 1]
	
	if set_facing and abs(angle) > 2:
		if sign(angle) == -1 and Samus.facing == Enums.dir.LEFT:
			Samus.facing = Enums.dir.RIGHT
			return true
		elif sign(angle) == 1 and Samus.facing == Enums.dir.RIGHT:
			Samus.facing = Enums.dir.LEFT
			return true
		return false

func set_angle():
	if beam.fire_pos:
		angle = anchor.global_position.angle_to_point(beam.fire_pos.global_position) - deg2rad(90)
		angle = (Vector2.LEFT.rotated(angle) * Vector2(1, -1)).angle()

# Called when Samus's state changes to this one
func init_state(data: Dictionary):
	anchor = data["anchor"]
	beam = data["beam"]
	set_state(STATES.STAND if Samus.is_on_floor() else STATES.SWING, false)
	
	angle = anchor.global_position.angle_to_point(beam.global_position) - deg2rad(90)
	angle = (Vector2.LEFT.rotated(angle) * Vector2(1, -1)).angle()

func physics_process(delta: float):
	var pad_vector = Shortcut.get_pad_vector("pressed")
	delta*=60
	if state == STATES.STAND or state == STATES.JUMP:
		
		if state == STATES.JUMP:
			if jump_current_time != 0 and Input.is_action_pressed("jump"):
				Physics.accelerate_y(jump_acceleration, jump_speed, Enums.dir.UP)
				jump_current_time -= delta/60
				if jump_current_time < 0:
					jump_current_time = 0
			else:
				jump_current_time = 0
		else:
			if not Samus.is_on_floor():
				set_state(STATES.SWING)
				return
			jump_current_time = 0
		
		var pad_x: float = Shortcut.get_pad_vector("pressed").x
		
		var capped: = false
		if beam.fire_pos:
			capped = beam.set_length(beam.fire_pos.global_position.distance_to(anchor.global_position)*2) and sign(pad_x) == sign(angle)
		if pad_x != 0 and not capped:
			Physics.vel.x = Shortcut.add_to_limit(Physics.vel.x*delta, walk_acceleration, max_walk_speed*pad_x)
		else:
			Physics.vel.x = Shortcut.add_to_limit(Physics.vel.x*delta, walk_deceleration, 0)
		return
	else:
		jump_current_time = 0
	
	angular_acceleration = ((-gravity) / beam.length) * sin(angle)
	angular_velocity += angular_acceleration*delta
	angular_velocity *= (speedboost_damping*delta) if Samus.boosting else (damping*delta)
	angle += angular_velocity*delta
	
	if beam.fire_pos:
		beampos = beam.fire_pos.global_position
	vOverlay.SET("beampos", beampos)
	
	if Samus.aiming == Samus.aim.SKY:
		angular_velocity += pad_vector.x*0.0005
		Samus.rotation = (Vector2.LEFT.rotated(angle) * Vector2(-1, 1)).angle()
	else:
		Samus.rotation = 0
	
	var max_velocity = max_speedboost_angular_velocity if Samus.boosting else max_angular_velocity
	angular_velocity = min(max(angular_velocity, -max_velocity), max_velocity)
	
	if Samus.is_upgrade_active(Enums.Upgrade.SPEEDBOOSTER) and (abs(angular_velocity) < 0.04 or pad_vector.x != sign(angular_velocity)):
		SpeedboostTimer.start(speedboost_charge_time)
		Samus.boosting = false
	
	linear_velocity = anchor.global_position + Vector2(beam.length*sin(angle), beam.length*cos(angle)) - beampos #Samus.global_position - Samus.to_local(beam.global_position)
	collision = Samus.move_and_collide(linear_velocity)
	if collision and jump_current_time == 0:
		if collided:
			return
		collided = true
		var collision_angle = collision.normal.dot(Vector2.UP)
		print(collision_angle)
		if collision.normal.y < 0 and abs(collision_angle) <= 135:
			set_state(STATES.STAND)
			return
		elif collision.normal.y > 0 and abs(collision_angle) <= 135:
			angular_velocity = 0
			if sign(collision.normal.y) == pad_vector.y:
				beam.length += pad_vector.y*2
		else:
			change_state("jump", {"options": ["fall"]})
			return
	else:
		collided = false
		beam.length += pad_vector.y*2

var collided = false


func speedboost():
	Samus.boosting = true

func set_state(value: int, adjust_beam_length:=true):
	state = value
	
	if state == STATES.SWING:
		if adjust_beam_length:
			beam.length /= 2
#			beam.length -= 25
		
		Physics.apply_velocity = false
		angular_velocity = 0
		angular_acceleration = 0.0
		collision = null
		
	elif state == STATES.STAND:
		SpeedboostTimer.stop()
		Physics.apply_velocity = true
		Samus.rotation = 0
