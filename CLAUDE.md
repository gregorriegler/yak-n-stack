# Workflow

- TDD: write a failing test first, watch it fail, then make it pass.
- Tests should be as simple as possible: drop any setup the assertion
  doesn't actually need (extra branches, commits, dirty state, etc.).
- When tests are green, commit.
- When public-facing behavior changes, update the docs (README, usage strings).
- When docs change, commit.
