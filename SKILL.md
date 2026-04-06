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

You manage a stacked-branch workflow using these operations: **yak**, **stack**, **sync**, **stack-pr**, and **tree**.
Branch relationships are tracked in git config as `branch.<name>.stack-parent`.

Interpret `$ARGUMENTS` to decide which operation to run. Examples:
- `/yak fix-auth` → yak (insert yak branch called "fix-auth")
- `/yak stack part-2` → stack (create stacked branch "part-2")
- `/yak sync` → sync (rebase the stack, auto-detect merged branches)
- `/yak sync part-1` → sync (part-1 was merged, rebase the rest)
- `/yak stack-pr "Add feature"` → create a PR for the bottom branch
- `/yak tree` → show the branch stack
- `/yak done` → finish the current yak
- `/yak continue` → resume after conflict resolution
- `/yak abort` → cancel and restore state
- `/yak install` → install commands as git subcommands
- `/yak` with no args → show status (current branch, stack, any in-progress operation)

## Setup

Before any operation, ensure:
1. Detect the default branch: `git config init.defaultBranch` or fall back to `main`. Call this `MAIN`.
2. Enable rerere if not already on:
   ```
   git config rerere.enabled true
   git config rerere.autoupdate true
   ```

## Operation: yak <name>

Insert a branch beneath the current work so you can do something first.

### Preconditions
- Fail if `git config yak.in-progress` is `true` (a yak is already active).
- Fail if a branch named `<name>` already exists.
- Fail if HEAD is detached.

### Steps

1. If there are uncommitted changes, `git stash` them. Remember whether you stashed.
2. Note the current branch as `RETURN_TO`.
3. `git fetch origin`
4. **If on MAIN:**
   - Count commits ahead of `origin/MAIN`.
   - If there are commits, ask the user for a work-branch name, then `git checkout -b <work-branch>` and set its `stack-parent` to `origin/MAIN`. This becomes the bottom of the stack.
   - If no commits, there's no stack to rebase — just create the yak branch and go.
5. **If on a feature branch:**
   - Walk `stack-parent` config down to find the full stack (bottom to top).
   - Collect the stack from current branch down to the branch whose parent is `origin/MAIN`.
6. Save old tips (`git rev-parse <branch>`) and remote tips (`git rev-parse origin/<branch>`) for every stack branch (needed for abort).
7. `git checkout -b <yak-name> origin/MAIN` — create the yak branch from main.
8. Set `branch.<yak-name>.stack-parent` to `origin/MAIN`.
9. Set `branch.<bottom-of-stack>.stack-parent` to `<yak-name>` (insert the yak beneath the stack).
10. Save in-progress state in git config under `yak.*`:
    - `yak.in-progress`, `yak.return-to`, `yak.has-stash`, `yak.yak-name`
    - `yak.cascade-stack` (space-separated branch names)
    - `yak.cascade-old-tips`, `yak.cascade-remote-tips` (space-separated hashes)
    - `yak.cascade-index` (start at 0)
    - `yak.bottom-original-parent` (so abort can restore it)
11. **Cascade rebase** each stack branch bottom-to-top:
    - For the first branch: `git rebase --onto <yak-name> origin/MAIN <branch>`
    - For subsequent branches: `git rebase --onto <prev-branch> <prev-old-tip> <branch>`
    - If a rebase fails with conflicts, tell the user to resolve them, run `git rebase --continue`, then `/yak continue`.
12. If cascade completes, clean up `yak.*` state except `yak.return-to` and `yak.has-stash`.
13. `git checkout <yak-name>` — the user is now on the yak branch ready to work.

## Operation: yak done

1. Read `yak.return-to` from git config. Fail if not set.
2. `git checkout <return-to>`
3. If `yak.has-stash` is true, `git stash pop`.
4. Clean up `yak.return-to` and `yak.has-stash` from config.

## Operation: yak continue

Resume after the user resolved a rebase conflict during yak.

1. Fail if `yak.in-progress` is not true.
2. Read `yak.cascade-index`. Continue the cascade from `index + 1`.
3. When cascade completes, clean up state, checkout the yak branch, tell user to work.

## Operation: yak abort

Cancel the yak and restore everything.

1. `git rebase --abort` (if one is in progress).
2. For each stack branch that was already rebased (index 0 to cascade-index - 1):
   - `git checkout <branch> && git reset --hard <old-tip>`
   - If the branch had a remote tip, `git push --force-with-lease=<branch>:<remote-tip> origin <branch>`
3. Restore the bottom branch's original `stack-parent`.
4. Delete the yak branch.
5. Checkout `return-to`, pop stash if needed.
6. Clean up all `yak.*` config.

## Operation: stack <name>

Create a new branch stacked on the current one.

1. Fail if not on a branch, or if `<name>` already exists.
2. `git checkout -b <name>`
3. `git config branch.<name>.stack-parent <current-branch>`
4. Confirm to user.

## Operation: sync (no args)

Rebase the entire stack. Auto-detects and removes squash-merged branches.

### Steps

1. If on main with no stacked branches, exit with "Nothing to sync."
2. `git fetch origin`
3. Walk `stack-parent` from the current branch to find the stack root.
4. Collect the full stack from root upward.
5. Check each branch from the bottom using `git cherry` — if all commits have equivalents on `origin/MAIN`, the branch was merged. Remove it and reparent the branch above.
6. Save state in `sync.*` config for continue/abort support.
7. **Cascade rebase** remaining branches onto their parents.
8. Update `stack-parent` config for each rebased branch.
9. Return to the original branch.

## Operation: sync <merged-branch>

After `<merged-branch>` was merged into main, rebase the remaining stack onto main.

### Steps

1. `git fetch origin`
2. Find the child of `<merged-branch>` by scanning `git config --get-regexp 'branch\..*\.stack-parent'` for a branch whose parent is `<merged-branch>`.
3. If no child found, just delete the local branch and its config. Done.
4. Walk upward from the child to collect the full stack above the merged branch.
5. Save old tips and remote tips for each stack branch.
6. Save in-progress state in `sync.*` config.
7. **Cascade rebase:**
   - First branch: `git rebase --onto origin/MAIN <merged-branch> <branch>`
   - Subsequent: `git rebase --onto <prev-branch> <prev-old-tip> <branch>`
   - On conflict: tell user to resolve, `git rebase --continue`, then `/yak sync --continue`.
8. Update `branch.<first-child>.stack-parent` to `origin/MAIN`.
9. Force-push each rebased branch: `git push --force-with-lease=<branch>:<old-remote-tip> origin <branch>`
10. Delete the merged branch locally and its git config section.
11. Clean up `sync.*` config.

### sync continue

Same as yak continue but reads from `sync.*` config. After cascade, does the push + cleanup steps.

### sync abort

Same pattern as yak abort but reads from `sync.*` config. Reset rebased branches, restore remote state.

## Operation: stack-pr <title>

Create a PR for the bottom branch of the stack.

1. Fail if not on a branch, or if on main.
2. Fail if the branch has no `stack-parent` config.
3. Fail if the branch's parent is not `origin/MAIN` (i.e., it's not the bottom of the stack).
4. `git push -u origin <branch>`
5. `gh pr create --base MAIN --title <title> --body ""`
6. Print the PR URL.

## Operation: tree

Show the branch stack by running `git stack-tree`.

## Operation: status (no args)

Show the user:
- Current branch
- The stack (walk stack-parent from current branch down, and find children above)
- Whether a yak or sync is in progress

## Operation: install

Install the git commands as git subcommands so the user can also use them directly from the terminal.

Run:
```
${CLAUDE_SKILL_DIR}/install.sh
```

If the user asks for `--copy` mode or a custom `--bin-dir`, pass those flags through.
If `~/.local/bin` is not on PATH, tell the user what to add to their shell profile.

## General rules

- Always use `--force-with-lease` (never `--force`) when pushing rebased branches.
- When a rebase conflicts, stop and guide the user through resolution. Don't try to auto-resolve.
- After each significant step, briefly tell the user what happened and what to do next.
- Use `git config --remove-section` to clean up state sections when done.
