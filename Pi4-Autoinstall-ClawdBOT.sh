#!/bin/bash

# =================================================================
# OpenClaw (Clawdbot) Ultimate Installer for Raspberry Pi 4
# 适用环境: Ubuntu Server 25 (64-bit)
# 改良点：自动补全 Skill 依赖 (pnpm/Go) + 强化破锁 + 零配置冲突
# Author: Gemini Adaptive Version (v2.5)
# =================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${GREEN}🚀 启动树莓派 4 (Pi4) 专用 OpenClaw 高性能安装程序 (v2.5)${NC}"

# 1. 内存优化
setup_mem_optimization() {
    echo -e "${YELLOW}[1/8] 检查物理内存状态...${NC}"
    TOTAL_RAM=$(free -m | grep Mem | awk '{print $2}')
    if [ "$TOTAL_RAM" -lt 1500 ]; then
        echo -e "${CYAN}内存低于 2GB，启用 1GB 临时 Swap...${NC}"
        sudo swapoff -a 2>/dev/null || true
        sudo fallocate -l 1G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=1024
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
    else
        echo -e "${GREEN}内存充足 (${TOTAL_RAM}MB)，无需配置 Swap。${NC}"
    fi
}

# 2. 破锁逻辑
resolve_apt_lock() {
    echo -e "${YELLOW}[2/8] 正在解除系统后台更新锁...${NC}"
    sudo systemctl stop unattended-upgrades 2>/dev/null || true
    sudo rm -f /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock*
    sudo dpkg --configure -a
}

# 3. 依赖补全 (针对 Skill 失败进行的改良)
ensure_deps() {
    echo -e "${YELLOW}[3/8] 正在同步系统依赖并补全 Skill 核心环境...${NC}"
    sudo apt-get update
    # 增加 golang-go 的安装，解决 Skill 编译需求
    sudo apt-get install -y curl build-essential python3 golang-go git
    echo -e "${GREEN}Go 语言环境及系统依赖已就绪。${NC}"
}

# 4. 环境净化
cleanup_environment() {
    echo -e "${YELLOW}[4/8] 深度清理冲突配置与残留...${NC}"
    rm -f ~/.npmrc
    rm -rf "${HOME}/.npm-global/lib/node_modules/openclaw"
}

# 5. 安装 Node.js 22
install_node() {
    echo -e "${YELLOW}[5/8] 部署 Node.js 22 (LTS)...${NC}"
    if ! command -v node &> /dev/null || [ "$(node -v | cut -d. -f1)" != "v22" ]; then
        curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi
}

# 6. NPM & pnpm 配置 (解决 spawn pnpm ENOENT 报错)
setup_npm_config() {
    echo -e "${YELLOW}[6/8] 配置 NPM 与 pnpm 运行环境...${NC}"
    mkdir -p "${HOME}/.npm-global/bin"
    npm config set prefix "${HOME}/.npm-global"
    
    # 写入环境变量
    if ! grep -q ".npm-global/bin" ~/.bashrc; then
        echo 'export PATH="${HOME}/.npm-global/bin:$PATH"' >> ~/.bashrc
    fi
    export PATH="${HOME}/.npm-global/bin:$PATH"

    # 安装 pnpm 以支持 OpenClaw Skill 管理
    if ! command -v pnpm &> /dev/null; then
        echo -e "${CYAN}正在安装 pnpm...${NC}"
        npm install -g pnpm --no-fund
    fi
}

# 7. 部署 OpenClaw + 自动补丁
install_openclaw() {
    echo -e "${YELLOW}[7/8] 正在部署 OpenClaw...${NC}"
    npm install -g openclaw@latest --no-fund --prefix "${HOME}/.npm-global"

    BIN_TARGET="${HOME}/.npm-global/bin/openclaw"
    CLI_SRC="${HOME}/.npm-global/lib/node_modules/openclaw/dist/cli.js"
    if [ ! -f "$BIN_TARGET" ]; then
        ln -sf "$CLI_SRC" "$BIN_TARGET"
        chmod +x "$BIN_TARGET"
    fi
}

# 8. Homebrew 引导 (Skill 核心)
brew_guide() {
    echo -e "${YELLOW}[8/8] 检查 Homebrew 状态...${NC}"
    if ! command -v brew &> /dev/null; then
        echo -e "${RED}提示: 许多高级 Skill 需要 Homebrew。${NC}"
        echo -e "${CYAN}安装完成后，建议手动运行此命令安装 Brew:${NC}"
        echo -e "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    fi
}

# --- 执行 ---
setup_mem_optimization
resolve_apt_lock
ensure_deps
cleanup_environment
install_node
setup_npm_config
install_openclaw
brew_guide

echo -e "\n${GREEN}==================================================${NC}"
echo -e "${GREEN}✨ Pi 4 安装及 Skill 环境补全已完成！${NC}"
echo -e "请执行: ${CYAN}source ~/.bashrc${NC}"
echo -e "然后再次尝试: ${CYAN}openclaw onboard${NC}"
echo -e "${GREEN}==================================================${NC}"
