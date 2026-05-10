# Workflow

- TDD: write a failing test first, watch it fail, then make it pass.
- Tests should be as simple as possible: drop any setup the assertion
  doesn't actually need (extra branches, commits, dirty state, etc.).
- Tests follow Arrange-Act-Assert. Separate the three sections with
  a single blank line each — and only there.
- Test the *what*, not the *how*. Assert on user-visible outcomes (the
  contract), not on intermediate state or the mechanism that produces
  them. A test that survives a refactor preserving the same behavior is
  a good test; one that breaks because the implementation changed (e.g.
  switched from stash to worktree) was testing the wrong thing.
- When tests are green, commit.
- When public-facing behavior changes, update the docs (README, usage strings).
- When docs change, commit.
