#!/system/bin/sh

# =====================================================
# frida_auto_match.sh - 手机端自动部署脚本 (升级版)
# =====================================================

VERSION=\$1
KILL_OLD=false
CACHE_DIR="/data/local/tmp/frida-cache"
REMOTE_PATH="/data/local/tmp/frida-server"
LOG_FILE="/data/local/tmp/frida.log"

# 参数解析
if [ "\$2" = "--kill" ]; then
    KILL_OLD=true
fi

mkdir -p "$CACHE_DIR"

# STEP 1: 检测 CPU 架构
ABI=$(getprop ro.product.cpu.abi)
ARCH=""
case "$ABI" in
    arm64-v8a) ARCH="android-arm64" ;;
    armeabi-v7a) ARCH="android-arm" ;;
    x86) ARCH="android-x86" ;;
    x86_64) ARCH="android-x86_64" ;;
    *) echo "[!] 未知架构: $ABI, 默认使用 android-arm64"; ARCH="android-arm64" ;;
esac
echo "[*] 检测到手机架构: $ABI -> $ARCH"

# STEP 2: 下载 frida-server（如果不存在）
TARGET_FILE="$CACHE_DIR/frida-server-$VERSION-$ARCH"

if [ ! -f "$TARGET_FILE" ]; then
    echo "[*] 未找到缓存，正在下载 frida-server $VERSION ($ARCH) ..."
    FRIDA_URL="https://github.com/frida/frida/releases/download/$VERSION/frida-server-$VERSION-$ARCH.xz"
    FILE_NAME="$CACHE_DIR/frida-server-$VERSION-$ARCH.xz"

    curl -L -o "$FILE_NAME" "$FRIDA_URL"
    if [ $? -ne 0 ]; then
        echo "[!] 下载失败: $FRIDA_URL"
        exit 1
    fi

    xz -d "$FILE_NAME"
    mv "$CACHE_DIR/frida-server-$VERSION-$ARCH" "$TARGET_FILE"
    chmod +x "$TARGET_FILE"
    echo "[*] 下载完成并缓存: $TARGET_FILE"
else
    echo "[*] 已存在缓存: $TARGET_FILE, 跳过下载"
fi

# STEP 3: 杀掉旧进程（如果需要）
if [ "$KILL_OLD" = true ]; then
    echo "[*] 杀掉旧的 frida-server ..."
    su -c "pkill -f frida-server || true"
fi

# STEP 4: 启动 frida-server
cp "$TARGET_FILE" "$REMOTE_PATH"
chmod +x "$REMOTE_PATH"

echo "[*] 启动 frida-server $VERSION ($ARCH)..."
su -c "nohup $REMOTE_PATH >$LOG_FILE 2>&1 &"

echo "[*] ✅ frida-server $VERSION ($ARCH) 已启动 (root 模式)"
echo "[*] 日志文件: $LOG_FILE"
