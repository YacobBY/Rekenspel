---
name: dh-plan
description: How to take the next task from PLAN.md and finish it the way the owner wants (which task, what to read, staying inside the task, what "done" means) — the owner's flow of 2026-09-19 for the local model.
whenToUse: Any task that says "volgende taak", "PLAN.md", a task id like B2/N8/K1, or "ga door met het plan".
---

# Which task

1. Read PLAN.md §7 (`grep -n "^## 7" PLAN.md`, then the newest dated entries).
   The newest entry with **Opdracht** in it is the owner's standing order and
   beats everything older, including §5.1.
2. Open tasks are the `- [ ]` blocks in §4 (`grep -n "^- \[ \]" -B1 PLAN.md`).
   Take them in the order §7 names; otherwise batch order, top to bottom, and
   only a task whose `hangt af van:` ids are all `[x]`.
3. Standing order of 2026-09-19: work on `main` in this checkout, no worktree
   (this replaces §5.1 step 1 and step 8). One task per commit (`dh-commit`).

# What to read for one task (≤ 8 reads before the first edit)

- The task block in §4: `stappen`, `acceptatie`, and its file set
  (`Bestandssets` line under the batch heading). The file set is the contract.
- The §3 design section the task names (grep its heading; read only that).
- The files in the set, whole, once. A test file: its helpers first.

# While building

- Stay inside the file set. Needing another file means the batch plan is
  wrong: stop, say which file and why, ask (`ask_user_question`) — do not edit it.
- Numbers, names and sentences in the plan are decisions, not suggestions
  (the 0.34 bar ceiling, `MAX_PER_KAMER`, the child sentences). Changing one
  is a deviation: ask first, or name it in the report and the commit message.
  Never silently.
- Things that stay as they are: `core/sommen.gd` byte-identical;
  `ui/spelbalk.gd` (the ⬅ Terug row outside the frame) stays; the "Nu" chip and
  the way back are NOT in the frame any more (§7, 2026-09-18 evening), so
  B2/B3/B6 are smaller than §3.1 describes.
- The parked branch `qwen/rekenbalk-b2-b3-b4` may be a source for single
  pieces (`git show qwen/rekenbalk-b2-b3-b4:<path>`), never merged whole.
- Every new behaviour gets a test; every changed child sentence is updated
  word for word in the game test in the same commit (§5.3).

# Done means all of this

1. The `acceptatie` line of the task holds, literally (the filter it names is green).
2. Full `tools/test.sh`: `0 fout`, exit 0 (`dh-tests`). A task that is only
   green filtered is not done.
3. Visible change: export + `kiek.js` picture on tablet and phone (`dh-screenshot`), shown.
4. PLAN.md: `[x]`, §7 line, batch table — in the same commit (`dh-commit`).
5. Report: what changed, `N goed, 0 fout`, pictures, what you did NOT do, every assumption.
