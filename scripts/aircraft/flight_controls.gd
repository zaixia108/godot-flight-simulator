extends Node
class_name FlightControls

## 飞行控制输入系统
## 处理键盘输入并转换为控制指令

# 控制输入 (-1.0 到 1.0)
var elevator: float = 0.0  # 升降舵 (俯仰)
var aileron: float = 0.0   # 副翼 (滚转)
var rudder: float = 0.0    # 方向舵 (偏航)

# 其他控制
var throttle: float = 0.5  # 油门 (0.0 到 1.0)
var flaps: float = 0.0     # 襟翼 (0.0 到 1.0)
var gear_down: bool = true # 起落架
var airbrake: bool = false # 空气制动器
var use_wep: bool = false  # 战争紧急功率

# 控制灵敏度
@export var control_sensitivity: float = 2.0
@export var throttle_change_rate: float = 0.5

# 输入平滑
var input_smoothing: float = 0.1

## 处理键盘输入
func process_input(delta: float) -> void:
	# 俯仰控制 (升降舵)
	var pitch_input = 0.0
	if Input.is_action_pressed("pitch_up"):
		pitch_input += 1.0
	if Input.is_action_pressed("pitch_down"):
		pitch_input -= 1.0
	elevator = lerp(elevator, pitch_input, input_smoothing)
	
	# 滚转控制 (副翼)
	var roll_input = 0.0
	if Input.is_action_pressed("roll_left"):
		roll_input -= 1.0
	if Input.is_action_pressed("roll_right"):
		roll_input += 1.0
	aileron = lerp(aileron, roll_input, input_smoothing)
	
	# 偏航控制 (方向舵)
	var yaw_input = 0.0
	if Input.is_action_pressed("yaw_left"):
		yaw_input -= 1.0
	if Input.is_action_pressed("yaw_right"):
		yaw_input += 1.0
	rudder = lerp(rudder, yaw_input, input_smoothing)
	
	# 油门控制
	if Input.is_action_pressed("throttle_up"):
		throttle = min(1.0, throttle + throttle_change_rate * delta)
	if Input.is_action_pressed("throttle_down"):
		throttle = max(0.0, throttle - throttle_change_rate * delta)
	
	# WEP (战争紧急功率) - 油门满时才能启用
	use_wep = throttle >= 0.99 and Input.is_action_pressed("throttle_up")
	
	# 开关控制
	if Input.is_action_just_pressed("toggle_gear"):
		gear_down = not gear_down
		print("起落架: ", "放下" if gear_down else "收起")
	
	if Input.is_action_just_pressed("toggle_flaps"):
		flaps = 1.0 if flaps < 0.5 else 0.0
		print("襟翼: ", "放下" if flaps > 0.5 else "收起")
	
	if Input.is_action_just_pressed("toggle_airbrake"):
		airbrake = not airbrake
		print("空气制动器: ", "开启" if airbrake else "关闭")

## 获取控制向量 (用于力矩计算)
func get_control_vector() -> Vector3:
	return Vector3(aileron, elevator, rudder) * control_sensitivity

## 重置所有控制
func reset_controls() -> void:
	elevator = 0.0
	aileron = 0.0
	rudder = 0.0
	throttle = 0.5
	flaps = 0.0
	gear_down = true
	airbrake = false
	use_wep = false
