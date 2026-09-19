---
name: dh-tools
description: Which harness tool to use for what in this repo (read/grep/edit/bash/jobs/images) and the rules that stop wandering. Load first on any task.
whenToUse: At the start of every task in this repository, before the first tool call.
---

# Tool rules for this repository

Decide the tool in one step; do not reason about alternatives.

| you want to | use | not |
|---|---|---|
| see a file or a line range | `read` (with `offset`/`limit`) | `bash sed -n` / `cat` |
| find text in files | `grep` (ripgrep regex, `include: "*.gd"`) | `bash grep -rn` |
| find files by name | `glob` | `bash find` / `ls -R` |
| change a file | `edit` (exact `old_string`, must be unique) — the file must have been `read` first in this session or the edit fails with `FS_NOT_OBSERVED` | `bash sed -i` / heredocs |
| create a file | `write` | `bash cat > file` |
| run a command | `bash` with `workdir: /home/pc/Documents/xnw/rkn` — every call is a fresh shell, `cd` does not persist | chaining `cd ... &&` |
| a command longer than ~60 s (full test suite, export, probe, kiek) | `bash` with `run_in_background: true`, then ONE `job_output` with `wait: true, timeout_ms: 240000` | polling `job_output` without `wait`, `sleep` loops, re-running the command |
| look at a PNG | `read_image` on the path | installing image libraries, base64, ImageMagick |
| give the user a file | `present` after writing it | only mentioning the path |
| plan a multi-step task | `todo_write` once at the start, update when a step is done | re-planning every step |

Never use: `subagent`, `subagent_fork`, `workflow`, `ralph`, `web_search`,
`web_fetch`, `create_goal` — this project is fully local and documented; they
only cost time. Ask with `ask_user_question` only when two readings of the task
lead to different code; otherwise pick the reading the spec supports and say so
in the final answer.

# Budget that keeps you productive

- At most **8 read/grep calls before your first edit** when the task names the
  files. AGENTS.md already tells you where things are; use the line numbers in
  the `dh-spec` skill instead of reading a 2000-line spec end to end.
- Do NOT read `ANALYSIS.md`, `HANDOFF.md`, `IDEAS.md`, `.fanout/ledger.md` or
  other games unless the task is about them. Everything a game change needs is
  in `games/<id>/` + its spec section + AGENTS.md §4–5.
- Decide in ≤ 2 paragraphs of thought, then act. If you notice you are weighing
  the same two options twice, take the first and verify with a test.
- Every shell command gets a `description`; every finished step gets one line
  in your answer. Report test counts literally (`N goed, M fout`).

# The one workflow

1. Load the matching skill: `dh-plan` (a task from PLAN.md), `dh-gdscript`
   (before editing `.gd`), `dh-tests` (run/read tests), `dh-minigame` (change
   a game), `dh-screenshot` (show a picture), `dh-export` (web build/probe),
   `dh-commit` (the gate and the commit).
2. Read only the files the skill names → edit → `DH_TEST_FILTER=<id>
   tools/test.sh` → fix → full `tools/test.sh` once (`0 fout`) → PLAN.md
   bookkeeping → commit by path → report. Never commit or push on red.
