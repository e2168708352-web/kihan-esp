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

echo "=========================================="
echo " espd boot (临时 root 模式)"
echo "=========================================="

# ---------- 1. root 自检 ----------
CTX=$(cat /proc/self/attr/current 2>/dev/null | tr -d '\0')
# 注意：不能用 UID 做变量名 —— bash/mksh 里它是只读变量，赋值会被静默忽略，
# 导致 root 自检拿到 shell 自动填充的旧值（虽然碰巧也是 0，但语义不可靠）。
RUID=$(id -u 2>/dev/null)
echo "[1] root 自检"
echo "    uid=$RUID"
echo "    ctx=$CTX"

if [ "$RUID" != "0" ]; then
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

# supervisor 现在就只有在模块里的一份（bin/espd-supervisor.sh），
# 不再维护内联兜底副本——两份逻辑容易不同步，且模块包里必然包含它。
SUP="$M/bin/espd-supervisor.sh"
if [ ! -f "$SUP" ]; then
  echo "    !! 缺少 $SUP，模块不完整"
  exit 3
fi
echo "    supervisor: $SUP"

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
# 关键：绝不能匹配 espd_boot.sh —— 当前脚本是通过
# `su -c "sh .../espd_boot.sh"` 启动的，匹配它会连父进程（su/App）一起杀掉，
# 这正是「一键部署跑到一半没输出」的原因。
# 也排除自己的所有祖先进程（$$ / $PPID / 更上层）。
ancestors=" $$ $PPID "
p=$PPID
while [ -n "$p" ] && [ "$p" != "0" ] && [ "$p" != "1" ]; do
  ancestors="$ancestors$p "
  p=$(awk '/^PPid:/{print $2}' "/proc/$p/status" 2>/dev/null)
  [ -z "$p" ] && break
done

kill_sup() {
  for d in /proc/[0-9]*; do
    [ -r "$d/cmdline" ] || continue
    pid=${d#/proc/}
    case "$ancestors" in *" $pid "*) continue;; esac
    c=$(tr '\0' ' ' < "$d/cmdline" 2>/dev/null)
    case "$c" in
      *espd-supervisor.sh*)
        kill -9 "$pid" 2>/dev/null && echo "    停止旧 supervisor pid=$pid"
        ;;
    esac
  done
}

# 无条件清理：即使当前没有 espd，也可能有残留的 supervisor 占着锁
OLD=$(pidof espd-arm64)
[ -n "$OLD" ] && echo "    发现旧 espd pid=$OLD"
kill_sup
sleep 1
for p in $(pidof espd-arm64); do kill -9 "$p" 2>/dev/null; done
sleep 1

rm -f "$W/espd.lock" "$W/supervisor.lock"

# 用 setsid 彻底脱离当前会话：
# App 通过 `su -c` 调用本脚本时，su 会话结束会连带回收其子进程；
# 只靠 nohup 在部分 Android 版本上不够，supervisor 会活不过 2 秒。
# setsid 让 supervisor 成为独立会话首进程，父进程变为 init。
if command -v setsid >/dev/null 2>&1; then
  setsid sh "$SUP" "$M" </dev/null >/dev/null 2>&1 &
else
  nohup sh "$SUP" "$M" </dev/null >/dev/null 2>&1 &
fi
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
# 不能用 pidof -x espd-supervisor.sh —— 脚本是以 "sh 脚本" 跑的，进程名是 sh。
SUPP=$(cat "$W/supervisor.pid" 2>/dev/null | tr -d ' \n')
if [ -n "$SUPP" ] && [ -d "/proc/$SUPP" ]; then echo "    sup:   $SUPP"; else echo "    sup:   -"; fi
echo "    游戏:  $(pidof com.tencent.KiHan || echo '未运行（开游戏后自动接管）')"
echo ""
echo "    日志: tail $W/espd.log"
echo "    状态: cat  $W/status.json"
echo ""
echo "=========================================="
echo " 完成。开游戏即可。"
echo " 停止(会被 supervisor 5s 内重新拉起):"
echo "   先杀 supervisor: kill \$(cat $W/supervisor.pid)"
echo "   再杀 espd:       kill \$(pidof espd-arm64)"
echo "   （只杀 espd 没用 —— supervisor 是守护进程，会立刻重启它）"
echo "=========================================="
