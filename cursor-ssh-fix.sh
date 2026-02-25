#!/usr/bin/env bash
#
# cursor-ssh-fix  一键修复 Cursor Remote SSH 连接失败
#
# 常见故障：
#   1. 锁文件残留 (Could not acquire lock after multiple attempts)
#   2. 远程机器无法下载 Cursor Server (install_timeout)
#   3. commit / realCommit 目录不匹配
#
# 用法：
#   cursor-ssh-fix <ssh-host>          # 自动诊断并修复，cursor-ssh-fix fedora
#   cursor-ssh-fix <ssh-host> --clean  # 完全清理后重装，cursor-ssh-fix fedora --clean


set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; }
die()   { err "$*"; exit 1; }

usage() {
    cat <<EOF
用法: cursor-ssh-fix <ssh-host> [--clean]

  <ssh-host>   SSH 配置中的远程主机名 (如 fedora)
  --clean      完全清理远程 Cursor Server 后重新安装
EOF
    exit 1
}

[[ $# -lt 1 ]] && usage
HOST="$1"
CLEAN="${2:-}"

# ── 1. 读取本地 Cursor 的 product.json ──

CURSOR_PRODUCT_JSON="/Applications/Cursor.app/Contents/Resources/app/product.json"
if [[ "$(uname)" == "Linux" ]]; then
    for p in /usr/share/cursor/resources/app/product.json \
             /opt/Cursor/resources/app/product.json \
             "$HOME/.local/share/cursor/resources/app/product.json"; do
        [[ -f "$p" ]] && CURSOR_PRODUCT_JSON="$p" && break
    done
fi
[[ ! -f "$CURSOR_PRODUCT_JSON" ]] && die "找不到 Cursor product.json: $CURSOR_PRODUCT_JSON"

COMMIT=$(python3 -c "import json; d=json.load(open('$CURSOR_PRODUCT_JSON')); print(d['commit'])")
REAL_COMMIT=$(python3 -c "import json; d=json.load(open('$CURSOR_PRODUCT_JSON')); print(d['realCommit'])")
VERSION=$(python3 -c "import json; d=json.load(open('$CURSOR_PRODUCT_JSON')); print(d['version'])")
DATA_FOLDER=$(python3 -c "import json; d=json.load(open('$CURSOR_PRODUCT_JSON')); print(d['serverDataFolderName'])")

info "Cursor $VERSION | commit=$COMMIT | realCommit=$REAL_COMMIT"

# ── 2. 测试 SSH ──

info "测试 SSH 连接 $HOST ..."
ssh -o ConnectTimeout=10 "$HOST" "echo ok" >/dev/null 2>&1 || die "SSH 连接失败，请先确认 ssh $HOST 正常"
ok "SSH 连接正常"

# ── 3. 探测远程架构 ──

REMOTE_ARCH_RAW=$(ssh "$HOST" "uname -m" 2>/dev/null)
case "$REMOTE_ARCH_RAW" in
    x86_64)  REMOTE_ARCH="x64" ;;
    aarch64) REMOTE_ARCH="arm64" ;;
    armv7l)  REMOTE_ARCH="armhf" ;;
    *)       REMOTE_ARCH="$REMOTE_ARCH_RAW" ;;
esac
PLATFORM="linux"
info "远程平台: $PLATFORM-$REMOTE_ARCH"

# ── 4. 清理残留 ──

info "清理锁文件和僵尸进程 ..."
ssh "$HOST" "
    pkill -f 'cursor-server.*tar.gz' 2>/dev/null || true
    LOCK_DIR=\${XDG_RUNTIME_DIR:-/tmp}
    rm -f \"\$LOCK_DIR\"/cursor-remote-lock* 2>/dev/null || true
    rm -f /tmp/cursor-remote-lock* 2>/dev/null || true
" 2>/dev/null
ok "清理完成"

# ── 5. --clean 模式 ──

if [[ "$CLEAN" == "--clean" ]]; then
    warn "完全清理模式：删除远程 ~/$DATA_FOLDER/bin"
    ssh "$HOST" "rm -rf ~/$DATA_FOLDER/bin" 2>/dev/null
    ok "已清理"
fi

# ── 6. 检查是否已安装 ──

SERVER_DIR="\$HOME/$DATA_FOLDER/bin/$PLATFORM-$REMOTE_ARCH/$COMMIT"

info "检查远程安装状态 ..."
INSTALLED=$(ssh "$HOST" "
    SD=\"\$HOME/$DATA_FOLDER/bin/$PLATFORM-$REMOTE_ARCH/$COMMIT\"
    if [ -f \"\$SD/bin/cursor-server\" ] && [ -s \"\$SD/bin/cursor-server\" ] && \
       [ -x \"\$SD/node\" ] && [ -f \"\$SD/out/server-main.js\" ]; then
        echo YES
    else
        echo NO
    fi
" 2>/dev/null)

if [[ "$INSTALLED" == "YES" ]]; then
    ok "Cursor Server 已正确安装"

    info "启动测试 ..."
    ssh "$HOST" "
        SD=\"\$HOME/$DATA_FOLDER/bin/$PLATFORM-$REMOTE_ARCH/$COMMIT\"
        timeout 5 \"\$SD/node\" \"\$SD/out/server-main.js\" \
            --host=127.0.0.1 --port=0 \
            --connection-token=test-\$\$ \
            --accept-server-license-terms 2>&1 \
        | grep -E '(Server bound|listening|started)' || true
    " 2>/dev/null

    ok "修复完成，请在 Cursor 中重新连接 $HOST"
    exit 0
fi

# ── 7. 下载并安装 ──

DOWNLOAD_URL="https://downloads.cursor.com/production/${REAL_COMMIT}/${PLATFORM}/${REMOTE_ARCH}/cursor-reh-${PLATFORM}-${REMOTE_ARCH}.tar.gz"
LOCAL_TMP="/tmp/cursor-reh-${PLATFORM}-${REMOTE_ARCH}.tar.gz"

info "远程未安装，检查远程能否直接下载 ..."
REMOTE_CAN_DOWNLOAD=$(ssh "$HOST" "
    timeout 10 curl -sI --connect-timeout 5 '$DOWNLOAD_URL' 2>/dev/null | head -1 | grep -c 200 || echo 0
" 2>/dev/null || echo "0")

if [[ "$REMOTE_CAN_DOWNLOAD" -ge 1 ]]; then
    info "远程可访问 downloads.cursor.com，直接下载 ..."
    ssh "$HOST" "
        SD=\"\$HOME/$DATA_FOLDER/bin/$PLATFORM-$REMOTE_ARCH/$COMMIT\"
        mkdir -p \"\$SD\"
        TMP=\"/tmp/cursor-server-\$\$.tar.gz\"
        echo '  下载中 ...'
        if command -v wget >/dev/null 2>&1; then
            wget --tries=3 --timeout=30 --progress=bar:force -O \"\$TMP\" '$DOWNLOAD_URL'
        else
            curl --retry 3 --connect-timeout 30 -fL --progress-bar -o \"\$TMP\" '$DOWNLOAD_URL'
        fi
        echo '  解压中 ...'
        tar xzf \"\$TMP\" --strip-components=1 -C \"\$SD\"
        rm -f \"\$TMP\"
    "
else
    warn "远程无法访问 downloads.cursor.com，本地下载后传输"

    NEED_DOWNLOAD=true
    if [[ -f "$LOCAL_TMP" ]]; then
        LOCAL_SIZE=$(stat -f%z "$LOCAL_TMP" 2>/dev/null || stat -c%s "$LOCAL_TMP" 2>/dev/null || echo 0)
        if (( LOCAL_SIZE > 50000000 )); then
            info "使用本地缓存: $LOCAL_TMP ($(( LOCAL_SIZE / 1048576 ))MB)"
            NEED_DOWNLOAD=false
        else
            rm -f "$LOCAL_TMP"
        fi
    fi

    if $NEED_DOWNLOAD; then
        info "下载 Cursor Server ($DOWNLOAD_URL) ..."
        curl -L --progress-bar -o "$LOCAL_TMP" "$DOWNLOAD_URL" || die "下载失败"
    fi

    info "传输到远程 ..."
    ssh "$HOST" "mkdir -p \"\$HOME/$DATA_FOLDER/bin/$PLATFORM-$REMOTE_ARCH/$COMMIT\""
    ssh "$HOST" "cat > /tmp/cursor-reh.tar.gz" < "$LOCAL_TMP"
    ok "传输完成 ($(( $(stat -f%z "$LOCAL_TMP" 2>/dev/null || stat -c%s "$LOCAL_TMP") / 1048576 ))MB)"

    info "远程解压安装 ..."
    ssh "$HOST" "
        SD=\"\$HOME/$DATA_FOLDER/bin/$PLATFORM-$REMOTE_ARCH/$COMMIT\"
        mkdir -p \"\$SD\"
        tar xzf /tmp/cursor-reh.tar.gz --strip-components=1 -C \"\$SD\"
        rm -f /tmp/cursor-reh.tar.gz
    " 2>/dev/null
fi

# ── 8. 验证 ──

info "验证安装 ..."
VERIFY=$(ssh "$HOST" "
    SD=\"\$HOME/$DATA_FOLDER/bin/$PLATFORM-$REMOTE_ARCH/$COMMIT\"
    if [ -f \"\$SD/bin/cursor-server\" ] && [ -s \"\$SD/bin/cursor-server\" ] && \
       [ -x \"\$SD/node\" ] && [ -f \"\$SD/out/server-main.js\" ]; then
        \"\$SD/node\" \"\$SD/out/server-main.js\" --version 2>/dev/null | head -1
    else
        echo FAIL
    fi
" 2>/dev/null)

if [[ "$VERIFY" == "FAIL" || -z "$VERIFY" ]]; then
    die "安装验证失败"
fi
ok "版本: $VERIFY"

# ── 9. 启动测试 ──

info "启动测试 ..."
ssh "$HOST" "
    SD=\"\$HOME/$DATA_FOLDER/bin/$PLATFORM-$REMOTE_ARCH/$COMMIT\"
    timeout 5 \"\$SD/node\" \"\$SD/out/server-main.js\" \
        --host=127.0.0.1 --port=0 \
        --connection-token=test-\$\$ \
        --accept-server-license-terms 2>&1 \
    | grep -E '(Server bound|listening|started)' || true
" 2>/dev/null

echo ""
ok "全部完成！请在 Cursor 中重新连接 $HOST"
