#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Dub Demo — Self-hosted GitHub Actions Runner 安装脚本
# 
# 用途: 在你的机器（本地 Mac 或阿里云 ECS）上部署 Runner
#       QoderCLI 的 API Key 仅存在于本地环境变量中
#
# 安全架构:
#   ┌──────────────────┐    ┌──────────────────────────────────┐
#   │  GitHub 云端      │    │  你的机器 (Self-hosted Runner)    │
#   │                  │    │                                  │
#   │  质量检查 (lint)  │    │  QoderCLI Review / Fix / Release │
#   │  Docker 构建      │    │  QODER_API_KEY=xxx (本地)        │
#   │  (无敏感信息)     │    │  (API Key 永远不离开本机)         │
#   └──────────────────┘    └──────────────────────────────────┘
#
# 使用方法:
#   chmod +x scripts/setup-runner.sh
#   ./scripts/setup-runner.sh
# ═══════════════════════════════════════════════════════════════

set -e

# ── 颜色输出 ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo ""
echo "═══════════════════════════════════════════════════"
echo "  Dub Demo — Self-hosted Runner 安装向导"
echo "  QoderCLI API Key 本地安全存储方案"
echo "═══════════════════════════════════════════════════"
echo ""

# ── Step 1: 检查前置条件 ──
info "Step 1/6: 检查前置条件..."

# Node.js
if command -v node &> /dev/null; then
  NODE_VER=$(node --version)
  ok "Node.js $NODE_VER"
else
  error "Node.js 未安装"
  echo "  请安装: https://nodejs.org/ 或 brew install node"
  exit 1
fi

# pnpm
if command -v pnpm &> /dev/null; then
  ok "pnpm $(pnpm --version)"
else
  warn "pnpm 未安装，正在安装..."
  npm install -g pnpm@9
fi

# git
if command -v git &> /dev/null; then
  ok "git $(git --version | awk '{print $3}')"
else
  error "git 未安装"
  exit 1
fi

# gh CLI
if command -v gh &> /dev/null; then
  ok "gh $(gh --version | head -1 | awk '{print $3}')"
else
  warn "gh CLI 未安装 (建议安装: brew install gh)"
fi

# Docker (可选)
if command -v docker &> /dev/null; then
  ok "Docker $(docker --version | awk '{print $3}' | tr -d ',')"
else
  warn "Docker 未安装 (部署步骤需要)"
fi

echo ""

# ── Step 2: 安装 QoderCLI ──
info "Step 2/6: 安装 QoderCLI..."

if command -v qoder &> /dev/null; then
  ok "QoderCLI 已安装: $(qoder --version 2>/dev/null || echo 'version unknown')"
else
  info "正在安装 QoderCLI..."
  # 中国版 Qoder CLI 安装
  # 方式 1: npm 安装
  npm install -g @anthropic-ai/qoder-cli 2>/dev/null || {
    # 方式 2: curl 安装
    warn "npm 安装失败，尝试 curl 安装..."
    curl -fsSL https://qoder.com/cli/install | sh 2>/dev/null || {
      error "QoderCLI 安装失败，请手动安装"
      echo "  访问: https://qoder.com/cli"
      exit 1
    }
  }
  ok "QoderCLI 安装完成"
fi

echo ""

# ── Step 3: 配置 QODER_API_KEY ──
info "Step 3/6: 配置 QODER_API_KEY (本地环境变量)..."

if [ -n "$QODER_API_KEY" ]; then
  ok "QODER_API_KEY 已配置 (长度: ${#QODER_API_KEY} 字符)"
else
  warn "QODER_API_KEY 未设置"
  echo ""
  echo "  请输入你的 Qoder API Key (输入不会显示在屏幕上):"
  read -s -p "  QODER_API_KEY: " API_KEY
  echo ""
  
  if [ -z "$API_KEY" ]; then
    error "API Key 不能为空"
    exit 1
  fi
  
  # 写入 shell 配置
  SHELL_RC="$HOME/.bashrc"
  if [ -n "$ZSH_VERSION" ] || [ "$SHELL" = "/bin/zsh" ]; then
    SHELL_RC="$HOME/.zshrc"
  fi
  
  echo "" >> "$SHELL_RC"
  echo "# Qoder API Key (Self-hosted Runner 使用)" >> "$SHELL_RC"
  echo "export QODER_API_KEY=\"$API_KEY\"" >> "$SHELL_RC"
  
  export QODER_API_KEY="$API_KEY"
  
  ok "QODER_API_KEY 已写入 $SHELL_RC"
  info "注意: 此 Key 仅存在于本机，不会上传到 GitHub"
fi

echo ""

# ── Step 4: 安装 GitHub Actions Runner ──
info "Step 4/6: 安装 GitHub Actions Runner..."

RUNNER_DIR="$HOME/actions-runner"
REPO="rickmodel/dub-demo"

if [ -d "$RUNNER_DIR" ] && [ -f "$RUNNER_DIR/run.sh" ]; then
  ok "Runner 已安装在 $RUNNER_DIR"
else
  mkdir -p "$RUNNER_DIR"
  cd "$RUNNER_DIR"
  
  # 检测系统架构
  ARCH=$(uname -m)
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  
  if [ "$OS" = "darwin" ]; then
    if [ "$ARCH" = "arm64" ]; then
      RUNNER_PKG="actions-runner-osx-arm64-2.323.0.tar.gz"
    else
      RUNNER_PKG="actions-runner-osx-x64-2.323.0.tar.gz"
    fi
  elif [ "$OS" = "linux" ]; then
    if [ "$ARCH" = "x86_64" ]; then
      RUNNER_PKG="actions-runner-linux-x64-2.323.0.tar.gz"
    else
      RUNNER_PKG="actions-runner-linux-arm64-2.323.0.tar.gz"
    fi
  fi
  
  info "下载 Runner: $RUNNER_PKG"
  curl -o runner.tar.gz -L "https://github.com/actions/runner/releases/download/v2.323.0/$RUNNER_PKG"
  tar xzf runner.tar.gz
  rm -f runner.tar.gz
  
  ok "Runner 下载解压完成"
fi

echo ""

# ── Step 5: 获取 Registration Token 并配置 Runner ──
info "Step 5/6: 配置 Runner 注册..."

# 检查是否已配置
if [ -f "$RUNNER_DIR/.runner" ]; then
  ok "Runner 已注册"
else
  info "获取 Runner Registration Token..."
  
  REG_TOKEN=$(gh api repos/$REPO/actions/runners/registration-token -X POST --jq '.token' 2>/dev/null)
  
  if [ -z "$REG_TOKEN" ]; then
    error "无法获取 Registration Token"
    echo "  请确保 gh CLI 已登录且有 repo 权限"
    echo "  手动获取: Settings → Actions → Runners → New self-hosted runner"
    exit 1
  fi
  
  cd "$RUNNER_DIR"
  
  # 配置 Runner
  # --labels 标签对应 workflow 中的 runs-on: [self-hosted, qoder]
  ./config.sh \
    --url "https://github.com/$REPO" \
    --token "$REG_TOKEN" \
    --name "qoder-runner-$(hostname)" \
    --labels "self-hosted,qoder" \
    --work "_work" \
    --replace
  
  ok "Runner 注册成功"
fi

echo ""

# ── Step 6: 启动 Runner ──
info "Step 6/6: 启动 Runner..."

echo ""
echo "═══════════════════════════════════════════════════"
echo "  ✅ 安装完成！"
echo "═══════════════════════════════════════════════════"
echo ""
echo "  Runner 目录: $RUNNER_DIR"
echo "  标签:        self-hosted, qoder"
echo "  API Key:     本地环境变量 (不上传云端)"
echo ""
echo "  启动命令 (前台运行):"
echo "    cd $RUNNER_DIR && ./run.sh"
echo ""
echo "  启动命令 (后台服务):"
if [ "$(uname)" = "Darwin" ]; then
  echo "    cd $RUNNER_DIR && ./svc.sh install && ./svc.sh start"
else
  echo "    cd $RUNNER_DIR && sudo ./svc.sh install && sudo ./svc.sh start"
fi
echo ""
echo "  停止服务:"
echo "    cd $RUNNER_DIR && ./svc.sh stop"
echo ""
echo "  验证 Runner 在线:"
echo "    gh api repos/$REPO/actions/runners --jq '.runners[] | .name + \": \" + .status'"
echo ""
echo "═══════════════════════════════════════════════════"
echo ""

# 询问是否立即启动
read -p "  是否现在启动 Runner? (y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
  cd "$RUNNER_DIR"
  info "启动 Runner (按 Ctrl+C 停止)..."
  ./run.sh
fi
