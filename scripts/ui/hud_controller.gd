extends Control
class_name HUDController

## HUD控制器
## 显示飞行仪表数据

# 飞机引用
var aircraft: AircraftController

# UI元素引用
@onready var speed_label: Label = $MarginContainer/VBoxContainer/SpeedLabel
@onready var altitude_label: Label = $MarginContainer/VBoxContainer/AltitudeLabel
@onready var throttle_label: Label = $MarginContainer/VBoxContainer/ThrottleLabel
@onready var g_force_label: Label = $MarginContainer/VBoxContainer/GForceLabel
@onready var heading_label: Label = $MarginContainer/VBoxContainer/HeadingLabel
@onready var aoa_label: Label = $MarginContainer/VBoxContainer/AOALabel
@onready var crosshair: Control = $Crosshair
@onready var info_label: Label = $MarginContainer/VBoxContainer/InfoLabel

func _ready():
	# 查找飞机
	call_deferred("_find_aircraft")

func _find_aircraft():
	var aircraft_node = get_tree().get_first_node_in_group("aircraft")
	if aircraft_node and aircraft_node is AircraftController:
		aircraft = aircraft_node
		print("HUD找到飞机: ", aircraft.name)

func _process(_delta):
	if not aircraft:
		return
	
	# 更新速度显示 (km/h)
	if speed_label:
		var speed_kmh = aircraft.get_speed_kmh()
		speed_label.text = "速度: %d km/h" % speed_kmh
	
	# 更新高度显示 (m)
	if altitude_label:
		var altitude = aircraft.current_altitude
		altitude_label.text = "高度: %d m" % altitude
	
	# 更新油门显示 (%)
	if throttle_label:
		var throttle = aircraft.flight_controls.throttle * 100
		var wep_text = " [WEP]" if aircraft.flight_controls.use_wep else ""
		throttle_label.text = "油门: %d%%%s" % [throttle, wep_text]
	
	# 更新G力显示（带颜色警告）
	if g_force_label:
		var g_force = aircraft.current_g_force
		g_force_label.text = "G力: %.1f" % g_force
		
		# 根据G力改变颜色
		if g_force > 7.0:
			g_force_label.add_theme_color_override("font_color", Color.RED)
		elif g_force > 5.0:
			g_force_label.add_theme_color_override("font_color", Color.ORANGE)
		else:
			g_force_label.add_theme_color_override("font_color", Color.WHITE)
	
	# 更新航向显示
	if heading_label:
		var heading = aircraft.get_heading()
		if heading < 0:
			heading += 360
		heading_label.text = "航向: %d°" % heading
	
	# 更新攻角显示
	if aoa_label:
		var aoa_deg = rad_to_deg(aircraft.angle_of_attack)
		aoa_label.text = "攻角: %.1f°" % aoa_deg
		
		# 接近失速角时警告
		if aoa_deg > aircraft.aircraft_data.stall_angle * 0.8:
			aoa_label.add_theme_color_override("font_color", Color.RED)
		else:
			aoa_label.add_theme_color_override("font_color", Color.WHITE)
	
	# 更新信息标签
	if info_label:
		var info_parts = []
		if aircraft.flight_controls.gear_down:
			info_parts.append("起落架↓")
		if aircraft.flight_controls.flaps > 0.5:
			info_parts.append("襟翼↓")
		if aircraft.flight_controls.airbrake:
			info_parts.append("制动")
		if aircraft.damage_model.is_on_fire:
			info_parts.append("⚠ 起火!")
		
		info_label.text = " | ".join(info_parts) if info_parts.size() > 0 else ""
		
		# 起火时闪烁红色
		if aircraft.damage_model.is_on_fire:
			var blink = int(Time.get_ticks_msec() / 500) % 2 == 0
			info_label.add_theme_color_override("font_color", Color.RED if blink else Color.ORANGE)
		else:
			info_label.add_theme_color_override("font_color", Color.WHITE)
	
	# 更新准星位置（鼠标瞄准模式）
	if crosshair and aircraft.mouse_aim.is_mouse_aim_active:
		crosshair.visible = true
		var camera = get_viewport().get_camera_3d()
		if camera:
			var crosshair_pos = aircraft.mouse_aim.get_crosshair_position(camera)
			crosshair.position = crosshair_pos - crosshair.size / 2
	else:
		if crosshair:
			crosshair.visible = false
