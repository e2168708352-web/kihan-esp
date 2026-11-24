#!/system/bin/sh
# ============================================================================
# espd-supervisor.sh — espd 的守护外壳
#
# 单例机制：PID 文件 + /proc 校验（不依赖 flock，Android toybox 的 flock
# 在 shell 里行为不一致，实测会报 Bad file descriptor）。
#   启动时读 supervisor.pid，若该 PID 仍存活且 cmdline 含本脚本名 → 退出。
#
# 由 service.d/97_espd.sh 或 espd_boot.sh 以 nohup 拉起，全程 u:r:ksu:s0。
# ============================================================================

MOD=${1:-/data/adb/modules/esp_local}
BIN=$MOD/bin/espd-arm64
CONF=$MOD/bin/espd.conf
DIR=/data/local/tmp/.esp
LOG=$DIR/espd.log
PIDF=$DIR/supervisor.pid
GAME=com.tencent.KiHan
OVERLAY=com.sys.deskhelper
SVC=$OVERLAY/com.lcs.esp.OverlayService

mkdir -p "$DIR" 2>/dev/null

log() {
  echo "$(date '+%m-%d %H:%M:%S') $*" >> "$LOG" 2>/dev/null
}

rotate() {
  SZ=$(wc -c < "$LOG" 2>/dev/null || echo 0)
  if [ "$SZ" -gt 262144 ] 2>/dev/null; then
    tail -n 200 "$LOG" > "$LOG.tmp" 2>/dev/null && mv -f "$LOG.tmp" "$LOG"
  fi
}

# ---------- 单例：PID 文件 + /proc 校验 ----------
is_sup_alive() {
  [ -f "$PIDF" ] || return 1
  p=$(cat "$PIDF" 2>/dev/null | tr -d ' \n')
  [ -n "$p" ] || return 1
  [ -d "/proc/$p" ] || return 1
  c=$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null)
  case "$c" in
    *espd-supervisor.sh*) return 0 ;;
    *) return 1 ;;
  esac
}

if is_sup_alive; then
  log "supervisor: already running pid=$(cat $PIDF), exit"
  exit 0
fi

# 抢占地写入自己的 PID（$$ 是当前 shell）
echo $$ > "$PIDF"
# 再校验一次，防止并发写覆盖
sleep 0.3
if [ "$(cat "$PIDF" 2>/dev/null | tr -d ' \n')" != "$$" ]; then
  log "supervisor: lost pid race, exit"
  exit 0
fi

log "=== supervisor start pid=$$ mod=$MOD"
log "ctx=$(cat /proc/self/attr/current 2>/dev/null) uid=$(id -u)"
[ -x "$BIN" ] || { log "FATAL: $BIN not executable"; exit 1; }

# ---------- 配置：首次写入，已存在不覆盖 ----------
if [ ! -f "$DIR/espd.conf" ] && [ -f "$CONF" ]; then
  cp -f "$CONF" "$DIR/espd.conf"
  chmod 644 "$DIR/espd.conf"
  log "wrote espd.conf"
fi

# ---------- 悬浮窗 APK ----------
if ! pm list packages 2>/dev/null | grep -q "package:$OVERLAY"; then
  i=0
  while [ $i -lt 5 ]; do
    log "install overlay try=$i"
    if pm install -r -g "$MOD/esp/esp.apk" >>"$LOG" 2>&1; then break; fi
    i=$((i+1))
    sleep 10
  done
fi

# ---------- 悬浮窗按需生命周期 ----------
# 由独立 watchdog 管理：游戏在才起服务，游戏退出主动停掉，
# 把 SYSTEM_ALERT_WINDOW 的暴露窗口压到仅对局期间。
DW=$MOD/bin/desk-watch.sh
if [ -f "$DW" ]; then
  chmod 755 "$DW" 2>/dev/null
  nohup sh "$DW" >/dev/null 2>&1 &
  log "desk-watch started"
fi

# ---------- 主循环 ----------
fails=0
last=0
while true; do
  rotate

  # 退出时清 PID 文件
  trap 'rm -f "$PIDF"; exit 0' INT TERM

  "$BIN" daemon --dir "$DIR" --pkg "$GAME"
  rc=$?

  now=$(date +%s)
  if [ $((now - last)) -lt 30 ]; then
    fails=$((fails+1))
  else
    fails=0
  fi
  last=$now

  case $fails in
    0|1) nap=5 ;;
    2)   nap=15 ;;
    *)   nap=60 ;;
  esac
  log "espd exit rc=$rc fails=$fails nap=${nap}s"
  sleep $nap
done
