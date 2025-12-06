extends Camera3D
class_name FollowCamera

## 第三人称跟随相机
## 平滑跟随飞机并保持固定距离

# 目标飞机
@export var target: Node3D

# 相机参数
@export var follow_distance: float = 20.0
@export var follow_height: float = 5.0
@export var follow_smoothness: float = 5.0
@export var look_ahead_distance: float = 10.0

# 当前速度（用于平滑）
var current_velocity: Vector3 = Vector3.ZERO

func _ready():
	# 如果没有指定目标，尝试查找场景中的飞机
	if not target:
		call_deferred("_find_target")

func _find_target():
	# 在场景中查找AircraftController
	var aircraft = get_tree().get_first_node_in_group("aircraft")
	if aircraft:
		target = aircraft
		print("相机找到目标: ", aircraft.name)

func _physics_process(delta):
	if not target:
		return
	
	# 计算目标位置
	var target_transform = target.global_transform
	var target_forward = -target_transform.basis.z
	var target_up = target_transform.basis.y
	
	# 相机应该在飞机后方和上方
	var offset = target_forward * -follow_distance + target_up * follow_height
	var desired_position = target.global_position + offset
	
	# 平滑移动到目标位置
	global_position = global_position.lerp(desired_position, follow_smoothness * delta)
	
	# 计算注视点（飞机前方一点）
	var look_at_point = target.global_position + target_forward * look_ahead_distance
	
	# 平滑看向目标
	look_at(look_at_point, Vector3.UP)

## 设置跟随距离
func set_follow_distance(distance: float) -> void:
	follow_distance = clamp(distance, 10.0, 50.0)

## 设置跟随高度
func set_follow_height(height: float) -> void:
	follow_height = clamp(height, 2.0, 15.0)
