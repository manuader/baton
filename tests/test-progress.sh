#!/bin/bash
# Tests for skills/baton/scripts/progress.sh. Run: bash tests/test-progress.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROGRESS_SH="$ROOT/skills/baton/scripts/progress.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
pass=0; fail=0
expect() {  # expect <description> <condition...>
  if "${@:2}"; then pass=$((pass + 1)); echo "  ✓ $1"; else fail=$((fail + 1)); echo "  ✗ $1"; fi
}

cat > "$T/tasks.md" <<'EOF'
# Demo — task board

## Statuses

| Mark | Meaning | Counts as |
|---|---|---|
| ✅ | done | done |
| ⏳ | ready | open |

## Progress

Progress: stale text that must be replaced

## Tasks

### Phase A

| ID | Task | Status | Deps | Owns | Done when | Notes |
|---|---|---|---|---|---|---|
| A1 | first | ✅ | — | a.ts | `npm test a` | 1a2b3c4 |
| A2 | second | ✅ | A1 | b.ts | `npm test b` | 5d6e7f8 |
| A3 | third | 🔄 | A1 | c.ts | `npm test c` | agent x |

### Phase B

| ID | Task | Status | Deps | Owns | Done when | Notes |
|---|---|---|---|---|---|---|
| B1 | fourth | ⏳ | — | d.ts | `npm test d` | |
| B2 | fifth | ⛔ | B1 | e.ts | `npm test e` | |
| B3 | sixth | 🔒 | — | f.ts | owner approves | |
| B4 | seventh | ⏭️ | — | g.ts | — | dropped 2026-10-20 |
| B5 | eighth | ⏳ | — | h.ts | `npm test h` | |
EOF

echo "progress.sh"
line=$(bash "$PROGRESS_SH" "$T/tasks.md" --line)
expect "counts done over the total, dropped left out"   grep -q "^Progress: 2/7 done (28.6 %)" <<<"$line"
expect "counts each open status"                        grep -q "🔄 1 in flight · 🟢 0 coded · 🔧 0 fixing · ⏳ 2 ready · ⛔ 1 blocked · 🔒 1 owner · ⏭️ 1 dropped" <<<"$line"
expect "the legend table is not counted as tasks"       test "$(grep -o '2/7' <<<"$line")" = "2/7"
full=$(bash "$PROGRESS_SH" "$T/tasks.md")
expect "reports per phase"                              grep -q "^- Phase A: 2/3 (67 %)" <<<"$full"
expect "dropped tasks leave the phase total"            grep -q "^- Phase B: 0/4 (0 %)" <<<"$full"
expect "lists the next ready tasks"                     grep -q "^Next ready: B1, B5" <<<"$full"
bash "$PROGRESS_SH" "$T/tasks.md" --update >/dev/null
expect "--update replaces the Progress section"         grep -q "^Progress: 2/7 done" "$T/tasks.md"
expect "--update drops the stale text"                  bash -c "! grep -q 'stale text' '$T/tasks.md'"
expect "--update keeps the tasks intact"                test "$(grep -c '^| [AB][0-9]' "$T/tasks.md")" = "8"
bash "$PROGRESS_SH" "$T/tasks.md" --update >/dev/null
expect "--update is idempotent"                         test "$(grep -c '^Progress:' "$T/tasks.md")" = "1"
tmpl=$(bash "$PROGRESS_SH" "$ROOT/skills/baton/assets/tasks.md" --line)
expect "the shipped template parses"                    grep -q "^Progress: 0/3 done" <<<"$tmpl"

echo "progress.sh: $pass passed, $fail failed"
[[ $fail == 0 ]]
