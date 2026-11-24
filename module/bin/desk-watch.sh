#!/system/bin/sh
# desk-watch.sh — 悬浮窗按需拉起
#
# 背景：supervisor 里原来的 svc_keep 写在主循环里，但 espd daemon 是常驻的，
# 那段代码实际永远不会执行 —— 等于 desk 从来不会自动起来，只能靠
# espd_boot.sh 或手动 am start 拉。本脚本补上这个缺口。
#
# 行为：游戏进程出现时拉起悬浮窗服务。
# 不做 force-stop —— 实测该 App 被停后会自行重启（父进程 zygote64），
# 强行杀只会产生无意义的启动/停止循环。

GAME=com.tencent.KiHan
PKG=com.sys.deskhelper
SVC=$PKG/com.lcs.esp.OverlayService
DIR=/data/local/tmp/.esp
PIDF=$DIR/desk-watch.pid
LOG=$DIR/espd.log

log() { echo "$(date '+%m-%d %H:%M:%S') desk-watch: $*" >> "$LOG" 2>/dev/null; }

# 单例
[ -f "$PIDF" ] && {
  p=$(cat "$PIDF" 2>/dev/null | tr -d ' \n')
  if [ -n "$p" ] && [ -d "/proc/$p" ]; then
    c=$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null)
    case "$c" in *desk-watch.sh*) exit 0;; esac
  fi
}
echo $$ > "$PIDF"

LAST_GAME=-1
log "start pid=$$"

while true; do
  GAME_ON=0
  pidof "$GAME" >/dev/null 2>&1 && GAME_ON=1

  # 只在 0→1 的上升沿动作，避免重复拉起
  if [ "$GAME_ON" = "1" ] && [ "$LAST_GAME" != "1" ]; then
    if ! pidof "$PKG" >/dev/null 2>&1; then
      am start-foreground-service -n "$SVC" >/dev/null 2>&1
      log "game on -> start overlay"
    fi
  fi
  LAST_GAME="$GAME_ON"
  sleep 5
done
