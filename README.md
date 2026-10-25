# Future Youth Platform

A bilingual Arabic/English video-learning platform built with Flutter and Firebase.

## Product roles

- **Admin:** review teacher content, approve/reject videos, manage teacher approvals, and review payment requests.
- **Teacher:** organize curriculum content into playlists, units, lessons, and video entries; track review status and content analytics.
- **Parent:** manage child profile/invitation requests, submit payment requests, and monitor learning progress.
- **Student:** explore teachers, watch approved free previews, access eligible paid learning, and take lesson/unit exams.

## Brand

- Navy: `#263778`
- Green: `#00A651`

Arabic and English are supported. Arabic layouts use right-to-left direction and English uses left-to-right direction.

## Run locally

Install Flutter and configure the Firebase project/app registrations for your target platform.

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d edge
```

## Current implementation status

The current branch adds a first role-aware workspace and initial Firestore-backed workflow surfaces:

- role-specific landing actions;
- teacher playlist drafts;
- parent child-profile/invitation requests;
- payment requests that remain pending until verified;
- Admin video review actions requiring rejection reason and timecode;
- branding and route integration.

The following are **not yet complete** and must not be treated as production-ready: actual video uploads/storage, automated AI moderation, email invitations and student Auth provisioning, payment gateway integrations, authoritative subscription/points enforcement, exam authoring/attempts, full analytics, comprehensive Firestore security rules, and native screen-capture prevention.

## Security and Firebase

Verify the Firebase project and per-platform Firebase options before running or deploying. Do not commit service-account keys or other secrets. Firestore rules and trusted Cloud Functions must enforce authorization; UI visibility is not a security boundary.

No Firebase deployment is performed by this repository change.
