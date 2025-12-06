# 项目实现文档

## 架构概述

本项目采用模块化设计，将飞行模拟器的各个子系统分离为独立的组件。

### 核心架构

```
AircraftController (RigidBody3D)
├── FlightModel (Node)         # 物理计算
├── FlightControls (Node)      # 输入处理
├── MouseAim (Node)            # 鼠标瞄准
└── DamageModel (Node)         # 伤害系统
```

## 模块详解

### 1. AircraftData (Resource)
**文件**: `scripts/aircraft/aircraft_data.gd`

数据资源类，存储飞机的所有物理参数。使用 Godot 的 Resource 系统，可以：
- 在编辑器中可视化编辑
- 创建不同配置的飞机
- 序列化保存和加载

**关键参数**:
- `mass`: 影响惯性和机动性
- `wing_area`: 影响升力大小
- `max_thrust`: 决定最大速度和爬升率
- `stall_angle`: 失速阈值

### 2. FlightModel (Node)
**文件**: `scripts/aircraft/flight_model.gd`

实现真实的空气动力学计算。

**核心公式**:

#### 升力 (Lift)
```
L = 0.5 * ρ * V² * S * Cl
```
其中：
- ρ = 空气密度（随高度变化）
- V = 速度
- S = 翼面积
- Cl = 升力系数（受攻角影响）

**实现细节**:
- 空气密度使用指数衰减模型：`ρ = ρ₀ * e^(-h/8500)`
- 升力系数随攻角线性增加，超过失速角急剧下降
- 失速后升力降至30%

#### 阻力 (Drag)
```
D = 0.5 * ρ * V² * S * Cd
Cd_total = Cd_zero + K * (AoA/10)²
```

包含两部分：
- 零升阻力（基础阻力）
- 诱导阻力（与攻角相关）

#### 推力 (Thrust)
```
T = T_max * throttle * WEP_multiplier
```

WEP（战争紧急功率）在油门100%时可用，提供20%额外推力。

#### 重力 (Gravity)
```
G = m * g * Vector3.DOWN
```

### 3. FlightControls (Node)
**文件**: `scripts/aircraft/flight_controls.gd`

处理所有输入并转换为控制指令。

**输入映射**:
- 俯仰 (Elevator): W/S → -1.0 到 1.0
- 滚转 (Aileron): A/D → -1.0 到 1.0
- 偏航 (Rudder): Q/E → -1.0 到 1.0
- 油门 (Throttle): Shift+W/S → 0.0 到 1.0

**特性**:
- 输入平滑（lerp）避免突变
- 油门渐变避免突然加速
- WEP自动检测（油门≥99%）

### 4. MouseAim (Node)
**文件**: `scripts/aircraft/mouse_aim.gd`

实现战争雷霆风格的鼠标瞄准系统。

**工作原理**:

1. **目标方向计算**:
   - 从相机和鼠标位置计算射线
   - 射线方向即为目标飞行方向

2. **误差计算**:
   ```
   error = target_direction - current_direction
   pitch_error = error · up_vector
   roll_error = current_roll_angle
   yaw_error = error · right_vector
   ```

3. **PID控制器**:
   ```
   output = Kp * error + Ki * ∫error + Kd * d(error)/dt
   ```
   
   三个独立的PID控制器分别控制：
   - 俯仰（P=2.0, I=0.1, D=0.5）
   - 滚转（P=2.5, I=0.1, D=0.6）
   - 偏航（P=1.0, I=0.05, D=0.3）

**特性**:
- 平滑响应，无抖动
- 自动保持水平（滚转归零）
- 积分限幅防止积分饱和

### 5. DamageModel (Node)
**文件**: `scripts/damage/damage_model.gd`

管理飞机损伤和火灾系统。

**部件系统**:
- 发动机 (engine)
- 左机翼 (left_wing)
- 右机翼 (right_wing)
- 尾翼 (tail)
- 机身 (fuselage)

**损伤效果**:

1. **推力降低**:
   ```
   actual_thrust = base_thrust * engine_health
   ```

2. **控制效率降低**:
   ```
   efficiency = min(avg(wing_health), tail_health)
   ```

3. **滚转倾向**:
   ```
   roll_bias = (right_wing - left_wing) * 0.5
   ```

4. **火灾系统**:
   - 发动机损伤>70%时触发
   - 逐渐加剧（0.1/秒）
   - 持续造成损伤
   - 影响推力和控制

### 6. AircraftController (RigidBody3D)
**文件**: `scripts/aircraft/aircraft_controller.gd`

主控制器，整合所有子系统。

**更新流程**:

```
_physics_process(delta):
1. 更新状态（速度、高度、G力）
2. 处理输入（键盘/鼠标）
3. 更新伤害系统
4. 计算空气动力学
5. 应用力和力矩
```

**物理集成**:
- 使用 `apply_central_force()` 施加力
- 直接修改 `angular_velocity` 施加力矩
- 在 `_integrate_forces()` 中应用角速度

### 7. FollowCamera (Camera3D)
**文件**: `scripts/camera/follow_camera.gd`

第三人称跟随相机。

**算法**:
```
desired_pos = target.pos + forward * -distance + up * height
camera.pos = lerp(camera.pos, desired_pos, smoothness * delta)
camera.look_at(target.pos + forward * look_ahead)
```

**参数**:
- `follow_distance`: 相机距离（20m）
- `follow_height`: 相机高度（5m）
- `follow_smoothness`: 平滑系数（5.0）
- `look_ahead_distance`: 前瞻距离（10m）

### 8. HUDController (Control)
**文件**: `scripts/ui/hud_controller.gd`

实时显示飞行参数。

**显示内容**:
- 速度（km/h）：`speed * 3.6`
- 高度（m）：直接读取 `position.y`
- 油门（%）：`throttle * 100`
- G力：`acceleration.length() / 9.81`
- 航向（度）：`atan2(forward.x, forward.z)`
- 攻角（度）：`rad_to_deg(aoa)`

**颜色警告**:
- G力 > 7.0: 红色
- G力 > 5.0: 橙色
- 攻角 > 失速角*0.8: 红色
- 火灾: 闪烁红色

## 场景结构

### Aircraft.tscn
飞机场景包含：

1. **RigidBody3D** (根节点)
   - 质量: 2000kg
   - 重力缩放: 0（手动处理）
   - 初始速度: (0, 0, -80) m/s

2. **视觉模型** (VisualModel)
   - 机身: CSGBox3D (2×1.5×8)
   - 主翼: 2个 CSGBox3D (8×0.3×2)
   - 尾翼: CSGBox3D + 垂直稳定器
   - 螺旋桨: CSGCylinder3D + 2个叶片

3. **碰撞形状**
   - BoxShape3D 匹配机身

### TestWorld.tscn
测试场景包含：

1. **WorldEnvironment**
   - 程序化天空
   - 环境光照

2. **DirectionalLight3D**
   - 模拟太阳光
   - 启用阴影

3. **Ground (StaticBody3D)**
   - 10000×10000 平面
   - 绿色材质

4. **Aircraft** (实例)
   - 起始位置: (0, 1000, 0)
   - 起始速度: 80 m/s 向前

5. **Camera3D**
   - 跟随脚本
   - 初始位置在飞机后方

6. **HUD** (实例)
   - CanvasLayer 覆盖

7. **ReferenceMarkers**
   - 高度参考标记物

## 输入系统

### 项目输入映射
在 `project.godot` 中定义：

```ini
pitch_up = W
pitch_down = S
roll_left = A
roll_right = D
yaw_left = Q
yaw_right = E
throttle_up = Shift+W
throttle_down = Shift+S
toggle_gear = G
toggle_flaps = F
toggle_airbrake = B
mouse_aim = Right Mouse Button
```

### 输入处理流程

1. **键盘输入** → FlightControls
2. **鼠标输入** → MouseAim
3. **混合输入** → AircraftController
4. **控制向量** → FlightModel
5. **力和力矩** → RigidBody3D

## 性能优化

### 优化策略

1. **物理计算**:
   - 仅在 `_physics_process` 中计算
   - 避免重复计算（缓存结果）

2. **HUD更新**:
   - 在 `_process` 中更新（60fps）
   - 整数格式化减少字符串操作

3. **相机平滑**:
   - 使用 `lerp` 而非每帧重新计算
   - 固定平滑系数

4. **信号使用**:
   - 仅在关键事件时发出信号
   - 避免每帧发送信号

## 扩展指南

### 添加新飞机

1. 创建新的 `.tres` 文件
2. 设置不同的参数
3. 在 aircraft.tscn 中引用

### 添加武器系统

1. 创建 `WeaponSystem` 节点
2. 添加到 AircraftController
3. 处理发射输入
4. 实例化子弹/导弹

### 添加音效

1. 创建 `AudioSystem` 节点
2. 基于状态播放音效：
   - 引擎声（基于油门）
   - 风声（基于速度）
   - 失速警告（基于攻角）

### 添加AI

1. 创建 `AIController` 脚本
2. 替换 FlightControls 输入
3. 实现导航算法
4. 使用MouseAim系统的PID控制器

## 调试技巧

### 启用调试输出

在 AircraftController 中：
```gdscript
show_debug = true
```

### 查看物理力

添加箭头可视化：
```gdscript
func _draw_force_vector(force: Vector3, color: Color):
    # 绘制调试箭头
```

### 监控性能

使用 Godot 的性能监视器：
- 按 F3 查看 FPS
- 查看物理帧时间
- 监控内存使用

## 常见问题

### Q: 飞机不响应输入
A: 检查：
1. 输入映射是否正确
2. FlightControls 是否添加到场景
3. 控制台是否有错误

### Q: 飞机立即坠毁
A: 检查：
1. 初始速度是否足够（>50 m/s）
2. 初始高度是否足够（>100 m）
3. 升力系数是否合理

### Q: HUD不显示
A: 检查：
1. HUD 是否添加到场景
2. 飞机是否在 "aircraft" 组中
3. 节点路径是否正确

### Q: 鼠标瞄准不工作
A: 检查：
1. 相机是否正确设置
2. 输入映射是否正确
3. PID参数是否合理

## 物理参数调优

### 升力系数 (lift_coefficient)
- 太低: 需要高速才能飞行
- 太高: 过度灵敏，难以控制
- 推荐: 0.4 - 0.6

### 阻力系数 (drag_coefficient)
- 太低: 无法减速
- 太高: 最大速度太低
- 推荐: 0.02 - 0.05

### 控制速率 (pitch/roll/yaw_rate)
- 太低: 响应迟缓
- 太高: 过度灵敏，难以控制
- 推荐: 
  - pitch: 0.8 - 1.2
  - roll: 1.5 - 2.5
  - yaw: 0.4 - 0.6

### PID参数
调优顺序：
1. 调整 P（比例）直到响应快速
2. 调整 D（微分）减少过冲
3. 调整 I（积分）消除稳态误差

## 版本历史

### v1.0 (当前)
- 完整的飞行物理模型
- 鼠标瞄准系统
- 伤害模型
- HUD显示
- 第三人称相机

### 未来计划
- 音效系统
- 武器系统
- AI对手
- 多人模式
- 更复杂的地形
