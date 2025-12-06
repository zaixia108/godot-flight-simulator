extends Node
class_name MouseAim

## 鼠标瞄准系统
## 模拟战争雷霆的鼠标飞行模式，使用PID控制器

# PID控制器参数
var pid_pitch: PIDController
var pid_roll: PIDController
var pid_yaw: PIDController

# 鼠标目标
var target_direction: Vector3 = Vector3.FORWARD
var is_mouse_aim_active: bool = false

# 灵敏度
@export var mouse_sensitivity: float = 0.002
@export var aim_distance: float = 100.0

# 屏幕中心
var screen_center: Vector2

## PID控制器类
class PIDController:
	var kp: float  # 比例增益
	var ki: float  # 积分增益
	var kd: float  # 微分增益
	
	var integral: float = 0.0
	var last_error: float = 0.0
	
	func _init(p: float, i: float, d: float):
		kp = p
		ki = i
		kd = d
	
	func calculate(error: float, delta: float) -> float:
		# 积分项
		integral += error * delta
		integral = clamp(integral, -10.0, 10.0)  # 防止积分饱和
		
		# 微分项
		var derivative = (error - last_error) / delta if delta > 0 else 0.0
		last_error = error
		
		# PID输出
		return kp * error + ki * integral + kd * derivative
	
	func reset():
		integral = 0.0
		last_error = 0.0

func _init():
	# 初始化PID控制器 (P, I, D)
	pid_pitch = PIDController.new(2.0, 0.1, 0.5)
	pid_roll = PIDController.new(2.5, 0.1, 0.6)
	pid_yaw = PIDController.new(1.0, 0.05, 0.3)

func _ready():
	var viewport = get_viewport()
	if viewport:
		screen_center = viewport.get_visible_rect().size / 2.0

## 处理鼠标输入
func process_mouse_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and is_mouse_aim_active:
		# 更新目标方向（相对于屏幕中心的偏移）
		pass  # 由主控制器处理

## 更新鼠标瞄准状态
func update_mouse_aim(active: bool) -> void:
	is_mouse_aim_active = active
	if not active:
		# 重置PID控制器
		pid_pitch.reset()
		pid_roll.reset()
		pid_yaw.reset()

## 计算目标方向（从相机和鼠标位置）
func calculate_target_direction(camera: Camera3D, mouse_pos: Vector2) -> Vector3:
	if not camera:
		return Vector3.FORWARD
	
	# 从屏幕位置计算世界空间射线
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * aim_distance
	
	return (to - from).normalized()

## 计算控制输入以飞向目标方向
func calculate_aim_controls(
	current_transform: Transform3D,
	target_dir: Vector3,
	delta: float
) -> Vector3:
	
	var forward = -current_transform.basis.z
	var right = current_transform.basis.x
	var up = current_transform.basis.y
	
	# 计算目标方向与当前朝向的误差
	var error_vec = target_dir - forward
	
	# 俯仰误差（在up方向上的投影）
	var pitch_error = error_vec.dot(up)
	
	# 滚转误差（需要根据目标方向计算期望的滚转角）
	# 简化处理：保持水平
	var current_roll = atan2(right.y, up.y)
	var roll_error = -current_roll
	
	# 偏航误差（在right方向上的投影）
	var yaw_error = error_vec.dot(right)
	
	# 使用PID控制器计算控制量
	var pitch_control = pid_pitch.calculate(pitch_error, delta)
	var roll_control = pid_roll.calculate(roll_error, delta)
	var yaw_control = pid_yaw.calculate(yaw_error, delta)
	
	# 限制控制量范围
	pitch_control = clamp(pitch_control, -1.0, 1.0)
	roll_control = clamp(roll_control, -1.0, 1.0)
	yaw_control = clamp(yaw_control, -1.0, 1.0)
	
	return Vector3(roll_control, pitch_control, yaw_control)

## 获取瞄准准星位置（用于HUD显示）
func get_crosshair_position(camera: Camera3D) -> Vector2:
	if not camera:
		return screen_center
	
	# 将目标方向投影到屏幕空间
	var target_pos_3d = camera.global_transform.origin + target_direction * aim_distance
	return camera.unproject_position(target_pos_3d)
