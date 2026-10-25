# Proposed Architecture

## Principles
- Inspect and adapt the existing project; do not replace it wholesale.
- Feature-oriented Flutter structure with separation of UI, business logic, and data access.
- Firebase may already be configured, but verify the intended Future Youth Platform project before using it. Do not accidentally connect to another product's project.
- Server-side validation is authoritative for roles, approvals, payment and points.
- Keep payment and AI providers behind interfaces.

## Suggested target structure (adopt incrementally)
```
lib/
  app/ (app.dart, router/, theme/, localization/)
  core/ (auth/, errors/, result/, security/, widgets/)
  features/
    auth/
    parent/ (children/, payments/, progress/)
    student/ (onboarding/, teacher_selection/, catalog/, video_player/, exams/, progress/)
    teacher/ (playlists/, units/, lessons/, videos/, ai_review/, analytics/)
    admin/ (dashboard/, users/, content_review/, payments/, audit_logs/)
    subscriptions/
    points/
    notifications/
  l10n/
  main.dart
test/ (unit/, widget/, integration/)
docs/ (requirements, permissions, architecture, task queue, open decisions)
```
This is a target, not permission to move existing files immediately.

## Proposed entities
- users: uid, role, status, displayName, locale, createdAt, updatedAt.
- parent profile: uid, phone, protected/minimized national ID.
- students: uid, parentUid, schoolYear, invitationStatus, accountStatus.
- teacherProfiles: uid, approvalStatus, subjects, schoolYears.
- playlists: id, teacherUid, subjectId, schoolYear, status.
- units: id, playlistId, order, title.
- lessons: id, unitId, order, title, textbookReference.
- videos: id, lessonId, teacherUid, order, durationSeconds, storagePath, moderationStatus, adminDecision, rejectionReason, rejectionTimecode, isFreePreview, publishedAt.
- teacherSelections: studentUid, subjectId, teacherUid, confirmationCount, status.
- subscriptions: parentUid, studentUid, subjectId/teacherUid, status, startsAt, endsAt, pointsGranted.
- paymentRequests: parentUid, amount, currency, method, reference, status, submittedAt, verifiedAt, verifiedBy.
- pointTransactions: studentUid, subscriptionId, signed amount, reason, videoId, idempotencyKey, createdAt.
- videoWatchEvents, ratings, comments, examAttempts, examResults, auditLogs, notifications.

Schema is a proposal, not final. Use server timestamps and avoid putting national IDs into broadly readable documents.

## Video access outcomes
Use a pure, testable policy with explicit outcomes such as freePreviewAllowed, paymentRequired, teacherSelectionRequired, contentPendingApproval, accountInactive, insufficientPoints, and allowed. Server is authoritative. Avoid long-lived public URLs for protected videos; use short-lived access grants or equivalent controlled delivery.

## Content approval
Uploads never publish automatically. AI review and Admin approval are distinct. Rejections preserve reason/timecode. Replacement/resubmission is auditable and reviewed again.

## Payments and points
- Payment provider undecided. Keep provider-neutral interfaces.
- Pending/manual verification only if product owner approves; never claim automatic integration without a verified route.
- Payment status written only by trusted backend or authorized verification.
- Point grants/consumption occur server-side with idempotency. Do not finalize formulas or replay policy until owner confirms.

## Screen capture
Implement best-effort native capture prevention on supported platforms. Document that web/desktop capture cannot be universally prevented and an external camera cannot be blocked.

## Branding and localization
Navy #263778, green #00A651. Use Flutter localization, Arabic RTL and English LTR. Check contrast and avoid hard-coded user-facing strings.
