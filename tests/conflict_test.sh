#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

set_up() {
    TEST_DIR=$(mktemp -d)
    REMOTE_DIR="$TEST_DIR/remote.git"
    WORK_DIR="$TEST_DIR/work"

    export GIT_AUTHOR_NAME="Test"
    export GIT_COMMITTER_NAME="Test"
    export GIT_AUTHOR_EMAIL="test@test.com"
    export GIT_COMMITTER_EMAIL="test@test.com"
    export PATH="$SCRIPT_DIR:$PATH"

    git init --bare "$REMOTE_DIR" >/dev/null 2>&1
    git clone "$REMOTE_DIR" "$WORK_DIR" >/dev/null 2>&1

    cd "$WORK_DIR"
    git config init.defaultBranch main

    echo "init" > file.txt
    git add file.txt
    git commit -m "initial" >/dev/null 2>&1
    git push origin main >/dev/null 2>&1
}

tear_down() {
    cd /
    rm -rf "$TEST_DIR"
}

commit() {
    echo "$1" > "$1" && git add "$1" && git commit -m "$1" >/dev/null 2>&1
}

make_branch() {
    git checkout -b "$1" >/dev/null 2>&1
    git config "branch.$1.stack-parent" origin/main
    commit "$1"
}

tree() {
    git yak-tree
}

# push a commit to origin/main that edits a file, creating a conflict
conflict_on_main() {
    local file="$1" content="$2"
    local helper="$TEST_DIR/helper"
    git clone "$REMOTE_DIR" "$helper" >/dev/null 2>&1
    echo "$content" > "$helper/$file"
    git -C "$helper" add "$file"
    git -C "$helper" commit -m "main edits $file" >/dev/null 2>&1
    git -C "$helper" push origin main >/dev/null 2>&1
    rm -rf "$helper"
}

# push a squash-merge of a branch plus a conflicting edit to origin/main
squash_merge_with_conflict() {
    local branch="$1" file="$2" content="$3"
    local helper="$TEST_DIR/helper"
    git clone "$REMOTE_DIR" "$helper" >/dev/null 2>&1
    git -C "$helper" merge --squash "origin/$branch" >/dev/null 2>&1
    git -C "$helper" commit -m "squash-merge $branch" >/dev/null 2>&1
    echo "$content" > "$helper/$file"
    git -C "$helper" add "$file"
    git -C "$helper" commit -m "main edits $file" >/dev/null 2>&1
    git -C "$helper" push origin main >/dev/null 2>&1
    rm -rf "$helper"
}

resolve() {
    local file="$1" content="$2"
    echo "$content" > "$file"
    git add "$file"
}

# ── yak with conflict ───────────────────────────────────────

function test_yak_conflict_then_continue() {
    make_branch feature-1
    echo "feature" > shared.txt
    git add shared.txt && git commit -m "edit shared" >/dev/null 2>&1

    conflict_on_main shared.txt "main"

    git yak the-yak || true

    resolve shared.txt "resolved"
    git rebase --continue >/dev/null 2>&1
    git yak --continue

    assert_same "the-yak" "$(git branch --show-current)"
    assert_same "resolved" "$(git show feature-1:shared.txt)"
}

function test_yak_conflict_then_abort() {
    make_branch feature-1
    echo "feature" > shared.txt
    git add shared.txt && git commit -m "edit shared" >/dev/null 2>&1

    local old_tip
    old_tip=$(git rev-parse feature-1)

    conflict_on_main shared.txt "main"

    git yak the-yak || true
    git yak --abort

    assert_same "feature-1" "$(git branch --show-current)"
    assert_same "$old_tip" "$(git rev-parse feature-1)"
    assert_empty "$(git branch --list the-yak)"
}

# ── sync with conflict ──────────────────────────────────────

function test_sync_conflict_then_continue() {
    make_branch part-1
    git push origin part-1 >/dev/null 2>&1
    git stack part-2
    echo "part-2" > shared.txt
    git add shared.txt && git commit -m "edit shared" >/dev/null 2>&1
    git push origin part-2 >/dev/null 2>&1

    squash_merge_with_conflict part-1 shared.txt "main"

    git sync part-1 || true

    resolve shared.txt "resolved"
    git rebase --continue >/dev/null 2>&1
    git sync --continue

    assert_same "resolved" "$(git show part-2:shared.txt)"
    assert_empty "$(git branch --list part-1)"
}

function test_sync_conflict_then_abort() {
    make_branch part-1
    git push origin part-1 >/dev/null 2>&1
    git stack part-2
    echo "part-2" > shared.txt
    git add shared.txt && git commit -m "edit shared" >/dev/null 2>&1
    git push origin part-2 >/dev/null 2>&1

    local old_tip
    old_tip=$(git rev-parse part-2)

    squash_merge_with_conflict part-1 shared.txt "main"

    git sync part-1 || true
    git sync --abort

    assert_same "$old_tip" "$(git rev-parse part-2)"
}

# ── no-arg sync with conflict ──────────────────────────────

function test_sync_no_arg_conflict_then_continue() {
    make_branch part-1
    git stack part-2
    echo "part-2" > shared.txt
    git add shared.txt && git commit -m "edit shared" >/dev/null 2>&1
    git stack part-3
    commit part-3

    # push a conflicting commit to main
    conflict_on_main shared.txt "main"

    git checkout part-3 >/dev/null 2>&1
    git sync || true

    resolve shared.txt "resolved"
    git rebase --continue >/dev/null 2>&1
    git sync --continue

    # part-2 has the resolution, part-3 is rebased on top, back on part-3
    assert_same "part-3" "$(git branch --show-current)"
    assert_same "resolved" "$(git show part-2:shared.txt)"
    assert_same "$(tree)" \
$'main
 └─ part-1 [1]
     └─ part-2 [1]
         └─ part-3 [1] ←'
}

function test_sync_no_arg_conflict_then_abort() {
    make_branch part-1
    git stack part-2
    echo "part-2" > shared.txt
    git add shared.txt && git commit -m "edit shared" >/dev/null 2>&1
    git stack part-3
    commit part-3

    local old_part1_tip old_part2_tip old_part3_tip
    old_part1_tip=$(git rev-parse part-1)
    old_part2_tip=$(git rev-parse part-2)
    old_part3_tip=$(git rev-parse part-3)

    conflict_on_main shared.txt "main"

    git checkout part-3 >/dev/null 2>&1
    git sync || true
    git sync --abort

    assert_same "$old_part1_tip" "$(git rev-parse part-1)"
    assert_same "$old_part2_tip" "$(git rev-parse part-2)"
    assert_same "$old_part3_tip" "$(git rev-parse part-3)"
}
