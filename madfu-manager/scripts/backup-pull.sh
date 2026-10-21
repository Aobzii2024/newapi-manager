#!/usr/bin/env bash
# Pull a consistent NewAPI database backup to this sandbox and keep at
# most 3 days of pulled copies.
#
# Method (learned 2026-10-17, do not shortcut): the live database is WAL
# mode, so never copy one-api.db directly while the service runs. Take
# the snapshot on the server with the SQLite backup API, then scp that
# snapshot file. The pulled database contains channel keys and password
# hashes, so the destination stays mode 700 and files mode 600, and the
# copies are never uploaded, shared or committed anywhere.
set -uo pipefail

DEST="$HOME/workspace/newapi-backups"
STAMP=$(TZ=Asia/Shanghai date +%Y%m%d-%H%M%S)
REMOTE_PATH="/root/newapi-backup-tmp/one-api.${STAMP}.db"
LOCAL_PATH="$DEST/one-api.${STAMP}.db"
SCP_OPTS=(-o BatchMode=yes -o ConnectTimeout=25
  -o UserKnownHostsFile=/home/hatch/.ssh/known_hosts
  -o ProxyCommand="python3 /home/hatch/workspace/services/proxy_connect.py %h %p"
  -i /home/hatch/.ssh/id_ed25519)

mkdir -p "$DEST" && chmod 700 "$DEST"

echo "== snapshot on server via SQLite backup API =="
~/workspace/services/hk_ssh.sh "mkdir -p /root/newapi-backup-tmp && python3 -c \"
import sqlite3
src = sqlite3.connect('file:/home/newapi/one-api.db?mode=ro', uri=True)
dst = sqlite3.connect('${REMOTE_PATH}')
with dst: src.backup(dst)
dst.close(); src.close()
print('snapshot done')
\" && sha256sum ${REMOTE_PATH} && ls -lh ${REMOTE_PATH}" || { echo "FAILED at snapshot"; exit 1; }

echo "== pull =="
scp "${SCP_OPTS[@]}" "root@39.109.62.190:${REMOTE_PATH}" "$LOCAL_PATH" || { echo "FAILED at scp"; exit 1; }
chmod 600 "$LOCAL_PATH"

echo "== verify pulled copy =="
LOCAL_HASH=$(sha256sum "$LOCAL_PATH" | awk '{print $1}')
echo "local sha256: $LOCAL_HASH"
python3 -c "
import sqlite3
con = sqlite3.connect('file:${LOCAL_PATH}?mode=ro', uri=True)
print('quick_check:', con.execute('PRAGMA quick_check').fetchone()[0])
print('users:', con.execute('SELECT COUNT(*) FROM users').fetchone()[0])
" || { echo "FAILED at verify"; exit 1; }
ls -lh "$LOCAL_PATH"
rm -f "$LOCAL_PATH-shm" "$LOCAL_PATH-wal"

echo "== clean remote tmp and prune local copies older than 3 days =="
~/workspace/services/hk_ssh.sh "rm -f ${REMOTE_PATH}" >/dev/null 2>&1 || true
find "$DEST" -name 'one-api.*.db*' -mmin +4320 -print -delete
echo "kept copies:"
ls -lh "$DEST"
echo "RESULT: backup pulled to $LOCAL_PATH"
