# Download Unit CamS3-5MP Firmware from GitHub Actions
# 从 GitHub Actions 下载编译好的固件

param(
    [Parameter(Mandatory=$true)]
    [string]$RepoUrl,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputDir = ".\firmware",
    
    [Parameter(Mandatory=$false)]
    [switch]$Latest
)

Write-Host "=== Unit CamS3-5MP 固件下载工具 ===" -ForegroundColor Cyan
Write-Host ""

# Parse repo owner and name from URL
if ($RepoUrl -match "github\.com/([^/]+)/([^/]+)") {
    $owner = $matches[1]
    $repo = $matches[2]
    Write-Host "仓库: $owner/$repo" -ForegroundColor Green
} else {
    Write-Host "错误: 无效的 GitHub 仓库 URL" -ForegroundColor Red
    Write-Host "示例: https://github.com/username/esp-claw" -ForegroundColor Yellow
    exit 1
}

# Check if gh CLI is installed
$ghInstalled = $null -ne (Get-Command gh -ErrorAction SilentlyContinue)
if (-not $ghInstalled) {
    Write-Host ""
    Write-Host "需要安装 GitHub CLI (gh) 才能下载 artifacts" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "安装方法:" -ForegroundColor Cyan
    Write-Host "  1. 访问: https://cli.github.com/" -ForegroundColor White
    Write-Host "  2. 下载并安装 Windows 版本" -ForegroundColor White
    Write-Host "  3. 运行: gh auth login" -ForegroundColor White
    Write-Host ""
    Write-Host "或者手动下载:" -ForegroundColor Cyan
    Write-Host "  1. 访问: $RepoUrl/actions" -ForegroundColor White
    Write-Host "  2. 点击最新的成功构建" -ForegroundColor White
    Write-Host "  3. 下载 'unit-cams3-5mp-firmware' artifact" -ForegroundColor White
    exit 1
}

# Check if authenticated
try {
    $ghUser = gh api user -q .login 2>$null
    Write-Host "GitHub 用户: $ghUser" -ForegroundColor Green
} catch {
    Write-Host "错误: 未登录 GitHub" -ForegroundColor Red
    Write-Host "运行: gh auth login" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "正在查询构建记录..." -ForegroundColor Cyan

# Get workflow runs
$runs = gh api "repos/$owner/$repo/actions/workflows/build-unit-cams3-5mp.yml/runs" -q '.workflow_runs[] | select(.conclusion == "success")' | ConvertFrom-Json

if ($runs.Count -eq 0) {
    Write-Host "错误: 没有找到成功的构建记录" -ForegroundColor Red
    Write-Host ""
    Write-Host "可能的原因:" -ForegroundColor Yellow
    Write-Host "  1. 还没有触发过构建" -ForegroundColor White
    Write-Host "  2. 构建正在进行中" -ForegroundColor White
    Write-Host "  3. 构建失败了" -ForegroundColor White
    Write-Host ""
    Write-Host "解决方法:" -ForegroundColor Cyan
    Write-Host "  访问: $RepoUrl/actions" -ForegroundColor White
    Write-Host "  手动触发 'Build Unit CamS3-5MP Firmware' workflow" -ForegroundColor White
    exit 1
}

# Select run
if ($Latest) {
    $selectedRun = $runs[0]
    Write-Host "选择最新构建: #$($selectedRun.run_number) ($(Get-Date $selectedRun.created_at -Format 'yyyy-MM-dd HH:mm'))" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "可用的构建记录:" -ForegroundColor Cyan
    for ($i = 0; $i -lt [Math]::Min(10, $runs.Count); $i++) {
        $run = $runs[$i]
        $date = Get-Date $run.created_at -Format "yyyy-MM-dd HH:mm"
        Write-Host "  [$($i+1)] #$($run.run_number) - $date - $($run.head_commit.message.Substring(0, [Math]::Min(50, $run.head_commit.message.Length)))" -ForegroundColor White
    }
    
    $selection = Read-Host "`n请选择要下载的构建 (输入序号，直接回车选择最新)"
    if ([string]::IsNullOrWhiteSpace($selection)) {
        $selectedRun = $runs[0]
    } else {
        $index = [int]$selection - 1
        if ($index -ge 0 -and $index -lt $runs.Count) {
            $selectedRun = $runs[$index]
        } else {
            Write-Host "无效的选择" -ForegroundColor Red
            exit 1
        }
    }
}

Write-Host ""
Write-Host "正在获取 artifacts..." -ForegroundColor Cyan

# Get artifacts for this run
$artifacts = gh api "repos/$owner/$repo/actions/runs/$($selectedRun.id)/artifacts" -q '.artifacts[] | select(.name == "unit-cams3-5mp-firmware")' | ConvertFrom-Json

if ($null -eq $artifacts) {
    Write-Host "错误: 未找到固件 artifact" -ForegroundColor Red
    exit 1
}

Write-Host "找到 artifact: $($artifacts.name) ($([Math]::Round($artifacts.size_in_bytes / 1MB, 2)) MB)" -ForegroundColor Green

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Host "创建目录: $OutputDir" -ForegroundColor Green
}

# Download artifact
Write-Host ""
Write-Host "正在下载固件..." -ForegroundColor Cyan
$zipPath = Join-Path $OutputDir "unit-cams3-5mp-firmware.zip"

gh api "repos/$owner/$repo/actions/artifacts/$($artifacts.id)/zip" > $zipPath

if (-not (Test-Path $zipPath)) {
    Write-Host "错误: 下载失败" -ForegroundColor Red
    exit 1
}

Write-Host "下载完成: $zipPath" -ForegroundColor Green

# Extract
Write-Host ""
Write-Host "正在解压..." -ForegroundColor Cyan
$extractPath = Join-Path $OutputDir "build_$($selectedRun.run_number)"
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

Write-Host "解压完成: $extractPath" -ForegroundColor Green

# Show contents
Write-Host ""
Write-Host "固件内容:" -ForegroundColor Cyan
Get-ChildItem $extractPath -Recurse -File | ForEach-Object {
    $relativePath = $_.FullName.Substring($extractPath.Length + 1)
    $size = if ($_.Length -gt 1MB) { "$([Math]::Round($_.Length / 1MB, 2)) MB" } else { "$([Math]::Round($_.Length / 1KB, 2)) KB" }
    Write-Host "  $relativePath ($size)" -ForegroundColor White
}

# Show flash instructions
Write-Host ""
Write-Host "=== 烧录说明 ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "方法 1: 使用 flash_args (推荐)" -ForegroundColor Green
Write-Host "  cd $extractPath" -ForegroundColor White
Write-Host "  esptool.py --chip esp32s3 --port COM3 write_flash @flash_args" -ForegroundColor White
Write-Host ""
Write-Host "方法 2: 使用合并固件 (最简单)" -ForegroundColor Green
$mergedBin = Get-ChildItem $extractPath -Filter "*.bin" -Recurse | Where-Object { $_.Name -match "merged" }
if ($mergedBin) {
    Write-Host "  esptool.py --chip esp32s3 --port COM3 write_flash 0x0 $($mergedBin.FullName)" -ForegroundColor White
} else {
    Write-Host "  (未找到合并固件，请使用方法 1)" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "完成！固件已下载到: $extractPath" -ForegroundColor Green
