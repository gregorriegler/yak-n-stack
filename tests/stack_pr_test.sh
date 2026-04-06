#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

set_up() {
    TEST_DIR=$(mktemp -d)
    REMOTE_DIR="$TEST_DIR/remote.git"
    WORK_DIR="$TEST_DIR/work"
    GH_LOG="$TEST_DIR/gh.log"

    export GIT_AUTHOR_NAME="Test"
    export GIT_COMMITTER_NAME="Test"
    export GIT_AUTHOR_EMAIL="test@test.com"
    export GIT_COMMITTER_EMAIL="test@test.com"

    mkdir -p "$TEST_DIR/bin"
    export PATH="$TEST_DIR/bin:$SCRIPT_DIR:$PATH"
    export GH_LOG

    stub_gh

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

squash_merge() {
    local branch="$1"
    local helper="$TEST_DIR/helper"
    git clone "$REMOTE_DIR" "$helper" >/dev/null 2>&1
    git -C "$helper" merge --squash "origin/$branch" >/dev/null 2>&1
    git -C "$helper" commit -m "squash-merge $branch" >/dev/null 2>&1
    git -C "$helper" push origin main >/dev/null 2>&1
    rm -rf "$helper"
}

stub_gh() {
    cat > "$TEST_DIR/bin/gh" <<'EOF'
#!/bin/bash
echo "$@" >> "$GH_LOG"
if [ "$1" = "pr" ] && [ "$2" = "create" ]; then
    echo "https://github.com/test/repo/pull/1"
fi
EOF
    chmod +x "$TEST_DIR/bin/gh"
}

gh_calls() {
    cat "$GH_LOG" 2>/dev/null
}

# ── PR creation ────────────────────────────────────────────

function test_stack_pr_creates_pr_for_bottom_branch() {
    make_branch feature-1

    local output
    output=$(git stack-pr "Add feature 1")

    assert_matches "https://github.com" "$output"
    assert_matches "pr create" "$(gh_calls)"
}

function test_stack_pr_pushes_branch_before_creating_pr() {
    make_branch feature-1

    git stack-pr "Add feature 1" >/dev/null 2>&1

    local remote_ref
    remote_ref=$(git ls-remote origin feature-1 2>/dev/null | head -1)
    assert_not_empty "$remote_ref"
}

function test_stack_pr_errors_if_not_bottom_of_stack() {
    make_branch part-1
    git stack part-2
    commit part-2

    local output
    output=$(git stack-pr "Add part 2" 2>&1) || true

    assert_matches "only the bottom" "$output"
}

function test_stack_pr_errors_on_main() {
    local output
    output=$(git stack-pr "Something" 2>&1) || true

    assert_matches "not on a stack branch" "$output"
}

function test_stack_pr_errors_on_branch_without_stack_parent() {
    git checkout -b random-branch >/dev/null 2>&1

    local output
    output=$(git stack-pr "Something" 2>&1) || true

    assert_matches "not part of a stack" "$output"
}

function test_stack_pr_works_after_sync_promotes_branch_to_bottom() {
    make_branch part-1
    git push origin part-1 >/dev/null 2>&1
    git stack part-2
    commit part-2

    squash_merge part-1

    git sync

    local output
    output=$(git stack-pr "Add part 2")

    assert_matches "https://github.com" "$output"
}
