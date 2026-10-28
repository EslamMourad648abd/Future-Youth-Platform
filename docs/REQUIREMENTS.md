# Requirements

Source: the owner's handwritten notes (two pages, October 2026). Every line of
the notes is below as one requirement. Where the notes were unclear, the
reading used is written as an **Assumption** and the open points are in
**Open questions**. Do not build on an open question before it is answered.

## Functional requirements

| ID | Requirement | Acceptance check |
|----|-------------|------------------|
| FR-01 | Separate login pages for Student, Parent, Teacher and Admin. | `/login/:role` shows email + password (students: username + password, A-7). After sign-in the user lands on their role's home. An account of another role is refused with a clear message. |
| FR-02 | Self sign-up only for Parent and Teacher. | `/signup/parent` and `/signup/teacher` work. There is no sign-up page for student or admin, and those URLs do not open one. |
| FR-03 | An admin creates admin accounts. | Only a signed-in admin can create one, through a Cloud Function. The creating admin stays signed in. |
| FR-04 | A parent creates the student account. | Only a parent can create a student, through a Cloud Function. The student is linked to that parent, and the parent sees a list of their students. |
| FR-05 | The first video is free. | The first video of each course (order 1) can be played without points. An unpaid student may watch it so they can assess the teacher before the parent subscribes (D-1). |
| FR-06 | Points-based viewing: watching a video removes one point. | A student needs at least 1 point to start a paid video. One completed view removes exactly 1 point, once, and the change is in the points ledger. |
| FR-07 | Minimum video count of a course equals its lesson count (from the school book). | A course stores `lessonCount`. A teacher cannot publish it until `videoCount >= lessonCount`. |
| FR-08 | Points are calculated automatically from the video count and the subscription duration. | When a payment is confirmed, a Cloud Function grants `videoCount x months` points (A-3). Running it twice for the same payment grants once. |
| FR-09 | Screenshots and screen capture are prevented. | On Android a screenshot or screen recording of the player shows a black frame. iOS hides the player while capture is active. The web cannot do this (see Q-6). |
| FR-10 | If the parent has not paid, the student sees only a loading screen until payment is done. | Paid videos are locked. The unpaid student may still play the free first video (FR-05 / D-1). When payment is confirmed the rest of the course unlocks without a restart. |
| FR-11 | A teacher sees analysis for their own course: video rating, comments, views. | Per video: average rating, rating count, comment count and the comments, view count. A teacher cannot see another teacher's course. |


| FR-12 | Teacher accounts require Admin approval before they can publish or appear in student discovery. | Self-signup creates `approvalStatus: pending`; pending/rejected teachers cannot publish or appear in the approved catalog. |
| FR-13 | Admin reviews submitted course/video content before students can access it. | New content remains pending until approved; rejection stores reviewer, timestamp, and reason. |
| FR-14 | Parents can submit subscription payment requests using Egyptian payment methods. | Supported request labels: InstaPay, Vodafone Cash, Orange Cash, Etisalat Cash. Requests do not grant access or points until an Admin confirms receipt. |
| FR-15 | The platform supports English and Arabic. | Existing `AppLocalizations` is the source of UI strings; Arabic uses RTL and English uses LTR. New feature strings must be localized rather than hard-coded. |

## Assumptions (change them by editing this file, then tell the agent)

- **A-1 / D-1** "First video is free" means the video with `order == 1` in every
  course. It costs no points. The unpaid student can watch it; this is how they
  assess the teacher they want to subscribe to. A parent can preview it too.
  Every other video stays locked until the parent pays (FR-10).
- **A-2** A view counts when the student has watched at least 90% of the video.
  One point is taken per student per video, once. Watching it again is free.
- **A-3** A subscription grants `videoCount x months` points: one full pass over
  the course for each month paid.
- **A-4** A subscription is per student per course (one teacher's course). A
  renewal extends the end date and adds points to the same subscription.
  Points belong to that subscription, not to the student overall.
- **A-5** A parent can have several students. A student belongs to one parent.
- **A-6** Videos are stored in Firebase Storage and played through short-lived
  signed URLs issued by a Cloud Function. The raw storage path is never
  readable by a client.
- **A-7** A student signs in with a username chosen by the parent, not an
  email. Internally the Auth email is `<username>@students.fyp.invalid`.
  Children often have no email address, and the parent creates the account.

## Decisions (owner, October 2026)

- **D-1** Unpaid students can watch the free first video. It is the way they
  assess the teacher before the parent subscribes.
- **D-2** Payment rails (Egypt): Instapay, Vodafone Cash, Orange Cash, Etisalat
  Cash. Until a provider is wired, T12 stays provider-neutral with admin
  confirm (`PaymentProvider`).
- **D-3** An admin must approve new teachers **and** their content after review.
  Teachers may self-sign-up, then wait as `approvalStatus: pending`.
- **D-4** Dual language: English and Arabic (RTL). Keep strings in one place
  per feature; the live app already has `AppLocalizations`.
- **D-5** Only a parent, after registering as a parent, creates a student
  account. Admins do not create students. Same `createUser` callable, tighter
  permissions only.

## Open questions (still unanswered)

- **Q-5** Note 7 says points are calculated "for a teacher". A-4 reads that as
  one subscription per teacher's course. Is that right, or is one subscription
  valid for all teachers?
- **Q-6** The web cannot block screenshots or screen recording at all. Is the
  platform Android/iOS only for students, or is the web allowed with this limit?

## Out of scope for now

The "Bevatel Mascot Assistant" and anything from the BBC Operations Platform.
