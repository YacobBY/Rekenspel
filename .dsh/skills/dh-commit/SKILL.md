---
name: dh-commit
description: The gate before a commit in this repo and the commit itself (one task per commit, files by path, PLAN.md bookkeeping, message style), and push only when asked and only green.
whenToUse: The user says commit, push, "zet op github", or you have finished a PLAN.md task.
---

# The gate — every line must be true, or you do not commit

1. Full suite after your LAST edit: `tools/test.sh` → `0 fout` and exit 0
   (`dh-tests`). Red tests are never "known rest points" to mention in the
   message: a red suite means no commit and no push; report the red tests instead.
2. `git diff --stat HEAD -- godot/dierenhotel/core/sommen.gd` prints nothing
   (the maths core is frozen, byte-identical).
3. `git status --short`: every modified file belongs to THIS task's file set
   (PLAN.md task block, or the request). Anything else stays out of the commit —
   another agent works in this checkout; its files (`ANALYSIS.md`, `*.bak`,
   `.dsh/`, `.godot/`, `build/web/`) are never yours to add.
4. A new `.gd` file has its `.uid` next to it (run `tools/import.sh` if not),
   and both go in.
5. PLAN.md is updated in the same commit when the task comes from the plan:
   `- [ ]` → `- [x]` on the task, one line in §7 (`- <date> — <task id>: what
   changed, N goed, 0 fout, what was left out`), and the batch table count.

# The commit — by path, never `git add -A`, `-u` or `.`

```bash
git add godot/dierenhotel/games/sleutels/spel.gd godot/dierenhotel/games/sleutels/test_sleutels.gd PLAN.md
git commit -F - <<'MSG'
<Area>: <what changed, one line, ≤ 72 chars> (PLAN.md <task id>)

<2–6 lines: what the child now sees, which rule or spec section it follows,
"470 goed, 0 fout", and every deviation from the plan, named.>

Ontwikkeld door <model name>.
MSG
```

One task = one commit. Two tasks that share a file are two commits in order.
Area names as in `git log --oneline -8`: `Sleutels:`, `Rekenbalk:`, `Hotel:`,
`World:`, `Tools:`, `Docs:`. Spec changes go in the same commit as the code.

# Push — only when the user said push

`git push origin main`, then report the short hash and `git status -sb`. CI:
`gh run list --branch main --limit 2` after ~4 minutes; `test` and `pages`
must both say `success`. If CI is red, say so at once, do not push a fix on
top without the suite green locally.
