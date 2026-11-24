#!/system/bin/sh
# ============================================================================
# espd_boot.sh — 临时 root 环境下的 ESP 启动脚本
#
# 用途：完全重启后临时 root 会消失。重新拿到 root 后跑这个脚本恢复。
#   adb push espd_boot.sh /data/local/tmp/
#   adb shell 'su -c "sh /data/local/tmp/espd_boot.sh"'
#
# 它做的事：
#   1) 自检：是否真的在 ksu 域（临时 root 是否生效）
#   2) 从模块目录同步 espd 到 /data/local/tmp/.esp/bin（防止模块被清理）
#   3) 起 supervisor（单例）
#   4) 装/更新 desk APK
#   5) 输出完整状态
#
# 不依赖：service.d、post-fs-data、zygisk、reboot
# ============================================================================

M=/data/adb/modules/esp_local
W=/data/local/tmp/.esp
BIN=$W/bin
LOG=$W/espd.log

log() { echo "$(date '+%m-%d %H:%M:%S') $*" | tee -a "$LOG" >/dev/null; echo "  $*"; }

echo "=========================================="
echo " espd boot (临时 root 模式)"
echo "=========================================="

# ---------- 1. root 自检 ----------
CTX=$(cat /proc/self/attr/current 2>/dev/null | tr -d '\0')
UID=$(id -u 2>/dev/null)
echo "[1] root 自检"
echo "    uid=$UID"
echo "    ctx=$CTX"

if [ "$UID" != "0" ]; then
  echo "    !! 不是 root，退出"
  exit 1
fi

case "$CTX" in
  *ksu*|*su:s0*|*su_u*)
    echo "    域可用 ✓"
    ;;
  *shell*)
    echo "    !! 在 shell 域（读不到 app 内存）"
    echo "    原因：内联 su -c '...' 会掉域，必须走脚本文件"
    echo "    正确用法： adb shell 'su -c \"sh /data/local/tmp/espd_boot.sh\"'"
    exit 2
    ;;
  *)
    echo "    ? 未知域，继续尝试（多数情况仍可用）"
    ;;
esac

# ---------- 2. 定位 espd 二进制 ----------
echo ""
echo "[2] 定位 espd"
mkdir -p "$BIN" "$W"

# 优先用模块里的（模块可能因临时 root 失效而未挂载，但文件通常在）
SRC=""
for c in "$M/bin/espd-arm64" "$W/bin/espd-arm64" "/data/local/tmp/espd"; do
  if [ -f "$c" ] && [ -s "$c" ]; then SRC="$c"; break; fi
done

if [ -z "$SRC" ]; then
  echo "    !! 找不到 espd-arm64"
  echo "    需要先刷模块：ksud module install /data/local/tmp/esp_local-module.zip"
  exit 3
fi
echo "    source: $SRC"

# 复制到工作目录（模块目录可能被卸载/只读，工作目录更稳）
if [ "$SRC" != "$BIN/espd-arm64" ]; then
  cp -f "$SRC" "$BIN/espd-arm64" 2>/dev/null
fi
chmod 755 "$BIN/espd-arm64" 2>/dev/null
echo "    ready: $BIN/espd-arm64 ($(stat -c %s "$BIN/espd-arm64" 2>/dev/null) B)"

# supervisor：模块里有就用模块的，否则内联一份精简版
if [ -f "$M/bin/espd-supervisor.sh" ]; then
  SUP="$M/bin/espd-supervisor.sh"
  echo "    supervisor: $SUP (模块)"
else
  SUP="$BIN/supervisor.sh"
   cat > "$SUP" <<'SUPEOF'
#!/system/bin/sh
W=/data/local/tmp/.esp
B=$W/bin/espd-arm64
PIDF=$W/supervisor.pid
mkdir -p "$W"

# 单例：PID 文件 + /proc 校验（不用 flock，Android toybox 在 sh 里不可靠）
alive() {
  [ -f "$PIDF" ] || return 1
  p=$(cat "$PIDF" 2>/dev/null | tr -d ' \n')
  [ -n "$p" ] && [ -d "/proc/$p" ] || return 1
  c=$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null)
  case "$c" in *espd-supervisor.sh*) return 0;; *) return 1;; esac
}
alive && exit 0
echo $$ > "$PIDF"
sleep 0.3
[ "$(cat "$PIDF" 2>/dev/null | tr -d ' \n')" = "$$" ] || exit 0

# 悬浮窗按需启动（游戏在才起服务）
DW=$W/bin/desk-watch.sh
[ -f "$DW" ] && nohup sh "$DW" >/dev/null 2>&1 &

fails=0; last=0
while true; do
  "$B" daemon --dir "$W" --pkg com.tencent.KiHan >>"$W/espd.log" 2>&1
  rc=$?
  now=$(date +%s)
  if [ $((now - last)) -lt 30 ]; then fails=$((fails+1)); else fails=0; fi
  last=$now
  case $fails in 0|1) nap=5;; 2) nap=15;; *) nap=60;; esac
  echo "$(date '+%m-%d %H:%M:%S') espd exit rc=$rc fails=$fails nap=${nap}s" >>"$W/espd.log"
  sleep $nap
done
SUPEOF
  chmod 755 "$SUP"
  echo "    supervisor: $SUP (内联)"
fi

# 配置模板
if [ ! -f "$W/espd.conf" ] && [ -f "$M/bin/espd.conf" ]; then
  cp -f "$M/bin/espd.conf" "$W/espd.conf"
  echo "    配置: 已从模块复制"
elif [ ! -f "$W/espd.conf" ]; then
  echo "    !! 无 espd.conf，daemon 会自己生成（需模块模板）"
fi

# ---------- 3. 起 supervisor ----------
echo ""
echo "[3] 启动 espd"

# 停止所有旧 supervisor / espd。
# 注意：pidof -x espd-supervisor.sh 找不到进程——脚本是通过 "sh 脚本" 跑的，
# 进程名是 sh。必须扫 /proc/*/cmdline 精确匹配。
kill_sup() {
  for d in /proc/[0-9]*; do
    [ -r "$d/cmdline" ] || continue
    c=$(tr '\0' ' ' < "$d/cmdline" 2>/dev/null)
    case "$c" in
      *espd-supervisor.sh*|*espd_boot.sh*)
        p=${d#/proc/}
        [ "$p" = "$$" ] && continue
        kill -9 "$p" 2>/dev/null && echo "    停止旧 supervisor pid=$p"
        ;;
    esac
  done
}

OLD=$(pidof espd-arm64)
if [ -n "$OLD" ] || true; then
  kill_sup
  sleep 1
  for p in $(pidof espd-arm64); do kill -9 "$p" 2>/dev/null; done
  sleep 1
fi

rm -f "$W/espd.lock" "$W/supervisor.lock"
nohup sh "$SUP" "$M" >/dev/null 2>&1 &
sleep 4

P=$(pidof espd-arm64)
if [ -n "$P" ]; then
  echo "    espd pid=$P ✓"
  echo "    domain=$(cat /proc/$P/attr/current 2>/dev/null | tr -d '\0')"
else
  echo "    !! espd 未起来，看日志："
  tail -10 "$W/espd.log" 2>/dev/null | sed 's/^/      /'
fi

# ---------- 4. desk ----------
echo ""
echo "[4] 悬浮窗"
if pm list packages 2>/dev/null | grep -q "package:com.sys.deskhelper"; then
  echo "    已安装 ✓"
else
  if [ -f "$M/esp/esp.apk" ]; then
    echo "    安装中..."
    pm install -r -g "$M/esp/esp.apk" 2>&1 | tail -1 | sed 's/^/      /'
  else
    echo "    !! 无 esp.apk"
  fi
fi
appops set com.sys.deskhelper SYSTEM_ALERT_WINDOW allow 2>/dev/null && echo "    悬浮窗权限 ✓"

# ---------- 5. 状态汇总 ----------
echo ""
echo "[5] 状态"
echo "    espd:  $(pidof espd-arm64 || echo NOT_RUNNING)"
echo "    sup:   $(pidof -x espd-supervisor.sh 2>/dev/null || echo -)"
echo "    游戏:  $(pidof com.tencent.KiHan || echo '未运行（开游戏后自动接管）')"
echo ""
echo "    日志: tail $W/espd.log"
echo "    状态: cat  $W/status.json"
echo ""
echo "=========================================="
echo " 完成。开游戏即可。"
echo " 停止: kill \$(pidof espd-arm64)"
echo "=========================================="
