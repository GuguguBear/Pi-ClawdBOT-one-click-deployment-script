#!/bin/bash

# =================================================================
# OpenClaw (Clawdbot) Performance Installer for Raspberry Pi 4
# 适用环境: Ubuntu Server 25 (64-bit)
# 优化点：多核并行安装优化 + 智能内存管理 + 零配置冲突 + 自动化二进制修复
# =================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${GREEN}🚀 启动树莓派 4 (Pi4) 专用 OpenClaw 高性能安装程序 (Ubuntu 25)...${NC}"

# 1. 智能内存优化 (Pi 4 内存通常充足，仅按需开启 Swap)
setup_mem_optimization() {
    echo -e "${YELLOW}[1/7] 正在优化内存管理...${NC}"
    TOTAL_RAM=$(free -m | grep Mem | awk '{print $2}')
    if [ "$TOTAL_RAM" -lt 1500 ]; then
        echo -e "${CYAN}检测到物理内存低于 2GB，正在创建 1GB 临时交换空间...${NC}"
        sudo fallocate -l 1G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=1024
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
    else
        echo -e "${GREEN}检测到物理内存充足 (${TOTAL_RAM}MB)，跳过 Swap 配置。${NC}"
    fi
}

# 2. 增强型 APT 资源处理
resolve_apt_lock() {
    echo -e "${YELLOW}[2/7] 正在确保 APT 系统可用性...${NC}"
    sudo rm -f /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock*
    sudo dpkg --configure -a
    echo -e "${GREEN}APT 锁环境就绪。${NC}"
}

# 3. 基础依赖预装
ensure_deps() {
    echo -e "${YELLOW}[3/7] 预装系统依赖组件...${NC}"
    sudo apt update
    sudo apt install -y curl build-essential python3
}

# 4. 彻底净化 Node 环境 (预防 ENOTEMPTY 报错)
cleanup_environment() {
    echo -e "${YELLOW}[4/7] 清理潜在的配置冲突与残留...${NC}"
    rm -f ~/.npmrc
    rm -rf "${HOME}/.npm-global/lib/node_modules/openclaw"
    rm -rf "${HOME}/.npm-global/lib/node_modules/.openclaw-*"
    
    if command -v node &> /dev/null; then
        sudo apt remove --purge nodejs npm -y && sudo apt autoremove -y
    fi
}

# 5. 安装 Node.js 22 (针对 Ubuntu 25 优化)
install_node() {
    echo -e "${YELLOW}[5/7] 部署 Node.js 22.x (LTS)...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt install -y nodejs
    echo -e "${GREEN}Node.js $(node -v) 部署成功。${NC}"
}

# 6. 高性能 NPM 全局配置
setup_npm_config() {
    echo -e "${YELLOW}[6/7] 配置高性能 NPM 并行安装参数...${NC}"
    mkdir -p "${HOME}/.npm-global/bin"
    npm config set prefix "${HOME}/.npm-global"
    # 开启多核编译加速
    npm config set jobs $(nproc)
    
    if ! grep -q ".npm-global/bin" ~/.bashrc; then
        echo 'export PATH="${HOME}/.npm-global/bin:$PATH"' >> ~/.bashrc
    fi
    export PATH="${HOME}/.npm-global/bin:$PATH"
}

# 7. 部署 OpenClaw + 二进制自动补丁
install_openclaw() {
    echo -e "${YELLOW}[7/7] 利用多核性能部署 OpenClaw...${NC}"
    # 使用 --foreground 提高安装稳定性
    npm install -g openclaw@latest --no-fund --prefix "${HOME}/.npm-global"

    echo -e "${CYAN}执行最终路径校验与自动补丁...${NC}"
    BIN_TARGET="${HOME}/.npm-global/bin/openclaw"
    CLI_SRC="${HOME}/.npm-global/lib/node_modules/openclaw/dist/cli.js"

    if [ ! -f "$BIN_TARGET" ]; then
        ln -sf "$CLI_SRC" "$BIN_TARGET"
        chmod +x "$BIN_TARGET"
    fi

    if command -v openclaw &> /dev/null || [ -f "$BIN_TARGET" ]; then
        echo -e "${GREEN}OpenClaw 部署圆满成功！${NC}"
    else
        echo -e "${RED}部署失败，请检查网络连接。${NC}"
        exit 1
    fi
}

# --- 启动引擎 ---
setup_mem_optimization
resolve_apt_lock
ensure_deps
cleanup_environment
install_node
setup_npm_config
install_openclaw

echo -e "\n${GREEN}==================================================${NC}"
echo -e "${GREEN}✨ Pi 4 安装完成！ (Ubuntu 25)${NC}"
echo -e "${YELLOW}下一步操作：${NC}"
echo -e "1. 输入: ${CYAN}source ~/.bashrc${NC}"
echo -e "2. 输入: ${CYAN}openclaw onboard${NC}"
echo -e "3. 由于内核版本较高，建议执行: ${CYAN}sudo reboot${NC}"
echo -e "${GREEN}==================================================${NC}"