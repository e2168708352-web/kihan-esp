#!/system/bin/sh
# espd-supervisor.sh — espd 的守护外壳（单例 + 退避重启 + 日志轮转 + 悬浮窗保活）
#
# 由 service.d/97_espd.sh 以 nohup 拉起，全程运行在 u:r:ksu:s0（实测该域可读 app 内存）。
# 本脚本不提权、不碰 zygote、不 pkill 任何系统进程。

MOD=${1:-/data/adb/modules/esp_local}
BIN=$MOD/bin/espd-arm64
CONF=$MOD/bin/espd.conf
DIR=/data/local/tmp/.esp
LOG=$DIR/espd.log
STATUS=$DIR/status.json
OVERLAY=com.sys.deskhelper
SVC=$OVERLAY/com.lcs.esp.OverlayService
GAME=com.tencent.KiHan

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

# ---------- 单例：已有 espd 在跑就退出 ----------
if [ -n "$(pidof espd-arm64)" ]; then
  log "supervisor: espd-arm64 already running, exit"
  exit 0
fi

log "=== supervisor start mod=$MOD"
log "ctx=$(cat /proc/self/attr/current 2>/dev/null) uid=$(id -u)"
[ -x "$BIN" ] || { log "FATAL: $BIN not executable"; exit 1; }

# ---------- 配置：首次写入，已存在不覆盖（保留真机校准值） ----------
if [ ! -f "$DIR/espd.conf" ] && [ -f "$CONF" ]; then
  cp -f "$CONF" "$DIR/espd.conf"
  chmod 644 "$DIR/espd.conf"
  log "wrote espd.conf"
fi

# ---------- 悬浮窗 APK：没装就装，冷启动 pm 未就绪 → 5 次重试 ----------
if ! pm list packages 2>/dev/null | grep -q "package:$OVERLAY"; then
  i=0
  while [ $i -lt 5 ]; do
    log "install overlay try=$i"
    if pm install -r -g "$MOD/esp/esp.apk" >>"$LOG" 2>&1; then break; fi
    i=$((i+1))
    sleep 10
  done
fi

# 悬浮窗服务保活（游戏在跑时才需要，避免空转拉起）
svc_keep() {
  if pidof "$GAME" >/dev/null 2>&1 && ! pidof "$OVERLAY" >/dev/null 2>&1; then
    am start-foreground-service -n "$SVC" >/dev/null 2>&1
    log "overlay down -> start service"
  fi
}

# ---------- 主循环：espd 退出就带退避重启 ----------
fails=0
last=0
while true; do
  svc_keep
  rotate

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
