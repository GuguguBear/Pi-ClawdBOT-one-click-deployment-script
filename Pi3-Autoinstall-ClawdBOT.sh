#!/bin/bash

# =================================================================
# OpenClaw (Clawdbot) Ultimate Installer for Raspberry Pi 3 (Ubuntu)
# 改良点：解决内存溢出(OOM) + 强制接管后台锁 + 环境深度净化
# Author: Gemini Adaptive Version (v2.5)
# =================================================================

set -e 

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${GREEN}🚀 启动树莓派 3 (Pi3) 专用 OpenClaw 强化安装程序 (v2.5)${NC}"

# 1. 内存保护：针对 Pi3 强制 2GB Swap
setup_swap() {
    echo -e "${YELLOW}[1/7] 检查系统虚拟内存 (针对 Pi3 优化)...${NC}"
    # 无论当前有多少 Swap，针对 Pi3 建议重新创建 2G 纯净 Swap
    if [ $(free -m | grep Swap | awk '{print $2}') -lt 1500 ]; then
        echo -e "${CYAN}检测到 Pi3 物理内存受限，正在部署 2GB Swap 缓冲区...${NC}"
        sudo swapoff -a 2>/dev/null || true
        sudo rm -f /swapfile
        sudo fallocate -l 2G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        echo -e "${GREEN}Swap 缓冲区部署完成。${NC}"
    else
        echo -e "${GREEN}当前 Swap 充足，继续下一步。${NC}"
    fi
}

# 2. 增强型破锁处理 (针对 Ubuntu 后台更新)
resolve_apt_lock() {
    echo -e "${YELLOW}[2/7] 解除系统后台更新锁...${NC}"
    sudo systemctl stop unattended-upgrades 2>/dev/null || true
    sudo rm -f /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock*
    sudo dpkg --configure -a
    echo -e "${GREEN}APT 控制权已回收。${NC}"
}

# 3. 基础工具确保
ensure_deps() {
    echo -e "${YELLOW}[3/7] 同步核心编译组件...${NC}"
    sudo apt-get update
    sudo apt-get install -y curl build-essential python3
}

# 4. 彻底环境净化
remove_old_node() {
    echo -e "${YELLOW}[4/7] 深度清理冲突残留...${NC}"
    rm -f ~/.npmrc
    rm -rf "${HOME}/.npm-global/lib/node_modules/openclaw"
    rm -rf "${HOME}/.npm-global/lib/node_modules/.openclaw-*"
}

# 5. 安装 Node.js 22 并解锁内存限制
install_node() {
    echo -e "${YELLOW}[5/7] 部署 Node.js 22 (LTS) 并配置内存优化...${NC}"
    if ! command -v node &> /dev/null || [ "$(node -v | cut -d. -f1)" != "v22" ]; then
        curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi

    # 【关键改进】注入 NODE_OPTIONS，防止 Pi3 运行 onboard 时 OOM 崩溃
    if ! grep -q "NODE_OPTIONS" ~/.bashrc; then
        echo -e "${CYAN}正在注入 Node.js 内存解锁参数 (2GB)...${NC}"
        echo 'export NODE_OPTIONS="--max-old-space-size=2048"' >> ~/.bashrc
    fi
    export NODE_OPTIONS="--max-old-space-size=2048"
    echo -e "${GREEN}Node.js 内存上限已提升至 2048MB。${NC}"
}

# 6. NPM 路径优化
setup_npm_global() {
    echo -e "${YELLOW}[6/7] 配置用户级 NPM 目录...${NC}"
    mkdir -p "${HOME}/.npm-global/bin"
    npm config set prefix "${HOME}/.npm-global"
    
    if ! grep -q ".npm-global/bin" ~/.bashrc; then
        echo 'export PATH="${HOME}/.npm-global/bin:$PATH"' >> ~/.bashrc
    fi
    export PATH="${HOME}/.npm-global/bin:$PATH"
}

# 7. 部署 OpenClaw + 自动补丁
install_openclaw() {
    echo -e "${YELLOW}[7/7] 部署 OpenClaw 程序...${NC}"
    rm -rf "${HOME}/.npm-global/lib/node_modules/openclaw"
    
    # 使用增强内存模式运行安装
    npm install -g openclaw@latest --no-fund --prefix "${HOME}/.npm-global"

    echo -e "${CYAN}执行最终路径校验...${NC}"
    BIN_TARGET="${HOME}/.npm-global/bin/openclaw"
    CLI_SRC="${HOME}/.npm-global/lib/node_modules/openclaw/dist/cli.js"

    if [ ! -f "$BIN_TARGET" ]; then
        ln -sf "$CLI_SRC" "$BIN_TARGET"
        chmod +x "$BIN_TARGET"
    fi

    if command -v openclaw &> /dev/null || [ -f "$BIN_TARGET" ]; then
        echo -e "${GREEN}OpenClaw 部署圆满成功！${NC}"
    else
        echo -e "${RED}部署失败，请检查错误日志。${NC}"
        exit 1
    fi
}

# --- 执行引擎 ---
setup_swap
resolve_apt_lock
ensure_deps
remove_old_node
install_node
setup_npm_global
install_openclaw

echo -e "\n${GREEN}==================================================${NC}"
echo -e "${GREEN}✨ Pi 3 安装与内存优化已完成！${NC}"
echo -e "${YELLOW}下一步操作：${NC}"
echo -e "1. 输入 ${CYAN}source ~/.bashrc${NC} (必须执行，激活内存补丁)"
echo -e "2. 输入 ${CYAN}openclaw onboard${NC} (此时不会再报错内存不足)"
echo -e "${GREEN}==================================================${NC}"
