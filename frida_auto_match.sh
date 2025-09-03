#!/system/bin/sh
# =====================================================
# frida_auto_match.sh - 手机端自动部署脚本 (增强版)
# =====================================================

VERSION=\$1
KILL_OLD=false
CACHE_DIR="/data/local/tmp/frida-cache"
REMOTE_PATH="/data/local/tmp/frida-server"
LOG_FILE="/data/local/tmp/frida.log"
PID_FILE="/data/local/tmp/frida.pid"

# ================= 参数校验 =================
if [ -z "$VERSION" ]; then
    echo "[!] 用法: sh frida_auto_match.sh <version> [--kill|--status]"
    exit 1
fi

if [ "\$2" = "--kill" ]; then
    KILL_OLD=true
fi

mkdir -p "$CACHE_DIR"

# ================= 工具可用性检查 =================
command -v curl >/dev/null 2>&1 || { echo "[!] 缺少 curl，请安装或推送"; exit 1; }
command -v xz   >/dev/null 2>&1 || { echo "[!] 缺少 xz，请安装"; exit 1; }

# ================= 检测 CPU 架构 =================
ABI=$(getprop ro.product.cpu.abi)
ARCH=""
case "$ABI" in
    arm64-v8a)   ARCH="android-arm64" ;;
    armeabi-v7a) ARCH="android-arm" ;;
    x86)         ARCH="android-x86" ;;
    x86_64)      ARCH="android-x86_64" ;;
    *) echo "[!] 未知架构: $ABI, 默认使用 android-arm64"; ARCH="android-arm64" ;;
esac
echo "[*] 检测到手机架构: $ABI -> $ARCH"

# ================= 下载或使用缓存 =================
TARGET_FILE="$CACHE_DIR/frida-server-$VERSION-$ARCH"

if [ ! -x "$TARGET_FILE" ]; then
    echo "[*] 未找到缓存或文件不可执行，正在下载 frida-server $VERSION ($ARCH) ..."
    FRIDA_URL="https://github.com/frida/frida/releases/download/$VERSION/frida-server-$VERSION-$ARCH.xz"
    FILE_NAME="$CACHE_DIR/frida-server-$VERSION-$ARCH.xz"

    rm -f "$FILE_NAME" "$TARGET_FILE"     # 清理旧文件
    curl -L -o "$FILE_NAME" "$FRIDA_URL"
    if [ $? -ne 0 ]; then
        echo "[!] 下载失败: $FRIDA_URL"
        exit 1
    fi

    xz -d "$FILE_NAME" || { echo "[!] 解压失败"; exit 1; }
    mv "$CACHE_DIR/frida-server-$VERSION-$ARCH" "$TARGET_FILE"
    chmod +x "$TARGET_FILE"
    echo "[*] 下载完成并缓存: $TARGET_FILE"
else
    echo "[*] 已存在缓存: $TARGET_FILE"
fi

# ================= 选择 root 调用方式 =================
if su -c true >/dev/null 2>&1; then
    SU="su -c"
elif su 0 true >/dev/null 2>&1; then
    SU="su 0 -c"
else
    echo "[!] 无 root 权限，无法启动 frida-server"
    exit 1
fi

# ================= --status 模式 =================
if [ "\$2" = "--status" ]; then
    echo "[*] 状态检查："
    if [ -x "$REMOTE_PATH" ]; then
        echo " - 运行目录: 存在"
        $SU "$REMOTE_PATH --version" 2>/dev/null || echo " - 无法获取版本"
    else
        echo " - 运行目录: 不存在"
    fi
    if [ -f "$PID_FILE" ]; then
        echo " - PID文件: 存在 ($(cat $PID_FILE))"
    else
        echo " - PID文件: 不存在"
    fi
    exit 0
fi

# ================= 杀掉旧进程 =================
if [ "$KILL_OLD" = true ]; then
    echo "[*] 杀掉旧的 frida-server ..."
    $SU "pkill -f frida-server || true"
fi

# ================= 检查运行目录版本 =================
if [ -x "$REMOTE_PATH" ] && cmp -s "$REMOTE_PATH" "$TARGET_FILE"; then
    echo "[*] 运行目录已是目标版本，无需复制"
else
    echo "[*] 更新运行目录为目标版本..."
    cp "$TARGET_FILE" "$REMOTE_PATH"
    chmod +x "$REMOTE_PATH"
fi

# ================= 启动 frida-server =================
echo "[*] 启动 frida-server $VERSION ($ARCH)..."
$SU "nohup $REMOTE_PATH >$LOG_FILE 2>&1 & echo \$! > $PID_FILE"

PID=$(cat $PID_FILE 2>/dev/null)
if [ -n "$PID" ]; then
    echo "[*] ✅ frida-server $VERSION ($ARCH) 已启动 (PID: $PID)"
else
    echo "[!] 启动 frida-server 失败，请检查日志"
fi

echo "[*] 日志文件: $LOG_FILE"
