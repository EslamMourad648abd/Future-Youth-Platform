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

- Preserve existing operational modules and the legacy `functions/` codebase unless a
  requirement explicitly needs a change. Future Youth functionality belongs in
  `lib/app`, `lib/core`, `lib/features`, `functions_fyp/`, and tests. Do not make
  destructive replacements of working screens or user-creation logic.
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
- Support English and Arabic using the existing AppLocalizations in
  lib/services/localization_service.dart. New user-facing strings must be
  localized in both languages, with RTL layout for Arabic.
