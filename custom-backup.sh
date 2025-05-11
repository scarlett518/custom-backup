#!/bin/bash

# 确保以 root 权限运行
if [ "$(id -u)" -ne 0 ]; then
    echo "请以 root 权限运行此脚本"
    exit 1
fi

# 默认配置
DEFAULT_SOURCE="/home"
DEFAULT_BACKUP="/var/backups/custom"
DEFAULT_INTERVAL=86400 # 1天
DEFAULT_MAX_BACKUPS=7

# 提示用户输入配置
read -p "请输入要备份的源目录 [$DEFAULT_SOURCE]: " SOURCE_DIR
SOURCE_DIR=${SOURCE_DIR:-$DEFAULT_SOURCE}

read -p "请输入备份存储的目标目录 [$DEFAULT_BACKUP]: " BACKUP_DIR
BACKUP_DIR=${BACKUP_DIR:-$DEFAULT_BACKUP}

read -p "请输入备份间隔时间(秒) [$DEFAULT_INTERVAL]: " BACKUP_INTERVAL
BACKUP_INTERVAL=${BACKUP_INTERVAL:-$DEFAULT_INTERVAL}

read -p "请输入保留的最大备份数量 [$DEFAULT_MAX_BACKUPS]: " MAX_BACKUPS
MAX_BACKUPS=${MAX_BACKUPS:-$DEFAULT_MAX_BACKUPS}

# 创建备份目录
mkdir -p "$BACKUP_DIR"

# 创建备份脚本
SCRIPT_PATH="/usr/local/bin/custom-backup.sh"
cat > "$SCRIPT_PATH" << EOL
#!/bin/bash

# 配置部分
SOURCE_DIR="$SOURCE_DIR"
BACKUP_DIR="$BACKUP_DIR"
BACKUP_INTERVAL=$BACKUP_INTERVAL
MAX_BACKUPS=$MAX_BACKUPS
LOG_FILE="/var/log/custom_backup.log"

# 确保备份目录存在
mkdir -p "\$BACKUP_DIR"

# 记录日志的函数
log_message() {
    echo "\$(date '+%Y-%m-%d %H:%M:%S') - \$1" >> "\$LOG_FILE"
    echo "\$(date '+%Y-%m-%d %H:%M:%S') - \$1"
}

# 执行备份的函数
perform_backup() {
    # 创建带时间戳的备份文件名
    TIMESTAMP=\$(date +"%Y%m%d_%H%M%S")
    BACKUP_FILE="\$BACKUP_DIR/backup_\$TIMESTAMP.tar.gz"
    
    log_message "开始备份 \$SOURCE_DIR 到 \$BACKUP_FILE"
    
    # 执行备份
    if tar -czf "\$BACKUP_FILE" -C "\$(dirname "\$SOURCE_DIR")" "\$(basename "\$SOURCE_DIR")"; then
        log_message "备份成功完成"
        
        # 检查并删除旧备份
        cleanup_old_backups
    else
        log_message "备份失败"
    fi
}

# 清理旧备份的函数
cleanup_old_backups() {
    # 获取备份文件列表并按时间排序
    BACKUP_COUNT=\$(ls -1 "\$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null | wc -l)
    
    if [ "\$BACKUP_COUNT" -gt "\$MAX_BACKUPS" ]; then
        log_message "当前备份数量 (\$BACKUP_COUNT) 超过最大限制 (\$MAX_BACKUPS)，正在清理旧备份"
        
        # 删除最旧的备份
        OLDEST_BACKUPS=\$(ls -1t "\$BACKUP_DIR"/backup_*.tar.gz | tail -n \$((\$BACKUP_COUNT - \$MAX_BACKUPS)))
        for old_backup in \$OLDEST_BACKUPS; do
            rm "\$old_backup"
            log_message "已删除旧备份: \$old_backup"
        done
    fi
}

# 主循环
main_loop() {
    log_message "备份服务已启动，间隔时间: \$BACKUP_INTERVAL 秒，最大备份数: \$MAX_BACKUPS"
    
    while true; do
        perform_backup
        log_message "等待下一次备份，将在 \$BACKUP_INTERVAL 秒后执行"
        sleep "\$BACKUP_INTERVAL"
    done
}

# 启动主循环
main_loop
EOL

# 设置执行权限
chmod +x "$SCRIPT_PATH"

# 创建 systemd 服务文件
SERVICE_PATH="/etc/systemd/system/custom-backup.service"
cat > "$SERVICE_PATH" << EOL
[Unit]
Description=Custom Backup Service
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash $SCRIPT_PATH
Restart=on-failure
RestartSec=60
User=root

[Install]
WantedBy=multi-user.target
EOL

# 重新加载 systemd 配置
systemctl daemon-reload

# 启用并启动服务
systemctl enable custom-backup.service
systemctl start custom-backup.service

echo "备份服务已安装并启动"
echo "源目录: $SOURCE_DIR"
echo "备份目录: $BACKUP_DIR"
echo "备份间隔: $BACKUP_INTERVAL 秒"
echo "最大备份数: $MAX_BACKUPS"
echo "日志文件: /var/log/custom_backup.log"
echo ""
echo "您可以使用以下命令管理服务:"
echo "  查看状态: systemctl status custom-backup.service"
echo "  停止服务: systemctl stop custom-backup.service"
echo "  启动服务: systemctl start custom-backup.service"
echo "  禁用自启: systemctl disable custom-backup.service"
