#!/bin/bash
# Installs Baton's skills and agent into Claude Code.
#
#   ./install.sh               symlink every skill and agent into ~/.claude (updates follow `git pull`)
#   ./install.sh --copy        copy instead of symlinking
#   ./install.sh --replace     back up conflicting skills/agents first, then install over them
#   ./install.sh --uninstall   remove only the links that point into this repo
#
# CLAUDE_HOME overrides ~/.claude. Existing skills or agents with the same name are never overwritten silently:
# without --replace they are skipped and reported.

set -eu
REPO="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
MODE=link; REPLACE=0; UNINSTALL=0
for arg in "$@"; do
  case "$arg" in
    --copy) MODE=copy ;;
    --replace) REPLACE=1 ;;
    --uninstall) UNINSTALL=1 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg"; sed -n '2,10p' "$0"; exit 64 ;;
  esac
done

BACKUP="$CLAUDE_HOME/.baton-backup-$(date +%Y%m%d-%H%M%S)"
installed=0; skipped=0; backed_up=0

points_here() { [[ -L "$1" && "$(readlink "$1")" == "$REPO/"* ]]; }

place() {
  local src="$1" dst="$2" name
  name=$(basename "$dst")
  if [[ $UNINSTALL == 1 ]]; then
    if points_here "$dst"; then rm "$dst"; echo "  ✓ removed $dst"; fi
    return
  fi
  if points_here "$dst"; then echo "  = $name already linked"; installed=$((installed + 1)); return; fi
  if [[ -e "$dst" || -L "$dst" ]]; then
    if [[ $REPLACE == 0 ]]; then
      echo "  ! skipped $name: $dst already exists (rerun with --replace to back it up and install Baton's)"
      skipped=$((skipped + 1)); return
    fi
    mkdir -p "$BACKUP/$(basename "$(dirname "$dst")")"
    mv "$dst" "$BACKUP/$(basename "$(dirname "$dst")")/"
    echo "  ↺ backed up $name to $BACKUP"; backed_up=$((backed_up + 1))
  fi
  if [[ $MODE == link ]]; then ln -s "$src" "$dst"; else cp -R "$src" "$dst"; fi
  echo "  ✓ $name"; installed=$((installed + 1))
}

mkdir -p "$CLAUDE_HOME/skills" "$CLAUDE_HOME/agents"
chmod +x "$REPO"/skills/*/scripts/*.sh "$REPO"/tests/*.sh 2>/dev/null || true

echo "Skills → $CLAUDE_HOME/skills"
for dir in "$REPO"/skills/*/; do
  dir="${dir%/}"; place "$dir" "$CLAUDE_HOME/skills/$(basename "$dir")"
done
echo "Agents → $CLAUDE_HOME/agents"
for file in "$REPO"/agents/*.md; do
  place "$file" "$CLAUDE_HOME/agents/$(basename "$file")"
done

if [[ $UNINSTALL == 1 ]]; then echo "Done."; exit 0; fi
echo
echo "Installed: $installed · skipped: $skipped · backed up: $backed_up"
[[ $skipped -gt 0 ]] && echo "Skipped items keep your existing version; Baton works with it if it's compatible."
echo "Restart Claude Code, open a project and say: \"Set up Baton for this project\"."
