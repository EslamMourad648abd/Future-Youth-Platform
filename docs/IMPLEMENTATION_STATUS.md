# Future Youth Platform — implementation status

This document describes what is implemented on `fix/security-and-fyp-requirements`. It is not a production-readiness claim.

## Implemented in this stage

- Student catalog query is limited to published and approved courses.
- Student course details show approved lessons, with the first approved lesson presented as a free preview and later lessons visibly locked in the UI.
- Teacher Studio lists the teacher's courses and routes into a course editor.
- Teachers can create lesson metadata and link a Google Drive share URL to a draft lesson through the `registerVideoSource` callable.
- Teacher analytics reads lesson ratings and comments from their Firestore subcollections. View counts remain zero until secure playback tracking is implemented.
- Students can submit 1–5 star ratings and comments using the Firestore schema enforced by the current rules.
- Admin UI includes teacher review, course review, and individual lesson review queues.
- Course/lesson approval checks that video sources have been linked.
- Parent checkout and admin payment-verification screens are UI-only. No payment request is written, no transfer is verified, no subscription is activated, and no points are granted by these screens.
- Payment-related callable functions were removed from the Future Youth functions code until checkout is intentionally enabled.

## Important limitations

- Google Drive playback currently requires the teacher to configure the file as “Anyone with the link can view”. The preview callable checks platform approval, but the Drive URL itself is shareable and is not a DRM or signed, expiring media URL.
- The first-lesson restriction is enforced by the preview callable and UI, but a future production version should move to private media storage and short-lived signed playback URLs.
- Lesson creation currently saves metadata; video upload is not implemented. Teachers link an existing Google Drive video instead.
- Screenshot and screen-recording prevention cannot be guaranteed across web and desktop clients.
- Teacher analytics for views are not populated yet.
- Some screens still have English-only text despite the app's global Arabic/English locale switch. Full translation coverage and RTL review remain.
- Payment screens are intentionally non-functional placeholders. Do not treat their displayed provider names or sample descriptions as payment instructions.

## Before production

1. Revoke the exposed Firebase Admin service-account key found in the repository's historical commits, if not already rotated.
2. Test Firestore rules with the Firebase Emulator Suite, especially collection-group lesson review and course-owner analytics reads.
3. Add automated tests for teacher/video approval, source registration, and preview access.
4. Replace public Google Drive links with private storage and controlled playback.
5. Finish bilingual translations, responsive QA, and real-device/browser testing.
6. Only implement payment integration when explicitly approved; use trusted server-side verification and idempotent subscription/points transactions.
