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
    git config "branch.$1.yak-parent" origin/main
    commit "$1"
}

tree() {
    git yak-tree
}

# simulate a squash-merge of a branch into main on the remote
# uses a helper clone so the working repo sees it as origin
squash_merge() {
    local branch="$1"
    local helper="$TEST_DIR/helper"
    git clone "$REMOTE_DIR" "$helper" >/dev/null 2>&1
    git -C "$helper" merge --squash "origin/$branch" >/dev/null 2>&1
    git -C "$helper" commit -m "squash-merge $branch" >/dev/null 2>&1
    git -C "$helper" push origin main >/dev/null 2>&1
    rm -rf "$helper"
}

# ── git sync: basic squash-merge ────────────────────────────

function test_sync_rebases_stack_after_squash_merge() {
    make_branch part-1
    git push origin part-1 >/dev/null 2>&1
    git stack part-2
    commit part-2
    git push origin part-2 >/dev/null 2>&1

    squash_merge part-1

    git sync part-1

    # part-1 is gone, part-2 sits directly on main
    assert_same "$(tree)" \
$'main
 └─ part-2 [1] ←'
}

function test_sync_rebases_deep_stack() {
    make_branch part-1
    git push origin part-1 >/dev/null 2>&1
    git stack part-2
    commit part-2
    git push origin part-2 >/dev/null 2>&1
    git stack part-3
    commit part-3
    git push origin part-3 >/dev/null 2>&1

    squash_merge part-1

    git sync part-1

    # part-1 is gone, part-2 and part-3 rebased onto main
    assert_same "$(tree)" \
$'main
 └─ part-2 [1]
     └─ part-3 [1] ←'
}

function test_sync_cleans_up_merged_branch() {
    make_branch part-1
    git push origin part-1 >/dev/null 2>&1
    git stack part-2
    commit part-2
    git push origin part-2 >/dev/null 2>&1

    squash_merge part-1

    git sync part-1

    # part-1 local branch should be deleted
    local branches
    branches=$(git branch --list part-1)
    assert_empty "$branches"
}

function test_sync_with_no_stack_above() {
    make_branch part-1
    git push origin part-1 >/dev/null 2>&1

    squash_merge part-1

    local output
    output=$(git sync part-1 2>&1)

    # no child branches, just cleans up
    assert_matches "No branch found" "$output"
}

# ── sync after yak merges ───────────────────────────────────

function test_sync_yak_then_sync_restores_stack_to_main() {
    make_branch feature-1
    git push origin feature-1 >/dev/null 2>&1

    git yak the-yak
    commit yak-work
    git push origin the-yak >/dev/null 2>&1
    git yak --done

    # stack is: main -> the-yak -> feature-1
    # now the-yak gets squash-merged
    squash_merge the-yak

    git sync the-yak

    # feature-1 should now sit directly on main
    assert_same "$(tree)" \
$'main
 └─ feature-1 [1] ←'
}
