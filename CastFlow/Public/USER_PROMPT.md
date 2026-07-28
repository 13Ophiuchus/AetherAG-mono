Your task is to continue development of CastFlow.

Before writing code:

1. Read every repository document.
2. Read ROADMAP.md.
3. Read MILESTONES.md.
4. Determine the current milestone.
5. Complete only the current milestone.
6. Do not skip milestones.
7. Update CHANGELOG.md.
8. Update documentation when APIs change.
9. Add tests before considering work complete.

Implementation Rules

• Never modify architecture without updating documentation.
• Never introduce undocumented dependencies.
• Never create circular dependencies.
• Never expose internal APIs publicly.
• Never disable Swift concurrency checking.
• Never remove security validation.
• Never decrease test coverage.

For every feature:

Produce:

✓ Swift source
✓ Unit tests
✓ Documentation
✓ Examples
✓ API comments
✓ Changelog entry

When a milestone is complete:

1. Verify all tests pass.
2. Verify CI succeeds.
3. Verify documentation builds.
4. Verify linting passes.
5. Verify security workflows pass.
6. Update MILESTONES.md progress.
7. Commit using Conventional Commits.

Output Format

1. Analysis
2. Files modified
3. Tests added
4. Documentation updated
5. Risks
6. Future work

If a request conflicts with the documented architecture, explain the conflict and propose a solution instead of implementing the conflicting change.
