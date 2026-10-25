# Android Studio AI Agent Task Queue

Run one task at a time in order. Inspect first, make the smallest safe change, test, report actual results, and wait before moving on.

## T00 — Repository and secret hygiene audit
Inspect Git status, branches, .gitignore, Firebase config, tracked generated files, node_modules, and service-account/private-key files. Do not print secrets. Report findings first. Ask before destructive cleanup. If a credential was exposed, revoke/rotate it; deleting the file alone is not enough.
**Done when:** findings and safe cleanup plan are reported; no secret value exposed.

## T01 — Architecture inventory
Map entry point, routes, theme, auth, Firebase initialization, dependencies, tests, and feature folders. Compare with architecture doc. Do not move files yet.
**Done when:** inventory and minimal migration plan documented.

## T02 — Firebase target
Identify current Firebase project and ask owner to confirm/create a dedicated Future Youth Platform project before changing options or deploying.
**Done when:** target is confirmed; app cannot accidentally write to unrelated project.

## T03 — Theme
Centralize navy #263778 and green #00A651 tokens, preserve working layout, check contrast.
## T04 — Localization
Set up Flutter localization, Arabic RTL and English LTR, translated strings and locale tests.
## T05 — Auth and roles
Verify Admin, Teacher, Parent, Student roles and statuses; role changes privileged; no public Student/Teacher signup without approval.
## T06 — Parent and invitations
Implement parent registration, child creation/invitation, child password setup, validation and parent-child security.
## T07 — Teacher provisioning
Admin-controlled teacher provisioning and approval states; teachers cannot publish directly.
## T08 — Curriculum
Playlist → unit → lesson → numbered video; subject, school year, order and textbook reference; test one playlist per subject/year if confirmed.
## T09 — Moderation lifecycle
Implement upload state and AI-review interface without choosing provider; Admin approve/reject; require reason/timecode; replacement/resubmission.
## T10 — Free preview
Explicit server-enforced preview flag. Preview is available without payment but requires approved content. Do not guess scope; flag decision.
## T11 — Teacher selection
Per-subject selection with two confirmations and auditable record; leave change workflow unresolved.
## T12 — Payment requests
Provider-neutral models for InstaPay, Vodafone Cash, Orange Cash, Etisalat Cash; pending/manual only if owner approves; no client-side paid status.
## T13 — Subscription access
Pure policy: paid lessons require confirmed payment, active subscription, confirmed selection, approved content, active account and points where applicable. Preview bypasses payment/points only.
## T14 — Points ledger
Implement transaction-ledger abstraction, idempotency and non-negative balance tests. Do not invent point formulas or replay rules.
## T15 — Exams/progress
Lesson/unit exams, watch time and replay events; parent-child and student-only access boundaries.
## T16 — Teacher analytics
Views, ratings, comments for own content. Keep student progress closed until owner confirms aggregate scope.
## T17 — Screen-capture best effort
Implement native protection where supported; document web/desktop limitations and manual tests.
## T18 — Backend rules
Draft/test Firestore rules/functions for roles, relationships, ownership, approvals, payment and points. Do not deploy without approval.
## T19 — Audit/privacy
Audit admin and payment actions; mask sensitive fields; review logs for PII/secrets.
## T20 — End-to-end verification
Run formatter, flutter analyze and available tests. Verify all role flows, free preview vs paid content, approval lifecycle, bilingual layout and security. Report commands, actual output, unresolved issues and manual steps.

For each task, provide: files inspected/changed, behavior, tests run and results, blockers, and next task. Never claim unrun checks passed.
