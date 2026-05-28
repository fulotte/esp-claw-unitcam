# M5Stack Unit CamS3-5MP Board Support

ESP-Claw 板级支持包，专为 M5Stack Unit CamS3-5MP (OV5640) 相机模块设计。

## 硬件规格

### 主控芯片
- **ESP32-S3-WROOM-1 (N16R8)**
  - 双核 Xtensa 32-bit LX7 @ 240MHz
  - 16MB QIO Flash @ 80MHz
  - 8MB Octal PSRAM @ 80MHz
  - Wi-Fi 802.11 b/g/n
  - Bluetooth 5.0 (LE)

### 相机传感器
- **OV5640 5MP CMOS**
  - 最高分辨率：2592 x 1944 (5MP)
  - 像素尺寸：1.4µm x 1.4µm
  - 输出格式：JPEG, RGB565, YUV422
  - 自动对焦：否（定焦）
  - 自动曝光/白平衡：支持

### 接口
- USB Type-C (供电 + 烧录)
- Grove (I2C 扩展)
- SD 卡槽（部分型号）

## GPIO 引脚映射

| 功能 | GPIO | 说明 |
|------|------|------|
| **相机数据总线** | | |
| D0 | 6 | 数据线 0 |
| D1 | 15 | 数据线 1 |
| D2 | 16 | 数据线 2 |
| D3 | 7 | 数据线 3 |
| D4 | 5 | 数据线 4 |
| D5 | 10 | 数据线 5 |
| D6 | 4 | 数据线 6 |
| D7 | 13 | 数据线 7 |
| **相机控制信号** | | |
| VSYNC | 42 | 帧同步 |
| HREF | 18 | 行同步 |
| PCLK | 12 | 像素时钟 |
| XCLK | 11 | 主时钟输出 (20MHz) |
| RESET | 21 | 相机复位 |
| PWDN | -1 | 未使用 |
| **I2C (SCCB)** | | |
| SIOD (SDA) | 17 | I2C 数据线 |
| SIOC (SCL) | 41 | I2C 时钟线 |
| **其他** | | |
| LED | 14 | 状态指示灯 |

## 文件结构

`\\
unit_cams3_5mp/
├── board_info.yaml              # 板级元数据
├── board_devices.yaml           # 设备配置（相机、LED）
├── board_peripherals.yaml       # 外设配置（I2C）
├── sdkconfig.defaults.board     # ESP-IDF 编译配置
├── readme.md                    # 本文档
└── fatfs_image/
    ├── skills/
    │   └── camera_snap/
    │       ├── SKILL.md         # 技能描述
    │       └── scripts/
    │           └── camera_snap.lua  # 拍照脚本
    └── router_rules/
        └── camera_snap_rules.json   # IM 消息路由规则
`\\

## 编译和烧录

### 1. 准备环境

确保已安装 ESP-IDF v5.1 或更高版本：

`ash
# 设置 ESP-IDF 环境
. \/export.sh
`

### 2. 配置目标芯片

`ash
cd esp-claw/application/edge_agent
idf.py set-target esp32s3
`

### 3. 选择板级配置

`ash
# 使用 menuconfig 选择板级配置
idf.py menuconfig

# 导航到:
# Board Configuration → M5Stack → Unit CamS3-5MP
`

或者手动复制配置：

`ash
cp boards/m5stack/unit_cams3_5mp/*.yaml .
cp boards/m5stack/unit_cams3_5mp/sdkconfig.defaults.board sdkconfig.defaults
`

### 4. 编译固件

`ash
idf.py build
`

### 5. 烧录固件

`ash
# 通过串口烧录
idf.py -p /dev/ttyUSB0 flash

# 或使用 Windows 串口号
idf.py -p COM3 flash
`

### 6. 监控串口输出

`ash
idf.py -p /dev/ttyUSB0 monitor
`

## 使用方法

### IM 触发拍照

在微信、Telegram 或其他 IM 平台发送以下命令：

- **基本拍照**: 拍照 / 拍一张 / 	ake photo / snap
- **高清拍照**: 高清拍照 / 5MP拍照 / hd photo

设备会自动拍摄照片并返回保存路径。

### 通过 Agent 调用

在 ESP-Claw Agent 对话中请求拍照：

`
用户: 帮我拍张照片
Agent: 好的，正在拍照...
[调用 camera_snap 技能]
Agent: 照片已保存: /fatfs/storage/camera_snap.jpg (2592x1944, 524288 bytes)
`

### 直接运行脚本

通过串口 CLI 运行拍照脚本：

`
lua_run /fatfs/skills/camera_snap/scripts/camera_snap.lua
`

带参数运行：

`
lua_run /fatfs/skills/camera_snap/scripts/camera_snap.lua {"filename":"my_photo.jpg","width":1920,"height":1080}
`

## 拍照参数

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| filename | string | "camera_snap.jpg" | 输出文件名 |
| dir | string | "" | 存储子目录 |
| width | integer | 2592 | 图像宽度 |
| height | integer | 1944 | 图像高度 |
| timeout_ms | integer | 5000 | 超时时间（毫秒） |
| skip_frames | integer | 3 | 预热帧跳过数 |

## 内存优化

OV5640 5MP JPEG 图像需要约 500KB-1MB 内存。本配置使用以下优化：

1. **PSRAM 帧缓冲**: 所有相机帧缓冲存储在 PSRAM 中
2. **JPEG 压缩**: 使用 JPEG 格式减少内存占用
3. **单帧模式**: b_count = 1，避免多帧缓冲
4. **及时释放**: 拍照后立即释放帧资源

## 故障排除

### 相机初始化失败

**现象**: camera.open failed 错误

**解决方案**:
1. 检查 PSRAM 是否正确配置（查看启动日志）
2. 确认 GPIO 引脚连接正确
3. 降低分辨率测试："width": 640, "height": 480
4. 检查 I2C 通信（SCCB 需要正确初始化）

### 照片模糊或曝光异常

**现象**: 照片过暗、过亮或模糊

**解决方案**:
1. 增加 skip_frames 参数（默认 3，可增加到 5）
2. 确保相机镜头清洁
3. 检查环境光线是否充足
4. 等待几秒让自动曝光稳定

### 内存不足

**现象**: memory allocation failed 错误

**解决方案**:
1. 确认 PSRAM 已启用（查看 sdkconfig）
2. 减少 b_count（应为 1）
3. 降低 JPEG 质量（增加 quality 值）
4. 降低分辨率

### 照片发送失败

**现象**: 拍照成功但 IM 发送失败

**解决方案**:
1. 检查 IM 连接状态（Wi-Fi、网络）
2. 确认照片大小不超过 IM 限制（微信 5MB，Telegram 10MB）
3. 降低 JPEG 质量以减小文件大小
4. 检查 router_rules.json 配置是否正确

## 技术架构

### Camera HAL 抽象

ESP-Claw 使用 V4L2 抽象层驱动相机：

`
Lua Script (camera_snap.lua)
    ↓
lua_module_camera (Lua bindings)
    ↓
camera_hal.c (V4L2 抽象)
    ↓
claw_video / esp_video (V4L2 driver)
    ↓
DVP Camera Hardware (OV5640)
`

### 帧生命周期

1. **打开相机**: camera.open() 初始化 V4L2 设备
2. **获取帧**: camera.get_frame() 借用帧缓冲（borrow）
3. **使用帧**: 访问帧数据、保存为 JPEG
4. **释放帧**: rame:release() 或 <close> 自动释放
5. **关闭相机**: camera.close() 释放所有资源

### 内存布局

`
内部 SRAM (512KB)
├── 代码段
├── 数据段
└── 堆栈

PSRAM (8MB)
├── 相机帧缓冲 (1-2MB)
├── JPEG 编码缓冲
└── 其他大对象
`

## 性能参数

| 指标 | 数值 | 说明 |
|------|------|------|
| 拍照延迟 | ~500ms | 从触发到保存完成 |
| 连拍间隔 | ≥ 2s | 避免内存不足 |
| JPEG 大小 | 500KB-1MB | 5MP, quality=12 |
| 内存占用 | ~1.5MB | 帧缓冲 + 编码 |

## 参考资源

- [ESP-Claw 官方文档](https://esp-claw.com/)
- [M5Stack Unit CamS3-5MP 产品页](https://docs.m5stack.com/en/unit/Unit-CAMS3%205MP)
- [OV5640 数据手册](https://www.ovt.com/products/ov5640/)
- [ESP-IDF 相机驱动](https://github.com/espressif/esp32-camera)

## 许可证

Apache-2.0 License
