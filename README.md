# git-yak, git-stack, git-sync

Three git commands for a workflow where you always start working on main, create small PRs, and stack your next change on top of each one without waiting for them to merge.

## Install

```bash
cp git-yak git-stack git-sync /usr/local/bin/
```

## The idea

You always start on main. When you are ready to PR, or when you find something you need to do first, you reach for one of these commands.

- **git yak** moves your current work to a branch and drops you on a new branch for the thing you need to do first
- **git stack** creates a new branch on top of your current one so you can keep going without waiting for the PR to merge
- **git sync** updates your stack after a branch gets squash-merged into main

The scripts track your stack by storing each branch's parent in git config under `branch.<name>.yak-parent`. They also enable rerere automatically so that repeated rebase conflicts across stack branches only need to be resolved once.

---

## Flows

### 1. Basic: work on main, create a PR

You work on main as usual. When you are ready to open a PR:

```bash
git yak fix-the-thing
```

If you have commits on main, the script asks you to name a branch for your current work, moves everything there, then drops you on `fix-the-thing` to do the yak. When done:

```bash
git add .
git commit -m "fix the thing"
git push origin fix-the-thing
# open PR
git yak --done
```

`--done` puts you back on your work branch with your stash restored.

---

### 2. Stack: keep going without waiting for the PR to merge

You are on `feature-part-1` and want to continue building on top of it:

```bash
git stack feature-part-2
# work, commit, push
# open PR targeting feature-part-1
git stack feature-part-3
# work, commit, push
# open PR targeting feature-part-2
```

Each PR shows only the diff introduced by that branch. Reviewers see small focused changes. You never have to wait.

---

### 3. Sync: a branch was squash-merged into main

`feature-part-1` merged. The squash creates a new commit on main with a different hash, so a plain rebase would replay the old commits and cause conflicts. Instead:

```bash
git sync feature-part-1
```

This rebases `feature-part-2` directly onto `origin/main` using `--onto`, skipping the old commits from `feature-part-1`. Then it cascades up to `feature-part-3` and any further branches, force pushes them all, and cleans up the local `feature-part-1` branch.

---

### 4. Yak from a stack: finding something you need to do first while mid-stack

You are on `feature-part-2` and discover something that needs to happen before your whole stack. Just run:

```bash
git yak the-yak
```

The script walks down to the bottom of your stack, rebases the whole stack on top of `the-yak`, then drops you on `the-yak` to do the work. Your stack now looks like:

```
main -> the-yak -> feature-part-1 -> feature-part-2 -> feature-part-3
```

When `the-yak` merges, run `git sync the-yak` and the rest of the stack moves onto main.

---

### 5. Multiple yaks: finding another yak while doing a yak

You are on `the-yak` and discover yet another thing that needs to happen first:

```bash
git yak deeper-yak
```

Same flow. The script inserts `deeper-yak` beneath `the-yak` and the rest of the stack. The stack becomes:

```
main -> deeper-yak -> the-yak -> feature-part-1 -> feature-part-2
```

Sync them from the bottom up as each one merges.

---

### 6. Yak from main with no prior commits

You just pulled main and haven't written anything yet. You spot something to fix:

```bash
git yak quick-fix
```

Since there are no commits on main, the script skips creating a work branch and just drops you on `quick-fix` directly. When done:

```bash
git yak --done
# returns you to main
```

---

### 7. Conflict during yak or sync

If a rebase hits a conflict:

```
Conflict rebasing 'feature-part-2' onto 'the-yak'.
Resolve the conflicts, then run: git rebase --continue
Then run: git yak --continue
```

Resolve the conflict in your editor, then:

```bash
git add .
git rebase --continue
git yak --continue   # or git sync --continue
```

Because rerere is enabled, if the same conflict appears on the next branch in the cascade, git resolves it automatically.

---

### 8. Aborting a yak or sync

If you want to cancel and go back to exactly how things were:

```bash
git yak --abort   # or git sync --abort
```

This aborts any in-progress rebase, resets all branches that were already rebased back to their original commits, restores the original yak-parent config on your stack, force pushes the restored branches to remote if they were already pushed, deletes the yak branch, and pops your stash if one was saved.

---

## Commands

```
git yak <name>       insert a yak branch beneath your current work
git yak --done       yak is finished, return to your work branch
git yak --continue   continue the cascade after resolving a rebase conflict
git yak --abort      cancel and restore everything to its original state

git stack <name>     create a new branch stacked on top of the current one

git sync <branch>    rebase the stack after <branch> was squash-merged into main
git sync --continue  continue after resolving a rebase conflict
git sync --abort     cancel and restore everything to its original state
```

## Notes

- Branch names are tracked in git config as `branch.<name>.yak-parent`. If you rename or delete branches manually outside these commands, that config can go stale.
- The scripts assume your remote is named `origin`.
- If `init.defaultBranch` is not set in your git config, the scripts default to `main`. Set it explicitly if your repo uses a different name:
  ```bash
  git config init.defaultBranch master
  ```
- Rerere is enabled automatically on first use. If you want it globally across all repos:
  ```bash
  git config --global rerere.enabled true
  git config --global rerere.autoupdate true
  ```
