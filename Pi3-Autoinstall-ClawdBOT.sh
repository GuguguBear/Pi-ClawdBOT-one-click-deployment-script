#!/bin/bash

# =================================================================
# OpenClaw (Clawdbot) Ultimate Installer for Raspberry Pi 3 (Ubuntu)
# 改良点：解决内存溢出(OOM) + 补全 Skill 依赖 (pnpm/Go) + 环境深度净化
# Author: Gemini Adaptive Version (v2.6)
# =================================================================

set -e 

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${GREEN}🚀 启动树莓派 3 (Pi3) 强化安装程序 v2.6 (含 Skill 依赖补全)${NC}"

# 1. 内存保护：针对 Pi3 强制 2GB Swap (生存基础)
setup_swap() {
    echo -e "${YELLOW}[1/8] 检查系统虚拟内存...${NC}"
    if [ $(free -m | grep Swap | awk '{print $2}') -lt 1500 ]; then
        echo -e "${CYAN}检测到 Pi3 内存受限，部署 2GB Swap 缓冲区...${NC}"
        sudo swapoff -a 2>/dev/null || true
        sudo rm -f /swapfile
        sudo fallocate -l 2G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
    fi
}

# 2. 破锁逻辑
resolve_apt_lock() {
    echo -e "${YELLOW}[2/8] 解除系统后台更新锁...${NC}"
    sudo systemctl stop unattended-upgrades 2>/dev/null || true
    sudo rm -f /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock*
    sudo dpkg --configure -a
}

# 3. 依赖补全 (新增 Go 语言支持)
ensure_deps() {
    echo -e "${YELLOW}[3/8] 同步系统依赖并安装 Go (用于 Skill 编译)...${NC}"
    sudo apt-get update
    # 加入 golang-go，解决 Pi3 编译 Skill 的需求
    sudo apt-get install -y curl build-essential python3 golang-go git
}

# 4. 环境净化
remove_old_node() {
    echo -e "${YELLOW}[4/8] 深度清理冲突残留...${NC}"
    rm -f ~/.npmrc
    rm -rf "${HOME}/.npm-global/lib/node_modules/openclaw"
    rm -rf "${HOME}/.npm-global/lib/node_modules/.openclaw-*"
}

# 5. 安装 Node.js 22 并解锁内存限制
install_node() {
    echo -e "${YELLOW}[5/8] 部署 Node.js 22 (LTS)...${NC}"
    if ! command -v node &> /dev/null || [ "$(node -v | cut -d. -f1)" != "v22" ]; then
        curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi

    # 注入内存解锁参数，这是 Pi3 运行 onboard 和 pnpm 的关键
    if ! grep -q "NODE_OPTIONS" ~/.bashrc; then
        echo 'export NODE_OPTIONS="--max-old-space-size=2048"' >> ~/.bashrc
    fi
    export NODE_OPTIONS="--max-old-space-size=2048"
}

# 6. NPM 路径优化与 pnpm 安装
setup_npm_global() {
    echo -e "${YELLOW}[6/8] 配置 NPM 与 pnpm 运行环境...${NC}"
    mkdir -p "${HOME}/.npm-global/bin"
    npm config set prefix "${HOME}/.npm-global"
    
    if ! grep -q ".npm-global/bin" ~/.bashrc; then
        echo 'export PATH="${HOME}/.npm-global/bin:$PATH"' >> ~/.bashrc
    fi
    export PATH="${HOME}/.npm-global/bin:$PATH"

    # 安装 pnpm (Skill 管理必备)
    if ! command -v pnpm &> /dev/null; then
        echo -e "${CYAN}正在为 Pi3 安装 pnpm...${NC}"
        npm install -g pnpm --no-fund
    fi
}

# 7. 部署 OpenClaw + 自动补丁
install_openclaw() {
    echo -e "${YELLOW}[7/8] 部署 OpenClaw 程序...${NC}"
    npm install -g openclaw@latest --no-fund --prefix "${HOME}/.npm-global"

    BIN_TARGET="${HOME}/.npm-global/bin/openclaw"
    CLI_SRC="${HOME}/.npm-global/lib/node_modules/openclaw/dist/cli.js"
    if [ ! -f "$BIN_TARGET" ]; then
        ln -sf "$CLI_SRC" "$BIN_TARGET"
        chmod +x "$BIN_TARGET"
    fi
}

# 8. Brew 引导提示
brew_guide() {
    if ! command -v brew &> /dev/null; then
        echo -e "\n${YELLOW}[8/8] Homebrew 提示:${NC}"
        echo -e "部分高级 Skill 需要 Brew。由于 Pi3 性能极弱，建议仅在必要时手动安装。"
    fi
}

# --- 执行 ---
setup_swap
resolve_apt_lock
ensure_deps
remove_old_node
install_node
setup_npm_global
install_openclaw
brew_guide

echo -e "\n${GREEN}==================================================${NC}"
echo -e "${GREEN}✨ Pi 3 全功能环境部署完成！${NC}"
echo -e "1. 执行: ${CYAN}source ~/.bashrc${NC}"
echo -e "2. 执行: ${CYAN}openclaw onboard${NC}"
echo -e "${GREEN}==================================================${NC}"
