# yak

Git commands for stacking small PRs without waiting for them to merge.

```
git stack <name>      stack a new branch on top of the current one
git yak <name>        insert a branch beneath your current work
git sync              rebase the stack, cleaning up merged branches
git stack-pr <title>  push and create a PR for the bottom branch
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

These commands handle the bookkeeping.

---

## Use cases

### Stack: keep going without waiting

You finished `part-1` and want to keep building on top:

```bash
git stack part-2
# work, commit
git stack part-3
# work, commit
```

```
main
 └─ part-1          ← ready for review
     └─ part-2
         └─ part-3  ← you are here
```

---

### Stack-pr: open a PR for the bottom branch

When you're ready to send the bottom branch for review:

```bash
git checkout part-1
git stack-pr "Add feature part 1"
```

This pushes the branch and creates a PR targeting main. Only the bottom
of the stack can have a PR — the branches above it are still in progress.

When `part-1` merges and you run `git sync`, `part-2` becomes the new
bottom and you can run `git stack-pr` again.

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
 └─ part-2          ← rebased, now the bottom of the stack
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
 └─ refactor        ← git stack-pr "Refactor" to open PR
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

Branch relationships are stored in git config as `branch.<name>.stack-parent`.
`git yak-tree` prints the current stack:

```bash
$ git yak-tree
main
 └─ refactor [2]
     └─ feature [3] ←
```

The `[N]` is the commit count. The `←` marks the current branch.

## Tests

The [tests](tests/) cover every use case above in detail, including edge
cases like nested yaks, conflict resolution, and squash-merge detection.
Read them if you want to understand exactly what each command does.

```bash
./test.sh
```

## Notes

- `git stack-pr` requires the [GitHub CLI](https://cli.github.com/) (`gh`).
- The scripts assume your remote is named `origin`.
- If `init.defaultBranch` is not set, the scripts default to `main`:
  ```bash
  git config init.defaultBranch develop   # if your trunk is different
  ```
- If you rename or delete branches outside these commands, the
  `stack-parent` config can go stale. Clean it up with
  `git config --remove-section branch.<name>`.
