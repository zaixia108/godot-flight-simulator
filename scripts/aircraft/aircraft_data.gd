extends Resource
class_name AircraftData

## 飞机数据资源
## 存储飞机的物理特性和性能参数

# 基本物理属性
@export var mass: float = 2000.0  # 质量 (kg)
@export var wing_area: float = 20.0  # 翼面积 (m²)
@export var wing_span: float = 10.0  # 翼展 (m)

# 推力参数
@export var max_thrust: float = 15000.0  # 最大推力 (N)
@export var wep_thrust_multiplier: float = 1.2  # WEP推力倍增器

# 空气动力系数
@export var lift_coefficient: float = 0.5  # 升力系数
@export var drag_coefficient: float = 0.03  # 阻力系数
@export var induced_drag_factor: float = 0.05  # 诱导阻力因子

# 控制面效率
@export var pitch_rate: float = 1.0  # 俯仰速率 (rad/s)
@export var roll_rate: float = 2.0  # 滚转速率 (rad/s)
@export var yaw_rate: float = 0.5  # 偏航速率 (rad/s)

# 失速参数
@export var stall_angle: float = 15.0  # 失速攻角 (度)
@export var max_aoa: float = 20.0  # 最大攻角 (度)

# 结构限制
@export var max_g_force: float = 8.0  # 最大G力
@export var structural_speed_limit: float = 250.0  # 结构速度限制 (m/s)

# 燃油系统
@export var fuel_capacity: float = 1000.0  # 燃油容量 (L)
@export var fuel_consumption: float = 0.5  # 燃油消耗率 (L/s at full throttle)
