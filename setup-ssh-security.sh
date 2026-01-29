#!/bin/bash

# SSH安全配置脚本
# 功能：修改SSH端口为34567，安装配置fail2ban
# 支持：Ubuntu、Debian、CentOS

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 新SSH端口
NEW_SSH_PORT=34567

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误：此脚本需要root权限运行${NC}"
        echo "请使用 sudo $0 运行"
        exit 1
    fi
}

# 检测操作系统类型
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS="centos"
    elif [ -f /etc/debian_version ]; then
        OS="debian"
    else
        echo -e "${RED}无法检测操作系统类型${NC}"
        exit 1
    fi

    echo -e "${GREEN}检测到操作系统: $OS${NC}"
}

# 备份SSH配置
backup_ssh_config() {
    local backup_file="/etc/ssh/sshd_config.backup.$(date +%Y%m%d%H%M%S)"
    cp /etc/ssh/sshd_config "$backup_file"
    echo -e "${GREEN}SSH配置已备份到: $backup_file${NC}"
}

# 修改SSH端口
change_ssh_port() {
    echo -e "${YELLOW}正在修改SSH端口为 $NEW_SSH_PORT ...${NC}"

    # 备份配置
    backup_ssh_config

    # 修改端口配置
    if grep -q "^Port " /etc/ssh/sshd_config; then
        sed -i "s/^Port .*/Port $NEW_SSH_PORT/" /etc/ssh/sshd_config
    elif grep -q "^#Port " /etc/ssh/sshd_config; then
        sed -i "s/^#Port .*/Port $NEW_SSH_PORT/" /etc/ssh/sshd_config
    else
        echo "Port $NEW_SSH_PORT" >> /etc/ssh/sshd_config
    fi

    echo -e "${GREEN}SSH端口已修改为 $NEW_SSH_PORT${NC}"
}

# 配置防火墙（针对不同系统）
configure_firewall() {
    echo -e "${YELLOW}正在配置防火墙...${NC}"

    case $OS in
        ubuntu|debian)
            # 检查ufw是否存在
            if command -v ufw &> /dev/null; then
                ufw allow $NEW_SSH_PORT/tcp
                echo -e "${GREEN}UFW已允许端口 $NEW_SSH_PORT${NC}"
            fi
            ;;
        centos|rhel|fedora|rocky|almalinux)
            # 检查firewalld
            if systemctl is-active --quiet firewalld 2>/dev/null; then
                firewall-cmd --permanent --add-port=$NEW_SSH_PORT/tcp
                firewall-cmd --reload
                echo -e "${GREEN}Firewalld已允许端口 $NEW_SSH_PORT${NC}"
            fi
            ;;
    esac

    # 配置SELinux（如果存在）
    if command -v semanage &> /dev/null; then
        semanage port -a -t ssh_port_t -p tcp $NEW_SSH_PORT 2>/dev/null || \
        semanage port -m -t ssh_port_t -p tcp $NEW_SSH_PORT 2>/dev/null || true
        echo -e "${GREEN}SELinux已配置允许SSH使用端口 $NEW_SSH_PORT${NC}"
    fi
}

# 重启SSH服务
restart_ssh() {
    echo -e "${YELLOW}正在重启SSH服务...${NC}"

    case $OS in
        ubuntu|debian)
            systemctl restart sshd || systemctl restart ssh
            ;;
        centos|rhel|fedora|rocky|almalinux)
            systemctl restart sshd
            ;;
    esac

    echo -e "${GREEN}SSH服务已重启${NC}"
}

# 安装fail2ban
install_fail2ban() {
    echo -e "${YELLOW}正在安装fail2ban...${NC}"

    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get install -y fail2ban iptables
            ;;
        centos|rhel|fedora|rocky|almalinux)
            # CentOS 8+ 使用dnf
            if command -v dnf &> /dev/null; then
                dnf install -y epel-release
                dnf install -y fail2ban iptables
            else
                yum install -y epel-release
                yum install -y fail2ban iptables
            fi
            ;;
    esac

    echo -e "${GREEN}fail2ban安装完成${NC}"
}

# 配置fail2ban
configure_fail2ban() {
    echo -e "${YELLOW}正在配置fail2ban...${NC}"

    # 创建jail.local配置文件
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
# 封禁时间：1小时
bantime = 3600

# 检测时间窗口：10分钟
findtime = 600

# 最大尝试次数：5次
maxretry = 5

# 使用iptables进行封禁
banaction = iptables-multiport
banaction_allports = iptables-allports

# 忽略本地地址
ignoreip = 127.0.0.1/8 ::1

# 后端使用auto自动检测
backend = auto

# 启用邮件通知（可选，默认关闭）
# destemail = admin@example.com
# sender = fail2ban@example.com
# mta = sendmail

[sshd]
enabled = true
port = $NEW_SSH_PORT
filter = sshd
logpath = %(sshd_log)s
maxretry = 5
findtime = 600
bantime = 3600
banaction = iptables-multiport
EOF

    # 创建自定义action配置确保使用iptables
    cat > /etc/fail2ban/action.d/iptables-common.local << EOF
[Init]
# 使用iptables而非nftables
# 适用于旧版系统和需要iptables的环境
EOF

    echo -e "${GREEN}fail2ban配置完成${NC}"
}

# 启动fail2ban服务
start_fail2ban() {
    echo -e "${YELLOW}正在启动fail2ban服务...${NC}"

    systemctl enable fail2ban
    systemctl restart fail2ban

    # 等待服务启动
    sleep 2

    # 检查服务状态
    if systemctl is-active --quiet fail2ban; then
        echo -e "${GREEN}fail2ban服务已启动${NC}"
    else
        echo -e "${RED}fail2ban服务启动失败，请检查日志${NC}"
        journalctl -u fail2ban -n 20 --no-pager
        exit 1
    fi
}

# 显示状态信息
show_status() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}         配置完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "SSH新端口: ${YELLOW}$NEW_SSH_PORT${NC}"
    echo -e "请使用以下命令连接: ${YELLOW}ssh -p $NEW_SSH_PORT user@server${NC}"
    echo ""
    echo -e "${YELLOW}fail2ban状态:${NC}"
    fail2ban-client status
    echo ""
    echo -e "${YELLOW}SSH jail状态:${NC}"
    fail2ban-client status sshd 2>/dev/null || echo "SSH jail正在初始化..."
    echo ""
    echo -e "${RED}重要提示:${NC}"
    echo -e "1. 请确保在关闭当前SSH连接前，先测试新端口是否可以正常连接"
    echo -e "2. 如需恢复，SSH配置备份在 /etc/ssh/sshd_config.backup.*"
    echo -e "3. 查看封禁IP: fail2ban-client status sshd"
    echo -e "4. 解封IP: fail2ban-client set sshd unbanip <IP地址>"
    echo ""
}

# 主函数
main() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   SSH安全配置脚本${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""

    check_root
    detect_os
    change_ssh_port
    configure_firewall
    restart_ssh
    install_fail2ban
    configure_fail2ban
    start_fail2ban
    show_status
}

# 运行主函数
main "$@"
