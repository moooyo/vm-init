# VM-Init

Linux 服务器初始化安全配置脚本集合。

## 快速使用

### SSH 安全配置脚本

一键在线执行（无需下载）：

```bash
# 使用 curl
curl -fsSL https://raw.githubusercontent.com/moooyo/vm-init/main/setup-ssh-security.sh | sudo bash

# 使用 wget
wget -qO- https://raw.githubusercontent.com/moooyo/vm-init/main/setup-ssh-security.sh | sudo bash
```

## 功能说明

### setup-ssh-security.sh

此脚本将自动完成以下配置：

| 功能 | 说明 |
|------|------|
| SSH 端口修改 | 将默认 22 端口改为 **34567** |
| 防火墙配置 | 自动放行新端口（支持 UFW/Firewalld） |
| SELinux 配置 | 自动添加端口策略（如适用） |
| fail2ban 安装 | 自动安装并配置 |
| 暴力破解防护 | 10分钟内失败5次即封禁1小时 |

**支持的系统：**
- Ubuntu
- Debian
- CentOS / RHEL / Rocky Linux / AlmaLinux

## 配置详情

### fail2ban 配置参数

| 参数 | 值 | 说明 |
|------|-----|------|
| findtime | 600 | 检测时间窗口（10分钟） |
| maxretry | 5 | 最大尝试次数 |
| bantime | 3600 | 封禁时长（1小时） |
| banaction | iptables-multiport | 使用 iptables 封禁 |

### 常用命令

```bash
# 查看 fail2ban 状态
sudo fail2ban-client status sshd

# 查看被封禁的 IP 列表
sudo fail2ban-client status sshd | grep "Banned IP"

# 解封指定 IP
sudo fail2ban-client set sshd unbanip <IP地址>

# 手动封禁 IP
sudo fail2ban-client set sshd banip <IP地址>

# 使用新端口连接 SSH
ssh -p 34567 user@your-server
```

## 注意事项

1. **执行前确保当前 SSH 会话不要断开**，先用新端口测试连接
2. 脚本会自动备份 SSH 配置到 `/etc/ssh/sshd_config.backup.*`
3. 如需恢复原配置：
   ```bash
   sudo cp /etc/ssh/sshd_config.backup.* /etc/ssh/sshd_config
   sudo systemctl restart sshd
   ```

## License

MIT
