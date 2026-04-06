---
name: yak
description: >
  Stacked PR workflow. Use when the user wants to create stacked branches,
  insert a yak branch beneath current work, sync a stack, or create a PR.
  TRIGGER when: user says "yak", "stack", "sync", "stack-pr", or talks about stacking PRs/branches.
argument-hint: <yak|stack|sync|stack-pr|tree|done|continue|abort|install> [branch-name|title]
allowed-tools: Bash(git *) Bash(gh *) Bash(${CLAUDE_SKILL_DIR}/install.sh *) Bash(chmod *)
---

# yak — stacked PR workflow

Interpret `$ARGUMENTS` to decide which command to run.

## Commands

```bash
git yak <name>           # insert a branch beneath current work
git yak --done           # finish the yak, return to your work branch
git yak --continue       # resume after resolving a rebase conflict
git yak --abort          # cancel and restore everything

git stack <name>         # create a new branch on top of the current one

git sync                 # rebase the stack, auto-detect and remove merged branches
git sync <branch>        # rebase after a specific branch was merged
git sync --continue      # resume after resolving a rebase conflict
git sync --abort         # cancel and restore everything

git stack-pr <title>     # push and create a PR for the bottom branch (requires gh)

git stack-tree           # print the branch stack
```

## Examples

- `/yak fix-auth` → `git yak fix-auth`
- `/yak stack part-2` → `git stack part-2`
- `/yak sync` → `git sync`
- `/yak sync part-1` → `git sync part-1`
- `/yak stack-pr "Add feature"` → `git stack-pr "Add feature"`
- `/yak tree` → `git stack-tree`
- `/yak done` → `git yak --done`
- `/yak continue` → check `git config yak.in-progress` or `git config sync.in-progress` to decide `git yak --continue` or `git sync --continue`
- `/yak abort` → same check, then `git yak --abort` or `git sync --abort`
- `/yak install` → `${CLAUDE_SKILL_DIR}/install.sh`
- `/yak` with no args → run `git stack-tree` and report status

## Notes

- Branch relationships are stored in `branch.<name>.stack-parent` git config.
- `stack-pr` finds the bottom branch automatically — run it from any branch in the stack.
- Rerere is enabled automatically so repeated conflicts resolve themselves.
- Always use `--force-with-lease` (never `--force`) when pushing.
- When a rebase conflicts, guide the user to resolve, then `--continue`.
