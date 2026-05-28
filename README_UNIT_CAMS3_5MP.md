# Unit CamS3-5MP ESP-Claw 固件

这是一个为 M5Stack Unit CamS3-5MP 定制的 ESP-Claw 固件，支持通过微信远程控制拍照。

## 📋 项目概览

### 功能特性

- ✅ **远程拍照** - 通过微信发送命令即可拍照
- ✅ **5MP 高清** - 支持 OV5640 传感器，最高 2592x1944 分辨率
- ✅ **自动保存** - 照片保存到 SD 卡
- ✅ **IM 发送** - 自动将照片发送到微信/Telegram
- ✅ **多命令支持** - 支持多种触发词（"拍照"、"拍一张"、"/snap" 等）

### 技术架构

```
┌─────────────────────────────────────┐
│         微信/Telegram               │
│    (发送 "拍照" / "/snap")          │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│      ESP-Claw Router Rules          │
│   (匹配 IM 消息关键词)              │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│    camera_snap.lua (Lua 脚本)       │
│  - 初始化相机 (OV5640)              │
│  - 拍摄照片 (1920x1080 JPEG)        │
│  - 保存到 SD 卡                     │
│  - 通过 IM 发送                     │
│  - 清理资源                         │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│      Camera HAL (V4L2 抽象)         │
│  (esp_video → esp_camera 驱动)      │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│    Unit CamS3-5MP 硬件              │
│  - ESP32-S3 (N16R8)                 │
│  - OV5640 相机 (5MP)                │
│  - PSRAM (8MB)                      │
│  - SD 卡                            │
└─────────────────────────────────────┘
```

## 🚀 快速开始

### 方法 1：使用 GitHub Actions 构建（推荐）

无需安装 ESP-IDF 开发环境，直接在 GitHub 上编译并下载固件。

#### 步骤 1：推送到 GitHub

```bash
cd esp-claw
git add .
git commit -m "Add Unit CamS3-5MP support with camera snap feature"
git remote add origin https://github.com/你的用户名/esp-claw.git
git push -u origin main
```

#### 步骤 2：触发构建

**自动触发**（推荐）：
- 推送代码后自动构建
- 修改板级配置或 Lua 脚本后自动构建

**手动触发**：
1. 访问你的 GitHub 仓库
2. 点击 "Actions" 标签
3. 选择 "Build Unit CamS3-5MP Firmware"
4. 点击 "Run workflow"
5. 选择分支，点击 "Run workflow"

#### 步骤 3：下载固件

**使用下载脚本**（推荐）：

```powershell
# Windows PowerShell
.\tools\download-firmware.ps1 -RepoUrl "https://github.com/你的用户名/esp-claw"

# 或指定输出目录
.\tools\download-firmware.ps1 -RepoUrl "https://github.com/你的用户名/esp-claw" -OutputDir ".\my-firmware"
```

**手动下载**：
1. 在 GitHub Actions 页面点击最新的成功构建
2. 滚动到页面底部 "Artifacts" 部分
3. 下载 `unit-cams3-5mp-firmware.zip`
4. 解压到本地目录

#### 步骤 4：烧录固件

```bash
# 解压固件
unzip unit-cams3-5mp-firmware.zip -d firmware/

# 烧录（使用 flash_args）
cd firmware
esptool.py --chip esp32s3 --port COM3 write_flash @flash_args

# 或使用合并固件（更简单）
esptool.py --chip esp32s3 --port COM3 write_flash 0x0 merged_firmware.bin
```

### 方法 2：本地构建

如果你已经安装了 ESP-IDF 开发环境：

```bash
cd esp-claw/application/edge_agent

# 设置目标芯片
idf.py set-target esp32s3

# 选择板级配置
# 方法 A: 手动复制
cp boards/m5stack/unit_cams3_5mp/sdkconfig.defaults.board sdkconfig.defaults.board
cp boards/m5stack/unit_cams3_5mp/board_*.yaml .

# 方法 B: 使用 menuconfig
idf.py menuconfig
# Board Configuration → Board Selection → m5stack → unit_cams3_5mp

# 编译
idf.py build

# 烧录
idf.py -p COM3 flash monitor
```

## 📖 使用指南

### 微信拍照

1. **添加设备为好友**（首次使用）
   - 确保设备已连接 WiFi
   - 设备会自动登录微信

2. **发送拍照命令**
   ```
   拍照
   拍一张
   /snap
   拍个照
   来张照片
   photo
   take a photo
   ```

3. **接收照片**
   - 设备会自动回复 "📸 正在拍照，请稍候..."
   - 拍照完成后发送照片信息
   - 最后发送照片文件

### 查看保存的照片

照片保存在 SD 卡根目录：
```
/sdcard/snap_<timestamp>.jpg
```

### 自定义配置

#### 修改拍照分辨率

编辑 `fatfs_image/skills/camera_snap/scripts/camera_snap.lua`：

```lua
-- 修改第 15-16 行
camera.open(camera_paths.dev_path, {
    format = "JPEG",
    width = 2592,      -- 改为 5MP
    height = 1944,
    nearest = true
})
```

#### 修改 JPEG 质量

```lua
-- 修改第 18 行
sensor:set_quality(8)  -- 0-63，数值越小质量越高
```

#### 添加新的触发词

编辑 `fatfs_image/router_rules/router_rules.json`：

```json
{
  "id": "im_camera_snap_command",
  "match": {
    "text_patterns": ["拍照", "拍一张", "/snap", "你的新触发词"]
  }
}
```

## 📁 项目结构

```
esp-claw/
├── application/edge_agent/
│   ├── boards/m5stack/unit_cams3_5mp/    # 板级配置
│   │   ├── board_info.yaml               # 板级元数据
│   │   ├── board_devices.yaml            # OV5640 相机定义
│   │   ├── board_peripherals.yaml        # I2C 总线配置
│   │   ├── sdkconfig.defaults.board      # ESP-IDF 配置
│   │   └── readme.md                     # 板级说明
│   │
│   └── fatfs_image/
│       ├── skills/camera_snap/           # 拍照技能
│       │   ├── SKILL.md                  # 技能描述
│       │   └── scripts/camera_snap.lua   # 拍照脚本
│       │
│       └── router_rules/router_rules.json # 消息路由规则
│
├── .github/workflows/
│   └── build-unit-cams3-5mp.yml          # GitHub Actions 构建配置
│
├── tools/
│   └── download-firmware.ps1             # 固件下载脚本
│
├── BUILD_GUIDE.md                        # 构建指南
└── README.md                             # 本文件
```

## 🔧 硬件要求

### M5Stack Unit CamS3-5MP

- **主控**: ESP32-S3-WROOM-1 (N16R8)
  - 双核 Xtensa 32-bit LX7 @ 240MHz
  - 16MB Flash
  - 8MB PSRAM (Octal SPI)
- **相机**: OV5640 (5MP)
- **接口**:
  - USB Type-C (供电和编程)
  - Grove (I2C)
  - SD 卡槽

### 引脚定义

| 功能 | GPIO | 说明 |
|------|------|------|
| PWDN | -1 | 电源控制 (未使用) |
| RESET | 21 | 复位 |
| XCLK | 11 | 主时钟输出 |
| SIOD | 17 | I2C 数据线 (SCCB) |
| SIOC | 41 | I2C 时钟线 (SCCB) |
| D7-D0 | 13,4,10,5,7,16,15,6 | 数据总线 |
| VSYNC | 42 | 帧同步 |
| HREF | 18 | 行同步 |
| PCLK | 12 | 像素时钟 |
| LED | 14 | 状态指示灯 |

## ⚙️ 配置说明

### ESP-IDF 配置 (sdkconfig.defaults.board)

```ini
# CPU
CONFIG_ESP_DEFAULT_CPU_FREQ_MHZ_240=y

# Flash: 16MB QIO @ 80MHz
CONFIG_ESPTOOLPY_FLASHMODE_QIO=y
CONFIG_ESPTOOLPY_FLASHFREQ_80M=y
CONFIG_ESPTOOLPY_FLASHSIZE_16MB=y

# PSRAM: 8MB Octal @ 80MHz
CONFIG_SPIRAM=y
CONFIG_SPIRAM_MODE_OCT=y
CONFIG_SPIRAM_SPEED_80M=y

# Camera: OV5640 over DVP 8-bit
CONFIG_ESP_BOARD_DEV_CAMERA_SUPPORT=y
CONFIG_ESP_VIDEO_ENABLE_DVP_VIDEO_DEVICE=y
CONFIG_CAMERA_OV5640=y
CONFIG_CAMERA_OV5640_AUTO_DETECT_DVP_INTERFACE_SENSOR=y
CONFIG_CAMERA_OV5640_DVP_JPEG_1920X1080_15FPS=y
CONFIG_CAMERA_OV5640_DVP_DEFAULT_FMT_JPEG_1920X1080_15FPS=y

# Lua modules
CONFIG_APP_CLAW_LUA_MODULE_CAMERA=y
CONFIG_APP_CLAW_LUA_MODULE_IMAGE=y
CONFIG_APP_CLAW_LUA_MODULE_STORAGE=y
```

### 相机配置 (board_devices.yaml)

```yaml
- name: camera
  type: camera
  sub_type: dvp
  config:
    dvp_config:
      reset_io: 21
      pwdn_io: -1
      vsync_io: 42
      de_io: 18        # HREF
      pclk_io: 12
      xclk_io: 11
      xclk_freq: 20000000
      data_width: CAM_CTLR_DATA_WIDTH_8
      data_io:
        data_io_0: 6
        data_io_1: 15
        data_io_2: 16
        data_io_3: 7
        data_io_4: 5
        data_io_5: 10
        data_io_6: 4
        data_io_7: 13
```

## 🐛 故障排除

### 构建失败

**查看构建日志**：
1. 访问 GitHub Actions 页面
2. 点击失败的 workflow run
3. 查看详细日志

**常见问题**：
- 缺少依赖：检查 `sdkconfig.defaults.board`
- 引脚冲突：检查 `board_devices.yaml`
- 内存不足：检查 PSRAM 配置

### 烧录失败

**检查串口**：
```bash
# Windows
dir COM*

# Linux
ls /dev/ttyUSB*
```

**进入下载模式**：
1. 按住 BOOT 按钮
2. 短按 RST 按钮
3. 松开 BOOT 按钮
4. 执行烧录命令

### 相机不工作

**检查日志**：
```bash
idf.py -p COM3 monitor
```

**常见错误**：
- `Camera init failed`: 检查引脚配置
- `Frame buffer allocation failed`: 检查 PSRAM 配置
- `JPEG encoding failed`: 降低分辨率或提高质量值

### IM 连接失败

**检查 WiFi**：
- 确认设备已连接到 WiFi
- 检查信号强度

**检查 IM 配置**：
- 确认微信/Telegram 已登录
- 检查网络连接

## 📊 性能指标

- **拍照延迟**: < 2 秒（从命令到照片）
- **照片大小**: 约 200-400 KB (1920x1080 JPEG)
- **内存占用**: PSRAM 使用约 2-4 MB
- **连续拍照**: 建议间隔 2-3 秒

## 🔐 安全说明

- 照片保存在本地 SD 卡
- 仅通过 IM 发送给命令发送者
- 不会自动分享到公开平台
- 建议定期清理 SD 卡

## 📚 相关文档

- [BUILD_GUIDE.md](BUILD_GUIDE.md) - 详细构建指南
- [IMPLEMENTATION_REPORT.md](../IMPLEMENTATION_REPORT.md) - 实施报告
- [ESP-Claw 官方文档](https://docs.espressif.com/projects/esp-idf/)
- [M5Stack Unit CamS3-5MP](https://docs.m5stack.com/en/unit/Unit-CamS3-5MP)

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

本项目基于 ESP-Claw 许可证 (Apache-2.0)

---

**提示**：如果遇到问题，请先查看 GitHub Actions 构建日志和串口监控输出，大部分问题都能从中找到原因。
