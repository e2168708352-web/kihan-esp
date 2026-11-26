#!/system/bin/sh
# desk-watch.sh — 悬浮窗按需生命周期
#
# 背景：supervisor 里原来的 svc_keep 写在主循环里，但 espd daemon 是常驻的，
# 那段代码实际永远不会执行 —— 等于 desk 从来不会自动起来，只能靠
# espd_boot.sh 或手动 am start 拉。本脚本补上这个缺口。
#
# 不变量（每 5s 校验一次，动作带节流）：
#   游戏在 + 服务不在 → start-foreground-service
#   游戏不在 + 服务在 → stopservice
# 这样既覆盖「开游戏自动起」，也覆盖「对局中悬浮窗被系统回收后自动恢复」，
# 还把 SYSTEM_ALERT_WINDOW 的暴露窗口压到仅对局期间。
#
# 判「服务在不在」必须用 dumpsys，不能用 pidof：
#   am stopservice 之后进程会作为空进程常驻（实测 pid 一直在），
#   用 pidof 会永远认为「还在跑」，每 30s 空刷一次 stopservice。
#
# 不做 force-stop —— 实测该 App 被停后会自行重启（父进程 zygote64），
# 强行杀只会产生无意义的启动/停止循环。

GAME=com.tencent.KiHan
PKG=com.sys.deskhelper
SVC=$PKG/com.lcs.esp.OverlayService
DIR=/data/local/tmp/.esp
PIDF=$DIR/desk-watch.pid
LOG=$DIR/espd.log

log() { echo "$(date '+%m-%d %H:%M:%S') desk-watch: $*" >> "$LOG" 2>/dev/null; }

# 单例：PID 文件 + /proc 校验（进程名是 sh，不能用 pidof -x）
[ -f "$PIDF" ] && {
  p=$(cat "$PIDF" 2>/dev/null | tr -d ' \n')
  if [ -n "$p" ] && [ -d "/proc/$p" ]; then
    c=$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null)
    case "$c" in *desk-watch.sh*) exit 0;; esac
  fi
}
echo $$ > "$PIDF"
trap 'rm -f "$PIDF"; exit 0' INT TERM

alive() { pidof "$1" >/dev/null 2>&1; }

# 服务级判断（准确，但 dumpsys 较慢，只在必要时调用）
# 用「完整组件名」而非模糊的 "OverlayService" 匹配：不同 Android 版本的 dumpsys
# 输出列名/排版差异很大，匹配完整组件名 com.lcs.esp.OverlayService 最稳。
# 注意：不能用 pidof 兜底 —— am stopservice 之后进程会作为空进程常驻（实测 pid
# 一直在），pidof 会永远返回「还在跑」，导致 stop 逻辑每 30s 空刷一次。
svc_running() {
  dumpsys activity services "$PKG" 2>/dev/null | grep -q "com.lcs.esp.OverlayService"
}

SVC_ON=unknown
LAST_CHK=0
LAST_START=0
LAST_STOP=0
LAST_GAME=x
log "start pid=$$"

while true; do
  NOW=$(date +%s)
  GAME_ON=0
  alive "$GAME" && GAME_ON=1

  # 服务状态：游戏状态切换时立刻查，其余时间每 30s 复核一次。
  # 对局中服务被回收最多 30s 恢复，游戏退出最多 30s 摘掉，够用且不烧 CPU。
  if [ "$GAME_ON" != "$LAST_GAME" ] || [ $((NOW - LAST_CHK)) -ge 30 ]; then
    if svc_running; then SVC_ON=1; else SVC_ON=0; fi
    LAST_CHK=$NOW
  fi

  if [ "$GAME_ON" = "1" ] && [ "$SVC_ON" != "1" ] && [ $((NOW - LAST_START)) -ge 15 ]; then
    am start-foreground-service -n "$SVC" >/dev/null 2>&1
    sleep 2
    if svc_running; then
      SVC_ON=1
      LAST_START=$NOW
      log "game on -> overlay started"
    else
      LAST_START=$NOW
      log "game on -> start failed, retry later"
    fi
  elif [ "$GAME_ON" = "0" ] && [ "$SVC_ON" = "1" ] && [ $((NOW - LAST_STOP)) -ge 30 ]; then
    am stopservice -n "$SVC" >/dev/null 2>&1
    sleep 2
    if svc_running; then
      LAST_STOP=$NOW
      log "game off -> stop failed, retry later"
    else
      SVC_ON=0
      LAST_STOP=$NOW
      log "game off -> overlay stopped"
    fi
  fi

  LAST_GAME=$GAME_ON
  sleep 5
done
