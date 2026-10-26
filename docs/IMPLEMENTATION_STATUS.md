# Future Youth Platform — implementation status

This document describes what is implemented on `fix/security-and-fyp-requirements`. It is not a production-readiness claim.

## Implemented in this stage

- Student catalog query is limited to published and approved courses.
- Student course details show approved lessons, with the first approved lesson presented as a free preview and later lessons visibly locked in the UI.
- Teacher Studio lists the teacher's courses and routes into a course editor.
- Teachers can create lesson metadata and upload video files to private Firebase Storage. Upload rules limit writes to the owning teacher while a lesson is a draft; a callable validates the uploaded object.
- Teacher analytics reads lesson ratings and comments from their Firestore subcollections. Approved first-lesson preview views are counted once per student by a trusted callable; subscription lesson view tracking is not available while subscriptions remain UI-only.
- Students can submit 1–5 star ratings and comments using the Firestore schema enforced by the current rules.
- Admin UI includes teacher review, course review, and individual lesson review queues.
- Course/lesson approval checks that video sources have been linked.
- Parent checkout and admin payment-verification screens are UI-only. No payment request is written, no transfer is verified, no subscription is activated, and no points are granted by these screens.
- Payment-related callable functions were removed from the Future Youth functions code until checkout is intentionally enabled.

## Important limitations

- Playback uses short-lived (five-minute) signed Firebase Storage URLs after server-side course, lesson, teacher, and access checks. Signed URLs remain shareable until they expire; this is access control, not DRM.
- Private media upload and playback code are committed, but Storage rules, bucket configuration, upload size/MIME behavior, signed URLs, and deployed Functions still require emulator and staging verification before production.
- Screenshot and screen-recording prevention cannot be guaranteed across web and desktop clients.
- Teacher view analytics count unique students per lesson. Paid-lesson playback and view tracking call a server function that requires an active, unexpired subscription record. Payment UI remains disabled, so paid access stays denied until a trusted subscription-activation workflow exists.
- A persistent global light/dark switch is available alongside the Arabic/English language switch; both preferences are stored locally. Main learning pages now use theme surfaces for key backgrounds, and automated WCAG contrast-pair plus Arabic RTL tests were added. Remaining fixed palette uses and responsive layouts still need browser/device review.
- Arabic translations were added for key learning, teacher, parent, and theme controls. Translation coverage is improved but not yet complete across every screen and message.
- Payment screens are intentionally non-functional placeholders. Do not treat their displayed provider names or sample descriptions as payment instructions.

## Before production

1. Revoke the exposed Firebase Admin service-account key found in the repository's historical commits; follow `docs/KEY_ROTATION_CHECKLIST.md` (requires Google Cloud IAM access).
2. Test Firestore rules with the Firebase Emulator Suite, especially collection-group lesson review and course-owner analytics reads.
3. Add automated tests for teacher/video approval, source registration, and preview access.
4. Replace public Google Drive links with private storage and controlled playback.
5. Finish bilingual translations, responsive QA, and real-device/browser testing.
6. Only implement payment integration when explicitly approved; use trusted server-side verification and idempotent subscription/points transactions.
