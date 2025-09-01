#!/bin/bash
set -e

# ===== 配置 =====
TARGET_DIR=/data/local/tmp
ADB_BIN=${ADB:-adb}
KILL_OLD=false
CACHE_DIR="$HOME/.frida_servers"   # 缓存目录
mkdir -p "$CACHE_DIR"

# ===== 帮助信息 =====
show_help() {
    cat <<EOF
用法: $(basename "\$0") [版本号] [--kill] [-h|--help]

说明:
  · 无参数        → 自动检测本地 frida-tools 版本，并下载/复用缓存的 frida-server
  · [版本号]      → 使用指定版本号
  · --kill        → 在启动新 frida-server 前，自动杀掉旧进程
  · -h, --help    → 显示本帮助信息

示例:
  $(basename "\$0")               # 自动检测
  $(basename "\$0") 17.1.5        # 指定版本
  $(basename "\$0") --kill        # 自动检测并杀掉旧进程
  $(basename "\$0") 17.1.5 --kill # 指定版本并杀掉旧进程
EOF
}

# ===== 参数解析 =====
ARGS=()
for arg in "$@"; do
    case "$arg" in
        --kill)
            KILL_OLD=true
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            ARGS+=("$arg")
            ;;
    esac
done

# ===== 获取版本号 =====
if [ ${#ARGS[@]} -ge 1 ]; then
    FRIDA_VERSION=${ARGS[0]}
    echo "[*] 使用用户指定的版本号: $FRIDA_VERSION"
else
    echo "[*] 未指定版本号，自动检测本地 frida-tools..."
    if ! command -v frida >/dev/null 2>&1; then
        echo "[!] 未检测到 frida，请先安装: pip install frida-tools"
        exit 1
    fi
    FRIDA_VERSION=$(frida --version)
    echo "[*] 检测到本地 frida-tools 版本: $FRIDA_VERSION"
fi

# ===== 检测设备架构 =====
echo "[*] 检测设备架构..."
ARCH=$($ADB_BIN shell getprop ro.product.cpu.abi | tr -d '\r')

case "$ARCH" in
    arm64-v8a)   ARCH_NAME="android-arm64" ;;
    armeabi-v7a) ARCH_NAME="android-arm" ;;
    x86)         ARCH_NAME="android-x86" ;;
    x86_64)      ARCH_NAME="android-x86_64" ;;
    *)
        echo "[!] 未知架构: $ARCH"
        exit 1
        ;;
esac
echo "[*] 设备架构: $ARCH -> $ARCH_NAME"

# ===== 构造文件名 & 路径 =====
SERVER_NAME="frida-server-${FRIDA_VERSION}-${ARCH_NAME}"
CACHE_BIN="$CACHE_DIR/$SERVER_NAME"

# ===== 检查缓存 =====
if [ -f "$CACHE_BIN" ]; then
    echo "[*] 已发现本地缓存: $CACHE_BIN"
else
    echo "[*] 本地未找到，开始下载 frida-server $FRIDA_VERSION for $ARCH_NAME"
    DOWNLOAD_URL="https://github.com/frida/frida/releases/download/${FRIDA_VERSION}/${SERVER_NAME}.xz"
    CHECKSUM_URL="https://github.com/frida/frida/releases/download/${FRIDA_VERSION}/frida-server-${FRIDA_VERSION}-checksums.txt"

    TMP_FILE="/tmp/${SERVER_NAME}.xz"

    echo "[*] 下载中: $DOWNLOAD_URL"
    curl -L -o "$TMP_FILE" "$DOWNLOAD_URL"

    echo "[*] 获取官方 SHA256..."
    EXPECTED_SHA256=$(curl -sL "$CHECKSUM_URL" | grep "${SERVER_NAME}.xz" | awk '{print \$1}')

    if [ -z "$EXPECTED_SHA256" ]; then
        echo "[!] 获取 SHA256 失败，请检查版本/架构是否存在"
        exit 1
    fi

    ACTUAL_SHA256=$(sha256sum "$TMP_FILE" | awk '{print \$1}')

    if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
        echo "[!] 校验失败！停止执行。"
        echo "    期待: $EXPECTED_SHA256"
        echo "    实际: $ACTUAL_SHA256"
        exit 1
    fi
    echo "[*] 校验通过 ✅"

    echo "[*] 解压并写入缓存目录..."
    xz -d -c "$TMP_FILE" > "$CACHE_BIN"
    chmod +x "$CACHE_BIN"
    rm -f "$TMP_FILE"
    echo "[*] 已缓存到: $CACHE_BIN"
fi

# ===== 推送到设备 =====
echo "[*] 推送 frida-server 到设备..."
$ADB_BIN push "$CACHE_BIN" "$TARGET_DIR/" >/dev/null
REMOTE_PATH="$TARGET_DIR/$SERVER_NAME"

# ===== 在手机端执行 =====
if [ "$KILL_OLD" = true ]; then
    echo "[*] 杀掉旧的 frida-server 进程..."
    $ADB_BIN shell "pkill -f frida-server || true"
fi

echo "[*] 设置权限并启动..."
$ADB_BIN shell "chmod +x $REMOTE_PATH && nohup $REMOTE_PATH >/dev/null 2>&1 &"

echo "[*] ✅ 完成！现在可以在 PC 上运行: frida-ps -U"
