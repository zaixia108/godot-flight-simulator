extends Node
class_name FlightModel

## 飞行物理模型
## 基于真实空气动力学原理计算飞机的力和力矩

# 物理常量
const AIR_DENSITY_SEA_LEVEL: float = 1.225  # 海平面空气密度 (kg/m³)
const GRAVITY: float = 9.81  # 重力加速度 (m/s²)

# 飞机数据引用
var aircraft_data: AircraftData

# 当前状态
var velocity: Vector3 = Vector3.ZERO
var angular_velocity: Vector3 = Vector3.ZERO
var altitude: float = 0.0
var air_density: float = AIR_DENSITY_SEA_LEVEL

func _init(data: AircraftData = null):
	if data:
		aircraft_data = data

## 计算当前高度的空气密度
func calculate_air_density(alt: float) -> float:
	# 使用简化的气压递减模型
	# ρ = ρ₀ * e^(-h/H) 其中 H ≈ 8500m
	return AIR_DENSITY_SEA_LEVEL * exp(-alt / 8500.0)

## 计算攻角 (Angle of Attack)
func calculate_aoa(vel: Vector3, forward: Vector3) -> float:
	if vel.length() < 0.1:
		return 0.0
	
	# 计算速度向量在飞机纵向平面上的投影
	var vel_normalized = vel.normalized()
	var forward_normalized = forward.normalized()
	
	# 攻角是速度方向与机身轴线的夹角
	var dot = vel_normalized.dot(forward_normalized)
	return acos(clamp(dot, -1.0, 1.0))

## 计算侧滑角 (Sideslip Angle)
func calculate_sideslip(vel: Vector3, right: Vector3) -> float:
	if vel.length() < 0.1:
		return 0.0
	
	var vel_normalized = vel.normalized()
	var right_normalized = right.normalized()
	
	# 侧滑角是速度在机身横向上的分量
	return asin(clamp(vel_normalized.dot(right_normalized), -1.0, 1.0))

## 计算升力
## L = 0.5 * ρ * V² * S * Cl
func calculate_lift(vel: Vector3, up: Vector3, aoa: float) -> Vector3:
	if not aircraft_data:
		return Vector3.ZERO
	
	var speed_squared = vel.length_squared()
	if speed_squared < 0.01:
		return Vector3.ZERO
	
	# 根据攻角调整升力系数
	var cl = aircraft_data.lift_coefficient
	var aoa_deg = rad_to_deg(aoa)
	
	# 在失速角之前线性增加，失速后急剧下降
	if aoa_deg < aircraft_data.stall_angle:
		cl *= (1.0 + aoa_deg / 10.0)
	else:
		# 失速后升力大幅下降
		var stall_factor = 1.0 - (aoa_deg - aircraft_data.stall_angle) / 10.0
		cl *= max(0.3, stall_factor)
	
	var lift_magnitude = 0.5 * air_density * speed_squared * aircraft_data.wing_area * cl
	return up * lift_magnitude

## 计算阻力
## D = 0.5 * ρ * V² * S * Cd
func calculate_drag(vel: Vector3, aoa: float) -> Vector3:
	if not aircraft_data:
		return Vector3.ZERO
	
	var speed = vel.length()
	if speed < 0.01:
		return Vector3.ZERO
	
	# 零升阻力
	var cd = aircraft_data.drag_coefficient
	
	# 诱导阻力（与升力相关）
	var aoa_deg = rad_to_deg(aoa)
	var induced_drag = aircraft_data.induced_drag_factor * pow(aoa_deg / 10.0, 2)
	cd += induced_drag
	
	var drag_magnitude = 0.5 * air_density * speed * speed * aircraft_data.wing_area * cd
	return -vel.normalized() * drag_magnitude

## 计算推力
func calculate_thrust(throttle: float, forward: Vector3, use_wep: bool = false) -> Vector3:
	if not aircraft_data:
		return Vector3.ZERO
	
	var thrust = aircraft_data.max_thrust * clamp(throttle, 0.0, 1.0)
	
	# WEP加成
	if use_wep and throttle >= 0.99:
		thrust *= aircraft_data.wep_thrust_multiplier
	
	return forward * thrust

## 计算重力
func calculate_gravity() -> Vector3:
	if not aircraft_data:
		return Vector3.ZERO
	
	return Vector3.DOWN * (aircraft_data.mass * GRAVITY)

## 计算总的力
func calculate_total_force(
	vel: Vector3,
	transform_basis: Basis,
	throttle: float,
	use_wep: bool = false
) -> Vector3:
	var forward = -transform_basis.z  # 飞机朝向-Z方向，所以前进方向是-Z
	var up = transform_basis.y
	var right = transform_basis.x
	
	# 更新空气密度
	air_density = calculate_air_density(altitude)
	
	# 计算角度
	var aoa = calculate_aoa(vel, forward)
	
	# 计算各分力
	var lift = calculate_lift(vel, up, aoa)
	var drag = calculate_drag(vel, aoa)
	var thrust = calculate_thrust(throttle, forward, use_wep)
	var gravity = calculate_gravity()
	
	return lift + drag + thrust + gravity

## 计算力矩（用于旋转控制）
func calculate_torque(
	control_input: Vector3,  # x: 滚转, y: 俯仰, z: 偏航
	angular_vel: Vector3,
	delta: float
) -> Vector3:
	if not aircraft_data:
		return Vector3.ZERO
	
	var torque = Vector3.ZERO
	
	# 俯仰力矩（绕X轴）
	torque.x = control_input.y * aircraft_data.pitch_rate
	
	# 滚转力矩（绕Z轴）
	torque.z = control_input.x * aircraft_data.roll_rate
	
	# 偏航力矩（绕Y轴）
	torque.y = control_input.z * aircraft_data.yaw_rate
	
	# 添加阻尼以防止过度旋转
	var damping = 0.5
	torque -= angular_vel * damping
	
	return torque

## 计算当前G力
func calculate_g_force(acceleration: Vector3) -> float:
	return acceleration.length() / GRAVITY
