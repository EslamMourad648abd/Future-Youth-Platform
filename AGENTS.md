# Future Youth Platform — Agent Instructions

## Mission
Build the bilingual Arabic/English learning platform in this existing Flutter repository. Roles: Admin, Teacher, Parent, Student.

## Workflow
1. Read this file and docs/REQUIREMENTS.md, docs/ROLE_PERMISSIONS.md, docs/ARCHITECTURE.md, docs/AGENT_TASKS.md, and docs/OPEN_DECISIONS.md.
2. Inspect the repository and Git status before edits. Work one task at a time in order.
3. Preserve working functionality; do not perform broad refactors or overwrite existing app configuration without a clear need.
4. Never print, commit, or expose secrets, service-account keys, API keys, .env files, passwords, tokens, or private data.
5. Do not commit node_modules, build outputs, caches, or local IDE state.
6. Never deploy Firebase rules/functions or change cloud resources without explicit owner approval.
7. Backend/security rules must enforce access; hiding UI controls is not security.
8. Add tests for business rules and security-sensitive behavior. Run formatter, flutter analyze, and relevant tests when possible. Report only checks actually run and their real results.
9. Never claim a task is done if it was not tested; explain blockers and manual steps.
10. Do not implement a real payment integration until the owner chooses a provider and its official integration route is verified. A pending/manual-verification workflow may be proposed but not silently activated.
11. Brand colors: navy #263778 and green #00A651. Use accessible contrast.
12. Support Arabic RTL and English LTR using Flutter localization; avoid hard-coded user-facing strings.
13. Separate stated requirements, inferences, recommendations, and unresolved decisions. Do not invent business rules.
14. Treat the existing Firebase configuration as potentially belonging to another product. Verify the intended Future Youth Platform project before connecting or deploying.

## Definition of done
- Acceptance criteria met.
- Relevant tests run and results accurately reported.
- No secrets or unrelated files added.
- Summary includes changed files, behavior, test output, blockers, and next step.
