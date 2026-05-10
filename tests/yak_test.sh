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

# ── yak: stay on the current branch ─────────────────────────

function test_yak_keeps_you_on_current_branch() {
    git yak typo-fix

    assert_same "main" "$(git branch --show-current)"
}

# ── yak --done: yak commits land on the original branch ─────

function test_yak_done_keeps_yak_commit_on_original_branch() {
    git yak typo-fix
    commit typo

    git yak --done

    assert_equals 0 $?
    assert_same "main" "$(git branch --show-current)"
    assert_same "typo" "$(git log -1 --format=%s)"
}

# ── yak hides uncommitted work so yak commits stay clean ────

function test_yak_clears_uncommitted_changes() {
    echo "dirty" > dirty.txt

    git yak typo-fix

    assert_same "" "$(git status --porcelain)"
}

# ── yak --done brings uncommitted work back ─────────────────

function test_yak_done_restores_uncommitted_changes() {
    echo "dirty" > dirty.txt

    git yak typo-fix
    git yak --done

    assert_same "dirty" "$(cat dirty.txt)"
}

# ── yak from main with commits keeps yak commits off main ───

function test_yak_on_main_with_commits_keeps_yak_off_main() {
    commit work

    git yak typo-fix
    commit typo
    git yak --done

    assert_same "work" "$(git log -1 main --format=%s)"
    assert_same "work-1" "$(git branch --show-current)"
}

# ── nested yaks: each --done restores its own WIP ───────────

function test_nested_yaks_unwind_each_levels_wip() {
    echo "outer" > outer.txt
    git yak first
    echo "inner" > inner.txt
    git yak second

    git yak --done
    git yak --done

    assert_same "outer" "$(cat outer.txt)"
    assert_same "inner" "$(cat inner.txt)"
}
