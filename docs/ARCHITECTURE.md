# Architecture

## Stack

- Flutter app (`lib/main_fyp.dart`), `go_router` for navigation.
- Firebase project `future-youth-platform`: Auth, Firestore, Storage, Hosting,
  Cloud Functions (codebase `fyp`, folder `functions_fyp/`).
- Everything that moves money, points, roles or video access runs in Cloud
  Functions. The app only reads and asks.

## Brand

Two identity colors, both taken from the logo (`assets/logo.png`):

| Name | Hex | Use |
|------|-----|-----|
| Navy | `#263778` | primary: app bars, primary buttons, headings |
| Green | `#00A651` | accent: progress, success, selected state, highlights |

Everything else in `BrandColors` is a tint or a contrast-safe variant.
Measured contrast (WCAG): navy on white 11.05:1, green on white 3.19:1,
`greenText #00803F` on white 5.05:1, dark text on green 5.62:1.
So green is for large shapes, icons and bold text. For green text on a light
background use `BrandColors.greenText`. On a green fill use dark text, not white. White surfaces (cards, login card)
are acceptable with this identity.

## Folder structure

```
lib/
  main_fyp.dart                 entry point of the new app        (T01)
  app/
    fyp_app.dart                MaterialApp.router + FypTheme     (T01)
    fyp_routes.dart             all route paths                   (exists)
    fyp_router.dart             go_router, role guard             (T02)
  core/
    constants/                  user_role.dart, firestore_paths.dart   (exist)
    theme/                      brand_colors.dart, fyp_theme.dart      (exist)
    security/screen_protection.dart                                    (exists)
    widgets/                    shared widgets (placeholder_page.dart exists)
  features/
    auth/        presentation: role_select, login, signup   data: auth_repository (T03)
    admin/       presentation: dashboard, create_admin                    (T07)
    parent/      presentation: dashboard, create_student, subscription    (T08, T12)
    teacher/     presentation: dashboard, course_analytics               (T09, T15)
    student/     presentation: home, video_player, payment_locked        (T10-T13)
    course/      domain: course, video models   data: course_repository    (T09)
    video/       domain: video_access_policy (exists)   data: playback     (T10)
    points/      domain: points_policy (exists)   data: points_repository  (T11)
    subscription/ domain: subscription model   data: subscription_repository (T12)
    feedback/    comments and ratings                                      (T16)
functions_fyp/                  Cloud Functions, codebase "fyp"            (T06)
docs/                           this folder
test/fyp/                       tests for the new app
```

Older product, do not touch: `lib/modules`, `lib/router`, `lib/services`,
`lib/admin_console`, `lib/login`, `functions/`, `bbc-api-tool/`, `main/`, `public/`.

## Roles

`UserRole` = student, parent, teacher, admin. The role is stored twice, and only
Cloud Functions write either copy:

1. `role` custom claim on the Auth token. Security rules read this one.
2. `role` field on `users/{uid}`. The UI reads this one.

How accounts are created:

- Parent and teacher: sign up in the app, then call `completeSignup({role})`.
  It accepts only `parent` or `teacher`, and only for a user that has no role yet.
  A teacher stays `approvalStatus: pending` until an admin approves them and
  their content (D-3).
- Student: the existing `createUser` callable, with parent-only permission.
  Same create logic as every other role. Writes `users/{uid}` with `parentId`.
  Admins cannot create students (D-5).
- Admin: `createUser` callable by an admin (admin / teacher / parent only).
- The very first admin is created once by hand from a trusted machine with
  Application Default Credentials. There is no sign-up path to admin.

## Data model (Firestore)

```
users/{uid}                 role, displayName, email, parentId?, createdAt
courses/{courseId}          teacherId, title, description, lessonCount,
                            videoCount, price, status (draft|published),
                            createdAt
  videos/{videoId}          title, order (1 = free), durationSec, status,
                            viewCount, ratingSum, ratingCount, commentCount
    comments/{commentId}    uid, text, createdAt
    ratings/{uid}           value (1-5), updatedAt        one per student
  video_sources/{videoId}   storagePath          SERVER ONLY, no client access
subscriptions/{studentId}_{courseId}
                            parentId, studentId, courseId, status
                            (pending|active|expired), startsAt, endsAt,
                            pointsBalance
payments/{paymentId}        parentId, subscriptionId, amount, currency,
                            provider, providerRef, status (pending|paid|failed)
points_ledger/{entryId}     studentId, courseId, delta, reason
                            (subscription_grant|video_view), videoId?, paymentId?
video_views/{studentId}_{videoId}
                            studentId, courseId, videoId, startedAt,
                            completedAt?, charged
```

Document ids that are built from two ids (`subscriptions`, `video_views`) make
the operations safe to repeat: the same payment or the same view cannot be
applied twice.

## Points

- Grant (FR-08): `confirmPayment` runs in one transaction. It marks the payment
  `paid`, activates or extends the subscription, adds
  `videoCount x months` to `pointsBalance`, and writes a ledger row. If the
  payment is already `paid` it does nothing.
- Deduction (FR-06): `completeVideoView` runs in one transaction. If
  `video_views/{studentId}_{videoId}.charged` is already true it does nothing.
  Otherwise it checks the 90% rule (A-2), takes 1 point, writes a ledger row and
  sets `charged`. Order-1 videos are never charged.
- The balance can never go below 0. The ledger is append-only and is the audit
  trail; the app never writes either.

## Video delivery and protection

1. The app calls `getPlaybackUrl({courseId, videoId})`.
2. The function loads the student, the subscription and the points balance and
   applies the same rules as `decideVideoAccess`. Order-1 videos are allowed
   for the student and the parent without a subscription (D-1). Other videos
   return `payment_required` until the parent has paid.
3. If allowed, it reads `video_sources/{videoId}`, creates a signed URL that
   expires in a few minutes, and opens `video_views/...` (`startedAt`).
4. The player turns on `ScreenProtection.enable()` before it shows a frame and
   turns it off when it closes (FR-09).
5. At 90% watched the app calls `completeVideoView`.

## Payment gating (FR-10)

The student app listens (`snapshots()`) to the student's subscription
documents. No active subscription: paid videos stay on `PaymentLockedPage`.
The free first video remains playable (D-1). When `confirmPayment` flips the
status to `active`, the listener fires and the rest of the course unlocks.

## Teacher analytics (FR-11)

Counters live on each video document and are maintained by Cloud Functions:
`viewCount` (on `completeVideoView`), `ratingSum` and `ratingCount` (on rating
write), `commentCount` (on comment write). The analytics page reads the video
documents of one course, plus the comment list. Average rating is
`ratingSum / ratingCount`. A teacher can read only courses where
`teacherId == uid`.

## Security rules

Proposed rules for this data model are in `docs/proposed/firestore.rules`.
They are NOT applied yet, because the current `firestore.rules` belongs to the
older product and the same project must not lose it by accident. Task T17
merges them and tests them with the emulator.

Principles: deny by default. Clients can read their own data and write only
what is listed (comments, ratings, their own profile fields). Clients can never
write `subscriptions`, `payments`, `points_ledger`, `video_views` or
`video_sources`, and cannot change `role`.

## Hosting

`.firebaserc` default project is `future-youth-platform` with hosting target
`master`. Build the web app with
`flutter build web -t lib/main_fyp.dart` and deploy with
`firebase deploy --only hosting`. Deploy functions with
`firebase deploy --only functions:fyp` so the older functions in `functions/`
are not pushed into this project.
