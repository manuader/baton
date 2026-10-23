#!/bin/bash
# Tests for skills/baton/scripts/lock.sh. Run: bash tests/test-lock.sh
set -u
LOCK_SH="$(cd "$(dirname "$0")/.." && pwd)/skills/baton/scripts/lock.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
L="$T/run/LOCK"
pass=0; fail=0

check() {  # check <description> <expected exit> <command...>
  local desc="$1" want="$2"; shift 2
  "$@" >"$T/out" 2>&1; local got=$?
  if [[ $got == "$want" ]]; then pass=$((pass + 1)); echo "  ✓ $desc"
  else fail=$((fail + 1)); echo "  ✗ $desc (exit $got, wanted $want)"; sed 's/^/      /' "$T/out"; fi
}
has() {  # has <description> <pattern>
  if grep -q "$2" "$L"; then pass=$((pass + 1)); echo "  ✓ $1"
  else fail=$((fail + 1)); echo "  ✗ $1 (no '$2' in LOCK)"; sed 's/^/      /' "$L"; fi
}
age_heartbeat() { sed -i.bak 's/^last_heartbeat: .*/last_heartbeat: 2020-01-01 00:00:00 +0000/' "$L" && rm -f "$L.bak"; }

echo "lock.sh"
check "create makes a FREE lock"                 0 bash "$LOCK_SH" create "$L"
check "status of a FREE lock exits 0"            0 bash "$LOCK_SH" status "$L"
check "A takes it"                               0 bash "$LOCK_SH" take "$L" "relay 1" local_a
has   "the link is built from the session id"    "^link: claude://claude.ai/epitaxy/local_a$"
check "status of a live lock exits 1"            1 bash "$LOCK_SH" status "$L"
check "B can't take a live lock"                 1 bash "$LOCK_SH" take "$L" "relay 2" local_b
check "B can't beat A's lock"                    3 bash "$LOCK_SH" beat "$L" local_b
check "A beats its own lock"                     0 bash "$LOCK_SH" beat "$L" local_a
age_heartbeat
check "status of a stale lock exits 2"           2 bash "$LOCK_SH" status "$L"
check "B can't take a stale lock unverified"     2 bash "$LOCK_SH" take "$L" "relay 2" local_b
check "B takes a stale lock with --stale"        0 bash "$LOCK_SH" take "$L" "relay 2" local_b --stale
has   "the takeover is recorded"                 "^taken_over_from: relay 1 (local_a)$"
check "A can't release B's lock"                 3 bash "$LOCK_SH" release "$L" local_a
check "B releases"                               0 bash "$LOCK_SH" release "$L" local_b
has   "the release records the last holder"      "^last_holder: relay 2$"
check "beat-loop exits 0 once the lock is FREE"  0 bash "$LOCK_SH" beat-loop "$L" local_b 1
bash "$LOCK_SH" take "$L" "relay 3" local_c >/dev/null
sed -i.bak 's/^session: .*/session: local_z/' "$L" && rm -f "$L.bak"
check "beat-loop exits 3 when another session holds the lock" 3 bash "$LOCK_SH" beat-loop "$L" local_c 1
mkdir "$L.mutex"; touch -t 202001010000 "$L.mutex"
check "an orphaned mutex is recovered"           0 bash "$LOCK_SH" beat "$L" local_z
[[ -d "$L.mutex" ]] && { fail=$((fail + 1)); echo "  ✗ the mutex was left behind"; } || { pass=$((pass + 1)); echo "  ✓ no mutex left behind"; }

echo "lock.sh: $pass passed, $fail failed"
[[ $fail == 0 ]]
