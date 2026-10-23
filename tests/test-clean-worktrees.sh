#!/bin/bash
# Tests for skills/baton/scripts/clean-worktrees.sh against a throwaway repo and remote.
# Run: bash tests/test-clean-worktrees.sh
set -u
CLEAN_SH="$(cd "$(dirname "$0")/.." && pwd)/skills/baton/scripts/clean-worktrees.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
R="$T/repo"; W="$R/.claude/worktrees"
g() { git -C "$1" -c user.name=test -c user.email=test@example.com "${@:2}"; }
pass=0; fail=0
expect() {  # expect <description> <condition...>
  if "${@:2}"; then pass=$((pass + 1)); echo "  ✓ $1"; else fail=$((fail + 1)); echo "  ✗ $1"; fi
}

git init -q --bare "$T/remote.git"
git init -q -b work "$R"; g "$R" remote add origin "$T/remote.git"
echo a > "$R/a"; g "$R" add a; g "$R" commit -qm base; g "$R" push -q origin work
for t in merged dirty unpushed; do g "$R" worktree add -q -b "r1/$t" "$W/r1-$t" work; done
g "$R" worktree add -q -b keepme "$W/keepme" work
echo x > "$W/r1-merged/x"; g "$W/r1-merged" add x; g "$W/r1-merged" commit -qm x; g "$W/r1-merged" push -q origin r1/merged
g "$R" merge -q r1/merged
echo y > "$W/r1-dirty/y"
echo z > "$W/r1-unpushed/z"; g "$W/r1-unpushed" add z; g "$W/r1-unpushed" commit -qm z

echo "clean-worktrees.sh"
KEEP=keepme bash "$CLEAN_SH" "$R" > "$T/dry"
expect "the dry run removes nothing"              test -d "$W/r1-merged"
expect "the dry run lists the merged worktree"    grep -q "would remove r1-merged" "$T/dry"
expect "the dry run would push the unpushed one"  grep -q "would push it to origin/r1/unpushed" "$T/dry"

KEEP=keepme bash "$CLEAN_SH" "$R" --apply > "$T/apply"
expect "the merged worktree is removed"           test ! -d "$W/r1-merged"
expect "the dirty worktree is kept"               test -d "$W/r1-dirty"
expect "the protected worktree is kept"           test -d "$W/keepme"
expect "the unpushed worktree is removed"         test ! -d "$W/r1-unpushed"
expect "…but only after its branch was pushed"    git -C "$T/remote.git" rev-parse -q --verify r1/unpushed >/dev/null
expect "the merged branch is deleted locally"     test -z "$(git -C "$R" branch --list r1/merged)"

echo "clean-worktrees.sh: $pass passed, $fail failed"
[[ $fail == 0 ]]
