# Product Requirements — Future Youth Platform

## Labels
**Stated** = directly from notebook, user clarification, or supplied role matrix. **Inferred** = needed for coherent behavior. **Recommended** = proposed default needing confirmation. Do not silently convert recommendations into requirements.

## Purpose
A bilingual Arabic/English learning platform where teachers publish curriculum video lessons, students preview and learn, parents manage children and payments, and Admin reviews teacher/content.

## Roles and functional requirements

### Accounts
- **FR-01 Stated:** Role-appropriate login for Admin, Teacher, Parent, Student.
- **FR-02 Stated/Recommended:** Admin and Teacher use separate private entry links; Parent can register publicly; Student cannot self-register.
- **FR-03 Stated:** Parent creates child profiles and sends invitations by email.
- **FR-04 Stated:** Invited Student accepts invitation and sets their own password.
- **FR-05 Stated:** Admin accounts are created/provisioned by an authorized Admin/super-admin. Teacher account provisioning is admin-controlled; no public teacher signup unless approved.
- **FR-06 Stated:** Admin can support and manage accounts. Soft deletion with audit trail is recommended; confirm destructive deletion behavior.

### Curriculum and teacher content
- **FR-07 Stated:** Teacher creates playlists by subject and school year; matrix specifies one playlist per subject/year.
- **FR-08 Stated:** Playlist structure: units → lessons → numbered videos.
- **FR-09 Stated:** Teacher submits uploads for AI review.
- **FR-10 Stated:** Uploaded content is not available for normal paid learning until AI review and Admin approval.
- **FR-11 Stated:** Admin reviews AI report and approves/rejects each video.
- **FR-12 Stated:** Rejection includes video identity, exact minute/timecode, and reason. Teacher can replace and resubmit.
- **FR-13 Stated:** Content must not include personal contact details, profanity, or non-curriculum music.
- **FR-14 Stated:** A free preview video lets a student evaluate a teacher before subscribing.
- **FR-15 Inferred:** Free-preview eligibility must be explicit and server-enforced. Confirm whether the preview is per teacher, subject, playlist, or course.

### Parent payments and activation
- **FR-16 Stated:** Parent is payer; Student cannot pay.
- **FR-17 Stated:** Student chooses a teacher per subject and confirms the selection twice.
- **FR-18 Stated:** A fee notice follows teacher selection.
- **FR-19 Stated:** Until payment is confirmed, paid lessons show a waiting/loading state. Free preview remains available before payment.
- **FR-20 Stated:** Paid access activates only after confirmed payment and other eligibility checks.
- **FR-21 Stated preference, provider undecided:** Preferred Egyptian payment methods: InstaPay, Vodafone Cash, Orange Cash, Etisalat Cash.
- **FR-22 Recommended:** Initially record pending payment requests and use authorized manual verification if owner approves. Do not claim automatic payment integration without a verified provider integration.
- **FR-23 Recommended:** Payment events must be auditable and idempotent; never store wallet PINs or bank credentials.

### Points, lessons, exams
- **FR-24 Stated but incomplete:** Watching a video consumes one point; points are calculated automatically based on video count and subscription duration.
- **FR-25 Stated but incomplete:** Minimum video count corresponds to lesson count based on the school book.
- **FR-26 Open:** Grant formula, point quantity, expiry, replay charging, and view-completion threshold are not defined. Do not invent them.
- **FR-27 Stated:** Students take lesson and unit exams.
- **FR-28 Stated:** Parent monitors each child's exam results, curriculum progress, watch time, and replay counts.
- **FR-29 Stated:** Student sees own results and progress.
- **FR-30 Recommended:** Use a server-side point transaction ledger to prevent duplicate charges and client-side tampering.

### Analytics, privacy, security
- **FR-31 Stated:** Teacher analytics include own content's views, ratings, and comments.
- **FR-32 Unresolved:** Matrix is ambiguous about teacher access to individual or anonymous aggregate student progress. Keep student-level access closed until confirmed.
- **FR-33 Recommended:** Do not expose student names, national IDs, contact data, or individual exam results to teachers unless approved.
- **FR-34 Inferred:** Parent accesses only their own children; Student accesses only their own records.
- **FR-35 Inferred:** Teacher cannot read unrelated users' private data.
- **FR-36 Stated:** Prevent screenshots/screen capture where platform permits.
- **FR-37 Limitation:** Capture blocking is best-effort on supported native platforms; cannot be guaranteed on all web/desktop environments or against filming with another device.
- **FR-38 Recommended:** Audit Admin approvals/rejections, account changes, and payment verification.
- **FR-39 Recommended:** Mask sensitive identity fields and never log secrets.

### Localization and identity
- **FR-40 Stated:** Arabic and English.
- **FR-41 Stated:** Brand navy #263778 and green #00A651.
- **FR-42 Recommended:** Arabic RTL, English LTR, localized UI strings.

## Acceptance scenarios
1. Parent registers and creates a child profile.
2. Student cannot self-register and must accept an invitation.
3. Student can view designated free preview without paid subscription.
4. Unpaid Student cannot access paid lessons.
5. Teacher uploads remain unpublished until AI review and Admin approval.
6. Rejection stores reason and timecode; replacement can be resubmitted.
7. Only Admin can approve/reject.
8. Parent sees only their children; Student sees only own records.
9. Teacher analytics are scoped to their own content.
10. Arabic renders RTL and English LTR.
11. Backend rules deny unauthorized direct reads/writes.

## Open decisions
- Free-preview scope: teacher, subject, playlist, or course?
- Exact points grant/consumption formula; replay and completion policy?
- Provider and official payment integration route?
- AI moderation provider and criteria?
- Teacher analytics: content metrics only or anonymous progress aggregates?
- Invitation expiry and reminder cadence?
- Teacher-change workflow after confirmation?
- Who bootstraps first Admin; is super-admin a separate role?
- Soft delete or permanent deletion cases?
- Initial platform scope: mobile-only or web/desktop too?
- Can parents themselves preview content, or is preview Student-only?
