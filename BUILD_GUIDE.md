# Unit CamS3-5MP 固件构建指南

本项目支持通过 GitHub Actions 自动构建固件，你可以在本地下载编译好的二进制文件并烧录到设备。

## 快速开始

### 方法 1：通过 GitHub 网页手动触发

1. **将代码推送到 GitHub**
   ```bash
   cd esp-claw
   git add .
   git commit -m "Add Unit CamS3-5MP support"
   git push origin main
   ```

2. **在 GitHub 上触发构建**
   - 访问你的 GitHub 仓库页面
   - 点击 "Actions" 标签
   - 选择 "Build Unit CamS3-5MP Firmware"
   - 点击 "Run workflow" 按钮
   - 选择分支，点击 "Run workflow"

3. **等待构建完成**
   - 构建通常需要 15-30 分钟
   - 使用 `espressif/idf:release-v5.5` Docker 镜像
   - 自动编译 ESP-IDF 项目和所有依赖

4. **下载固件**
   - 构建完成后，点击对应的 workflow run
   - 在页面底部的 "Artifacts" 部分
   - 下载 `unit-cams3-5mp-firmware` 压缩包

5. **解压并烧录**
   ```bash
   # 解压下载的固件
   unzip unit-cams3-5mp-firmware.zip -d firmware/
   
   # 使用 esptool.py 烧录
   cd firmware
   esptool.py --chip esp32s3 --port COM3 write_flash @flash_args
   ```

### 方法 2：自动触发（推荐）

当你修改以下文件并推送到 GitHub 时，构建会自动触发：

- `application/edge_agent/boards/m5stack/unit_cams3_5mp/**` - 板级配置
- `application/edge_agent/fatfs_image/**` - Lua 脚本和路由规则
- `.github/workflows/build-unit-cams3-5mp.yml` - 构建配置

### 方法 3：创建 Release 版本

如果你想创建一个带版本号的可发布固件：

1. **手动触发并创建 Release**
   - 在 "Run workflow" 页面
   - 勾选 "Create release with binaries"
   - 运行 workflow

2. **或者打标签触发**
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
   - 这会自动触发构建并创建 GitHub Release
   - Release 页面会包含合并好的固件二进制文件

## 烧录说明

下载的固件包包含以下文件：

```
firmware/
├── bootloader/
│   └── bootloader.bin          # 引导程序
├── partition_table/
│   └── partition-table.bin     # 分区表
├── ota_data_initial.bin        # OTA 数据
├── edge_agent.bin              # 主应用程序
├── fatfs_image.bin             # 文件系统镜像（含 Lua 脚本）
├── flash_args                  # 烧录参数文件
├── flash_project_args          # 项目烧录参数
└── flasher_args.json           # JSON 格式烧录参数
```

### 使用 esptool.py 烧录

```bash
# 安装 esptool.py
pip install esptool

# 烧录（自动读取 flash_args）
esptool.py --chip esp32s3 --port COM3 write_flash @flash_args

# 或者手动指定每个文件
esptool.py --chip esp32s3 --port COM3 write_flash \
  0x0 bootloader/bootloader.bin \
  0x8000 partition_table/partition-table.bin \
  0xd000 ota_data_initial.bin \
  0x20000 edge_agent.bin \
  0x310000 fatfs_image.bin
```

### 使用 ESP-IDF 工具烧录

如果你有完整的 ESP-IDF 开发环境：

```bash
# 将下载的固件复制到 build 目录
cp -r firmware/* application/edge_agent/build/

# 使用 idf.py 烧录
cd application/edge_agent
idf.py -p COM3 flash
```

## 合并的固件镜像

如果你下载了 `merged_binary/` 目录，会找到一个合并的单一固件文件：

```bash
# 烧录合并固件（最简单）
esptool.py --chip esp32s3 --port COM3 write_flash 0x0 merged_firmware.bin
```

这个文件包含了所有必要的组件，可以直接烧录到 0x0 地址。

## 故障排除

### 构建失败

1. **检查构建日志**
   - 在 GitHub Actions 页面点击失败的 workflow run
   - 查看详细的构建日志
   - 常见问题会显示在日志中

2. **常见错误**
   - 缺少依赖：检查 `sdkconfig.defaults.board` 中的配置
   - 引脚冲突：检查 `board_devices.yaml` 中的 GPIO 定义
   - 内存不足：检查 PSRAM 配置是否正确

3. **本地调试**
   ```bash
   # 使用 Docker 在本地重现构建环境
   docker run -it -v $(pwd):/project -w /project espressif/idf:release-v5.5 bash
   
   # 在容器内执行构建
   cd application/edge_agent
   pip install idf_build_apps esp-bmgr-assist
   python ../../.gitlab/ci/build_apps.py . \
     --config "=" \
     -t esp32s3 \
     -r 1 \
     -vv \
     --board unit_cams3_5mp \
     --board-path boards/m5stack
   ```

### 烧录失败

1. **检查串口连接**
   - 确认设备已连接到电脑
   - 确认串口号（Windows: COM3, Linux: /dev/ttyUSB0）
   - 尝试降低波特率：`esptool.py --baud 115200 ...`

2. **进入下载模式**
   - 按住 BOOT 按钮
   - 短按 RST 按钮
   - 松开 BOOT 按钮
   - 然后执行烧录命令

3. **权限问题（Linux）**
   ```bash
   # 添加用户到 dialout 组
   sudo usermod -a -G dialout $USER
   # 重新登录生效
   ```

## 自定义构建

如果你需要修改构建配置：

### 修改固件版本

编辑 `.github/workflows/build-unit-cams3-5mp.yml`：

```yaml
- name: Create release
  uses: softprops/action-gh-release@v1
  with:
    tag_name: v1.0.0-${{ github.run_number }}
    name: Unit CamS3-5MP Firmware v1.0.0-${{ github.run_number }}
```

### 添加额外的构建步骤

```yaml
- name: Run custom script
  run: |
    echo "Running custom build steps..."
    # 你的自定义命令
```

### 修改保留时间

```yaml
- name: Upload build artifacts
  uses: actions/upload-artifact@v4
  with:
    retention-days: 90  # 延长到 90 天
```

## 成本说明

GitHub Actions 对公开仓库完全免费，对私有仓库：
- 每月 2000 分钟免费额度
- 每次构建约 15-30 分钟
- 大约可以构建 60-130 次/月

对于个人项目通常完全够用。

## 技术支持

如果遇到问题：
1. 查看 GitHub Actions 构建日志
2. 参考 `IMPLEMENTATION_REPORT.md` 了解技术细节
3. 参考 ESP-Claw 官方文档：https://docs.espressif.com/projects/esp-idf/

---

**提示**：建议将 `merged_binary/` 中的合并固件作为主要烧录方式，最简单且不容易出错。
