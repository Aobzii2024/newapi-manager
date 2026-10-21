#!/usr/bin/env bash
# NewAPI + Hong Kong host read-only health check.
# Runs entirely through ~/workspace/services/hk_ssh.sh and changes nothing
# on the server. Output lines start with [OK], [WARN] or [ANOMALY].
# Final line: RESULT: OK | RESULT: ANOMALY (n)
# Thresholds: disk >=75% WARN, >=85% ANOMALY. Mem available <500MB WARN,
# <250MB ANOMALY. Cert <=30d WARN, <=14d ANOMALY. Swap >50% used WARN.
set -uo pipefail

REMOTE=$(cat <<'EOS'
DISK_WARN=75; DISK_ALARM=85; CERT_WARN=30; CERT_ALARM=14
echo "== host (server clock is UTC, Beijing = UTC+8) =="
hostname; date "+%F %T %Z"; uptime
echo "== services =="
for s in newapi nginx docker tailscaled; do
  st=$(systemctl is-active "$s" 2>/dev/null || echo unknown)
  if [ "$st" = "active" ]; then echo "[OK] $s active"; else echo "[ANOMALY] $s = $st"; fi
done
echo "== resources =="
df -h / | tail -n 1
disk_pct=$(df / | tail -n 1 | awk '{print $5}' | tr -d '%')
if [ "$disk_pct" -ge "$DISK_ALARM" ]; then echo "[ANOMALY] disk ${disk_pct}%"
elif [ "$disk_pct" -ge "$DISK_WARN" ]; then echo "[WARN] disk ${disk_pct}%"
else echo "[OK] disk ${disk_pct}%"; fi
free -m
avail=$(free -m | awk '/^Mem:/{print $7}')
if [ "$avail" -lt 250 ]; then echo "[ANOMALY] mem available ${avail}MB"
elif [ "$avail" -lt 500 ]; then echo "[WARN] mem available ${avail}MB"
else echo "[OK] mem available ${avail}MB"; fi
swap_pct=$(free -m | awk '/^Swap:/{if($2>0) printf "%d", $3*100/$2; else print 0}')
if [ "$swap_pct" -gt 50 ]; then echo "[WARN] swap used ${swap_pct}%"; else echo "[OK] swap used ${swap_pct}%"; fi
echo "== endpoints =="
code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://127.0.0.1:3000/api/status)
if [ "$code" = "200" ]; then echo "[OK] local :3000/api/status 200"; else echo "[ANOMALY] local :3000/api/status = $code"; fi
code2=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 --resolve ai.aobzii.cn:443:127.0.0.1 https://ai.aobzii.cn/api/status)
if [ "$code2" = "200" ]; then echo "[OK] nginx https ai.aobzii.cn/api/status 200"; else echo "[ANOMALY] nginx https ai.aobzii.cn/api/status = $code2"; fi
ss -tlnp 2>/dev/null | grep -E ':3000|:443 ' | awk '{print $1, $4}'
echo "== cert ai.aobzii.cn =="
end=$(openssl x509 -enddate -noout -in /etc/letsencrypt/live/ai.aobzii.cn/fullchain.pem 2>/dev/null | cut -d= -f2)
if [ -n "$end" ]; then
  days=$(( ( $(date -d "$end" +%s) - $(date +%s) ) / 86400 ))
  echo "cert expires: $end (${days}d left)"
  if [ "$days" -le "$CERT_ALARM" ]; then echo "[ANOMALY] cert ${days}d left"
  elif [ "$days" -le "$CERT_WARN" ]; then echo "[WARN] cert ${days}d left"
  else echo "[OK] cert ${days}d left"; fi
else echo "[ANOMALY] cannot read ai.aobzii.cn cert"; fi
echo "== database and last 24h =="
python3 - <<'PYEOF'
import sqlite3, time
try:
    con = sqlite3.connect("file:/home/newapi/one-api.db?mode=ro", uri=True)
    qc = con.execute("PRAGMA quick_check").fetchone()[0]
    print(("[OK] db quick_check ok" if qc == "ok" else "[ANOMALY] db quick_check = %s" % qc))
    for t in ["users", "tokens", "channels"]:
        print("%s: %d" % (t, con.execute("SELECT COUNT(*) FROM %s" % t).fetchone()[0]))
    off = [r for r in con.execute("SELECT id, name, status FROM channels WHERE status != 1")]
    if off: print("[WARN] channels not enabled: %s" % off)
    else: print("[OK] all channels status=1")
    since = int(time.time()) - 86400
    n, q = con.execute("SELECT COUNT(*), COALESCE(SUM(quota),0) FROM logs WHERE type=2 AND created_at>=?", (since,)).fetchone()
    print("consume logs 24h: %d calls, %d quota = $%.2f" % (n, q, q / 500000.0))
    zero = con.execute("SELECT COUNT(*) FROM logs WHERE type=2 AND created_at>=? AND completion_tokens=0", (since,)).fetchone()[0]
    print("zero-completion consume logs 24h: %d" % zero)
except Exception as e:
    print("[ANOMALY] db check failed: %s" % e)
PYEOF
echo "== newapi errors, journal last 3h =="
errs=$(journalctl -u newapi --since "3 hours ago" -p err --no-pager -q 2>/dev/null | wc -l)
echo "error-level journal lines (3h): $errs"
if [ "$errs" -gt 0 ]; then journalctl -u newapi --since "3 hours ago" -p err --no-pager -q 2>/dev/null | tail -n 5; fi
EOS
)

OUT=$(~/workspace/services/hk_ssh.sh "$REMOTE" 2>&1)
echo "$OUT"
N=$(printf '%s\n' "$OUT" | grep -c '^\[ANOMALY\]' || true)
W=$(printf '%s\n' "$OUT" | grep -c '^\[WARN\]' || true)
echo "warnings: $W"
if [ "$N" -gt 0 ]; then echo "RESULT: ANOMALY ($N)"; exit 1; fi
echo "RESULT: OK"
