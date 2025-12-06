extends Node
class_name DamageModel

## 伤害模型系统
## 管理飞机各部件的损伤状态

# 部件健康度 (0.0 = 完全损坏, 1.0 = 完好)
var engine_health: float = 1.0
var left_wing_health: float = 1.0
var right_wing_health: float = 1.0
var tail_health: float = 1.0
var fuselage_health: float = 1.0

# 火灾系统
var is_on_fire: bool = false
var fire_intensity: float = 0.0

# 性能影响
var thrust_multiplier: float = 1.0
var control_efficiency: float = 1.0
var roll_bias: float = 0.0  # 机翼损伤导致的滚转倾向

signal aircraft_destroyed
signal component_damaged(component: String, health: float)
signal fire_started
signal fire_extinguished

## 对特定部件造成伤害
func damage_component(component: String, damage: float) -> void:
	match component:
		"engine":
			engine_health = max(0.0, engine_health - damage)
			if engine_health < 0.3 and not is_on_fire:
				start_fire()
		"left_wing":
			left_wing_health = max(0.0, left_wing_health - damage)
		"right_wing":
			right_wing_health = max(0.0, right_wing_health - damage)
		"tail":
			tail_health = max(0.0, tail_health - damage)
		"fuselage":
			fuselage_health = max(0.0, fuselage_health - damage)
	
	emit_signal("component_damaged", component, get_component_health(component))
	update_performance_modifiers()
	check_destruction()

## 获取部件健康度
func get_component_health(component: String) -> float:
	match component:
		"engine":
			return engine_health
		"left_wing":
			return left_wing_health
		"right_wing":
			return right_wing_health
		"tail":
			return tail_health
		"fuselage":
			return fuselage_health
	return 1.0

## 更新性能修正因子
func update_performance_modifiers() -> void:
	# 发动机损伤影响推力
	thrust_multiplier = engine_health
	
	# 机翼损伤影响控制效率
	var wing_avg = (left_wing_health + right_wing_health) / 2.0
	var tail_factor = tail_health
	control_efficiency = min(wing_avg, tail_factor)
	
	# 机翼不对称造成滚转倾向
	roll_bias = (right_wing_health - left_wing_health) * 0.5
	
	# 火灾影响
	if is_on_fire:
		thrust_multiplier *= (1.0 - fire_intensity * 0.3)
		control_efficiency *= (1.0 - fire_intensity * 0.2)

## 开始火灾
func start_fire() -> void:
	if not is_on_fire:
		is_on_fire = true
		fire_intensity = 0.3
		emit_signal("fire_started")
		print("警告: 发动机起火!")

## 更新火灾状态
func update_fire(delta: float) -> void:
	if is_on_fire:
		# 火灾逐渐加剧
		fire_intensity = min(1.0, fire_intensity + delta * 0.1)
		
		# 火灾持续损伤发动机和机身
		damage_component("engine", delta * 0.05)
		damage_component("fuselage", delta * 0.02)
		
		# 自动灭火条件（引擎完全损坏或速度很低）
		if engine_health <= 0.0:
			extinguish_fire()

## 扑灭火灾
func extinguish_fire() -> void:
	if is_on_fire:
		is_on_fire = false
		fire_intensity = 0.0
		emit_signal("fire_extinguished")
		print("火势已扑灭")

## 检查是否完全毁坏
func check_destruction() -> void:
	# 关键部件损坏超过临界值时飞机毁坏
	if fuselage_health <= 0.0 or (left_wing_health <= 0.0 and right_wing_health <= 0.0):
		emit_signal("aircraft_destroyed")
		print("飞机已毁坏!")

## 修复所有部件（用于测试）
func repair_all() -> void:
	engine_health = 1.0
	left_wing_health = 1.0
	right_wing_health = 1.0
	tail_health = 1.0
	fuselage_health = 1.0
	extinguish_fire()
	update_performance_modifiers()
	print("飞机已完全修复")

## 获取总体健康度
func get_overall_health() -> float:
	return (engine_health + left_wing_health + right_wing_health + tail_health + fuselage_health) / 5.0
