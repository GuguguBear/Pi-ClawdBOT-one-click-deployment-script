#!/bin/bash

# =================================================================
# OpenClaw (Clawdbot) Performance Installer for Raspberry Pi 4
# 适用环境: Ubuntu Server 25 (64-bit)
# 改良点：移除废弃 NPM 参数 + 增强目录净化 + 自动软链接校验
# =================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${GREEN}🚀 启动树莓派 4 (Pi4) 专用 OpenClaw 高性能安装程序 (v2.3)${NC}"

# 1. 内存优化逻辑
setup_mem_optimization() {
    echo -e "${YELLOW}[1/7] 检查物理内存状态...${NC}"
    TOTAL_RAM=$(free -m | grep Mem | awk '{print $2}')
    if [ "$TOTAL_RAM" -lt 1500 ]; then
        echo -e "${CYAN}内存低于 2GB，正在启用 1GB 临时 Swap 保护...${NC}"
        sudo fallocate -l 1G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=1024
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
    else
        echo -e "${GREEN}内存充足 (${TOTAL_RAM}MB)，无需配置 Swap。${NC}"
    fi
}

# 2. 锁处理逻辑
resolve_apt_lock() {
    echo -e "${YELLOW}[2/7] 清理 APT 锁环境...${NC}"
    sudo rm -f /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock*
    sudo dpkg --configure -a
}

# 3. 依赖预装
ensure_deps() {
    echo -e "${YELLOW}[3/7] 正在同步系统依赖...${NC}"
    sudo apt update
    sudo apt install -y curl build-essential python3
}

# 4. 环境净化 (解决 ENOTEMPTY 和权限残留)
cleanup_environment() {
    echo -e "${YELLOW}[4/7] 深度清理冲突配置与目录...${NC}"
    rm -f ~/.npmrc
    # 物理粉碎可能导致重命名失败的残留
    rm -rf "${HOME}/.npm-global/lib/node_modules/openclaw"
    rm -rf "${HOME}/.npm-global/lib/node_modules/.openclaw-*"
}

# 5. 安装 Node.js 22
install_node() {
    echo -e "${YELLOW}[5/7] 部署 Node.js 22 (LTS)...${NC}"
    if ! command -v node &> /dev/null || [ "$(node -v | cut -d. -f1)" != "v22" ]; then
        curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
        sudo apt install -y nodejs
    else
        echo -e "${GREEN}Node.js 22 已存在，跳过安装。${NC}"
    fi
}

# 6. NPM 路径配置 (已修复 jobs 报错)
setup_npm_config() {
    echo -e "${YELLOW}[6/7] 配置 NPM 运行环境...${NC}"
    mkdir -p "${HOME}/.npm-global/bin"
    npm config set prefix "${HOME}/.npm-global"
    
    # 【修复】移除了导致报错的 npm config set jobs 命令
    # 新版 NPM 默认会自动利用多核性能
    
    if ! grep -q ".npm-global/bin" ~/.bashrc; then
        echo 'export PATH="${HOME}/.npm-global/bin:$PATH"' >> ~/.bashrc
    fi
    export PATH="${HOME}/.npm-global/bin:$PATH"
}

# 7. 部署 OpenClaw + 自动补丁
install_openclaw() {
    echo -e "${YELLOW}[7/7] 部署 OpenClaw 程序...${NC}"
    # 强制清理安装目标，确保路径绝对干净
    rm -rf "${HOME}/.npm-global/lib/node_modules/openclaw"
    
    npm install -g openclaw@latest --no-fund --prefix "${HOME}/.npm-global"

    echo -e "${CYAN}验证二进制链接...${NC}"
    BIN_TARGET="${HOME}/.npm-global/bin/openclaw"
    CLI_SRC="${HOME}/.npm-global/lib/node_modules/openclaw/dist/cli.js"

    if [ ! -f "$BIN_TARGET" ]; then
        echo -e "${YELLOW}执行命令补丁...${NC}"
        ln -sf "$CLI_SRC" "$BIN_TARGET"
        chmod +x "$BIN_TARGET"
    fi

    if command -v openclaw &> /dev/null || [ -f "$BIN_TARGET" ]; then
        echo -e "${GREEN}OpenClaw 安装完成！${NC}"
    else
        echo -e "${RED}部署失败，请检查错误日志。${NC}"
        exit 1
    fi
}

# --- 执行流程 ---
setup_mem_optimization
resolve_apt_lock
ensure_deps
cleanup_environment
install_node
setup_npm_config
install_openclaw

echo -e "\n${GREEN}==================================================${NC}"
echo -e "${GREEN}🎉 Pi 4 环境部署圆满成功！${NC}"
echo -e "${YELLOW}下一步操作：${NC}"
echo -e "1. 执行: ${CYAN}source ~/.bashrc${NC}"
echo -e "2. 执行: ${CYAN}openclaw onboard${NC}"
echo -e "${GREEN}==================================================${NC}"
