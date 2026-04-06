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

# ── git stack ────────────────────────────────────────────────

function test_stack_creates_branch_on_top_of_current() {
    make_branch feature-1

    git stack feature-2

    assert_same "$(tree)" \
$'main
 └─ feature-1 [1]
     └─ feature-2 ←'
}

function test_stack_fails_if_branch_exists() {
    make_branch feature-1
    git stack feature-2
    commit feature-2

    local output
    output=$(git stack feature-2 2>&1) || true

    assert_matches "already exists" "$output"
    assert_same "$(tree)" \
$'main
 └─ feature-1 [1]
     └─ feature-2 [1] ←'
}
