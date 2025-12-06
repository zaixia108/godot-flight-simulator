extends RigidBody3D
class_name AircraftController

## 飞机主控制器
## 整合所有子系统并处理物理更新

# 组件引用
var flight_model: FlightModel
var flight_controls: FlightControls
var mouse_aim: MouseAim
var damage_model: DamageModel

# 飞机数据
@export var aircraft_data: AircraftData

# 当前状态
var current_speed: float = 0.0
var current_altitude: float = 0.0
var current_g_force: float = 1.0
var angle_of_attack: float = 0.0

# 上一帧的速度（用于计算加速度）
var last_velocity: Vector3 = Vector3.ZERO

# 相机引用
var camera: Camera3D

# 调试信息
var show_debug: bool = true

func _ready():
	# 加载默认飞机数据（如果没有指定）
	if not aircraft_data:
		aircraft_data = load("res://resources/default_aircraft.tres")
		if not aircraft_data:
			push_error("无法加载飞机数据!")
			return
	
	# 初始化组件
	flight_model = FlightModel.new(aircraft_data)
	add_child(flight_model)
	
	flight_controls = FlightControls.new()
	add_child(flight_controls)
	
	mouse_aim = MouseAim.new()
	add_child(mouse_aim)
	
	damage_model = DamageModel.new()
	add_child(damage_model)
	
	# 设置物理属性
	mass = aircraft_data.mass
	gravity_scale = 0.0  # 我们手动处理重力
	
	# 设置初始速度
	linear_velocity = -global_transform.basis.z * 80.0  # 80 m/s 前进
	
	# 连接信号
	damage_model.aircraft_destroyed.connect(_on_aircraft_destroyed)
	
	# 查找相机
	call_deferred("_find_camera")
	
	print("飞机初始化完成")

func _find_camera():
	# 在场景树中查找相机
	var cam = get_viewport().get_camera_3d()
	if cam:
		camera = cam

func _physics_process(delta):
	# 更新当前状态
	current_altitude = global_position.y
	current_speed = linear_velocity.length()
	flight_model.altitude = current_altitude
	flight_model.velocity = linear_velocity
	
	# 计算G力
	var acceleration = (linear_velocity - last_velocity) / delta
	current_g_force = flight_model.calculate_g_force(acceleration)
	last_velocity = linear_velocity
	
	# 计算攻角
	angle_of_attack = flight_model.calculate_aoa(linear_velocity, -global_transform.basis.z)
	
	# 处理输入
	flight_controls.process_input(delta)
	
	# 检查鼠标瞄准
	if Input.is_action_pressed("mouse_aim") and camera:
		if not mouse_aim.is_mouse_aim_active:
			mouse_aim.update_mouse_aim(true)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
		# 使用鼠标位置计算目标方向
		var mouse_pos = get_viewport().get_mouse_position()
		var target_dir = mouse_aim.calculate_target_direction(camera, mouse_pos)
		mouse_aim.target_direction = target_dir
		
		# 获取鼠标瞄准控制输入
		var aim_controls = mouse_aim.calculate_aim_controls(global_transform, target_dir, delta)
		
		# 混合键盘和鼠标输入
		flight_controls.elevator = lerp(flight_controls.elevator, aim_controls.y, 0.3)
		flight_controls.aileron = lerp(flight_controls.aileron, aim_controls.x, 0.3)
	else:
		if mouse_aim.is_mouse_aim_active:
			mouse_aim.update_mouse_aim(false)
	
	# 更新损伤系统
	damage_model.update_fire(delta)
	
	# 应用空气动力学
	apply_aerodynamics(delta)
	
	# 应用控制输入
	apply_control_inputs(delta)

func apply_aerodynamics(delta: float) -> void:
	# 计算总力
	var total_force = flight_model.calculate_total_force(
		linear_velocity,
		global_transform.basis,
		flight_controls.throttle,
		flight_controls.use_wep
	)
	
	# 应用伤害修正
	if total_force.dot(-global_transform.basis.z) > 0:  # 推力方向
		var thrust_component = total_force.project(-global_transform.basis.z)
		var other_forces = total_force - thrust_component
		total_force = thrust_component * damage_model.thrust_multiplier + other_forces
	
	# 应用力
	apply_central_force(total_force)

func apply_control_inputs(delta: float) -> void:
	# 获取控制向量
	var control = flight_controls.get_control_vector()
	
	# 应用伤害影响
	control *= damage_model.control_efficiency
	control.x += damage_model.roll_bias  # 机翼不对称造成的滚转
	
	# 计算力矩
	var torque = flight_model.calculate_torque(control, angular_velocity, delta)
	
	# 应用力矩（通过调整角速度）
	angular_velocity += torque * delta
	
	# 限制角速度（防止过度旋转）
	var max_angular_vel = 3.0
	angular_velocity = angular_velocity.limit_length(max_angular_vel)

func _integrate_forces(state: PhysicsDirectBodyState3D):
	# 在物理积分中应用角速度
	state.angular_velocity = angular_velocity

func _on_aircraft_destroyed():
	print("飞机已被摧毁!")
	# 这里可以添加爆炸效果、游戏结束逻辑等

## 获取当前速度（km/h）
func get_speed_kmh() -> float:
	return current_speed * 3.6

## 获取航向角度
func get_heading() -> float:
	var forward = -global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	var angle = atan2(forward.x, forward.z)
	return rad_to_deg(angle)

## 应用伤害（外部接口）
func apply_damage(component: String, amount: float) -> void:
	damage_model.damage_component(component, amount)
