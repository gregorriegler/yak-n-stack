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
    git stack-tree
}

# ── git yak from main with commits ──────────────────────────

function test_yak_from_main_moves_work_and_lands_on_yak() {
    commit work

    git yak the-yak

    assert_same "$(tree)" \
$'main
 └─ the-yak ←
     └─ work-1 [1]'
}

function test_yak_done_returns_to_work_branch() {
    commit work

    git yak the-yak
    git yak --done

    assert_same "$(tree)" \
$'main
 └─ the-yak
     └─ work-1 [1] ←'
}

# ── git yak from main with no commits ───────────────────────

function test_yak_from_main_no_commits_lands_on_yak() {
    git yak quick-fix

    assert_same "$(tree)" \
$'main
 └─ quick-fix ←'
}

function test_yak_done_from_main_returns_to_main() {
    git yak quick-fix
    git yak --done

    assert_same "$(tree)" \
$'main ←
 └─ quick-fix'
}

# ── git yak from a feature branch ───────────────────────────

function test_yak_from_feature_inserts_beneath() {
    make_branch feature-1

    git yak the-yak

    assert_same "$(tree)" \
$'main
 └─ the-yak ←
     └─ feature-1 [1]'
}

function test_yak_done_from_feature_returns_to_feature() {
    make_branch feature-1

    git yak the-yak
    git yak --done

    assert_same "$(tree)" \
$'main
 └─ the-yak
     └─ feature-1 [1] ←'
}

# ── stacked branches with yak beneath ───────────────────────

function test_yak_beneath_stack_rebases_entire_stack() {
    make_branch part-1
    git stack part-2
    commit part-2

    git yak the-yak

    assert_same "$(tree)" \
$'main
 └─ the-yak ←
     └─ part-1 [1]
         └─ part-2 [1]'
}

function test_yak_done_from_stack_returns_to_original_branch() {
    make_branch part-1
    git stack part-2
    commit part-2

    git yak the-yak
    git yak --done

    assert_same "$(tree)" \
$'main
 └─ the-yak
     └─ part-1 [1]
         └─ part-2 [1] ←'
}

# ── uncommitted changes are stashed and restored ─────────────

function test_yak_preserves_uncommitted_changes() {
    make_branch feature-1
    echo "dirty" > dirty.txt

    git yak the-yak
    git yak --done

    assert_same "$(tree)" \
$'main
 └─ the-yak
     └─ feature-1 [1] ←'
    assert_same "dirty" "$(cat dirty.txt)"
}

# ── multiple yaks: yak while doing a yak ────────────────────

function test_nested_yak_inserts_beneath_current_yak() {
    make_branch feature-1

    git yak the-yak
    commit yak-work

    git yak deeper-yak

    assert_same "$(tree)" \
$'main
 └─ deeper-yak ←
     └─ the-yak [1]
         └─ feature-1 [1]'
}

function test_nested_yak_done_returns_to_original_branch() {
    make_branch feature-1

    git yak the-yak
    commit yak-work

    git yak deeper-yak
    commit deeper-work
    git yak --done

    # --done returns to where we were before the deeper yak
    assert_same "$(tree)" \
$'main
 └─ deeper-yak [1]
     └─ the-yak [1] ←
         └─ feature-1 [1]'
}

