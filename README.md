# yak

Three git commands for stacking small PRs without waiting for them to merge.

```
git stack <name>     stack a new branch on top of the current one
git yak <name>       insert a branch beneath your current work
git sync             rebase the stack, cleaning up merged branches
```

## Install

```bash
./install.sh            # symlinks into ~/.local/bin (default)
./install.sh --copy     # copies instead of symlinking
./install.sh --uninstall
```

## Why

You want to keep working while your PRs are in review. But each piece of
work depends on the last, so you need your branches stacked in order.
When a PR merges, you need everything above it rebased cleanly.

These three commands handle the bookkeeping.

---

## Use cases

### Stack: keep going without waiting

You finished `part-1` and want to keep building on top:

```bash
git stack part-2
# work, commit, push, open PR targeting part-1
```

```
main
 └─ part-1          ← PR #1
     └─ part-2      ← PR #2 (you are here)
```

Stack as many as you need:

```bash
git stack part-3
```

```
main
 └─ part-1          ← PR #1
     └─ part-2      ← PR #2
         └─ part-3  ← PR #3 (you are here)
```

Each PR shows only its own diff. Reviewers see small, focused changes.

---

### Sync: a PR was merged

PR #1 (`part-1`) gets merged. Run sync to update the stack:

```bash
git sync
```

Before:
```
main
 └─ part-1          ← merged
     └─ part-2
         └─ part-3  ← you are here
```

After:
```
main                ← includes part-1
 └─ part-2          ← rebased, PR #2 now targets main
     └─ part-3      ← rebased (you are here)
```

`git sync` automatically detects that `part-1` was merged, deletes it,
and rebases everything above onto the new main. Works with squash merges,
rebase-and-merge, and regular merge commits.

---

### Sync: you changed a branch lower in the stack

You got review feedback on `part-1` and pushed a fix. Now `part-2` and
`part-3` are out of date:

```bash
git checkout part-1
# make changes, commit
git sync
```

Before:
```
main
 └─ part-1 *        ← new commit added
     └─ part-2      ← stale
         └─ part-3  ← stale
```

After:
```
main
 └─ part-1          ← you are here
     └─ part-2      ← rebased
         └─ part-3  ← rebased
```

---

### Yak: you found something that needs to happen first

You are working on `feature` and realize you need a refactor to land first:

```bash
git yak refactor
```

Before:
```
main
 └─ feature         ← you are here, mid-work
```

After:
```
main
 └─ refactor        ← you are here, do the refactor
     └─ feature     ← moved on top, waiting
```

The script stashes uncommitted changes, creates `refactor` beneath
`feature`, rebases the stack, and drops you on `refactor`. When done:

```bash
git yak --done
```

```
main
 └─ refactor        ← push this, open PR
     └─ feature     ← you are back here, stash restored
```

When `refactor` merges, `git sync` cleans it up and `feature` lands
directly on main.

---

### Yak from a stack: prerequisite work while mid-stack

You are on `part-3` and discover something that the whole stack needs:

```bash
git yak prereq
```

Before:
```
main
 └─ part-1
     └─ part-2
         └─ part-3  ← you are here
```

After:
```
main
 └─ prereq          ← you are here
     └─ part-1      ← rebased
         └─ part-2  ← rebased
             └─ part-3  ← rebased
```

`--done` returns you to `part-3`. When `prereq` merges, `git sync`
moves the whole stack back onto main.

---

### Nested yaks: another yak while doing a yak

You are on `refactor` and discover yet another thing:

```bash
git yak typo-fix
```

```
main
 └─ typo-fix        ← you are here
     └─ refactor
         └─ feature
```

Same flow. Sync them from the bottom up as each one merges.

---

### Conflicts

If a rebase hits a conflict during `yak` or `sync`:

```
Conflict rebasing 'part-2' onto 'origin/main'.
Resolve the conflicts, then run: git rebase --continue
Then run: git sync --continue
```

Resolve, then:

```bash
git add .
git rebase --continue
git sync --continue   # or: git yak --continue
```

Rerere is enabled automatically, so repeated conflicts across the stack
resolve themselves.

To cancel and restore everything:

```bash
git sync --abort   # or: git yak --abort
```

---

## How it works

Branch relationships are stored in git config as `branch.<name>.yak-parent`.
`git yak-tree` prints the current stack:

```bash
$ git yak-tree
main
 └─ refactor [2]
     └─ feature [3] ←
```

The `[N]` is the commit count. The `←` marks the current branch.

## Notes

- The scripts assume your remote is named `origin`.
- If `init.defaultBranch` is not set, the scripts default to `main`:
  ```bash
  git config init.defaultBranch develop   # if your trunk is different
  ```
- If you rename or delete branches outside these commands, the
  `yak-parent` config can go stale. Clean it up with
  `git config --remove-section branch.<name>`.
