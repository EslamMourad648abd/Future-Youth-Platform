# Future Youth Platform — instructions for the AI agent

Flutter + Firebase learning platform. Teachers publish video courses, parents
pay, students watch. Four roles: student, parent, teacher, admin.

Requirements: `docs/REQUIREMENTS.md`. Design and data model:
`docs/ARCHITECTURE.md`. **Work plan: `docs/AGENT_TASKS.md`.**

## How to work

- Do ONE task from `docs/AGENT_TASKS.md` at a time, in the order given there.
  Each task has a "Done when" list. Do not start the next task until it holds.
- After each task run `dart format .`, `flutter analyze` and `flutter test`.
  No new analyzer issues. Then stop and show a short summary of what changed.
- If a task touches an "Open question" in `docs/REQUIREMENTS.md`, ask the user
  instead of choosing.

## Where code goes

- The live skeleton is the existing app construction (`lib/modules`, `lib/router`,
  `lib/services`, `lib/admin_console`, `functions/`). Do not rewrite screens or
  user-creation logic. Permission checks and identity (BrandColors / FypTheme)
  are the only allowed edits there.
- Future feature code still goes in `lib/app`, `lib/core`, `lib/features`,
  `functions_fyp/`, `docs/`, and tests under `test/fyp/`.
- `lib/main.dart` and `lib/main_fyp.dart` start the same Future Youth Platform
  app. Do not reintroduce BBC / Bevatel identity or a second product tree.
- Roles, who may create whom, and video access live in
  `lib/core/permissions/role_permissions.dart` and
  `lib/features/video/domain/video_access_policy.dart`. Keep those as the
  source of truth when features grow.
- Feature layout: `features/<name>/{presentation,domain,data}`. Pages and widgets
  in `presentation`, pure rules in `domain`, Firebase access in `data`.

## Rules that must not be broken

- Colors: navy `#263778` and green `#00A651`, only through `BrandColors` and
  `FypTheme`. No hex values in widgets. Never small white text on a green fill.
- Roles come from `UserRole`. Routes come from `FypRoutes`. Collection names come
  from `FirestorePaths`. No inline strings for these.
- The client never writes points, subscriptions, payments, roles or video
  sources. Those are written only by Cloud Functions in `functions_fyp/`.
  Access decisions are made again on the server.
- Secrets: never commit or print service-account keys, `.env` files or tokens.
  Cloud Functions use Application Default Credentials.
- Keep the UI strings in English for now, but put them in one place per feature
  so Arabic can be added later.
