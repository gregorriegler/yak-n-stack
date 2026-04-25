# yak-n-stack

![Build](https://img.shields.io/github/actions/workflow/status/gregorriegler/yak-n-stack/coverage.yml?branch=main&label=build)
![Coverage](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/gregorriegler/yak-n-stack/badges/coverage.json)

Git commands for yak-shaving and stacking PRs.

```
git yak <name>        insert a branch beneath your current work
git stack <name>      stack a new branch on top of the current one
git stack-pr <title>  push and create a PR for the bottom branch
git sync              rebase the stack, cleaning up merged branches
git stack-tree        print the branch stack
```

## Install

```bash
./install.sh            # symlinks into ~/.local/bin (default)
./install.sh --copy     # copies instead of symlinking
./install.sh --uninstall
```

---

## Yak: something needs to happen first

You are working on `feature` and realize you need a refactor to land first.

Before:
```
main
 └─ feature         ← you are here, mid-work
```

Motivation: the refactor is a prerequisite. You want it reviewed and
merged on its own, with `feature` waiting on top.

```bash
git yak refactor
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
 └─ refactor        ← ready for review
     └─ feature     ← you are back here, stash restored
```

---

## Stack: keep going without waiting

You finished `part-1` and want to keep building on top.

Before:
```
main
 └─ part-1          ← you are here, done but not merged
```

Motivation: `part-1` is in review. You don't want to wait — you want to
start `part-2` on top, so it's ready the moment `part-1` lands.

```bash
git stack part-2
```

After:
```
main
 └─ part-1
     └─ part-2      ← you are here
```

---

## Stack-pr: open a PR for the bottom branch

You're ready to send the bottom branch for review.

Before:
```
main
 └─ part-1
     └─ part-2      ← you are here
```

Motivation: only the bottom branch can be merged next. `stack-pr` finds
it and opens the PR against main — no checkout needed.

```bash
git stack-pr "Add feature part 1"
```

After: `part-1` is pushed and a PR is open against main. You stay on
`part-2` and keep working.

---

## Sync: a PR was merged

PR #1 (`part-1`) gets merged.

Before:
```
main
 └─ part-1          ← merged
     └─ part-2      ← you are here
```

Motivation: main moved forward. The stack needs to be rebased onto the
new main, and the merged branch cleaned up.

```bash
git sync
```

After:
```
main                ← includes part-1
 └─ part-2          ← rebased onto new main (you are here)
```

`git sync` detects that `part-1` was merged, deletes it, and rebases
everything above onto the new main. Works with squash merges,
rebase-and-merge, and regular merge commits.

---

## How it works

Branch relationships are stored in git config as `branch.<name>.stack-parent`.
`git stack-tree` prints the current stack:

```bash
$ git stack-tree
main
 └─ refactor [2]
     └─ feature [3] ←
```

The `[N]` is the commit count. The `←` marks the current branch.
All commands print the tree after completing, so you always know where
you are.

## Tests

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
