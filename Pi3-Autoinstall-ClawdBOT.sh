#!/bin/bash

# OpenClaw (Clawdbot) Ultimate Installer for Raspberry Pi 3 (Ubuntu)
# 升级点：强制路径修复 + 内存压力监测 + 增强型锁清理 + 零配置冲突
# Author: Gemini Adaptive Version (v2.1)

set -e 

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${GREEN}🦞 OpenClaw Installer for Raspberry Pi 3 (Enhanced v2.1)${NC}"

# 1. 内存保护：智能扩容 Swap (Pi 3 1GB 内存生命线)
setup_swap() {
    echo -e "${YELLOW}[1/7] 检查系统虚拟内存...${NC}"
    # 如果 Swap 小于 1.5GB 则扩容到 2GB
    if [ $(free -m | grep Swap | awk '{print $2}') -lt 1500 ]; then
        echo -e "${CYAN}检测到物理内存较低，正在创建 2GB 临时 Swap 保护进程...${NC}"
        sudo swapoff /swapfile 2>/dev/null || true
        sudo rm -f /swapfile
        sudo fallocate -l 2G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        echo -e "${GREEN}Swap 扩容完成。${NC}"
    fi
}

# 2. 增强型锁处理：智能等待与物理强删结合
resolve_apt_lock() {
    echo -e "${YELLOW}[2/7] 正在检测并解除 APT 资源锁定...${NC}"
    LOCK_FILES=("/var/lib/apt/lists/lock" "/var/cache/apt/archives/lock" "/var/lib/dpkg/lock-frontend" "/var/lib/dpkg/lock")
    
    # 智能等待现有的 apt 进程
    for i in {1..20}; do
        APT_PID=$(ps aux | grep -E '[a]pt-get|[a]pt |[d]pkg' | grep -v grep | awk '{print $2}' | head -n1) || true
        if [ -z "$APT_PID" ]; then break; fi
        echo -e "${CYAN}等待现有 APT 进程 (PID: $APT_PID) 结束... ($i/20)${NC}"
        sleep 5
    done

    # 物理移除残留锁文件
    for lock in "${LOCK_FILES[@]}"; do
        if [ -e "$lock" ]; then sudo rm -f "$lock"; fi
    done
    sudo dpkg --configure -a
    echo -e "${GREEN}APT 锁环境已就绪。${NC}"
}

# 3. 基础工具确保
ensure_curl() {
    echo -e "${YELLOW}[3/7] 检查网络下载工具...${NC}"
    if ! command -v curl &> /dev/null; then
        sudo apt update && sudo apt install -y curl
    fi
}

# 4. 彻底环境净化 (解决 prefix 冲突的关键)
remove_old_node() {
    echo -e "${YELLOW}[4/7] 净化旧版 Node 环境与冲突配置...${NC}"
    # 强制物理删除导致 npm 报错的旧配置
    rm -f ~/.npmrc
    if command -v node &> /dev/null || command -v npm &> /dev/null; then
        sudo apt remove --purge nodejs npm -y && sudo apt autoremove -y
        sudo rm -rf /usr/bin/node /usr/bin/nodejs /usr/bin/npm /etc/apt/sources.list.d/nodesource.list
    fi
}

# 5. 标准化安装 Node.js 22
install_node() {
    echo -e "${YELLOW}[5/7] 安装 Node.js 22 (LTS)...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt install -y nodejs
    echo -e "${GREEN}Node.js $(node -v) 部署成功。${NC}"
}

# 6. NPM 路径优化 (解决 PATH 找不到命令的问题)
setup_npm_global() {
    echo -e "${YELLOW}[6/7] 配置 NPM 全局二进制目录...${NC}"
    mkdir -p "${HOME}/.npm-global"
    npm config set prefix "${HOME}/.npm-global"
    
    # 永久写入 PATH 到配置文件
    if ! grep -q ".npm-global/bin" ~/.bashrc; then
        echo 'export PATH="${HOME}/.npm-global/bin:$PATH"' >> ~/.bashrc
    fi
    # 立即生效当前进程
    export PATH="${HOME}/.npm-global/bin:$PATH"
}

# 7. 部署 OpenClaw + 强制二进制补丁
install_openclaw() {
    echo -e "${YELLOW}[7/7] 部署 OpenClaw 并修复软链接...${NC}"
    # 使用 --prefix 强制安装到指定目录，防止进 lib
    npm install -g openclaw@latest --no-fund --prefix "${HOME}/.npm-global"

    # 【核心升级：强制修复逻辑】
    echo -e "${CYAN}检测命令二进制文件状态...${NC}"
    BIN_TARGET="${HOME}/.npm-global/bin/openclaw"
    CLI_SRC="${HOME}/.npm-global/lib/node_modules/openclaw/dist/cli.js"

    if [ ! -f "$BIN_TARGET" ]; then
        echo -e "${RED}警告：二进制文件未自动生成，正在执行强制手动链接...${NC}"
        mkdir -p "${HOME}/.npm-global/bin"
        ln -sf "$CLI_SRC" "$BIN_TARGET"
        chmod +x "$BIN_TARGET"
    fi

    if command -v openclaw &> /dev/null || [ -f "$BIN_TARGET" ]; then
        echo -e "${GREEN}OpenClaw 安装与二进制补丁应用成功！${NC}"
    else
        echo -e "${RED}错误：OpenClaw 部署失败，请检查 NPM 日志。${NC}"
        exit 1
    fi
}

# --- 执行引擎 ---
setup_swap
resolve_apt_lock
ensure_curl
remove_old_node
install_node
setup_npm_global
install_openclaw

echo -e "\n${GREEN}==================================================${NC}"
echo -e "${GREEN}✨ 安装圆满完成！${NC}"
echo -e "${YELLOW}下一步必做操作：${NC}"
echo -e "1. 输入 ${CYAN}source ~/.bashrc${NC} 激活命令"
echo -e "2. 输入 ${CYAN}openclaw onboard${NC} 开始配置"
echo -e "3. 为了系统稳定，建议稍后执行 ${CYAN}sudo reboot${NC}"
echo -e "${GREEN}==================================================${NC}"
