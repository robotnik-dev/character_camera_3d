extends Camera3D
class_name CharacterCamera3D

## An orbit camera for Third Person Characters that handles the tracking and
## following and keeps the target in screen. Character must be of type CharacterBody3D
## Just set the y-position of this node in the editor above your character mesh.

@export_category("Auto Focus Camera")
## The speed of the following camera
@export_range(2.0, 8.0, 0.1) var camera_speed: float = 5.0:
	set(value):
		camera_speed = clampf(value, 2.0, 8.0)

## Zoom of the camera
@export_range(0.9, 4.8, 0.1) var camera_zoom: float = 3.0:
	get:
		return camera_zoom
	set(value):
		camera_zoom = clampf(value, minimum_zoom, maximum_zoom)
		if spring_arm:
			spring_arm.spring_length = camera_zoom

## tries to push the camera back when character leaves the screen
@export var keep_character_in_screen: bool = true

## smoothness for snapping to character when leaving screen, plattform snap, etc.
@export_range(45.0, 75.0, 0.1) var camera_snap_smoothness: float = 60.0

## when keeping the character in screen, how smooth the camera zooms out
@export_range(90.0, 100.0, 0.1) var zoom_smoothness: float = 96.0
## Speed of the auto rotation when moving
@export_range(1.3, 1.8, 0.05) var auto_rotation_speed: float = 1.5

@export_category("Manual Camera Control")
@export_range(0.1, 1.3, 0.1) var zoom_speed: float = 0.7:
	set(value):
		zoom_speed = clampf(value, 0.1, 2.0)
@export_range(0.9, 3.0, 0.1) var minimum_zoom: float = 2.0
@export_range(3.1, 4.8, 0.1) var maximum_zoom: float = 4.0
## Sensitivity for manual rotating the camera
@export_range(0.1, 1.0, 0.1) var control_sensitivity: float = 0.5
## speed of manual rotating the camera around character
@export_range(90.0, 100.0, 0.1) var rotation_smoothness: float = 95.0
@export_range(-1.2, -0.1, 0.05) var rotation_limit_top: float = -0.75
@export_range(0.0, 1.2, 0.05) var rotation_limit_bottom: float = 0.8
## Manual rotating inverted
@export var y_inverted: bool = false

@export_category("Optional")
@export var collision_shape_for_springarm: Shape3D:
	set(value):
		collision_shape_for_springarm = value
		if spring_arm:
			spring_arm.shape = collision_shape_for_springarm

## top level node for movement checks needed
var character: CharacterBody3D
## ghost_target node for smooth follwing and plattform snapping etc.
var ghost_target: Node3D
## parent node for keeping the camera at a distance and collision checks
var spring_arm: SpringArm3D
var h_rotation_node: Node3D

## local initial position of springarm (pivot) node. Basically the base height
## of the focus point (ideally above character head)
var _start_position: Vector3
## helper target position for smooth transitions
var _ghost_position: Vector3
## helper for smooth zoom transitions
var _zoom_distance: float:
	set(value):
		_zoom_distance = clampf(value, minimum_zoom, maximum_zoom)


func _ready() -> void:
	_setup_springarm_parent()
	_setup_ghost_target()
	_set_initial_values()

func _setup_springarm_parent() -> void:
	character = owner as CharacterBody3D
	spring_arm = SpringArm3D.new()
#	if not collision_shape_for_springarm:
#		collision_shape_for_springarm = CapsuleShape3D.new()
	spring_arm.add_excluded_object(character.get_rid())
	h_rotation_node = Node3D.new()
	h_rotation_node.top_level = true
	
	add_sibling.call_deferred(spring_arm, true)
	add_sibling.call_deferred(h_rotation_node, true)
	reparent.call_deferred(spring_arm)
	spring_arm.reparent.call_deferred(h_rotation_node)

func _setup_ghost_target() -> void:
	ghost_target = Node3D.new()
	add_child(ghost_target)

func _set_initial_values() -> void:
	_start_position = global_position
	ghost_target.position.y = character.global_position.y + _start_position.y
	spring_arm.shape = collision_shape_for_springarm
	spring_arm.spring_length = camera_zoom
	_zoom_distance = camera_zoom

func _physics_process(delta : float):
	if Engine.is_editor_hint():
		return
	
	if not (_character_is_looking_towards_cam() or _character_x_y_plane_velocity_is_zero()):
		_auto_rotate()
	
	if not _character_x_y_plane_velocity_is_zero():
		_center_camera_y()
	
	var look_direction: Vector2 = _get_look_direction()
	if look_direction.length() > 0:
		_manual_rotate(look_direction * control_sensitivity)

	_interpolate_translation(delta)
	
	_interpolate_zoom(delta)
	
	_keep_character_in_center()
	
	_update_ghost_transform()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("zoom_in"):
		var zoom_in = Input.get_action_strength("zoom_in")
		_zoom_distance = camera_zoom - zoom_in * zoom_speed
	elif event.is_action_pressed("zoom_out"):
		var zoom_out = Input.get_action_strength("zoom_out")
		_zoom_distance = camera_zoom + zoom_out * zoom_speed

## follow the rotation of the character
func _auto_rotate() -> void:
	var offset: float = character.rotation.y - h_rotation_node.rotation.y
	var target_angle: float = (
		character.rotation.y - 2 * PI if offset > PI
		else character.rotation.y + 2 * PI if offset < -PI
		else character.rotation.y
	)

	var weight = (auto_rotation_speed / 100)
	
	h_rotation_node.rotation.y = lerpf(h_rotation_node.rotation.y, target_angle, weight)

## rotate the Node3D for horizontal rotation and the springarm vor vertical
func _manual_rotate(offset: Vector2) -> void:
	var target_rotation: Vector3
	target_rotation.y = h_rotation_node.rotation.y - offset.x
	target_rotation.x = spring_arm.rotation.x + offset.y
	if y_inverted:
		target_rotation.x * -1.0
	target_rotation.x = clamp(target_rotation.x, rotation_limit_top, rotation_limit_bottom)
	target_rotation.z = 0
	
	var weight = 1 - (rotation_smoothness / 100)
	spring_arm.rotation.x = lerpf(spring_arm.rotation.x, target_rotation.x, weight)
	h_rotation_node.rotation.y = lerpf(h_rotation_node.rotation.y, target_rotation.y, weight)

## auto center camera when movement happens
func _center_camera_y() -> void:
	var weight = 1 - (rotation_smoothness / 100)
	spring_arm.rotation.x = lerpf(spring_arm.rotation.x, 0, weight)

## interpolates between the ghost target and the SpringArm3D
## the SpringArm3D should follow the ghost target
func _interpolate_translation(delta: float) -> void:
	var translation_factor: float = camera_speed * delta
	var ghost_target_transform: Transform3D = ghost_target.global_transform
	var origin_transform: Transform3D = Transform3D(Basis(), h_rotation_node.global_transform.origin)
	var basis_transform: Transform3D = Transform3D(h_rotation_node.global_transform.basis, Vector3())
	# TODO: jittering when hitting collision
	if _is_springarm_colliding():
#		translation_factor = 0.8
#		print("R")
		pass
#	if _character_is_looking_towards_cam():
#		translation_factor *= 1.5
	origin_transform = origin_transform.interpolate_with(ghost_target_transform, translation_factor)
	h_rotation_node.global_transform = Transform3D(basis_transform.basis, origin_transform.origin)

## handles transition between desired zoom and current zoom. Manipulates property
## springarm.spring_length in the background
func _interpolate_zoom(delta: float) -> void:
	if keep_character_in_screen:
		# check for out of bounds events
		var frustum: Array[Plane] = get_frustum()
		var top_plane: Plane = frustum[3]
		var bottom_plane: Plane = frustum[5]
		if bottom_plane.is_point_over(character.global_position):
			# check if no springarm collision happens, only then zoom out
			if not _is_springarm_colliding():
				_zoom_distance = camera_zoom + camera_zoom / 4
			else:
				_zoom_distance = camera_zoom
	var weight = 1 - (zoom_smoothness / 100)
	camera_zoom = lerpf(camera_zoom, _zoom_distance, weight)

## tries to keep character in the frustum of the camera and updates the height
## of the ghost transform node
func _keep_character_in_center() -> void:
	var frustum: Array[Plane] = get_frustum()
	var top_plane: Plane = frustum[3]
	var bottom_plane: Plane = frustum[5]
	if (
	top_plane.is_point_over(character.global_position + _start_position) or \
	bottom_plane.is_point_over(character.global_position)
	):
		if keep_character_in_screen:
			_ghost_position.y = character.global_position.y + _start_position.y
	
	# plattform snap
	elif character.is_on_floor():
		_ghost_position.y = character.global_position.y + _start_position.y

## apply all position changes to the ghost transform
func _update_ghost_transform() -> void:
	var desired_position: Vector3 
	desired_position.x = character.global_position.x
	desired_position.z = character.global_position.z
	desired_position.y = _ghost_position.y
	
	var weight = 1 - (camera_snap_smoothness / 100)
	ghost_target.global_position = ghost_target.global_position.slerp(desired_position, weight)

# HELPER FUNCTIONS

## for auto rotation only. Compares the player look at direction with the
## camera direction
func _character_is_looking_towards_cam() -> bool:
	var char_dir: Vector3 = character.global_transform.basis.z.normalized()
	var pivot_dir: Vector3 = spring_arm.global_transform.basis.z.normalized()
	
	var char_projection = char_dir.project(Vector3.FORWARD)
	var pivot_projection = pivot_dir.project(Vector3.FORWARD)

	var pivot_y_rot: float = spring_arm.global_rotation.y
	var char_y_rot: float = character.global_rotation.y
	var diff: float = pivot_y_rot - char_y_rot
	var offset: float = 0.4
	
	return abs(diff) >= PI - offset and abs(diff) <= PI + offset

## for auto rotation only. Returns true if character is not moving
func _character_x_y_plane_velocity_is_zero() -> bool:
	return is_equal_approx(character.velocity.x, 0) or is_equal_approx(character.velocity.z, 0)

## get input action strength for manual camera control
func _get_look_direction() -> Vector2:
	return Vector2(
			Input.get_action_strength("look_right") - Input.get_action_strength("look_left"),
			Input.get_action_strength("look_down") - Input.get_action_strength("look_up")
		).normalized()

## compares the actual length of the springarm vs. the desired length
func _is_springarm_colliding() -> bool:
	return not is_equal_approx(spring_arm.get_hit_length(), camera_zoom)
