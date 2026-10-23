# Baton

**Autonomous relay development for Claude Code.** Your project keeps moving while you sleep: a scheduled routine
wakes a fresh agent every hour. The one that takes the lock works the plan until its context fills up, then closes
cleanly, documents everything, and passes the baton. You talk to the relays through an inbox file, and whatever only
you can do lands on a short to-do list instead of blocking the work.

Baton is a methodology packaged as Claude Code skills. It was distilled from 90+ relays building and shipping an iOS
game, and every rule in it exists because breaking it once cost hours.

## How it works

```text
  routine (every hour)
        │
        ▼
  gate: is the LOCK free, and is there quota left? ── no ──▶ "🔒 held by relay 41 → [link to that chat]", end
        │ yes
        ▼
  relay N takes the LOCK (heartbeat every 10 min)
        │  reads OWNER.md → newest handoff → general → journal
        │  works the plan: waves of subagents, each in its own git worktree, one owner per file
        │  logs every task boundary in the journal and STATUS.md
        ▼
  at ~300k tokens of context
        │  waits for every subagent → session doc + handoff + general → push → releases the LOCK → ends
        ▼
  the next hourly firing takes the baton with a fresh context
```

The run lives in `.claude/avo/<date>-<slug>/`, outside git:

| File | What it holds |
|---|---|
| `LOCK` | who holds the baton, and the last heartbeat |
| `OWNER.md` | your inbox: requests `[ ]` → `[x]`, standing rules, your answers |
| `OWNER-TODO.md` | only what you can do (sign, pay, approve), each with the exact command |
| `journal.md` | charter, current state, discarded directions, one block per relay |
| `STATUS.md` | a five-line snapshot of where things stand |

The rules that make it work:

- **Nothing is cut while work is in flight.** No clearing or stopping a session with subagents running, ever.
- **Only the LOCK holder works.** A live heartbeat means hands off.
- **The closing relay doesn't launch the next one.** The hour is the clock.
- **Your requests go to `OWNER.md`.** A chat session with you plans and loads them; it doesn't implement.
- **Nothing external without your yes in chat.**
- **One heavy thing at a time** on the machine.

## What's in the box

| Path | What it is |
|---|---|
| `skills/baton/` | The methodology: relay protocol, dispatch, owner channel, setup, traps, templates, `lock.sh`, `clean-worktrees.sh` |
| `skills/avo-harness/` | The long-horizon loop: oracle → hypothesis → variants → evidence → commit/revert, with a journal that outlives the context |
| `skills/handoff-system/`, `skills/writing-session-handoff/`, `skills/writing-general-handoff/` | The three-document handoff system every relay closes with |
| `agents/avo-supervisor.md` | A context-free subagent that reads the journal and says CONTINUE, PIVOT, LEVEL UP or STOP AND ASK |
| `tests/` | Tests for the scripts (`bash tests/run.sh`) |
| `install.sh` | Links everything into `~/.claude` |

## Requirements

- **Claude Code, desktop app (Code tab).** Baton relies on its scheduled tasks and session tools: `get_session`,
  `set_session_title`, `get_usage`, `SendMessage` and `PushNotification`. Without scheduled tasks you can still run
  relays by typing "continue" in a new session.
- **git, bash, and macOS or Linux.**
- **Optional:** the [superpowers](https://github.com/obra/superpowers) plugin, which Baton uses for planning
  (`brainstorming`, `writing-plans`) and dispatch (`subagent-driven-development`).

## Install

```bash
git clone https://github.com/manuader/baton.git
cd baton
./install.sh
```

Then restart Claude Code.

- **Updating:** `install.sh` symlinks by default, so `git pull` updates it. Use `--copy` to copy instead.
- **Existing skills:** if you already have a skill or agent with the same name, it is skipped, never overwritten.
  Use `./install.sh --replace` to back it up into `~/.claude/.baton-backup-<timestamp>/` and install Baton's.
- **Removing:** `./install.sh --uninstall` removes only the links that point into this repo.

Optionally, add this to `~/.claude/CLAUDE.md`, so long tasks and relays pick the skills up without being asked:

```markdown
## Long-horizon work
Before any task that won't be solved in one pass (debugging after a failed attempt, performance work, a large
refactor, a migration, anything that spans sessions), invoke `avo-harness` and follow its loop. When a repo has a
Baton run (`.claude/avo/*/LOCK`), or I ask for autonomous development, invoke `baton`.
```

## Quick start

In your project, in Claude Code:

> Set up Baton for this project. The plan is `docs/ROADMAP.md`.

The setup session:

1. asks you a handful of questions: the work branch, protected areas, what counts as external, your approval
   gates, and how heavy your builds are;
2. turns the plan into tasks with checkable "Done when" criteria;
3. creates the run folder and its files;
4. shows you the hourly routine and creates it **after you say yes**.

From then on:

- **Every hour,** a relay takes the baton or, if one is already working, leaves a one-line message with the link to
  the working chat.
- **To ask for something,** open any chat in the project and say it. That session writes it into `OWNER.md` and
  pings the active relay.
- **Once in a while,** check `OWNER-TODO.md`. That's where the relays leave what only you can do, each item with the
  exact command or link.
- **When the plan is done,** the last relay sends you a report and disables the routine, if you allowed that at
  setup.

## Verify

```bash
bash tests/run.sh
```

## License

MIT — see `LICENSE`.
